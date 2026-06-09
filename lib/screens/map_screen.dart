import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_popup/flutter_popup.dart';
import 'package:intl/intl.dart';

import '../models/call_out_result.dart';
import '../models/map_place.dart';
import '../models/app_transaction.dart';
import '../models/hotspot.dart';
import '../repositories/transaction_repository.dart';
import '../services/sms_service.dart';
import '../services/spending_service.dart';
import '../services/geofence_service.dart';
import '../utils/marker_utils.dart';
import '../widgets/category_messages_sheet.dart';
import '../widgets/map_style_picker_modal.dart';
import '../widgets/map/map_action_button.dart';
import '../widgets/map/map_category_filters.dart';
import '../widgets/map/map_search_header.dart';
import '../widgets/map/grouped_transactions_sheet.dart';
import '../widgets/map/transaction_popup_content.dart';
import '../widgets/analytics/grouped_transactions_list.dart';
import '../widgets/custom_toast.dart';
import 'location_picker_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  mp.PointAnnotationManager? _annotationManager;
  mp.CircleAnnotationManager? _dotManager;
  final Map<String, MapPlace> _annotationToPlaceMap = {};
  final bool _isAnimating = false;
  List<MapPlace> _places = [];
  mp.MapboxMap? mapboxMapController;
  StreamSubscription? userPositionStream;
  StreamSubscription? _bgServiceSub;
  gl.Position? _lastGeofenceRegistrationPoint;
  final GeofenceService _geofenceService = GeofenceService();

  int _annotationUpdateVersion = 0;
  String _currentMapStyle = mp.MapboxStyles.STANDARD;
  bool _isMapUpdating = false;

  final GlobalKey<MapSearchHeaderState> _headerKey = GlobalKey();

  String? _selectedCategory;
  String? _selectedTxId;

  final GlobalKey<CustomPopupState> _popupKey = GlobalKey<CustomPopupState>();
  mp.ScreenCoordinate? _popupPosition;
  MapPlace? _selectedPlace;
  bool _isPopupActive = false;

  // Initialised once onMapCreated fires
  final GlobalKey _fabKey = GlobalKey();
  SmsService? _smsService;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _loadMapStyle();
    _positionTracking();

    // Listen for background service events
    _bgServiceSub = FlutterBackgroundService().on('transaction_saved').listen((
      _,
    ) {
      if (mounted) {
        context.read<SpendingService>().refresh();
      }
    });

    FlutterBackgroundService().on('location_attached').listen((event) async {
      if (mounted) {
        final spending = context.read<SpendingService>();
        // Explicitly await refresh to ensure the new transaction is in mappedTransactions
        await spending.refresh();

        if (event != null && event['id'] != null) {
          final txId = event['id'].toString();
          if (mounted) {
            final mappedTxs = spending.mappedTransactions;
            final txIndex = mappedTxs.indexWhere((t) => t.id == txId);
            if (txIndex != -1) {
              _headerKey.currentState?.showDynamicIslandForTransaction(
                mappedTxs[txIndex],
              );
            }
          }
        }
      }
    });

    // Add listener for selected transaction from Messages screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SpendingService>().addListener(_handleSelectedTransaction);
    });

    // Check for recently mapped transactions on app startup
    _checkRecentTransactions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    userPositionStream?.cancel();
    _bgServiceSub?.cancel();
    mapboxMapController?.dispose();
    _smsService?.dispose();

    // Remove listener to prevent memory leaks
    final spending = Provider.of<SpendingService>(context, listen: false);
    spending.removeListener(_refreshAnnotations);
    spending.removeListener(_refreshHotspots);
    spending.removeListener(_handleSelectedTransaction);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh data and check for recent transactions whenever we return to the foreground
      context.read<SpendingService>().refresh().then((_) {
        _checkRecentTransactions();
      });
    }
  }

  Future<void> _checkRecentTransactions() async {
    // Slight delay to ensure Provider context is ready
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final spending = context.read<SpendingService>();

    // Wait for the SpendingService to finish its initial data fetch
    while (spending.isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }

    final now = DateTime.now();
    // Scan for any mapped transactions that occurred in the last 5 minutes
    for (final tx in spending.mappedTransactions) {
      if (now.difference(tx.timestamp).inMinutes <= 5) {
        _headerKey.currentState?.showDynamicIslandForTransaction(tx);
      }
    }
  }

  Future<void> _loadMapStyle() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStyle = prefs.getString('map_style');
    if (savedStyle != null && mounted) {
      setState(() {
        _currentMapStyle = savedStyle;
      });

      // If controller is already ready, load the style now
      if (mapboxMapController != null) {
        await mapboxMapController!.loadStyleURI(savedStyle);
        // Style load takes a moment, expressions need re-applying
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _applyStyleLayerExpressions();
            _refreshAnnotations();
          }
        });
      }
    }
  }

  Future<void> _saveMapStyle(String styleUri) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('map_style', styleUri);
  }

  void _handleSelectedTransaction() async {
    final spending = context.read<SpendingService>();
    final txId = spending.selectedTxId;
    if (txId == null || mapboxMapController == null) return;

    // Find the transaction in either mapped or period transactions
    final allTxs = [
      ...spending.mappedTransactions,
      ...spending.periodTransactions,
    ];
    final txIndex = allTxs.indexWhere((t) => t.id == txId);
    if (txIndex == -1) {
      spending.clearSelectedTransaction();
      return;
    }
    final tx = allTxs[txIndex];

    if (tx.latitude == null || tx.longitude == null) {
      spending.clearSelectedTransaction();
      return;
    }

    final place = MapPlace(
      name: tx.merchant,
      latitude: tx.latitude!,
      longitude: tx.longitude!,
      transactions: [tx],
    );

    // Fly to the location
    await mapboxMapController?.flyTo(
      mp.CameraOptions(
        zoom: 17,
        center: mp.Point(
          coordinates: mp.Position(place.longitude, place.latitude),
        ),
      ),
      mp.MapAnimationOptions(duration: 1000),
    );

    // Wait for camera animation to finish
    await Future.delayed(const Duration(milliseconds: 1100));

    if (!mounted) return;

    final screenCoord = await mapboxMapController?.pixelForCoordinate(
      mp.Point(coordinates: mp.Position(place.longitude, place.latitude)),
    );

    if (screenCoord != null && mounted) {
      setState(() {
        _selectedPlace = place;
        _popupPosition = screenCoord;
        _selectedTxId = tx.id;
      });

      // Boost priority of the selected annotation so it wins collision
      await _updateAnnotationPriority();

      // Clear the selection so it doesn't trigger again on every rebuild
      spending.clearSelectedTransaction();

      // Show popup in next frame after Positioned has moved the anchor
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _popupKey.currentState?.show();
      });
    }
  }

  Future<void> _updateAnnotationPriority() async {
    if (_annotationManager == null || _selectedTxId == null) return;

    final allAnnotations = await _annotationManager!.getAnnotations();
    for (final ann in allAnnotations) {
      final place = _annotationToPlaceMap[ann.id];
      if (place == null) continue;

      final double newSortKey = _getSortKey(place);

      if (ann.symbolSortKey != newSortKey) {
        ann.symbolSortKey = newSortKey;
        await _annotationManager!.update(ann);
      }
    }
  }

  List<MapPlace> _groupTransactions(List<AppTransaction> transactions) {
    final Map<String, List<AppTransaction>> groups = {};

    for (var tx in transactions) {
      if (tx.latitude == null || tx.longitude == null) continue;
      // Using a rounded coordinate string as key to handle precision issues if any,
      // but the requirement says "exact same location".
      final key = '${tx.latitude},${tx.longitude}';
      groups.putIfAbsent(key, () => []).add(tx);
    }

    return groups.values.map((group) {
      return MapPlace(
        name: group.first.merchant,
        latitude: group.first.latitude!,
        longitude: group.first.longitude!,
        transactions: group,
      );
    }).toList();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // Build

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 12;
    final spending = context.watch<SpendingService>();

    // Sync places with spending service mapped transactions
    final saved = spending.mappedTransactions
        .where((tx) => _isToday(tx.timestamp))
        .toList();
    _places = _groupTransactions(saved);

    return CupertinoPageScaffold(
      child: Stack(
        children: [
          mp.MapWidget(
            styleUri: _currentMapStyle,
            onMapCreated: onMapCreated,
            onCameraChangeListener: (data) {
              debugPrint(
                '🔥🔥[MapBox] Zoom Level: ${data.cameraState.zoom.toStringAsFixed(2)}🔥🔥',
              );
            },
          ),
          if (spending.isLoading || _isMapUpdating)
            const Center(
              child: CupertinoActivityIndicator(
                radius: 16,
                color: CupertinoColors.activeBlue,
              ),
            ),
          Positioned(
            top: topPadding,
            left: 16,
            right: 16,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 46),
                  child: MapCategoryFilters(
                    categories: spending.categories,
                    selectedCategory: _selectedCategory,
                    onCategoryTap: (cat) async {
                      setState(() {
                        if (_selectedCategory == cat.name) {
                          _selectedCategory = null;
                        } else {
                          _selectedCategory = cat.name;
                        }
                      });

                      if (_selectedCategory != null) {
                        final results = await spending.getMessagesByCategory(
                          cat.name,
                        );
                        if (!context.mounted) return;

                        showCupertinoSheet(
                          context: context,
                          builder: (context) => CategoryMessagesSheet(
                            results: results,
                            categoryName: cat.name,
                            onMessageSelected: (tx) {
                              spending.selectTransaction(tx.id);
                            },
                          ),
                        );
                      }
                    },
                  ),
                ),
                MapSearchHeader(
                  key: _headerKey,
                  onTransactionSelected: (tx) {
                    _flyToAndShowPopup(tx);
                  },
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 40,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MapActionButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    _showMapStylePicker();
                  },
                  child: const Icon(
                    CupertinoIcons.square_stack_3d_up,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
                const SizedBox(height: 12),
                MapActionButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    _flyToUserLocation();
                  },
                  child: const Icon(
                    CupertinoIcons.location_fill,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
                const SizedBox(height: 12),
                if (_places.isNotEmpty)
                  MapActionButton(
                    buttonKey: _fabKey,
                    isAnimating: _isAnimating,
                    onPressed: _isAnimating
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            showCupertinoModalPopup(
                              context: context,
                              builder: (context) =>
                                  _buildHeatmapModal(spending),
                            );
                          },
                    child: _isAnimating
                        ? const CupertinoActivityIndicator(
                            color: CupertinoColors.white,
                          )
                        : const Icon(
                            CupertinoIcons.play_fill,
                            color: CupertinoColors.black,
                          ),
                  ),
              ],
            ),
          ),
          if (_popupPosition != null &&
              _selectedPlace != null &&
              _isPopupActive)
            Positioned(
              key: ValueKey(_selectedTxId),
              left: _popupPosition!.x,
              top: _popupPosition!.y,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: CustomPopup(
                    key: _popupKey,
                    backgroundColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                    content: TransactionPopupContent(place: _selectedPlace!),
                    child: const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeatmapModal(SpendingService spending) {
    return _HeatmapExploreSheet(
      transactions: spending.mappedTransactions,
      onTopItemChanged: (tx) {
        _handleTopItemChanged(tx);
      },
    );
  }

  Future<void> _flyToUserLocation() async {
    try {
      // Get last known position for immediate feedback if possible
      final lastPos = await gl.Geolocator.getLastKnownPosition();
      if (lastPos != null && mounted) {
        await mapboxMapController?.flyTo(
          mp.CameraOptions(
            zoom: 17,
            bearing: 0.0,
            pitch: 0.0,
            center: mp.Point(
              coordinates: mp.Position(lastPos.longitude, lastPos.latitude),
            ),
          ),
          mp.MapAnimationOptions(duration: 800),
        );
      }

      final position = await gl.Geolocator.getCurrentPosition(
        locationSettings: const gl.LocationSettings(
          accuracy: gl.LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      _checkGeofenceRegistration(position);
      await mapboxMapController?.flyTo(
        mp.CameraOptions(
          zoom: 17,
          bearing: 0.0,
          pitch: 0.0,
          center: mp.Point(
            coordinates: mp.Position(position.longitude, position.latitude),
          ),
        ),
        mp.MapAnimationOptions(duration: 1000),
      );
    } catch (e) {
      debugPrint('[Home] Could not get user location: $e');
    }
  }

  // Location tracking

  void _checkGeofenceRegistration(gl.Position currentPosition) {
    if (_lastGeofenceRegistrationPoint == null) {
      _registerGeofences(currentPosition);
      return;
    }

    final distance = gl.Geolocator.distanceBetween(
      _lastGeofenceRegistrationPoint!.latitude,
      _lastGeofenceRegistrationPoint!.longitude,
      currentPosition.latitude,
      currentPosition.longitude,
    );

    // Re-registration rule: moves more than 2km from the last registration point
    if (distance > 2000) {
      _registerGeofences(currentPosition);
    }
  }

  void _registerGeofences(gl.Position pivot) {
    _lastGeofenceRegistrationPoint = pivot;
    if (!mounted) return;
    final spending = context.read<SpendingService>();
    final hotspots = List<Hotspot>.from(spending.hotspots);

    if (hotspots.isEmpty) return;

    // Sort by distance to pivot and take top 100 to stay within Android limits
    hotspots.sort((a, b) {
      final distA = gl.Geolocator.distanceBetween(
        pivot.latitude,
        pivot.longitude,
        a.latitude,
        a.longitude,
      );
      final distB = gl.Geolocator.distanceBetween(
        pivot.latitude,
        pivot.longitude,
        b.latitude,
        b.longitude,
      );
      return distA.compareTo(distB);
    });

    final nearestHotspots = hotspots.take(100).toList();
    _geofenceService.registerHotspots(nearestHotspots);
    debugPrint(
      '[MapScreen] Registered ${nearestHotspots.length} hotspots near user',
    );
  }

  Future<void> _positionTracking() async {
    final bool serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[Home] Location service is off');
      return;
    }

    userPositionStream?.cancel();
    userPositionStream =
        gl.Geolocator.getPositionStream(
          locationSettings: const gl.LocationSettings(
            accuracy: gl.LocationAccuracy.high,
            distanceFilter: 50,
          ),
        ).listen((gl.Position? position) {
          if (position != null) {
            _checkGeofenceRegistration(position);
            if (mapboxMapController != null && !_isAnimating) {
              mapboxMapController?.setCamera(
                mp.CameraOptions(
                  zoom: 17,
                  center: mp.Point(
                    coordinates: mp.Position(
                      position.longitude,
                      position.latitude,
                    ),
                  ),
                ),
              );
            }
          }
        });
  }

  void _showMapStylePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => MapStylePickerModal(
        currentStyle: _currentMapStyle,
        onStyleChanged: (newStyle) async {
          if (newStyle == _currentMapStyle) return;
          setState(() => _currentMapStyle = newStyle);
          await _saveMapStyle(newStyle);
          await mapboxMapController?.loadStyleURI(newStyle);
          // Wait for style to load before re-applying layer properties
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _applyStyleLayerExpressions();
              _refreshAnnotations();
              _refreshHotspots();
            }
          });
        },
      ),
    );
  }

  Future<void> _applyStyleLayerExpressions() async {
    if (mapboxMapController == null) return;

    // 2. Configure Callout Collision & Native Opacity Expressions
    if (_annotationManager != null) {
      await _annotationManager!.setIconAllowOverlap(false);
      await _annotationManager!.setIconIgnorePlacement(false);
      await _annotationManager!.setTextAllowOverlap(false);
      await _annotationManager!.setTextIgnorePlacement(false);

      // Detailed Callouts: Visible only >= 13.0
      await mapboxMapController?.style.setStyleLayerProperty(
        _annotationManager!.id,
        'icon-opacity',
        [
          'step',
          ['zoom'],
          0.0,
          11.0,
          1.0,
        ],
      );
      await mapboxMapController?.style.setStyleLayerProperty(
        _annotationManager!.id,
        'text-opacity',
        [
          'step',
          ['zoom'],
          0.0,
          11.0,
          1.0,
        ],
      );
    }

    // 3. Configure Dot Native Opacity Expressions
    if (_dotManager != null) {
      // Dots: Hidden < 11.0, Visible >= 11.0
      // By staying visible, they act as a fallback when the Callout above them is hidden by collision.
      await mapboxMapController?.style.setStyleLayerProperty(
        _dotManager!.id,
        'circle-opacity',
        [
          'step',
          ['zoom'],
          0.0,
          9.0,
          1.0,
        ],
      );
      await mapboxMapController?.style.setStyleLayerProperty(
        _dotManager!.id,
        'circle-stroke-opacity',
        [
          'step',
          ['zoom'],
          0.0,
          9.0,
          1.0,
        ],
      );
    }
  }

  // Map

  Future<void> onMapCreated(mp.MapboxMap controller) async {
    setState(() => mapboxMapController = controller);

    // Limit zoom range: prevents globe view (min 3.0) and excessive street-level zoom (max 19.73)
    await controller.setBounds(
      mp.CameraBoundsOptions(minZoom: 3.0, maxZoom: 19.73),
    );

    // Ensure the persisted style is loaded if it's not the default
    if (_currentMapStyle != mp.MapboxStyles.STANDARD) {
      await controller.loadStyleURI(_currentMapStyle);
    }

    final locationPermission = await Permission.location.status;
    if (locationPermission != PermissionStatus.granted) return;

    // Center map on user's last known position immediately to avoid New York
    try {
      final lastPos = await gl.Geolocator.getLastKnownPosition();
      if (lastPos != null && mounted) {
        controller.setCamera(
          mp.CameraOptions(
            zoom: 17,
            center: mp.Point(
              coordinates: mp.Position(lastPos.longitude, lastPos.latitude),
            ),
          ),
        );
      }
      // Trigger a fresh location fetch for high accuracy
      gl.Geolocator.getCurrentPosition(
        locationSettings: const gl.LocationSettings(
          accuracy: gl.LocationAccuracy.high,
        ),
      ).then((pos) {
        if (mounted) {
          controller.flyTo(
            mp.CameraOptions(
              zoom: 17,
              center: mp.Point(
                coordinates: mp.Position(pos.longitude, pos.latitude),
              ),
            ),
            mp.MapAnimationOptions(duration: 1000),
          );
        }
      });
    } catch (e) {
      debugPrint('[MapScreen] Initial location fetch failed: $e');
    }

    controller.location.updateSettings(
      mp.LocationComponentSettings(enabled: true, pulsingEnabled: false),
    );

    controller.compass.updateSettings(
      mp.CompassSettings(
        enabled: true,
        position: mp.OrnamentPosition.BOTTOM_RIGHT,
        marginTop: 0,
        marginBottom: 210, // Positioned above the FABs
        marginLeft: 0,
        marginRight: 16,
      ),
    );

    controller.scaleBar.updateSettings(
      mp.ScaleBarSettings(
        enabled: false,
        position: mp.OrnamentPosition.BOTTOM_RIGHT,
        marginBottom: 60, // Positioned just above the tab bar
        marginRight: 16,
      ),
    );

    // 1. Initialize Managers
    // Important: Initialize _dotManager FIRST so it renders BELOW the _annotationManager.
    _dotManager = await controller.annotations.createCircleAnnotationManager();
    _annotationManager = await controller.annotations
        .createPointAnnotationManager();

    await _applyStyleLayerExpressions();

    // 3. Configure Dot Native Opacity Expressions (continued)
    if (_dotManager != null) {
      // Shared tap events for dots
      _dotManager!.tapEvents(
        onTap: (annotation) =>
            _onMarkerTapped(annotation.id, annotation.geometry),
      );
      _dotManager!.longPressEvents(
        onLongPress: (annotation) =>
            _onMarkerLongPressed(annotation.id, annotation.geometry),
      );
    }

    // Handle marker taps for full callouts
    _annotationManager?.tapEvents(
      onTap: (annotation) =>
          _onMarkerTapped(annotation.id, annotation.geometry),
    );
    _annotationManager?.longPressEvents(
      onLongPress: (annotation) {
        HapticFeedback.heavyImpact();
        _onMarkerLongPressed(annotation.id, annotation.geometry);
      },
    );

    if (!mounted) return;
    final spending = context.read<SpendingService>();
    _smsService = SmsService(repo: TransactionRepository(), spending: spending);
    await _smsService!.init();

    spending.addListener(_refreshAnnotations);
    spending.addListener(_refreshHotspots);
    _refreshAnnotations();
    _refreshHotspots();
  }

  Future<void> _refreshHotspots() async {
    if (mapboxMapController == null) return;
    if (!mounted) return;

    final spending = context.read<SpendingService>();
    final transactions = spending.mappedTransactions;

    if (!spending.isHotspotDataSufficient) {
      _showHotspotDataNotification();
    }

    // Use try-catch to avoid breaking the UI if style operations fail
    try {
      if (transactions.isEmpty) {
        if (await mapboxMapController!.style.styleLayerExists(
          'hotspots-heatmap',
        )) {
          await mapboxMapController!.style.removeStyleLayer('hotspots-heatmap');
        }
        if (await mapboxMapController!.style.styleSourceExists(
          'hotspots-source',
        )) {
          await mapboxMapController!.style.removeStyleSource('hotspots-source');
        }
        return;
      }

      final now = DateTime.now();
      final geojson = {
        'type': 'FeatureCollection',
        'features': transactions.map((tx) {
          final daysAgo = now.difference(tx.timestamp).inDays;
          // lambda = 0.02 -> weight halves roughly every 35 days
          final decayedAmount = tx.amount * math.exp(-0.02 * daysAgo);

          return {
            'type': 'Feature',
            'properties': {
              'amount': tx.amount,
              'decayed_amount': decayedAmount,
            },
            'geometry': {
              'type': 'Point',
              'coordinates': [tx.longitude, tx.latitude],
            },
          };
        }).toList(),
      };

      // Ensure we remove the layer before removing the source if we were to recreate them,
      // but here we'll try to update if possible.
      if (await mapboxMapController!.style.styleSourceExists(
        'hotspots-source',
      )) {
        // Correct way to update GeoJSON data in Mapbox
        await mapboxMapController!.style.setStyleSourceProperty(
          'hotspots-source',
          'data',
          jsonEncode(geojson),
        );
      } else {
        await mapboxMapController!.style.addSource(
          mp.GeoJsonSource(id: 'hotspots-source', data: jsonEncode(geojson)),
        );
      }

      if (!await mapboxMapController!.style.styleLayerExists(
        'hotspots-heatmap',
      )) {
        // Create heatmap layer with defaults
        final heatmapLayer = mp.HeatmapLayer(
          id: 'hotspots-heatmap',
          sourceId: 'hotspots-source',
        );

        // Insert below the annotation layers
        try {
          if (_dotManager != null) {
            await mapboxMapController!.style.addLayerAt(
              heatmapLayer,
              mp.LayerPosition(below: _dotManager!.id),
            );
          } else {
            await mapboxMapController!.style.addLayer(heatmapLayer);
          }
        } catch (e) {
          await mapboxMapController!.style.addLayer(heatmapLayer);
        }
      }

      // Heatmap styling expressions
      //
      // Google Photos-style clustering.
      //   • Zoomed out (city/country): large overlapping radii fuse nearby
      //     transactions into unified warm blobs.
      //   • Zoomed in (street): blobs fragment into individual amber/orange dots.
      //   • No blue, green, or purple in the gradient.
      //
      // Radius is INVERTED — large when zoomed OUT, small when
      // zoomed IN. This produces the clustering-then-fragmentation behaviour.

      // Intensity: low at country scale to prevent blob fusion, ramps up at
      // street level so individual dots glow visibly.
      await mapboxMapController!.style.setStyleLayerProperty(
        'hotspots-heatmap',
        'heatmap-intensity',
        [
          'interpolate',
          ['linear'],
          ['zoom'],
          8,
          0.4,
          10,
          0.6,
          12,
          1.0,
          14,
          1.5,
          17,
          2.5,
        ],
      );

      // Color: warm amber, orange, and deep red.
      // • density 0.0 -> fully transparent (no colour bleed)
      // • density 0.2 -> faint amber glow (isolated single transactions)
      // • density 0.4 -> solid orange (small clusters)
      // • density 0.6 -> red-orange (medium density)
      // • density 0.8 -> deep red
      // • density 1.0 -> darkest red core (maximum overlap)
      await mapboxMapController!.style.setStyleLayerProperty(
        'hotspots-heatmap',
        'heatmap-color',
        [
          'interpolate',
          ['linear'],
          ['heatmap-density'],
          0.0,
          'rgba(0, 0, 0, 0)',
          0.2,
          'rgba(255, 160, 0, 0.6)',
          0.4,
          'rgb(255, 100, 0)',
          0.6,
          'rgb(220, 30, 0)',
          0.8,
          'rgb(178, 0, 0)',
          1.0,
          'rgb(120, 0, 0)',
        ],
      );

      // Radius: INVERTED — large when zoomed out, small when zoomed in.
      // Uses linear interpolation (NOT exponential) for a smooth, predictable
      // curve. At zoom 8 each point covers ~60px, causing nearby transactions
      // to merge into a single blob. By zoom 17 the radius shrinks to 10px so
      // each transaction resolves as an individual dot.
      await mapboxMapController!.style.setStyleLayerProperty(
        'hotspots-heatmap',
        'heatmap-radius',
        [
          'interpolate',
          ['linear'],
          ['zoom'],
          8,
          60.0,
          10,
          50.0,
          12,
          30.0,
          14,
          18.0,
          17,
          10.0,
        ],
      );

      // Weight: data-driven by decayed_amount so high-value/recent transactions
      // contribute more visual density than old/small ones.
      // Floor is 0.15 (not 0.0) so even tiny transactions cast a soft glow.
      await mapboxMapController!.style.setStyleLayerProperty(
        'hotspots-heatmap',
        'heatmap-weight',
        [
          'interpolate',
          ['linear'],
          ['get', 'decayed_amount'],
          0,
          0.15,
          100,
          0.4,
          1000,
          0.75,
          3000,
          1.0,
        ],
      );

      // Opacity: fully opaque at city scale so blobs are bold and visible.
      // Slightly reduced at street level so individual dots don't obscure the
      // underlying map features.
      // First stop is zoom 8 so the heatmap is never hidden when zoomed out.
      await mapboxMapController!.style.setStyleLayerProperty(
        'hotspots-heatmap',
        'heatmap-opacity',
        [
          'interpolate',
          ['linear'],
          ['zoom'],
          // 8,  1.0,
          15, 0.85,
          17, 0.75,
        ],
      );
    } catch (e) {
      debugPrint('[MapScreen] Failed to refresh hotspots: $e');
    }
  }

  void _onMarkerTapped(String annotationId, mp.Point geometry) async {
    final place = _annotationToPlaceMap[annotationId];
    if (place == null) return;

    if (place.transactions.length > 1) {
      showCupertinoSheet(
        showDragHandle: true,
        context: context,
        builder: (context) => GroupedTransactionsSheet(
          place: place,
          onTransactionSelected: (txId) {
            final spending = context.read<SpendingService>();
            spending.selectTransaction(txId);
          },
        ),
      );
      return;
    }

    final screenCoord = await mapboxMapController?.pixelForCoordinate(geometry);

    if (screenCoord != null && mounted) {
      setState(() {
        _selectedPlace = place;
        _popupPosition = screenCoord;
        _selectedTxId = place.id;
      });

      // Boost priority of the tapped marker
      await _updateAnnotationPriority();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _popupKey.currentState?.show();
      });
    }
  }

  void _onMarkerLongPressed(String annotationId, mp.Point geometry) async {
    final place = _annotationToPlaceMap[annotationId];
    if (place == null) return;

    HapticFeedback.heavyImpact();

    // For grouped messages, we use the first one for the picker initial state
    final tx = place.transactions.first;

    if (mounted) {
      // Close any open popups first
      if (_selectedPlace != null) {
        setState(() {
          _selectedPlace = null;
          _popupPosition = null;
        });
      }

      Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute(
          builder: (context) => LocationPickerScreen(transactions: [tx]),
        ),
      );
    }
  }

  void _refreshAnnotations() async {
    if (_annotationManager == null) return;

    final spending = context.read<SpendingService>();

    // If spending service is loading, ensure we show our local indicator
    if (spending.isLoading) {
      if (!_isMapUpdating) {
        setState(() => _isMapUpdating = true);
      }
      return;
    }

    // Start local update phase
    if (!_isMapUpdating) {
      setState(() => _isMapUpdating = true);
    }

    // Versioning prevents rapid consecutive refreshes from
    // clobbering each other (race conditions).
    final int currentVersion = ++_annotationUpdateVersion;

    final saved = spending.mappedTransactions
        .where((tx) => _isToday(tx.timestamp))
        .toList();
    final newPlaces = _groupTransactions(saved);

    // If a newer refresh has started, abort this outdated one.
    if (currentVersion != _annotationUpdateVersion || !mounted) return;

    await _addAllAnnotations(newPlaces);

    // Finalize update phase
    if (currentVersion == _annotationUpdateVersion && mounted) {
      setState(() => _isMapUpdating = false);
    }
  }

  Future<void> _addAllAnnotations(List<MapPlace> places) async {
    if (_annotationManager == null || _dotManager == null) return;
    final spending = context.read<SpendingService>();

    // Generate callout options and dot options in parallel
    final List<Future<(mp.PointAnnotationOptions, mp.CircleAnnotationOptions)>>
    futures = places.map((place) async {
      final catColor = spending.getCategoryColor(place.category ?? '');
      final CalloutResult callout = await createCalloutImage(
        place.name,
        place.displayPrice,
        color: catColor,
      );

      final geometry = mp.Point(
        coordinates: mp.Position(place.longitude, place.latitude),
      );
      final sortKey = _getSortKey(place);

      final pointOptions = mp.PointAnnotationOptions(
        image: callout.image,
        iconSize: 1.5,
        iconAnchor: mp.IconAnchor.CENTER,
        iconOffset: [0.0, 0.0],
        symbolSortKey: sortKey,
        geometry: geometry,
      );

      final circleOptions = mp.CircleAnnotationOptions(
        geometry: geometry,
        circleColor: catColor.toARGB32(),
        circleRadius: 1.575,
        circleStrokeWidth: 1.0,
        circleStrokeColor: CupertinoColors.white.toARGB32(),
        circleSortKey: sortKey,
      );

      return (pointOptions, circleOptions);
    }).toList();

    final List<(mp.PointAnnotationOptions, mp.CircleAnnotationOptions)>
    results = await Future.wait(futures);

    final pointOptionsList = results.map((r) => r.$1).toList();
    final circleOptionsList = results.map((r) => r.$2).toList();

    // Perform instantaneous swap on both layers
    await _annotationManager?.deleteAll();
    await _dotManager?.deleteAll();
    _annotationToPlaceMap.clear();

    final pointAnnotations = await _annotationManager?.createMulti(
      pointOptionsList,
    );
    final circleAnnotations = await _dotManager?.createMulti(circleOptionsList);

    if (pointAnnotations != null) {
      for (int i = 0; i < pointAnnotations.length; i++) {
        final ann = pointAnnotations[i];
        if (ann != null) {
          _annotationToPlaceMap[ann.id] = places[i];
        }
      }
    }
    if (circleAnnotations != null) {
      for (int i = 0; i < circleAnnotations.length; i++) {
        final ann = circleAnnotations[i];
        if (ann != null) {
          _annotationToPlaceMap[ann.id] = places[i];
        }
      }
    }
  }

  // Timeline

  void _flyToAndShowPopup(AppTransaction tx) async {
    MapPlace? targetPlace;

    // Check if it's already in our grouped today's places
    for (final place in _places) {
      if (place.transactions.any((t) => t.id == tx.id)) {
        targetPlace = place;
        break;
      }
    }

    // If not found (e.g. from another day), create a temporary place for navigation
    if (targetPlace == null && tx.latitude != null && tx.longitude != null) {
      targetPlace = MapPlace(
        name: tx.merchant,
        latitude: tx.latitude!,
        longitude: tx.longitude!,
        transactions: [tx],
      );
    }

    if (targetPlace == null) return;

    // First, clear everything to ensure the previous popup is removed
    setState(() {
      _isPopupActive = false;
      _selectedPlace = null;
      _popupPosition = null;
    });

    // Brief delay to allow the UI to clear the old popup
    await Future.delayed(Duration.zero);

    final screenHeight = MediaQuery.of(context).size.height;
    // Set padding to position the target point 1/3 from the top of the visible map (top 65%)
    // This moves the "center" of the map higher up so the popup isn't blocked by the modal.
    final bottomPadding = screenHeight * 0.55;

    await mapboxMapController?.flyTo(
      mp.CameraOptions(
        zoom: 17,
        center: mp.Point(
          coordinates: mp.Position(targetPlace.longitude, targetPlace.latitude),
        ),
        padding: mp.MbxEdgeInsets(
          top: 0.0,
          left: 0.0,
          bottom: bottomPadding,
          right: 0.0,
        ),
      ),
      mp.MapAnimationOptions(duration: 400),
    );

    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    final screenCoord = await mapboxMapController?.pixelForCoordinate(
      mp.Point(
        coordinates: mp.Position(targetPlace.longitude, targetPlace.latitude),
      ),
    );

    if (screenCoord != null && mounted) {
      setState(() {
        _isPopupActive = true;
        _selectedPlace = targetPlace;
        _popupPosition = screenCoord;
        _selectedTxId = tx.id;
      });
      await _updateAnnotationPriority();
      // Ensure the popup shows for the NEW selection
      _popupKey.currentState?.show();
    }
  }

  void _handleTopItemChanged(AppTransaction? tx) {
    if (tx == null) {
      if (mounted) {
        setState(() {
          _isPopupActive = false;
          _selectedPlace = null;
          _popupPosition = null;
        });
      }
      return;
    }
    _flyToAndShowPopup(tx);
  }

  static bool _hasCheckedHotspotNotification = false;

  Future<void> _showHotspotDataNotification() async {
    if (_hasCheckedHotspotNotification) return;
    _hasCheckedHotspotNotification = true;

    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool('hotspot_notification_shown') ?? false;

    if (!hasShown) {
      await prefs.setBool('hotspot_notification_shown', true);
      if (!mounted) return;
      showCustomToast(
        'GeoCent will start identifying your spending patterns after a few more transactions.',
      );
    }
  }

  double _getSortKey(MapPlace place) {
    if (place.id == _selectedTxId) return -1000000.0;
    // For grouped markers, use a large priority so they stay visible
    if (place.transactions.length > 1) return -500000.0;

    final clean = place.transactions.first.formattedAmount.replaceAll(
      RegExp(r'[^0-9.]'),
      '',
    );
    return double.tryParse(clean) ?? 0.0;
  }
}

class _HeatmapExploreSheet extends StatefulWidget {
  final List<AppTransaction> transactions;
  final Function(AppTransaction?) onTopItemChanged;

  const _HeatmapExploreSheet({
    required this.transactions,
    required this.onTopItemChanged,
  });

  @override
  State<_HeatmapExploreSheet> createState() => _HeatmapExploreSheetState();
}

class _HeatmapExploreSheetState extends State<_HeatmapExploreSheet> {
  late ScrollController _scrollController;
  int _lastTopIndex = -1;
  Timer? _debounceTimer;
  String _currentTitle = 'Explore Mapped Messages';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (widget.transactions.isEmpty) return;

    final offset = _scrollController.offset;
    final index = (offset / 72.0).floor().clamp(
      0,
      widget.transactions.length - 1,
    );

    // Update map popup
    if (index != _lastTopIndex) {
      _lastTopIndex = index;
      _debounceTimer?.cancel();

      // Trigger callback to close current message before showing next
      widget.onTopItemChanged(null);

      _debounceTimer = Timer(const Duration(milliseconds: 350), () {
        if (mounted) {
          widget.onTopItemChanged(widget.transactions[index]);
        }
      });
    }

    // Update title:
    // If we haven't scrolled past the first potential header, show default title.
    // Otherwise, show the date of the current top item.
    final String newTitle;
    if (offset < 40) {
      newTitle = 'Explore Mapped Messages';
    } else {
      final date = widget.transactions[index].timestamp;
      newTitle = DateFormat('d MMMM y').format(date);
    }

    if (newTitle != _currentTitle) {
      setState(() {
        _currentTitle = newTitle;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.35,
      decoration: const BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey4,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, 0.2),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                    child: Text(
                      _currentTitle,
                      key: ValueKey<String>(_currentTitle),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.clear,
                      size: 18,
                      color: CupertinoColors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: GroupedTransactionsList(
                    transactions: widget.transactions,
                    onTransactionTap: (tx) {
                      widget.onTopItemChanged(tx);
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

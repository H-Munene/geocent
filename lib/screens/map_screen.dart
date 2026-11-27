import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:maplibre_gl/maplibre_gl.dart';
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
import '../utils/map_styles.dart';
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
  // Map layer ids. Dots sit below callouts; the heatmap sits below dots.
  static const String _placesSource = 'places-source';
  static const String _dotsLayer = 'places-dots';
  static const String _calloutsLayer = 'places-callouts';
  static const String _hotspotsSource = 'hotspots-source';
  static const String _heatmapLayer = 'hotspots-heatmap';

  MapLibreMapController? _mapController;
  bool _styleReady = false;
  bool _heatmapAdded = false;
  bool _myLocationEnabled = false;
  final Set<String> _addedImages = {};
  List<MapPlace> _renderedPlaces = [];
  final Map<String, MapPlace> _annotationToPlaceMap = {};
  final bool _isAnimating = false;
  List<MapPlace> _places = [];
  StreamSubscription? userPositionStream;
  StreamSubscription? _bgServiceSub;
  gl.Position? _lastGeofenceRegistrationPoint;
  final GeofenceService _geofenceService = GeofenceService();

  int _annotationUpdateVersion = 0;
  String _currentMapStyle = MapStyles.standard;
  bool _isMapUpdating = false;

  final GlobalKey<MapSearchHeaderState> _headerKey = GlobalKey();

  String? _selectedCategory;
  String? _selectedTxId;

  final GlobalKey<CustomPopupState> _popupKey = GlobalKey<CustomPopupState>();
  Offset? _popupPosition;
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
    _mapController?.onFeatureTapped.remove(_onFeatureTapped);
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
    final savedStyle = MapStyles.normalize(prefs.getString('map_style'));
    // Changing styleString reloads the style; _onStyleLoaded re-adds layers.
    if (mounted && savedStyle != _currentMapStyle) {
      setState(() {
        _currentMapStyle = savedStyle;
        _styleReady = false;
      });
    }
  }

  Future<void> _saveMapStyle(String styleUri) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('map_style', styleUri);
  }

  /// Animates the camera to [lat]/[lng]. [bottomPadding] (logical px) shifts
  /// the target up so it sits in the visible area above a bottom sheet.
  Future<void> _flyTo(
    double lat,
    double lng, {
    double zoom = 17,
    int durationMs = 1000,
    double bottomPadding = 0,
  }) async {
    final controller = _mapController;
    if (controller == null) return;
    double targetLat = lat;
    if (bottomPadding > 0) {
      // MapLibre uses 512px tiles: metres per logical pixel at this zoom.
      final metersPerPixel =
          78271.517 * math.cos(lat * math.pi / 180) / math.pow(2, zoom);
      targetLat = lat - (bottomPadding / 2 * metersPerPixel) / 111320.0;
    }
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(targetLat, lng), zoom: zoom),
      ),
      duration: Duration(milliseconds: durationMs),
    );
  }

  Future<Offset?> _screenPointFor(double lat, double lng) async {
    final controller = _mapController;
    if (controller == null) return null;
    final p = await controller.toScreenLocation(LatLng(lat, lng));
    return Offset(p.x.toDouble(), p.y.toDouble());
  }

  void _handleSelectedTransaction() async {
    final spending = context.read<SpendingService>();
    final txId = spending.selectedTxId;
    if (txId == null || _mapController == null) return;

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
    await _flyTo(place.latitude, place.longitude);

    // Wait for camera animation to finish
    await Future.delayed(const Duration(milliseconds: 1100));

    if (!mounted) return;

    final screenCoord = await _screenPointFor(place.latitude, place.longitude);

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
    if (_selectedTxId == null) return;
    // Sort keys live in the GeoJSON, so re-push it with the new selection.
    await _pushPlacesGeoJson();
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
          MapLibreMap(
            styleString: _currentMapStyle,
            initialCameraPosition: const CameraPosition(
              target: LatLng(-1.2864, 36.8172), // Nairobi until GPS resolves
              zoom: 12,
            ),
            minMaxZoomPreference: const MinMaxZoomPreference(3.0, 19.73),
            onMapCreated: onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            onMapLongClick: _onMapLongClick,
            myLocationEnabled: _myLocationEnabled,
            myLocationRenderMode: MyLocationRenderMode.normal,
            compassEnabled: true,
            compassViewPosition: CompassViewPosition.bottomRight,
            compassViewMargins: const math.Point(16, 210),
            attributionButtonPosition: AttributionButtonPosition.bottomLeft,
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
              left: _popupPosition!.dx,
              top: _popupPosition!.dy,
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
        await _flyTo(lastPos.latitude, lastPos.longitude, durationMs: 800);
      }

      final position = await gl.Geolocator.getCurrentPosition(
        locationSettings: const gl.LocationSettings(
          accuracy: gl.LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      _checkGeofenceRegistration(position);
      await _flyTo(position.latitude, position.longitude);
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
            if (_mapController != null && !_isAnimating) {
              _mapController?.moveCamera(
                CameraUpdate.newLatLngZoom(
                  LatLng(position.latitude, position.longitude),
                  17,
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
          // Reloading the style drops our layers; _onStyleLoaded re-adds them.
          setState(() {
            _currentMapStyle = newStyle;
            _styleReady = false;
          });
          await _saveMapStyle(newStyle);
        },
      ),
    );
  }

  // Map

  Future<void> onMapCreated(MapLibreMapController controller) async {
    setState(() => _mapController = controller);
    controller.onFeatureTapped.add(_onFeatureTapped);

    final locationPermission = await Permission.location.status;
    if (locationPermission == PermissionStatus.granted) {
      if (mounted) setState(() => _myLocationEnabled = true);

      // Center map on user's last known position immediately
      try {
        final lastPos = await gl.Geolocator.getLastKnownPosition();
        if (lastPos != null && mounted) {
          await controller.moveCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(lastPos.latitude, lastPos.longitude),
              17,
            ),
          );
        }
        // Trigger a fresh location fetch for high accuracy
        gl.Geolocator.getCurrentPosition(
          locationSettings: const gl.LocationSettings(
            accuracy: gl.LocationAccuracy.high,
          ),
        ).then((pos) {
          if (mounted) _flyTo(pos.latitude, pos.longitude);
        });
      } catch (e) {
        debugPrint('[MapScreen] Initial location fetch failed: $e');
      }
    }

    if (!mounted) return;
    final spending = context.read<SpendingService>();
    _smsService = SmsService(repo: TransactionRepository(), spending: spending);
    await _smsService!.init();

    spending.addListener(_refreshAnnotations);
    spending.addListener(_refreshHotspots);
  }

  /// Runs on first load and after every style switch: a new style starts
  /// with no custom images, sources or layers.
  Future<void> _onStyleLoaded() async {
    final controller = _mapController;
    if (controller == null) return;
    _addedImages.clear();
    _heatmapAdded = false;

    try {
      await controller.addGeoJsonSource(_placesSource, _emptyCollection);

      // Dots: hidden below zoom 9. They stay visible under callouts, so they
      // act as a fallback when a callout is hidden by collision.
      await controller.addCircleLayer(
        _placesSource,
        _dotsLayer,
        CircleLayerProperties(
          circleColor: ['get', 'color'],
          circleRadius: 1.575,
          circleStrokeWidth: 1.0,
          circleStrokeColor: '#FFFFFF',
          circleSortKey: ['get', 'sortKey'],
          circleOpacity: _stepAt(9.0),
          circleStrokeOpacity: _stepAt(9.0),
        ),
      );

      // Callouts: visible from zoom 11. Overlap is off so MapLibre's
      // collision engine hides overlapping callouts; lower sortKey wins.
      await controller.addSymbolLayer(
        _placesSource,
        _calloutsLayer,
        SymbolLayerProperties(
          iconImage: ['get', 'icon'],
          iconSize: 1.5,
          iconAnchor: 'center',
          iconAllowOverlap: false,
          iconIgnorePlacement: false,
          symbolSortKey: ['get', 'sortKey'],
          iconOpacity: _stepAt(11.0),
        ),
      );
    } catch (e) {
      debugPrint('[MapScreen] Failed to add place layers: $e');
      return;
    }

    _styleReady = true;
    _refreshAnnotations();
    _refreshHotspots();
  }

  static const Map<String, dynamic> _emptyCollection = {
    'type': 'FeatureCollection',
    'features': [],
  };

  /// Opacity 0 below [zoom], 1 at or above it.
  static List<Object> _stepAt(double zoom) => [
    'step',
    ['zoom'],
    0.0,
    zoom,
    1.0,
  ];

  Future<void> _refreshHotspots() async {
    final controller = _mapController;
    if (controller == null || !_styleReady) return;
    if (!mounted) return;

    final spending = context.read<SpendingService>();
    final transactions = spending.mappedTransactions;

    if (!spending.isHotspotDataSufficient) {
      _showHotspotDataNotification();
    }

    // Use try-catch to avoid breaking the UI if style operations fail
    try {
      if (transactions.isEmpty) {
        if (_heatmapAdded) {
          await controller.removeLayer(_heatmapLayer);
          await controller.removeSource(_hotspotsSource);
          _heatmapAdded = false;
        }
        return;
      }

      final now = DateTime.now();
      final geojson = <String, dynamic>{
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

      if (_heatmapAdded) {
        await controller.setGeoJsonSource(_hotspotsSource, geojson);
        return;
      }

      await controller.addGeoJsonSource(_hotspotsSource, geojson);

      // Heatmap styling: zoomed out, large radii fuse nearby transactions
      // into warm blobs; zoomed in, they fragment into individual dots.
      // Radius is inverted (large when zoomed out). Warm colours only.
      await controller.addHeatmapLayer(
        _hotspotsSource,
        _heatmapLayer,
        const HeatmapLayerProperties(
          // Low at country scale to prevent blob fusion, higher at street level.
          heatmapIntensity: [
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
          // Transparent -> amber -> orange -> red -> darkest red core.
          heatmapColor: [
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
          heatmapRadius: [
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
          // Recent/high-value transactions weigh more; floor 0.15 so small
          // ones still glow.
          heatmapWeight: [
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
          heatmapOpacity: [
            'interpolate',
            ['linear'],
            ['zoom'],
            15,
            0.85,
            17,
            0.75,
          ],
        ),
        belowLayerId: _dotsLayer,
      );
      _heatmapAdded = true;
    } catch (e) {
      debugPrint('[MapScreen] Failed to refresh hotspots: $e');
    }
  }

  void _onFeatureTapped(
    math.Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (layerId != _dotsLayer && layerId != _calloutsLayer) return;
    _onMarkerTapped(id);
  }

  /// MapLibre has no per-feature long-press callback, so look up what is
  /// rendered under the finger.
  Future<void> _onMapLongClick(math.Point<double> point, LatLng _) async {
    final controller = _mapController;
    if (controller == null || !_styleReady) return;
    final features = await controller.queryRenderedFeatures(point, [
      _calloutsLayer,
      _dotsLayer,
    ], null);
    if (features.isEmpty) return;
    final dynamic first = features.first;
    final Map feature = first is String ? jsonDecode(first) : first as Map;
    final key = (feature['properties'] as Map?)?['key'] ?? feature['id'];
    if (key != null) _onMarkerLongPressed(key.toString());
  }

  void _onMarkerTapped(String annotationId) async {
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

    final screenCoord = await _screenPointFor(place.latitude, place.longitude);

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

  void _onMarkerLongPressed(String annotationId) async {
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
    if (_mapController == null || !_styleReady) return;

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
    final controller = _mapController;
    if (controller == null || !_styleReady) return;
    final spending = context.read<SpendingService>();

    // Render any callout images this style hasn't seen yet. Images are keyed
    // by their content so unchanged callouts are reused across refreshes.
    await Future.wait(
      places.map((place) async {
        final name = _calloutImageName(place, spending);
        if (_addedImages.contains(name)) return;
        _addedImages.add(name);
        final CalloutResult callout = await createCalloutImage(
          place.name,
          place.displayPrice,
          color: spending.getCategoryColor(place.category ?? ''),
        );
        await controller.addImage(name, callout.image);
      }),
    );

    _renderedPlaces = places;
    await _pushPlacesGeoJson();
  }

  String _calloutImageName(MapPlace place, SpendingService spending) {
    final color = spending.getCategoryColor(place.category ?? '').toARGB32();
    return 'callout-${Object.hash(place.name, place.displayPrice, color)}';
  }

  /// Writes [_renderedPlaces] to the places source (one feature per place).
  /// Feature ids are list indexes, which [_annotationToPlaceMap] maps back.
  Future<void> _pushPlacesGeoJson() async {
    final controller = _mapController;
    if (controller == null || !_styleReady || !mounted) return;
    final spending = context.read<SpendingService>();

    _annotationToPlaceMap.clear();
    final features = <Map<String, dynamic>>[];
    for (int i = 0; i < _renderedPlaces.length; i++) {
      final place = _renderedPlaces[i];
      final key = '$i';
      _annotationToPlaceMap[key] = place;
      final rgb =
          spending.getCategoryColor(place.category ?? '').toARGB32() & 0xFFFFFF;
      features.add({
        'type': 'Feature',
        'id': i,
        'properties': {
          'key': key,
          'icon': _calloutImageName(place, spending),
          'color': '#${rgb.toRadixString(16).padLeft(6, '0')}',
          'sortKey': _getSortKey(place),
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [place.longitude, place.latitude],
        },
      });
    }

    try {
      await controller.setGeoJsonSource(_placesSource, {
        'type': 'FeatureCollection',
        'features': features,
      });
    } catch (e) {
      debugPrint('[MapScreen] Failed to update places: $e');
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

    await _flyTo(
      targetPlace.latitude,
      targetPlace.longitude,
      durationMs: 400,
      bottomPadding: bottomPadding,
    );

    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    final screenCoord = await _screenPointFor(
      targetPlace.latitude,
      targetPlace.longitude,
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

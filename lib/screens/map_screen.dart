import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:flutter_popup/flutter_popup.dart';

import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/call_out_result.dart';
import '../models/map_place.dart';
import '../repositories/transaction_repository.dart';
import '../services/sms_service.dart';
import '../services/spending_service.dart';
import '../utils/marker_utils.dart';
import '../widgets/dynamic_island.dart';
import '../widgets/category_dropdown_widget.dart';
import '../widgets/map_style_picker_modal.dart';
import 'location_picker_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  bool _islandExpanded = false;
  bool _amountsVisible = false;
  late AnimationController _bounceController;
  late Animation<double> _bounceScale;

  mp.PointAnnotationManager? _annotationManager;
  mp.CircleAnnotationManager? _dotManager;
  final Map<String, MapPlace> _annotationToPlaceMap = {};
  bool _isAnimating = false;
  List<MapPlace> _places = [];
  mp.MapboxMap? mapboxMapController;
  StreamSubscription? userPositionStream;
  StreamSubscription? _bgServiceSub;

  int _annotationUpdateVersion = 0;
  String _currentMapStyle = mp.MapboxStyles.STANDARD;
  bool _isMapUpdating = false;

  final GlobalKey<CustomPopupState> _popupKey = GlobalKey<CustomPopupState>();
  mp.ScreenCoordinate? _popupPosition;
  MapPlace? _selectedPlace;

  // Initialised once onMapCreated fires
  SmsService? _smsService;

  @override
  void initState() {
    super.initState();
    _positionTracking();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.95,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.95,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 70,
      ),
    ]).animate(_bounceController);

    // Listen for background service events to trigger Dynamic Island
    _bgServiceSub = FlutterBackgroundService().on('transaction_saved').listen((
      _,
    ) {
      _triggerIslandAutoExpand();
      if (mounted) {
        context.read<SpendingService>().refresh();
      }
    });

    FlutterBackgroundService().on('location_attached').listen((_) {
      if (mounted) {
        context.read<SpendingService>().refresh();
      }
    });

    // Add listener for selected transaction from Messages screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SpendingService>().addListener(_handleSelectedTransaction);
    });
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
      id: tx.id,
      name: tx.merchant,
      price: tx.formattedAmount,
      latitude: tx.latitude!,
      longitude: tx.longitude!,
      rawMessage: tx.rawMessage,
      category: tx.category,
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
      });

      // Clear the selection so it doesn't trigger again on every rebuild
      spending.clearSelectedTransaction();

      // Show popup in next frame after Positioned has moved the anchor
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _popupKey.currentState?.show();
      });
    }
  }

  void _triggerIslandAutoExpand() {
    if (!mounted) return;
    setState(() {
      _amountsVisible = true;
      _islandExpanded = true;
    });

    // Fold back up after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _amountsVisible = false;
          _islandExpanded = false;
        });
        _bounceController.forward(from: 0.0);
      }
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    userPositionStream?.cancel();
    _bgServiceSub?.cancel();
    mapboxMapController?.dispose();
    _smsService?.dispose();

    // Remove listener to prevent memory leaks
    final spending = Provider.of<SpendingService>(context, listen: false);
    spending.removeListener(_refreshAnnotations);
    spending.removeListener(_handleSelectedTransaction);

    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 12;
    final spending = context.watch<SpendingService>();

    // Sync places with spending service mapped transactions
    final saved = spending.mappedTransactions;
    _places = saved
        .map(
          (tx) => MapPlace(
            id: tx.id,
            name: tx.merchant,
            price: tx.formattedAmount,
            latitude: tx.latitude!,
            longitude: tx.longitude!,
            rawMessage: tx.rawMessage,
            category: tx.category,
          ),
        )
        .toList();

    return CupertinoPageScaffold(
      child: Stack(
        children: [
          mp.MapWidget(styleUri: _currentMapStyle, onMapCreated: onMapCreated),
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
            child: DynamicIsland(
              spent: spending.spent,
              limit: spending.limit,
              amountsVisible: _amountsVisible,
              islandExpanded: _islandExpanded,
              selectedPeriod: spending.period,
              bounceScale: _bounceScale,
              onTapCircle: () {
                setState(() => _amountsVisible = true);
                _bounceController.value = 0.0;
              },
              onTapClose: () {
                setState(() {
                  _amountsVisible = false;
                  _islandExpanded = false;
                });
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) _bounceController.forward(from: 0.0);
                });
              },
              onToggleExpand: () =>
                  setState(() => _islandExpanded = !_islandExpanded),
              onTapEditLimit: () => _showLimitSettings(spending),
              onPeriodSelected: (period) =>
                  context.read<SpendingService>().setPeriod(period),
            ),
          ),
          // FABs moved into the stack as Positioned widgets
          Positioned(
            bottom: 32,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    _showMapStylePicker();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: CupertinoColors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      CupertinoIcons.square_stack_3d_up,
                      color: Color(0xFF1D1D1F),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    _flyToUserLocation();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: CupertinoColors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      CupertinoIcons.location_fill,
                      color: Color(0xFF1D1D1F),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_places.isNotEmpty)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _isAnimating
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            _animateAnnotations();
                          },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isAnimating
                            ? CupertinoColors.systemGrey3
                            : const Color(0xFF1D1D1F),
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _isAnimating
                          ? const CupertinoActivityIndicator(
                              color: CupertinoColors.white,
                            )
                          : const Icon(
                              CupertinoIcons.play_fill,
                              color: CupertinoColors.white,
                            ),
                    ),
                  ),
              ],
            ),
          ),
          if (_popupPosition != null)
            Positioned(
              left: _popupPosition!.x,
              top: _popupPosition!.y,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: CustomPopup(
                    key: _popupKey,
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                    contentPadding: EdgeInsets.zero,
                    content: DefaultTextStyle(
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.black,
                        decoration: TextDecoration.none,
                      ),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 300),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final cat = context
                                    .read<SpendingService>()
                                    .getCategoryByName(
                                      _selectedPlace?.category,
                                    );
                                return CustomPopup(
                                  barrierColor: CupertinoColors.transparent,
                                  contentPadding: EdgeInsets.zero,
                                  content: CategoryDropdownWidget(
                                    transactionId: _selectedPlace!.id,
                                    currentCategory: _selectedPlace!.category,
                                    onCategorySelected: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.popUntil(
                                        context,
                                        (route) => route.isFirst,
                                      );
                                    },
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cat == null
                                          ? CupertinoColors.systemGrey5
                                          : cat.color.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (cat != null) ...[
                                          HugeIcon(
                                            icon: cat.icon,
                                            color: cat.color,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Text(
                                          _selectedPlace?.category ??
                                              'Set Category',
                                          style: GoogleFonts.spaceGrotesk(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: cat == null
                                                ? CupertinoColors.systemGrey
                                                : cat.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 1,
                              color: Colors.black.withValues(alpha: 0.1),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedPlace?.rawMessage ?? '',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 14,
                                height: 1.5,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    child: const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _flyToUserLocation() async {
    try {
      final position = await gl.Geolocator.getCurrentPosition(
        locationSettings: const gl.LocationSettings(
          accuracy: gl.LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      await mapboxMapController?.flyTo(
        mp.CameraOptions(
          zoom: 17,
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

  // ── Location tracking ──────────────────────────────────────────────────────

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
          if (position != null &&
              mapboxMapController != null &&
              !_isAnimating) {
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
          await mapboxMapController?.loadStyleURI(newStyle);
          // Wait for style to load before re-applying layer properties
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _applyStyleLayerExpressions();
              _refreshAnnotations();
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
          13.0,
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
          13.0,
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
          11.0,
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
          11.0,
          1.0,
        ],
      );
    }
  }

  // ── Map ────────────────────────────────────────────────────────────────────

  Future<void> onMapCreated(mp.MapboxMap controller) async {
    setState(() => mapboxMapController = controller);

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

    mapboxMapController?.location.updateSettings(
      mp.LocationComponentSettings(enabled: true, pulsingEnabled: false),
    );

    // 1. Initialize Managers
    // Important: Initialize _dotManager FIRST so it renders BELOW the _annotationManager.
    _dotManager = await mapboxMapController?.annotations
        .createCircleAnnotationManager();
    _annotationManager = await mapboxMapController?.annotations
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
    _refreshAnnotations();
  }

  void _onMarkerTapped(String annotationId, mp.Point geometry) async {
    final place = _annotationToPlaceMap[annotationId];
    if (place == null) return;

    final screenCoord = await mapboxMapController?.pixelForCoordinate(geometry);

    if (screenCoord != null && mounted) {
      setState(() {
        _selectedPlace = place;
        _popupPosition = screenCoord;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _popupKey.currentState?.show();
      });
    }
  }

  void _onMarkerLongPressed(String annotationId, mp.Point geometry) async {
    final place = _annotationToPlaceMap[annotationId];
    if (place == null) return;

    HapticFeedback.heavyImpact();
    final spending = context.read<SpendingService>();
    final allTxs = [
      ...spending.mappedTransactions,
      ...spending.periodTransactions,
    ];
    final txIndex = allTxs.indexWhere((t) => t.id == place.id);

    if (txIndex != -1 && mounted) {
      // Close any open popups first
      if (_selectedPlace != null) {
        setState(() {
          _selectedPlace = null;
          _popupPosition = null;
        });
      }

      Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute(
          builder: (context) =>
              LocationPickerScreen(transaction: allTxs[txIndex]),
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

    final saved = spending.mappedTransactions;

    final newPlaces = saved
        .map(
          (tx) => MapPlace(
            id: tx.id,
            name: tx.merchant,
            price: tx.formattedAmount,
            latitude: tx.latitude!,
            longitude: tx.longitude!,
            rawMessage: tx.rawMessage,
            category: tx.category,
          ),
        )
        .toList();

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
      final cat = spending.getCategoryByName(place.category);
      final CalloutResult callout = await createCalloutImage(
        place.name,
        place.price,
        color: cat?.color,
      );

      final geometry = mp.Point(
        coordinates: mp.Position(place.longitude, place.latitude),
      );
      final sortKey = _getSortKey(place.price);

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
        circleColor:
            cat?.color.toARGB32() ?? const Color(0xFF0071E3).toARGB32(),
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

  // ── Animate FAB ────────────────────────────────────────────────────────────

  Future<void> _animateAnnotations() async {
    if (_isAnimating) return;
    setState(() => _isAnimating = true);
    await _annotationManager?.deleteAll();
    await _dotManager?.deleteAll();
    _annotationToPlaceMap.clear();

    for (final place in _places) {
      if (!_isAnimating) break;
      await _addAnnotationForPlace(place);
      await Future.delayed(const Duration(seconds: 1));
    }
    setState(() => _isAnimating = false);
  }

  Future<void> _addAnnotationForPlace(MapPlace place) async {
    await mapboxMapController?.flyTo(
      mp.CameraOptions(
        zoom: 13.5, // Fly in closer to reveal the callout immediately
        center: mp.Point(
          coordinates: mp.Position(place.longitude, place.latitude),
        ),
      ),
      mp.MapAnimationOptions(duration: 1000),
    );

    if (!mounted) return;
    final spending = context.read<SpendingService>();
    final cat = spending.getCategoryByName(place.category);
    final CalloutResult callout = await createCalloutImage(
      place.name,
      place.price,
      color: cat?.color,
    );

    final geometry = mp.Point(
      coordinates: mp.Position(place.longitude, place.latitude),
    );
    final sortKey = _getSortKey(place.price);

    final pointAnn = await _annotationManager?.create(
      mp.PointAnnotationOptions(
        image: callout.image,
        iconSize: 1.5,
        iconAnchor: mp.IconAnchor.CENTER,
        iconOffset: [0.0, 0.0],
        symbolSortKey: sortKey,
        geometry: geometry,
      ),
    );

    final circleAnn = await _dotManager?.create(
      mp.CircleAnnotationOptions(
        geometry: geometry,
        circleColor:
            cat?.color.toARGB32() ?? CupertinoColors.systemGrey.toARGB32(),
        circleRadius: 1.575,
        circleStrokeWidth: 1.0,
        circleStrokeColor: CupertinoColors.white.toARGB32(),
        circleSortKey: sortKey,
      ),
    );

    if (pointAnn != null) {
      _annotationToPlaceMap[pointAnn.id] = place;
    }
    if (circleAnn != null) {
      _annotationToPlaceMap[circleAnn.id] = place;
    }
  }

  double _getSortKey(String price) {
    final clean = price.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  void _showLimitSettings(SpendingService spending) {
    final controller = TextEditingController(
      text: spending.limit.toStringAsFixed(0),
    );
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Set ${spending.period} Limit'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: CupertinoTextField(
            controller: controller,
            keyboardType: TextInputType.number,
            prefix: const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Text('Ksh '),
            ),
            placeholder: 'Limit Amount',
            style: GoogleFonts.spaceGrotesk(),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final amount = double.tryParse(controller.text) ?? 0.0;
              spending.setLimit(spending.period, amount);
              Navigator.pop(context);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }
}

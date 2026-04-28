import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../models/call_out_result.dart';
import '../models/map_place.dart';
import '../repositories/transaction_repository.dart';
import '../services/sms_service.dart';
import '../services/spending_service.dart';
import '../utils/marker_utils.dart';
import '../widgets/dynamic_island.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  bool _islandExpanded = false;
  bool _amountsVisible = false;
  late AnimationController _bounceController;
  late Animation<double> _bounceScale;

  mp.PointAnnotationManager? _annotationManager;
  bool _isAnimating = false;
  List<MapPlace> _places = [];
  mp.MapboxMap? mapboxMapController;
  StreamSubscription? userPositionStream;
  StreamSubscription? _bgServiceSub;

  int _annotationUpdateVersion = 0;

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
          end: 0.98,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.98,
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
            name: tx.merchant,
            price: tx.formattedAmount,
            latitude: tx.latitude!,
            longitude: tx.longitude!,
            rawMessage: tx.rawMessage,
          ),
        )
        .toList();

    return Scaffold(
      body: Stack(
        children: [
          mp.MapWidget(
            styleUri: mp.MapboxStyles.LIGHT,
            onMapCreated: onMapCreated,
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
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'user_location',
            onPressed: _flyToUserLocation,
            backgroundColor: Colors.white,
            child: const Icon(Icons.my_location, color: Colors.black),
          ),
          const SizedBox(height: 12),
          if (_places.isNotEmpty)
            FloatingActionButton(
              heroTag: 'animate',
              onPressed: _isAnimating ? null : _animateAnnotations,
              backgroundColor: _isAnimating ? Colors.grey : Colors.black,
              child: _isAnimating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Icon(Icons.play_arrow, color: Colors.white),
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
      await mapboxMapController?.flyTo(
        mp.CameraOptions(
          zoom: 14,
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
                zoom: 13,
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

  // ── Map ────────────────────────────────────────────────────────────────────

  Future<void> onMapCreated(mp.MapboxMap controller) async {
    setState(() => mapboxMapController = controller);

    final locationPermission = await Permission.location.status;
    if (locationPermission != PermissionStatus.granted) return;

    mapboxMapController?.location.updateSettings(
      mp.LocationComponentSettings(enabled: true, pulsingEnabled: false),
    );

    _annotationManager = await mapboxMapController?.annotations
        .createPointAnnotationManager();

    // Handle marker taps using modern API
    _annotationManager?.tapEvents(
      onTap: (annotation) {
        final place = _places.firstWhere(
          (p) =>
              (p.longitude - annotation.geometry.coordinates.lng).abs() <
                  0.0001 &&
              (p.latitude - annotation.geometry.coordinates.lat).abs() < 0.0001,
          orElse: () => _places.first,
        );
        _showTransactionDetails(place);
      },
    );

    if (!mounted) return;
    final spending = context.read<SpendingService>();
    _smsService = SmsService(repo: TransactionRepository(), spending: spending);
    await _smsService!.init();

    // The build method will handle syncing _places and rendering annotations
    // via its reactivity to SpendingService.
    // However, we need to trigger the first set of annotations manually
    // or rely on the build method's reactivity if we wrap annotation creation.
    // Let's add a listener to spending service to refresh annotations.
    spending.addListener(_refreshAnnotations);
    _refreshAnnotations();
  }

  void _refreshAnnotations() async {
    if (_annotationManager == null) return;

    // Versioning prevents rapid consecutive refreshes from
    // clobbering each other (race conditions).
    final int currentVersion = ++_annotationUpdateVersion;

    final spending = context.read<SpendingService>();
    final saved = spending.mappedTransactions;

    final newPlaces = saved
        .map(
          (tx) => MapPlace(
            name: tx.merchant,
            price: tx.formattedAmount,
            latitude: tx.latitude!,
            longitude: tx.longitude!,
            rawMessage: tx.rawMessage,
          ),
        )
        .toList();

    await _annotationManager?.deleteAll();

    // If a newer refresh has started, abort this outdated one.
    if (currentVersion != _annotationUpdateVersion || !mounted) return;

    await _addAllAnnotations(newPlaces);
  }

  void _showTransactionDetails(MapPlace place) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    place.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Text(
                  place.price,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE53935),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'TRANSACTION MESSAGE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                place.rawMessage,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.grey[800],
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _addAllAnnotations(List<MapPlace> places) async {
    for (final place in places) {
      final CalloutResult callout = await createCalloutImage(
        place.name,
        place.price,
      );

      await _annotationManager?.create(
        mp.PointAnnotationOptions(
          image: callout.image,
          iconSize: 1.5,
          iconOpacity: 1.0,
          geometry: mp.Point(
            coordinates: mp.Position(place.longitude, place.latitude),
          ),
        ),
      );
    }
  }

  // ── Animate FAB ────────────────────────────────────────────────────────────

  Future<void> _animateAnnotations() async {
    if (_isAnimating) return;
    setState(() => _isAnimating = true);
    await _annotationManager?.deleteAll();
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
        zoom: 11.7,
        center: mp.Point(
          coordinates: mp.Position(place.longitude, place.latitude),
        ),
      ),
      mp.MapAnimationOptions(duration: 1000),
    );

    final CalloutResult callout = await createCalloutImage(
      place.name,
      place.price,
    );

    final mp.PointAnnotation? calloutAnnotation = await _annotationManager
        ?.create(
          mp.PointAnnotationOptions(
            image: callout.image,
            iconSize: 1.5,
            iconOpacity: 0.0,
            geometry: mp.Point(
              coordinates: mp.Position(place.longitude, place.latitude),
            ),
          ),
        );

    await _fadeInAnnotations(calloutAnnotation);
  }

  Future<void> _fadeInAnnotations(mp.PointAnnotation? callout) async {
    for (int i = 1; i <= 25; i++) {
      final double opacity = i / 25;
      if (callout != null) {
        callout.iconOpacity = opacity;
        await _annotationManager?.update(callout);
      }
      await Future.delayed(const Duration(milliseconds: 16));
    }
  }

  void _showLimitSettings(SpendingService spending) {
    final controller = TextEditingController(
      text: spending.limit.toStringAsFixed(0),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set ${spending.period} Limit'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            prefixText: 'Ksh ',
            labelText: 'Limit Amount',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
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

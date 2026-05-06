import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_tut/utils/icons.dart';
import 'package:provider/provider.dart';
import '../models/app_transaction.dart';
import '../services/spending_service.dart';
import '../widgets/custom_toast.dart';

import 'package:google_fonts/google_fonts.dart';

class LocationPickerScreen extends StatefulWidget {
  final AppTransaction transaction;

  const LocationPickerScreen({super.key, required this.transaction});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  mp.MapboxMap? _mapboxMap;
  mp.Position? _initialPosition;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    if (widget.transaction.latitude != null &&
        widget.transaction.longitude != null) {
      setState(() {
        _initialPosition = mp.Position(
          widget.transaction.longitude!,
          widget.transaction.latitude!,
        );
      });
      return;
    }

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _initialPosition = mp.Position(position.longitude, position.latitude);
    });

    if (_mapboxMap != null) {
      _mapboxMap?.setCamera(
        mp.CameraOptions(
          center: mp.Point(coordinates: _initialPosition!),
          zoom: 15,
        ),
      );
    }
  }

  Future<void> _onMapCreated(mp.MapboxMap controller) async {
    _mapboxMap = controller;

    // Enable user location indicator (blue dot)
    controller.location.updateSettings(
      mp.LocationComponentSettings(enabled: true, pulsingEnabled: false),
    );

    if (_initialPosition != null) {
      controller.setCamera(
        mp.CameraOptions(
          center: mp.Point(coordinates: _initialPosition!),
          zoom: 15,
        ),
      );
    }
  }

  Future<void> _flyToUserLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      await _mapboxMap?.flyTo(
        mp.CameraOptions(
          zoom: 17,
          center: mp.Point(
            coordinates: mp.Position(position.longitude, position.latitude),
          ),
        ),
        mp.MapAnimationOptions(duration: 1000),
      );
    } catch (e) {
      debugPrint('[LocationPicker] Could not get user location: $e');
    }
  }

  Future<void> _onConfirm() async {
    if (_mapboxMap == null || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      // Get the current camera center which corresponds to the fixed marker's position
      final cameraState = await _mapboxMap!.getCameraState();
      final center = cameraState.center.coordinates;

      if (!mounted) return;
      final spendingService = context.read<SpendingService>();
      await spendingService.attachLocation(
        widget.transaction.id,
        center.lat.toDouble(),
        center.lng.toDouble(),
      );

      if (mounted) {
        setState(() => _isSaving = false);
        // Pop first to ensure we are back on the previous screen
        Navigator.pop(context);
        // Then show the toast via the root navigator key
        showCustomToast('Transaction Successfully mapped');
      }
    } catch (e) {
      debugPrint('[LocationPicker] Error confirming location: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        showCustomToast('Error: Could not save location');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReassigning = widget.transaction.latitude != null;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white.withValues(alpha: 0.7),
        border: null,
        middle: Text(
          isReassigning ? 'Reassign Location' : 'Pick Location',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: const Color(0xFF1D1D1F),
          ),
        ),
        trailing: _isSaving
            ? CupertinoActivityIndicator(color: CupertinoColors.activeBlue)
            : CupertinoButton(
                padding: EdgeInsets.zero,
                child: Text(
                  'Confirm',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: CupertinoColors.systemBlue,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _onConfirm();
                },
              ),
      ),
      child: Stack(
        children: [
          if (_initialPosition == null)
            const Center(child: CupertinoActivityIndicator())
          else
            mp.MapWidget(
              cameraOptions: mp.CameraOptions(
                center: mp.Point(coordinates: _initialPosition!),
                zoom: 15,
              ),
              styleUri: mp.MapboxStyles.STANDARD_SATELLITE,
              onMapCreated: _onMapCreated,
            ),
          // Precision Crosshair
          IgnorePointer(child: Center(child: locationPicker)),

          // Fly to User Location FAB
          Positioned(
            bottom: 32,
            right: 16,
            child: CupertinoButton(
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
          ),
        ],
      ),
    );
  }
}

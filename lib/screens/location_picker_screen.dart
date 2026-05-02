import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
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

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
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
    if (_initialPosition != null) {
      _mapboxMap?.setCamera(
        mp.CameraOptions(
          center: mp.Point(coordinates: _initialPosition!),
          zoom: 15,
        ),
      );
    }
  }

  Future<void> _onConfirm() async {
    if (_mapboxMap == null) return;

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
        // Pop first to ensure we are back on the messages screen
        Navigator.pop(context);
        // Then show the toast via the root navigator key
        showCustomToast('Transaction Successfully mapped');
      }
    } catch (e) {
      debugPrint('[LocationPicker] Error confirming location: $e');
      if (mounted) {
        showCustomToast('Error: Could not save location');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white.withValues(alpha: 0.8),
        border: null,
        middle: Text(
          'Pick Location',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            HapticFeedback.mediumImpact();
            _onConfirm();
          },
          child: Text(
            'Confirm',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF0071E3),
              fontWeight: FontWeight.w600,
            ),
          ),
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
              styleUri: mp.MapboxStyles.LIGHT,
              onMapCreated: _onMapCreated,
            ),
          // Fixed Center Marker
          IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.black.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const HugeIcon(
                      icon: HugeIcons.strokeRoundedLocation01,
                      color: Color(0xFF0071E3),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 40), // Offset to put the tip on center
                ],
              ),
            ),
          ),
          // Crosshair for precision
          IgnorePointer(
            child: Center(
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF0071E3).withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0071E3),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

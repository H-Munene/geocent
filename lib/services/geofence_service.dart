import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geocent/models/hotspot.dart';

class GeofenceService {
  static const _channel = MethodChannel('app.geocent/geofence');

  // Singleton
  static final GeofenceService _instance = GeofenceService._internal();
  factory GeofenceService() => _instance;
  GeofenceService._internal() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  // Callback type for transitions
  Function(String id, String transition)? onGeofenceTransition;

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onGeofenceTransition':
        final String id = call.arguments['id'];
        final String transition = call.arguments['transition'];
        onGeofenceTransition?.call(id, transition);
        break;
    }
  }

  Future<void> registerHotspots(List<Hotspot> hotspots) async {
    final List<Map<String, dynamic>> geofences = hotspots
        .map(
          (h) => {
            'id': h.stableKey,
            'latitude': h.latitude,
            'longitude': h.longitude,
            'radius': h.radius,
          },
        )
        .toList();

    try {
      await _channel.invokeMethod('addGeofences', {'geofences': geofences});
    } catch (e) {
      debugPrint('[GeofenceService] Failed to add geofences: $e');
    }
  }

  Future<void> removeGeofences(List<String> ids) async {
    try {
      await _channel.invokeMethod('removeGeofences', {'ids': ids});
    } catch (e) {
      debugPrint('[GeofenceService] Failed to remove geofences: $e');
    }
  }

  Future<void> removeAllGeofences() async {
    try {
      await _channel.invokeMethod('removeAllGeofences');
    } catch (e) {
      debugPrint('[GeofenceService] Failed to remove all geofences: $e');
    }
  }

  Future<String?> getActiveGeofenceId() async {
    try {
      return await _channel.invokeMethod<String>('getActiveGeofenceId');
    } catch (e) {
      debugPrint('[GeofenceService] Failed to get active geofence ID: $e');
      return null;
    }
  }
}

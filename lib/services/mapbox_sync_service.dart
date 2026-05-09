import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/hotspot.dart';
import '../repositories/budget_repository.dart';
import '../repositories/hotspot_repository.dart';

class MapboxSyncService {
  final HotspotRepository _hotspotRepo = HotspotRepository();
  final BudgetRepository _budgetRepo = BudgetRepository();

  static const double _syncDistanceThreshold = 10000.0; // 10km
  static const int _syncTimeThresholdDays = 7;

  Future<void> syncHotspotsIfNecessary(
    double currentLat,
    double currentLon,
  ) async {
    try {
      final SyncMetadata? metadata = await _hotspotRepo.getSyncMetadata();

      bool shouldSync = false;
      if (metadata == null) {
        shouldSync = true;
      } else {
        final double distance = Geolocator.distanceBetween(
          currentLat,
          currentLon,
          metadata.lastSyncLat,
          metadata.lastSyncLon,
        );
        final int daysSinceSync = DateTime.now()
            .difference(metadata.lastSyncTimestamp)
            .inDays;

        if (distance >= _syncDistanceThreshold ||
            daysSinceSync >= _syncTimeThresholdDays) {
          shouldSync = true;
        }
      }

      if (shouldSync) {
        await _performSync(currentLat, currentLon);
      }
    } catch (e) {
      debugPrint('[MapboxSync] Sync check failed: $e');
    }
  }

  Future<void> _performSync(double lat, double lon) async {
    debugPrint('[MapboxSync] Starting POI sync around $lat, $lon');

    final budgets = await _budgetRepo.getAllBudgets();
    if (budgets.isEmpty) return;

    final categories = budgets.map((b) => b.categoryName).toSet();
    final List<Hotspot> allHotspots = [];

    // Mapbox Category Search API: bounding box format is minLon,minLat,maxLon,maxLat
    // 10km bounding box
    final double delta = 10000.0 / 111000.0;
    final String bbox =
        '${lon - delta},${lat - delta},${lon + delta},${lat + delta}';
    final String token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

    for (final category in categories) {
      final List<String> poiTypes = _mapCategoryToPoiTypes(category);
      if (poiTypes.isEmpty) continue;

      for (final type in poiTypes) {
        final List<Hotspot> hotspots = await _fetchPoisFromMapbox(
          type,
          bbox,
          token,
          category,
        );
        allHotspots.addAll(hotspots);
      }
    }

    if (allHotspots.isNotEmpty) {
      await _hotspotRepo.batchInsertHotspots(allHotspots);
      await _hotspotRepo.updateSyncMetadata(lat, lon);
      debugPrint(
        '[MapboxSync] Sync complete. Cached ${allHotspots.length} hotspots.',
      );
    }
  }

  List<String> _mapCategoryToPoiTypes(String category) {
    switch (category) {
      case 'Dining':
      case 'Coffee':
      case 'Snacks':
      case 'Alcohol':
      case 'Coffee To Go':
      case 'Fast Food':
        return ['food_and_drink', 'restaurant', 'cafe', 'bar'];
      case 'Groceries':
        return ['grocery', 'supermarket'];
      case 'Shopping':
      case 'Clothing':
      case 'Shoes':
      case 'Jewelry':
      case 'Hardware':
        return ['shopping', 'clothing_store', 'department_store', 'mall'];
      case 'Travel':
      case 'Taxi':
        return ['transportation', 'airport', 'train_station', 'bus_stop'];
      case 'Health':
      case 'Dental':
      case 'Vision':
        return ['health_services', 'hospital', 'pharmacy', 'doctor'];
      case 'Education':
        return ['education', 'school', 'university'];
      case 'Vacation':
        return ['beach', 'park', 'campground', 'hotel'];
      default:
        return [];
    }
  }

  Future<List<Hotspot>> _fetchPoisFromMapbox(
    String type,
    String bbox,
    String token,
    String category,
  ) async {
    final url =
        'https://api.mapbox.com/search/searchbox/v1/category/$type'
        '?access_token=$token&bbox=$bbox&limit=25';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List features = data['features'] ?? [];

        return features.map((f) {
          final props = f['properties'] ?? {};
          final coords = f['geometry']['coordinates'];
          return Hotspot(
            id: props['mapbox_id'] ?? props['id'] ?? '',
            name: props['name'] ?? 'Unknown',
            longitude: (coords[0] as num).toDouble(),
            latitude: (coords[1] as num).toDouble(),
            matchedCategory: category,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[MapboxSync] API call failed for $type: $e');
    }
    return [];
  }
}

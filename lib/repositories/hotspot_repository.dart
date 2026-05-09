// THIS FILE IS DECOMMISSIONED
// The Hotspot feature has been removed.
// You can safely delete this file.
/*
import 'package:geocent/database_helper.dart';
import 'package:geocent/models/hotspot.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sqflite/sqflite.dart';

class HotspotRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<void> batchInsertHotspots(List<Hotspot> hotspots) async {
    final db = await _db.database;
    final batch = db.batch();

    for (final hotspot in hotspots) {
      batch.insert(
        DatabaseHelper.tableCachedHotspots,
        hotspot.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> updateSyncMetadata(double lat, double lon) async {
    final db = await _db.database;
    await db.insert(
      DatabaseHelper.tableSyncMetadata,
      {
        DatabaseHelper.colId: 1,
        DatabaseHelper.colLastSyncLat: lat,
        DatabaseHelper.colLastSyncLon: lon,
        DatabaseHelper.colLastSyncTimestamp: DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<SyncMetadata?> getSyncMetadata() async {
    final rows = await _db.rawQuery(
      DatabaseHelper.tableSyncMetadata,
      where: '${DatabaseHelper.colId} = ?',
      whereArgs: [1],
    );

    if (rows.isEmpty) return null;

    final row = rows.first;
    return SyncMetadata(
      lastSyncLat: (row[DatabaseHelper.colLastSyncLat] as num).toDouble(),
      lastSyncLon: (row[DatabaseHelper.colLastSyncLon] as num).toDouble(),
      lastSyncTimestamp: DateTime.parse(
        row[DatabaseHelper.colLastSyncTimestamp] as String,
      ),
    );
  }

  Future<List<Hotspot>> getNearbyHotspots(
    double lat,
    double lon, {
    double radiusInMeters = 150,
  }) async {
    // 1. Calculate Bounding Box (Fast SQLite Pre-filter)
    // Approx 111,000 meters per degree
    final double latDelta = radiusInMeters / 111000.0;
    // Nairobi is near equator, so lonDelta is similar.
    final double lonDelta = radiusInMeters / 111000.0;

    final double minLat = lat - latDelta;
    final double maxLat = lat + latDelta;
    final double minLon = lon - lonDelta;
    final double maxLon = lon + lonDelta;

    final List<Map<String, dynamic>> candidateRows = await _db.rawQuery(
      DatabaseHelper.tableCachedHotspots,
      where:
          '${DatabaseHelper.colLatitude} BETWEEN ? AND ? AND '
          '${DatabaseHelper.colLongitude} BETWEEN ? AND ?',
      whereArgs: [minLat, maxLat, minLon, maxLon],
    );

    // 2. Exact Filtering in Dart using Haversine
    final List<Hotspot> result = [];
    for (final row in candidateRows) {
      final hotspot = Hotspot.fromMap(row);
      final double distance = Geolocator.distanceBetween(
        lat,
        lon,
        hotspot.latitude,
        hotspot.longitude,
      );

      if (distance <= radiusInMeters) {
        result.add(hotspot);
      }
    }

    return result;
  }

  Future<void> clearAllHotspots() async {
    final db = await _db.database;
    await db.delete(DatabaseHelper.tableCachedHotspots);
  }

  Future<List<Hotspot>> getAllHotspots() async {
    final rows = await _db.rawQuery(DatabaseHelper.tableCachedHotspots);
    return rows.map((row) => Hotspot.fromMap(row)).toList();
  }
}
*/

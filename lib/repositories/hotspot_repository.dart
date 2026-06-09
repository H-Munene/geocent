import 'package:geocent/database_helper.dart';
import 'package:geocent/models/hotspot.dart';
import 'package:sqflite/sqflite.dart';

class HotspotRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<void> saveHotspots(List<Hotspot> hotspots) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      // Get all current stable keys to see what to delete later if needed
      // Or just use ConflictAlgorithm.replace if stable_key is UNIQUE.
      // But stable_key is not the PRIMARY KEY (id is).

      for (final hotspot in hotspots) {
        // Check if exists by stable_key to preserve last_notified_at
        final existing = await txn.query(
          DatabaseHelper.tableHotspots,
          where: '${DatabaseHelper.colStableKey} = ?',
          whereArgs: [hotspot.stableKey],
          limit: 1,
        );

        DateTime? lastNotifiedAt = hotspot.lastNotifiedAt;
        if (existing.isNotEmpty) {
          final String? lnAt =
              existing.first[DatabaseHelper.colLastNotifiedAt] as String?;
          if (lnAt != null) {
            lastNotifiedAt = DateTime.parse(lnAt);
          }

          // Update existing
          await txn.update(
            DatabaseHelper.tableHotspots,
            hotspot.copyWith(lastNotifiedAt: lastNotifiedAt).toMap(),
            where: '${DatabaseHelper.colStableKey} = ?',
            whereArgs: [hotspot.stableKey],
          );
        } else {
          // Insert new
          await txn.insert(
            DatabaseHelper.tableHotspots,
            hotspot.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // Delete orphaned hotspots that are no longer valid (e.g. user moved transactions)
      final newStableKeys = hotspots.map((h) => h.stableKey).toList();
      if (newStableKeys.isNotEmpty) {
        final placeholders = List.filled(newStableKeys.length, '?').join(',');
        await txn.delete(
          DatabaseHelper.tableHotspots,
          where: '${DatabaseHelper.colStableKey} NOT IN ($placeholders)',
          whereArgs: newStableKeys,
        );
      } else {
        await txn.delete(DatabaseHelper.tableHotspots);
      }
    });
  }

  Future<List<Hotspot>> getAllHotspots() async {
    final rows = await _db.rawQuery(DatabaseHelper.tableHotspots);
    return rows.map((row) => Hotspot.fromMap(row)).toList();
  }

  Future<void> updateLastNotified(String stableKey, DateTime at) async {
    await _db.rawUpdate(
      DatabaseHelper.tableHotspots,
      {DatabaseHelper.colLastNotifiedAt: at.toIso8601String()},
      '${DatabaseHelper.colStableKey} = ?',
      [stableKey],
    );
  }

  Future<void> deleteAll() async {
    final db = await _db.database;
    await db.delete(DatabaseHelper.tableHotspots);
  }
}

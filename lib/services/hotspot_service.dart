import 'dart:math';
import 'package:geocent/models/app_transaction.dart';
import 'package:geocent/models/hotspot.dart';
import 'package:geocent/repositories/hotspot_repository.dart';
import 'package:geocent/repositories/transaction_repository.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

class HotspotService {
  final TransactionRepository _transactionRepo = TransactionRepository();
  final HotspotRepository _hotspotRepo = HotspotRepository();

  static const double defaultEpsilon = 100.0; // meters
  static const int defaultMinPoints = 3;
  static const int minTransactionsRequired = 10;

  Future<bool> isDataSufficient() async {
    final count = await _transactionRepo.countGeocodedTransactions();
    return count >= minTransactionsRequired;
  }

  Future<void> runClustering({
    double epsilon = defaultEpsilon,
    int minPoints = defaultMinPoints,
  }) async {
    if (!await isDataSufficient()) return;

    final transactions = await _transactionRepo.loadMapped();

    // Using a simple in-isolate DBSCAN.
    // If performance becomes an issue, this can be moved to a Compute isolate.
    final clusters = _dbscan(transactions, epsilon, minPoints);
    final hotspots = clusters
        .map((cluster) => _createHotspot(cluster))
        .toList();

    await _hotspotRepo.saveHotspots(hotspots);
  }

  List<List<AppTransaction>> _dbscan(
    List<AppTransaction> transactions,
    double epsilon,
    int minPoints,
  ) {
    final List<List<AppTransaction>> clusters = [];
    final Set<String> visited = {};
    final Set<String> clustered = {};

    for (final tx in transactions) {
      if (visited.contains(tx.id)) continue;
      visited.add(tx.id);

      final neighbors = _getNeighbors(tx, transactions, epsilon);

      if (neighbors.length < minPoints) {
        // Noise
      } else {
        final List<AppTransaction> cluster = [];
        clusters.add(cluster);
        _expandCluster(
          tx,
          neighbors,
          cluster,
          visited,
          clustered,
          transactions,
          epsilon,
          minPoints,
        );
      }
    }

    return clusters;
  }

  void _expandCluster(
    AppTransaction tx,
    List<AppTransaction> neighbors,
    List<AppTransaction> cluster,
    Set<String> visited,
    Set<String> clustered,
    List<AppTransaction> allTransactions,
    double epsilon,
    int minPoints,
  ) {
    cluster.add(tx);
    clustered.add(tx.id);

    final List<AppTransaction> queue = List.from(neighbors);
    int i = 0;
    while (i < queue.length) {
      final neighborTx = queue[i];
      if (!visited.contains(neighborTx.id)) {
        visited.add(neighborTx.id);
        final neighborNeighbors = _getNeighbors(
          neighborTx,
          allTransactions,
          epsilon,
        );
        if (neighborNeighbors.length >= minPoints) {
          queue.addAll(neighborNeighbors.where((n) => !visited.contains(n.id)));
        }
      }

      if (!clustered.contains(neighborTx.id)) {
        cluster.add(neighborTx);
        clustered.add(neighborTx.id);
      }
      i++;
    }
  }

  List<AppTransaction> _getNeighbors(
    AppTransaction tx,
    List<AppTransaction> allTransactions,
    double epsilon,
  ) {
    return allTransactions.where((other) {
      if (tx.id == other.id) return false;
      final distance = Geolocator.distanceBetween(
        tx.latitude!,
        tx.longitude!,
        other.latitude!,
        other.longitude!,
      );
      return distance <= epsilon;
    }).toList();
  }

  Hotspot _createHotspot(List<AppTransaction> cluster) {
    double totalSpend = 0;
    for (final tx in cluster) {
      totalSpend += tx.amount;
    }

    // Find the medoid (the actual transaction with the minimum total distance to all other transactions in the cluster)
    // This ensures the visual hotspot perfectly centers over the densest cluster of markers.
    AppTransaction? medoid;
    double minTotalDistance = double.infinity;

    for (final candidate in cluster) {
      double totalDistance = 0;
      for (final other in cluster) {
        totalDistance += Geolocator.distanceBetween(
          candidate.latitude!,
          candidate.longitude!,
          other.latitude!,
          other.longitude!,
        );
      }
      if (totalDistance < minTotalDistance) {
        minTotalDistance = totalDistance;
        medoid = candidate;
      }
    }

    final avgLat = medoid!.latitude!;
    final avgLng = medoid.longitude!;
    final avgSpend = totalSpend / cluster.length;

    double maxDistance = 0;
    for (final tx in cluster) {
      final distance = Geolocator.distanceBetween(
        avgLat,
        avgLng,
        tx.latitude!,
        tx.longitude!,
      );
      if (distance > maxDistance) maxDistance = distance;
    }

    // Stable key: lat/lng rounded to 4 decimal places for better precision
    final stableKey =
        '${avgLat.toStringAsFixed(4)}:${avgLng.toStringAsFixed(4)}';

    return Hotspot(
      id: const Uuid().v4(),
      stableKey: stableKey,
      latitude: avgLat,
      longitude: avgLng,
      radius: max(maxDistance, 50.0), // minimum 50m radius
      avgSpend: avgSpend,
      totalSpend: totalSpend,
      transactionCount: cluster.length,
    );
  }
}

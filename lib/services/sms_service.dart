// lib/services/sms_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/app_transaction.dart';
import '../repositories/transaction_repository.dart';
import '../services/native_sms_channel.dart';
import '../services/sms_parser.dart';
import '../services/spending_service.dart';

class SmsService {
  final TransactionRepository _repo;
  final SpendingService _spending;

  // Subscriptions to background service events
  StreamSubscription? _txSavedSub;
  StreamSubscription? _locAttachedSub;
  StreamSubscription? _smsStreamSub;

  SmsService({
    required TransactionRepository repo,
    required SpendingService spending,
  }) : _repo = repo,
       _spending = spending;

  Future<void> init() async {
    final bool hasPermission = await _requestSmsPermission();
    if (!hasPermission) {
      debugPrint('[SmsService] SMS permission denied');
      return;
    }

    // 1. Initial history load from local inbox
    await _loadInboxHistory();

    final service = FlutterBackgroundService();

    // 2. Fallback for live SMS: the background isolate is the primary writer
    // (it also runs budget alerts). Only handle here when it isn't running.
    NativeSmsChannel.instance.register();
    _smsStreamSub = NativeSmsChannel.instance.smsStream.listen((sms) async {
      if (await service.isRunning()) return;
      debugPrint(
        '[SmsService] Background service down; handling SMS from ${sms.sender}',
      );
      await _processMessage(sms.body, captureLocation: true);
    });

    // 3. Refresh when the background isolate saves or geotags a transaction

    _txSavedSub = service.on('transaction_saved').listen((_) async {
      debugPrint(
        '[SmsService] Background service saved a transaction. Refreshing...',
      );
      await _spending.refresh();
    });

    _locAttachedSub = service.on('location_attached').listen((_) async {
      debugPrint(
        '[SmsService] Background service attached GPS. Refreshing map...',
      );
      await _spending.refresh();
    });
  }

  void dispose() {
    _txSavedSub?.cancel();
    _locAttachedSub?.cancel();
    _smsStreamSub?.cancel();
  }

  Future<bool> _requestSmsPermission() async {
    final status = await Permission.sms.request();
    return status == PermissionStatus.granted;
  }

  Future<void> _loadInboxHistory() async {
    try {
      final SmsQuery query = SmsQuery();
      final mpesa = await query.querySms(
        kinds: [SmsQueryKind.inbox],
        address: 'MPESA',
        count: 200,
      );
      final equity = await query.querySms(
        kinds: [SmsQueryKind.inbox],
        address: 'Equity',
        count: 200,
      );
      int saved = 0;
      for (final sms in [...mpesa, ...equity]) {
        if (await _processMessage(sms.body ?? '', captureLocation: false)) {
          saved++;
        }
      }
      debugPrint('[SmsService] Inbox import: $saved new transactions');
      if (saved > 0) await _spending.refresh();
    } catch (e) {
      debugPrint('[SmsService] Inbox load failed: $e');
    }
  }

  Future<bool> _processMessage(
    String body, {
    required bool captureLocation,
  }) async {
    if (body.isEmpty) return false;
    final AppTransaction? tx = SmsParser.parse(body);
    if (tx == null) return false;
    if (await _repo.exists(tx.id)) return false;
    await _repo.save(tx);
    debugPrint(
      '[SmsService] Saved: ${tx.id} ${tx.formattedAmount} @ ${tx.merchant}',
    );

    // Refresh totals immediately even before location is attached
    await _spending.refresh();

    if (captureLocation) _captureAndAttachLocation(tx.id);
    return true;
  }

  Future<void> _captureAndAttachLocation(String txId) async {
    try {
      // 1. Try last known position (very fast, usually accurate if app is open)
      Position? pos = await Geolocator.getLastKnownPosition();

      // If no last known or it's old (>5 mins), get current position
      if (pos == null ||
          DateTime.now().difference(pos.timestamp).inMinutes > 5) {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 20),
          ),
        );
      }

      await _spending.attachLocation(txId, pos.latitude, pos.longitude);
      debugPrint('[SmsService] GPS attached to $txId');
    } catch (e) {
      debugPrint('[SmsService] GPS failed for $txId: $e');
    }
  }
}

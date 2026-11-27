import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../repositories/transaction_repository.dart';
import '../repositories/budget_repository.dart';
import '../services/native_sms_channel.dart';
import '../services/sms_parser.dart';
import '../services/notification_service.dart';
import '../services/geofence_service.dart';
import '../repositories/hotspot_repository.dart';
import '../models/sms_message.dart';
import '../models/app_transaction.dart';
import '../utils/date_periods.dart';

String? _activeGeofenceId;

@pragma('vm:entry-point')
void onBackgroundServiceStart(ServiceInstance service) async {
  // Use try-catch to prevent a single plugin registration error from killing the service.
  try {
    DartPluginRegistrant.ensureInitialized();
  } catch (e) {
    debugPrint('[Background Isolate] Plugin registration warning: $e');
  }

  await NotificationService.instance.init();

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
  );

  final repo = TransactionRepository();

  final geofenceService = GeofenceService();

  // 📍 Phase 5: Rehydration
  _activeGeofenceId = await geofenceService.getActiveGeofenceId();
  debugPrint(
    '[Background Isolate] Rehydrated active geofence: $_activeGeofenceId',
  );

  geofenceService.onGeofenceTransition = (id, transition) async {
    if (transition == 'DWELL') {
      _activeGeofenceId = id;
      _handleGeofenceDwell(id, repo, flutterLocalNotificationsPlugin);
    } else if (transition == 'EXIT') {
      if (_activeGeofenceId == id) {
        _activeGeofenceId = null;
      }
    }
  };

  NativeSmsChannel.instance.register();

  NativeSmsChannel.instance.smsStream.listen((sms) async {
    _processIncomingSms(sms, repo, service, flutterLocalNotificationsPlugin);
  });

  service.on('simulate_transaction').listen((_) async {
    // Real M-PESA "paid to" format with a fresh code so dedupe doesn't skip it.
    final now = DateTime.now();
    final code =
        'SIM${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final meridiem = now.hour < 12 ? 'AM' : 'PM';
    final mockSms =
        '$code Confirmed. Ksh5,200.00 paid to ARTCAFFE. on '
        '${now.day}/${now.month}/${now.year % 100} at $hour12:$minute $meridiem. '
        'New M-PESA balance is Ksh10,000.00.';
    _processIncomingSms(
      SmsMessage(sender: 'MPESA', body: mockSms),
      repo,
      service,
      flutterLocalNotificationsPlugin,
    );
  });
}

Future<void> _checkBudgetThresholds(
  String category,
  BudgetRepository budgetRepo,
  TransactionRepository txRepo, {
  String? activeGeofenceId,
}) async {
  final budgets = await budgetRepo.getAllBudgets();
  final budget = budgets.where((b) => b.categoryName == category).firstOrNull;
  if (budget == null) return;

  final DateTime now = DateTime.now();
  final DateTime start = periodStart(budget.period, now);

  final spending = await txRepo.getCategorySpending(start, now);
  final match = spending.firstWhere(
    (s) => s['category'] == category,
    orElse: () => {'total_amount': 0.0},
  );

  final double totalSpent = (match['total_amount'] as num).toDouble();
  final double percentage = totalSpent / budget.amountLimit;

  int lastThreshold = budget.lastNotifiedThreshold;
  if (budget.lastNotifiedAt != null && budget.lastNotifiedAt!.isBefore(start)) {
    lastThreshold = 0;
  }

  int newThreshold = lastThreshold;
  if (percentage >= 1.0 && lastThreshold < 100) {
    newThreshold = 100;
  } else if (percentage >= 0.80 && lastThreshold < 80) {
    newThreshold = 80;
  } else if (percentage >= 0.50 && lastThreshold < 50) {
    newThreshold = 50;
  }

  if (newThreshold > lastThreshold) {
    String? locationContext;
    if (activeGeofenceId != null) {
      locationContext = 'your spending hotspot';
    }

    await NotificationService.instance.showBudgetNotification(
      id: budget.id.hashCode,
      category: budget.categoryName,
      percentUsed: (percentage * 100).toInt(),
      amountLeft: (budget.amountLimit - totalSpent).clamp(0, double.infinity),
      locationContext: locationContext,
    );

    await budgetRepo.updateNotificationState(budget.id, newThreshold, now);
  }
}

Future<void> _processIncomingSms(
  SmsMessage sms,
  TransactionRepository repo,
  ServiceInstance service,
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
) async {
  debugPrint('[Background Isolate] Processing SMS from ${sms.sender}');

  AppTransaction? tx = SmsParser.parse(sms.body);
  if (tx != null && !(await repo.exists(tx.id))) {
    // Auto-categorize based on merchant history
    String? category = tx.category;
    if (category == null) {
      category = await repo.getMerchantCategory(tx.merchant);
      if (category != null) {
        tx = tx.copyWith(category: category);
      }
    }

    await repo.save(tx);

    service.invoke('transaction_saved');

    _showTransactionNotification(
      flutterLocalNotificationsPlugin,
      tx.merchant,
      tx.formattedAmount,
      tx.id,
    );

    // 📍 New: Check Budget Thresholds
    if (tx.category != null) {
      final budgetRepo = BudgetRepository();
      await _checkBudgetThresholds(
        tx.category!,
        budgetRepo,
        repo,
        activeGeofenceId: _activeGeofenceId,
      );
    }

    try {
      geo.Position? pos = await geo.Geolocator.getLastKnownPosition();

      if (pos == null ||
          DateTime.now().difference(pos.timestamp).inMinutes > 10) {
        pos = await geo.Geolocator.getCurrentPosition(
          locationSettings: const geo.LocationSettings(
            accuracy: geo.LocationAccuracy.high,
            timeLimit: Duration(seconds: 40),
          ),
        );
      }

      await repo.updateLocation(tx.id, pos.latitude, pos.longitude);

      service.invoke('location_attached', {'id': tx.id});
    } catch (e) {
      debugPrint('[Background Isolate] GPS failed: $e');
    }
  }
}

void _showTransactionNotification(
  FlutterLocalNotificationsPlugin plugin,
  String merchant,
  String amount,
  String txId,
) {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'geocent_tx',
        'Transactions',
        channelDescription: 'New transaction alerts',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );
  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );
  plugin.show(
    id: txId.hashCode,
    title: 'New Expense Tracked',
    body: '$amount spent at $merchant',
    notificationDetails: platformChannelSpecifics,
  );
}

Future<void> _handleGeofenceDwell(
  String stableKey,
  TransactionRepository repo,
  FlutterLocalNotificationsPlugin notifications,
) async {
  final hotspotRepo = HotspotRepository();
  final hotspots = await hotspotRepo.getAllHotspots();
  final hotspot = hotspots.where((h) => h.stableKey == stableKey).firstOrNull;

  if (hotspot == null) return;

  // 📍 Phase 4: Cooldown logic (6 hours)
  final now = DateTime.now();
  if (hotspot.lastNotifiedAt != null &&
      now.difference(hotspot.lastNotifiedAt!).inHours < 6) {
    debugPrint('[Background Isolate] Cooldown active for hotspot $stableKey');
    return;
  }

  // Fire notification
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'geocent_hotspot',
        'Hotspots',
        channelDescription: 'Spending hotspot alerts',
        importance: Importance.high,
        priority: Priority.high,
      );
  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );

  await notifications.show(
    id: stableKey.hashCode,
    title: 'Spending Alert',
    body:
        "You've spent an average of Ksh ${hotspot.avgSpend.toStringAsFixed(0)} in this area.",
    notificationDetails: platformChannelSpecifics,
  );

  // Update cooldown
  await hotspotRepo.updateLastNotified(stableKey, now);
}

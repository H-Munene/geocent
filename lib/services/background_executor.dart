import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/budget_repository.dart';
import '../services/native_sms_channel.dart';
import '../services/sms_parser.dart';
import '../services/notification_service.dart';
import '../models/sms_message.dart';
import '../models/app_transaction.dart';

@pragma('vm:entry-point')
void onBackgroundServiceStart(ServiceInstance service) async {
  // Use try-catch to prevent a single plugin registration error from killing the service.
  try {
    DartPluginRegistrant.ensureInitialized();
  } catch (e) {
    debugPrint('[Background Isolate] Plugin registration warning: $e');
  }

  // 📍 FIX: Load environment variables for the background isolate's memory space
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('[Background Isolate] Failed to load .env: $e');
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

  NativeSmsChannel.instance.register();

  NativeSmsChannel.instance.smsStream.listen((sms) async {
    _processIncomingSms(sms, repo, service, flutterLocalNotificationsPlugin);
  });

  service.on('simulate_transaction').listen((_) async {
    const mockSms =
        'Confirmed. KES 5,200.00 paid to ARTCAFFE. On 12/5/26 at 1:45 PM.';
    _processIncomingSms(
      const SmsMessage(sender: 'MPESA', body: mockSms),
      repo,
      service,
      flutterLocalNotificationsPlugin,
    );
  });
}

Future<void> _checkBudgetThresholds(
  String category,
  BudgetRepository budgetRepo,
  TransactionRepository txRepo,
) async {
  final budgets = await budgetRepo.getAllBudgets();
  final budget = budgets.where((b) => b.categoryName == category).firstOrNull;
  if (budget == null) return;

  final DateTime now = DateTime.now();
  final DateTime start = _getPeriodStart(budget.period, now);

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
  if (percentage >= 0.80 && lastThreshold < 80) {
    newThreshold = 80;
  } else if (percentage >= 0.50 && lastThreshold < 50) {
    newThreshold = 50;
  }

  if (newThreshold > lastThreshold) {
    await NotificationService.instance.showBudgetNotification(
      id: budget.id.hashCode,
      category: budget.categoryName,
      percentUsed: (percentage * 100).toInt(),
      amountLeft: (budget.amountLimit - totalSpent).clamp(0, double.infinity),
    );

    await budgetRepo.updateNotificationState(budget.id, newThreshold, now);
  }
}

DateTime _getPeriodStart(String period, DateTime now) {
  switch (period.toLowerCase()) {
    case 'daily':
      return DateTime(now.year, now.month, now.day);
    case 'weekly':
      final int daysToSubtract = now.weekday == 7 ? 0 : now.weekday;
      final startOfCurrentWeek = now.subtract(Duration(days: daysToSubtract));
      return DateTime(
        startOfCurrentWeek.year,
        startOfCurrentWeek.month,
        startOfCurrentWeek.day,
      );
    case 'monthly':
      return DateTime(now.year, now.month, 1);
    default:
      return DateTime(now.year, now.month, now.day);
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
      _checkBudgetThresholds(tx.category!, budgetRepo, repo);
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

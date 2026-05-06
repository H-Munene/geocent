import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../repositories/transaction_repository.dart';
import '../services/native_sms_channel.dart';
import '../services/sms_parser.dart';
import '../models/sms_message.dart';

@pragma('vm:entry-point')
void onBackgroundServiceStart(ServiceInstance service) async {
  // Use try-catch to prevent a single plugin registration error from killing the service.
  // mapbox_maps_flutter is known to throw "This class should only be used in the main isolate"
  // during registration in background isolates.
  try {
    DartPluginRegistrant.ensureInitialized();
  } catch (e) {
    debugPrint('[Background Isolate] Plugin registration warning: $e');
  }

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
        'Confirmed. Ksh5,200.00 paid to ARTCAFFE. On 12/5/26 at 1:45 PM.';
    _processIncomingSms(
      const SmsMessage(sender: 'MPESA', body: mockSms),
      repo,
      service,
      flutterLocalNotificationsPlugin,
    );
  });
}

Future<void> _processIncomingSms(
  SmsMessage sms,
  TransactionRepository repo,
  ServiceInstance service,
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
) async {
  debugPrint('[Background Isolate] Processing SMS from ${sms.sender}');

  final tx = SmsParser.parse(sms.body);
  if (tx != null && !(await repo.exists(tx.id))) {
    await repo.save(tx);

    service.invoke('transaction_saved');

    _showTransactionNotification(
      flutterLocalNotificationsPlugin,
      tx.merchant,
      tx.formattedAmount,
      tx.id,
    );

    try {
      geo.Position? pos = await geo.Geolocator.getLastKnownPosition();

      if (pos == null ||
          DateTime.now().difference(pos.timestamp).inMinutes > 10) {
        pos = await geo.Geolocator.getCurrentPosition(
          locationSettings: const geo.LocationSettings(
            accuracy: geo.LocationAccuracy.medium,
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

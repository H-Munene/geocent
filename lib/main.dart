import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:mapbox_tut/repositories/transaction_repository.dart';
import 'package:mapbox_tut/screens/main_screen.dart';
import 'package:mapbox_tut/services/native_sms_channel.dart';
import 'package:mapbox_tut/services/spending_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'services/sms_parser.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setup();
  await getPermissions();
  await initializeBackgroundService();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SpendingService()..init()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'SpendMap',
      theme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.activeBlue,
        textTheme: CupertinoTextThemeData(
          textStyle: GoogleFonts.spaceGrotesk(color: const Color(0xFF1A1A1A)),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  // Create the notification channel manually to avoid "Bad notification" errors on Android 12+
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'spendmap_foreground',
    'SpendMap Background Service',
    description: 'Running in the background to track expenses',
    importance: Importance.low, // Lower importance so it doesn't pop up
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onBackgroundServiceStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'spendmap_foreground',
      initialNotificationTitle: 'SpendMap Active',
      initialNotificationContent: 'Tracking expenses in the background',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(autoStart: false),
  );
}

@pragma('vm:entry-point')
void onBackgroundServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

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
    debugPrint('[Background Isolate] Processing SMS from ${sms.sender}');

    final tx = SmsParser.parse(sms.body);
    if (tx != null && !(await repo.exists(tx.id))) {
      await repo.save(tx);

      service.invoke('transaction_saved');

      _showTransactionNotification(
        flutterLocalNotificationsPlugin,
        tx.merchant,
        tx.formattedAmount,
      );

      try {
        geo.Position? pos = await geo.Geolocator.getLastKnownPosition();

        if (pos == null ||
            DateTime.now().difference(pos.timestamp).inMinutes > 10) {
          pos = await geo.Geolocator.getCurrentPosition(
            locationSettings: const geo.LocationSettings(
              accuracy: geo.LocationAccuracy.medium,
              timeLimit: Duration(seconds: 8),
            ),
          );
        }

        await repo.updateLocation(tx.id, pos.latitude, pos.longitude);

        service.invoke('location_attached', {'id': tx.id});
      } catch (e) {
        debugPrint('[Background Isolate] GPS failed: $e');
      }
    }
  });
}

void _showTransactionNotification(
  FlutterLocalNotificationsPlugin plugin,
  String merchant,
  String amount,
) {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'spendmap_tx',
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
    id: DateTime.now().millisecond,
    title: 'New Expense Tracked',
    body: '$amount spent at $merchant',
    notificationDetails: platformChannelSpecifics,
  );
}

Future<void> setup() async {
  await dotenv.load(fileName: '.env');
  final String mapBoxToken = dotenv.env['MAPBOX_ACCESS_TOKEN']!;
  mb.MapboxOptions.setAccessToken(mapBoxToken);
}

Future<void> getPermissions() async {
  await [
    Permission.location,
    Permission.sms,
    Permission.notification,
  ].request();
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:geocent/screens/main_screen.dart';
import 'package:geocent/services/background_executor.dart';
import 'package:geocent/services/budget_service.dart';
import 'package:geocent/services/spending_service.dart';
import 'package:geocent/widgets/custom_toast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await setup();
  await getPermissions();
  await initializeBackgroundService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SpendingService()..init()),
        ChangeNotifierProvider(create: (_) => BudgetService()..init()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // This re-applies the style on every frame — survives navigation,
      // keyboard show/hide, and plugin resets.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: CupertinoApp(
        navigatorKey: rootNavigatorKey,
        title: 'Geocent',
        theme: CupertinoThemeData(
          brightness: Brightness.light,
          primaryColor: const Color(0xFF0071E3),
          textTheme: CupertinoTextThemeData(
            textStyle: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF1D1D1F),
              letterSpacing: -0.3,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ),
        home: const MainScreen(),
      ),
    );
  }
}

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  // Create the notification channel manually to avoid "Bad notification" errors on Android 12+
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'geocent_foreground',
    'Geocent Background Service',
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
      notificationChannelId: 'geocent_foreground',
      initialNotificationTitle: 'Geocent Active',
      initialNotificationContent: 'Tracking expenses in the background',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(autoStart: false),
  );
}

Future<void> setup() async {
  await dotenv.load(fileName: '.env');
  final String? mapBoxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'];
  if (mapBoxToken != null) {
    mb.MapboxOptions.setAccessToken(mapBoxToken);
  } else {
    debugPrint('WARNING: MAPBOX_ACCESS_TOKEN not found in .env');
  }
}

Future<void> getPermissions() async {
  final statuses = await [
    Permission.locationWhenInUse,
    Permission.sms,
    Permission.notification,
  ].request();

  if (statuses[Permission.locationWhenInUse] == PermissionStatus.granted) {
    await Permission.locationAlways.request();
  }
}

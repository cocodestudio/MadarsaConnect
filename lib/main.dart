import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:madarsaconnect/utils/app_usage_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Data/check_internet.dart';
import 'Data/main_page.dart';
import 'Home Screen/upload_provider.dart';
import 'Main Screen/search_map.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'Main Screen/splash_screen.dart';
import 'l10n/app_localizations.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
late FirebaseAnalytics analytics;
FirebaseAnalyticsObserver? analyticsObserver;
final AppUsageTracker usageTracker = AppUsageTracker();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'This channel is used for important notifications.',
  importance: Importance.high,
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@drawable/notification_icon');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: DarwinInitializationSettings(),
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  final String? savedLanguageCode = prefs.getString('language_code');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ProfileProvider()),
        ChangeNotifierProvider(create: (context) => UploadProvider()),
        ChangeNotifierProvider(
          create: (context) => LanguageProvider(savedLanguageCode),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  String _getFontFamily(String localeCode) {
    switch (localeCode) {
      case 'hi':
        return 'HindiFont';
      case 'ur':
        return 'UrduFont';
      default:
        return 'Gilroy';
    }
  }

  TextTheme _getTextTheme(String localeCode) {
    final String fontFamily = _getFontFamily(localeCode);
    if (localeCode == 'ur') {
      const double urduHeight = 1.9;
      return TextTheme(
        displayLarge: TextStyle(fontFamily: fontFamily, height: urduHeight),
        displayMedium: TextStyle(fontFamily: fontFamily, height: urduHeight),
        displaySmall: TextStyle(fontFamily: fontFamily, height: urduHeight),
        headlineLarge: TextStyle(fontFamily: fontFamily, height: urduHeight),
        headlineMedium: TextStyle(fontFamily: fontFamily, height: urduHeight),
        headlineSmall: TextStyle(fontFamily: fontFamily, height: urduHeight),
        titleLarge: TextStyle(fontFamily: fontFamily, height: urduHeight),
        titleMedium: TextStyle(fontFamily: fontFamily, height: urduHeight),
        titleSmall: TextStyle(fontFamily: fontFamily, height: urduHeight),
        bodyLarge: TextStyle(fontFamily: fontFamily, height: urduHeight),
        bodyMedium: TextStyle(fontFamily: fontFamily, height: urduHeight),
        bodySmall: TextStyle(fontFamily: fontFamily, height: urduHeight),
        labelLarge: TextStyle(fontFamily: fontFamily, height: urduHeight),
        labelMedium: TextStyle(fontFamily: fontFamily, height: urduHeight),
        labelSmall: TextStyle(fontFamily: fontFamily, height: urduHeight),
      );
    }

    return TextTheme(
      displayLarge: TextStyle(fontFamily: fontFamily),
      displayMedium: TextStyle(fontFamily: fontFamily),
      displaySmall: TextStyle(fontFamily: fontFamily),
      headlineLarge: TextStyle(fontFamily: fontFamily),
      headlineMedium: TextStyle(fontFamily: fontFamily),
      headlineSmall: TextStyle(fontFamily: fontFamily),
      titleLarge: TextStyle(fontFamily: fontFamily),
      titleMedium: TextStyle(fontFamily: fontFamily),
      titleSmall: TextStyle(fontFamily: fontFamily),
      bodyLarge: TextStyle(fontFamily: fontFamily),
      bodyMedium: TextStyle(fontFamily: fontFamily),
      bodySmall: TextStyle(fontFamily: fontFamily),
      labelLarge: TextStyle(fontFamily: fontFamily),
      labelMedium: TextStyle(fontFamily: fontFamily),
      labelSmall: TextStyle(fontFamily: fontFamily),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final localeCode = languageProvider.currentLocale.languageCode;
    final TextTheme currentTextTheme = _getTextTheme(localeCode);

    return InternetChecker(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Madarsa Connect',
        locale: languageProvider.currentLocale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('hi'), Locale('ur')],
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
              child: child!,
            ),
          );
        },
        theme: ThemeData(
          primarySwatch: Colors.red,
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
          textTheme: currentTextTheme,
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: Colors.redAccent,
            selectionColor: Color(0x4DFF5252),
            selectionHandleColor: Colors.redAccent,
          ),
        ),
        initialRoute: '/',
        routes: {'/': (context) => const SplashScreen(), ...appRoutes},
      ),
    );
  }
}

class LanguageProvider extends ChangeNotifier {
  Locale _currentLocale;

  LanguageProvider(String? initialLanguageCode)
    : _currentLocale = Locale(initialLanguageCode ?? 'en');

  Locale get currentLocale => _currentLocale;

  Future<void> changeLocale(String languageCode) async {
    if (_currentLocale.languageCode == languageCode) return;

    _currentLocale = Locale(languageCode);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
  }
}

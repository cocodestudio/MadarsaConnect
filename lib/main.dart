import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:madarsaConnect/Data/check_internet.dart';
import 'package:madarsaConnect/Main%20Screen/splash_screen.dart';
import 'package:madarsaConnect/utils/app_usage_tracker.dart';
import 'Data/main_page.dart';
import 'Home Screen/upload_provider.dart';
import 'Main Screen/search_map.dart';
import 'package:provider/provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
late FirebaseAnalytics analytics;
FirebaseAnalyticsObserver? analyticsObserver;
final AppUsageTracker usageTracker = AppUsageTracker();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ProfileProvider()),
        ChangeNotifierProvider(create: (context) => UploadProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return InternetChecker(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'MadarsaConnect',
        theme: ThemeData(
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: Colors.grey,
            selectionColor: Colors.grey.shade800,
            selectionHandleColor: Colors.grey,
          ),
        ),
        navigatorObservers: [if (analyticsObserver != null) analyticsObserver!],
        initialRoute: '/',
        routes: {'/': (context) => const SplashScreen(), ...appRoutes},
      ),
    );
  }
}

class LocaleProvider with ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }
}

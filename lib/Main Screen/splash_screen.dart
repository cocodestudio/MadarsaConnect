import 'dart:async';
import 'dart:io';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Data/main_page.dart';
import '../Login & Signup Screen/loginpage.dart';
import '../l10n/app_localizations.dart';
import 'admin_screen.dart';
import 'on_boarding.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../main.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

enum SplashScreenState { loading, noInternet, error }

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final FirebaseAuth _auth;
  late final FirebaseFirestore _firestore;
  SplashScreenState _currentState = SplashScreenState.loading;

  @override
  void initState() {
    super.initState();
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    if (!mounted) return;

    setState(() {
      _currentState = SplashScreenState.loading;
    });

    try {
      final hasInternet = await _hasInternet();
      if (!hasInternet) {
        if (mounted) {
          setState(() => _currentState = SplashScreenState.noInternet);
        }
        return;
      }

      final initializationFuture = _initializeAppServices();
      final delayFuture = Future.delayed(const Duration(seconds: 2));

      await Future.wait([initializationFuture, delayFuture]);

      final nextScreen = await _determineNextScreen();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, _, __) => nextScreen,
            transitionsBuilder: (context, animation, _, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _currentState = SplashScreenState.error);
    }
  }

  Future<void> _initializeNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permission');

      try {
        await messaging.subscribeToTopic("all_users");
        debugPrint("Successfully subscribed to 'all_users' topic");
      } catch (e) {
        debugPrint("Failed to subscribe to 'all_users' topic: $e");
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null) {
          flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: '@drawable/notification_icon',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
          );
        }
      });
    } else {
      debugPrint('User declined or has not accepted permission');
    }
  }

  Future<void> _initializeAppServices() async {
    _auth = FirebaseAuth.instance;
    _firestore = FirebaseFirestore.instance;
    analytics = FirebaseAnalytics.instance;
    analyticsObserver = FirebaseAnalyticsObserver(analytics: analytics);
    usageTracker.startTracking();
    await _initializeNotifications();

    if (kReleaseMode) {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
      );
    } else {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
      );
    }
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<Widget> _determineNextScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('onBoardingShown') ?? false;
    if (!hasSeenOnboarding) {
      return const Onboarding();
    }

    final user = _auth.currentUser;
    if (user == null) {
      return const LoginPage();
    }
    String? role = prefs.getString('user_role');
    if (role == null) {
      try {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists && userDoc.data()!.containsKey('role')) {
          role = userDoc.data()!['role'] as String?;
          if (role != null) {
            await prefs.setString('user_role', role);
          }
        }
      } catch (e) {
        debugPrint("Error fetching role, signing out: $e");
        await _auth.signOut();
        return const LoginPage();
      }
    }

    if (role != null) {
      if (role == 'Admin') {
        return const AdminSupportScreen();
      }
      return MainPage(userRole: role);
    } else {
      await _auth.signOut();
      return const LoginPage();
    }
  }

  Widget _buildErrorUI() {
    String message;
    if (_currentState == SplashScreenState.noInternet) {
      message = AppLocalizations.of(context)!.noInternet;
    } else {
      message = AppLocalizations.of(context)!.somethingWentWrongSplash;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.4),
        Text(
          message,
          style: const TextStyle(fontSize: 16, color: Colors.black54),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.refresh, color: Colors.white),
          label: Text(
            AppLocalizations.of(context)!.retry,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          onPressed: _initializeAndNavigate,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black87,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            elevation: 5,
            shadowColor: Colors.black.withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          Center(
            child: CircleAvatar(
              radius: screenHeight * 0.16,
              backgroundColor: Colors.transparent,
              backgroundImage: const AssetImage(
                'assets/images/splash_logo.png',
              ),
            ),
          ),
          SafeArea(
            top: false,
            left: false,
            right: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/cocode.png', height: 24),
                    const SizedBox(width: 8),
                    RichText(
                      textAlign: TextAlign.left,
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                        children: <TextSpan>[
                          TextSpan(
                            text: '${AppLocalizations.of(context)!.from}\n',
                          ),
                          const TextSpan(
                            text: 'CoCode Studio',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color:
                                  Colors
                                      .black54, // Explicitly set color to avoid default white in some themes
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child:
                _currentState == SplashScreenState.loading
                    ? const SizedBox.shrink()
                    : _buildErrorUI(),
          ),
        ],
      ),
    );
  }
}

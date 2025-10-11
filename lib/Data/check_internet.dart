import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../main.dart';
import 'dynamic_popup.dart';

class InternetChecker extends StatefulWidget {
  final Widget child;
  const InternetChecker({super.key, required this.child});

  @override
  State<InternetChecker> createState() => _InternetCheckerState();
}

class _InternetCheckerState extends State<InternetChecker>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool? _wasOnline;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndNotify();
    _startMonitoring();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkAndNotify();
      _startMonitoring();
    } else if (state == AppLifecycleState.paused) {
      _stopMonitoring();
    }
  }

  void _startMonitoring() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkAndNotify();
    });
  }

  void _stopMonitoring() {
    _timer?.cancel();
  }

  Future<void> _checkAndNotify() async {
    if (!mounted) return;

    final isOnline = await _hasInternet();
    if (_wasOnline == null) {
      setState(() {
        _wasOnline = isOnline;
      });
      return;
    }
    if (isOnline != _wasOnline) {
      print("Internet state changed! From '$_wasOnline' to '$isOnline'.");

      if (isOnline) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            _showBackOnlinePopup();
          }
        });
      } else {
        _showNoInternetPopup();
      }
      setState(() {
        _wasOnline = isOnline;
      });
    }
  }

  void _showNoInternetPopup() {
    final overlayContext = navigatorKey.currentContext;
    if (overlayContext != null) {
      CustomPopup.show(overlayContext, "No Internet Connection");
    }
  }

  void _showBackOnlinePopup() {
    final overlayContext = navigatorKey.currentContext;
    if (overlayContext != null) {
      CustomPopup.show(overlayContext, "Back Online");
    }
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class InternetUtils {
  static Future<bool> hasInternet() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> checkAndRun({
    required BuildContext context,
    required Function() onConnected,
  }) async {
    final isOnline = await hasInternet();
    if (isOnline) {
      onConnected();
    } else {
      CustomPopup.show(context, "No Internet Connection");
    }
  }

  static Future<void> checkAndRunAsync({
    required BuildContext context,
    required Future<void> Function() onConnected,
  }) async {
    final isOnline = await hasInternet();
    if (isOnline) {
      await onConnected();
    } else {
      CustomPopup.show(context, "No Internet Connection");
    }
  }
}

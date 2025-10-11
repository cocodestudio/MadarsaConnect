import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class AppUsageTracker with WidgetsBindingObserver {
  static final AppUsageTracker _instance = AppUsageTracker._internal();
  factory AppUsageTracker() => _instance;

  AppUsageTracker._internal();

  // --- Keys for SharedPreferences ---
  static const String _dailyUsageSecondsKey = 'daily_usage_seconds';
  static const String _lastTrackedDateKey = 'last_tracked_date';
  static const String _weeklyHistoryKey = 'weekly_usage_history';

  Timer? _timer;
  bool _isInitialized = false;

  // --- Public Methods ---

  /// App shuru hone par isse call karein
  void startTracking() {
    if (_isInitialized) return;
    WidgetsBinding.instance.addObserver(this);
    _handleNewDayCheck(); // App khulte hi check karein
    _startTimer();
    _isInitialized = true;
  }

  /// Aaj ka usage seconds mein deta hai
  Future<double> getTodayUsageSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    await _handleNewDayCheck(); // Hamesha latest data ke liye check karein
    return prefs.getDouble(_dailyUsageSecondsKey) ?? 0.0;
  }

  /// Weekly usage seconds mein deta hai
  Future<double> getWeeklyUsageSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    await _handleNewDayCheck(); // Ensure data is archived if needed

    final history = prefs.getStringList(_weeklyHistoryKey) ?? [];
    double weeklyTotalSeconds = 0;
    final today = DateTime.now();

    // Pichhle 7 din ka data calculate karein
    for (String entry in history) {
      final parts = entry.split('|'); // Format: "2025-10-06|3600"
      if (parts.length == 2) {
        final date = DateTime.tryParse(parts[0]);
        final seconds = double.tryParse(parts[1]) ?? 0.0;
        if (date != null && today.difference(date).inDays < 7) {
          weeklyTotalSeconds += seconds;
        }
      }
    }
    // Aaj ka current usage bhi jodein
    weeklyTotalSeconds += await getTodayUsageSeconds();
    return weeklyTotalSeconds;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _handleNewDayCheck(); // App wapas aane par bhi check karein
      _startTimer();
    } else if (state == AppLifecycleState.paused) {
      _stopTimer();
    }
  }

  // --- Private Helper Methods ---

  void _startTimer() {
    // Agar timer pehle se chal raha hai to kuch na karein
    if (_timer?.isActive ?? false) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final prefs = await SharedPreferences.getInstance();
      double currentSeconds = prefs.getDouble(_dailyUsageSecondsKey) ?? 0.0;
      currentSeconds++;
      await prefs.setDouble(_dailyUsageSecondsKey, currentSeconds);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Check karta hai ki din badal gaya hai ya nahi
  Future<void> _handleNewDayCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final todayString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastDateString = prefs.getString(_lastTrackedDateKey);

    if (lastDateString != todayString) {
      // Din badal gaya hai!
      if (lastDateString != null) {
        // Pichle din ka data weekly history mein save karein
        final lastDaySeconds = prefs.getDouble(_dailyUsageSecondsKey) ?? 0.0;
        await _archiveDay(prefs, lastDateString, lastDaySeconds);
      }

      // Aaj ka counter reset karein
      await prefs.setString(_lastTrackedDateKey, todayString);
      await prefs.setDouble(_dailyUsageSecondsKey, 0.0);
    }
  }

  /// Din ka data weekly list mein save karta hai
  Future<void> _archiveDay(
    SharedPreferences prefs,
    String dateStr,
    double seconds,
  ) async {
    if (seconds <= 0) return; // Agar usage nahi hai to save na karein

    final history = prefs.getStringList(_weeklyHistoryKey) ?? [];
    final newEntry = '$dateStr|$seconds';

    // Purani entry (agar hai) to hata do
    history.removeWhere((entry) => entry.startsWith(dateStr));
    history.add(newEntry);

    // Sirf pichhle 7 din ka data rakhein
    while (history.length > 7) {
      history.removeAt(0);
    }

    await prefs.setStringList(_weeklyHistoryKey, history);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
  }
}

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Data/dynamic_popup.dart';
import '../Data/loader.dart';
import '../Data/main_page.dart';
import '../Home Screen/home_screen.dart';
import '../l10n/app_localizations.dart';
import '../utils/app_usage_tracker.dart';
import 'faculty_attendance_mark.dart';

class Course {
  final String id;
  final String name;
  final String code;
  final int duration;
  final List<Subject> subjects;

  Course({
    required this.id,
    required this.name,
    required this.code,
    required this.duration,
    this.subjects = const [],
  });
}

class Subject {
  final String name;
  final String code;

  Subject({required this.name, required this.code});
}

class DashboardScreen extends StatefulWidget {
  final bool showCourseSelectionOnly;

  const DashboardScreen({super.key, this.showCourseSelectionOnly = false});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool showSubjectSelection = false;
  bool showAttendanceScreen = false;
  bool showCourseSelectionOnly = false;
  Subject? selectedSubject;
  bool isLoading = true;
  String? selectedCourseId;
  Map<String, dynamic>? selectedCourse;
  int? selectedYear;
  String? headUid;
  List<Map<String, String>> _courses = [];
  double? todayUsageHours;

  @override
  void initState() {
    super.initState();
    _loadAllInitialData();
    if (widget.showCourseSelectionOnly) {
      showCourseSelectionOnly = true;
    }
  }

  Future<void> _loadAllInitialData() async {
    await _fetchHeadUid();

    if (headUid != null) {
      _courses = await fetchCourses();
    }
    final tracker = AppUsageTracker();
    final seconds = await tracker.getTodayUsageSeconds();
    todayUsageHours = seconds / 3600;

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchHeadUid() async {
    final prefs = await SharedPreferences.getInstance();
    final isHead = prefs.getBool('isHead') ?? false;
    final isFaculty = prefs.getBool('isFaculty') ?? false;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted)
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.userNotLoggedIn,
        );
      return;
    }

    if (isHead) {
      headUid = user.uid;
    } else if (isFaculty) {
      final facultyDoc =
          await FirebaseFirestore.instance
              .collection('Faculties')
              .doc(user.uid)
              .get();
      headUid = facultyDoc.data()?['headUid'];
    }

    if (headUid == null) {
      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.couldNotDetermineHead,
        );
      }
    }
  }

  void resetView() {
    if (mounted) {
      setState(() {
        showAttendanceScreen = false;
        selectedSubject = null;
      });
    }
  }

  Future<List<Map<String, String>>> fetchCourses() async {
    if (headUid == null) return [];

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('courses')
              .where('headUid', isEqualTo: headUid)
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name']?.toString() ?? '',
          'code': data['code']?.toString() ?? '',
          'duration': (data['duration'] ?? 1).toString(),
        };
      }).toList();
    } catch (e) {
      debugPrint("Error fetching courses: $e");
      return [];
    }
  }

  Widget _buildCourseList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children:
          _courses.map((course) {
            return InfoCard(
              title: course['name']!,
              subtitle: course['code']!,
              gradientColors: const [Color(0xFFFFF1DC), Color(0xFFE2C290)],
              onTap: () => _showDurationSelector(context, course),
            );
          }).toList(),
    );
  }

  Widget _buildSubjectList(Map<String, dynamic> course, int year) {
    // Year labels like '1st Year' are usually kept in English or handled with specific logic.
    // Here using basic localization helper.
    final yearLabel =
        '${year}${_getYearSuffix(year)} ${AppLocalizations.of(context)!.year}';

    return StreamBuilder(
      stream:
          FirebaseFirestore.instance
              .collection('subjects')
              .where('courseId', isEqualTo: course['id'])
              .where('year', isEqualTo: year)
              .where('headUid', isEqualTo: headUid)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: GradientSpinner());

        final subjects =
            snapshot.data!.docs.map((doc) {
              final data = doc.data();
              return Subject(name: data['name'], code: data['code']);
            }).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              yearLabel,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...subjects.map((subject) {
              return InfoCard(
                title: subject.name,
                subtitle: subject.code,
                gradientColors: const [Color(0xFFE3E4E5), Color(0xFFB5B5B5)],
                onTap: () {
                  setState(() {
                    selectedSubject = subject;
                    selectedCourseId = course['id'];
                    selectedYear = year;
                    showAttendanceScreen = true;
                  });
                },
              );
            }).toList(),
          ],
        );
      },
    );
  }

  String _getYearSuffix(int year) {
    if (year >= 11 && year <= 13) {
      return 'th';
    }
    switch (year % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  void _showDurationSelector(
    BuildContext context,
    Map<String, dynamic> course,
  ) {
    final duration = int.tryParse(course['duration'] ?? '1') ?? 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          height: screenHeight * 0.53,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  AppLocalizations.of(context)!.selectCourseDuration,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: GridView.builder(
                  itemCount: duration,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 70,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final year = index + 1;
                    final suffix = _getYearSuffix(year);
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          selectedCourse = course;
                          selectedYear = year;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: Center(
                          child: Text(
                            '$year$suffix ${AppLocalizations.of(context)!.year}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getAppBarTitle() {
    if (showAttendanceScreen && selectedSubject != null) {
      return selectedSubject!.name;
    } else if (selectedCourse != null && selectedYear != null) {
      return AppLocalizations.of(context)!.selectSubject;
    } else if (showCourseSelectionOnly) {
      return AppLocalizations.of(context)!.selectCourse;
    } else {
      return AppLocalizations.of(context)!.attendance;
    }
  }

  void _handleBackPress() {
    if (showAttendanceScreen) {
      resetView();
    } else if (selectedCourse != null) {
      if (mounted) {
        setState(() {
          selectedCourse = null;
          selectedYear = null;
        });
      }
    } else if (showCourseSelectionOnly) {
      if (mounted) setState(() => showCourseSelectionOnly = false);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _handleBackPress();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.grey.withOpacity(0.2),
          surfaceTintColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 26, color: Colors.black),
            onPressed: _handleBackPress,
          ),
          title: Text(
            _getAppBarTitle(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
        ),
        body:
            isLoading
                ? const Center(child: GradientSpinner())
                : (headUid == null
                    ? Center(
                      child: Text(
                        AppLocalizations.of(context)!.couldNotLoadData,
                      ),
                    )
                    : showAttendanceScreen &&
                        selectedSubject != null &&
                        selectedCourseId != null &&
                        selectedYear != null
                    ? AttendanceReviewScreen(
                      subjectName: selectedSubject!.name,
                      courseId: selectedCourseId!,
                      year: selectedYear!,
                      headUid: headUid!,
                    )
                    : showCourseSelectionOnly
                    ? (selectedCourse != null && selectedYear != null
                        ? _buildSubjectList(selectedCourse!, selectedYear!)
                        : _buildCourseList())
                    : SingleChildScrollView(
                      key: const ValueKey("DashboardMain"),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const TeachingHourSummary(),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                DashboardCard(
                                  title:
                                      AppLocalizations.of(
                                        context,
                                      )!.studentAttendance,
                                  subtitle:
                                      AppLocalizations.of(
                                        context,
                                      )!.trackStudentAttendance,
                                  gradientColors: const [
                                    Color(0xFFD4E7FE),
                                    Color(0xFFA0C4FF),
                                  ],
                                  onTap: () {
                                    setState(() {
                                      showCourseSelectionOnly = true;
                                    });
                                  },
                                ),
                                const SizedBox(height: 15),
                                DashboardCard(
                                  title:
                                      AppLocalizations.of(
                                        context,
                                      )!.facultyAttendance,
                                  subtitle:
                                      AppLocalizations.of(
                                        context,
                                      )!.trackFacultyAttendance,
                                  gradientColors: const [
                                    Color(0xFFD1FAE5),
                                    Color(0xFFA7F3D0),
                                  ],
                                  onTap: () {
                                    navigateWithPremiumTransition(
                                      context,
                                      const MarkFacultyAttendanceScreen(),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
      ),
    );
  }
}

class DashboardCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const DashboardCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  State<DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<DashboardCard> {
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => isPressed = true);
      },
      onTapUp: (_) => setState(() => isPressed = false),
      onTapCancel: () => setState(() => isPressed = false),
      child: AnimatedScale(
        scale: isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.22,
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: widget.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.gradientColors.first.withOpacity(0.5),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 22,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.subtitle,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TeachingHourSummary extends StatefulWidget {
  const TeachingHourSummary({super.key});

  @override
  State<TeachingHourSummary> createState() => _TeachingHourSummaryState();
}

class _TeachingHourSummaryState extends State<TeachingHourSummary> {
  double todayHours = 0;
  double weeklyHours = 0;
  Timer? _uiUpdateTimer;
  final AppUsageTracker _tracker = AppUsageTracker();

  @override
  void initState() {
    super.initState();
    _tracker.startTracking();
    _startUiTimer();
  }

  @override
  void dispose() {
    _uiUpdateTimer?.cancel();
    super.dispose();
  }

  void _startUiTimer() {
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _updateUsageData();
    });
    _updateUsageData();
  }

  Future<void> _updateUsageData() async {
    final todaySeconds = await _tracker.getTodayUsageSeconds();
    final weekSeconds = await _tracker.getWeeklyUsageSeconds();

    if (mounted) {
      setState(() {
        todayHours = todaySeconds / 3600;
        weeklyHours = weekSeconds / 3600;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const double totalHoursInDay = 24;
    final double workingPercent =
        (todayHours / totalHoursInDay).isNaN
            ? 0.0
            : (todayHours / totalHoursInDay);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(23),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.teachingHourSummary,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                CircularPercentIndicator(
                  radius: 55.0,
                  lineWidth: 25.0,
                  percent: workingPercent.clamp(0, 1),
                  center: const Text(""),
                  circularStrokeCap: CircularStrokeCap.round,
                  backgroundColor: Colors.blue.shade400,
                  progressColor: Colors.amber.shade600,
                  animation: true,
                  animationDuration: 800,
                ),
                const SizedBox(width: 40),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 5,
                          backgroundColor: Colors.amber.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)!.todaySpendTime,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    Text(
                      "${todayHours.toStringAsFixed(2)} ${AppLocalizations.of(context)!.hrs}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 5,
                          backgroundColor: Colors.blue.shade400,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)!.weeklySpendTime,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    Text(
                      "${weeklyHours.toStringAsFixed(2)} ${AppLocalizations.of(context)!.hrs}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class InfoCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const InfoCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  State<InfoCard> createState() => _InfoCardState();
}

class _InfoCardState extends State<InfoCard> {
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final screenHeight = media.size.height;
    final textScale = media.textScaleFactor.clamp(1.0, 1.2);

    final isAttendance = widget.subtitle.toLowerCase().contains("attendance");

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => isPressed = true);
      },
      onTapUp: (_) => setState(() => isPressed = false),
      onTapCancel: () => setState(() => isPressed = false),
      child: AnimatedScale(
        scale: isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: screenHeight * 0.12,
          width: double.infinity,
          margin: EdgeInsets.symmetric(vertical: screenWidth * 0.02),
          padding:
              isAttendance
                  ? EdgeInsets.symmetric(
                    vertical: screenWidth * 0.025,
                    horizontal: screenWidth * 0.05,
                  )
                  : EdgeInsets.all(screenWidth * 0.045),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: widget.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.gradientColors.first.withOpacity(0.5),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textScaleFactor: textScale,
                style: TextStyle(
                  fontSize: screenWidth * 0.05,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: screenWidth * 0.012),
              Text(
                widget.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textScaleFactor: textScale,
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AttendanceReviewScreen extends StatefulWidget {
  final String subjectName;
  final String courseId;
  final int year;
  final String headUid;

  const AttendanceReviewScreen({
    super.key,
    required this.subjectName,
    required this.courseId,
    required this.year,
    required this.headUid,
  });

  @override
  State<AttendanceReviewScreen> createState() => _AttendanceReviewScreenState();
}

class _AttendanceReviewScreenState extends State<AttendanceReviewScreen> {
  List<Map<String, dynamic>> students = [];
  Map<String, bool> attendance = {};
  bool isLoading = true;
  bool isHeaderChecked = false;
  String selectedHeaderStatus = 'Present';
  int presentCount = 0;
  int absentCount = 0;
  bool isSessionActive = false;
  String sessionStatusMessage = '';
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  void updateCounts() {
    presentCount = attendance.values.where((v) => v).length;
    absentCount = attendance.length - presentCount;
  }

  @override
  void initState() {
    super.initState();
    checkSessionAndFetchStudents();
    _loadBannerAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-2465407468425782/8176087690',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          print('Failed to load a banner ad: ${err.message}');
          _isBannerAdReady = false;
          ad.dispose();
        },
      ),
    );

    _bannerAd?.load();
  }

  void showSuccessFullScreenDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Success',
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: curved,
            child: Scaffold(
              backgroundColor: Colors.white,
              body: SafeArea(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            height: 150,
                            width: 150,
                            child: Icon(
                              Icons.verified,
                              size: 100,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            AppLocalizations.of(context)!.successfullySubmitted,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize:
                                  MediaQuery.of(context).size.width * 0.05,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 50.0),
                        child: Column(
                          children: [
                            if (_isBannerAdReady && _bannerAd != null)
                              SizedBox(
                                width: _bannerAd!.size.width.toDouble(),
                                height: _bannerAd!.size.height.toDouble(),
                                child: AdWidget(ad: _bannerAd!),
                              ),
                            if (_isBannerAdReady) const SizedBox(height: 20),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => const MainPage(),
                                  ),
                                  (route) => false,
                                );
                              },
                              child: Container(
                                alignment: Alignment.center,
                                width: double.infinity,
                                height:
                                    MediaQuery.of(context).size.height * 0.060,
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Text(
                                  AppLocalizations.of(context)!.done,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                  ),
                                ),
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
          ),
        );
      },
    );
  }

  Future<void> checkSessionAndFetchStudents() async {
    setState(() => isLoading = true);
    final today = DateTime.now();

    final sessionsSnapshot =
        await FirebaseFirestore.instance
            .collection('sessions')
            .where('headUid', isEqualTo: widget.headUid)
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

    if (sessionsSnapshot.docs.isEmpty) {
      if (mounted) {
        setState(() {
          isSessionActive = false;
          isLoading = false;
          sessionStatusMessage = AppLocalizations.of(context)!.noActiveSession;
        });
      }
      return;
    }

    final sessionDoc = sessionsSnapshot.docs.first.data();
    final startDate = (sessionDoc['startDate'] as Timestamp).toDate();
    final endDate = (sessionDoc['endDate'] as Timestamp).toDate();

    if (today.isAfter(startDate.subtract(const Duration(days: 1))) &&
        today.isBefore(endDate.add(const Duration(days: 1)))) {
      if (mounted) {
        setState(() {
          isSessionActive = true;
          sessionStatusMessage = '';
        });
      }
      fetchStudents();
    } else {
      if (mounted) {
        setState(() {
          isSessionActive = false;
          isLoading = false;
          sessionStatusMessage = AppLocalizations.of(
            context,
          )!.attendanceDateRangeError(
            DateFormat('d MMM').format(startDate),
            DateFormat('d MMM').format(endDate),
          );
        });
      }
    }
  }

  Future<void> fetchStudents() async {
    final facultyUid = FirebaseAuth.instance.currentUser?.uid;

    if (facultyUid == null) {
      if (mounted)
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.noFacultyLoggedIn,
        );
      if (mounted) setState(() => isLoading = false);
      return;
    }

    final courseDoc =
        await FirebaseFirestore.instance
            .collection('courses')
            .doc(widget.courseId)
            .get();

    final courseName = courseDoc.data()?['name']?.toString().trim();
    final yearSuffix = ['st', 'nd', 'rd', 'th'];
    final durationString = '${widget.year}${yearSuffix[widget.year - 1]} Year';

    if (courseName == null || courseName.isEmpty) {
      if (mounted) setState(() => isLoading = false);
      if (mounted)
        CustomPopup.show(context, AppLocalizations.of(context)!.courseNotFound);
      return;
    }

    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final attendanceSnapshot =
        await FirebaseFirestore.instance
            .collection('attendance')
            .where('date', isEqualTo: date)
            .where('subject', isEqualTo: widget.subjectName)
            .where('headUid', isEqualTo: widget.headUid)
            .get();

    Map<String, String> statusMap = {};
    for (var doc in attendanceSnapshot.docs) {
      final data = doc.data();
      statusMap[data['student_uid']] = data['status'];
    }

    final studentSnapshot =
        await FirebaseFirestore.instance
            .collection('Students')
            .where('headUid', isEqualTo: widget.headUid)
            .where('course', isEqualTo: courseName)
            .where('courseDuration', isEqualTo: durationString)
            .get();

    students =
        studentSnapshot.docs.map((doc) {
          final data = doc.data();
          final studentUid = doc.id;
          attendance[studentUid] =
              statusMap.containsKey(studentUid)
                  ? (statusMap[studentUid] == 'Present')
                  : true;

          return {
            'uid': studentUid,
            'fullName': data['fullName'] ?? '',
            'rollNo': data['rollNo'] ?? 0,
          };
        }).toList();

    students.sort((a, b) => (a['rollNo'] as int).compareTo(b['rollNo'] as int));

    if (mounted) {
      setState(() {
        isLoading = false;
        updateCounts();
      });
    }
  }

  void toggleAttendance(String uid) {
    if (mounted) {
      setState(() {
        attendance[uid] = !(attendance[uid] ?? true);
        updateCounts();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    if (!isSessionActive) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            sessionStatusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body:
          isLoading
              ? const Center(child: GradientSpinner())
              : Padding(
                padding: EdgeInsets.all(w * 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CourseCard(
                      title: '',
                      subtitle: '',
                      gradientColors: [
                        const Color(0xFFFFF1DC),
                        const Color(0xFFE2C290),
                      ],
                      present: presentCount,
                      absent: absentCount,
                      onTap: () {},
                    ),
                    SizedBox(height: h * 0.012),
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: isHeaderChecked,
                                onChanged: (value) {
                                  if (mounted) {
                                    setState(() {
                                      isHeaderChecked = value!;
                                      for (var uid in attendance.keys) {
                                        attendance[uid] =
                                            isHeaderChecked
                                                ? selectedHeaderStatus ==
                                                    'Present'
                                                : false;
                                      }
                                      updateCounts();
                                    });
                                  }
                                },
                              ),
                              Container(
                                width: w * 0.3,
                                height: h * 0.045,
                                padding: EdgeInsets.symmetric(
                                  horizontal: w * 0.03,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade400,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.shade200,
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedHeaderStatus,
                                    dropdownColor: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    isExpanded: true,
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                    ),
                                    items:
                                        ['Present', 'Absent']
                                            .map(
                                              (value) => DropdownMenuItem(
                                                value: value,
                                                child: Text(
                                                  value == 'Present'
                                                      ? AppLocalizations.of(
                                                        context,
                                                      )!.present
                                                      : AppLocalizations.of(
                                                        context,
                                                      )!.absent,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        if (mounted) {
                                          setState(() {
                                            selectedHeaderStatus = value;
                                            if (isHeaderChecked) {
                                              for (var uid in attendance.keys) {
                                                attendance[uid] =
                                                    value == 'Present';
                                              }
                                            }
                                            updateCounts();
                                          });
                                        }
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: w * 0.03,
                              vertical: h * 0.01,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    AppLocalizations.of(context)!.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: w * 0.035,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    AppLocalizations.of(context)!.rollNo,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: w * 0.035,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    AppLocalizations.of(context)!.status,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: w * 0.035,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: students.length,
                              itemBuilder: (context, index) {
                                final student = students[index];
                                final isPresent =
                                    attendance[student['uid']] ?? false;
                                final rollNoStr = student['rollNo']
                                    .toString()
                                    .padLeft(3, '0');

                                return Container(
                                  margin: EdgeInsets.symmetric(
                                    vertical: w * 0.02,
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    vertical: w * 0.03,
                                    horizontal: w * 0.03,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              student['fullName'],
                                              style: TextStyle(
                                                fontSize: w * 0.035,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Align(
                                              alignment: Alignment.center,
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: w * 0.015,
                                                  horizontal: w * 0.03,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue[100],
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  rollNoStr,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: w * 0.035,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap:
                                                  () => toggleAttendance(
                                                    student['uid'],
                                                  ),
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 300,
                                                ),
                                                curve: Curves.easeInOut,
                                                height: w * 0.08,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      isPresent
                                                          ? Colors.green
                                                          : Colors.red,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    Align(
                                                      alignment:
                                                          isPresent
                                                              ? Alignment
                                                                  .centerLeft
                                                              : Alignment
                                                                  .centerRight,
                                                      child: Padding(
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              horizontal:
                                                                  w * 0.01,
                                                            ),
                                                        child: Container(
                                                          width: w * 0.045,
                                                          height: w * 0.045,
                                                          decoration:
                                                              const BoxDecoration(
                                                                shape:
                                                                    BoxShape
                                                                        .circle,
                                                                color:
                                                                    Colors
                                                                        .white,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                    Center(
                                                      child: Text(
                                                        isPresent
                                                            ? AppLocalizations.of(
                                                              context,
                                                            )!.present
                                                            : AppLocalizations.of(
                                                              context,
                                                            )!.absent,
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: w * 0.03,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: h * 0.012),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder:
                                (_) => const Center(child: GradientSpinner()),
                          );

                          final facultyUid =
                              FirebaseAuth.instance.currentUser?.uid ?? '';
                          final subject = widget.subjectName;
                          final courseId = widget.courseId;
                          final year = widget.year;
                          final headUid = widget.headUid;
                          final yearSuffix = ['st', 'nd', 'rd', 'th'];
                          final duration =
                              '${year}${yearSuffix[year - 1]} Year';
                          final date = DateFormat(
                            'yyyy-MM-dd',
                          ).format(DateTime.now());

                          final sessionsSnapshot =
                              await FirebaseFirestore.instance
                                  .collection('sessions')
                                  .where('headUid', isEqualTo: headUid)
                                  .orderBy('createdAt', descending: true)
                                  .limit(1)
                                  .get();

                          String? sessionId;
                          if (sessionsSnapshot.docs.isNotEmpty) {
                            sessionId = sessionsSnapshot.docs.first.id;
                          }

                          final courseDoc =
                              await FirebaseFirestore.instance
                                  .collection('courses')
                                  .doc(courseId)
                                  .get();

                          final courseName = courseDoc['name'] ?? 'Unknown';

                          for (var student in students) {
                            final studentUid = student['uid'];
                            final isPresent = attendance[studentUid] ?? true;
                            final rollNo = student['rollNo'] ?? 0;

                            final docRef = FirebaseFirestore.instance
                                .collection('attendance')
                                .doc('${studentUid}_${subject}_$date');

                            await docRef.set({
                              'student_uid': studentUid,
                              'headUid': headUid,
                              'course_name': courseName,
                              'course_id': courseId,
                              'subject': subject,
                              'roll_no': rollNo,
                              'course_duration': duration,
                              'date': date,
                              'status': isPresent ? 'Present' : 'Absent',
                              'marked_by': facultyUid,
                              'timestamp': FieldValue.serverTimestamp(),
                              'sessionId': sessionId,
                            }, SetOptions(merge: true));
                          }
                          if (mounted) Navigator.pop(context);
                          if (mounted) showSuccessFullScreenDialog(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: h * 0.018),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.confirmSubmitAttendance,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: w * 0.04,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}

class CourseCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final int present;
  final int absent;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const CourseCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.present,
    required this.absent,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  State<CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<CourseCard> {
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => isPressed = true);
      },
      onTapUp: (_) => setState(() => isPressed = false),
      onTapCancel: () => setState(() => isPressed = false),
      child: AnimatedScale(
        scale: isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.22,
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: widget.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.gradientColors.first.withOpacity(0.5),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Text(
                    '${widget.present} ',
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width * 0.11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.present,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '${widget.absent} ',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.absent,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

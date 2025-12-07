import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../Data/dynamic_popup.dart';
import '../Data/loader.dart';
import '../Faculty Screen/attendance_f.dart';
import '../l10n/app_localizations.dart';
import '../utils/app_usage_tracker.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.grey.withOpacity(0.2),
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.attendance,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold, // Replaced Gilroy-Bold
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const AdminHourSummary(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView(
                  children: [
                    // DashboardCard(
                    //   title: AppLocalizations.of(context)!.facultyAttendance,
                    //   subtitle: AppLocalizations.of(context)!.markDailyAttendance,
                    //   gradientColors: const [
                    //     Color(0xFFE3E4E5),
                    //     Color(0xFFB5B5B5),
                    //   ],
                    //   onTap: () {
                    //     Navigator.push(
                    //       context,
                    //       MaterialPageRoute(
                    //         builder: (_) => const FacultyAttendanceScreen(),
                    //       ),
                    //     );
                    //   },
                    // ),
                    const SizedBox(height: 20),
                    DashboardCard(
                      title: AppLocalizations.of(context)!.studentView,
                      subtitle:
                          AppLocalizations.of(
                            context,
                          )!.viewStudentAttendanceRecords,
                      gradientColors: const [
                        Color(0xFFFFE4E1),
                        Color(0xFFB76E79),
                      ],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StudentAttScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
          height: 180,
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: widget.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.gradientColors.first.withOpacity(0.4),
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
                  fontSize: 20,
                  color: Colors.black,
                  fontWeight: FontWeight.bold, // Replaced Gilroy-Bold
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  // Replaced Gilroy-Regular
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FacultyAttendanceScreen extends StatefulWidget {
  const FacultyAttendanceScreen({super.key});

  @override
  State<FacultyAttendanceScreen> createState() =>
      _FacultyAttendanceScreenState();
}

class _FacultyAttendanceScreenState extends State<FacultyAttendanceScreen> {
  List<Map<String, dynamic>> facultyList = [];
  Map<String, bool> attendance = {};
  bool isLoading = true;
  bool isHeaderChecked = false;
  String selectedHeaderStatus = 'Present';
  String? headUid;
  String? sessionId;

  int presentCount = 0;
  int absentCount = 0;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void updateCounts() {
    presentCount = attendance.values.where((v) => v).length;
    absentCount = attendance.length - presentCount;
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => isLoading = true);
    await _loadHeadUid();
    if (headUid != null) {
      await _fetchCurrentSession();
      await fetchFaculty();
    }
    setState(() {
      isLoading = false;
      updateCounts();
    });
  }

  Future<void> _loadHeadUid() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      headUid = currentUser.uid;
    }
  }

  Future<void> _fetchCurrentSession() async {
    if (headUid == null) return;
    try {
      final sessionSnap =
          await _firestore
              .collection('sessions')
              .where('headUid', isEqualTo: headUid)
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();

      if (sessionSnap.docs.isNotEmpty) {
        sessionId = sessionSnap.docs.first.id;
      }
    } catch (e) {
      CustomPopup.show(
        context,
        '${AppLocalizations.of(context)!.errorFetchingSession}: $e',
      );
    }
  }

  Future<void> fetchFaculty() async {
    if (headUid == null) {
      setState(() => isLoading = false);
      return;
    }

    setState(() => isLoading = true);
    try {
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final attendanceSnapshot =
          await _firestore
              .collection('faculty_attendance')
              .where('date', isEqualTo: date)
              .where('marked_by', isEqualTo: headUid)
              .get();

      Map<String, String> statusMap = {};
      for (var doc in attendanceSnapshot.docs) {
        final data = doc.data();
        statusMap[data['faculty_id']] = data['status'];
      }

      final snapshot =
          await _firestore
              .collection('Faculties')
              .where('headUid', isEqualTo: headUid)
              .get();

      facultyList =
          snapshot.docs.map((doc) {
            final data = doc.data();
            final fucId = doc.id;
            final name = data['fullName'] ?? '';

            attendance[fucId] =
                statusMap.containsKey(fucId)
                    ? (statusMap[fucId] == 'Present')
                    : true;

            return {'id': fucId, 'name': name};
          }).toList();
    } catch (e) {
      CustomPopup.show(
        context,
        '${AppLocalizations.of(context)!.errorFetchingFaculty}: $e',
      );
    }

    setState(() {
      isLoading = false;
      updateCounts();
    });
  }

  void toggleAttendance(String id) {
    setState(() {
      attendance[id] = !(attendance[id] ?? true);
      updateCounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body:
          isLoading
              ? const Center(child: GradientSpinner())
              : Padding(
                padding: EdgeInsets.all(w * 0.05),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CourseCard(
                        title: '',
                        subtitle: '',
                        gradientColors: [Color(0xFFDDE8FF), Color(0xFFB7CCF9)],
                        present: presentCount,
                        absent: absentCount,
                        onTap: () {},
                      ),
                      SizedBox(height: h * 0.012),
                      Row(
                        children: [
                          Checkbox(
                            value: isHeaderChecked,
                            onChanged: (value) {
                              setState(() {
                                isHeaderChecked = value!;
                                for (var id in attendance.keys) {
                                  attendance[id] =
                                      isHeaderChecked
                                          ? selectedHeaderStatus == 'Present'
                                          : false;
                                }
                                updateCounts();
                              });
                            },
                          ),
                          Container(
                            width: w * 0.3,
                            height: h * 0.045,
                            padding: EdgeInsets.symmetric(horizontal: w * 0.03),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade400),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade200,
                                  blurRadius: 5,
                                  offset: Offset(0, 2),
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
                                                fontWeight:
                                                    FontWeight
                                                        .bold, // Replaced Gilroy-Bold
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      selectedHeaderStatus = value;
                                      if (isHeaderChecked) {
                                        for (var id in attendance.keys) {
                                          attendance[id] = value == 'Present';
                                        }
                                        updateCounts();
                                      }
                                    });
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
                              flex: 5,
                              child: Text(
                                AppLocalizations.of(context)!.name,
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold, // Replaced Gilroy-Bold
                                  fontSize: w * 0.035,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 5,
                              child: Text(
                                AppLocalizations.of(context)!.status,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold, // Replaced Gilroy-Bold
                                  fontSize: w * 0.035,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: facultyList.length,
                          itemBuilder: (context, index) {
                            final faculty = facultyList[index];
                            final isPresent =
                                attendance[faculty['id']] ?? false;

                            return Container(
                              margin: EdgeInsets.symmetric(vertical: w * 0.02),
                              padding: EdgeInsets.symmetric(
                                vertical: w * 0.03,
                                horizontal: w * 0.03,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Text(
                                      faculty['name'],
                                      style: TextStyle(fontSize: w * 0.035),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: GestureDetector(
                                      onTap:
                                          () => toggleAttendance(faculty['id']),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeInOut,
                                        height: w * 0.10,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              isPresent
                                                  ? Colors.green
                                                  : Colors.red,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Align(
                                              alignment:
                                                  isPresent
                                                      ? Alignment.centerLeft
                                                      : Alignment.centerRight,
                                              child: Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: w * 0.01,
                                                ),
                                                child: Container(
                                                  width: w * 0.060,
                                                  height: w * 0.060,
                                                  decoration:
                                                      const BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: Colors.white,
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
                                                      FontWeight
                                                          .bold, // Replaced Gilroy-Bold
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
                            );
                          },
                        ),
                      ),
                      SizedBox(height: h * 0.012),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (sessionId == null) {
                              CustomPopup.show(
                                context,
                                AppLocalizations.of(
                                  context,
                                )!.noActiveSessionSave,
                              );
                              return;
                            }
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder:
                                  (_) => const Center(child: GradientSpinner()),
                            );

                            final date = DateFormat(
                              'yyyy-MM-dd',
                            ).format(DateTime.now());

                            for (var faculty in facultyList) {
                              final fucId = faculty['id'];
                              final name = faculty['name'] ?? '';
                              final isPresent = attendance[fucId] ?? true;

                              final docId = '${date}_$fucId';
                              final docRef = _firestore
                                  .collection('faculty_attendance')
                                  .doc(docId);

                              final docSnapshot = await docRef.get();

                              if (docSnapshot.exists) {
                                await docRef.update({
                                  'status': isPresent ? 'Present' : 'Absent',
                                  'sessionId': sessionId,
                                });
                              } else {
                                await docRef.set({
                                  'faculty_id': fucId,
                                  'name': name,
                                  'date': date,
                                  'status': isPresent ? 'Present' : 'Absent',
                                  'marked_by': headUid,
                                  'sessionId': sessionId,
                                });
                              }
                            }

                            Navigator.pop(context);
                            CustomPopup.show(
                              context,
                              AppLocalizations.of(context)!.attendanceSaved,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: h * 0.018),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(
                              context,
                            )!.confirmSubmitAttendance,
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold, // Replaced Gilroy-Bold
                              fontSize: w * 0.04,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}

class AdminHourSummary extends StatefulWidget {
  const AdminHourSummary({super.key});

  @override
  State<AdminHourSummary> createState() => _AdminHourSummaryState();
}

class _AdminHourSummaryState extends State<AdminHourSummary>
    with WidgetsBindingObserver {
  double todayHours = 0;
  double weeklyHours = 0;
  bool isLoading = true;
  Timer? _uiUpdateTimer;
  final AppUsageTracker _tracker = AppUsageTracker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tracker.startTracking();
    _startUiTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _uiUpdateTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _startUiTimer();
    }
  }

  void _startUiTimer() {
    _uiUpdateTimer?.cancel();
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
        if (isLoading) isLoading = false;
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

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(23),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.teachingHourSummary,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ), // Replaced Gilroy-Bold
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
                        fontWeight: FontWeight.bold, // Replaced Gilroy-Bold
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
                        fontWeight: FontWeight.bold, // Replaced Gilroy-Bold
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

class StudentAttScreen extends StatefulWidget {
  const StudentAttScreen({super.key});

  @override
  State<StudentAttScreen> createState() => _StudentAttScreenState();
}

class _StudentAttScreenState extends State<StudentAttScreen> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? studentData;
  int totalLectures = 0;
  int presentLectures = 0;
  bool isLoading = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void searchById() async {
    setState(() {
      isLoading = true;
      studentData = null;
      totalLectures = 0;
      presentLectures = 0;
    });

    final inputId = _searchController.text.trim();
    if (inputId.isEmpty) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final lowercaseInputId = inputId.toLowerCase();
      final studentSnap =
          await _firestore
              .collection('Students')
              .where('sucId', isEqualTo: lowercaseInputId)
              .limit(1)
              .get();

      if (studentSnap.docs.isNotEmpty) {
        studentData = studentSnap.docs.first.data();
        final studentUid = studentSnap.docs.first.id;

        final attendanceSnap =
            await _firestore
                .collection('attendance')
                .where('student_uid', isEqualTo: studentUid)
                .get();

        totalLectures = attendanceSnap.docs.length;
        presentLectures =
            attendanceSnap.docs
                .where((doc) => doc.data()['status'] == 'Present')
                .length;
      } else {
        final facultySnap =
            await _firestore
                .collection('Faculties')
                .where('fucId', isEqualTo: lowercaseInputId)
                .limit(1)
                .get();

        if (facultySnap.docs.isNotEmpty) {
          studentData = facultySnap.docs.first.data();
          final facultyId = facultySnap.docs.first.id;

          final attendanceSnap =
              await _firestore
                  .collection('faculty_attendance')
                  .where('faculty_id', isEqualTo: facultyId)
                  .get();

          totalLectures = attendanceSnap.docs.length;
          presentLectures =
              attendanceSnap.docs
                  .where((doc) => doc.data()['status'] == 'Present')
                  .length;
        }
      }
    } catch (e) {
      print("❌ Error: $e");
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final double attendancePercent =
        totalLectures == 0 ? 0 : presentLectures / totalLectures;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.grey.withOpacity(0.2),
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.studentAttendance,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold, // Replaced Gilroy-Bold
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  top: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.overallAttendanceSummary,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ), // Replaced Gilroy-Bold
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        CircularPercentIndicator(
                          radius: 55.0,
                          lineWidth: 25.0,
                          percent: attendancePercent.clamp(0.0, 1.0),
                          center: Text(
                            "${(attendancePercent * 100).toStringAsFixed(1)}%",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
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
                            Text(
                              AppLocalizations.of(
                                context,
                              )!.totalPresentLectures,
                              style: const TextStyle(fontSize: 14),
                            ),
                            Text(
                              "$presentLectures ${AppLocalizations.of(context)!.lectures}",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.bold, // Replaced Gilroy-Bold
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(context)!.totalLectures,
                              style: const TextStyle(fontSize: 14),
                            ),
                            Text(
                              "$totalLectures ${AppLocalizations.of(context)!.lectures}",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.bold, // Replaced Gilroy-Bold
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchController,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  AppLocalizations.of(context)!.enterSucId,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: Colors.grey,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: Colors.black,
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : searchById,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child:
                                  isLoading
                                      ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : Text(
                                        AppLocalizations.of(context)!.search,
                                        style: const TextStyle(
                                          fontWeight:
                                              FontWeight
                                                  .bold, // Replaced Gilroy-Bold
                                          fontSize: 15,
                                          color: Colors.white,
                                        ),
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    if (studentData != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.white,
                              backgroundImage:
                                  (studentData!['profilePictureUrl'] != null &&
                                          studentData!['profilePictureUrl']
                                              .toString()
                                              .isNotEmpty)
                                      ? NetworkImage(
                                            studentData!['profilePictureUrl'],
                                          )
                                          as ImageProvider
                                      : null,
                              child:
                                  (studentData!['profilePictureUrl'] == null ||
                                          studentData!['profilePictureUrl']
                                              .toString()
                                              .isEmpty)
                                      ? SvgPicture.asset(
                                        'assets/icons/users.svg',
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.contain,
                                      )
                                      : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    studentData!['fullName'] ?? '',
                                    style: const TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .bold, // Replaced Gilroy-Bold
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (studentData!.containsKey('rollNo'))
                                    Text(
                                      "${AppLocalizations.of(context)!.rollNo}: ${studentData!['rollNo'] ?? ''}",
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  if (studentData!.containsKey('sucId'))
                                    Text(
                                      "${AppLocalizations.of(context)!.sucId}: ${studentData!['sucId'] ?? ''}",
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  if (studentData!.containsKey('fucId'))
                                    Text(
                                      "FUC ID: ${studentData!['fucId'] ?? ''}",
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  if (studentData!.containsKey('facultyId'))
                                    Text(
                                      "Faculty ID: ${studentData!['facultyId'] ?? ''}",
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

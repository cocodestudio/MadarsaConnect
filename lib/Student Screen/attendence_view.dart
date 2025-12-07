import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:intl/intl.dart';
import '../Data/loader.dart';
import '../l10n/app_localizations.dart';

class StudentViewAttendanceScreen extends StatefulWidget {
  const StudentViewAttendanceScreen({super.key});

  @override
  State<StudentViewAttendanceScreen> createState() =>
      _StudentViewAttendanceScreenState();
}

class _StudentViewAttendanceScreenState
    extends State<StudentViewAttendanceScreen> {
  bool isLoading = true;
  bool showSubjects = true;
  String studentUid = '';
  String? headUid;

  List<Map<String, dynamic>> allEnrollments = [];
  Map<String, dynamic>? selectedEnrollment;

  List<Map<String, dynamic>> attendanceHistory = [];
  int totalLectures = 0;
  int presentLectures = 0;
  double attendancePercentage = 0.0;
  List<DateTime> _allDatesInSession = [];

  List<Map<String, dynamic>> subjects = [];
  String? selectedSubjectName;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (mounted) setState(() => isLoading = true);

    await _fetchStudentAndEnrollments();

    if (selectedEnrollment != null) {
      _generateDatesInSession();
      await _fetchSubjectsForSelectedSession();
      await _fetchOverallAttendanceForSession();
    }

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _fetchStudentAndEnrollments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }
    studentUid = user.uid;

    List<Map<String, dynamic>> fetchedEnrollments = [];

    final studentDoc =
        await FirebaseFirestore.instance
            .collection('Students')
            .doc(studentUid)
            .get();

    if (studentDoc.exists && studentDoc.data() != null) {
      final data = studentDoc.data()!;
      headUid = data['headUid'] as String?;
      final currentCourse = {
        'courseName': (data['course'] as String?)?.trim(),
        'yearNumberCap': data['courseDurationNumber'] as int?,
        'academicYear': data['academicYear'] as String?,
        'isArchived': false,
      };
      final sessions = await _fetchSessionsForCourse(currentCourse);
      fetchedEnrollments.addAll(sessions);
    }

    final archivedSnap =
        await FirebaseFirestore.instance
            .collection('ArchivedEnrollments')
            .where('studentUid', isEqualTo: studentUid)
            .get();

    for (var doc in archivedSnap.docs) {
      final data = doc.data();
      final archivedCourse = {
        'courseName': data['courseName'] as String?,
        'yearNumberCap': data['academicYear'] as int?,
        'academicYear': data['academicYear']?.toString(),
        'isArchived': true,
      };
      final sessions = await _fetchSessionsForCourse(archivedCourse);
      fetchedEnrollments.addAll(sessions);
    }

    fetchedEnrollments.sort((a, b) {
      if (a['isArchived'] != b['isArchived']) {
        return a['isArchived'] ? 1 : -1;
      }
      return (b['startDate'] as DateTime).compareTo(a['startDate'] as DateTime);
    });

    setState(() {
      allEnrollments = fetchedEnrollments;
      if (allEnrollments.isNotEmpty) {
        selectedEnrollment = allEnrollments.firstWhere(
          (e) => !e['isArchived'],
          orElse: () => allEnrollments.first,
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> _fetchSessionsForCourse(
    Map<String, dynamic> courseData,
  ) async {
    if (headUid == null ||
        courseData['courseName'] == null ||
        courseData['academicYear'] == null) {
      return [];
    }

    try {
      final int year = int.tryParse(courseData['academicYear'].toString()) ?? 0;
      if (year == 0) return [];

      final startOfYear = DateTime(year);
      final endOfYear = DateTime(year + 1);

      final snap =
          await FirebaseFirestore.instance
              .collection('sessions')
              .where('headUid', isEqualTo: headUid)
              .where('course', isEqualTo: courseData['courseName'])
              .where(
                'yearNumber',
                isLessThanOrEqualTo: courseData['yearNumberCap'],
              )
              .where(
                'startDate',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear),
              )
              .where('startDate', isLessThan: Timestamp.fromDate(endOfYear))
              .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'courseName': courseData['courseName'],
          'isArchived': courseData['isArchived'],
          'term': data['term'] ?? 'Unnamed Term',
          'startDate': (data['startDate'] as Timestamp).toDate(),
          'endDate': (data['endDate'] as Timestamp).toDate(),
          'yearNumber': data['yearNumber'] ?? 0,
        };
      }).toList();
    } catch (e) {
      print("Error fetching sessions for ${courseData['courseName']}: $e");
      return [];
    }
  }

  void _generateDatesInSession() {
    _allDatesInSession = [];
    if (selectedEnrollment == null) return;
    final startDate = selectedEnrollment!['startDate'] as DateTime;
    final endDate = selectedEnrollment!['endDate'] as DateTime;
    for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
      _allDatesInSession.add(startDate.add(Duration(days: i)));
    }
  }

  Future<void> _fetchSubjectsForSelectedSession() async {
    if (selectedEnrollment == null || headUid == null) {
      if (mounted) setState(() => subjects = []);
      return;
    }
    try {
      final sessionCourseName = selectedEnrollment!['courseName'] as String?;
      final sessionYear = selectedEnrollment!['yearNumber'] as int? ?? 0;

      if (sessionCourseName == null || sessionYear == 0) {
        if (mounted) setState(() => subjects = []);
        return;
      }

      final snap =
          await FirebaseFirestore.instance
              .collection('subjects')
              .where('headUid', isEqualTo: headUid)
              .where('courseName', isEqualTo: sessionCourseName)
              .where('year', isEqualTo: sessionYear)
              .get();

      final list =
          snap.docs.map((d) {
            final m = d.data();
            return {
              'name': (m['name'] ?? '').toString(),
              'code': (m['code'] ?? '').toString(),
            };
          }).toList();
      list.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
      if (mounted) setState(() => subjects = list);
    } catch (e) {
      print("Error fetching subjects: $e");
      if (mounted) setState(() => subjects = []);
    }
  }

  Future<void> _fetchOverallAttendanceForSession() async {
    if (studentUid.isEmpty || selectedEnrollment == null) return;
    final snap =
        await FirebaseFirestore.instance
            .collection('attendance')
            .where('student_uid', isEqualTo: studentUid)
            .where('sessionId', isEqualTo: selectedEnrollment!['id'])
            .get();
    int present = 0;
    for (var doc in snap.docs) {
      final data = doc.data();
      if ((data['status'] ?? '').toString().trim().toLowerCase() == 'present') {
        present++;
      }
    }
    final int totalMarked = snap.docs.length;
    if (mounted) {
      setState(() {
        totalLectures = totalMarked;
        presentLectures = present;
        attendancePercentage = totalMarked == 0 ? 0.0 : present / totalMarked;
      });
    }
  }

  Future<void> _fetchAttendanceForSubject(String subjectName) async {
    if (studentUid.isEmpty || selectedEnrollment == null) return;
    if (mounted) setState(() => isLoading = true);
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('attendance')
              .where('student_uid', isEqualTo: studentUid)
              .where('sessionId', isEqualTo: selectedEnrollment!['id'])
              .where('subject', isEqualTo: subjectName)
              .get();
      int present = 0;
      final fetchedHistory = <Map<String, dynamic>>[];
      for (var doc in snap.docs) {
        final data = doc.data();
        final date = data['date'] as String?;
        final status = (data['status'] ?? '').toString().trim();
        if (date != null && date.isNotEmpty) {
          fetchedHistory.add({'date': date, 'status': status});
        }
        if (status.toLowerCase() == 'present') {
          present++;
        }
      }
      final int totalMarked = snap.docs.length;
      if (mounted) {
        setState(() {
          totalLectures = totalMarked;
          presentLectures = present;
          attendancePercentage = totalMarked == 0 ? 0.0 : present / totalMarked;
          attendanceHistory = fetchedHistory;
          showSubjects = false;
          selectedSubjectName = subjectName;
        });
      }
    } catch (e) {
      print("Error fetching subject attendance: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<bool> _handleBackNavigation() async {
    if (!showSubjects) {
      if (mounted) setState(() => isLoading = true);
      setState(() {
        showSubjects = true;
        selectedSubjectName = null;
        attendanceHistory = [];
      });
      await _fetchOverallAttendanceForSession();
      if (mounted) setState(() => isLoading = false);
      return false;
    }
    return true;
  }

  String _academicYearFromStart(DateTime start) {
    final startYear = start.year;
    final nextYY = ((startYear + 1) % 100).toString().padLeft(2, '0');
    return "$startYear-$nextYY";
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBackNavigation,
      child: Scaffold(
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
            AppLocalizations.of(context)!.viewAttendanceTitle,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child:
                    isLoading
                        ? const Center(child: GradientSpinner())
                        : allEnrollments.isEmpty
                        ? Center(
                          child: Text(
                            AppLocalizations.of(context)!.noAttendanceSessions,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.black54,
                            ),
                          ),
                        )
                        : Column(
                          children: [
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      CircularPercentIndicator(
                                        radius: 70.0,
                                        lineWidth: 24.0,
                                        percent: attendancePercentage.clamp(
                                          0.0,
                                          1.0,
                                        ),
                                        animation: true,
                                        animationDuration: 800,
                                        center: Text(
                                          "${(attendancePercentage * 100).toStringAsFixed(1)}%",
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        circularStrokeCap:
                                            CircularStrokeCap.round,
                                        backgroundColor: const Color(
                                          0xFFE1E4EC,
                                        ),
                                        progressColor: Colors.redAccent,
                                      ),
                                      const SizedBox(width: 24),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.present,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            "$presentLectures",
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            AppLocalizations.of(context)!.total,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            "$totalLectures",
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  GestureDetector(
                                    onTap: _showSessionDropdown,
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              selectedEnrollment != null
                                                  ? "${selectedEnrollment!['term']} (${_academicYearFromStart(selectedEnrollment!['startDate'])})"
                                                  : AppLocalizations.of(
                                                    context,
                                                  )!.selectSession,
                                              style: const TextStyle(
                                                fontSize: 16,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.arrow_drop_down,
                                            color: Colors.black54,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.grey.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      showSubjects
                                          ? AppLocalizations.of(
                                            context,
                                          )!.subjects
                                          : (selectedSubjectName ??
                                              AppLocalizations.of(
                                                context,
                                              )!.attendanceHistory),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Expanded(
                                      child:
                                          showSubjects
                                              ? _buildSubjectListView()
                                              : _buildAttendanceListView(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSessionDropdown() {
    final currentSessions =
        allEnrollments.where((s) => s['isArchived'] == false).toList();

    final Map<String, List<Map<String, dynamic>>> groupedArchived = {};
    for (var session in allEnrollments.where((s) => s['isArchived'] == true)) {
      final courseName = session['courseName'] as String;
      if (!groupedArchived.containsKey(courseName)) {
        groupedArchived[courseName] = [];
      }
      groupedArchived[courseName]!.add(session);
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            AppLocalizations.of(context)!.selectSessionTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (currentSessions.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 10.0,
                        bottom: 8,
                        top: 4,
                      ),
                      child: Text(
                        "${currentSessions.first['courseName']}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    ...currentSessions.map(
                      (session) => _buildSessionTile(session),
                    ),
                  ],
                  ...groupedArchived.entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 10.0,
                            bottom: 8,
                            top: 16,
                          ),
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        ...entry.value.map(
                          (session) => _buildSessionTile(session),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSessionTile(Map<String, dynamic> session) {
    final termName =
        "${session['term']} (${_academicYearFromStart(session['startDate'])})";
    final isSelected = selectedEnrollment?['id'] == session['id'];

    return InkWell(
      onTap: () async {
        Navigator.of(context).pop();
        if (!isSelected) {
          setState(() {
            selectedEnrollment = session;
            showSubjects = true;
            isLoading = true;
            selectedSubjectName = null;
          });
          _generateDatesInSession();
          await _fetchSubjectsForSelectedSession();
          await _fetchOverallAttendanceForSession();
          if (mounted) setState(() => isLoading = false);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? Colors.redAccent.withOpacity(0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          termName,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.redAccent : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectListView() {
    if (subjects.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noSubjectsFound));
    }
    return ListView.builder(
      itemCount: subjects.length,
      itemBuilder: (context, index) {
        final subject = subjects[index];
        final subjectName = subject['name'] ?? 'No Name';
        final subjectCode = subject['code'] ?? 'N/A';
        return GestureDetector(
          onTap: () {
            _fetchAttendanceForSubject(subjectName);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(
                color: Colors.grey.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subjectName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subjectCode,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttendanceListView() {
    if (_allDatesInSession.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context)!.noAttendanceRecords),
      );
    }
    Map<String, dynamic> attendanceMap = {
      for (var record in attendanceHistory) record['date']: record['status'],
    };

    return ListView.builder(
      itemCount: _allDatesInSession.length,
      itemBuilder: (context, index) {
        final date = _allDatesInSession[index];
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final status = attendanceMap[dateStr]?.toString() ?? 'Not Marked';
        final isPresent = status.toLowerCase() == 'present';
        final isMarked = status != 'Not Marked';

        String statusText;
        Color statusColor;
        Color statusBgColor;

        if (isMarked) {
          if (isPresent) {
            statusText = AppLocalizations.of(context)!.present;
            statusColor = const Color(0xFF4CAF50);
            statusBgColor = const Color(0xFF4CAF50).withOpacity(0.1);
          } else {
            statusText = AppLocalizations.of(context)!.absent;
            statusColor = const Color(0xFFF44336);
            statusBgColor = const Color(0xFFF44336).withOpacity(0.1);
          }
        } else {
          statusText = AppLocalizations.of(context)!.notMarked;
          statusColor = Colors.grey;
          statusBgColor = Colors.grey.withOpacity(0.1);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(color: Colors.grey.withOpacity(0.15), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMM dd, yyyy').format(date),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

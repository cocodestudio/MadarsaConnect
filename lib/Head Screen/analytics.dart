import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:pie_chart/pie_chart.dart' as pc;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int selectedCardIndex = 0;
  bool _isLoading = true;
  String? _headUid;
  String? _userRole;
  String? _studentUid;
  String selectedDateRange = "Current";
  DateTime? _selectedDate;
  int _totalStudents = 0;
  int _totalTeachers = 0;
  int _totalMadarsas = 0;
  double _totalPaidAmount = 0.0;
  double _totalDueAmount = 0.0;
  List<Map<String, dynamic>> _topMadarsas = [];
  List<Map<String, dynamic>> _topStudents = [];
  Map<String, int> _genderDistribution = {};
  Map<String, int> _ageDistribution = {};
  final Map<String, int> _courseCount = {};
  List<Map<String, dynamic>> _allStudents = [];
  final Map<String, Color> _courseColors = {};
  final List<Color> _palette = const [
    Color(0xFFB39DDB),
    Color(0xFFFFAB91),
    Color(0xFFFFEE58),
    Color(0xFF81D4FA),
    Color(0xFFEC407A),
    Color(0xFFFF7043),
    Color(0xFF26A69A),
    Color(0xFF9575CD),
    Color(0xFFFFD54F),
    Color(0xFF4DD0E1),
  ];
  int _paletteIndex = 0;
  List<Map<String, dynamic>> _inactiveStudents = [];
  List<Map<String, dynamic>> _pendingFeesStudents = [];
  int _paidFeesCount = 0;
  int _pendingFeesCount = 0;
  int _weeklyPresent = 0;
  int _weeklyTotal = 0;
  int _monthlyPresent = 0;
  int _monthlyTotal = 0;
  int _allTimePresent = 0;
  int _allTimeTotal = 0;

  void _assignColors(Set<String> courses) {
    final list =
        courses.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    for (final c in list) {
      if (_courseColors.containsKey(c)) continue;
      _courseColors[c] = _palette[_paletteIndex % _palette.length];
      _paletteIndex++;
    }
  }

  Color _colorForCourse(String course) {
    return _courseColors[course] ?? Colors.grey;
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    _checkUserRoleAndLoadData();
  }

  Future<void> _checkUserRoleAndLoadData() async {
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_role') ?? 'Unknown';
    _studentUid = FirebaseAuth.instance.currentUser?.uid;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      if (_userRole == "Head") {
        _headUid = uid;
      } else {
        // Faculty/Student ke liye Head UID profile se fetch karna hoga
        final collection = _userRole == "Faculty" ? "Faculties" : "Students";
        final snap =
            await FirebaseFirestore.instance
                .collection(collection)
                .doc(uid)
                .get();
        _headUid = snap.data()?['headUid'];
      }
    }

    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    if (_userRole == 'Head' && _headUid == null) {
      _headUid = FirebaseAuth.instance.currentUser?.uid;
    }

    try {
      if (selectedCardIndex == 0) {
        // Fetch data for the first tab
        await _fetchOverallCounts();
        await _fetchTopMadarsas();
      } else if (selectedCardIndex == 1) {
        // Fetch data for the second tab
        await _fetchStudentDataForAcademics();
        _calculateCourseCompletion();
        _calculateGenderDistribution();
        _calculateAgeDistribution();
        await _calculateTopPerformingStudents();
      } else if (selectedCardIndex == 2) {
        await _fetchAttendanceData();
        await _fetchInactiveStudents();
      } else if (selectedCardIndex == 3) {
        await _fetchFeeData();
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchOverallCounts() async {
    Query<Map<String, dynamic>> studentQuery = FirebaseFirestore.instance
        .collection('Students');
    Query<Map<String, dynamic>> facultyQuery = FirebaseFirestore.instance
        .collection('Faculties');

    if (selectedDateRange == 'Current') {
      studentQuery = studentQuery.where('headUid', isEqualTo: _headUid);
      facultyQuery = facultyQuery.where('headUid', isEqualTo: _headUid);
    } else if (selectedDateRange == 'Specific Date' && _selectedDate != null) {
      final endOfDate = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        23,
        59,
        59,
      );
      studentQuery = studentQuery
          .where('headUid', isEqualTo: _headUid)
          .where('createdAt', isLessThanOrEqualTo: endOfDate);
      facultyQuery = facultyQuery
          .where('headUid', isEqualTo: _headUid)
          .where('createdAt', isLessThanOrEqualTo: endOfDate);
    }

    final studentSnapshot = await studentQuery.get();
    _totalStudents = studentSnapshot.docs.length;

    final facultySnapshot = await facultyQuery.get();
    _totalTeachers = facultySnapshot.docs.length;

    final headSnapshot =
        await FirebaseFirestore.instance.collection('Heads').get();
    _totalMadarsas = headSnapshot.docs.length;
  }

  Future<void> _fetchTopMadarsas() async {
    final madrasaCounts = <String, int>{};
    final headQuery =
        await FirebaseFirestore.instance.collection('Heads').get();

    _topMadarsas = [];

    for (var headDoc in headQuery.docs) {
      final madrasaName = headDoc.data()['madarsaName'] ?? 'Unnamed';
      final headId = headDoc.id;
      final studentsSnapshot =
          await FirebaseFirestore.instance
              .collection('Students')
              .where('headUid', isEqualTo: headId)
              .count()
              .get();
      madrasaCounts[madrasaName] = studentsSnapshot.count ?? 0;
    }

    _topMadarsas =
        madrasaCounts.entries
            .map((e) => {'name': e.key, 'students': e.value.toString()})
            .toList();

    _topMadarsas.sort(
      (a, b) => int.parse(
        b['students'] as String,
      ).compareTo(int.parse(a['students'] as String)),
    );
  }

  Future<void> _fetchStudentDataForAcademics() async {
    Query<Map<String, dynamic>> studentQuery = FirebaseFirestore.instance
        .collection('Students');

    if (selectedDateRange == 'Current') {
      studentQuery = studentQuery.where('headUid', isEqualTo: _headUid);
    } else if (selectedDateRange == 'Specific Date' && _selectedDate != null) {
      final endOfDate = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        23,
        59,
        59,
      );
      studentQuery = studentQuery
          .where('headUid', isEqualTo: _headUid)
          .where('createdAt', isLessThanOrEqualTo: endOfDate);
    }

    final studentsSnap = await studentQuery.get();
    _allStudents =
        studentsSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  void _calculateCourseCompletion() {
    _courseCount.clear();
    final Set<String> foundCourses = {};

    for (var student in _allStudents) {
      final raw = (student['course'] as String?)?.trim();
      final course = (raw == null || raw.isEmpty) ? 'Others' : raw;
      _courseCount.update(course, (v) => v + 1, ifAbsent: () => 1);
      foundCourses.add(course);
    }
    _assignColors(foundCourses);
  }

  Future<void> _calculateTopPerformingStudents() async {
    _topStudents = [];
    final marksQuery = FirebaseFirestore.instance
        .collection('studentMarks')
        .where('headUid', isEqualTo: _headUid);

    final snapshot = await marksQuery.get();
    final List<Map<String, dynamic>> studentsWithMarks = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final records = data['records'] as Map<String, dynamic>? ?? {};
      double totalPercentage = 0.0;

      final examTypes = records.keys.toList();
      if (examTypes.isNotEmpty) {
        final lastExam = records[examTypes.last] as Map<String, dynamic>?;
        if (lastExam != null) {
          totalPercentage =
              (lastExam['totalPercentage'] as num? ?? 0.0).toDouble();
        }
      }

      if (totalPercentage > 0) {
        studentsWithMarks.add({
          'name': data['fullName'] as String? ?? 'N/A',
          'percent': totalPercentage,
          'course': data['course'] as String? ?? 'N/A',
        });
      }
    }

    studentsWithMarks.sort(
      (a, b) => (b['percent'] as double).compareTo(a['percent'] as double),
    );
    _topStudents = studentsWithMarks.take(5).toList();
    _assignColors(
      _topStudents
          .map(
            (e) =>
                (e['course'] as String?)?.trim().isNotEmpty == true
                    ? e['course'] as String
                    : 'Others',
          )
          .toSet(),
    );
    if (!mounted) return;
    setState(() {});
  }

  void _calculateGenderDistribution() {
    _genderDistribution = {'Male': 0, 'Female': 0, 'Other': 0};
    for (var student in _allStudents) {
      final gender = (student['gender'] as String? ?? 'Other').toLowerCase();
      if (gender == 'male') {
        _genderDistribution['Male'] = (_genderDistribution['Male']! + 1);
      } else if (gender == 'female') {
        _genderDistribution['Female'] = (_genderDistribution['Female']! + 1);
      } else {
        _genderDistribution['Other'] = (_genderDistribution['Other']! + 1);
      }
    }
  }

  void _calculateAgeDistribution() {
    // New age distribution ranges as requested
    _ageDistribution = {
      '5-15 years': 0,
      '15-25 years': 0,
      '25-35 years': 0,
      '35+ years': 0,
    };

    final now = DateTime.now();
    int parsedCount = 0;

    for (var student in _allStudents) {
      final dobField = student['dateOfBirth'];
      if (dobField == null) continue;

      DateTime? dob;
      try {
        if (dobField is String) {
          final parts = dobField.split('/');
          if (parts.length == 3) {
            final day = int.tryParse(parts[0]);
            final month = int.tryParse(parts[1]);
            final year = int.tryParse(parts[2]);
            if (day != null && month != null && year != null) {
              dob = DateTime(year, month, day);
            }
          }
        } else if (dobField is DateTime) {
          dob = dobField;
        }
      } catch (_) {
        dob = null;
      }

      if (dob == null) continue;
      parsedCount++;

      int age = now.year - dob.year;
      if (now.month < dob.month ||
          (now.month == dob.month && now.day < dob.day)) {
        age--;
      }

      // Updated logic for the new age ranges
      if (age >= 5 && age < 15) {
        _ageDistribution['5-15 years'] = _ageDistribution['5-15 years']! + 1;
      } else if (age >= 15 && age < 25) {
        _ageDistribution['15-25 years'] = _ageDistribution['15-25 years']! + 1;
      } else if (age >= 25 && age < 35) {
        _ageDistribution['25-35 years'] = _ageDistribution['25-35 years']! + 1;
      } else if (age >= 35) {
        _ageDistribution['35+ years'] = _ageDistribution['35+ years']! + 1;
      }
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _fetchAttendanceData() async {
    // reset counters
    _weeklyPresent = 0;
    _weeklyTotal = 0;
    _monthlyPresent = 0;
    _monthlyTotal = 0;
    _allTimePresent = 0;
    _allTimeTotal = 0;

    Query query;

    if (_userRole == 'Student') {
      // ✅ Student: sirf apna data
      query = FirebaseFirestore.instance
          .collection('attendance')
          .where('student_uid', isEqualTo: _studentUid);
    } else {
      // ✅ Head & Faculty: aggregated data head ke courses ke hisaab se
      query = FirebaseFirestore.instance
          .collection('attendance')
          .where('headUid', isEqualTo: _headUid);
    }

    // ✅ Date filter agar "Specific Date" selected hai
    if (selectedDateRange == 'Specific Date' && _selectedDate != null) {
      final startOfDay = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
      );
      final endOfDay = startOfDay.add(const Duration(days: 1));
      query = query.where('timestamp', isGreaterThanOrEqualTo: startOfDay);
      query = query.where('timestamp', isLessThan: endOfDay);
    }

    final snapshot = await query.get();

    final now = DateTime.now();
    final lastWeek = now.subtract(const Duration(days: 7));
    final startOfMonth = DateTime(now.year, now.month, 1);

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = (data['timestamp'] as Timestamp).toDate();
      final status = data['status'] as String? ?? '';

      if (status.toLowerCase() == 'present' ||
          status.toLowerCase() == 'absent') {
        _allTimeTotal++;
        if (status.toLowerCase() == 'present') {
          _allTimePresent++;
        }
      }

      if (timestamp.isAfter(lastWeek)) {
        if (status.toLowerCase() == 'present' ||
            status.toLowerCase() == 'absent') {
          _weeklyTotal++;
          if (status.toLowerCase() == 'present') {
            _weeklyPresent++;
          }
        }
      }

      if (timestamp.isAfter(startOfMonth)) {
        if (status.toLowerCase() == 'present' ||
            status.toLowerCase() == 'absent') {
          _monthlyTotal++;
          if (status.toLowerCase() == 'present') {
            _monthlyPresent++;
          }
        }
      }
    }

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _fetchInactiveStudents() async {
    _inactiveStudents.clear();
    final today = DateTime.now();
    final cutoffDate = today.subtract(const Duration(days: 7));

    Query studentQuery = FirebaseFirestore.instance
        .collection('Students')
        .where('headUid', isEqualTo: _headUid);
    final studentsSnapshot = await studentQuery.get();

    for (var studentDoc in studentsSnapshot.docs) {
      final studentId = studentDoc.id;
      final studentData = studentDoc.data() as Map<String, dynamic>? ?? {};
      final studentName = studentData['fullName'] as String? ?? 'N/A';

      final attendanceSnapshot =
          await FirebaseFirestore.instance
              .collection('attendance')
              .where('student_uid', isEqualTo: studentId)
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffDate),
              )
              .get();

      // Build a safe list of DateTime values (ignore docs without valid timestamp)
      final attendanceDates =
          attendanceSnapshot.docs
              .map((doc) {
                final d = doc.data() as Map<String, dynamic>? ?? {};
                final ts = d['timestamp'];
                if (ts is Timestamp) return ts.toDate();
                return null;
              })
              .whereType<DateTime>()
              .toList();

      attendanceDates.sort((a, b) => b.compareTo(a));
      final lastAttendanceDate =
          attendanceDates.isNotEmpty ? attendanceDates.first : null;

      if (lastAttendanceDate == null ||
          lastAttendanceDate.isBefore(cutoffDate)) {
        final daysAbsentStr =
            lastAttendanceDate != null
                ? today.difference(lastAttendanceDate).inDays.toString()
                : 'N/A';
        _inactiveStudents.add({
          'name': studentName,
          'days': '$daysAbsentStr days absent',
        });
      }
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _fetchFeeData() async {
    _paidFeesCount = 0;
    _pendingFeesCount = 0;
    _pendingFeesStudents.clear();
    _totalPaidAmount = 0.0;
    _totalDueAmount = 0.0;

    Query studentQuery = FirebaseFirestore.instance
        .collection('Students')
        .where('headUid', isEqualTo: _headUid);
    final studentsSnapshot = await studentQuery.get();

    for (var studentDoc in studentsSnapshot.docs) {
      final studentId = studentDoc.id;
      final studentData = studentDoc.data() as Map<String, dynamic>? ?? {};
      final studentName = studentData['fullName'] as String? ?? 'N/A';
      String? courseName = (studentData['courseName'] as String?)?.trim();
      if (courseName == null || courseName.isEmpty) {
        courseName = (studentData['course'] as String?)?.trim();
      }

      double totalFees = 0.0;
      if (courseName != null && courseName.isNotEmpty) {
        final feeQuery =
            await FirebaseFirestore.instance
                .collection('fees')
                .where('courseName', isEqualTo: courseName)
                .where('headUid', isEqualTo: _headUid)
                .limit(1)
                .get();

        final feeDoc = feeQuery.docs.isNotEmpty ? feeQuery.docs.first : null;
        final feeData = feeDoc?.data() as Map<String, dynamic>? ?? {};
        totalFees = (feeData['totalFees'] as num?)?.toDouble() ?? 0.0;
      }

      final paymentsSnapshot =
          await FirebaseFirestore.instance
              .collection('feePayments')
              .where('userId', isEqualTo: studentId)
              .where('status', isEqualTo: 'approved')
              .get();

      double paidAmount = paymentsSnapshot.docs.fold<double>(0.0, (sum, doc) {
        final payment = doc.data() as Map<String, dynamic>? ?? {};
        final amount = payment['amount'];
        return sum + ((amount is num) ? amount.toDouble() : 0.0);
      });

      _totalPaidAmount += paidAmount;

      double dueAmount = 0.0;
      if (totalFees > 0) {
        dueAmount = totalFees - paidAmount;
        if (dueAmount < 0) dueAmount = 0.0;
      }

      if (dueAmount > 0) {
        _pendingFeesCount++;
        _totalDueAmount += dueAmount;
        final createdAt = studentData['createdAt'];
        final daysDue =
            (createdAt is Timestamp)
                ? DateTime.now().difference(createdAt.toDate()).inDays
                : null;

        _pendingFeesStudents.add({
          'name': studentName,
          'days': daysDue != null ? daysDue.toString() : 'N/A',
          'dueAmount': dueAmount,
          'paidAmount': paidAmount,
          'totalFees': totalFees,
        });
      } else {
        _paidFeesCount++;
      }
    }

    if (!mounted) return;
    setState(() {});
  }

  Widget buildCard(int index, String title, IconData icon) {
    final screenWidth = MediaQuery.of(context).size.width;
    bool isSelected = selectedCardIndex == index;
    return InkWell(
      canRequestFocus: false,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      onTap: () {
        if (!mounted) return;
        setState(() {
          selectedCardIndex = index;
          _loadAnalyticsData();
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(screenWidth * 0.04),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black54,
                fontSize: screenWidth * 0.04,
                fontFamily: 'Gilroy-Bold',
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Icon(
                icon,
                size: 30,
                color: isSelected ? Colors.white : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

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
        title: const Text(
          'Analytics',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Gilroy-Bold',
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Expanded(
                child:
                    _isLoading
                        ? const Center(
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: CircularProgressIndicator(
                              color: Colors.redAccent,
                              strokeWidth: 4,
                            ),
                          ),
                        )
                        : SingleChildScrollView(
                          child: Column(
                            children: [
                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.2,
                                children: [
                                  buildCard(0, 'Total Students', Icons.people),
                                  buildCard(
                                    1,
                                    'Academic Performance',
                                    Icons.bar_chart,
                                  ),
                                  buildCard(
                                    2,
                                    'Students Records',
                                    Icons.school,
                                  ),
                                  buildCard(
                                    3,
                                    'Payments Overview',
                                    Icons.payment,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 1),
                              if (selectedCardIndex == 0)
                                ActivityGoalChart(
                                  totalStudents: _totalStudents,
                                  totalTeachers: _totalTeachers,
                                  totalMadarsas: _totalMadarsas,
                                  onDateRangeChanged: (range, date) {
                                    setState(() {
                                      selectedDateRange = range;
                                      _selectedDate = date;
                                      _loadAnalyticsData();
                                    });
                                  },
                                ),
                              const SizedBox(height: 24),
                              if (selectedCardIndex == 0)
                                TopMadarsasContainer(
                                  madarsas:
                                      _topMadarsas
                                          .map(
                                            (e) => {
                                              'name': e['name'] as String,
                                              'students':
                                                  e['students'] as String,
                                            },
                                          )
                                          .toList(),
                                ),
                              if (selectedCardIndex == 1)
                                ActivityPieChart(
                                  courseData: _courseCount,
                                  courseColors: _courseColors,
                                ),
                              if (selectedCardIndex == 2)
                                OverallAttendance(
                                  weeklyPresent: _weeklyPresent,
                                  weeklyTotal: _weeklyTotal,
                                  monthlyPresent: _monthlyPresent,
                                  monthlyTotal: _monthlyTotal,
                                  allTimePresent: _allTimePresent,
                                  allTimeTotal: _allTimeTotal,
                                  userRole: _userRole!,
                                  selectedDateRange: selectedDateRange,
                                  onDateRangeChanged: (range, date) {
                                    setState(() {
                                      selectedDateRange = range;
                                      _selectedDate = date;
                                      _loadAnalyticsData();
                                    });
                                  },
                                ),
                              if (selectedCardIndex == 3)
                                DonationOverview(
                                  selectedDateRange: selectedDateRange,
                                  selectedDate: _selectedDate,
                                  headUid: _headUid,
                                ),
                              const SizedBox(height: 10),
                              if (selectedCardIndex == 2)
                                InactiveStudentsContainer(
                                  students: _inactiveStudents,
                                ),
                              const SizedBox(height: 5),
                              if (selectedCardIndex == 3)
                                FeesChart(
                                  paidStudents: _paidFeesCount,
                                  dueStudents: _pendingFeesCount,
                                  totalPaidAmount: _totalPaidAmount,
                                  totalDueAmount: _totalDueAmount,
                                ),
                              const SizedBox(height: 10),
                              if (selectedCardIndex == 3)
                                PendingFeesContainer(
                                  students: _pendingFeesStudents,
                                ),
                              if (selectedCardIndex == 1)
                                TopPerformingStudents(
                                  students: _topStudents,
                                  courseColors: _courseColors,
                                ),
                              if (selectedCardIndex == 1)
                                DemographicChartWidget(
                                  genderData: _genderDistribution,
                                ),
                              const SizedBox(height: 24),
                              if (selectedCardIndex == 1)
                                AgeDistributionChart(ageData: _ageDistribution),
                            ],
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

class ActivityGoalChart extends StatefulWidget {
  final int totalStudents;
  final int totalTeachers;
  final int totalMadarsas;
  final Function(String, DateTime?) onDateRangeChanged;

  const ActivityGoalChart({
    super.key,
    required this.totalStudents,
    required this.totalTeachers,
    required this.totalMadarsas,
    required this.onDateRangeChanged,
  });

  @override
  State<ActivityGoalChart> createState() => _ActivityGoalChartState();
}

class _ActivityGoalChartState extends State<ActivityGoalChart> {
  String selectedRange = 'Current';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Activity",
                style: TextStyle(
                  color: Colors.black,
                  fontFamily: 'Gilroy-Bold',
                  fontSize: 17,
                ),
              ),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String>(
                  value: selectedRange,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                      borderSide: const BorderSide(color: Colors.black),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                      borderSide: const BorderSide(color: Colors.black),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(7),
                  dropdownColor: Colors.white,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                  items:
                      ['Current', 'All', 'Specific Date']
                          .map(
                            (String value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                  onChanged: (val) async {
                    if (val == 'Specific Date') {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          selectedRange = 'Specific Date';
                        });
                        widget.onDateRangeChanged(val!, pickedDate);
                      }
                    } else {
                      setState(() {
                        selectedRange = val!;
                      });
                      widget.onDateRangeChanged(val!, null);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularPercentIndicator(
                    radius: 90.0,
                    lineWidth: 15.0,
                    percent:
                        widget.totalStudents > 0
                            ? widget.totalStudents / (widget.totalStudents + 10)
                            : 0,
                    backgroundColor: Colors.blueAccent.withOpacity(0.2),
                    progressColor: Colors.blueAccent,
                    circularStrokeCap: CircularStrokeCap.round,
                    animation: true,
                    animationDuration: 800,
                  ),
                  CircularPercentIndicator(
                    radius: 70.0,
                    lineWidth: 15.0,
                    percent:
                        widget.totalTeachers > 0
                            ? widget.totalTeachers / (widget.totalTeachers + 5)
                            : 0,
                    backgroundColor: Colors.pinkAccent.withOpacity(0.2),
                    progressColor: Colors.pinkAccent,
                    circularStrokeCap: CircularStrokeCap.round,
                    animation: true,
                    animationDuration: 800,
                  ),
                  CircularPercentIndicator(
                    radius: 50.0,
                    lineWidth: 15.0,
                    percent:
                        widget.totalMadarsas > 0
                            ? widget.totalMadarsas / (widget.totalMadarsas + 20)
                            : 0,
                    backgroundColor: Colors.redAccent.withOpacity(0.2),
                    progressColor: Colors.redAccent,
                    circularStrokeCap: CircularStrokeCap.round,
                    animation: true,
                    animationDuration: 800,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          ActivityInfoRow(
            color: Colors.blueAccent,
            label: 'Total Students',
            percent: widget.totalStudents.toString(),
          ),
          const Divider(),
          ActivityInfoRow(
            color: Colors.pinkAccent,
            label: 'Total Teachers',
            percent: widget.totalTeachers.toString(),
          ),
          const Divider(),
          ActivityInfoRow(
            color: Colors.redAccent,
            label: 'Total Madarsas',
            percent: widget.totalMadarsas.toString(),
          ),
        ],
      ),
    );
  }
}

class ActivityInfoRow extends StatelessWidget {
  final Color color;
  final String label;
  final String percent;

  const ActivityInfoRow({
    super.key,
    required this.color,
    required this.label,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(radius: 5, backgroundColor: color),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 14)),
          ],
        ),
        Text(percent, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}

class ActivityPieChart extends StatefulWidget {
  final Map<String, int> courseData;
  final Map<String, Color> courseColors; // NEW

  const ActivityPieChart({
    super.key,
    required this.courseData,
    required this.courseColors, // NEW
  });

  @override
  State<ActivityPieChart> createState() => _ActivityPieChartState();
}

class _ActivityPieChartState extends State<ActivityPieChart> {
  @override
  Widget build(BuildContext context) {
    final Map<String, double> dataMap = {
      for (final e in widget.courseData.entries) e.key: e.value.toDouble(),
    };

    if (dataMap.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            "No course data available",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Complete Course",
            style: TextStyle(
              color: Colors.black,
              fontFamily: 'Gilroy-Bold',
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 35),
          Center(
            child: Column(
              children: [
                pc.PieChart(
                  dataMap: dataMap,
                  animationDuration: const Duration(milliseconds: 800),
                  chartLegendSpacing: 0,
                  chartRadius: 100,
                  colorList:
                      dataMap.keys
                          .map((key) => widget.courseColors[key] ?? Colors.grey)
                          .toList(),
                  initialAngleInDegree: 0,
                  chartType: pc.ChartType.ring,
                  ringStrokeWidth: 22,
                  centerTextStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  legendOptions: const pc.LegendOptions(showLegends: false),
                  chartValuesOptions: const pc.ChartValuesOptions(
                    showChartValues: false,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          ...dataMap.entries.map((entry) {
            return Column(
              children: [
                ActivityInfoRow2(
                  color: widget.courseColors[entry.key] ?? Colors.grey,
                  label: 'Total ${entry.key}',
                  percent: entry.value.toStringAsFixed(0),
                ),
                const Divider(),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }
}

class ActivityInfoRow2 extends StatelessWidget {
  final Color color;
  final String label;
  final String percent;

  const ActivityInfoRow2({
    super.key,
    required this.color,
    required this.label,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(radius: 5, backgroundColor: color),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 14)),
          ],
        ),
        Text(percent, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}

class YearPickerDialog extends StatelessWidget {
  final int firstYear;
  final int lastYear;

  const YearPickerDialog({
    super.key,
    required this.firstYear,
    required this.lastYear,
  });

  @override
  Widget build(BuildContext context) {
    final List<int> years = List.generate(
      lastYear - firstYear + 1,
      (index) => lastYear - index,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        height: 400,
        width: 300,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Year',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: years.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(years[index].toString()),
                    onTap: () {
                      Navigator.of(context).pop(years[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DemographicChartWidget extends StatelessWidget {
  final Map<String, int> genderData;

  const DemographicChartWidget({super.key, required this.genderData});

  @override
  Widget build(BuildContext context) {
    final total =
        (genderData['Male'] ?? 0) +
        (genderData['Female'] ?? 0) +
        (genderData['Other'] ?? 0);

    final malePercent =
        total > 0 ? (genderData['Male']! / total).toDouble() : 0.0;
    final femalePercent =
        total > 0 ? (genderData['Female']! / total).toDouble() : 0.0;
    final otherPercent =
        total > 0 ? (genderData['Other']! / total).toDouble() : 0.0;

    return Padding(
      padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gender Distribution',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Gilroy-Bold',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  CircularPercentIndicator(
                    radius: 60.0,
                    lineWidth: 20.0,
                    percent: malePercent + femalePercent + otherPercent,
                    circularStrokeCap: CircularStrokeCap.round,
                    backgroundColor: Colors.transparent,
                    progressColor: const Color(0xFFFF4F8B),
                  ),
                  CircularPercentIndicator(
                    radius: 60.0,
                    lineWidth: 20.0,
                    percent: malePercent,
                    circularStrokeCap: CircularStrokeCap.round,
                    backgroundColor: Colors.transparent,
                    progressColor: const Color(0xFF14C8C5),
                  ),
                  Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.male, color: Colors.blue, size: 22),
                        SizedBox(width: 5),
                        Icon(Icons.female, color: Colors.pink, size: 22),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 30),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${(malePercent * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 25,
                            fontFamily: 'Gilroy-Bold',
                            color: Color(0xFF14C8C5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Male',
                          style: TextStyle(
                            fontSize: 19,
                            fontFamily: 'Gilroy-Bold',
                            color: Color(0xFF343E5C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Text(
                          '${(femalePercent * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 25,
                            fontFamily: 'Gilroy-Bold',
                            color: Color(0xFFFF4F8B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Female',
                          style: TextStyle(
                            fontSize: 19,
                            fontFamily: 'Gilroy-Bold',
                            color: Color(0xFF343E5C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    if (otherPercent > 0)
                      Row(
                        children: [
                          Text(
                            '${(otherPercent * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 25,
                              fontFamily: 'Gilroy-Bold',
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Other',
                            style: TextStyle(
                              fontSize: 19,
                              fontFamily: 'Gilroy-Bold',
                              color: Color(0xFF343E5C),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class OverallAttendance extends StatefulWidget {
  final int weeklyPresent;
  final int weeklyTotal;
  final int monthlyPresent;
  final int monthlyTotal;
  final int allTimePresent;
  final int allTimeTotal;
  final String userRole;
  final String selectedDateRange;
  final Function(String, DateTime?) onDateRangeChanged;

  const OverallAttendance({
    super.key,
    required this.weeklyPresent,
    required this.weeklyTotal,
    required this.monthlyPresent,
    required this.monthlyTotal,
    required this.allTimePresent,
    required this.allTimeTotal,
    required this.userRole,
    required this.selectedDateRange,
    required this.onDateRangeChanged,
  });

  @override
  State<OverallAttendance> createState() => _OverallAttendanceState();
}

class _OverallAttendanceState extends State<OverallAttendance> {
  int selectedTabIndex = 0;
  final List<String> tabs = ['Weekly', 'Monthly', 'All Time'];

  String _getFormattedDateRange() {
    final now = DateTime.now();
    switch (selectedTabIndex) {
      case 0:
        final lastWeek = now.subtract(const Duration(days: 7));
        return '${DateFormat('MMM dd').format(lastWeek)} - ${DateFormat('MMM dd').format(now)}';
      case 1:
        return DateFormat('MMM yyyy').format(now);
      case 2:
        return 'All Time';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    int presentCount = 0;
    int totalCount = 0;

    switch (selectedTabIndex) {
      case 0:
        presentCount = widget.weeklyPresent;
        totalCount = widget.weeklyTotal;
        break;
      case 1:
        presentCount = widget.monthlyPresent;
        totalCount = widget.monthlyTotal;
        break;
      case 2:
        presentCount = widget.allTimePresent;
        totalCount = widget.allTimeTotal;
        break;
    }

    final percent = (totalCount > 0) ? (presentCount / totalCount) * 100 : 0.0;
    final absent = totalCount - presentCount;
    final dateRangeText = _getFormattedDateRange();

    final chartData = [
      _AttendanceData("Present", presentCount.toDouble(), Colors.green),
      _AttendanceData("Absent", absent.toDouble(), Colors.redAccent),
    ];

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            const Text(
              'Overall Attendance',
              style: TextStyle(fontFamily: 'Gilroy-Bold', fontSize: 20),
            ),
            const SizedBox(height: 5),
            Text(
              dateRangeText,
              style: const TextStyle(
                color: Colors.grey,
                fontFamily: 'Gilroy-Bold',
              ),
            ),
            const SizedBox(height: 20),

            // Tab Switcher
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE7ECFD),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: List.generate(
                  tabs.length,
                  (index) => Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedTabIndex = index;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color:
                              selectedTabIndex == index
                                  ? Colors.white
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          tabs[index],
                          style: const TextStyle(
                            fontFamily: 'Gilroy-Bold',
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Doughnut Chart
            SizedBox(
              height: 200,
              child: SfCircularChart(
                margin: EdgeInsets.zero,
                annotations: <CircularChartAnnotation>[
                  CircularChartAnnotation(
                    widget: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${percent.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 22,
                            fontFamily: 'Gilroy-Bold',
                          ),
                        ),
                        const Text(
                          "Present",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
                series: <CircularSeries<_AttendanceData, String>>[
                  DoughnutSeries<_AttendanceData, String>(
                    dataSource: chartData,
                    xValueMapper: (_AttendanceData data, _) => data.label,
                    yValueMapper: (_AttendanceData data, _) => data.value,
                    pointColorMapper: (_AttendanceData data, _) => data.color,
                    innerRadius: '70%',
                    dataLabelMapper:
                        (_AttendanceData data, _) =>
                            "${data.label}\n${data.value.toInt()}",
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      textStyle: TextStyle(
                        fontFamily: 'Gilroy-Bold',
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                      labelPosition: ChartDataLabelPosition.outside,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Summary
            Text(
              "Total: $totalCount, Present: $presentCount, Absent: $absent",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Gilroy-Bold',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceData {
  final String label;
  final double value;
  final Color color;
  _AttendanceData(this.label, this.value, this.color);
}

class InactiveStudentsContainer extends StatefulWidget {
  final List<Map<String, dynamic>> students;

  const InactiveStudentsContainer({super.key, required this.students});

  @override
  _InactiveStudentsContainerState createState() =>
      _InactiveStudentsContainerState();
}

class _InactiveStudentsContainerState extends State<InactiveStudentsContainer> {
  bool showAll = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final visibleStudents =
        showAll ? widget.students : widget.students.take(4).toList();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Inactive Students",
                style: TextStyle(fontSize: 16, fontFamily: 'Gilroy-Bold'),
              ),
              if (widget.students.length > 4)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      showAll = !showAll;
                    });
                  },
                  child: Row(
                    children: [
                      Text(
                        showAll ? "Show Less" : "See All",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        showAll
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          widget.students.isEmpty
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    "No record found",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
              : ListView.separated(
                itemCount: visibleStudents.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final student = visibleStudents[index];
                  return Row(
                    children: [
                      const Icon(
                        Icons.person_off_outlined,
                        size: 18,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          student['name']!,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        student['days']!,
                        style: const TextStyle(fontSize: 14, color: Colors.red),
                      ),
                    ],
                  );
                },
              ),
        ],
      ),
    );
  }
}

class FeesChart extends StatefulWidget {
  final int paidStudents;
  final int dueStudents;
  final double totalPaidAmount;
  final double totalDueAmount;

  const FeesChart({
    super.key,
    required this.paidStudents,
    required this.dueStudents,
    required this.totalPaidAmount,
    required this.totalDueAmount,
  });

  @override
  State<FeesChart> createState() => _FeesChartState();
}

class _FeesChartState extends State<FeesChart> {
  @override
  Widget build(BuildContext context) {
    final double totalAmount = widget.totalPaidAmount + widget.totalDueAmount;

    final List<FeesData> chartData = [
      FeesData('Paid', widget.totalPaidAmount, const Color(0xFF4CAF50)),
      FeesData('Dues', widget.totalDueAmount, const Color(0xFFF44336)),
    ];

    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400, width: 0.8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Fee Overview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Gilroy-Bold',
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 220, // Height badha di hai taaki labels na katein
            child: SfCircularChart(
              margin: EdgeInsets.zero,
              annotations: <CircularChartAnnotation>[
                CircularChartAnnotation(
                  widget: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Total', style: TextStyle(color: Colors.grey[700])),
                      Text(
                        '₹${totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontFamily: 'Gilroy-Bold',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              series: <CircularSeries<FeesData, String>>[
                DoughnutSeries<FeesData, String>(
                  dataSource: chartData,
                  xValueMapper: (FeesData data, _) => data.type,
                  yValueMapper: (FeesData data, _) => data.value,
                  pointColorMapper: (FeesData data, _) => data.color,
                  innerRadius: '60%',
                  dataLabelMapper: (FeesData data, _) {
                    final percent =
                        (totalAmount > 0)
                            ? (data.value / totalAmount) * 100
                            : 0;
                    return '₹${data.value.toStringAsFixed(0)}\n(${percent.toStringAsFixed(0)}%)';
                  },
                  dataLabelSettings: const DataLabelSettings(
                    isVisible: true,
                    textStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontFamily: 'Gilroy-Bold',
                    ),
                    labelPosition: ChartDataLabelPosition.outside,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            children: [
              LegendDot(color: const Color(0xFFF44336), label: 'Dues'),
              LegendDot(color: const Color(0xFF4CAF50), label: 'Paid'),
            ],
          ),
        ],
      ),
    );
  }
}

class FeesData {
  final String type;
  final double value;
  final Color color;
  FeesData(this.type, this.value, this.color);
}

class LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const LegendDot({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black87,
            fontFamily: 'Gilroy-Bold',
          ),
        ),
      ],
    );
  }
}

class PendingFeesContainer extends StatefulWidget {
  final List<Map<String, dynamic>> students;

  const PendingFeesContainer({super.key, required this.students});

  @override
  _PendingFeesContainerState createState() => _PendingFeesContainerState();
}

class _PendingFeesContainerState extends State<PendingFeesContainer> {
  bool showAll = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final visibleStudents =
        showAll ? widget.students : widget.students.take(4).toList();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Pending Amount",
                style: TextStyle(fontSize: 16, fontFamily: 'Gilroy-Bold'),
              ),
              if (widget.students.length > 4)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      showAll = !showAll;
                    });
                  },
                  child: Row(
                    children: [
                      Text(
                        showAll ? "Show Less" : "See All",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        showAll
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          widget.students.isEmpty
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    "No record found",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
              : ListView.separated(
                itemCount: visibleStudents.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final student = visibleStudents[index];
                  return Row(
                    children: [
                      const Icon(
                        Icons.currency_rupee,
                        size: 18,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          student['name'] ?? 'N/A',
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        "₹${(student['dueAmount'] as num?)?.toStringAsFixed(0) ?? '0'}",
                        style: const TextStyle(fontSize: 14, color: Colors.red),
                      ),
                    ],
                  );
                },
              ),
        ],
      ),
    );
  }
}

class TopMadarsasContainer extends StatefulWidget {
  final List<Map<String, String>> madarsas;
  const TopMadarsasContainer({super.key, required this.madarsas});

  @override
  _TopMadarsasContainerState createState() => _TopMadarsasContainerState();
}

class _TopMadarsasContainerState extends State<TopMadarsasContainer> {
  List<Map<String, String>> filteredMadarsas = [];

  @override
  void initState() {
    super.initState();
    filteredMadarsas = widget.madarsas;
  }

  void _showAllMadarsasDialog() {
    final screenWidth = MediaQuery.of(context).size.width;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder:
              (_, controller) => Padding(
                padding: EdgeInsets.all(screenWidth * 0.04),
                child: Column(
                  children: [
                    Container(
                      height: 5,
                      width: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: InputDecoration(
                        hintText: "Search Madarsa",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          filteredMadarsas =
                              widget.madarsas
                                  .where(
                                    (madarsa) => madarsa['name']!
                                        .toLowerCase()
                                        .contains(value.toLowerCase()),
                                  )
                                  .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        controller: controller,
                        itemCount: filteredMadarsas.length,
                        separatorBuilder:
                            (_, __) => const Divider(height: 8, thickness: 0.7),
                        itemBuilder: (_, index) {
                          final madarsa = filteredMadarsas[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.school_outlined,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    madarsa['name']!,
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  "${madarsa['students']} Students",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.teal,
                                  ),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final List<Map<String, String>> visibleMadarsas =
        widget.madarsas.take(5).toList();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Top Madarsas",
                style: TextStyle(fontSize: 16, fontFamily: 'Gilroy-Bold'),
              ),
              if (widget.madarsas.length > 5)
                GestureDetector(
                  onTap: _showAllMadarsasDialog,
                  child: Row(
                    children: const [
                      Text(
                        "See All",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            itemCount: visibleMadarsas.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, index) {
              final madarsa = visibleMadarsas[index];
              return Row(
                children: [
                  const Icon(
                    Icons.school_outlined,
                    size: 18,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      madarsa['name']!,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class DonationOverview extends StatefulWidget {
  final String selectedDateRange;
  final DateTime? selectedDate;
  final String? headUid;

  const DonationOverview({
    super.key,
    required this.selectedDateRange,
    required this.selectedDate,
    this.headUid,
  });

  @override
  State<DonationOverview> createState() => _DonationOverviewState();
}

class _DonationOverviewState extends State<DonationOverview> {
  bool _isLoading = true;
  final Map<String, double> _donationData = {};
  double _totalAmount = 0.0;
  final List<Color> _palette = [
    Colors.redAccent,
    Colors.orange,
    Colors.purple,
    Colors.green,
    Colors.blue,
    Colors.teal,
  ];

  @override
  void initState() {
    super.initState();
    _fetchDonationData();
  }

  @override
  void didUpdateWidget(covariant DonationOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDateRange != oldWidget.selectedDateRange ||
        widget.selectedDate != oldWidget.selectedDate ||
        widget.headUid != oldWidget.headUid) {
      _fetchDonationData();
    }
  }

  Future<void> _fetchDonationData() async {
    if (widget.headUid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _donationData.clear();
        _totalAmount = 0.0;
      });
    }

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('donationRequests')
          .where('headUid', isEqualTo: widget.headUid)
          .where('status', isEqualTo: 'approved');
      if (widget.selectedDateRange == 'Current') {
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
        );
      } else if (widget.selectedDateRange == 'Specific Date' &&
          widget.selectedDate != null) {
        final startOfDay = DateTime(
          widget.selectedDate!.year,
          widget.selectedDate!.month,
          widget.selectedDate!.day,
        );
        final endOfDay = startOfDay.add(const Duration(days: 1));
        query = query
            .where(
              'timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay));
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _donationData.clear();
            _totalAmount = 0.0;
            _isLoading = false;
          });
        }
        return;
      }

      double total = 0.0;
      final Map<String, double> categoryTotals = {
        'Sadaqah': 0.0,
        'Zakat': 0.0,
        'Fitra': 0.0,
        'Imdad': 0.0,
        'Hadiya': 0.0,
        'Others': 0.0,
      };

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final category = data['category'] as String? ?? 'Others';
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

        total += amount;
        if (categoryTotals.containsKey(category)) {
          categoryTotals[category] = categoryTotals[category]! + amount;
        } else {
          categoryTotals['Others'] = categoryTotals['Others']! + amount;
        }
      }

      if (mounted) {
        setState(() {
          _donationData.addAll(categoryTotals);
          _totalAmount = total;
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching donation data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _colorForCategory(String category) {
    final index = _donationData.keys.toList().indexOf(category);
    return _palette[index % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 350,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: Colors.redAccent),
      );
    }

    if (_donationData.isEmpty || _totalAmount == 0.0) {
      return Center(
        child: Container(
          width: double.infinity,
          height: 200,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade400, width: 0.8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.remove_circle_outline, size: 60, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                "No donation data available for this period.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontFamily: 'Gilroy-Bold',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;

    return Center(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(screenWidth * 0.04),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400, width: 0.8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pie_chart_outline,
                  color: Colors.redAccent.withOpacity(0.8),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Donation Overview',
                  style: TextStyle(fontSize: 18, fontFamily: 'Gilroy-Bold'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              // Center widget added to center the chart
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 200,
                    width: 200,
                    child: SfCircularChart(
                      margin: EdgeInsets.zero,
                      series: <CircularSeries>[
                        DoughnutSeries<_ChartData, String>(
                          dataSource:
                              _donationData.entries
                                  .map(
                                    (e) => _ChartData(
                                      e.key,
                                      e.value,
                                      _colorForCategory(e.key),
                                    ),
                                  )
                                  .toList(),
                          pointColorMapper: (_ChartData data, _) => data.color,
                          xValueMapper: (_ChartData data, _) => data.label,
                          yValueMapper: (_ChartData data, _) => data.value,
                          innerRadius: '65%',
                          dataLabelSettings: const DataLabelSettings(
                            isVisible: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontFamily: 'Gilroy-Bold',
                        ),
                      ),
                      Text(
                        '₹${_totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontFamily: 'Gilroy-Bold',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartData {
  final String label;
  final double value;
  final Color color;

  _ChartData(this.label, this.value, this.color);
}

class TopPerformingStudents extends StatelessWidget {
  final List<Map<String, dynamic>> students;
  final Map<String, Color> courseColors;

  const TopPerformingStudents({
    super.key,
    required this.students,
    required this.courseColors,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      height: 200,
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Top Performing Students",
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              fontFamily: 'Gilroy-Bold',
            ),
          ),
          const SizedBox(height: 12),

          students.isEmpty
              ? const Expanded(
                child: Center(
                  child: Text(
                    "No record found",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
              : Expanded(
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: students.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final student = students[index];
                    final course =
                        (student['course'] as String?)?.trim().isNotEmpty ==
                                true
                            ? student['course'] as String
                            : 'Others';

                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 5,
                          backgroundColor: courseColors[course] ?? Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: Text(
                            student['name'] as String,
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              "${(student['percent'] as double).toStringAsFixed(1)}%",
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              course,
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }
}

class AgeDistributionChart extends StatelessWidget {
  final Map<String, int> ageData;

  const AgeDistributionChart({super.key, required this.ageData});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final totalStudents = ageData.values.fold<int>(
      0,
      (sum, item) => sum + item,
    );

    return Container(
      height: 250,
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Age Distribution",
            style: TextStyle(
              fontSize: screenWidth * 0.045,
              fontFamily: 'Gilroy-Bold',
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ageData.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final ageRange = ageData.keys.elementAt(index);
                final count = ageData[ageRange]!;
                final percent =
                    totalStudents > 0
                        ? (count / totalStudents).toDouble()
                        : 0.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(
                            ageRange,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              "${(percent * 100).toStringAsFixed(0)}%",
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: percent,
                      minHeight: 4,
                      backgroundColor: Colors.grey.shade300,
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

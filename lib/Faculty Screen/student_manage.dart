import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:madarsaconnect/Faculty%20Screen/quiz_upload.dart';
import '../Data/loader.dart';
import '../Home Screen/home_screen.dart';
import '../l10n/app_localizations.dart';

class StudentManagementScreen extends StatefulWidget {
  final String headUid;
  const StudentManagementScreen({super.key, required this.headUid});

  @override
  State<StudentManagementScreen> createState() =>
      _StudentManagementScreenState();
}

class StudentDetailsPage extends StatelessWidget {
  final Map<String, dynamic> student;
  const StudentDetailsPage({super.key, required this.student});

  Widget _buildField(String label, String key) {
    dynamic value;
    if (key.contains('.')) {
      final parts = key.split('.');
      value = student[parts[0]]?[parts[1]];
    } else {
      value = student[key];
    }

    String displayValue = '';
    if (key == 'address') {
      displayValue =
          '${student['address']['line1'] ?? ''}, ${student['address']['townCity'] ?? ''}, ${student['address']['district'] ?? ''}, ${student['address']['state'] ?? ''}';
    } else if (key == 'rollNo' && value != null) {
      displayValue = value.toString().padLeft(3, '0');
    } else {
      displayValue = value?.toString() ?? '';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 1),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "$label: $displayValue",
        style: const TextStyle(fontSize: 15, color: Colors.black87),
      ),
    );
  }

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
          icon: const Icon(Icons.arrow_back, size: 26, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.studentDetailsTitle,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDAE2F8), Color(0xFFD6A4A4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    backgroundImage:
                        (student['profilePictureUrl'] != null &&
                                student['profilePictureUrl']
                                    .toString()
                                    .isNotEmpty)
                            ? NetworkImage(student['profilePictureUrl'])
                            : null,
                    child:
                        (student['profilePictureUrl'] == null ||
                                student['profilePictureUrl'].toString().isEmpty)
                            ? SvgPicture.asset(
                              'assets/icons/users.svg',
                              width: 35,
                              height: 35,
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
                          student['fullName'] ?? '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          student['gender'] ?? '',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        Text(
                          student['email'] ?? '',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        Text(
                          student['phoneNumber'] ?? '',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Text(
              AppLocalizations.of(context)!.personalDetailsHeader,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            _buildField(
              AppLocalizations.of(context)!.dateOfBirth,
              "dateOfBirth",
            ),
            _buildField(AppLocalizations.of(context)!.fatherName, "fatherName"),
            _buildField(AppLocalizations.of(context)!.motherName, "motherName"),
            _buildField(AppLocalizations.of(context)!.sucId, "sucId"),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.academicDetails,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            _buildField(AppLocalizations.of(context)!.course, "course"),
            _buildField(
              AppLocalizations.of(context)!.duration,
              "courseDuration",
            ),
            _buildField(
              AppLocalizations.of(context)!.academicYear,
              "academicYear",
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.addressHeader,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            _buildField(AppLocalizations.of(context)!.address, "address"),
            _buildField(
              AppLocalizations.of(context)!.townCity,
              "address.townCity",
            ),
            _buildField(AppLocalizations.of(context)!.state, "address.state"),
            _buildField(
              AppLocalizations.of(context)!.district,
              "address.district",
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.identificationDetailsHeader,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            _buildField(
              AppLocalizations.of(context)!.aadhaarNumber,
              "aadhaarNumber",
            ),
            _buildField(AppLocalizations.of(context)!.panCard, "panCard"),
          ],
        ),
      ),
    );
  }
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  List<Map<String, dynamic>> courses = [];
  List<Map<String, dynamic>> students = [];
  bool showStudentList = false;
  String? selectedCourseName;
  String? selectedCourseId;
  int? selectedYear;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCourses();
  }

  Future<void> fetchCourses() async {
    setState(() => _isLoading = true);
    if (widget.headUid == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('courses')
              .where('headUid', isEqualTo: widget.headUid)
              .get();
      if (mounted) {
        setState(() {
          courses =
              snapshot.docs.map((doc) {
                final Map<String, dynamic> data = doc.data();
                return {
                  'id': doc.id,
                  'name': data['name'] ?? '',
                  'code': data['code'] ?? '',
                  'duration': (data['duration'] ?? 1).toString(),
                };
              }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching courses: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> fetchStudents(String courseName, int year) async {
    setState(() => _isLoading = true);

    final yearSuffix = ['st', 'nd', 'rd', 'th', 'th', 'th', 'th', 'th'];
    final duration = '$year${yearSuffix[year > 3 ? 3 : year - 1]} Year';

    final snapshot =
        await FirebaseFirestore.instance
            .collection('Students')
            .where('headUid', isEqualTo: widget.headUid)
            .where('course', isEqualTo: courseName)
            .where('courseDuration', isEqualTo: duration)
            .orderBy('rollNo')
            .get();
    if (mounted) {
      setState(() {
        students =
            snapshot.docs.map((doc) {
              final data = doc.data();
              data['uid'] = doc.id;
              return data;
            }).toList();
        showStudentList = true;
        _isLoading = false;
      });
    }
  }

  void _showDurationSelector(
    BuildContext context,
    Map<String, dynamic> course,
  ) {
    final yearSuffix = ['st', 'nd', 'rd', 'th', 'th', 'th', 'th', 'th'];
    final duration = int.tryParse(course['duration'] ?? '1') ?? 1;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          height: MediaQuery.of(context).size.height * 0.5,
          child: Column(
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
              const SizedBox(height: 18),
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
                    final suffix = yearSuffix[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          selectedCourseName = course['name'];
                          selectedCourseId = course['id'];
                          selectedYear = year;
                        });
                        fetchStudents(course['name'], year);
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

  Widget _buildStudentList() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 110,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF1DC), Color(0xFFE2C290)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  students.length.toString(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  AppLocalizations.of(context)!.totalStudents,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  AppLocalizations.of(context)!.rollNo,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => StudentDetailsPage(student: student),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 12.0),
                            child: Text(student['fullName'] ?? ''),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 11.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              student['rollNo'].toString().padLeft(3, '0'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleActionButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SingleActionCard(
        title: AppLocalizations.of(context)!.quizUpload,
        subtitle: AppLocalizations.of(context)!.uploadQuizSubtitle,
        gradientColors: const [Color(0xFFE3E4E5), Color(0xFFB5B5B5)],
        icon: Icons.quiz,
        onTap: () {
          navigateWithPremiumTransition(
            context,
            const FacultyQuizUploadScreen(),
          );
        },
      ),
    );
  }

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
          icon: const Icon(Icons.arrow_back, size: 26, color: Colors.black),
          onPressed: () {
            if (showStudentList) {
              setState(() => showStudentList = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          showStudentList
              ? AppLocalizations.of(context)!.studentListTitle
              : AppLocalizations.of(context)!.studentManagementTitle,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: showStudentList ? 0 : 20),
          if (_isLoading)
            const Expanded(child: Center(child: GradientSpinner()))
          else if (!showStudentList) ...[
            _buildSingleActionButton(),
            const SizedBox(height: 25),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  Text(
                    AppLocalizations.of(context)!.selectCourse,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    ' (${courses.length})',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (!_isLoading)
            Expanded(
              child:
                  showStudentList
                      ? _buildStudentList()
                      : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        itemCount: courses.length,
                        itemBuilder:
                            (context, index) => GestureDetector(
                              onTap:
                                  () => _showDurationSelector(
                                    context,
                                    courses[index],
                                  ),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(25),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFF1DC),
                                      Color(0xFFE2C290),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Text(
                                  courses[index]['name'] ?? 'Course Name',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                      ),
            ),
        ],
      ),
    );
  }
}

class SingleActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const SingleActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Colors.black87),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
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

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:madarsaConnect/Faculty%20Screen/attendance_f.dart';
import 'package:madarsaConnect/Faculty%20Screen/add_student.dart';
import 'package:madarsaConnect/Faculty%20Screen/faculty_view_att.dart';
import 'package:madarsaConnect/Faculty%20Screen/leave_holiday_screen.dart';
import 'package:madarsaConnect/Head%20Screen/Examination_screen.dart';
import 'package:madarsaConnect/Head%20Screen/faculty_attendence.dart';
import 'package:madarsaConnect/Head%20Screen/promote_screen.dart';
import 'package:madarsaConnect/Head%20Screen/session_manage.dart';
import 'package:madarsaConnect/Head%20Screen/staff_panel.dart';
import 'package:madarsaConnect/Head%20Screen/course_manage.dart';
import 'package:madarsaConnect/Head%20Screen/student_find.dart';
import 'package:madarsaConnect/Head%20Screen/subject_manage.dart';
import 'package:madarsaConnect/Student%20Screen/attendence_view.dart';
import 'package:madarsaConnect/Student%20Screen/certificate_screen.dart';
import 'package:madarsaConnect/Student%20Screen/fees_screen.dart';
import 'package:madarsaConnect/Student%20Screen/quiz_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Faculty Screen/marks_screen.dart';
import '../Faculty Screen/student_manage.dart';
import '../Head Screen/add_faculty.dart';
import '../Head Screen/analytics.dart';
import '../Head Screen/request_screen.dart';

typedef SubscriptionCheckOnTap =
    void Function(BuildContext context, Widget destinationPage);

class AcademicAndToolsSection extends StatelessWidget {
  final String headUid;
  final SubscriptionCheckOnTap onTap;

  const AcademicAndToolsSection({
    Key? key,
    required this.headUid,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tileSize = screenWidth / 3.5;
    final imageColor = Colors.redAccent.shade100;

    return Column(
      children: [
        _buildSection(
          context: context,
          title: 'Academic Tools',
          tileSize: tileSize,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                customSizedTile(
                  'assets/images/staff.png',
                  'Staff Panel',
                  size: tileSize,
                  imageColor: imageColor,
                  onTap: () {
                    onTap(context, const StaffPanelScreen());
                  },
                ),
                customSizedTile(
                  'assets/images/course.png',
                  'Course Manage',
                  size: tileSize,
                  imageColor: imageColor,
                  onTap: () {
                    navigateWithPremiumTransition(
                      context,
                      const CourseManageScreen(),
                    );
                  },
                ),
                customSizedTile(
                  'assets/images/subject.png',
                  'Subject Manage',
                  size: tileSize,
                  imageColor: imageColor,
                  onTap: () {
                    navigateWithPremiumTransition(
                      context,
                      const SubjectManageScreen(),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                customSizedTile(
                  'assets/images/marks_manage.png',
                  'Marks Manage',
                  size: tileSize,
                  imageColor: imageColor,
                  onTap: () {
                    onTap(context, MarksManagementScreen(headUid: headUid));
                  },
                ),
                customSizedTile(
                  'assets/images/exam.png',
                  'Exam Manage',
                  size: tileSize,
                  imageColor: imageColor,
                  onTap: () {
                    navigateWithPremiumTransition(context, ExaminationScreen());
                  },
                ),
                customSizedTile(
                  'assets/images/promote.png',
                  'Promote Students',
                  size: tileSize,
                  imageColor: imageColor,
                  onTap: () {
                    onTap(context, PromoteStudentScreen());
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required double tileSize,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade400, width: 0.4),
      ),
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Gilroy-Bold',
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

Widget customSizedTile(
  String imagePath,
  String title, {
  double? size,
  VoidCallback? onTap,
  Color? imageColor,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final tileWidth = size ?? (MediaQuery.of(context).size.width - 48) / 3;
      final tileHeight = tileWidth * (160 / 110);

      return SizedBox(
        width: tileWidth,
        height: tileHeight,
        child: Card(
          elevation: 0,
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300, width: 1.0),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            highlightColor: Colors.grey.shade50,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Gilroy-Bold',
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -13,
                  right: 0,
                  child: Image.asset(
                    imagePath,
                    height: tileHeight * 0.5,
                    width: tileWidth * 0.5,
                    fit: BoxFit.contain,
                    color: imageColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class DashboardCards extends StatefulWidget {
  final Function(BuildContext, Widget) onTap;
  const DashboardCards({super.key, required this.onTap});

  @override
  State<DashboardCards> createState() => _DashboardCardsState();
}

class _DashboardCardsState extends State<DashboardCards> {
  String userRole = '';
  String? headUid;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    final firestore = FirebaseFirestore.instance;

    if (prefs.getBool('isHead') ?? false) {
      setState(() {
        userRole = 'head';
        headUid = user?.uid;
      });
    } else if (prefs.getBool('isFaculty') ?? false) {
      setState(() {
        userRole = 'faculty';
      });

      if (user != null) {
        final doc = await firestore.collection('Faculties').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            headUid = doc.data()?['headUid'];
          });
        }
      }
    } else if (prefs.getBool('isStudent') ?? false) {
      setState(() => userRole = 'student');
    } else {
      setState(() => userRole = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (userRole.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.01,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildLargeCard(
                  context: context,
                  title:
                      userRole == 'faculty'
                          ? 'Add Student'
                          : userRole == 'head'
                          ? 'Add Faculty'
                          : 'View Attendance',
                  subtitle:
                      userRole == 'faculty'
                          ? 'Student Adding, Management, View'
                          : userRole == 'head'
                          ? 'Faculty Adding, Management, View'
                          : 'View Attendance Only For Student',
                  imagePath:
                      userRole == 'head'
                          ? 'assets/images/faculty.png'
                          : userRole == 'faculty'
                          ? 'assets/images/faculty.png'
                          : 'assets/images/view_attendance.png',
                  imageColor:
                      userRole == 'head'
                          ? Colors.redAccent.shade100
                          : userRole == 'faculty'
                          ? Colors.redAccent.shade100
                          : Colors.redAccent.shade100,
                  onTap: () {
                    widget.onTap(
                      context,
                      userRole == 'faculty'
                          ? const AddStudent()
                          : userRole == 'head'
                          ? const AddFaculty()
                          : const StudentViewAttendanceScreen(),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _buildSmallCard(
                      title:
                          userRole == 'head'
                              ? 'Analytics'
                              : userRole == 'faculty'
                              ? 'Analytics'
                              : 'Analytics',
                      subtitle:
                          userRole == 'head'
                              ? 'Overall Data Management'
                              : userRole == 'faculty'
                              ? 'Student Performance & Records'
                              : 'Student Performance & Records',
                      imagePath: 'assets/images/analytics.png',
                      imageColor:
                          userRole == 'head'
                              ? Colors.redAccent.shade100
                              : userRole == 'faculty'
                              ? Colors.redAccent.shade100
                              : Colors.redAccent.shade100,
                      onTap: () {
                        widget.onTap(context, const AnalyticsScreen());
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildSmallCard(
                      title:
                          userRole == 'head'
                              ? 'Requests'
                              : userRole == 'faculty'
                              ? 'View Attendance'
                              : 'Quiz',
                      subtitle:
                          userRole == 'head'
                              ? 'Manage Student & Faculty Requests'
                              : userRole == 'faculty'
                              ? 'View Staff Attendance'
                              : 'Daily Quiz Attempt',
                      imagePath:
                          userRole == 'head'
                              ? 'assets/images/request.png'
                              : userRole == 'faculty'
                              ? 'assets/images/view_attendance.png'
                              : 'assets/images/qna.png',
                      imageColor:
                          userRole == 'head'
                              ? Colors.redAccent.shade100
                              : userRole == 'faculty'
                              ? Colors.redAccent.shade100
                              : Colors.redAccent.shade100,
                      onTap: () {
                        widget.onTap(
                          context,
                          userRole == 'head'
                              ? const RequestScreen()
                              : userRole == 'faculty'
                              ? const FacultyViewAttendanceScreen()
                              : const StudentQuizListScreen(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.01,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildSmallCard(
                      title:
                          userRole == 'head'
                              ? 'Student Manage'
                              : userRole == 'faculty'
                              ? 'Leave Request'
                              : 'Certificate',
                      subtitle:
                          userRole == 'head'
                              ? 'Any Student Access Data'
                              : userRole == 'faculty'
                              ? 'Request for leave (holiday)'
                              : 'View Your Certificates',
                      imagePath:
                          userRole == 'head'
                              ? 'assets/images/student_manage.png'
                              : userRole == 'faculty'
                              ? 'assets/images/leave.png'
                              : 'assets/images/certificate.png',
                      imageColor:
                          userRole == 'head'
                              ? Colors.redAccent.shade100
                              : userRole == 'faculty'
                              ? Colors.redAccent.shade100
                              : Colors.redAccent.shade100,
                      onTap: () {
                        widget.onTap(
                          context,
                          userRole == 'head'
                              ? const StudentFindScreen()
                              : userRole == 'faculty'
                              ? const LeaveScreen()
                              : const CertificateScreen(),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildSmallCard(
                      title:
                          userRole == 'head'
                              ? 'Session Control'
                              : userRole == 'faculty'
                              ? 'Marks Management'
                              : 'Leave Request',
                      subtitle:
                          userRole == 'head'
                              ? 'Manage Session & Examination'
                              : userRole == 'faculty'
                              ? 'Manage & Update Student Marks'
                              : 'Request for leave (holiday)',
                      imagePath:
                          userRole == 'head'
                              ? 'assets/images/session.png'
                              : userRole == 'faculty'
                              ? 'assets/images/marks_manage.png'
                              : 'assets/images/leave.png',
                      imageColor:
                          userRole == 'head'
                              ? Colors.redAccent.shade100
                              : userRole == 'faculty'
                              ? Colors.redAccent.shade100
                              : Colors.redAccent.shade100,
                      onTap: () {
                        widget.onTap(
                          context,
                          userRole == 'head'
                              ? SessionManagementScreen(headUid: headUid!)
                              : userRole == 'faculty'
                              ? StudentManagementScreen(headUid: headUid!)
                              : const LeaveScreen(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLargeCard(
                  context: context,
                  title:
                      userRole == 'head'
                          ? 'Attendance'
                          : userRole == 'faculty'
                          ? 'Student Attendance'
                          : 'Fees Management',
                  subtitle:
                      userRole == 'head'
                          ? 'Faculty Attendance Overview'
                          : userRole == 'faculty'
                          ? 'Mark Attendance'
                          : 'Organize, collect, and analyze fees easily',
                  imagePath:
                      userRole == 'head'
                          ? 'assets/images/attendance.png'
                          : userRole == 'faculty'
                          ? 'assets/images/attendance.png'
                          : 'assets/images/fees.png',
                  imageColor:
                      userRole == 'head'
                          ? Colors.redAccent.shade100
                          : userRole == 'faculty'
                          ? Colors.redAccent.shade100
                          : Colors.redAccent.shade100,
                  onTap: () {
                    if (userRole == 'head') {
                      widget.onTap(context, const AdminDashboardScreen());
                    } else if (userRole == 'faculty') {
                      widget.onTap(context, const DashboardScreen());
                    } else {
                      widget.onTap(context, const StudentFeePaymentScreen());
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLargeCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String imagePath,
    Color? imageColor,
    required VoidCallback onTap,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = MediaQuery.of(context).size.height;

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: height * 0.25,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade400, width: 0.8),
              ),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Padding(
                    padding: EdgeInsets.all(width * 0.05),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Gilroy-Bold',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontFamily: 'Gilroy-Regular',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: -15,
                    right: -6,
                    child: Image.asset(
                      imagePath,
                      height: width * 0.7,
                      width: width * 0.7,
                      fit: BoxFit.contain,
                      color: imageColor,
                      opacity: const AlwaysStoppedAnimation(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSmallCard({
    required String title,
    required String subtitle,
    required String imagePath,
    required VoidCallback onTap,
    Color? imageColor,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = MediaQuery.of(context).size.height;

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: height * 0.12,
              width: width,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade400, width: 0.8),
              ),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Padding(
                    padding: EdgeInsets.all(width * 0.05),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Gilroy-Bold',
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontFamily: 'Gilroy-Regular',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: -7,
                    right: 10,
                    child: Image.asset(
                      imagePath,
                      height: width * 0.35,
                      width: width * 0.33,
                      fit: BoxFit.contain,
                      opacity: const AlwaysStoppedAnimation(0.6),
                      color: imageColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class SubscriptionCard extends StatelessWidget {
  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final String iconPath;

  const SubscriptionCard({
    super.key,
    required this.onTap,
    this.title = 'Subscription',
    this.subtitle = 'Your access to exclusive features',
    this.iconPath = 'assets/images/subscription.png',
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const cardHeight = 80.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.red.withOpacity(0.1),
          highlightColor: Colors.red.withOpacity(0.05),
          child: Container(
            height: cardHeight,
            width: screenWidth * 0.95,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.grey.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withOpacity(0.08),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Image.asset(
                      iconPath,
                      fit: BoxFit.contain,
                      color: Colors.redAccent.shade200,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Gilroy-Bold',
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          fontFamily: 'Gilroy-Regular',
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 35,
                  width: 35,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.shade100,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InviteCard extends StatelessWidget {
  final VoidCallback? onTap;
  const InviteCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return LayoutBuilder(
      builder: (context, constraints) {
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            height: 350,
            width: double.infinity,
            padding: EdgeInsets.all(width * 0.04),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "You ❤️ Madarsa",
                  style: TextStyle(
                    fontSize: width * 0.05,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Gilroy-Bold',
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6),
                Text(
                  "Your friends are going to love us too!",
                  style: TextStyle(
                    fontSize: width * 0.045,
                    fontFamily: 'Gilroy-Bold',
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6),
                Text(
                  "Invite a friend to join Madarsa Connect ➟",
                  style: TextStyle(
                    fontSize: width * 0.038,
                    fontFamily: 'Gilroy-Bold',
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                Image.asset(
                  'assets/images/invite.png',
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ImageCarouselSlider extends StatelessWidget {
  final List<String> imagePaths;
  final PageController controller;
  final VoidCallback? onTap;

  const ImageCarouselSlider({
    super.key,
    required this.imagePaths,
    required this.controller,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return SizedBox(
      height: height * 0.22,
      child: PageView.builder(
        controller: controller,
        itemCount: imagePaths.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: width * 0.01,
            ), // responsive padding
            child: Material(
              borderRadius: BorderRadius.circular(
                width * 0.04,
              ), // responsive radius
              child: InkWell(
                borderRadius: BorderRadius.circular(width * 0.04),
                onTap: onTap,
                splashColor: Colors.blue.withOpacity(0.3),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(width * 0.04),
                  child: Image.asset(
                    imagePaths[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ResponsiveImageCarousel extends StatelessWidget {
  final List<String> cardImages;
  final PageController pageController;

  const ResponsiveImageCarousel({
    Key? key,
    required this.cardImages,
    required this.pageController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.of(context).size.height * 0.2;

    return SizedBox(
      height: height,
      child: PageView.builder(
        controller: pageController,
        itemCount: cardImages.length,
        itemBuilder: (context, index) {
          final imagePath = cardImages[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.0),
            child: Material(
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {},
                splashColor: Colors.blue.withOpacity(0.3),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imagePath,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(child: Icon(Icons.error));
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class DonationCard extends StatelessWidget {
  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final String imagePath;

  const DonationCard({
    Key? key,
    required this.onTap,
    this.title = 'Donate Charity',
    this.subtitle = 'Help us build a better community',
    this.imagePath = 'assets/icons/donation.svg',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const cardHeight = 80.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.red.withOpacity(0.1),
          highlightColor: Colors.red.withOpacity(0.05),
          child: Container(
            height: cardHeight,
            width: screenWidth * 0.95,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.grey.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon with circular background
                Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withOpacity(0.08),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: SvgPicture.asset(
                      imagePath, // Using the parameter here
                      fit: BoxFit.contain,
                      colorFilter: ColorFilter.mode(
                        Colors.redAccent.shade200,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Title and Subtitle
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16, // Font size matched
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Gilroy-Bold',
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13, // Font size matched
                          color: Colors.grey,
                          fontFamily: 'Gilroy-Regular',
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),

                // Forward arrow icon
                Container(
                  height: 35,
                  width: 35,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.shade100,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void navigateWithPremiumTransition(BuildContext context, Widget page) {
  Navigator.of(context).push(
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slideTween = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );
        return SlideTransition(position: slideTween, child: child);
      },
    ),
  );
}

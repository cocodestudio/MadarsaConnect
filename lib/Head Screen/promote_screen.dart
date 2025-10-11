import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:madarsaConnect/Data/loader.dart';
import 'package:madarsaConnect/Data/dynamic_popup.dart';

import '../utils/firebase_notification_helper.dart';

class PromoteStudentScreen extends StatefulWidget {
  const PromoteStudentScreen({super.key});

  @override
  State<PromoteStudentScreen> createState() => _PromoteStudentScreenState();
}

class _PromoteStudentScreenState extends State<PromoteStudentScreen> {
  String? headUid;
  bool isLoading = true;
  List<Map<String, dynamic>> courses = [];
  Map<String, dynamic>? selectedCourse;
  int? selectedYear;
  List<Map<String, dynamic>> students = [];
  Set<String> selectedStudents = {};

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadHeadUidAndCourses();
  }

  Future<void> _loadHeadUidAndCourses() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      headUid = currentUser.uid;
      await _fetchCourses();
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _fetchCourses() async {
    if (headUid == null) return;
    try {
      final snapshot =
          await _firestore
              .collection('courses')
              .where('headUid', isEqualTo: headUid)
              .get();

      if (mounted) {
        setState(() {
          courses =
              snapshot.docs.map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  'name': data['name'] ?? '',
                  'duration': data['duration'] ?? 1,
                  'code': data['code'] ?? '',
                };
              }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        CustomPopup.show(context, "Error fetching courses: $e");
      }
    }
  }

  Future<void> _fetchStudentsForPromotion() async {
    if (selectedCourse == null || selectedYear == null) return;
    if (mounted) setState(() => isLoading = true);
    selectedStudents.clear();

    try {
      final courseName = selectedCourse!['name'];
      final duration = '${selectedYear}${_getSuffix(selectedYear!)} Year';

      final studentSnapshot =
          await _firestore
              .collection('Students')
              .where('headUid', isEqualTo: headUid)
              .where('course', isEqualTo: courseName)
              .where('courseDuration', isEqualTo: duration)
              .orderBy('rollNo')
              .get();

      if (mounted) {
        setState(() {
          students =
              studentSnapshot.docs.map((doc) {
                final studentData = doc.data();
                return {
                  'uid': doc.id,
                  'fullName': studentData['fullName'] ?? '',
                  'rollNo': studentData['rollNo'] ?? 0,
                  'sucId': studentData['sucId'] ?? '',
                  'courseDurationNumber':
                      studentData['courseDurationNumber'] ?? selectedYear,
                  'profilePictureUrl': studentData['profilePictureUrl'],
                  'fcmToken': studentData['fcmToken'],
                };
              }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        CustomPopup.show(context, "Error fetching students: $e");
      }
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _promoteStudent(Map<String, dynamic> student) async {
    if (headUid == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: GradientSpinner()),
    );

    try {
      final studentId = student['uid'];
      final int currentCourseYear = student['courseDurationNumber'] ?? 0;
      final int nextCourseYear = currentCourseYear + 1;
      final int courseDurationMax = selectedCourse?['duration'] ?? 1;
      final studentName = student['fullName'] ?? 'Student';

      if (currentCourseYear < courseDurationMax) {
        final String nextCourseDuration =
            '${nextCourseYear}${_getSuffix(nextCourseYear)} Year';
        await _firestore.collection('Students').doc(studentId).update({
          'courseDurationNumber': nextCourseYear,
          'courseDuration': nextCourseDuration,
        });
        if (mounted) {
          CustomPopup.show(context, "$studentName promoted successfully.");
        }
      } else {
        await _firestore.collection('Students').doc(studentId).update({
          'enrollmentStatus': 'Completed',
        });
        await _firestore.collection('ArchivedEnrollments').add({
          'studentUid': studentId,
          'courseName': selectedCourse!['name'],
          'sucId': student['sucId'],
          'rollNo': student['rollNo'],
          'academicYear': selectedYear,
          'status': 'Completed',
        });
        if (mounted) {
          CustomPopup.show(
            context,
            "$studentName has completed the course and is archived.",
          );
        }
      }

      if (mounted) {
        setState(() {
          students.removeWhere((s) => s['uid'] == studentId);
          selectedStudents.remove(studentId);
        });
      }
    } catch (e) {
      if (mounted) {
        CustomPopup.show(context, "Error promoting student: $e");
      }
    } finally {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _promoteSelectedStudents() async {
    if (selectedStudents.isEmpty) {
      CustomPopup.show(context, "Please select students.");
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: GradientSpinner()),
    );

    try {
      final batch = _firestore.batch();
      final studentsToPromote =
          students.where((s) => selectedStudents.contains(s['uid'])).toList();

      for (var student in studentsToPromote) {
        final studentId = student['uid'];
        final int currentCourseYear = student['courseDurationNumber'] ?? 0;
        final int courseDurationMax = selectedCourse?['duration'] ?? 1;
        final String? fcmToken = student['fcmToken'];

        final settingsDoc =
            await _firestore
                .collection('notificationSettings')
                .doc(studentId)
                .get();
        final bool isPushEnabled = settingsDoc.data()?['push'] ?? true;
        final bool isInAppEnabled = settingsDoc.data()?['inApp'] ?? true;

        String notificationTitle;
        String notificationBody;

        if (currentCourseYear < courseDurationMax) {
          final String nextCourseDuration =
              '${currentCourseYear + 1}${_getSuffix(currentCourseYear + 1)} Year';
          batch.update(_firestore.collection('Students').doc(studentId), {
            'courseDurationNumber': currentCourseYear + 1,
            'courseDuration': nextCourseDuration,
          });
          notificationTitle = 'Congratulations!';
          notificationBody =
              'You have been promoted to the $nextCourseDuration.';
        } else {
          final newArchiveDoc =
              _firestore.collection('ArchivedEnrollments').doc();
          batch.set(newArchiveDoc, {
            'studentUid': studentId,
            'courseName': selectedCourse!['name'],
            'sucId': student['sucId'],
            'rollNo': student['rollNo'],
            'academicYear': selectedYear,
            'status': 'Completed',
          });
          notificationTitle = 'Course Completed!';
          notificationBody =
              'Congratulations! You have successfully completed your course.';
        }

        if (isPushEnabled && fcmToken != null && fcmToken.isNotEmpty) {
          FirebaseNotificationHelper.sendNotificationFromApp(
            fcmToken: fcmToken,
            title: notificationTitle,
            body: notificationBody,
          ).catchError(
            (e) => print(
              'Error sending push notification to student $studentId: $e',
            ),
          );
        }

        if (isInAppEnabled) {
          final notificationDoc = _firestore.collection('notifications').doc();
          batch.set(notificationDoc, {
            'recipientId': studentId,
            'title': notificationTitle,
            'message': notificationBody,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'type': 'studentPromotion',
            'senderId': _auth.currentUser!.uid,
            'senderName': 'Admin',
          });
        }
      }

      await batch.commit();

      if (mounted) {
        setState(() {
          students.removeWhere((s) => selectedStudents.contains(s['uid']));
          selectedStudents.clear();
        });
        Navigator.pop(context);
        CustomPopup.show(
          context,
          "All selected students processed successfully.",
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        CustomPopup.show(context, "Error promoting students: $e");
      }
    }
  }

  String _getSuffix(int n) {
    if (n >= 11 && n <= 13) return 'th';
    switch (n % 10) {
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final baseFontSize = screenWidth * 0.045;

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
            if (selectedCourse != null) {
              setState(() {
                selectedCourse = null;
                selectedYear = null;
                students.clear();
                selectedStudents.clear();
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          selectedCourse == null ? 'Promote Students' : 'Select Students',
          style: const TextStyle(
            fontSize: 20,
            fontFamily: 'Gilroy-Bold',
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child:
                isLoading
                    ? const Center(child: GradientSpinner())
                    : selectedCourse == null
                    ? _buildCourseSelectionList(baseFontSize)
                    : _buildStudentPromotionList(),
          ),
          if (selectedStudents.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _promoteSelectedStudents,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text('Promote ${selectedStudents.length} Students'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCourseSelectionList(double baseFontSize) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const PromoteStudentCard(
              title: 'Promote Student',
              subtitle: 'Select students to promote to the next academic year.',
              gradientColors: [Color(0xFFE6F7F1), Color(0xFFC2F0DF)],
            ),
            const SizedBox(height: 26),
            ...courses.map((course) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () {
                    _showDurationSelector(course);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                course['name'] ?? '',
                                style: TextStyle(
                                  fontSize: baseFontSize.clamp(14, 22),
                                  fontFamily: 'Gilroy-Bold',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Code: ${course['code'] ?? ''}',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Duration: ${course['duration']} Years',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  void _showDurationSelector(Map<String, dynamic> course) {
    final duration = course['duration'] ?? 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) {
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
              const Center(
                child: Text(
                  'Select Course Year',
                  style: TextStyle(fontSize: 18, fontFamily: 'Gilroy-Bold'),
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
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          selectedCourse = course;
                          selectedYear = year;
                        });
                        _fetchStudentsForPromotion();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.redAccent,
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${year}${_getSuffix(year)} Year',
                            style: const TextStyle(
                              fontSize: 16,
                              fontFamily: 'Gilroy-Bold',
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

  Widget _buildStudentPromotionList() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            PromoteStudentCard(
              title: 'Promote ${selectedCourse!['name']}',
              subtitle: '${selectedYear}${_getSuffix(selectedYear!)} Year',
              gradientColors: [Colors.blue.shade100, Colors.blue.shade300],
            ),
            const SizedBox(height: 16),
            if (students.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${selectedStudents.length} of ${students.length} selected',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (selectedStudents.length == students.length) {
                            selectedStudents.clear();
                          } else {
                            selectedStudents =
                                students.map((s) => s['uid'] as String).toSet();
                          }
                        });
                      },
                      child: Text(
                        selectedStudents.length == students.length
                            ? 'Deselect All'
                            : 'Select All',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (students.isEmpty)
              const Center(child: Text('No students found in this year.'))
            else
              ...students.map((student) {
                bool isSelected = selectedStudents.contains(student['uid']);

                return Card(
                  color: Colors.white,
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage:
                          student['profilePictureUrl'] != null &&
                                  student['profilePictureUrl']
                                      .toString()
                                      .isNotEmpty
                              ? NetworkImage(student['profilePictureUrl'])
                                  as ImageProvider
                              : null,
                      child:
                          student['profilePictureUrl'] == null ||
                                  student['profilePictureUrl']
                                      .toString()
                                      .isEmpty
                              ? const Icon(Icons.person, color: Colors.white)
                              : null,
                    ),
                    title: Text(
                      student['fullName'] ?? 'N/A',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Roll No: ${student['rollNo'] ?? 'N/A'}'),
                    trailing: Checkbox(
                      value: isSelected,
                      activeColor: Colors.redAccent,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            selectedStudents.add(student['uid']);
                          } else {
                            selectedStudents.remove(student['uid']);
                          }
                        });
                      },
                    ),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}

class PromoteStudentCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<Color> gradientColors;

  const PromoteStudentCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
  });

  @override
  State<PromoteStudentCard> createState() => _PromoteStudentCardState();
}

class _PromoteStudentCardState extends State<PromoteStudentCard> {
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
                color: widget.gradientColors.first.withOpacity(0.6),
                blurRadius: 9,
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
                  fontFamily: 'Gilroy-Bold',
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  fontFamily: 'Gilroy-Regular',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

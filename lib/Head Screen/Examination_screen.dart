import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Data/dynamic_popup.dart';
import '../Data/loader.dart';
import '../l10n/app_localizations.dart';
import '../utils/firebase_notification_helper.dart';

class ExaminationScreen extends StatefulWidget {
  const ExaminationScreen({super.key});

  @override
  State<ExaminationScreen> createState() => _ExaminationScreenState();
}

class _ExaminationScreenState extends State<ExaminationScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _courseController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _examTypeController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _scheduleSelectController =
      TextEditingController();
  final TextEditingController _maxMarksController = TextEditingController();
  final TextEditingController _passingMarksController = TextEditingController();

  List<Map<String, dynamic>> _courseList = [];
  int _selectedCourseDuration = 0;
  int _selectedTab = 0;
  bool _isPressed = false;
  List<String> _subjectList = ['All'];
  List<Map<String, dynamic>> _allSchedules = [];
  Map<String, dynamic>? _selectedScheduleData;
  bool _showHistoryScreen = false;
  bool _showHistory = false;
  String _selectedSession = '';
  String? _headUid;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadHeadDataAndFetchCourses();
  }

  Future<void> _loadHeadDataAndFetchCourses() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      _headUid = currentUser.uid;
      await _fetchCoursesFromFirestore();
    } else {
      debugPrint("User not authenticated for ExaminationScreen.");
    }
  }

  Future<void> _fetchCoursesFromFirestore() async {
    if (_headUid == null) return;

    try {
      final snapshot =
          await _firestore
              .collection('courses')
              .where('headUid', isEqualTo: _headUid)
              .get();

      List<Map<String, dynamic>> fetchedCourses = [
        {'name': 'All', 'duration': 8, 'id': null},
      ];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = data['name']?.toString() ?? '';
        final duration = int.tryParse(data['duration']?.toString() ?? '1') ?? 1;
        fetchedCourses.add({'name': name, 'duration': duration, 'id': doc.id});
      }

      if (mounted) {
        setState(() {
          _courseList = fetchedCourses;
        });
      }
    } catch (e) {
      debugPrint("Error fetching courses: $e");
    }
  }

  Future<void> _selectExamDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.redAccent,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _dateController.text = "${picked.day}/${picked.month}/${picked.year}";
    }
  }

  Future<void> _fetchSubjects() async {
    _subjectList = ['All'];
    if (_headUid == null ||
        _courseController.text == 'All' ||
        _durationController.text == 'All') {
      return;
    }

    try {
      final selectedCourseData = _courseList.firstWhere(
        (element) => element['name'] == _courseController.text,
        orElse: () => {'id': null},
      );

      final courseId = selectedCourseData['id'];
      if (courseId == null) return;

      final selectedYear =
          int.tryParse(_durationController.text.split(' ').first) ?? 1;

      final subjectSnap =
          await _firestore
              .collection('subjects')
              .where('courseId', isEqualTo: courseId)
              .where('year', isEqualTo: selectedYear)
              .where('headUid', isEqualTo: _headUid)
              .get();

      for (final doc in subjectSnap.docs) {
        _subjectList.add(doc['name']);
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Error fetching subjects: $e");
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.redAccent,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _endDateController.text = "${picked.day}/${picked.month}/${picked.year}";
    }
  }

  void _showSubjectPopupDialog() async {
    if (_subjectList.length <= 1) await _fetchSubjects();

    String? tempSelected = _subjectController.text;

    showDialog(
      context: context,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;

        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            AppLocalizations.of(context)!.selectSubject,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          content: SizedBox(
            height: screenHeight * 0.3,
            width: screenWidth * 0.9,
            child: ListView.builder(
              itemCount: _subjectList.length,
              itemBuilder: (context, index) {
                final subject = _subjectList[index];
                return RadioListTile<String>(
                  value: subject,
                  groupValue: tempSelected,
                  title: Text(
                    subject,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.start,
                  ),
                  activeColor: Colors.redAccent,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onChanged: (val) {
                    Navigator.pop(context);
                    if (mounted) {
                      setState(() {
                        _subjectController.text = val!;
                      });
                    }
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showCoursePopupDialog() async {
    if (_courseList.isEmpty) {
      await _fetchCoursesFromFirestore();
    }

    String? tempSelected = _courseController.text;

    showDialog(
      context: context,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;

        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            AppLocalizations.of(context)!.selectCourse,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          content: SizedBox(
            height: screenHeight * 0.3,
            width: screenWidth * 0.9,
            child: ListView.builder(
              itemCount: _courseList.length,
              itemBuilder: (context, index) {
                final course = _courseList[index];
                final name = course['name'] as String;

                return RadioListTile<String>(
                  value: name,
                  groupValue: tempSelected,
                  title: Text(
                    name,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.start,
                  ),
                  activeColor: Colors.redAccent,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onChanged: (val) {
                    Navigator.pop(context);
                    if (mounted) {
                      setState(() {
                        tempSelected = val;
                        if (val == 'All') {
                          _courseController.text = 'All';
                          _selectedCourseDuration = 8;
                        } else {
                          final selected = _courseList.firstWhere(
                            (e) => e['name'] == val,
                          );
                          _courseController.text = selected['name'];
                          _selectedCourseDuration = selected['duration'];
                        }
                        _durationController.clear();
                        _subjectController.clear();
                        _subjectList.clear();
                      });
                    }
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showDurationPopupDialog() {
    if (_selectedCourseDuration == 0) {
      CustomPopup.show(
        context,
        AppLocalizations.of(context)!.pleaseSelectCourseDurationFirst,
      );
      return;
    }

    final List<String> years = ['All'];
    List<String> suffix = ['st', 'nd', 'rd', 'th', 'th', 'th', 'th', 'th'];

    for (int i = 1; i <= _selectedCourseDuration; i++) {
      years.add('$i${suffix[i - 1]} ${AppLocalizations.of(context)!.year}');
    }

    String? tempSelected = _durationController.text;

    showDialog(
      context: context,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;

        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            AppLocalizations.of(context)!.selectDuration,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          content: SizedBox(
            height: screenHeight * 0.3,
            width: screenWidth * 0.9,
            child: ListView.builder(
              itemCount: years.length,
              itemBuilder: (context, index) {
                return RadioListTile<String>(
                  value: years[index],
                  groupValue: tempSelected,
                  title: Text(
                    years[index],
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.start,
                  ),
                  activeColor: Colors.redAccent,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onChanged: (val) {
                    Navigator.pop(context);
                    if (mounted) {
                      setState(() {
                        tempSelected = val!;
                        _durationController.text = val;
                        _subjectController.clear();
                        _subjectList.clear();
                      });
                    }
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showExamTypeDialog() {
    final List<String> types = ['Half Yearly Exam', 'Annually Exam'];
    String? tempSelected = _examTypeController.text;

    showDialog(
      context: context,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;

        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            AppLocalizations.of(context)!.selectExamType,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          content: SizedBox(
            height: screenHeight * 0.3,
            width: screenWidth * 0.9,
            child: ListView.builder(
              itemCount: types.length,
              itemBuilder: (context, index) {
                final type = types[index];
                return RadioListTile<String>(
                  value: type,
                  groupValue: tempSelected,
                  title: Text(
                    type,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.start,
                  ),
                  activeColor: Colors.redAccent,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onChanged: (val) {
                    Navigator.pop(context);
                    if (mounted) {
                      setState(() {
                        tempSelected = val!;
                        _examTypeController.text = val;
                      });
                    }
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showSessionSelector() {
    final now = DateTime.now();
    final startYear = 2025;
    final currentYear = now.month >= 4 ? now.year : now.year - 1;

    List<Widget> sessionWidgets = [];

    for (int year = startYear; year <= currentYear + 10; year++) {
      String session = "$year-${year + 1}";
      sessionWidgets.add(
        ListTile(
          title: Text(session),
          onTap: () {
            if (mounted) {
              setState(() {
                _selectedSession = session;
                _showHistory = true;
              });
            }
            Navigator.pop(context);
          },
        ),
      );
    }

    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        return SizedBox(
          height: screenHeight * 0.6,
          child: ListView(shrinkWrap: true, children: sessionWidgets),
        );
      },
    );
  }

  void _showCreateScheduleDialog() {
    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.70,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      AppLocalizations.of(context)!.createExamSchedule,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildCustomTextField(
                    controller: _examTypeController,
                    hint: AppLocalizations.of(context)!.selectExamType,
                    icon: Icons.assignment_outlined,
                    onTap: _showExamTypeDialog,
                  ),
                  const SizedBox(height: 10),
                  _buildCustomTextField(
                    controller: _courseController,
                    hint: AppLocalizations.of(context)!.selectCourse,
                    icon: Icons.book_outlined,
                    onTap: () async {
                      if (_courseList.length <= 1)
                        await _fetchCoursesFromFirestore();
                      _showCoursePopupDialog();
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildCustomTextField(
                    controller: _durationController,
                    hint: AppLocalizations.of(context)!.selectDuration,
                    icon: Icons.access_time,
                    onTap: _showDurationPopupDialog,
                  ),
                  const SizedBox(height: 10),
                  _buildCustomTextField(
                    controller: _subjectController,
                    hint: AppLocalizations.of(context)!.selectSubject,
                    icon: Icons.menu_book,
                    onTap: _showSubjectPopupDialog,
                  ),
                  const SizedBox(height: 10),
                  _buildCustomTextField(
                    controller: _dateController,
                    hint: AppLocalizations.of(context)!.examinationDate,
                    icon: Icons.date_range,
                    onTap: _selectExamDate,
                  ),
                  const SizedBox(height: 10),
                  _buildCustomTextField(
                    controller: _endDateController,
                    hint: AppLocalizations.of(context)!.endDate,
                    icon: Icons.date_range,
                    onTap: _selectEndDate,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        if (_examTypeController.text.isEmpty ||
                            _courseController.text.isEmpty ||
                            _durationController.text.isEmpty ||
                            _dateController.text.isEmpty) {
                          CustomPopup.show(
                            context,
                            AppLocalizations.of(context)!.fillAllRequiredFields,
                          );
                          return;
                        }

                        if (mounted) {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const GradientSpinner(),
                          );
                        }

                        try {
                          final now = DateTime.now();
                          final currentYear = now.year;
                          final nextYear =
                              now.month >= 4 ? currentYear + 1 : currentYear;
                          final session = "$currentYear-$nextYear";

                          await _firestore.collection('examination').add({
                            'examType': _examTypeController.text,
                            'course': _courseController.text,
                            'duration': _durationController.text,
                            'subject': _subjectController.text,
                            'date': _dateController.text,
                            'endDate': _endDateController.text,
                            'createdAt': FieldValue.serverTimestamp(),
                            'headUid': _headUid,
                            'session': session,
                          });

                          final studentsSnapshot =
                              await _firestore
                                  .collection('Students')
                                  .where('headUid', isEqualTo: _headUid)
                                  .get();

                          final facultiesSnapshot =
                              await _firestore
                                  .collection('Faculties')
                                  .where('headUid', isEqualTo: _headUid)
                                  .get();

                          final allUsers = [
                            ...studentsSnapshot.docs,
                            ...facultiesSnapshot.docs,
                          ];

                          for (var userDoc in allUsers) {
                            final userId = userDoc.id;

                            final settingsDoc =
                                await _firestore
                                    .collection('notificationSettings')
                                    .doc(userId)
                                    .get();
                            final bool isPushEnabled =
                                settingsDoc.data()?['push'] ?? true;
                            final bool isInAppEnabled =
                                settingsDoc.data()?['inApp'] ?? true;

                            final token = userDoc.data()['fcmToken'];
                            final notificationTitle =
                                AppLocalizations.of(context)!.newExamSchedule;
                            final notificationBody = AppLocalizations.of(
                              context,
                            )!.newExamBody(
                              _examTypeController.text,
                              _courseController.text,
                            );

                            if (isPushEnabled &&
                                token != null &&
                                token.toString().isNotEmpty) {
                              try {
                                await FirebaseNotificationHelper.sendNotificationFromApp(
                                  fcmToken: token,
                                  title: notificationTitle,
                                  body: notificationBody,
                                );
                              } catch (e) {
                                print(
                                  '❌ Error sending push notification to user $userId: $e',
                                );
                              }
                            }

                            if (isInAppEnabled) {
                              await _firestore.collection('notifications').add({
                                'recipientId': userId,
                                'title': notificationTitle,
                                'message': notificationBody,
                                'timestamp': FieldValue.serverTimestamp(),
                                'isRead': false,
                                'type': 'newExam',
                                'senderId': _headUid,
                                'senderName': 'Admin',
                                'senderProfileUrl': null,
                                'targetId': null,
                                'targetType': null,
                              });
                            }
                          }

                          if (mounted) Navigator.pop(context);
                          if (mounted) Navigator.pop(context);

                          _examTypeController.clear();
                          _courseController.clear();
                          _durationController.clear();
                          _dateController.clear();
                          _endDateController.clear();
                          _subjectController.clear();
                        } catch (e) {
                          if (mounted) Navigator.pop(context);
                          if (mounted) {
                            CustomPopup.show(
                              context,
                              "${AppLocalizations.of(context)!.error}: $e",
                            );
                          }
                        }
                      },
                      child: Text(
                        AppLocalizations.of(context)!.add,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      style: const TextStyle(color: Colors.black, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.black.withOpacity(0.8)),
        fillColor: Colors.white,
        filled: true,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.grey, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.black, width: 1),
        ),
      ),
    );
  }

  void _showScheduleSelectDialog() {
    String? tempSelected = _scheduleSelectController.text;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            AppLocalizations.of(context)!.selectExamSchedule,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          content: SafeArea(
            child: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _allSchedules.length,
                    itemBuilder: (context, index) {
                      final schedule = _allSchedules[index];
                      final label =
                          "${schedule['examType']} ${schedule['session']}";

                      return RadioListTile<String>(
                        value: label,
                        groupValue: tempSelected,
                        title: Text(
                          label,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.start,
                        ),
                        activeColor: Colors.redAccent,
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onChanged: (val) {
                          Navigator.pop(context);
                          if (mounted) {
                            setState(() {
                              tempSelected = val!;
                              _scheduleSelectController.text = val;

                              final matched = _allSchedules.firstWhere(
                                (element) =>
                                    "${element['examType']} ${element['session']}" ==
                                    val,
                                orElse: () => {},
                              );

                              if (matched.isNotEmpty) {
                                _selectedScheduleData = matched;
                              } else {
                                _selectedScheduleData = null;
                              }
                            });
                          }
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showScheduleOptions(String docId, Map<String, dynamic> data) {
    showModalBottomSheet(
      backgroundColor: Colors.white,
      isScrollControlled: true,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 12,
              left: 12,
              right: 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 16),
                ListTile(
                  title: Text(
                    AppLocalizations.of(context)!.edit,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditScheduleDialog(docId, data);
                  },
                ),
                ListTile(
                  title: Text(
                    AppLocalizations.of(context)!.delete,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _firestore
                        .collection('examination')
                        .doc(docId)
                        .delete();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditScheduleDialog(String docId, Map<String, dynamic> data) {
    _examTypeController.text = data['examType'];
    _courseController.text = data['course'];
    _durationController.text = data['duration'];
    _subjectController.text = data['subject'];
    _dateController.text = data['date'];
    _endDateController.text = data['endDate'];

    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  Text(
                    AppLocalizations.of(context)!.editSchedule,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildEditField(
                    _examTypeController,
                    AppLocalizations.of(context)!.examType,
                    _showExamTypeDialog,
                  ),
                  _buildEditField(
                    _courseController,
                    AppLocalizations.of(context)!.course,
                    _showCoursePopupDialog,
                  ),
                  _buildEditField(
                    _durationController,
                    AppLocalizations.of(context)!.duration,
                    _showDurationPopupDialog,
                  ),
                  _buildEditField(
                    _subjectController,
                    AppLocalizations.of(context)!.subject,
                    _showSubjectPopupDialog,
                  ),
                  _buildEditField(
                    _dateController,
                    AppLocalizations.of(context)!.date,
                    _selectExamDate,
                  ),
                  _buildEditField(
                    _endDateController,
                    AppLocalizations.of(context)!.endDate,
                    _selectEndDate,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (mounted) {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const GradientSpinner(),
                          );
                        }

                        try {
                          await _firestore
                              .collection('examination')
                              .doc(docId)
                              .update({
                                'examType': _examTypeController.text,
                                'course': _courseController.text,
                                'duration': _durationController.text,
                                'subject': _subjectController.text,
                                'date': _dateController.text,
                                'endDate': _endDateController.text,
                              });

                          if (mounted) Navigator.pop(context);
                          if (mounted) Navigator.pop(context);
                        } catch (e) {
                          if (mounted) Navigator.pop(context);
                          if (mounted) {
                            CustomPopup.show(
                              context,
                              "${AppLocalizations.of(context)!.error}: $e",
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.update,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditField(
    TextEditingController controller,
    String hint,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        style: const TextStyle(color: Colors.black, fontSize: 14),
        controller: controller,
        readOnly: true,
        onTap: onTap,
        decoration: InputDecoration(
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.grey, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.black, width: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBox(String label, int index) {
    bool isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (mounted) setState(() => _selectedTab = index);
        },
        child: Container(
          height: MediaQuery.of(context).size.height * 0.1,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: isSelected ? Colors.redAccent.shade200 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _courseController.dispose();
    _durationController.dispose();
    _dateController.dispose();
    _examTypeController.dispose();
    _subjectController.dispose();
    _endDateController.dispose();
    _scheduleSelectController.dispose();
    _maxMarksController.dispose();
    _passingMarksController.dispose();
    super.dispose();
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        "$label: ${value ?? '-'}",
        style: const TextStyle(fontSize: 14),
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
            if (_showHistoryScreen) {
              if (mounted) setState(() => _showHistoryScreen = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _showHistoryScreen
              ? AppLocalizations.of(context)!.history
              : AppLocalizations.of(context)!.examination,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!_showHistoryScreen)
            IconButton(
              icon: const Icon(Icons.history, size: 26, color: Colors.black),
              onPressed: () {
                if (mounted) setState(() => _showHistoryScreen = true);
              },
            )
          else
            const SizedBox(width: 48),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_showHistoryScreen) ...[
                Row(
                  children: [
                    _buildTabBox(AppLocalizations.of(context)!.schedule, 0),
                    _buildTabBox(
                      AppLocalizations.of(context)!.reportsManage,
                      1,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_selectedTab == 1)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                        left: 4,
                        right: 4,
                        top: 4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _scheduleSelectController,
                            readOnly: true,
                            onTap: _showScheduleSelectDialog,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  AppLocalizations.of(
                                    context,
                                  )!.selectExamSchedule,
                              prefixIcon: const Icon(Icons.event),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
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
                          const SizedBox(height: 20),
                          if (_selectedScheduleData != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.3),
                                    blurRadius: 5,
                                    offset: const Offset(0, -5),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDetailRow(
                                    AppLocalizations.of(context)!.examType,
                                    _selectedScheduleData!['examType'],
                                  ),
                                  _buildDetailRow(
                                    AppLocalizations.of(context)!.course,
                                    _selectedScheduleData!['course'],
                                  ),
                                  _buildDetailRow(
                                    AppLocalizations.of(context)!.duration,
                                    _selectedScheduleData!['duration'],
                                  ),
                                  _buildDetailRow(
                                    AppLocalizations.of(context)!.subject,
                                    _selectedScheduleData!['subject'],
                                  ),
                                  _buildDetailRow(
                                    AppLocalizations.of(context)!.date,
                                    _selectedScheduleData!['date'],
                                  ),
                                  _buildDetailRow(
                                    AppLocalizations.of(context)!.endDate,
                                    _selectedScheduleData!['endDate'],
                                  ),
                                  _buildDetailRow(
                                    AppLocalizations.of(context)!.session,
                                    _selectedScheduleData!['session'],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                AppLocalizations.of(context)!.setValue,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            TextField(
                              controller: _maxMarksController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    AppLocalizations.of(context)!.maxMarks,
                                prefixIcon: const Icon(Icons.score),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
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
                            const SizedBox(height: 15),
                            TextField(
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                              ),
                              keyboardType: TextInputType.number,
                              controller: _passingMarksController,
                              decoration: InputDecoration(
                                hintText:
                                    AppLocalizations.of(
                                      context,
                                    )!.setPassingValue,
                                prefixIcon: const Icon(Icons.check_circle),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
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
                            const SizedBox(height: 25),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 40,
                                    vertical: 14,
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () async {
                                  if (_maxMarksController.text.isEmpty ||
                                      _passingMarksController.text.isEmpty) {
                                    CustomPopup.show(
                                      context,
                                      AppLocalizations.of(
                                        context,
                                      )!.fillMaxAndPassing,
                                    );
                                    return;
                                  }
                                  if (mounted) {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder:
                                          (context) => const GradientSpinner(),
                                    );
                                  }
                                  try {
                                    final docId = _selectedScheduleData!['id'];
                                    await _firestore
                                        .collection('examination')
                                        .doc(docId)
                                        .update({
                                          'maxMarks': int.tryParse(
                                            _maxMarksController.text,
                                          ),
                                          'passingMarks': int.tryParse(
                                            _passingMarksController.text,
                                          ),
                                        });
                                    if (mounted) Navigator.pop(context);
                                    if (mounted) {
                                      CustomPopup.show(
                                        context,
                                        AppLocalizations.of(
                                          context,
                                        )!.marksUpdatedSuccessfully,
                                      );
                                    }
                                    _maxMarksController.clear();
                                    _passingMarksController.clear();
                                    _scheduleSelectController.clear();
                                    if (mounted) {
                                      setState(
                                        () => _selectedScheduleData = null,
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      CustomPopup.show(
                                        context,
                                        "${AppLocalizations.of(context)!.error}: $e",
                                      );
                                    }
                                  }
                                },
                                child: Text(
                                  AppLocalizations.of(context)!.save,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                if (_selectedTab == 0) ...[
                  GestureDetector(
                    onTap: _showCreateScheduleDialog,
                    onTapDown: (_) {
                      HapticFeedback.lightImpact();
                      if (mounted) setState(() => _isPressed = true);
                    },
                    onTapUp: (_) {
                      if (mounted) setState(() => _isPressed = false);
                    },
                    onTapCancel: () {
                      if (mounted) setState(() => _isPressed = false);
                    },
                    child: AnimatedScale(
                      scale: _isPressed ? 0.97 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 180),
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFF1DC), Color(0xFFE2C290)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFF1DC).withOpacity(0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.createSchedule,
                              style: const TextStyle(
                                fontSize: 22,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(context)!.scheduleDescription,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              width: 35,
                              height: 35,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black,
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.arrow_forward,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: FutureBuilder<String?>(
                      future: (() async => _headUid)(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) {
                          return const Center(child: GradientSpinner());
                        }
                        final currentHeadUid = userSnapshot.data;
                        return StreamBuilder<QuerySnapshot>(
                          stream:
                              _firestore
                                  .collection('examination')
                                  .where('headUid', isEqualTo: currentHeadUid)
                                  .orderBy('createdAt', descending: true)
                                  .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(child: GradientSpinner());
                            }
                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return Center(
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.noSchedulesAdded,
                                ),
                              );
                            }
                            final rawDocs = snapshot.data!.docs;
                            final activeDocs =
                                rawDocs.where((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  final createdAt =
                                      data['createdAt'] as Timestamp?;
                                  if (createdAt == null) return false;
                                  final expiryDate = createdAt.toDate().add(
                                    const Duration(days: 90),
                                  );
                                  return expiryDate.isAfter(DateTime.now());
                                }).toList();

                            _allSchedules =
                                activeDocs.map((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  return {'id': doc.id, ...data};
                                }).toList();

                            return ListView.builder(
                              itemCount: activeDocs.length,
                              itemBuilder: (context, index) {
                                final data =
                                    activeDocs[index].data()
                                        as Map<String, dynamic>;
                                final docId = activeDocs[index].id;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
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
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    title: Text(
                                      data['examType'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      "${AppLocalizations.of(context)!.date}: ${data['date'] ?? 'N/A'}",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    trailing: GestureDetector(
                                      onTap:
                                          () =>
                                              _showScheduleOptions(docId, data),
                                      child: const Icon(Icons.more_vert),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ],
              if (_showHistoryScreen) Expanded(child: _HistoryScreenWidget()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _HistoryScreenWidget() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.selectSessionTitle,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showSessionSelector(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedSession.isEmpty
                            ? AppLocalizations.of(context)!.select
                            : _selectedSession,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_showHistory)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  _firestore
                      .collection('examination')
                      .where('session', isEqualTo: _selectedSession)
                      .where('headUid', isEqualTo: _headUid)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: GradientSpinner());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      AppLocalizations.of(context)!.noDataFoundForSession,
                    ),
                  );
                }
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.yellow.shade700,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  data['examType'] ??
                                      AppLocalizations.of(context)!.examType,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  data['session'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            AppLocalizations.of(context)!.course,
                            data['course'],
                          ),
                          _buildDetailRow(
                            AppLocalizations.of(context)!.duration,
                            data['duration'],
                          ),
                          _buildDetailRow(
                            AppLocalizations.of(context)!.subject,
                            data['subject'],
                          ),
                          _buildDetailRow(
                            AppLocalizations.of(context)!.examDate,
                            data['date'],
                          ),
                          _buildDetailRow(
                            AppLocalizations.of(context)!.endDate,
                            data['endDate'],
                          ),
                          if (data['maxMarks'] != null)
                            _buildDetailRow(
                              AppLocalizations.of(context)!.maxMarks,
                              data['maxMarks'],
                            ),
                          if (data['passingMarks'] != null)
                            _buildDetailRow(
                              AppLocalizations.of(context)!.passingMarks,
                              data['passingMarks'],
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

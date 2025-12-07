import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Data/uppercase.dart';
import '../l10n/app_localizations.dart';

void main() {
  runApp(const MaterialApp(home: CourseManageScreen()));
}

class CourseManageScreen extends StatefulWidget {
  const CourseManageScreen({super.key});

  @override
  State<CourseManageScreen> createState() => _CourseManageScreenState();
}

class _CourseManageScreenState extends State<CourseManageScreen> {
  List<Map<String, dynamic>> courses = [];
  String? headUid;
  int selectedDuration = 0;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _suffix(int n) {
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

  final TextEditingController nameController = TextEditingController();
  final TextEditingController codeController = TextEditingController();
  final TextEditingController durationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserAndCourses();
  }

  Future<void> _loadUserAndCourses() async {
    final prefs = await SharedPreferences.getInstance();
    bool? isHead = prefs.getBool('isHead');

    if (isHead == true) {
      headUid = _auth.currentUser?.uid;
      if (headUid != null) {
        final snapshot =
            await _firestore
                .collection('courses')
                .where('headUid', isEqualTo: headUid)
                .get();

        setState(() {
          courses =
              snapshot.docs.map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  'name': data['name']?.toString() ?? '',
                  'code': data['code']?.toString() ?? '',
                  'duration': data['duration'] ?? 1,
                };
              }).toList();
        });
      }
    }
  }

  Future<void> _saveCourseToFirestore({
    Map<String, dynamic>? course,
    String? courseId,
  }) async {
    if (headUid == null) {
      return;
    }

    final data = {
      'name': nameController.text.trim(),
      'code': codeController.text.trim(),
      'duration': selectedDuration,
      'headUid': headUid,
    };

    if (courseId != null) {
      await _firestore.collection('courses').doc(courseId).update(data);
    } else {
      await _firestore.collection('courses').add(data);
    }

    await _loadUserAndCourses();

    setState(() {
      nameController.clear();
      codeController.clear();
      selectedDuration = 1;
    });
  }

  Future<void> _deleteCourse(String courseId) async {
    if (headUid == null) return;

    await _firestore.collection('courses').doc(courseId).delete();

    await _loadUserAndCourses();
  }

  void _showCourseDialog({Map<String, dynamic>? course}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (course == null) {
      nameController.clear();
      codeController.clear();
      durationController.clear();
      selectedDuration = 0;
    } else {
      nameController.text = course['name'] ?? '';
      codeController.text = course['code'] ?? '';
      final dur = course['duration'] ?? 0;
      selectedDuration = dur;
      durationController.text =
          dur > 0
              ? '$dur${_suffix(dur)} ${AppLocalizations.of(context)!.year}'
              : '';
    }

    nameController.addListener(() {
      String name = nameController.text.trim();
      if (name.isNotEmpty) {
        String firstWord = name.split(" ")[0];
        codeController.text = firstWord.toUpperCase();
      } else {
        codeController.text = "";
      }
    });

    bool isButtonEnabledLocal =
        nameController.text.trim().isNotEmpty &&
        codeController.text.trim().isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        final safeBottom = MediaQuery.of(ctx).viewPadding.bottom;

        return StatefulBuilder(
          builder: (context, setState) {
            void onTextChanged() {
              final enabled =
                  nameController.text.trim().isNotEmpty &&
                  codeController.text.trim().isNotEmpty;
              if (enabled != isButtonEnabledLocal) {
                setState(() {
                  isButtonEnabledLocal = enabled;
                });
              }
            }

            nameController.removeListener(onTextChanged);
            codeController.removeListener(onTextChanged);
            nameController.addListener(onTextChanged);
            codeController.addListener(onTextChanged);

            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: bottomInset + (safeBottom > 0 ? safeBottom : 20),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.05,
                  vertical: screenHeight * 0.020,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Text(
                        course == null
                            ? AppLocalizations.of(context)!.addCourse
                            : AppLocalizations.of(context)!.editCourse,
                        style: TextStyle(
                          fontSize: screenWidth * 0.05,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.025),

                    // Name
                    TextField(
                      controller: nameController,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [UpperCaseTextFormatter()],
                      style: TextStyle(
                        fontSize: screenWidth * 0.037,
                        color: Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.enterCourseName,
                        prefixIcon: Icon(
                          Icons.drive_file_rename_outline,
                          color: Colors.black.withOpacity(0.8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        counterText: '',
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: Colors.black),
                        ),
                      ),
                    ),

                    SizedBox(height: screenHeight * 0.015),

                    // Duration Selector
                    GestureDetector(
                      onTap: () => _showDurationSelector(context),
                      child: AbsorbPointer(
                        child: TextField(
                          controller: durationController,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(
                            fontSize: screenWidth * 0.037,
                            color: Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                AppLocalizations.of(context)!.selectDuration,
                            prefixIcon: Icon(
                              Icons.access_time_filled,
                              color: Colors.black.withOpacity(0.8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            counterText: '',
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(color: Colors.black),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: screenHeight * 0.015),

                    // Course Code
                    TextField(
                      controller: codeController,
                      readOnly: true,
                      textInputAction: TextInputAction.done,
                      style: TextStyle(
                        fontSize: screenWidth * 0.037,
                        color: Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.enterCourseCode,
                        prefixIcon: Icon(
                          Icons.code,
                          color: Colors.black.withOpacity(0.8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        counterText: '',
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: Colors.black),
                        ),
                      ),
                      onSubmitted: (_) {
                        if (isButtonEnabledLocal) {
                          _saveCourseToFirestore(
                            course: course,
                            courseId: course?['id'],
                          );
                          Navigator.of(context).pop();
                        }
                      },
                    ),

                    SizedBox(height: screenHeight * 0.04),

                    // Save/Add Button
                    SizedBox(
                      width: double.infinity,
                      height: screenHeight * 0.06,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isButtonEnabledLocal && selectedDuration > 0
                                  ? Colors.redAccent
                                  : Colors.redAccent.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed:
                            isButtonEnabledLocal && selectedDuration > 0
                                ? () {
                                  _saveCourseToFirestore(
                                    course: course,
                                    courseId: course?['id'],
                                  );
                                  nameController.clear();
                                  codeController.clear();
                                  Navigator.of(context).pop();
                                }
                                : null,
                        child: Text(
                          course == null
                              ? AppLocalizations.of(context)!.add
                              : AppLocalizations.of(context)!.save,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: screenWidth * 0.04,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.02),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDurationSelector(BuildContext context) {
    final yearSuffix = ['st', 'nd', 'rd', 'th', 'th', 'th', 'th', 'th'];

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
                  itemCount: 8,
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
                          selectedDuration = year;
                          durationController.text = '$year$suffix Year';
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: Center(
                          child: Text(
                            '$year$suffix Year',
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

  void _showOptions(int index) {
    showModalBottomSheet(
      backgroundColor: Colors.white,
      isScrollControlled: true,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) {
        final bottomPadding = MediaQuery.of(ctx).viewPadding.bottom;
        final screenHeight = MediaQuery.of(ctx).size.height;
        final screenWidth = MediaQuery.of(ctx).size.width;
        final courseId = courses[index]['id'];

        return Padding(
          padding: EdgeInsets.only(
            left: screenWidth * 0.03,
            right: screenWidth * 0.03,
            top: screenHeight * 0.015,
            bottom: bottomPadding > 0 ? bottomPadding : screenHeight * 0.025,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    width: 40,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              ListTile(
                title: Text(
                  AppLocalizations.of(context)!.edit,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: screenWidth * 0.045,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showUpdateWarningPopup(
                    context: context,
                    onOk: () {
                      _showCourseDialog(course: courses[index]);
                    },
                  );
                },
              ),
              ListTile(
                title: Text(
                  AppLocalizations.of(context)!.delete,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: screenWidth * 0.045,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  _deleteCourse(courseId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showUpdateWarningPopup({
    required BuildContext context,
    required VoidCallback onOk,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Update Warning",
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, __, ___) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, _) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        );

        return ScaleTransition(
          scale: curvedAnimation,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.80,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.warning,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)!.editCourseWarning,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          AppLocalizations.of(context)!.cancel,
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onOk();
                        },
                        child: Text(
                          AppLocalizations.of(context)!.ok,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
          icon: const Icon(Icons.arrow_back, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.courseManagement,
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
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CourseCard(
                        title: AppLocalizations.of(context)!.addCourseName,
                        subtitle:
                            AppLocalizations.of(context)!.addCourseSubtitle,
                        gradientColors: const [
                          Color(0xFFFFF1DC),
                          Color(0xFFE2C290),
                        ],
                        onTap: () => _showCourseDialog(),
                      ),
                      const SizedBox(height: 26),
                      ...courses.asMap().entries.map((entry) {
                        final i = entry.key;
                        final course = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.3),
                                blurRadius: 5,
                                offset: const Offset(0, -5),
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
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${AppLocalizations.of(context)!.code}: ${course['code'] ?? ''}',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${AppLocalizations.of(context)!.duration}: ${course['duration'] != null ? '${course['duration']}${_suffix(course['duration'])} ${AppLocalizations.of(context)!.year}' : 'N/A'}',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _showOptions(i),
                                icon: const Icon(Icons.more_vert),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
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
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const CourseCard({
    super.key,
    required this.title,
    required this.subtitle,
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
              const Spacer(),
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
    );
  }
}

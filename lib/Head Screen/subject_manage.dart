import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Data/dynamic_popup.dart';
import '../Data/uppercase.dart';
import '../l10n/app_localizations.dart';

class SubjectManageScreen extends StatefulWidget {
  const SubjectManageScreen({super.key});

  @override
  State<SubjectManageScreen> createState() => _SubjectManageScreenState();
}

class _SubjectManageScreenState extends State<SubjectManageScreen> {
  List<Map<String, dynamic>> courses = [];
  String? headUid;
  Map<String, dynamic>? selectedCourse;
  int? selectedYear;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
        _firestore
            .collection('courses')
            .where('headUid', isEqualTo: headUid)
            .snapshots()
            .listen((snapshot) {
              if (mounted) {
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
            });
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (selectedCourse != null) {
      setState(() {
        selectedCourse = null;
        selectedYear = null;
      });
      return false;
    }
    return true;
  }

  Future<void> _showAddSubjectDialog(
    String courseId,
    String courseCode,
    int year,
  ) async {
    final TextEditingController _nameController = TextEditingController();
    final TextEditingController _codeController = TextEditingController();
    final ValueNotifier<bool> isFilled = ValueNotifier(false);

    final snapshot =
        await _firestore
            .collection('subjects')
            .where('courseId', isEqualTo: courseId)
            .where('year', isEqualTo: year)
            .where('headUid', isEqualTo: headUid)
            .get();

    int subjectCount = snapshot.docs.length;
    int startingCode = (year * 100) + 1 + subjectCount;
    String finalCode = "$courseCode-$startingCode";
    _codeController.text = finalCode;

    void _checkFields() {
      final name = _nameController.text.trim();
      final code = _codeController.text.trim();
      isFilled.value = name.isNotEmpty && code.length > courseCode.length;
    }

    _nameController.addListener(_checkFields);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        final viewInsets = MediaQuery.of(context).viewInsets.bottom;
        final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

        return Padding(
          padding: EdgeInsets.only(
            bottom:
                viewInsets > 0
                    ? viewInsets
                    : (bottomPadding > 0 ? bottomPadding : 20),
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.addSubject,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [UpperCaseTextFormatter()],
                  style: const TextStyle(color: Colors.black, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.enterSubjectName,
                    counterText: "",
                    prefixIcon: Icon(
                      Icons.drive_file_rename_outline,
                      color: Colors.black.withOpacity(0.8),
                    ),
                    fillColor: Colors.white,
                    filled: true,
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
                const SizedBox(height: 14),
                TextField(
                  controller: _codeController,
                  readOnly: true,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(color: Colors.black, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.enterSubjectCode,
                    prefixIcon: Icon(
                      Icons.code,
                      color: Colors.black.withOpacity(0.8),
                    ),
                    fillColor: Colors.white,
                    filled: true,
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
                const SizedBox(height: 24),
                ValueListenableBuilder<bool>(
                  valueListenable: isFilled,
                  builder: (context, filled, _) {
                    return SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor:
                              filled ? Colors.redAccent : Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed:
                            filled
                                ? () async {
                                  try {
                                    final name = _nameController.text.trim();
                                    final code = _codeController.text.trim();
                                    await _firestore
                                        .collection('subjects')
                                        .add({
                                          'name': name,
                                          'code': code,
                                          'courseId': courseId,
                                          'courseName': selectedCourse!['name'],
                                          'year': year,
                                          'headUid': headUid,
                                          'timestamp':
                                              FieldValue.serverTimestamp(),
                                        });
                                    Navigator.pop(context);
                                    CustomPopup.show(
                                      context,
                                      AppLocalizations.of(
                                        context,
                                      )!.subjectAddedSuccess,
                                    );
                                  } catch (e) {
                                    CustomPopup.show(
                                      context,
                                      '${AppLocalizations.of(context)!.failedToAddSubject}: $e',
                                    );
                                  }
                                }
                                : null,
                        child: Text(
                          AppLocalizations.of(context)!.addSubject,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteSubject(String subjectId) async {
    if (headUid == null) return;
    try {
      await _firestore.collection('subjects').doc(subjectId).delete();
      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.subjectDeletedSuccess,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomPopup.show(
          context,
          '${AppLocalizations.of(context)!.failedToDeleteSubject}: $e',
        );
      }
    }
  }

  void _showEditSubjectDialog(String subjectId, Map<String, dynamic> data) {
    final TextEditingController _nameController = TextEditingController(
      text: data['name'],
    );
    final TextEditingController _codeController = TextEditingController(
      text: data['code'],
    );
    final ValueNotifier<bool> isFilled = ValueNotifier(true);

    void _checkFields() {
      final name = _nameController.text.trim();
      final code = _codeController.text.trim();
      isFilled.value = name.isNotEmpty && code.isNotEmpty;
    }

    _nameController.addListener(_checkFields);
    _codeController.addListener(_checkFields);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        final viewInsets = MediaQuery.of(context).viewInsets.bottom;
        final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

        return Padding(
          padding: EdgeInsets.only(
            bottom:
                viewInsets > 0
                    ? viewInsets
                    : (bottomPadding > 0 ? bottomPadding : 20),
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.editSubject,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: Colors.black, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.enterSubjectName,
                    prefixIcon: const Icon(Icons.drive_file_rename_outline),
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
                const SizedBox(height: 6),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(color: Colors.black, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.enterSubjectCode,
                    prefixIcon: const Icon(Icons.code),
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
                const SizedBox(height: 30),
                ValueListenableBuilder<bool>(
                  valueListenable: isFilled,
                  builder: (context, filled, _) {
                    return SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              filled ? Colors.redAccent : Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed:
                            filled
                                ? () async {
                                  try {
                                    final name = _nameController.text.trim();
                                    final code = _codeController.text.trim();
                                    await _firestore
                                        .collection('subjects')
                                        .doc(subjectId)
                                        .update({'name': name, 'code': code});
                                    Navigator.pop(context);
                                    CustomPopup.show(
                                      context,
                                      AppLocalizations.of(
                                        context,
                                      )!.subjectUpdatedSuccess,
                                    );
                                  } catch (e) {
                                    CustomPopup.show(
                                      context,
                                      '${AppLocalizations.of(context)!.failedToUpdateSubject}: $e',
                                    );
                                  }
                                }
                                : null,
                        child: Text(
                          AppLocalizations.of(context)!.updateSubject,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 15),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDurationSelector(Map<String, dynamic> course) {
    final yearSuffix = [
      AppLocalizations.of(context)!.yearSuffixSt,
      AppLocalizations.of(context)!.yearSuffixNd,
      AppLocalizations.of(context)!.yearSuffixRd,
      AppLocalizations.of(context)!.yearSuffixTh,
    ];
    final duration = course['duration'] ?? 8;

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
                  AppLocalizations.of(context)!.selectYear,
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
                    String suffix;
                    if (year >= 11 && year <= 13) {
                      suffix = AppLocalizations.of(context)!.yearSuffixTh;
                    } else {
                      int remainder = year % 10;
                      if (remainder == 1) {
                        suffix = AppLocalizations.of(context)!.yearSuffixSt;
                      } else if (remainder == 2) {
                        suffix = AppLocalizations.of(context)!.yearSuffixNd;
                      } else if (remainder == 3) {
                        suffix = AppLocalizations.of(context)!.yearSuffixRd;
                      } else {
                        suffix = AppLocalizations.of(context)!.yearSuffixTh;
                      }
                    }

                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          selectedCourse = course;
                          selectedYear = year;
                        });
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
                            '$year$suffix ${AppLocalizations.of(context)!.year}',
                            style: const TextStyle(
                              fontSize: 16,
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

  String _getYearLabel(int year) {
    // Similar suffix logic here for display
    String suffix;
    if (year >= 11 && year <= 13) {
      suffix = AppLocalizations.of(context)!.yearSuffixTh;
    } else {
      int remainder = year % 10;
      if (remainder == 1) {
        suffix = AppLocalizations.of(context)!.yearSuffixSt;
      } else if (remainder == 2) {
        suffix = AppLocalizations.of(context)!.yearSuffixNd;
      } else if (remainder == 3) {
        suffix = AppLocalizations.of(context)!.yearSuffixRd;
      } else {
        suffix = AppLocalizations.of(context)!.yearSuffixTh;
      }
    }
    return '$year$suffix ${AppLocalizations.of(context)!.year}';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final baseFontSize = screenWidth * 0.045;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
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
                });
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(
            selectedCourse == null
                ? AppLocalizations.of(context)!.subjectManagement
                : '${selectedCourse!['name']}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: true,
        ),
        body:
            selectedCourse == null
                ? _buildCourseList(baseFontSize)
                : _buildSubjectList(selectedCourse!, selectedYear!),
      ),
    );
  }

  Widget _buildCourseList(double baseFontSize) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CourseCard(
              title: AppLocalizations.of(context)!.selectCourse,
              subtitle: AppLocalizations.of(context)!.addSubjectsToCourse,
              gradientColors: const [Color(0xFFFFF8F1), Color(0xFFD1A66C)],
              onTap: () {},
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
                                '${AppLocalizations.of(context)!.duration}: ${course['duration']} ${AppLocalizations.of(context)!.years}',
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

  Widget _buildSubjectList(Map<String, dynamic> course, int year) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SubjectCard(
              title: AppLocalizations.of(context)!.addSubject,
              subtitle: AppLocalizations.of(context)!.letsAddSubject,
              gradientColors: const [Color(0xFFFFF1DC), Color(0xFFE2C290)],
              onTap:
                  () => _showAddSubjectDialog(
                    course['id']!,
                    course['code'] ?? '',
                    year,
                  ),
            ),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream:
                  _firestore
                      .collection('subjects')
                      .where('courseId', isEqualTo: course['id'])
                      .where('year', isEqualTo: year)
                      .where('headUid', isEqualTo: headUid)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      '${AppLocalizations.of(context)!.error}: ${snapshot.error}',
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      AppLocalizations.of(
                        context,
                      )!.noSubjectsAddedForYear(_getYearLabel(year)),
                      style: const TextStyle(),
                    ),
                  );
                }

                final subjects = snapshot.data!.docs;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      subjects.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
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
                                      data['name'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      data['code'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${AppLocalizations.of(context)!.year}: ${data['year'] ?? 'N/A'}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  showModalBottomSheet(
                                    backgroundColor: Colors.white,
                                    context: context,
                                    isScrollControlled: true,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(25),
                                      ),
                                    ),
                                    builder: (context) {
                                      final bottomPadding =
                                          MediaQuery.of(
                                            context,
                                          ).viewPadding.bottom;
                                      return Padding(
                                        padding: EdgeInsets.only(
                                          left: 12,
                                          right: 12,
                                          top: 12,
                                          bottom:
                                              bottomPadding > 0
                                                  ? bottomPadding
                                                  : 20,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Center(
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  8.0,
                                                ),
                                                child: Container(
                                                  width: 40,
                                                  height: 2,
                                                  decoration: BoxDecoration(
                                                    color: Colors.black,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            ListTile(
                                              title: Text(
                                                AppLocalizations.of(
                                                  context,
                                                )!.edit,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 17,
                                                ),
                                              ),
                                              onTap: () {
                                                Navigator.pop(context);
                                                _showEditSubjectDialog(
                                                  doc.id,
                                                  data,
                                                );
                                              },
                                            ),
                                            ListTile(
                                              title: Text(
                                                AppLocalizations.of(
                                                  context,
                                                )!.delete,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 17,
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                              onTap: () async {
                                                Navigator.pop(context);
                                                _deleteSubject(doc.id);
                                              },
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                                child: const Icon(Icons.more_vert),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                );
              },
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
          height: MediaQuery.of(context).size.height * 0.14,
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

class SubjectCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const SubjectCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  State<SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<SubjectCard> {
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

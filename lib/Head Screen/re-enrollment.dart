import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Data/const.dart';
import '../Data/dynamic_popup.dart';
import '../Data/loader.dart';
import '../l10n/app_localizations.dart';

enum _SearchStep { search, form }

class ReEnrollStudentScreen extends StatefulWidget {
  const ReEnrollStudentScreen({super.key});

  @override
  State<ReEnrollStudentScreen> createState() => _ReEnrollStudentScreenState();
}

class _ReEnrollStudentScreenState extends State<ReEnrollStudentScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _courseController = TextEditingController();
  final TextEditingController _coursedurationController =
      TextEditingController();
  final TextEditingController _yearController = TextEditingController();

  _SearchStep _step = _SearchStep.search;
  bool _isLoading = false;
  Map<String, dynamic>? _searchedStudentData;
  String? _searchedStudentUid;

  List<String> courseList = [];
  int _selectedCourseDuration = 0;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    fetchCoursesFromHead();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _courseController.dispose();
    _coursedurationController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _handleBackButton() {
    if (_step == _SearchStep.form) {
      setState(() => _step = _SearchStep.search);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> fetchCoursesFromHead() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.userNotLoggedIn,
        );
      }
      return;
    }

    String? finalHeadUid;

    try {
      final prefs = await SharedPreferences.getInstance();
      final isHead = prefs.getBool('isHead') ?? false;
      final isFaculty = prefs.getBool('isFaculty') ?? false;
      if (isHead) {
        finalHeadUid = currentUser.uid;
      } else if (isFaculty) {
        final facultyDoc =
            await _firestore.collection('Faculties').doc(currentUser.uid).get();
        if (facultyDoc.exists) {
          finalHeadUid = facultyDoc.data()?['headUid'];
        }
      }

      if (finalHeadUid == null) {
        if (mounted) {
          CustomPopup.show(
            context,
            AppLocalizations.of(context)!.couldNotDetermineHead,
          );
        }
        return;
      }

      final snapshot =
          await _firestore
              .collection('courses')
              .where('headUid', isEqualTo: finalHeadUid)
              .get();

      if (mounted) {
        setState(() {
          courseList =
              snapshot.docs.map((doc) {
                final data = doc.data();
                return jsonEncode({
                  'name': data['name']?.toString() ?? '',
                  'duration': data['duration'] ?? 1,
                });
              }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        CustomPopup.show(
          context,
          "${AppLocalizations.of(context)!.errorFetchingCourses}: ${e.toString()}",
        );
      }
    }
  }

  Future<String> generateNextSUC() async {
    final counterRef = _firestore.collection('counters').doc('students');
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);
      if (!snapshot.exists) {
        transaction.set(counterRef, {'currentSUC': 1});
        return 'suc0000001';
      }
      int current =
          int.tryParse(snapshot.data()?['currentSUC'].toString() ?? '0') ?? 0;
      int next = current + 1;
      transaction.update(counterRef, {'currentSUC': next});
      return 'suc${next.toString().padLeft(7, '0')}';
    });
  }

  Future<void> _searchStudent() async {
    if (_searchController.text.trim().isEmpty) {
      CustomPopup.show(
        context,
        AppLocalizations.of(context)!.enterSucIdToSearch,
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      final query =
          await _firestore
              .collection('Students')
              .where(
                'sucId',
                isEqualTo: _searchController.text.trim().toLowerCase(),
              )
              .limit(1)
              .get();

      if (query.docs.isEmpty) {
        if (mounted) {
          CustomPopup.show(
            context,
            AppLocalizations.of(context)!.noStudentFoundSuc,
          );
        }
      } else {
        final studentDoc = query.docs.first;
        setState(() {
          _searchedStudentData = studentDoc.data();
          _searchedStudentUid = studentDoc.id;
          _step = _SearchStep.form;
        });
      }
    } catch (e) {
      if (mounted) {
        CustomPopup.show(
          context,
          "${AppLocalizations.of(context)!.anErrorOccurred}: ${e.toString()}",
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _reEnrollStudent() async {
    if (_courseController.text.isEmpty ||
        _coursedurationController.text.isEmpty ||
        _yearController.text.isEmpty) {
      CustomPopup.show(
        context,
        AppLocalizations.of(context)!.selectCourseDurationYear,
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      final newSucId = await generateNextSUC();
      final courseName = _courseController.text;
      final durationText = _coursedurationController.text;
      final headUid = _searchedStudentData?['headUid'];

      final counterDocId = "${headUid}_${courseName}_${durationText}";
      final counterRef = _firestore
          .collection('rollCounters')
          .doc(counterDocId);

      final newRollNo = await _firestore.runTransaction((transaction) async {
        final counterSnap = await transaction.get(counterRef);
        if (!counterSnap.exists) {
          transaction.set(counterRef, {'currentRoll': 1});
          return 1;
        }
        int currentRoll = counterSnap['currentRoll'] ?? 0;
        int nextRoll = currentRoll + 1;
        transaction.update(counterRef, {'currentRoll': nextRoll});
        return nextRoll;
      });

      final updateData = {
        'course': courseName,
        'courseDuration': durationText,
        'courseDurationNumber': int.tryParse(
          RegExp(r'^(\d+)').firstMatch(durationText)?.group(1) ?? '1',
        ),
        'sucId': newSucId,
        'rollNo': newRollNo,
        'academicYear': _yearController.text,
        'enrollmentStatus': 'Active',
      };

      await _firestore
          .collection('Students')
          .doc(_searchedStudentUid!)
          .update(updateData);

      _showSuccessDialog();
    } catch (e) {
      if (mounted) {
        CustomPopup.show(
          context,
          "${AppLocalizations.of(context)!.failedToReEnroll}: ${e.toString()}",
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showYearPickerDialog() {
    final currentYear = DateTime.now().year;
    final List<int> years = List.generate(10, (index) => currentYear + index);
    int selectedYearIndex = years.indexOf(
      int.tryParse(_yearController.text) ?? currentYear,
    );

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.selectAcademicYear,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(
                    initialItem: selectedYearIndex,
                  ),
                  itemExtent: 40,
                  onSelectedItemChanged: (int index) {
                    _yearController.text = years[index].toString();
                  },
                  children:
                      years
                          .map((year) => Center(child: Text(year.toString())))
                          .toList(),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context),
                child: Container(
                  alignment: Alignment.center,
                  width: 150,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.done,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void showCourseBottomSheet() {
    if (courseList.isEmpty) {
      CustomPopup.show(
        context,
        AppLocalizations.of(context)!.noCoursesAvailable,
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context)!.selectNewCourse,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: courseList.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final courseData = jsonDecode(courseList[index]);
                        return RadioListTile<String>(
                          value: courseData['name'],
                          groupValue: _courseController.text,
                          title: Text(courseData['name']),
                          activeColor: Colors.redAccent,
                          onChanged: (value) {
                            if (mounted) {
                              this.setState(() {
                                _courseController.text = value!;
                                _coursedurationController.clear();
                                _selectedCourseDuration =
                                    courseData['duration'];
                              });
                            }
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void showCourseDurationSheet() {
    if (_courseController.text.isEmpty) {
      CustomPopup.show(
        context,
        AppLocalizations.of(context)!.pleaseSelectCourseFirst,
      );
      return;
    }
    if (_selectedCourseDuration == 0) return;

    List<String> yearList = List.generate(_selectedCourseDuration, (i) {
      final year = i + 1;
      final yearSuffix = ['st', 'nd', 'rd', 'th'];
      return '$year${yearSuffix[year > 3 ? 3 : year - 1]} ${AppLocalizations.of(context)!.year}';
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context)!.selectNewDuration,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemCount: yearList.length,
                      itemBuilder: (context, index) {
                        return RadioListTile<String>(
                          value: yearList[index],
                          groupValue: _coursedurationController.text,
                          title: Text(yearList[index]),
                          activeColor: Colors.redAccent,
                          onChanged: (value) {
                            if (mounted) {
                              this.setState(
                                () => _coursedurationController.text = value!,
                              );
                            }
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSuccessDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Success',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder:
          (_, animation, __) => ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: Scaffold(
                backgroundColor: Colors.white,
                body: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(),
                        Image.asset(
                          'assets/images/done.png',
                          color: Colors.redAccent,
                          height: 150,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          AppLocalizations.of(
                            context,
                          )!.studentReEnrolledSuccess,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 50.0),
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).pop();
                            },
                            child: Container(
                              alignment: Alignment.center,
                              width: double.infinity,
                              height: 55,
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.done,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
          icon: const Icon(Icons.arrow_back, size: 26),
          onPressed: _handleBackButton,
        ),
        title: Text(
          _step == _SearchStep.search
              ? AppLocalizations.of(context)!.findStudent
              : AppLocalizations.of(context)!.reEnrollStudent,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body:
          _isLoading
              ? const Center(child: GradientSpinner())
              : _step == _SearchStep.search
              ? _buildSearchStep()
              : _buildFormStep(),
    );
  }

  Widget _buildSearchStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Image.asset(
            'assets/images/admission.png',
            height: 180,
            color: Colors.redAccent.shade100,
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context)!.reEnrollStudent,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.reEnrollDescription,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Colors.grey),
          ),
          const SizedBox(height: 30),
          TextField(
            controller: _searchController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.enterSucId,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Colors.black, width: 1),
              ),
            ),
          ),
          const SizedBox(height: 20),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _searchStudent,
            child: Container(
              alignment: Alignment.center,
              width: double.infinity,
              height: 55,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                AppLocalizations.of(context)!.searchStudent,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormStep() {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        Center(
          child: Text(
            "${AppLocalizations.of(context)!.profileFoundFor}: ${_searchedStudentData?['fullName']}",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          AppLocalizations.of(context)!.personalDetailsReadOnly,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 12),
        _buildReadOnlyTextField(
          AppLocalizations.of(context)!.fullName,
          _searchedStudentData?['fullName'],
          nameIcon,
        ),
        _buildReadOnlyTextField(
          AppLocalizations.of(context)!.dateOfBirth,
          _searchedStudentData?['dateOfBirth'],
          "assets/icons/calender.svg",
        ),
        _buildReadOnlyTextField(
          AppLocalizations.of(context)!.phoneNumber,
          _searchedStudentData?['phoneNumber'],
          phoneIcon,
        ),
        _buildReadOnlyTextField(
          AppLocalizations.of(context)!.email,
          _searchedStudentData?['email'],
          emailIcon,
        ),
        const SizedBox(height: 30),
        Text(
          AppLocalizations.of(context)!.newAcademicDetails,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        _buildEditableTextField(
          AppLocalizations.of(context)!.selectNewCourse,
          _courseController,
          Icons.work_outline,
          showCourseBottomSheet,
        ),
        const SizedBox(height: 12),
        _buildEditableTextField(
          AppLocalizations.of(context)!.selectNewDuration,
          _coursedurationController,
          Icons.access_time,
          showCourseDurationSheet,
        ),
        const SizedBox(height: 12),
        _buildEditableTextField(
          AppLocalizations.of(context)!.selectAcademicYear,
          _yearController,
          Icons.calendar_today,
          _showYearPickerDialog,
        ),
        const SizedBox(height: 40),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _reEnrollStudent,
          child: Container(
            alignment: Alignment.center,
            width: double.infinity,
            height: 55,
            decoration: BoxDecoration(
              color: _isLoading ? Colors.grey : Colors.redAccent,
              borderRadius: BorderRadius.circular(15),
            ),
            child:
                _isLoading
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                    : Text(
                      AppLocalizations.of(context)!.reEnrollStudent,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyTextField(String hint, String? value, String iconPath) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextField(
        controller: TextEditingController(text: value ?? 'N/A'),
        readOnly: true,
        style: const TextStyle(color: Colors.black54),
        decoration: InputDecoration(
          hintText: hint,
          fillColor: Colors.grey.shade100,
          filled: true,
          prefixIcon: Padding(
            padding: const EdgeInsets.all(14.0),
            child: SvgPicture.asset(
              iconPath,
              height: 22,
              width: 22,
              colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildEditableTextField(
    String hint,
    TextEditingController controller,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextField(
          controller: controller,
          readOnly: true,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.black),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),
      ),
    );
  }
}

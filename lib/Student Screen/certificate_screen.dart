import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:madarsaConnect/Data/loader.dart';
import '../Data/dynamic_popup.dart';
import '../Data/marksheet_generate.dart';

class CertificateScreen extends StatefulWidget {
  const CertificateScreen({super.key});

  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen> {
  final TextEditingController courseController = TextEditingController();
  final TextEditingController examController = TextEditingController();
  final TextEditingController durationController = TextEditingController();

  bool isLoading = true;
  String? _studentUid;
  String? _headUid;

  List<Map<String, dynamic>> _allEnrollments = [];
  Map<String, dynamic>? _selectedEnrollment;
  List<String> _availableExams = [];
  String? _selectedExamType;

  @override
  void initState() {
    super.initState();
    _loadAllEnrollments();
  }

  Future<void> _loadAllEnrollments() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      _studentUid = user.uid;

      List<Map<String, dynamic>> enrollments = [];

      final studentDoc =
          await FirebaseFirestore.instance
              .collection('Students')
              .doc(_studentUid)
              .get();

      Map<String, dynamic>? currentEnrollment;
      if (studentDoc.exists && studentDoc.data() != null) {
        final data = studentDoc.data()!;
        _headUid = data['headUid'];
        currentEnrollment = {
          'courseName': data['course']?.toString() ?? 'N/A',
          'sucId': data['sucId'] ?? '',
          'academicYear': data['courseDurationNumber'],
          'isArchived': false,
        };
        enrollments.add(currentEnrollment);
      }

      final archivedSnap =
          await FirebaseFirestore.instance
              .collection('ArchivedEnrollments')
              .where('studentUid', isEqualTo: _studentUid)
              .get();

      for (var doc in archivedSnap.docs) {
        enrollments.add({
          'courseName': doc.data()['courseName'] ?? 'N/A',
          'sucId': doc.data()['sucId'] ?? '',
          'academicYear': doc.data()['academicYear'],
          'isArchived': true,
        });
      }

      if (mounted) {
        setState(() {
          _allEnrollments = enrollments;
          if (currentEnrollment != null) {
            _selectedEnrollment = currentEnrollment;
            courseController.text = _selectedEnrollment!['courseName'];
            _fetchExamsForSelectedCourse();
          }
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading enrollments: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchExamsForSelectedCourse() async {
    if (_selectedEnrollment == null || _selectedEnrollment!['sucId'] == null)
      return;

    if (!mounted) return;
    setState(() {
      _availableExams = [];
      _selectedExamType = null;
      examController.clear();
      durationController.clear();
    });

    try {
      final sucId = _selectedEnrollment!['sucId'];
      final marksDoc =
          await FirebaseFirestore.instance
              .collection('studentMarks')
              .doc(sucId)
              .get();

      if (marksDoc.exists && marksDoc.data() != null) {
        final records = marksDoc.data()!['records'] as Map<String, dynamic>?;
        if (records != null) {
          final allExams = records.keys.toList();

          if (mounted) {
            setState(() {
              _availableExams = allExams;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching exams: $e");
    }
  }

  void _showCourseSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Course',
                style: TextStyle(fontSize: 20, fontFamily: 'Gilroy-Bold'),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _allEnrollments.length,
                  itemBuilder: (context, index) {
                    final enrollment = _allEnrollments[index];
                    return ListTile(
                      title: Text(enrollment['courseName']),
                      trailing:
                          enrollment['isArchived']
                              ? const Text("(Completed)")
                              : const Text("(Current)"),
                      onTap: () {
                        Navigator.pop(ctx);
                        if (mounted) {
                          setState(() {
                            _selectedEnrollment = enrollment;
                            courseController.text = enrollment['courseName'];
                            _fetchExamsForSelectedCourse();
                          });
                        }
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
  }

  void _showExamSelector(BuildContext context) {
    if (_availableExams.isEmpty) {
      showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('No Exam Data'),
              content: const Text('No exams found for this course.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Exam Type',
                style: TextStyle(fontSize: 20, fontFamily: 'Gilroy-Bold'),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _availableExams.length,
                  itemBuilder: (context, index) {
                    final exam = _availableExams[index];
                    final coursePrefix =
                        "${_selectedEnrollment!['courseName']} - ";
                    final cleanExamName = exam.replaceFirst(coursePrefix, '');
                    return ListTile(
                      title: Text(cleanExamName),
                      onTap: () {
                        Navigator.pop(ctx);
                        if (mounted) {
                          setState(() {
                            _selectedExamType = exam;
                            examController.text = cleanExamName;
                            durationController.clear();
                          });
                        }
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
  }

  void _showDurationSelector(BuildContext context) async {
    if (_selectedExamType == null ||
        _selectedEnrollment == null ||
        _selectedEnrollment!['sucId'] == null) {
      CustomPopup.show(context, 'Please select a course and exam first.');
      return;
    }

    final sucId = _selectedEnrollment!['sucId'];
    final marksDoc =
        await FirebaseFirestore.instance
            .collection('studentMarks')
            .doc(sucId)
            .get();
    if (!marksDoc.exists || marksDoc.data() == null) {
      CustomPopup.show(context, 'No marks found.');
      return;
    }
    final records = marksDoc.data()!['records'] as Map<String, dynamic>;
    final examRecords = records[_selectedExamType!] as Map<String, dynamic>?;

    if (examRecords == null || examRecords.isEmpty) {
      CustomPopup.show(context, 'No records for this exam.');
      return;
    }

    final List<String> availableDurations =
        examRecords.keys
            .where((key) => !['totalPercentage', 'resultStatus'].contains(key))
            .toList();

    if (availableDurations.isEmpty) {
      CustomPopup.show(context, 'No year/duration found for this exam.');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Year',
                style: TextStyle(fontSize: 20, fontFamily: 'Gilroy-Bold'),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableDurations.length,
                  itemBuilder: (context, index) {
                    final duration = availableDurations[index];
                    return ListTile(
                      title: Text(duration),
                      onTap: () {
                        Navigator.pop(ctx);
                        if (mounted) {
                          setState(() {
                            durationController.text = duration;
                          });
                        }
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
  }

  Future<void> _checkMarksApprovalAndNavigate() async {
    if (_selectedEnrollment == null ||
        _selectedEnrollment!['sucId'] == null ||
        _selectedExamType == null ||
        durationController.text.isEmpty) {
      CustomPopup.show(context, 'Please select all fields.');
      return;
    }
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final sucId = _selectedEnrollment!['sucId'];
      final marksDoc =
          await FirebaseFirestore.instance
              .collection('studentMarks')
              .doc(sucId)
              .get();
      final records = marksDoc.data()!['records'] as Map<String, dynamic>;
      final examRecords = records[_selectedExamType!] as Map<String, dynamic>;
      final durationRecords =
          examRecords[durationController.text] as Map<String, dynamic>;

      bool isApproved = durationRecords.values.every(
        (subjectData) =>
            subjectData is Map<String, dynamic> &&
            (subjectData['isApproved'] ?? false),
      );

      if (!isApproved) {
        CustomPopup.show(context, 'Result not yet approved.');
      } else {
        await _fetchDataAndGenerateMarksheet();
      }
    } catch (e) {
      CustomPopup.show(context, 'Error checking approval.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchDataAndGenerateMarksheet() async {
    try {
      DocumentSnapshot studentDataSource;
      if (_selectedEnrollment!['isArchived']) {
        final querySnapshot =
            await FirebaseFirestore.instance
                .collection('ArchivedEnrollments')
                .where('sucId', isEqualTo: _selectedEnrollment!['sucId'])
                .limit(1)
                .get();
        if (querySnapshot.docs.isEmpty) {
          CustomPopup.show(context, 'Archived student data not found.');
          return;
        }
        studentDataSource = querySnapshot.docs.first;
      } else {
        studentDataSource =
            await FirebaseFirestore.instance
                .collection('Students')
                .doc(_studentUid)
                .get();
      }

      final sucId = _selectedEnrollment!['sucId'];
      final marksDoc =
          await FirebaseFirestore.instance
              .collection('studentMarks')
              .doc(sucId)
              .get();
      final headDoc =
          await FirebaseFirestore.instance
              .collection('Heads')
              .doc(_headUid)
              .get();

      if (!studentDataSource.exists || !marksDoc.exists || !headDoc.exists) {
        if (mounted) {
          CustomPopup.show(context, 'Required data not found.');
        }
        return;
      }

      final studentData = studentDataSource.data() as Map<String, dynamic>;
      final studentMainData =
          (await FirebaseFirestore.instance
                  .collection('Students')
                  .doc(_studentUid)
                  .get())
              .data()!;
      final marksData = marksDoc.data()!;
      final headData = headDoc.data()!;

      final studentProfileData = {
        'fullName': studentMainData['fullName'] ?? 'N/A',
        'sucId': _selectedEnrollment!['sucId'] ?? 'N/A',
        'fatherName': studentMainData['fatherName'] ?? 'N/A',
        'motherName': studentMainData['motherName'] ?? 'N/A',
        'dateOfBirth': studentMainData['dateOfBirth'] ?? 'N/A',
        'rollNo': studentData['rollNo']?.toString() ?? 'N/A',
        'course': _selectedEnrollment!['courseName'] ?? 'N/A',
        'courseDuration': durationController.text,
        'academicYear': studentData['academicYear']?.toString() ?? 'N/A',
        'examType': _selectedExamType,
        'madarsaName': headData['madarsaName'] ?? 'N/A',
      };

      final examRecords =
          marksData['records'][_selectedExamType!] as Map<String, dynamic>?;
      final marks =
          examRecords?[durationController.text] as Map<String, dynamic>?;

      if (marks == null) {
        if (mounted) {
          CustomPopup.show(context, 'Marks not found for selected year.');
        }
        return;
      }

      final marksheetData = {
        'records': {
          _selectedExamType!: {durationController.text: marks},
        },
        'totalPercentage': examRecords?['totalPercentage'] ?? 'N/A',
        'resultStatus': examRecords?['resultStatus'] ?? 'N/A',
      };

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => MarksheetPreviewScreen(
                  studentData: studentProfileData,
                  marksData: marksheetData,
                  selectedYear: durationController.text,
                  headLogoUrl: headData['logoUrl'] as String?,
                  headSignatureUrl: headData['signatureUrl'] as String?,
                  studentSignatureUrl: studentMainData['signatureUrl'],
                ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        CustomPopup.show(context, 'Error generating marksheet.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

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
          'Certificate',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Gilroy-Bold',
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child:
            isLoading
                ? const Center(child: GradientSpinner())
                : Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.05,
                    vertical: screenHeight * 0.02,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            _buildCertificateCard(context),
                            SizedBox(height: screenHeight * 0.02),
                            _buildDropdownField(
                              context,
                              'Select Course',
                              courseController,
                              () => _showCourseSelector(context),
                            ),
                            SizedBox(height: screenHeight * 0.02),
                            _buildDropdownField(
                              context,
                              'Select Exam Type',
                              examController,
                              () => _showExamSelector(context),
                            ),
                            SizedBox(height: screenHeight * 0.02),
                            _buildDropdownField(
                              context,
                              'Select Year',
                              durationController,
                              () => _showDurationSelector(context),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: screenHeight * 0.02,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                (_selectedExamType != null &&
                                        durationController.text.isNotEmpty &&
                                        !isLoading)
                                    ? _checkMarksApprovalAndNavigate
                                    : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 0,
                            ),
                            child:
                                isLoading
                                    ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    )
                                    : const Text(
                                      'Generate Marksheet',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
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

  Widget _buildDropdownField(
    BuildContext context,
    String label,
    TextEditingController controller,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          controller: controller,
          readOnly: true,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(fontFamily: 'Gilroy-Bold'),
            filled: true,
            fillColor: Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(
              vertical: 18,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
        ),
      ),
    );
  }

  Widget _buildCertificateCard(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final title = _selectedEnrollment?['courseName'] ?? 'Select a Course';
    final subtitle = "Download Your Marksheets";

    return Container(
      height: screenHeight * 0.20,
      width: double.infinity,
      margin: EdgeInsets.only(bottom: screenHeight * 0.01),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFE6F7F1), Color(0xFFC2F0DF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE6F7F1).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: screenWidth * 0.055,
              color: Colors.black,
              fontFamily: 'Gilroy-Bold',
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: screenWidth * 0.038,
              color: Colors.black.withOpacity(0.65),
              fontFamily: 'Gilroy-Regular',
            ),
          ),
        ],
      ),
    );
  }
}

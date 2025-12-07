import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Data/check_internet.dart';
import '../Data/dynamic_popup.dart';
import '../Data/loader.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';

class StudentFindScreen extends StatefulWidget {
  const StudentFindScreen({super.key});

  @override
  State<StudentFindScreen> createState() => _StudentFindScreenState();
}

class _StudentFindScreenState extends State<StudentFindScreen> {
  final TextEditingController controller = TextEditingController();
  int totalStudents = 0;
  bool isLoading = false;
  Map<String, dynamic>? studentData;
  String? headUid;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadHeadData();
  }

  Future<void> _loadHeadData() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      setState(() {
        headUid = currentUser.uid;
      });
      _firestore
          .collection('Students')
          .where('headUid', isEqualTo: headUid)
          .snapshots()
          .listen((snapshot) {
            if (mounted) {
              setState(() {
                totalStudents = snapshot.docs.length;
              });
            }
          });
    } else {
      if (mounted) {
        setState(() {
          headUid = null;
        });
      }
    }
  }

  Future<void> fetchStudentBySUC(String input) async {
    if (headUid == null) {
      CustomPopup.show(context, AppLocalizations.of(context)!.headNotLoggedIn);
      return;
    }

    setState(() {
      isLoading = true;
      studentData = null;
    });

    try {
      final String searchKey = input.trim().toLowerCase();

      final query =
          await _firestore
              .collection('Students')
              .where('sucId', isEqualTo: searchKey)
              .where('headUid', isEqualTo: headUid)
              .limit(1)
              .get();

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() {
          isLoading = false;
          if (query.docs.isNotEmpty) {
            studentData = {
              ...query.docs.first.data(),
              'id': query.docs.first.id,
            };
          } else {
            studentData = null;
          }
        });
      }
    } catch (e) {
      CustomPopup.show(
        context,
        "${AppLocalizations.of(context)!.errorFetchingStudent}: $e",
      );
      if (mounted) {
        setState(() {
          isLoading = false;
          studentData = null;
        });
      }
    }
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
          AppLocalizations.of(context)!.studentManagementTitle,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: 160,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFF0F5),
                      Color(0xFFFFE3E1),
                      Color(0xFFFFF9F4),
                      Color(0xFFFFEAD0),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.totalStudents,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const Icon(
                          Icons.verified_user,
                          color: Colors.black54,
                          size: 20,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      '$totalStudents',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)!.activeStudents,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.black, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.enterSucId,
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 9.0),
                      child: GestureDetector(
                        onTap: () {
                          final input = controller.text.trim();

                          if (input.isNotEmpty) {
                            InternetUtils.checkAndRun(
                              context: context,
                              onConnected: () {
                                fetchStudentBySUC(input);
                              },
                            );
                          }
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.redAccent.shade200,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
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
              ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: GradientSpinner(),
                )
              else if (studentData != null)
                StudentDetailsCard(
                  student: studentData!,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => StudentDetailsPage(
                              student: studentData!,
                              docId: studentData!['id'],
                            ),
                      ),
                    ).then((result) {
                      if (result != null && result['deleted'] == true) {
                        setState(() {
                          studentData = null;
                        });
                        _loadHeadData();
                      }
                    });
                  },
                  docId: studentData!['id'],
                )
              else if (controller.text.isNotEmpty && !isLoading)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(AppLocalizations.of(context)!.noStudentFound),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class StudentDetailsCard extends StatefulWidget {
  final Map<String, dynamic> student;
  final VoidCallback onTap;
  final String docId;

  const StudentDetailsCard({
    required this.student,
    required this.onTap,
    required this.docId,
    super.key,
  });

  @override
  State<StudentDetailsCard> createState() => _StudentDetailsCardState();
}

class _StudentDetailsCardState extends State<StudentDetailsCard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> deleteStudent() async {
    try {
      final docId = widget.docId;
      final docSnapshot =
          await _firestore.collection('Students').doc(docId).get();
      final deletedData = docSnapshot.data();

      if (deletedData == null) {
        return;
      }

      await _firestore.collection('Students').doc(docId).delete();

      final headUid = deletedData['headUid'];
      if (headUid != null) {
        await _firestore
            .collection('Heads')
            .doc(headUid)
            .collection('students')
            .doc(docId)
            .delete();
      }

      final facultyUid = deletedData['facultyUid'];
      if (facultyUid != null) {
        await _firestore
            .collection('Faculties')
            .doc(facultyUid)
            .collection('students')
            .doc(docId)
            .delete();
      }

      Navigator.pop(context);
      Navigator.pop(context, {'deleted': true});
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  void _showStudentOptions() {
    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

        return Padding(
          padding: EdgeInsets.only(
            left: 10,
            right: 10,
            top: 10,
            bottom: bottomPadding > 0 ? bottomPadding : 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
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
                  AppLocalizations.of(context)!.update,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                onTap: () {
                  InternetUtils.checkAndRun(
                    context: context,
                    onConnected: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => UpdateStudentPage(
                                student: widget.student,
                                docId: widget.docId,
                              ),
                        ),
                      ).then((updated) async {
                        if (updated == true) {
                          final doc =
                              await _firestore
                                  .collection('Students')
                                  .doc(widget.docId)
                                  .get();

                          if (doc.exists) {
                            setState(() {
                              widget.student.clear();
                              widget.student.addAll(doc.data()!);
                            });
                          }
                        }
                      });
                    },
                  );
                },
              ),
              ListTile(
                title: Text(
                  AppLocalizations.of(context)!.delete,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  showGeneralDialog(
                    context: context,
                    barrierDismissible: false,
                    barrierLabel: "Delete Warning",
                    transitionDuration: const Duration(milliseconds: 150),
                    pageBuilder: (_, __, ___) {
                      return Container();
                    },
                    transitionBuilder: (
                      context,
                      animation,
                      secondaryAnimation,
                      _,
                    ) {
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
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Container(
                                width: constraints.maxWidth * 0.9,
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
                                      AppLocalizations.of(
                                        context,
                                      )!.deleteStudentConfirmation,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(context),
                                          child: Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.cancel,
                                            style: const TextStyle(
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            InternetUtils.checkAndRunAsync(
                                              context: context,
                                              onConnected: () async {
                                                await deleteStudent();
                                              },
                                            );
                                          },
                                          child: Text(
                                            AppLocalizations.of(context)!.ok,
                                            style: const TextStyle(
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.5), width: 1),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.white,
              backgroundImage:
                  (widget.student['profilePictureUrl'] != null &&
                          widget.student['profilePictureUrl']
                              .toString()
                              .isNotEmpty)
                      ? NetworkImage(widget.student['profilePictureUrl'])
                      : null,
              child:
                  (widget.student['profilePictureUrl'] == null ||
                          widget.student['profilePictureUrl']
                              .toString()
                              .isEmpty)
                      ? SvgPicture.asset(
                        'assets/icons/users.svg',
                        width: 24,
                        height: 24,
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
                    widget.student['fullName'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${AppLocalizations.of(context)!.rollNo}: ${widget.student['rollNo'] ?? ''}",
                    style: const TextStyle(color: Colors.black54),
                  ),
                  Text(
                    "${AppLocalizations.of(context)!.sucId}: ${widget.student['sucId'] ?? ''}",
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _showStudentOptions(),
              child: const Icon(Icons.more_vert, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class StudentDetailsPage extends StatefulWidget {
  final Map<String, dynamic> student;
  final String docId;

  const StudentDetailsPage({
    required this.student,
    required this.docId,
    super.key,
  });

  @override
  State<StudentDetailsPage> createState() => _StudentDetailsPageState();
}

class _StudentDetailsPageState extends State<StudentDetailsPage> {
  late Map<String, dynamic> student;

  @override
  void initState() {
    super.initState();
    student = Map<String, dynamic>.from(widget.student);
  }

  Widget _buildField(String label, String key) {
    dynamic value;
    if (key.contains('.')) {
      final parts = key.split('.');
      final Map<String, dynamic>? nestedMap = student[parts[0]];
      value = nestedMap?[parts[1]];
    } else {
      value = student[key];
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 1),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "$label: ${value ?? ''}",
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
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
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
                crossAxisAlignment: CrossAxisAlignment.center,
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
                              width: 30,
                              height: 30,
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
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 3, top: 2, bottom: 12),
                    child: Text(
                      AppLocalizations.of(context)!.personalDetailsHeader,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  _buildField(
                    AppLocalizations.of(context)!.dateOfBirth,
                    "dateOfBirth",
                  ),
                  _buildField(
                    AppLocalizations.of(context)!.fatherName,
                    "fatherName",
                  ),
                  _buildField(
                    AppLocalizations.of(context)!.motherName,
                    "motherName",
                  ),
                  _buildField(AppLocalizations.of(context)!.sucId, "sucId"),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 3,
                      top: 12,
                      bottom: 12,
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.academicDetails,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
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
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 3,
                      top: 12,
                      bottom: 12,
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.addressHeader,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  _buildField(
                    AppLocalizations.of(context)!.flatBuildingApartment,
                    "address.line1",
                  ),
                  _buildField(
                    AppLocalizations.of(context)!.townCity,
                    "address.townCity",
                  ),
                  _buildField(
                    AppLocalizations.of(context)!.state,
                    "address.state",
                  ),
                  _buildField(
                    AppLocalizations.of(context)!.district,
                    "address.district",
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 3,
                      top: 12,
                      bottom: 12,
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.identificationDetailsHeader,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  _buildField(
                    AppLocalizations.of(context)!.aadhaarNumber,
                    "aadhaarNumber",
                  ),
                  _buildField(AppLocalizations.of(context)!.panCard, "panCard"),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class UpdateStudentPage extends StatefulWidget {
  final Map<String, dynamic> student;
  final String docId;

  const UpdateStudentPage({
    required this.student,
    required this.docId,
    super.key,
  });

  @override
  State<UpdateStudentPage> createState() => _UpdateStudentPageState();
}

class _UpdateStudentPageState extends State<UpdateStudentPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Map<String, TextEditingController> controllers;
  late Map<String, dynamic> addressData;
  Map<String, dynamic> stateDistrictMap = {};
  List<String> stateList = [];
  List<String> courseList = [];

  @override
  void initState() {
    super.initState();
    controllers = {};
    addressData = widget.student['address'] ?? {};
    loadStateDistrictData();
    fetchCoursesFromHead();

    final Map<String, dynamic> flattenedData = {
      ...widget.student,
      'addressLine1': addressData['line1'],
      'townCity': addressData['townCity'],
      'state': addressData['state'],
      'district': addressData['district'],
    };

    flattenedData.forEach((key, value) {
      if (!['address', 'id'].contains(key)) {
        controllers[key] = TextEditingController(text: value?.toString() ?? '');
      }
    });
  }

  @override
  void dispose() {
    controllers.forEach((key, controller) {
      controller.dispose();
    });
    super.dispose();
  }

  Future<void> loadStateDistrictData() async {
    try {
      String jsonString = await rootBundle.loadString('assets/india/data.json');
      final data = json.decode(jsonString);
      if (mounted) {
        setState(() {
          stateDistrictMap = data;
          stateList = stateDistrictMap.keys.toList();
        });
      }
    } catch (e) {
      debugPrint("Error loading state/district data: $e");
    }
  }

  Future<void> fetchCoursesFromHead() async {
    final studentDoc =
        await _firestore.collection('Students').doc(widget.docId).get();
    final headUid = studentDoc.data()?['headUid'];

    if (headUid == null) return;

    try {
      final snapshot =
          await _firestore
              .collection('courses')
              .where('headUid', isEqualTo: headUid)
              .get();

      if (mounted) {
        setState(() {
          courseList =
              snapshot.docs.map((doc) {
                final data = doc.data();
                return data['name']?.toString() ?? '';
              }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching courses: $e');
    }
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            dialogBackgroundColor: Colors.white,
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
      controller.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  void _showGenderPicker(TextEditingController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(AppLocalizations.of(context)!.male),
              onTap: () {
                controller.text = 'Male';
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(AppLocalizations.of(context)!.female),
              onTap: () {
                controller.text = 'Female';
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(AppLocalizations.of(context)!.other),
              onTap: () {
                controller.text = 'Other';
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _showStatePicker(TextEditingController controller) {
    if (stateList.isEmpty) {
      CustomPopup.show(context, AppLocalizations.of(context)!.stateDataLoading);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ListView.builder(
          itemCount: stateList.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(stateList[index]),
              onTap: () {
                controller.text = stateList[index];
                controllers['district']?.clear();
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  void _showDistrictPicker(TextEditingController controller) {
    if (controllers['state']!.text.isEmpty ||
        stateDistrictMap[controllers['state']!.text] == null) {
      CustomPopup.show(
        context,
        AppLocalizations.of(context)!.pleaseSelectStateFirst,
      );
      return;
    }

    List<String> districtList = List<String>.from(
      stateDistrictMap[controllers['state']!.text] ?? [],
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ListView.builder(
          itemCount: districtList.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(districtList[index]),
              onTap: () {
                controller.text = districtList[index];
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  void _showCoursePicker(TextEditingController controller) {
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
        return ListView.builder(
          itemCount: courseList.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(courseList[index]),
              onTap: () {
                controller.text = courseList[index];
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  void _showCourseDurationPicker(TextEditingController controller) {
    List<String> durations = [
      '1 ${AppLocalizations.of(context)!.year}',
      '2 ${AppLocalizations.of(context)!.years}',
      '3 ${AppLocalizations.of(context)!.years}',
      '4 ${AppLocalizations.of(context)!.years}',
      '5 ${AppLocalizations.of(context)!.years}',
      '6 ${AppLocalizations.of(context)!.years}',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ListView.builder(
          itemCount: durations.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(durations[index]),
              onTap: () {
                controller.text = durations[index];
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  void _showAcademicYearPicker(TextEditingController controller) {
    final currentYear = DateTime.now().year;
    List<String> years = List.generate(
      10,
      (index) => (currentYear - index).toString(),
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ListView.builder(
          itemCount: years.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(years[index]),
              onTap: () {
                controller.text = years[index];
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  void _updateStudentToFirestore() async {
    Map<String, dynamic> updatedData = {};

    controllers.forEach((key, controller) {
      updatedData[key] = controller.text.trim();
    });

    final addressUpdates = {
      'line1': controllers['addressLine1']?.text.trim(),
      'townCity': controllers['townCity']?.text.trim(),
      'state': controllers['state']?.text.trim(),
      'district': controllers['district']?.text.trim(),
    };
    updatedData['address'] = addressUpdates;

    updatedData.remove('addressLine1');
    updatedData.remove('townCity');
    updatedData.remove('state');
    updatedData.remove('district');

    await _firestore
        .collection('Students')
        .doc(widget.docId)
        .update(updatedData);

    Navigator.pop(context, true);
  }

  Widget _buildTextField(
    String label,
    String key, {
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controllers[key],
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black54),
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
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
          AppLocalizations.of(context)!.updateDetails,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 20),
        child: Column(
          children: [
            _buildTextField(AppLocalizations.of(context)!.fullName, "fullName"),
            _buildTextField(
              AppLocalizations.of(context)!.gender,
              "gender",
              readOnly: true,
              onTap: () => _showGenderPicker(controllers['gender']!),
            ),
            _buildTextField(
              AppLocalizations.of(context)!.fatherName,
              "fatherName",
            ),
            _buildTextField(
              AppLocalizations.of(context)!.motherName,
              "motherName",
            ),
            _buildTextField(
              AppLocalizations.of(context)!.dateOfBirth,
              "dateOfBirth",
              readOnly: true,
              onTap: () => _selectDate(controllers['dateOfBirth']!),
            ),
            _buildTextField(
              AppLocalizations.of(context)!.course,
              "course",
              readOnly: true,
              onTap: () => _showCoursePicker(controllers['course']!),
            ),
            _buildTextField(
              AppLocalizations.of(context)!.duration,
              "courseDuration",
              readOnly: true,
              onTap:
                  () =>
                      _showCourseDurationPicker(controllers['courseDuration']!),
            ),
            _buildTextField(
              AppLocalizations.of(context)!.academicYear,
              "academicYear",
              readOnly: true,
              onTap:
                  () => _showAcademicYearPicker(controllers['academicYear']!),
            ),
            _buildTextField(
              AppLocalizations.of(context)!.flatBuildingApartment,
              "addressLine1",
            ),
            _buildTextField(AppLocalizations.of(context)!.townCity, "townCity"),
            _buildTextField(
              AppLocalizations.of(context)!.state,
              "state",
              readOnly: true,
              onTap: () => _showStatePicker(controllers['state']!),
            ),
            _buildTextField(
              AppLocalizations.of(context)!.district,
              "district",
              readOnly: true,
              onTap: () => _showDistrictPicker(controllers['district']!),
            ),
            _buildTextField(
              AppLocalizations.of(context)!.aadhaarNumber,
              "aadhaarNumber",
            ),
            _buildTextField(AppLocalizations.of(context)!.panCard, "panCard"),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                  elevation: 0,
                ),
                onPressed: _updateStudentToFirestore,
                child: Text(
                  AppLocalizations.of(context)!.update,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    height: 1.2,
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

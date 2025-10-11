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
      CustomPopup.show(context, "Head not logged in.");
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
      CustomPopup.show(context, "Error fetching student: $e");
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
        title: const Text(
          'Student Management',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Gilroy-Bold',
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
                      children: const [
                        Text(
                          'Total Students',
                          style: TextStyle(
                            fontSize: 20,
                            fontFamily: 'Gilroy-Bold',
                            color: Colors.black,
                          ),
                        ),
                        Icon(
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
                        fontFamily: 'Gilroy-Bold',
                        color: Colors.black,
                      ),
                    ),
                    const Text(
                      'Active Students',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
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
                    hintText: 'Enter Student Unique Code (SUC)',
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
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text("No student found."),
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

      Navigator.pop(context); // Close the dialog
      Navigator.pop(context, {
        'deleted': true,
      }); // Go back to the previous screen with a result
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
                title: const Text(
                  'Update',
                  style: TextStyle(fontFamily: 'Gilroy-Bold', fontSize: 15),
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
                title: const Text(
                  'Delete',
                  style: TextStyle(fontFamily: 'Gilroy-Bold', fontSize: 15),
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
                                    const Text(
                                      "Warning",
                                      style: TextStyle(
                                        fontFamily: 'Gilroy-Bold',
                                        fontSize: 20,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      "Are you sure you want to delete this student?",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontFamily: 'Gilroy-Regular',
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(context),
                                          child: const Text(
                                            "Cancel",
                                            style: TextStyle(
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
                                          child: const Text(
                                            "OK",
                                            style: TextStyle(
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
                      fontFamily: 'Gilroy-Bold',
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Roll No: ${widget.student['rollNo'] ?? ''}",
                    style: const TextStyle(color: Colors.black54),
                  ),
                  Text(
                    "SUC ID: ${widget.student['sucId'] ?? ''}",
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
        title: const Text(
          'Student Details',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Gilroy-Bold',
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
                            fontFamily: 'Gilroy-Bold',
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
                          student['phone'] ?? '',
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
                  const Padding(
                    padding: EdgeInsets.only(left: 3, top: 2, bottom: 12),
                    child: Text(
                      "PERSONAL DETAILS",
                      style: TextStyle(
                        fontFamily: 'Gilroy-Regular',
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  _buildField("Date of Birth", "dateOfBirth"),
                  _buildField("Father Name", "fatherName"),
                  _buildField("Mother Name", "motherName"),
                  _buildField("Student Unique Code", "sucId"),
                  const Padding(
                    padding: EdgeInsets.only(left: 3, top: 12, bottom: 12),
                    child: Text(
                      "ACADEMIC DETAILS",
                      style: TextStyle(
                        fontFamily: 'Gilroy-Regular',
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  _buildField("Course", "course"),
                  _buildField("Duration", "courseDuration"),
                  _buildField("Academic Year", "academicYear"),
                  const Padding(
                    padding: EdgeInsets.only(left: 3, top: 12, bottom: 12),
                    child: Text(
                      "ADDRESS DETAILS",
                      style: TextStyle(
                        fontFamily: 'Gilroy-Regular',
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  _buildField("Apartment", "address.line1"),
                  _buildField("Town/City", "address.townCity"),
                  _buildField("State", "address.state"),
                  _buildField("District", "address.district"),
                  const Padding(
                    padding: EdgeInsets.only(left: 3, top: 12, bottom: 12),
                    child: Text(
                      "IDENTIFICATION DETAILS",
                      style: TextStyle(
                        fontFamily: 'Gilroy-Regular',
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  _buildField("Aadhaar Number", "aadhaarNumber"),
                  _buildField("PAN Number", "panCard"),
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
              .collection('Heads')
              .doc(headUid)
              .collection('courses')
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
              title: const Text('Male'),
              onTap: () {
                controller.text = 'Male';
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Female'),
              onTap: () {
                controller.text = 'Female';
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Other'),
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
      CustomPopup.show(
        context,
        "State data is still loading. Please try again.",
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
      CustomPopup.show(context, "Please select a state first");
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
        "Course data is not available. Please try again.",
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
      '1 Year',
      '2 Years',
      '3 Years',
      '4 Years',
      '5 Years',
      '6 Years',
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
        title: const Text(
          'Update Details',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Gilroy-Bold',
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 20),
        child: Column(
          children: [
            _buildTextField("Full Name", "fullName"),
            _buildTextField(
              "Gender",
              "gender",
              readOnly: true,
              onTap: () => _showGenderPicker(controllers['gender']!),
            ),
            _buildTextField("Father Name", "fatherName"),
            _buildTextField("Mother Name", "motherName"),
            _buildTextField(
              "Date of Birth",
              "dateOfBirth",
              readOnly: true,
              onTap: () => _selectDate(controllers['dateOfBirth']!),
            ),
            _buildTextField(
              "Course",
              "course",
              readOnly: true,
              onTap: () => _showCoursePicker(controllers['course']!),
            ),
            _buildTextField(
              "Course Duration",
              "courseDuration",
              readOnly: true,
              onTap:
                  () =>
                      _showCourseDurationPicker(controllers['courseDuration']!),
            ),
            _buildTextField(
              "Academic Year",
              "academicYear",
              readOnly: true,
              onTap:
                  () => _showAcademicYearPicker(controllers['academicYear']!),
            ),
            _buildTextField("Address Line 1", "addressLine1"),
            _buildTextField("Town/City", "townCity"),
            _buildTextField(
              "State",
              "state",
              readOnly: true,
              onTap: () => _showStatePicker(controllers['state']!),
            ),
            _buildTextField(
              "District",
              "district",
              readOnly: true,
              onTap: () => _showDistrictPicker(controllers['district']!),
            ),
            _buildTextField("Aadhaar Number", "aadhaarNumber"),
            _buildTextField("PAN Number", "panCard"),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
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
                onPressed: _updateStudentToFirestore,
                child: const Text(
                  'Update',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Gilroy-Bold',
                    fontSize: 15,
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

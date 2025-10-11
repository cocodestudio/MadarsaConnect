import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Data/const.dart';
import '../Data/dynamic_popup.dart';
import '../Data/uppercase.dart';

class AddStudent extends StatefulWidget {
  const AddStudent({super.key});

  @override
  State<AddStudent> createState() => _AddStudentState();
}

class _AddStudentState extends State<AddStudent> {
  late final TextEditingController _fullNameController =
      TextEditingController();
  late final TextEditingController _dobController = TextEditingController();
  late final TextEditingController _phoneController = TextEditingController();
  late final TextEditingController _emailController = TextEditingController();
  late final TextEditingController _courseController = TextEditingController();
  late final TextEditingController _coursedurationController =
      TextEditingController();
  late final TextEditingController _yearController = TextEditingController();
  late final TextEditingController _addressLine1Controller =
      TextEditingController();
  late final TextEditingController _townCityController =
      TextEditingController();
  late final TextEditingController _districtController =
      TextEditingController();
  late final TextEditingController _stateController = TextEditingController();
  late final TextEditingController _aadhaarController = TextEditingController();
  late final TextEditingController _panController = TextEditingController();
  late final TextEditingController passwordController = TextEditingController();
  late final TextEditingController _motherNameController =
      TextEditingController();
  late final TextEditingController _fatherNameController =
      TextEditingController();

  Map<String, dynamic> stateDistrictMap = {};
  List<String> stateList = [];
  String? selectedState;
  String? selectedGender;
  List<String> courseList = [];
  List<String> selectedCourses = [];
  String selectedCourseId = '';
  int _selectedCourseDuration = 0;
  bool isButtonActive = false;
  bool isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> fetchCoursesFromHead() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('No user is currently logged in.');
      return;
    }
    final facultyUid = currentUser.uid;
    print('Current Faculty UID: $facultyUid');

    try {
      final facultyDoc =
          await _firestore.collection('Faculties').doc(facultyUid).get();
      if (!facultyDoc.exists) {
        print('Faculty document does not exist.');
        return;
      }

      final headUid = facultyDoc.data()?['headUid'];
      if (headUid == null) {
        print('Head UID not found for this faculty.');
        return;
      }
      print('Found Head UID: $headUid');
      final snapshot =
          await _firestore
              .collection('courses')
              .where('headUid', isEqualTo: headUid)
              .get();

      setState(() {
        courseList =
            snapshot.docs.map((doc) {
              final data = doc.data();
              return jsonEncode({
                'name': data['name']?.toString() ?? '',
                'duration': data['duration'] ?? 1,
              });
            }).toList();
        print('Fetched courses: $courseList');
      });
    } catch (e) {
      print('Error fetching courses: $e');
    }
  }

  Future<void> loadStateDistrictData() async {
    String jsonString = await rootBundle.loadString('assets/india/data.json');
    final data = json.decode(jsonString);
    stateDistrictMap = data;
    stateList = stateDistrictMap.keys.toList();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
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
      _dobController.text = "${picked.day}/${picked.month}/${picked.year}";
      updateButtonState();
    }
  }

  void _showYearPickerDialog() {
    final currentYear = DateTime.now().year;
    final List<int> years = List.generate(
      currentYear - 1799,
      (index) => 1800 + index,
    );
    int selectedYearIndex = years.indexOf(
      int.tryParse(_yearController.text) ?? currentYear,
    );

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return Container(
          height: 300,
          child: Column(
            children: [
              SizedBox(height: 16),
              Text(
                "Select Academic Year",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(
                    initialItem: selectedYearIndex,
                  ),
                  itemExtent: 40,
                  magnification: 1.1,
                  useMagnifier: true,
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
                  height: MediaQuery.of(context).size.height * 0.050,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Text(
                    "Done",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<String> generateNextSUC() async {
    final counterRef = FirebaseFirestore.instance
        .collection('counters')
        .doc('students');
    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);
      if (!snapshot.exists) {
        transaction.set(counterRef, {'currentSUC': 1});
        return 'SUC0000001'.toLowerCase();
      }
      int current =
          int.tryParse(snapshot.data()?['currentSUC'].toString() ?? '0') ?? 0;
      int next = current + 1;
      transaction.update(counterRef, {'currentSUC': next});
      return 'SUC${next.toString().padLeft(7, '0')}'.toLowerCase();
    });
  }

  void showCourseBottomSheet() {
    if (courseList.isEmpty) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String? tempSelected = courseList.firstWhere(
          (course) => jsonDecode(course)['name'] == _courseController.text,
          orElse: () => '',
        );
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(1, 20, 1, 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Select Course",
                    style: TextStyle(
                      fontSize: 20,
                      fontFamily: 'Gilroy-Bold',
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 10),
                  SizedBox(
                    height: 300,
                    child: ListView.separated(
                      itemCount: courseList.length,
                      separatorBuilder: (_, __) => Divider(height: 0),
                      itemBuilder: (context, index) {
                        final course = courseList[index];
                        final parsedCourse = jsonDecode(course);

                        return RadioListTile<String>(
                          value: course,
                          groupValue: tempSelected,
                          activeColor: Colors.redAccent,
                          title: Text(
                            parsedCourse['name'],
                            style: TextStyle(
                              fontFamily: 'Gilroy-Regular',
                              fontSize: 15,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              tempSelected = value;
                            });

                            final selected = jsonDecode(value!);
                            _courseController.text = selected['name'];
                            selectedCourseId = selected['name'];
                            _selectedCourseDuration = selected['duration'];
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

  void showCourseBottomSheet2(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String? tempSelected = _coursedurationController.text;

        List<String> yearSuffix = [
          'st',
          'nd',
          'rd',
          'th',
          'th',
          'th',
          'th',
          'th',
        ];
        List<String> yearList = List.generate(
          _selectedCourseDuration,
          (index) => '${index + 1}${yearSuffix[index]} Year',
        );

        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(1, 20, 1, 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Select Course",
                    style: TextStyle(
                      fontSize: 20,
                      fontFamily: 'Gilroy-Bold',
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 10),
                  SizedBox(
                    height: 300,
                    child: ListView.separated(
                      itemCount: yearList.length,
                      separatorBuilder: (_, __) => Divider(height: 0),
                      itemBuilder: (context, index) {
                        final course = yearList[index];
                        return RadioListTile<String>(
                          value: course,
                          groupValue: tempSelected,
                          activeColor: Colors.redAccent,
                          title: Text(
                            course,
                            style: TextStyle(
                              fontFamily: 'Gilroy-Regular',
                              fontSize: 15,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              tempSelected = value!;
                            });
                            _coursedurationController.text = value!;
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

  Future<void> _addStudent() async {
    setState(() {
      isLoading = true;
    });

    FirebaseApp? tempApp;

    try {
      final facultyUser = _auth.currentUser;
      if (facultyUser == null) {
        throw Exception("Faculty not logged in.");
      }
      final facultyEmail = facultyUser.email;
      final facultyUid = facultyUser.uid;

      final headUid =
          (await _firestore.collection('Faculties').doc(facultyUid).get())
              .data()?['headUid'];
      if (headUid == null) {
        throw Exception("Could not find Head reference for this faculty.");
      }

      const String defaultPassword = 'mc@12345';

      String? email =
          _emailController.text.trim().isNotEmpty
              ? _emailController.text.trim()
              : null;
      String rawPhone = _phoneController.text.trim();
      String phone = rawPhone.startsWith('+') ? rawPhone : '+91$rawPhone';

      if (email == null || email.isEmpty) {
        if (phone.isEmpty) {
          throw Exception(
            "Either Email or Phone Number is required for student registration.",
          );
        }
        email = "$phone@mc.com";
      }

      tempApp = await Firebase.initializeApp(
        name: 'studentCreationApp_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );

      UserCredential userCredential = await FirebaseAuth.instanceFor(
        app: tempApp,
      ).createUserWithEmailAndPassword(email: email, password: defaultPassword);
      final String studentUid = userCredential.user!.uid;

      final courseName = _courseController.text.trim();
      final durationText = _coursedurationController.text.trim();
      final counterDocId = "${headUid}_${courseName}_${durationText}";
      final counterRef = _firestore
          .collection('rollCounters')
          .doc(counterDocId);
      final sucId = await generateNextSUC();

      int newRollNo = await _firestore.runTransaction((transaction) async {
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

      Map<String, dynamic> studentData = {
        'fullName': _fullNameController.text.trim(),
        'email': email,
        'phoneNumber': phone,
        'gender': selectedGender,
        'dateOfBirth': _dobController.text,
        'fatherName': _fatherNameController.text.trim(),
        'motherName': _motherNameController.text.trim(),
        'course': courseName,
        'courseDuration': durationText,
        'courseDurationNumber': int.tryParse(
          RegExp(r'^(\d+)').firstMatch(durationText)?.group(1) ?? '',
        ),
        'academicYear': _yearController.text,
        'address': {
          'line1': _addressLine1Controller.text.trim(),
          'townCity': _townCityController.text.trim(),
          'district': _districtController.text.trim(),
          'state': _stateController.text.trim(),
        },
        'aadhaarNumber': _aadhaarController.text.trim(),
        'panCard': _panController.text.trim(),
        'role': 'Student',
        'headUid': headUid,
        'facultyUid': facultyUid,
        'createdAt': FieldValue.serverTimestamp(),
        'rollNo': newRollNo,
        'sucId': sucId,
      };

      Map<String, dynamic> userDataForUsersCollection = {
        'fullName': _fullNameController.text.trim(),
        'email': email,
        'role': 'Student',
        'createdAt': FieldValue.serverTimestamp(),
        'uid': studentUid,
      };

      await _firestore
          .collection('users')
          .doc(studentUid)
          .set(userDataForUsersCollection);
      await _firestore.collection('Students').doc(studentUid).set(studentData);
      await _firestore
          .collection('Heads')
          .doc(headUid)
          .collection('students')
          .doc(studentUid)
          .set({
            'uid': studentUid,
            'fullName': _fullNameController.text.trim(),
            'course': courseName,
            'addedBy': facultyUid,
            'addedAt': FieldValue.serverTimestamp(),
            'rollNo': newRollNo,
          });

      await _firestore
          .collection('Faculties')
          .doc(facultyUid)
          .collection('students')
          .doc(studentUid)
          .set({
            'uid': studentUid,
            'fullName': _fullNameController.text.trim(),
            'course': courseName,
            'addedAt': FieldValue.serverTimestamp(),
            'rollNo': newRollNo,
          });

      _showSuccessDialog();
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred. Please try again.';
      if (e.code == 'email-already-in-use') {
        message = 'The email/phone is already in use by another account.';
      } else {
        message = e.message ?? message;
      }
      if (mounted) {
        CustomPopup.show(context, message);
      }
    } catch (e) {
      if (mounted) {
        CustomPopup.show(
          context,
          'An unexpected error occurred: ${e.toString()}',
        );
      }
    } finally {
      if (tempApp != null) {
        await tempApp.delete();
      }
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fullNameController.addListener(updateButtonState);
    _dobController.addListener(updateButtonState);
    _emailController.addListener(updateButtonState);
    _phoneController.addListener(updateButtonState);
    _addressLine1Controller.addListener(updateButtonState);
    _townCityController.addListener(updateButtonState);
    _districtController.addListener(updateButtonState);
    _stateController.addListener(updateButtonState);
    _courseController.addListener(updateButtonState);
    _coursedurationController.addListener(updateButtonState);
    _yearController.addListener(updateButtonState);
    loadStateDistrictData();
    fetchCoursesFromHead();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _courseController.dispose();
    _yearController.dispose();
    _addressLine1Controller.dispose();
    _townCityController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    _motherNameController.dispose();
    _fatherNameController.dispose();
    loadStateDistrictData();
    super.dispose();
  }

  void updateButtonState() {
    setState(() {
      isButtonActive =
          _fullNameController.text.isNotEmpty &&
          selectedGender != null &&
          _dobController.text.isNotEmpty &&
          _phoneController.text.isNotEmpty &&
          _addressLine1Controller.text.isNotEmpty &&
          _townCityController.text.isNotEmpty &&
          _districtController.text.isNotEmpty &&
          selectedState != null &&
          _courseController.text.isNotEmpty &&
          _yearController.text.isNotEmpty;
    });
  }

  void _showSuccessDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Success',
      transitionDuration: Duration(milliseconds: 500),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: curved,
            child: Scaffold(
              backgroundColor: Colors.white,
              body: SafeArea(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/done.png',
                            color: Colors.redAccent,
                            height: 150,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Student Added Successfully!",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.black,
                              fontFamily: 'Gilroy-Bold',
                            ),
                          ),
                        ],
                      ),
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
                            height: MediaQuery.of(context).size.height * 0.060,
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Text(
                              "Done",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

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
          'Add Student',
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
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    ListView(
                      padding: EdgeInsets.all(size.height * 0.025),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 150,
                            height: 150,
                            child: Image.asset(
                              'assets/images/facultyicon.png',
                              color: Colors.redAccent.shade100,
                            ),
                          ),
                        ),
                        SizedBox(height: size.height * 0.03),
                        Text(
                          'Add Student',
                          style: TextStyle(
                            fontSize: 28,
                            color: Colors.black.withAlpha(230),
                            fontFamily: 'Gilroy-Bold',
                          ),
                        ),
                        SizedBox(height: size.height * 0.004),
                        Text(
                          'Please fill in the details below to add student information.',
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Gilroy-Regular',
                            color: Colors.black.withAlpha(128),
                          ),
                        ),
                        SizedBox(height: size.height * 0.04),
                        Text(
                          "PERSONAL DETAILS",
                          style: TextStyle(
                            fontSize: 17,
                            fontFamily: 'Gilroy-Bold',
                            color: Colors.black.withAlpha(179),
                          ),
                        ),

                        SizedBox(height: size.height * 0.02),

                        // Full Name
                        TextField(
                          controller: _fullNameController,
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [UpperCaseTextFormatter()],
                          style: TextStyle(color: Colors.black, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Full Name",
                            hintStyle: TextStyle(color: Colors.grey),
                            fillColor: Colors.white,
                            filled: true,
                            prefixIcon: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SvgPicture.asset(
                                nameIcon,
                                height: 23,
                                width: 24,
                                colorFilter: ColorFilter.mode(
                                  Colors.black.withAlpha(204),
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.grey,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 1,
                              ),
                            ),
                          ),
                          onChanged: (text) {
                            updateButtonState();
                          },
                        ),

                        SizedBox(height: size.height * 0.02),

                        // Gender Dropdown
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: selectedGender,
                            iconEnabledColor: Colors.black,
                            style: TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 15,
                              ),
                              icon: SvgPicture.asset(
                                genderIcon,
                                height: 23,
                                width: 24,
                                colorFilter: ColorFilter.mode(
                                  Colors.black.withAlpha(204),
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            hint: Text(
                              "Select Gender",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            items:
                                ["MALE", "FEMALE", "OTHER"].map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedGender = newValue;
                                updateButtonState();
                              });
                            },
                          ),
                        ),

                        SizedBox(height: size.height * 0.02),

                        // DOB
                        TextField(
                          controller: _dobController,
                          readOnly: true,
                          onTap: _selectDate,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontFamily: 'Gilroy-Regular',
                          ),
                          decoration: InputDecoration(
                            hintText: "Date of Birth",
                            hintStyle: TextStyle(color: Colors.grey),
                            fillColor: Colors.white,
                            filled: true,
                            prefixIcon: Icon(
                              Icons.calendar_today,
                              color: Colors.black.withAlpha(204),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.grey,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 1,
                              ),
                            ),
                          ),
                          onChanged: (text) {
                            updateButtonState();
                          },
                        ),

                        SizedBox(height: size.height * 0.02),

                        // Phone
                        TextField(
                          textInputAction: TextInputAction.next,
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          style: TextStyle(color: Colors.black, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Phone Number",
                            counterText: "",
                            hintStyle: TextStyle(color: Colors.grey),
                            fillColor: Colors.white,
                            filled: true,
                            prefixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: SvgPicture.asset(
                                    phoneIcon,
                                    height: 23,
                                    width: 24,
                                    colorFilter: ColorFilter.mode(
                                      Colors.black.withOpacity(0.7),
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                                const Text(
                                  "+91 ",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.grey,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 1,
                              ),
                            ),
                          ),
                          onChanged: (text) {
                            updateButtonState();
                          },
                        ),

                        SizedBox(height: size.height * 0.02),

                        // Email
                        TextField(
                          textInputAction: TextInputAction.next,
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: Colors.black, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Email (Optional)",
                            hintStyle: TextStyle(color: Colors.grey),
                            fillColor: Colors.white,
                            filled: true,
                            prefixIcon: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SvgPicture.asset(
                                emailIcon,
                                height: 23,
                                width: 24,
                                colorFilter: ColorFilter.mode(
                                  Colors.black.withAlpha(204),
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.grey,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 1,
                              ),
                            ),
                          ),
                          onChanged: (text) {
                            updateButtonState();
                          },
                        ),

                        SizedBox(height: size.height * 0.03),

                        Text(
                          "PARENTS DETAILS ",
                          style: TextStyle(
                            fontSize: 17,
                            fontFamily: 'Gilroy-Bold',
                            color: Colors.black.withAlpha(179),
                          ),
                        ),

                        SizedBox(height: size.height * 0.02),

                        // Father Name
                        TextField(
                          textInputAction: TextInputAction.next,
                          controller: _fatherNameController,
                          keyboardType: TextInputType.name,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [UpperCaseTextFormatter()],
                          style: TextStyle(color: Colors.black, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Father's Name",
                            hintStyle: TextStyle(color: Colors.grey),
                            fillColor: Colors.white,
                            filled: true,
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: Colors.black.withAlpha(204),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.grey,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 1,
                              ),
                            ),
                          ),
                          onChanged: (text) {
                            updateButtonState();
                          },
                        ),

                        SizedBox(height: size.height * 0.02),

                        // Mother Name
                        TextField(
                          textInputAction: TextInputAction.next,
                          controller: _motherNameController,
                          keyboardType: TextInputType.text,
                          inputFormatters: [UpperCaseTextFormatter()],
                          style: TextStyle(color: Colors.black, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Mother's Name",
                            hintStyle: TextStyle(color: Colors.grey),
                            fillColor: Colors.white,
                            filled: true,
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: Colors.black.withAlpha(204),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.grey,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 1,
                              ),
                            ),
                          ),
                          onChanged: (text) {
                            updateButtonState();
                          },
                        ),

                        SizedBox(height: size.height * 0.03),

                        Text(
                          "ACADEMIC DETAILS",
                          style: TextStyle(
                            fontSize: 17,
                            fontFamily: 'Gilroy-Bold',
                            color: Colors.black.withAlpha(179),
                          ),
                        ),

                        SizedBox(height: size.height * 0.02),

                        GestureDetector(
                          onTap: () async {
                            if (courseList.isEmpty) {
                              await fetchCoursesFromHead();
                            }
                            showCourseBottomSheet();
                          },
                          child: AbsorbPointer(
                            child: TextField(
                              controller: _courseController,
                              onChanged: (text) {
                                updateButtonState();
                              },
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                              ),
                              readOnly: true,
                              decoration: InputDecoration(
                                hintText: "Select Courses",
                                hintStyle: TextStyle(color: Colors.grey),
                                prefixIcon: Icon(
                                  Icons.work_outline,
                                  color: Colors.black.withAlpha(204),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.grey,
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.black,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: size.height * 0.02),

                        GestureDetector(
                          onTap: () {
                            showCourseBottomSheet2(context);
                          },
                          child: AbsorbPointer(
                            child: TextField(
                              controller: _coursedurationController,
                              onChanged: (text) {
                                updateButtonState();
                              },
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                              ),
                              readOnly: true,
                              decoration: InputDecoration(
                                hintText: "Select Duration",
                                hintStyle: TextStyle(color: Colors.grey),
                                prefixIcon: Icon(
                                  Icons.work_outline,
                                  color: Colors.black.withAlpha(204),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.grey,
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.black,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: size.height * 0.02),

                        TextField(
                          readOnly: true,
                          controller: _yearController,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(color: Colors.black, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Academic Year",
                            hintStyle: TextStyle(color: Colors.grey),
                            fillColor: Colors.white,
                            filled: true,
                            prefixIcon: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SvgPicture.asset(
                                calenderIcon,
                                height: 23,
                                width: 24,
                                colorFilter: ColorFilter.mode(
                                  Colors.black.withOpacity(0.7),
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.grey,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 1,
                              ),
                            ),
                          ),
                          onTap: _showYearPickerDialog,
                          onChanged: (text) {
                            updateButtonState();
                          },
                        ),

                        SizedBox(height: size.height * 0.03),

                        Text(
                          "ADDRESS",
                          style: TextStyle(
                            fontSize: 17,
                            fontFamily: 'Gilroy-Bold',
                            color: Colors.black.withAlpha(179),
                          ),
                        ),

                        SizedBox(height: size.height * 0.02),

                        // Address Line 1
                        TextField(
                          textInputAction: TextInputAction.next,
                          controller: _addressLine1Controller,
                          keyboardType: TextInputType.streetAddress,
                          textCapitalization: TextCapitalization.words,
                          style: TextStyle(color: Colors.black, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Flat, Building/Apartment",
                            hintStyle: TextStyle(color: Colors.grey),
                            fillColor: Colors.white,
                            filled: true,
                            prefixIcon: Icon(
                              Icons.location_on_outlined,
                              color: Colors.black.withAlpha(204),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.grey,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 1,
                              ),
                            ),
                          ),
                          onChanged: (text) {
                            updateButtonState();
                          },
                        ),
                        SizedBox(height: size.height * 0.02),

                        // Town/City
                        TextField(
                          textInputAction: TextInputAction.next,
                          controller: _townCityController,
                          keyboardType: TextInputType.text,
                          style: TextStyle(color: Colors.black, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Town/City",
                            hintStyle: TextStyle(color: Colors.grey),
                            fillColor: Colors.white,
                            filled: true,
                            prefixIcon: Icon(
                              Icons.location_city_outlined,
                              color: Colors.black.withAlpha(204),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.grey,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 1,
                              ),
                            ),
                          ),
                          onChanged: (text) {
                            updateButtonState();
                          },
                        ),
                        SizedBox(height: size.height * 0.02),

                        // State
                        TextField(
                          controller: _stateController,
                          readOnly: true,
                          onTap: () async {
                            await loadStateDistrictData();

                            if (!context.mounted) return;

                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              builder: (context) {
                                return ListView.builder(
                                  itemCount: stateList.length,
                                  itemBuilder: (context, index) {
                                    return ListTile(
                                      title: Text(stateList[index]),
                                      onTap: () {
                                        _stateController.text =
                                            stateList[index];
                                        selectedState = stateList[index];
                                        updateButtonState();
                                        Navigator.pop(context);
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          },
                          style: TextStyle(color: Colors.black, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "State",
                            hintStyle: TextStyle(color: Colors.grey),
                            fillColor: Colors.white,
                            filled: true,
                            prefixIcon: Icon(
                              Icons.flag_outlined,
                              color: Colors.black.withAlpha(204),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.grey,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 1,
                              ),
                            ),
                          ),
                          onChanged: (text) {
                            updateButtonState();
                          },
                        ),

                        SizedBox(height: size.height * 0.02),

                        // DISTRICT
                        TextField(
                          controller: _districtController,
                          readOnly: true,
                          onTap: () {
                            if (selectedState != null &&
                                stateDistrictMap[selectedState!] != null) {
                              List<String> districtList = List<String>.from(
                                stateDistrictMap[selectedState!] ?? [],
                              );
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                ),
                                builder: (context) {
                                  return ListView.builder(
                                    itemCount: districtList.length,
                                    itemBuilder: (context, index) {
                                      return ListTile(
                                        title: Text(districtList[index]),
                                        onTap: () {
                                          _districtController.text =
                                              districtList[index];
                                          updateButtonState();
                                          Navigator.pop(context);
                                        },
                                      );
                                    },
                                  );
                                },
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Please select a state first"),
                                ),
                              );
                            }
                          },
                          style: TextStyle(color: Colors.black, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "District",
                            hintStyle: TextStyle(color: Colors.grey),
                            fillColor: Colors.white,
                            filled: true,
                            prefixIcon: Icon(
                              Icons.map_outlined,
                              color: Colors.black.withAlpha(204),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.grey,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 1,
                              ),
                            ),
                          ),
                          onChanged: (text) {
                            updateButtonState();
                          },
                        ),

                        SizedBox(height: size.height * 0.03),

                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "IDENTIFICATION DETAILS",
                            style: TextStyle(
                              fontSize: 17,
                              fontFamily: 'Gilroy-Bold',
                              color: Colors.black.withOpacity(0.7),
                            ),
                          ),
                        ),

                        SizedBox(height: size.height * 0.02),

                        // Aadhaar Number Field
                        TextField(
                          controller: _aadhaarController,
                          keyboardType: TextInputType.number,
                          maxLength: 12,
                          style: TextStyle(color: Colors.black, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Aadhaar Number (optional)",
                            counterText: "",
                            prefixIcon: Icon(
                              Icons.credit_card,
                              color: Colors.black.withOpacity(0.8),
                            ),
                            fillColor: Colors.white,
                            filled: true,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.grey,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 1,
                              ),
                            ),
                          ),
                          onChanged: (text) {
                            updateButtonState();
                          },
                        ),

                        SizedBox(height: size.height * 0.02),

                        // PAN Card (Optional)
                        TextField(
                          controller: _panController,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [UpperCaseTextFormatter()],
                          maxLength: 10,
                          style: TextStyle(color: Colors.black, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "PAN Card (optional)",
                            counterText: "",
                            prefixIcon: Icon(
                              Icons.credit_card_outlined,
                              color: Colors.black.withOpacity(0.8),
                            ),
                            fillColor: Colors.white,
                            filled: true,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.grey,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 1,
                              ),
                            ),
                          ),
                          onChanged: (text) {
                            updateButtonState();
                          },
                        ),

                        SizedBox(height: size.height * 0.04),

                        // Next Button
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed:
                              (isButtonActive && !isLoading)
                                  ? _addStudent
                                  : null,
                          child: Container(
                            alignment: Alignment.center,
                            width: double.infinity,
                            height: size.height * 0.060,
                            decoration: BoxDecoration(
                              color:
                                  (isButtonActive && !isLoading)
                                      ? Colors.redAccent
                                      : Colors.redAccent.withAlpha(153),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child:
                                isLoading
                                    ? SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                    : Text(
                                      "Add",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 17,
                                      ),
                                    ),
                          ),
                        ),
                        SizedBox(height: 10),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

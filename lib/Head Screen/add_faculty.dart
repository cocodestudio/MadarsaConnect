import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../Data/const.dart';
import '../Data/dynamic_popup.dart';
import '../Data/main_page.dart';
import '../Data/uppercase.dart';

class AddFaculty extends StatefulWidget {
  const AddFaculty({super.key});

  @override
  State<AddFaculty> createState() => _AddFacultyState();
}

class _AddFacultyState extends State<AddFaculty> {
  bool isButtonActive = false;
  bool isLoading = false;

  late final TextEditingController _fullNameController =
      TextEditingController();
  late final TextEditingController _dobController = TextEditingController();
  late final TextEditingController _phoneController = TextEditingController();
  late final TextEditingController _emailController = TextEditingController();
  late final TextEditingController _qualificationController =
      TextEditingController();
  late final TextEditingController _experienceController =
      TextEditingController();
  late final TextEditingController _joiningDateController =
      TextEditingController();
  late final TextEditingController _addressLine1Controller =
      TextEditingController();
  late final TextEditingController _townCityController =
      TextEditingController();
  late final TextEditingController _districtController =
      TextEditingController();
  late final TextEditingController _stateController = TextEditingController();
  late final TextEditingController _aadhaarController = TextEditingController();
  late final TextEditingController _panController = TextEditingController();

  Map<String, dynamic> stateDistrictMap = {};
  List<String> stateList = [];
  String? selectedState;
  String? selectedGender;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> loadStateDistrictData() async {
    String jsonString = await rootBundle.loadString('assets/india/data.json');
    final data = json.decode(jsonString);
    stateDistrictMap = data;
    stateList = stateDistrictMap.keys.toList();
  }

  @override
  void initState() {
    super.initState();
    _fullNameController.addListener(updateButtonState);
    _dobController.addListener(updateButtonState);
    _emailController.addListener(updateButtonState);
    _phoneController.addListener(updateButtonState);
    _aadhaarController.addListener(updateButtonState);
    _joiningDateController.addListener(updateButtonState);
    _addressLine1Controller.addListener(updateButtonState);
    _townCityController.addListener(updateButtonState);
    _districtController.addListener(updateButtonState);
    _stateController.addListener(updateButtonState);
    _qualificationController.addListener(updateButtonState);
    _experienceController.addListener(updateButtonState);
    _panController.addListener(updateButtonState);
    loadStateDistrictData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _qualificationController.dispose();
    _experienceController.dispose();
    _joiningDateController.dispose();
    _addressLine1Controller.dispose();
    _townCityController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    super.dispose();
  }

  void updateButtonState() {
    setState(() {
      isButtonActive =
          _fullNameController.text.isNotEmpty &&
          selectedGender != null &&
          _dobController.text.isNotEmpty &&
          _phoneController.text.isNotEmpty &&
          _aadhaarController.text.length == 12 &&
          _joiningDateController.text.isNotEmpty &&
          _addressLine1Controller.text.isNotEmpty &&
          _townCityController.text.isNotEmpty &&
          _districtController.text.isNotEmpty &&
          _stateController.text.isNotEmpty &&
          _qualificationController.text.isNotEmpty &&
          _experienceController.text.isNotEmpty;
    });
  }

  Future<String> generateNextFUC() async {
    final counterRef = FirebaseFirestore.instance
        .collection('counters')
        .doc('faculties');

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);

      if (!snapshot.exists) {
        transaction.set(counterRef, {'currentFUC': 1});
        return 'FUC0000001'.toLowerCase();
      }

      int current =
          int.tryParse(snapshot.data()?['currentFUC'].toString() ?? '0') ?? 0;
      int next = current + 1;

      transaction.update(counterRef, {'currentFUC': next});
      return 'FUC${next.toString().padLeft(7, '0')}'.toLowerCase();
    });
  }

  Future<void> _addFaculty() async {
    setState(() {
      isLoading = true;
    });

    FirebaseApp? tempApp;

    try {
      final String? headUid = _auth.currentUser?.uid;
      if (headUid == null) {
        throw Exception("Head user not logged in.");
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
            "Either Email or Phone Number is required for faculty registration.",
          );
        }
        email = "$phone@mc.com";
      }

      tempApp = await Firebase.initializeApp(
        name: 'facultyCreationApp_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );

      UserCredential userCredential = await FirebaseAuth.instanceFor(
        app: tempApp,
      ).createUserWithEmailAndPassword(email: email, password: defaultPassword);

      final String facultyUid = userCredential.user!.uid;
      final fucId = await generateNextFUC();
      final counterDocId = "${headUid}_FACULTY";
      final counterRef = _firestore
          .collection('rollCounters')
          .doc(counterDocId);

      int facultyRollNo = await _firestore.runTransaction((transaction) async {
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

      Map<String, dynamic> facultyData = {
        'fullName': _fullNameController.text.trim(),
        'email': email,
        'phoneNumber': phone,
        'gender': selectedGender,
        'dateOfBirth': _dobController.text,
        'qualification': _qualificationController.text.trim(),
        'experience': _experienceController.text.trim(),
        'joiningDate': _joiningDateController.text,
        'address': {
          'line1': _addressLine1Controller.text.trim(),
          'townCity': _townCityController.text.trim(),
          'district': _districtController.text.trim(),
          'state': _stateController.text.trim(),
        },
        'aadhaarNumber': _aadhaarController.text.trim(),
        'panCard': _panController.text.trim(),
        'role': 'Faculty',
        'headUid': headUid,
        'createdAt': FieldValue.serverTimestamp(),
        'fucId': fucId,
        'rollNo': facultyRollNo,
      };

      Map<String, dynamic> userDataForUsersCollection = {
        'fullName': _fullNameController.text.trim(),
        'email': email,
        'role': 'Faculty',
        'createdAt': FieldValue.serverTimestamp(),
        'uid': facultyUid,
      };

      await _firestore
          .collection('users')
          .doc(facultyUid)
          .set(userDataForUsersCollection);
      await _firestore.collection('Faculties').doc(facultyUid).set(facultyData);
      await _firestore
          .collection('Heads')
          .doc(headUid)
          .collection('faculties')
          .doc(facultyUid)
          .set({
            'uid': facultyUid,
            'fullName': _fullNameController.text.trim(),
            'email': email,
            'addedAt': FieldValue.serverTimestamp(),
            'fucId': fucId,
            'rollNo': facultyRollNo,
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
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

  Future<void> _selectJoiningDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
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
      setState(() {
        _joiningDateController.text = DateFormat('dd/MM/yyyy').format(picked);
        updateButtonState();
      });
    }
  }

  void _showSuccessDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Success',
      transitionDuration: const Duration(milliseconds: 500),
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
                          const Text(
                            "Successfully Added!",
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
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const MainPage(),
                              ),
                              (route) => false,
                            );
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
          'Add Faculty',
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
                          'Add Faculty',
                          style: TextStyle(
                            fontSize: 28,
                            color: Colors.black.withAlpha(230),
                            fontFamily: 'Gilroy-Bold',
                          ),
                        ),
                        SizedBox(height: size.height * 0.004),
                        Text(
                          'Please fill in the details below to add faculty information.',
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
                          onChanged: (text) {
                            updateButtonState();
                          },
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [UpperCaseTextFormatter()],
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: "Full Name",
                            hintStyle: const TextStyle(color: Colors.grey),
                            fillColor: Colors.white,
                            filled: true,
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(12.0),
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

                        SizedBox(height: size.height * 0.02),

                        // Gender Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: selectedGender,
                            iconEnabledColor: Colors.black,
                            style: const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
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
                            hint: const Text(
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
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontFamily: 'Gilroy-Regular',
                          ),
                          decoration: InputDecoration(
                            hintText: "Date of Birth",
                            hintStyle: const TextStyle(color: Colors.grey),
                            fillColor: Colors.white,
                            filled: true,
                            prefixIcon: Icon(
                              Icons.calendar_today,
                              color: Colors.black.withAlpha(204),
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

                        SizedBox(height: size.height * 0.02),

                        // Phone
                        TextField(
                          textInputAction: TextInputAction.next,
                          onChanged: (text) {
                            updateButtonState();
                          },
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: "Phone Number",
                            counterText: "",
                            hintStyle: const TextStyle(color: Colors.grey),
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

                        SizedBox(height: size.height * 0.02),

                        // Email
                        TextField(
                          textInputAction: TextInputAction.next,
                          onChanged: (text) {
                            updateButtonState();
                          },
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: "Email",
                            hintStyle: const TextStyle(color: Colors.grey),
                            fillColor: Colors.white,
                            filled: true,
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(12.0),
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

                        SizedBox(height: size.height * 0.03),

                        Text(
                          "PROFESSIONAL DETAILS",
                          style: TextStyle(
                            fontSize: 17,
                            fontFamily: 'Gilroy-Bold',
                            color: Colors.black.withAlpha(179),
                          ),
                        ),

                        SizedBox(height: size.height * 0.02),

                        TextField(
                          textInputAction: TextInputAction.next,
                          onChanged: (text) {
                            updateButtonState();
                          },
                          controller: _qualificationController,
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [UpperCaseTextFormatter()],
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: "Qualification",
                            hintStyle: const TextStyle(color: Colors.grey),
                            fillColor: Colors.white,
                            filled: true,
                            prefixIcon: Icon(
                              Icons.school,
                              color: Colors.black.withAlpha(204),
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

                        SizedBox(height: size.height * 0.02),

                        TextField(
                          textInputAction: TextInputAction.next,
                          onChanged: (text) {
                            updateButtonState();
                          },
                          controller: _experienceController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          maxLength: 2,
                          decoration: InputDecoration(
                            hintText: "Experience (in years)",
                            counterText: "",
                            hintStyle: const TextStyle(color: Colors.grey),
                            fillColor: Colors.white,
                            filled: true,
                            prefixIcon: Icon(
                              Icons.timeline,
                              color: Colors.black.withAlpha(204),
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

                        SizedBox(height: size.height * 0.02),

                        TextField(
                          controller: _joiningDateController,
                          readOnly: true,
                          onTap: _selectJoiningDate,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: "Joining Date",
                            hintStyle: const TextStyle(color: Colors.grey),
                            fillColor: Colors.white,
                            filled: true,
                            prefixIcon: Icon(
                              Icons.calendar_today,
                              color: Colors.black.withAlpha(204),
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
                          onChanged: (text) {
                            updateButtonState();
                          },
                          controller: _addressLine1Controller,
                          keyboardType: TextInputType.streetAddress,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: "Flat, Building/Apartment",
                            hintStyle: const TextStyle(color: Colors.grey),
                            fillColor: Colors.white,
                            filled: true,
                            prefixIcon: Icon(
                              Icons.location_on_outlined,
                              color: Colors.black.withAlpha(204),
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
                        SizedBox(height: size.height * 0.02),

                        // Town/City
                        TextField(
                          textInputAction: TextInputAction.next,
                          onChanged: (text) {
                            updateButtonState();
                          },
                          controller: _townCityController,
                          keyboardType: TextInputType.text,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: "Town/City",
                            hintStyle: const TextStyle(color: Colors.grey),
                            fillColor: Colors.white,
                            filled: true,
                            prefixIcon: Icon(
                              Icons.location_city_outlined,
                              color: Colors.black.withAlpha(204),
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
                              shape: const RoundedRectangleBorder(
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
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: "State",
                            hintStyle: const TextStyle(color: Colors.grey),
                            fillColor: Colors.white,
                            filled: true,
                            prefixIcon: Icon(
                              Icons.flag_outlined,
                              color: Colors.black.withAlpha(204),
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

                        SizedBox(height: size.height * 0.02),

                        // DISTRICT
                        TextField(
                          controller: _districtController,
                          readOnly: true,
                          onTap: () {
                            if (_stateController.text.isNotEmpty &&
                                stateDistrictMap[_stateController.text] !=
                                    null) {
                              List<String> districtList = List<String>.from(
                                stateDistrictMap[_stateController.text] ?? [],
                              );
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.white,
                                shape: const RoundedRectangleBorder(
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
                                const SnackBar(
                                  content: Text("Please select a state first"),
                                ),
                              );
                            }
                          },
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: "District",
                            hintStyle: const TextStyle(color: Colors.grey),
                            fillColor: Colors.white,
                            filled: true,
                            prefixIcon: Icon(
                              Icons.map_outlined,
                              color: Colors.black.withAlpha(204),
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
                          onChanged: (text) {
                            updateButtonState();
                          },
                          controller: _aadhaarController,
                          keyboardType: TextInputType.number,
                          maxLength: 12,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: "Aadhaar Number",
                            counterText: "",
                            prefixIcon: Icon(
                              Icons.credit_card,
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

                        SizedBox(height: size.height * 0.02),

                        // PAN Card (Optional)
                        TextField(
                          onChanged: (text) {
                            updateButtonState();
                          },
                          controller: _panController,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [UpperCaseTextFormatter()],
                          maxLength: 10,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
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

                        SizedBox(height: size.height * 0.04),

                        // Add Button
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed:
                              isButtonActive && !isLoading ? _addFaculty : null,
                          child: Container(
                            alignment: Alignment.center,
                            width: double.infinity,
                            height: size.height * 0.060,
                            decoration: BoxDecoration(
                              color:
                                  isButtonActive && !isLoading
                                      ? Colors.redAccent
                                      : Colors.redAccent.withAlpha(153),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child:
                                isLoading
                                    ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                    : const Text(
                                      "Add",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 17,
                                      ),
                                    ),
                          ),
                        ),
                        SizedBox(
                          height:
                              MediaQuery.of(context).viewPadding.bottom + 20,
                        ),
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

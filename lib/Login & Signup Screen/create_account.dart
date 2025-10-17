import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Data/const.dart';
import '../Data/dynamic_popup.dart';
import '../Data/uppercase.dart';
import 'loginpage.dart';

class CreateAccount extends StatefulWidget {
  const CreateAccount({super.key});
  @override
  State<CreateAccount> createState() => _CreateAccountState();
}

class _CreateAccountState extends State<CreateAccount> {
  late final TextEditingController _fullNameController =
      TextEditingController();
  late final TextEditingController _madarsaNameController =
      TextEditingController();
  late final TextEditingController _emailController = TextEditingController();
  late final TextEditingController _phoneController = TextEditingController();
  late final TextEditingController _dobController = TextEditingController();
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
  late final TextEditingController _passwordController =
      TextEditingController();
  late final TextEditingController _confirmPasswordController =
      TextEditingController();

  // State variables
  bool isButtonActive = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? selectedGender;
  Map<String, dynamic> stateDistrictMap = {};
  List<String> stateList = [];
  String? selectedState;
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    // Add listeners to validate fields and update button state
    _madarsaNameController.addListener(updateButtonState);
    _fullNameController.addListener(updateButtonState);
    _emailController.addListener(updateButtonState);
    _phoneController.addListener(updateButtonState);
    _aadhaarController.addListener(updateButtonState);
    _passwordController.addListener(updateButtonState);
    _confirmPasswordController.addListener(updateButtonState);
    _dobController.addListener(updateButtonState);
    _yearController.addListener(updateButtonState);
    _addressLine1Controller.addListener(updateButtonState);
    _townCityController.addListener(updateButtonState);
    _districtController.addListener(updateButtonState);
    _stateController.addListener(updateButtonState);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    loadStateDistrictData();
    _loadBannerAd();
  }

  @override
  void dispose() {
    // Dispose all controllers to prevent memory leaks
    _madarsaNameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _yearController.dispose();
    _addressLine1Controller.dispose();
    _townCityController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
    _bannerAd?.dispose();
  }

  // This function checks all mandatory fields and updates the button state
  void updateButtonState() {
    setState(() {
      isButtonActive =
          _madarsaNameController.text.isNotEmpty &&
          _fullNameController.text.isNotEmpty &&
          _emailController.text.isNotEmpty &&
          _phoneController.text.isNotEmpty &&
          selectedGender != null &&
          _dobController.text.isNotEmpty &&
          _yearController.text.isNotEmpty &&
          _aadhaarController.text.length == 12 &&
          _passwordController.text.length >= 8 &&
          _confirmPasswordController.text.length >= 8 &&
          _passwordController.text == _confirmPasswordController.text &&
          _addressLine1Controller.text.isNotEmpty &&
          _townCityController.text.isNotEmpty &&
          _districtController.text.isNotEmpty &&
          _stateController.text.isNotEmpty;
    });
  }

  Future<String> generateNextHUC() async {
    final counterRef = FirebaseFirestore.instance
        .collection('counters')
        .doc('heads');

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);

      if (!snapshot.exists) {
        transaction.set(counterRef, {'currentHUC': 1});
        return 'HUC0000001'.toLowerCase();
      }

      int current =
          int.tryParse(snapshot.data()?['currentHUC'].toString() ?? '0') ?? 0;
      int next = current + 1;

      transaction.update(counterRef, {'currentHUC': next});
      return 'HUC${next.toString().padLeft(7, '0')}'.toLowerCase();
    });
  }

  Future<void> _registerHead() async {
    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      String uid = userCredential.user!.uid;
      final hucId = await generateNextHUC();

      Map<String, dynamic> headData = {
        'fullName': _fullNameController.text.trim(),
        'madarsaName': _madarsaNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': "+91${_phoneController.text.trim()}",
        'gender': selectedGender,
        'dateOfBirth': _dobController.text,
        'yearOfEstablishment': _yearController.text,
        'address': {
          'line1': _addressLine1Controller.text.trim(),
          'townCity': _townCityController.text.trim(),
          'district': _districtController.text.trim(),
          'state': _stateController.text.trim(),
        },
        'aadhaarNumber': _aadhaarController.text.trim(),
        'panCard': _panController.text.trim(),
        'role': 'Head',
        'createdAt': FieldValue.serverTimestamp(),
        'hucId': hucId,
      };

      Map<String, dynamic> userDataForUsersCollection = {
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': 'Head',
        'createdAt': FieldValue.serverTimestamp(),
        'uid': uid,
      };

      await _firestore
          .collection('users')
          .doc(uid)
          .set(userDataForUsersCollection);
      await _firestore.collection('Heads').doc(uid).set(headData);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('headEmail', _emailController.text.trim());
      await prefs.setString('headPassword', _passwordController.text.trim());

      _showSuccessDialog();
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred. Please try again.';
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'The account already exists for that email.';
      } else {
        message = e.message ?? message;
      }
      if (mounted) {
        CustomPopup.show(context, (message));
      }
    } catch (e) {
      if (mounted) {
        CustomPopup.show(
          context,
          'An unexpected error occurred: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-2465407468425782/2868114213',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          print('Failed to load a banner ad: ${err.message}');
          _isBannerAdReady = false;
          ad.dispose();
        },
      ),
    );

    _bannerAd?.load();
  }

  // --- NEW FUNCTION ---
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
                            "Registration Successful!",
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
                        child: Column(
                          children: [
                            if (_isBannerAdReady && _bannerAd != null)
                              SizedBox(
                                width: _bannerAd!.size.width.toDouble(),
                                height: _bannerAd!.size.height.toDouble(),
                                child: AdWidget(ad: _bannerAd!),
                              ),
                            if (_isBannerAdReady) const SizedBox(height: 20),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => const LoginPage(),
                                  ),
                                  (route) => false,
                                );
                              },
                              child: Container(
                                alignment: Alignment.center,
                                width: double.infinity,
                                height:
                                    MediaQuery.of(context).size.height * 0.060,
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
                          ],
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
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
      _dobController.text = "${picked.day}/${picked.month}/${picked.year}";
      updateButtonState();
    }
  }

  Future<void> loadStateDistrictData() async {
    String jsonString = await rootBundle.loadString('assets/india/data.json');
    final data = json.decode(jsonString);
    stateDistrictMap = data;
    stateList = stateDistrictMap.keys.toList();
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
              const Text(
                "Select Year of Establishment",
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
                    updateButtonState();
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
              const SizedBox(height: 20),
            ],
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
          'Create Account',
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
                      padding: EdgeInsets.all(size.height * 0.030),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 150,
                            height: 150,
                            child: Image.asset(
                              'assets/images/form.webp',
                            ), // Your image path
                          ),
                        ),
                        SizedBox(height: size.height * 0.03),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 25,
                              color: Colors.black.withOpacity(0.9),
                              fontFamily: 'Gilroy-Bold',
                            ),
                          ),
                        ),
                        SizedBox(height: size.height * 0.004),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Please fill in the details below to create your account (all details are mandatory).',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black.withOpacity(0.5),
                            ),
                          ),
                        ),
                        SizedBox(height: size.height * 0.03),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "PERSONAL DETAILS",
                            style: TextStyle(
                              fontSize: 15,
                              fontFamily: 'Gilroy-Bold',
                              color: Colors.black.withOpacity(0.7),
                            ),
                          ),
                        ),

                        SizedBox(height: size.height * 0.02),

                        // First Name Input Field
                        TextField(
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [UpperCaseTextFormatter()],
                          onChanged: (text) {
                            updateButtonState();
                          },
                          controller: _fullNameController,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: "Legal Full Name",
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
                                  Colors.black.withOpacity(0.7),
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
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                            ),
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
                                  Colors.black.withOpacity(0.8),
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
                              color: Colors.black.withOpacity(0.8),
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
                          controller: _emailController,
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
                                  Colors.black.withOpacity(0.7),
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

                        SizedBox(
                          height: size.height * 0.02,
                        ), // Spacing between fields
                        // Phone Number Input Field
                        TextField(
                          onChanged: (text) {
                            updateButtonState();
                          },
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          maxLength: 10,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          decoration: InputDecoration(
                            hintText: "Phone Number",
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
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 0,
                              minHeight: 0,
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
                            counterText: "",
                          ),
                        ),

                        SizedBox(height: size.height * 0.02),

                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "MADARSA DETAILS",
                            style: TextStyle(
                              fontSize: 15,
                              fontFamily: 'Gilroy-Bold',
                              color: Colors.black.withOpacity(0.7),
                            ),
                          ),
                        ),

                        SizedBox(height: size.height * 0.02),

                        TextField(
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [UpperCaseTextFormatter()],
                          onChanged: (text) {
                            updateButtonState();
                          },
                          controller: _madarsaNameController,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: "Enter Madarsa Name",
                            hintStyle: const TextStyle(color: Colors.grey),
                            fillColor: Colors.white,
                            filled: true,
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: SvgPicture.asset(
                                mosqueIcon,
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
                          readOnly: true,
                          controller: _yearController,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: "Year of Establishment",
                            hintStyle: const TextStyle(color: Colors.grey),
                            fillColor: Colors.white,
                            filled: true,
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(12.0),
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
                          onTap: _showYearPickerDialog,
                        ),

                        SizedBox(height: size.height * 0.02),

                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "ADDRESS",
                            style: TextStyle(
                              fontSize: 15,
                              fontFamily: 'Gilroy-Bold',
                              color: Colors.black.withOpacity(0.7),
                            ),
                          ),
                        ),

                        SizedBox(height: size.height * 0.02),

                        // Address Line 1
                        TextField(
                          onChanged: (text) {
                            updateButtonState();
                          },
                          textInputAction: TextInputAction.next,
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
                              color: Colors.black.withOpacity(0.8),
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
                          onChanged: (text) {
                            updateButtonState();
                          },
                          textInputAction: TextInputAction.next,
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
                              color: Colors.black.withOpacity(0.8),
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
                            if (!mounted) return;
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
                              color: Colors.black.withOpacity(0.8),
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
                              if (!mounted) return;
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
                              CustomPopup.show(
                                context,
                                "Please select a state first",
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
                              color: Colors.black.withOpacity(0.8),
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

                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "IDENTIFICATION DETAILS",
                            style: TextStyle(
                              fontSize: 15,
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
                        SizedBox(height: size.height * 0.02),

                        // Password
                        TextField(
                          onChanged: (text) {
                            updateButtonState();
                          },
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: "Password",
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: Colors.black.withOpacity(0.8),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.black.withOpacity(0.7),
                              ),
                              onPressed:
                                  () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
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

                        // Confirm Password
                        TextField(
                          onChanged: (text) {
                            updateButtonState();
                          },
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: "Confirm Password",
                            prefixIcon: Icon(
                              Icons.lock_open_outlined,
                              color: Colors.black.withOpacity(0.8),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.black.withOpacity(0.7),
                              ),
                              onPressed:
                                  () => setState(
                                    () =>
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword,
                                  ),
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

                        SizedBox(height: size.height * 0.03),

                        // Next Button
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed:
                              isButtonActive && !_isLoading
                                  ? _registerHead
                                  : null,
                          child: Container(
                            alignment: Alignment.center,
                            width: double.infinity,
                            height: size.height * 0.060,
                            decoration: BoxDecoration(
                              color:
                                  isButtonActive && !_isLoading
                                      ? Colors.redAccent
                                      : Colors.redAccent.withAlpha(130),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child:
                                _isLoading
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Text(
                                      "Submit",
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

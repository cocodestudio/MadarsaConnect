import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Data/dynamic_popup.dart';
import '../Data/loader.dart';
import '../Data/uppercase.dart';
import '../l10n/app_localizations.dart';

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _madarsaNameController = TextEditingController();
  final TextEditingController _addressLine1Controller = TextEditingController();
  final TextEditingController _townCityController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _panController = TextEditingController();
  final TextEditingController _aadhaarController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String? _role;
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic> _userData = {};
  Map<String, dynamic> stateDistrictMap = {};
  List<String> stateList = [];
  String? selectedState;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    loadStateDistrictData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _madarsaNameController.dispose();
    _phoneController.dispose();
    _addressLine1Controller.dispose();
    _townCityController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    _panController.dispose();
    _aadhaarController.dispose();
    _dobController.dispose();
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
      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.couldNotLoadAddressData,
        );
      }
    }
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.userNotLoggedIn,
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final isHead = prefs.getBool('isHead') ?? false;
    final isFaculty = prefs.getBool('isFaculty') ?? false;

    String collectionName;
    if (isHead) {
      collectionName = 'Heads';
      _role = 'Head';
    } else if (isFaculty) {
      collectionName = 'Faculties';
      _role = 'Faculty';
    } else {
      collectionName = 'Students';
      _role = 'Student';
    }

    try {
      final docSnapshot =
          await _firestore.collection(collectionName).doc(user.uid).get();

      if (mounted && docSnapshot.exists) {
        _userData = docSnapshot.data()!;
        final address = _userData['address'] as Map<String, dynamic>? ?? {};
        _fullNameController.text = _userData['fullName'] ?? '';
        _madarsaNameController.text = _userData['madarsaName'] ?? '';
        _phoneController.text = _userData['phoneNumber'] ?? '';
        _dobController.text = _userData['dateOfBirth'] ?? '';
        _addressLine1Controller.text = address['line1'] ?? '';
        _townCityController.text = address['townCity'] ?? '';
        _districtController.text = address['district'] ?? '';
        _stateController.text = address['state'] ?? '';
        _panController.text = _userData['panCard'] ?? '';
        _aadhaarController.text = _userData['aadhaarNumber'] ?? '';
        selectedState =
            _stateController.text.isNotEmpty ? _stateController.text : null;

        setState(() => _isLoading = false);
      } else {
        if (mounted) {
          CustomPopup.show(
            context,
            AppLocalizations.of(context)!.couldNotLoadUserDetails,
          );
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        CustomPopup.show(
          context,
          "${AppLocalizations.of(context)!.anErrorOccurred}: $e",
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateUserDetails() async {
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception(AppLocalizations.of(context)!.userNotLoggedIn);
      }

      Map<String, dynamic> updatedData;
      String collectionName;

      if (_role == 'Head') {
        collectionName = 'Heads';
        updatedData = {
          'fullName': _fullNameController.text.trim(),
          'madarsaName': _madarsaNameController.text.trim(),
          'panCard': _panController.text.trim(),
          'aadhaarNumber': _aadhaarController.text.trim(),
          'dateOfBirth': _dobController.text.trim(),
          'address': {
            'line1': _addressLine1Controller.text.trim(),
            'townCity': _townCityController.text.trim(),
            'district': _districtController.text.trim(),
            'state': _stateController.text.trim(),
          },
        };
      } else {
        collectionName = _role == 'Faculty' ? 'Faculties' : 'Students';
        updatedData = {
          'panCard': _panController.text.trim(),
          'aadhaarNumber': _aadhaarController.text.trim(),
          'dateOfBirth': _dobController.text.trim(),
          'address': {
            'line1': _addressLine1Controller.text.trim(),
            'townCity': _townCityController.text.trim(),
            'district': _districtController.text.trim(),
            'state': _stateController.text.trim(),
          },
        };
      }

      await _firestore
          .collection(collectionName)
          .doc(user.uid)
          .update(updatedData);

      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.detailsUpdatedSuccessfully,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.failedToUpdateDetails,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
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
    }
  }

  void _showStatePicker() {
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
                setState(() {
                  _stateController.text = stateList[index];
                  selectedState = stateList[index];
                  _districtController.clear();
                });
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  void _showDistrictPicker() {
    if (selectedState == null || stateDistrictMap[selectedState!] == null) {
      CustomPopup.show(
        context,
        AppLocalizations.of(context)!.pleaseSelectStateFirst,
      );
      return;
    }
    final List<String> districtList = List<String>.from(
      stateDistrictMap[selectedState!] ?? [],
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
                setState(() {
                  _districtController.text = districtList[index];
                });
                Navigator.pop(context);
              },
            );
          },
        );
      },
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.personalDetails,
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
              : GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_role == 'Head')
                      ..._buildHeadUI()
                    else
                      ..._buildFacultyStudentUI(),
                    const SizedBox(height: 30),
                    // Naya ElevatedButton wala code
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _updateUserDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 0,
                        ),
                        child:
                            _isSaving
                                ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                                : Text(
                                  AppLocalizations.of(context)!.saveChanges,
                                  style: const TextStyle(
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
    );
  }

  List<Widget> _buildHeadUI() {
    return [
      _buildSectionHeader(AppLocalizations.of(context)!.editableDetails),
      _buildTextField(
        controller: _fullNameController,
        label: AppLocalizations.of(context)!.fullName,
        icon: Icons.person_outline,
        textCapitalization: TextCapitalization.words,
        formatter: [UpperCaseTextFormatter()],
      ),
      _buildTextField(
        controller: _madarsaNameController,
        label: AppLocalizations.of(context)!.madarsaName,
        icon: Icons.school_outlined,
        textCapitalization: TextCapitalization.words,
        formatter: [UpperCaseTextFormatter()],
      ),
      _buildSectionHeader(AppLocalizations.of(context)!.personalInformation),
      _buildTextField(
        controller: _dobController,
        label: AppLocalizations.of(context)!.dateOfBirth,
        icon: Icons.calendar_today_outlined,
        onTap: _selectDate,
        readOnly: true,
      ),
      _buildTextField(
        controller: _phoneController,
        label: AppLocalizations.of(context)!.phoneNumber,
        icon: Icons.phone_outlined,
        readOnly: true,
      ),
      _buildSectionHeader(AppLocalizations.of(context)!.addressDetails),
      _buildTextField(
        controller: _addressLine1Controller,
        label: AppLocalizations.of(context)!.flatBuildingApartment,
        icon: Icons.location_on_outlined,
      ),
      _buildTextField(
        controller: _townCityController,
        label: AppLocalizations.of(context)!.townCity,
        icon: Icons.location_city_outlined,
      ),
      _buildTextField(
        controller: _stateController,
        label: AppLocalizations.of(context)!.state,
        icon: Icons.flag_outlined,
        readOnly: true,
        onTap: _showStatePicker,
      ),
      _buildTextField(
        controller: _districtController,
        label: AppLocalizations.of(context)!.district,
        icon: Icons.map_outlined,
        readOnly: true,
        onTap: _showDistrictPicker,
      ),
      _buildSectionHeader(AppLocalizations.of(context)!.identificationDetails),
      _buildTextField(
        controller: _aadhaarController,
        label: AppLocalizations.of(context)!.aadhaarNumber,
        icon: Icons.credit_card_outlined,
        keyboardType: TextInputType.number,
        maxLength: 12,
      ),
      _buildTextField(
        controller: _panController,
        label: AppLocalizations.of(context)!.panCard,
        icon: Icons.credit_card,
        textCapitalization: TextCapitalization.characters,
        formatter: [UpperCaseTextFormatter()],
        maxLength: 10,
      ),
    ];
  }

  List<Widget> _buildFacultyStudentUI() {
    return [
      _buildSectionHeader(
        AppLocalizations.of(context)!.editablePersonalInformation,
      ),
      _buildTextField(
        controller: _dobController,
        label: AppLocalizations.of(context)!.dateOfBirth,
        icon: Icons.calendar_today_outlined,
        onTap: _selectDate,
        readOnly: true,
      ),
      _buildSectionHeader(AppLocalizations.of(context)!.editableAddressDetails),
      _buildTextField(
        controller: _addressLine1Controller,
        label: AppLocalizations.of(context)!.flatBuildingApartment,
        icon: Icons.location_on_outlined,
      ),
      _buildTextField(
        controller: _townCityController,
        label: AppLocalizations.of(context)!.townCity,
        icon: Icons.location_city_outlined,
      ),
      _buildTextField(
        controller: _stateController,
        label: AppLocalizations.of(context)!.state,
        icon: Icons.flag_outlined,
        readOnly: true,
        onTap: _showStatePicker,
      ),
      _buildTextField(
        controller: _districtController,
        label: AppLocalizations.of(context)!.district,
        icon: Icons.map_outlined,
        readOnly: true,
        onTap: _showDistrictPicker,
      ),
      _buildSectionHeader(
        AppLocalizations.of(context)!.editableIdentificationDetails,
      ),
      _buildTextField(
        controller: _aadhaarController,
        label: AppLocalizations.of(context)!.aadhaarNumber,
        icon: Icons.credit_card_outlined,
        keyboardType: TextInputType.number,
        maxLength: 12,
      ),
      _buildTextField(
        controller: _panController,
        label: AppLocalizations.of(context)!.panCard,
        icon: Icons.credit_card,
        textCapitalization: TextCapitalization.characters,
        formatter: [UpperCaseTextFormatter()],
        maxLength: 10,
      ),
    ];
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? formatter,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: keyboardType,
        maxLength: maxLength,
        inputFormatters: formatter,
        textCapitalization: textCapitalization,
        style: TextStyle(
          color: readOnly ? Colors.grey.shade700 : Colors.black,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          counterText: "",
          hintText: label,
          hintStyle: const TextStyle(color: Colors.grey),
          fillColor:
              readOnly && onTap == null ? Colors.grey.shade100 : Colors.white,
          filled: true,
          prefixIcon: Icon(icon, color: Colors.black.withAlpha(204)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.black, width: 1.5),
          ),
        ),
      ),
    );
  }
}

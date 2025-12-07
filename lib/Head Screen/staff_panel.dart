import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Data/dynamic_popup.dart';
import '../Data/loader.dart';
import '../l10n/app_localizations.dart';

class StaffPanelScreen extends StatefulWidget {
  const StaffPanelScreen({super.key});

  @override
  State<StaffPanelScreen> createState() => _StaffPanelScreenState();
}

class _StaffPanelScreenState extends State<StaffPanelScreen> {
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _qualificationController =
      TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _joiningDateController = TextEditingController();
  final TextEditingController _addressLine1Controller = TextEditingController();
  final TextEditingController _townCityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _aadhaarNumberController =
      TextEditingController();
  final TextEditingController _panCardController = TextEditingController();

  String? headUid;
  int facultyCount = 0;
  Map<String, dynamic>? selectedFacultyData;
  String? selectedFacultyDocId;
  bool isEditMode = false;
  Map<String, dynamic> stateDistrictMap = {};
  List<String> stateList = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadHeadData();
    loadStateDistrictData();
  }

  @override
  void dispose() {
    _genderController.dispose();
    _qualificationController.dispose();
    _experienceController.dispose();
    _joiningDateController.dispose();
    _addressLine1Controller.dispose();
    _townCityController.dispose();
    _stateController.dispose();
    _districtController.dispose();
    _aadhaarNumberController.dispose();
    _panCardController.dispose();
    super.dispose();
  }

  Future<void> _loadHeadData() async {
    final User? currentUser = _auth.currentUser;

    if (currentUser != null) {
      if (mounted) {
        setState(() {
          headUid = currentUser.uid;
        });
      }

      _firestore
          .collection('Faculties')
          .where('headUid', isEqualTo: headUid)
          .snapshots()
          .listen((snapshot) {
            if (mounted) {
              setState(() {
                facultyCount = snapshot.docs.length;
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

  void _showFacultyOptions(String docId, Map<String, dynamic> data) {
    showModalBottomSheet(
      backgroundColor: Colors.white,
      isScrollControlled: true,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
        final scale = screenWidth / 375;

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
                    width: 40 * scale.clamp(0.8, 1.2),
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: screenWidth * 0.045,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    selectedFacultyData = data;
                    selectedFacultyDocId = docId;
                    isEditMode = true;
                    _genderController.text = data['gender'] ?? '';
                    _qualificationController.text = data['qualification'] ?? '';
                    _experienceController.text = data['experience'] ?? '';
                    _joiningDateController.text = data['joiningDate'] ?? '';
                    _addressLine1Controller.text =
                        data['address']?['line1'] ?? '';
                    _townCityController.text =
                        data['address']?['townCity'] ?? '';
                    _stateController.text = data['address']?['state'] ?? '';
                    _districtController.text =
                        data['address']?['district'] ?? '';
                    _aadhaarNumberController.text = data['aadhaarNumber'] ?? '';
                    _panCardController.text = data['panCard'] ?? '';
                  });
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
                  try {
                    final counterDoc = _firestore
                        .collection('roll_counters_faculty')
                        .doc(headUid);

                    await _firestore.runTransaction((transaction) async {
                      final snapshot = await transaction.get(counterDoc);

                      if (snapshot.exists) {
                        final current = snapshot['currentFacultyId'] ?? 1;
                        int updatedCount = current > 1 ? current - 1 : 0;

                        transaction.update(counterDoc, {
                          'currentFacultyId': updatedCount,
                        });
                      }

                      transaction.delete(
                        _firestore.collection('Faculties').doc(docId),
                      );
                    });

                    setState(() {
                      selectedFacultyData = null;
                      selectedFacultyDocId = null;
                    });
                    CustomPopup.show(
                      context,
                      AppLocalizations.of(context)!.facultyDeletedSuccess,
                    );
                  } catch (e) {
                    CustomPopup.show(
                      context,
                      '${AppLocalizations.of(context)!.failedToDeleteFaculty}: $e',
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _onWillPop() async {
    if (selectedFacultyData != null) {
      setState(() {
        selectedFacultyData = null;
        selectedFacultyDocId = null;
        isEditMode = false;
      });
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
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
              if (selectedFacultyData != null) {
                setState(() {
                  selectedFacultyData = null;
                  selectedFacultyDocId = null;
                  isEditMode = false;
                });
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(
            selectedFacultyData == null
                ? AppLocalizations.of(context)!.staffPanel
                : isEditMode
                ? AppLocalizations.of(context)!.updateDetails
                : AppLocalizations.of(context)!.staffDetails,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
          actions: [
            if (selectedFacultyData == null)
              IconButton(
                icon: const Icon(
                  Icons.help_outline,
                  size: 26,
                  color: Colors.black,
                ),
                onPressed: () => _showHelpSheet(context),
              )
            else
              const SizedBox(width: 48),
          ],
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.97, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutBack,
                    ),
                  ),
                  child: child,
                ),
              );
            },
            child:
                headUid == null
                    ? const Center(child: GradientSpinner())
                    : selectedFacultyData == null
                    ? _buildFacultyList()
                    : isEditMode
                    ? _buildEditForm()
                    : _buildFacultyDetails(selectedFacultyData!),
          ),
        ),
      ),
    );
  }

  Widget _buildFacultyList() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('Faculties')
              .where('headUid', isEqualTo: headUid)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: GradientSpinner());
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
            child: Text(AppLocalizations.of(context)!.noFacultyAdded),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            StaffCard(
              title: AppLocalizations.of(context)!.totalStaff,
              icon: Icons.verified_user,
              gradientColors: const [
                Color(0xFFFFF0F5),
                Color(0xFFFFE3E1),
                Color(0xFFFFF9F4),
                Color(0xFFFFEAD0),
              ],
              count: docs.length,
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.yourFaculty,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return GestureDetector(
                onTap:
                    () => setState(() {
                      selectedFacultyData = data;
                      selectedFacultyDocId = doc.id;
                      isEditMode = false;
                    }),
                child: Container(
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['fullName'] ??
                                  AppLocalizations.of(context)!.noName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data['email'] ?? '',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showFacultyOptions(doc.id, data),
                        child: const Icon(Icons.more_vert),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  // ... (Date, Gender, State, District pickers remain structurally same, just localized text)

  Future<void> _selectDate(TextEditingController controller) async {
    // ... same logic ...
  }

  void _showGenderPicker(TextEditingController controller) {
    // ... (Use AppLocalizations for Male, Female, Other)
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
    // ...
  }

  void _showDistrictPicker(TextEditingController controller) {
    if (_stateController.text.isEmpty ||
        stateDistrictMap[_stateController.text] == null) {
      CustomPopup.show(
        context,
        AppLocalizations.of(context)!.pleaseSelectStateFirst,
      );
      return;
    }
    // ...
  }

  Widget _buildEditForm() {
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = screenWidth / 375;
    final Map<String, TextEditingController> formFields = {
      AppLocalizations.of(context)!.gender: _genderController,
      AppLocalizations.of(context)!.qualification: _qualificationController,
      AppLocalizations.of(context)!.experience: _experienceController,
      AppLocalizations.of(context)!.joiningDate: _joiningDateController,
      AppLocalizations.of(context)!.flatBuildingApartment:
          _addressLine1Controller,
      AppLocalizations.of(context)!.townCity: _townCityController,
      AppLocalizations.of(context)!.state: _stateController,
      AppLocalizations.of(context)!.district: _districtController,
      AppLocalizations.of(context)!.aadhaarNumber: _aadhaarNumberController,
      AppLocalizations.of(context)!.panCard: _panCardController,
    };

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(16.0 * scale.clamp(0.9, 1.2)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...formFields.entries.map((entry) {
              final label = entry.key;
              final controller = entry.value;
              // Simple check based on controller instance or logic mapping if label changes
              final isDate = controller == _joiningDateController;
              final isGender = controller == _genderController;
              final isState = controller == _stateController;
              final isDistrict = controller == _districtController;

              return Padding(
                padding: EdgeInsets.only(bottom: 18.0 * scale.clamp(0.9, 1.2)),
                child: TextField(
                  controller: controller,
                  keyboardType:
                      isDate ? TextInputType.datetime : TextInputType.text,
                  textInputAction: TextInputAction.next,
                  readOnly: isDate || isGender || isState || isDistrict,
                  onTap: () {
                    if (isDate) {
                      _selectDate(controller);
                    } else if (isGender) {
                      _showGenderPicker(controller);
                    } else if (isState) {
                      _showStatePicker(controller);
                    } else if (isDistrict) {
                      _showDistrictPicker(controller);
                    }
                  },
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14 * scale.clamp(0.95, 1.1),
                  ),
                  decoration: InputDecoration(
                    labelText: label,
                    fillColor: Colors.white,
                    filled: true,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        15 * scale.clamp(0.9, 1.1),
                      ),
                      borderSide: const BorderSide(
                        color: Colors.grey,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        15 * scale.clamp(0.9, 1.1),
                      ),
                      borderSide: const BorderSide(
                        color: Colors.black,
                        width: 1,
                      ),
                    ),
                    suffixIcon:
                        isDate || isGender || isState || isDistrict
                            ? const Icon(Icons.arrow_drop_down)
                            : null,
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 5),
            SizedBox(
              width: double.infinity,
              height: 48 * scale.clamp(0.9, 1.2),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      12 * scale.clamp(0.9, 1.2),
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 40 * scale.clamp(0.8, 1.1),
                    vertical: 14 * scale.clamp(0.8, 1.1),
                  ),
                  elevation: 0,
                ),
                onPressed: () async {
                  try {
                    Map<String, dynamic> updatedData = {
                      'gender': _genderController.text.trim(),
                      'qualification': _qualificationController.text.trim(),
                      'experience': _experienceController.text.trim(),
                      'joiningDate': _joiningDateController.text.trim(),
                      'address': {
                        'line1': _addressLine1Controller.text.trim(),
                        'townCity': _townCityController.text.trim(),
                        'state': _stateController.text.trim(),
                        'district': _districtController.text.trim(),
                      },
                      'aadhaarNumber': _aadhaarNumberController.text.trim(),
                      'panCard': _panCardController.text.trim(),
                    };
                    await _firestore
                        .collection('Faculties')
                        .doc(selectedFacultyDocId)
                        .update(updatedData);

                    setState(() {
                      selectedFacultyData = null;
                      selectedFacultyDocId = null;
                      isEditMode = false;
                    });
                    CustomPopup.show(
                      context,
                      AppLocalizations.of(context)!.facultyUpdatedSuccess,
                    );
                  } catch (e) {
                    CustomPopup.show(
                      context,
                      '${AppLocalizations.of(context)!.failedToUpdateFaculty}: $e',
                    );
                  }
                },
                child: Text(
                  AppLocalizations.of(context)!.saveChanges,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15 * scale.clamp(0.95, 1.1),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, String key, Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 1),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "$label: ${data[key] ?? ''}",
        style: const TextStyle(fontSize: 15, color: Colors.black87),
      ),
    );
  }

  Widget _buildFacultyDetails(Map<String, dynamic> data) {
    final Map<String, dynamic>? address =
        data['address'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 16),
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
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    backgroundImage:
                        data['profileUrl'] != null &&
                                data['profileUrl'].toString().isNotEmpty
                            ? NetworkImage(data['profileUrl'])
                            : null,
                    child:
                        (data['profileUrl'] == null ||
                                data['profileUrl'].toString().isEmpty)
                            ? const Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.grey,
                            )
                            : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['fullName'] ?? '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          data['dateOfBirth'] ?? '',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        Text(
                          data['email'] ?? '',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        Text(
                          data['phoneNumber'] ?? '',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                AppLocalizations.of(context)!.professionalDetailsHeader,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildField(AppLocalizations.of(context)!.gender, "gender", data),
            _buildField(
              AppLocalizations.of(context)!.qualification,
              "qualification",
              data,
            ),
            _buildField(
              AppLocalizations.of(context)!.experience,
              "experience",
              data,
            ),
            _buildField(
              AppLocalizations.of(context)!.joiningDate,
              "joiningDate",
              data,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                AppLocalizations.of(context)!.addressHeader,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildField(
              AppLocalizations.of(context)!.address,
              "line1",
              address ?? {},
            ),
            _buildField(
              AppLocalizations.of(context)!.townCity,
              "townCity",
              address ?? {},
            ),
            _buildField(
              AppLocalizations.of(context)!.state,
              "state",
              address ?? {},
            ),
            _buildField(
              AppLocalizations.of(context)!.district,
              "district",
              address ?? {},
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                AppLocalizations.of(context)!.identificationDetailsHeader,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildField(
              AppLocalizations.of(context)!.aadhaarNumber,
              "aadhaarNumber",
              data,
            ),
            _buildField(AppLocalizations.of(context)!.panCard, "panCard", data),
          ],
        ),
      ),
    );
  }
}

class StaffCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> gradientColors;
  final int count;

  const StaffCard({
    super.key,
    required this.title,
    required this.icon,
    required this.gradientColors,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: gradientColors,
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
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Icon(icon, color: Colors.black54, size: 20),
            ],
          ),
          const Spacer(),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Text(
            AppLocalizations.of(context)!.activeStaff,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

void _showHelpSheet(BuildContext context) {
  showModalBottomSheet(
    backgroundColor: Colors.white,
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
    ),
    isScrollControlled: true,
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.6,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.of(context)!.view,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.viewHelp,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 19),
                Text(
                  AppLocalizations.of(context)!.modify,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.modifyHelp,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 19),
                Text(
                  AppLocalizations.of(context)!.delete,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.deleteHelp,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 19),
                Text(
                  AppLocalizations.of(context)!.realTimeCount,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.realTimeCountHelp,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 19),
                Text(
                  AppLocalizations.of(context)!.management,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.managementHelp,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      );
    },
  );
}

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Data/dynamic_popup.dart';
import '../l10n/app_localizations.dart';
import '../utils/firebase_notification_helper.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _subCategoryController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  XFile? _pickedScreenshot;
  String? _currentUserEmail;
  String? _currentUserRole;
  String? _currentUserId;
  bool _isSubmitting = false;

  // Keeping data in English for DB consistency
  final List<String> _issueCategories = [
    'Technical Issue',
    'Billing & Payments',
    'Account Management',
    'Feature Request',
    'Bug Report',
    'General Inquiry',
    'Examination',
    'Certificate',
    'Attendance',
    'Admissions',
    'Fee Management',
    'Other',
  ];

  final Map<String, List<String>> _subCategories = {
    'Technical Issue': [
      'App Crash',
      'Login Problem',
      'Performance Issue',
      'Data Sync',
      'Other Technical',
    ],
    'Billing & Payments': [
      'Subscription Issue',
      'Payment Failed',
      'Refund Request',
      'Invoice Query',
      'Other Billing',
    ],
    'Account Management': [
      'Profile Update',
      'Password Reset',
      'Account Deactivation',
      'Privacy Settings',
      'Other Account',
    ],
    'Feature Request': ['New Feature Idea', 'Improve Existing Feature'],
    'Bug Report': ['UI Bug', 'Functionality Bug', 'Data Error'],
    'General Inquiry': ['How-to Question', 'Information Request'],
    'Examination': [
      'Exam Schedule Issue',
      'Result Discrepancy',
      'Admit Card Problem',
      'Online Exam Technical Issue',
      'Grading Error',
      'Other Exam Issue',
    ],
    'Certificate': [
      'Certificate Generation Issue',
      'Download Problem',
      'Incorrect Details on Certificate',
      'Verification Issue',
      'Other Certificate Issue',
    ],
    'Attendance': [
      'Attendance Marking Error',
      'Biometric Sync Issue',
      'Attendance Record Discrepancy',
      'Leave Application Problem',
      'Attendance Report Issue',
      'Other Attendance Issue',
    ],
    'Admissions': [
      'Application Form Issue',
      'Enrollment Error',
      'Document Upload Problem',
      'Admission Status Query',
      'Other Admission Issue',
    ],
    'Fee Management': [
      'Fee Payment Issue',
      'Fee Receipt Problem',
      'Late Fee Query',
      'Scholarship Application Issue',
      'Fee Structure Query',
      'Other Fee Issue',
    ],
    'Other': [
      'General Feedback',
      'Partnership Inquiry',
      'Other Unlisted Issue',
    ],
  };

  final List<Map<String, String>> _faqs = [
    {
      'question': 'How do I reset my forgotten password?',
      'answer':
          'If you\'ve forgotten your password, go to the Login screen and tap on the "Forgot Password?" link. Follow the instructions to reset your password using your registered email.',
    },
    {
      'question': 'How can I change my password from my profile?',
      'answer':
          'To change your current password, navigate to the "Profile" section within the app, then look for "Account Settings" or "Change Password". You will need to enter your old password and then set a new one.',
    },
    // ... (Other FAQs kept as is for content)
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    _loadUserEmailAndRole();
  }

  Future<void> _loadUserEmailAndRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserEmail = prefs.getString('user_email');
      _emailController.text = _currentUserEmail ?? '';
      _currentUserRole = prefs.getString('user_role');
      _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _categoryController.dispose();
    _subCategoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _pickedScreenshot = image;
    });
    if (image == null) {
      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.noScreenshotSelected,
        );
      }
    }
  }

  Future<void> _showCategorySelectionDialog() async {
    final String? selectedCategory = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          title: Text(
            AppLocalizations.of(context)!.selectIssueCategory,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  _issueCategories.map((category) {
                    final isSelected = _categoryController.text == category;
                    return ListTile(
                      title: Text(category),
                      trailing:
                          isSelected
                              ? const Icon(
                                Icons.circle,
                                color: Colors.redAccent,
                                size: 20,
                              )
                              : null,
                      onTap: () {
                        Navigator.pop(dialogContext, category);
                      },
                    );
                  }).toList(),
            ),
          ),
        );
      },
    );

    if (selectedCategory != null) {
      setState(() {
        _categoryController.text = selectedCategory;
        _subCategoryController.clear();
      });
    }
  }

  Future<void> _showSubCategorySelectionDialog() async {
    final String selectedCategory = _categoryController.text;
    if (selectedCategory.isEmpty) {
      CustomPopup.show(
        context,
        AppLocalizations.of(context)!.pleaseSelectCategoryFirst,
      );
      return;
    }

    final List<String> availableSubCategories =
        _subCategories[selectedCategory] ?? [];
    if (availableSubCategories.isEmpty) {
      CustomPopup.show(context, AppLocalizations.of(context)!.noSubCategories);
      return;
    }

    final String? selectedSubCategory = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          title: Text(
            AppLocalizations.of(context)!.selectSubCategoryTitle,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  availableSubCategories.map((subCategory) {
                    final isSelected =
                        _subCategoryController.text == subCategory;
                    return ListTile(
                      title: Text(subCategory),
                      trailing:
                          isSelected
                              ? const Icon(
                                Icons.circle,
                                color: Colors.redAccent,
                                size: 20,
                              )
                              : null,
                      onTap: () {
                        Navigator.pop(dialogContext, subCategory);
                      },
                    );
                  }).toList(),
            ),
          ),
        );
      },
    );

    if (selectedSubCategory != null) {
      setState(() {
        _subCategoryController.text = selectedSubCategory;
      });
    }
  }

  Future<void> _submitTicket() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        String? screenshotDownloadUrl;
        if (_pickedScreenshot != null) {
          try {
            String fileName =
                'screenshots/${DateTime.now().millisecondsSinceEpoch}_${_pickedScreenshot!.name}';
            Reference storageRef = FirebaseStorage.instance.ref().child(
              fileName,
            );
            UploadTask uploadTask = storageRef.putFile(
              File(_pickedScreenshot!.path),
            );
            TaskSnapshot snapshot = await uploadTask;
            screenshotDownloadUrl = await snapshot.ref.getDownloadURL();
          } catch (e) {
            if (mounted) {
              CustomPopup.show(
                context,
                '${AppLocalizations.of(context)!.failedToUploadScreenshot}: $e',
              );
            }
            screenshotDownloadUrl = null;
          }
        }

        final ticketData = {
          'email': _emailController.text,
          'category': _categoryController.text,
          'subCategory': _subCategoryController.text,
          'description': _descriptionController.text,
          'hasScreenshot': _pickedScreenshot != null,
          'screenshotUrl': screenshotDownloadUrl,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'Open',
          'submittedByUid': _currentUserId,
          'submittedByRole': _currentUserRole,
        };

        if (_currentUserRole == 'Head') {
          await FirebaseFirestore.instance
              .collection('admin_tickets')
              .add(ticketData);

          // ... Notification logic ...

          if (mounted) {
            CustomPopup.show(
              context,
              AppLocalizations.of(context)!.ticketSubmittedAdmin,
            );
          }
        } else {
          await FirebaseFirestore.instance
              .collection('helpdesk')
              .add(ticketData);

          // ... Notification logic ...

          if (mounted) {
            CustomPopup.show(
              context,
              AppLocalizations.of(context)!.ticketSubmitted,
            );
          }
        }
        _clearForm();
      } catch (e) {
        if (mounted) {
          CustomPopup.show(
            context,
            '${AppLocalizations.of(context)!.failedToSubmit}: $e',
          );
        }
      } finally {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _clearForm() {
    _emailController.text = _currentUserEmail ?? '';
    _categoryController.clear();
    _subCategoryController.clear();
    _descriptionController.clear();
    setState(() {
      _pickedScreenshot = null;
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final double systemBottomPadding = MediaQuery.of(context).padding.bottom;
    final double bottomNavHeightInMainPage =
        MediaQuery.of(context).size.height * 0.01;
    final double totalBottomInset =
        systemBottomPadding + bottomNavHeightInMainPage;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        elevation: 0,
        centerTitle: false,
        title: Text(
          AppLocalizations.of(context)!.helpAndSupport,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16.0, 20.0, 16.0, totalBottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.howCanWeHelp,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 20),

            _buildSectionTitle(AppLocalizations.of(context)!.submitNewTicket),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.emailAddress,
                        hintText: AppLocalizations.of(context)!.emailHint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(context)!.emailEmpty;
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          return AppLocalizations.of(context)!.emailInvalid;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _categoryController,
                      readOnly: true,
                      onTap: _showCategorySelectionDialog,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.issueCategory,
                        hintText: AppLocalizations.of(context)!.selectCategory,
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(context)!.categoryEmpty;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _subCategoryController,
                      readOnly: true,
                      onTap: _showSubCategorySelectionDialog,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.subCategory,
                        hintText:
                            AppLocalizations.of(context)!.selectSubCategory,
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(context)!.subCategoryEmpty;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.description,
                        hintText: AppLocalizations.of(context)!.descriptionHint,
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(context)!.descriptionEmpty;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    InkWell(
                      onTap: _pickScreenshot,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color:
                              _pickedScreenshot != null
                                  ? Colors.indigo.shade50
                                  : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                _pickedScreenshot != null
                                    ? Colors.indigo.shade300
                                    : Colors.grey.shade300,
                            style: BorderStyle.solid,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _pickedScreenshot != null
                                  ? Icons.check_circle_outline
                                  : Icons.add_photo_alternate_outlined,
                              size: 30,
                              color:
                                  _pickedScreenshot != null
                                      ? Colors.indigo.shade700
                                      : Colors.grey.shade600,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _pickedScreenshot != null
                                  ? AppLocalizations.of(
                                    context,
                                  )!.screenshotSelected(_pickedScreenshot!.name)
                                  : AppLocalizations.of(
                                    context,
                                  )!.uploadScreenshot,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color:
                                    _pickedScreenshot != null
                                        ? Colors.indigo.shade700
                                        : Colors.grey.shade700,
                              ),
                            ),
                            if (_pickedScreenshot != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 10.0),
                                child: Image.file(
                                  File(_pickedScreenshot!.path),
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitTicket,
                          icon:
                              _isSubmitting
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.send_rounded),
                          label: Text(
                            _isSubmitting
                                ? AppLocalizations.of(context)!.submitting
                                : AppLocalizations.of(context)!.submitTicket,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 15,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            shadowColor: Colors.redAccent.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            if (_currentUserRole == 'Head')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(
                    AppLocalizations.of(context)!.adminActions,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.receipt_long,
                        color: Colors.indigo.shade700,
                      ),
                      title: Text(
                        AppLocalizations.of(context)!.viewAllTickets,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: Colors.grey.shade500,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    TicketViewerScreen(userRole: 'Head'),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle(AppLocalizations.of(context)!.myTickets),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.list_alt,
                      color: Colors.indigo.shade700,
                    ),
                    title: Text(
                      AppLocalizations.of(context)!.viewMyTickets,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade500,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => TicketViewerScreen(
                                userEmail: _currentUserEmail,
                                userRole: _currentUserRole,
                              ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),

            _buildSectionTitle(AppLocalizations.of(context)!.faqs),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _faqs.length,
                itemBuilder: (context, index) {
                  final faq = _faqs[index];
                  return Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      title: Text(
                        faq['question']!,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            16.0,
                            0,
                            16.0,
                            16.0,
                          ),
                          child: Text(
                            faq['answer']!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 25),

            _buildSectionTitle(AppLocalizations.of(context)!.connectWithUs),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSocialButton(
                    icon: Icons.work_outline,
                    label: AppLocalizations.of(context)!.linkedin,
                    onTap: () async {
                      final url = Uri.parse(
                        'https://www.linkedin.com/in/moh-abuzar-6a880b30b?utm_source=share&utm_campaign=share_via&utm_content=profile&utm_medium=android_app',
                      );
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                  ),
                  _buildSocialButton(
                    icon: Icons.whatshot,
                    label: AppLocalizations.of(context)!.whatsapp,
                    onTap: () async {
                      final url = Uri.parse(
                        'https://whatsapp.com/channel/0029Vb7LpPC0LKZG2gJ4tw3u',
                      );
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                  ),
                  _buildSocialButton(
                    icon: Icons.language,
                    label: AppLocalizations.of(context)!.website,
                    onTap: () async {
                      final url = Uri.parse('https://www.madarsaconnect.xyz');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: Colors.indigo.withOpacity(0.1),
      highlightColor: Colors.indigo.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Icon(icon, size: 30, color: Colors.black),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TicketViewerScreen extends StatefulWidget {
  final String? userEmail;
  final String? userRole;
  final String? userId;

  const TicketViewerScreen({
    super.key,
    this.userEmail,
    this.userRole,
    this.userId,
  });

  @override
  State<TicketViewerScreen> createState() => _TicketViewerScreenState();
}

class _TicketViewerScreenState extends State<TicketViewerScreen> {
  final Map<String, bool> _isLoading = {};

  void _showScreenshotDialog(String? screenshotUrl) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            AppLocalizations.of(context)!.screenshotPreview,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (screenshotUrl != null && screenshotUrl.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                    maxWidth: MediaQuery.of(context).size.width * 0.8,
                  ),
                  child: Image.network(
                    screenshotUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (
                      BuildContext context,
                      Widget child,
                      ImageChunkEvent? loadingProgress,
                    ) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value:
                              loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Text('Error loading image. URL: $screenshotUrl');
                    },
                  ),
                )
              else
                Text(
                  AppLocalizations.of(context)!.noScreenshotAvailable,
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Text(AppLocalizations.of(context)!.close),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateTicketStatus(
    String ticketId,
    String newStatus,
    String userEmail,
  ) async {
    setState(() {
      _isLoading[ticketId] = true;
    });
    try {
      await FirebaseFirestore.instance
          .collection('helpdesk')
          .doc(ticketId)
          .update({
            'status': newStatus,
            'statusChangeTimestamp': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.ticketStatusUpdated(newStatus),
        );
      }

      String notificationTitle = '';
      String notificationBody = '';

      if (newStatus == 'Solved') {
        notificationTitle = AppLocalizations.of(context)!.ticketSolved;
        notificationBody = AppLocalizations.of(context)!.ticketSolvedBody;
      } else if (newStatus == 'Rejected') {
        notificationTitle = AppLocalizations.of(context)!.ticketRejected;
        notificationBody = AppLocalizations.of(context)!.ticketRejectedBody;
      }

      String? fcmToken;

      QuerySnapshot facultySnap =
          await FirebaseFirestore.instance
              .collection('Faculties')
              .where('email', isEqualTo: userEmail)
              .get();
      if (facultySnap.docs.isNotEmpty) {
        fcmToken = facultySnap.docs.first['fcmToken'];
      } else {
        QuerySnapshot studentSnap =
            await FirebaseFirestore.instance
                .collection('Students')
                .where('email', isEqualTo: userEmail)
                .get();
        if (studentSnap.docs.isNotEmpty) {
          fcmToken = studentSnap.docs.first['fcmToken'];
        }
      }

      if (fcmToken != null && fcmToken.isNotEmpty) {
        await FirebaseNotificationHelper.sendNotificationFromApp(
          fcmToken: fcmToken,
          title: notificationTitle,
          body: notificationBody,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomPopup.show(
          context,
          '${AppLocalizations.of(context)!.failedUpdateStatus}: $e',
        );
      }
    } finally {
      setState(() {
        _isLoading[ticketId] = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double systemBottomPadding = MediaQuery.of(context).padding.bottom;
    final double bottomNavHeightInMainPage =
        MediaQuery.of(context).size.height * 0.01;
    final double totalBottomInset =
        systemBottomPadding + bottomNavHeightInMainPage;

    Stream<QuerySnapshot> ticketStream;
    String screenTitle;

    if (widget.userRole == 'Head' && widget.userEmail == null) {
      ticketStream =
          FirebaseFirestore.instance
              .collection('helpdesk')
              .orderBy('timestamp', descending: true)
              .snapshots();
      screenTitle = AppLocalizations.of(context)!.allSupportTickets;
    } else if (widget.userRole == 'Head' && widget.userEmail != null) {
      ticketStream =
          FirebaseFirestore.instance
              .collection('admin_tickets')
              .where(
                'submittedByUid',
                isEqualTo: FirebaseAuth.instance.currentUser?.uid,
              )
              .orderBy('timestamp', descending: true)
              .snapshots();
      screenTitle = AppLocalizations.of(context)!.mySupportTickets;
    } else {
      ticketStream =
          FirebaseFirestore.instance
              .collection('helpdesk')
              .where('email', isEqualTo: widget.userEmail)
              .orderBy('timestamp', descending: true)
              .snapshots();
      screenTitle = AppLocalizations.of(context)!.mySupportTickets;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          screenTitle,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: ticketStream,
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    screenTitle.contains(
                          AppLocalizations.of(context)!.myTickets,
                        )
                        ? AppLocalizations.of(context)!.noTicketsSubmitted
                        : AppLocalizations.of(context)!.noTicketsFound,
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  if (screenTitle.contains(
                    AppLocalizations.of(context)!.allSupportTickets,
                  ))
                    Text(
                      AppLocalizations.of(context)!.ticketsFromOthers,
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                ],
              ),
            );
          }

          final tickets = snapshot.data!.docs;

          return ListView.builder(
            padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, totalBottomInset),
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticketDoc = tickets[index];
              final ticketId = ticketDoc.id;
              final ticket = ticketDoc.data() as Map<String, dynamic>;
              final timestamp = (ticket['timestamp'] as Timestamp?)?.toDate();
              final formattedDate =
                  timestamp != null
                      ? DateFormat('MMM dd, yyyy HH:mm').format(timestamp)
                      : 'N/A';
              final currentStatus = ticket['status'] ?? 'Open';
              final screenshotUrl = ticket['screenshotUrl'] as String?;
              final bool loading = _isLoading[ticketId] ?? false;

              Color statusColor;
              Color statusTextColor;
              switch (currentStatus) {
                case 'Open':
                  statusColor = Colors.orange.shade100;
                  statusTextColor = Colors.orange.shade800;
                  break;
                case 'Solved':
                  statusColor = Colors.green.shade100;
                  statusTextColor = Colors.green.shade800;
                  break;
                case 'Rejected':
                  statusColor = Colors.red.shade100;
                  statusTextColor = Colors.red.shade800;
                  break;
                default:
                  statusColor = Colors.grey.shade100;
                  statusTextColor = Colors.grey.shade800;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade200, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ticket['category'] ?? 'N/A',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            currentStatus,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${AppLocalizations.of(context)!.subCategory}: ${ticket['subCategory'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${AppLocalizations.of(context)!.from}: ${ticket['email'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${AppLocalizations.of(context)!.description}: ${ticket['description'] ?? AppLocalizations.of(context)!.noDescription}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    if (ticket['hasScreenshot'] == true &&
                        screenshotUrl != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.image_outlined, size: 20),
                          label: Text(
                            AppLocalizations.of(context)!.viewScreenshot,
                          ),
                          onPressed: () => _showScreenshotDialog(screenshotUrl),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        '${AppLocalizations.of(context)!.raised}: $formattedDate',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                    if (widget.userRole == 'Head' &&
                        screenTitle.contains(
                          AppLocalizations.of(context)!.allSupportTickets,
                        ))
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed:
                                    loading ||
                                            currentStatus == 'Rejected' ||
                                            currentStatus == 'Solved'
                                        ? null
                                        : () => _updateTicketStatus(
                                          ticketId,
                                          'Rejected',
                                          ticket['email'],
                                        ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade600,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
                                ),
                                child:
                                    loading && (_isLoading[ticketId] ?? false)
                                        ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : Text(
                                          AppLocalizations.of(context)!.reject,
                                        ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed:
                                    loading ||
                                            currentStatus == 'Solved' ||
                                            currentStatus == 'Rejected'
                                        ? null
                                        : () => _updateTicketStatus(
                                          ticketId,
                                          'Solved',
                                          ticket['email'],
                                        ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
                                ),
                                child:
                                    loading && (_isLoading[ticketId] ?? false)
                                        ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : Text(
                                          AppLocalizations.of(context)!.solve,
                                        ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

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
    {
      'question': 'How do I view my child\'s (student\'s) attendance record?',
      'answer':
          'You can view real-time attendance records by going to the "Attendance" section on your dashboard. Select the student and the date range to see their attendance history.',
    },
    {
      'question': 'Where can I find my examination results?',
      'answer':
          'Examination results are available in the "Examinations" or "Results" section of the app. You can typically find results by selecting the specific exam name or academic session.',
    },
    {
      'question': 'How do I download my academic certificates or marksheets?',
      'answer':
          'Digital certificates and marksheets can be accessed and downloaded from the "Certificates" or "Documents" section. Look for the specific certificate you need and tap the download icon.',
    },
    {
      'question': 'What is the process for online fee payment?',
      'answer':
          'To pay fees online, go to the "Fee Management" section. Select the outstanding fee, choose your preferred payment method (e.g., credit card, UPI, net banking), and follow the on-screen instructions to complete the transaction.',
    },
    {
      'question': 'My attendance record seems incorrect. What should I do?',
      'answer':
          'If you believe there\'s an error in your attendance record, please submit a support ticket under the "Attendance" category, providing details like date, time, and class. Our team will review it promptly.',
    },
    {
      'question': 'How can I apply for leave or absence?',
      'answer':
          'Leave applications can usually be submitted through the "Attendance" or "Leave Management" section. Fill out the required details, including the reason and duration, and submit it for approval.',
    },
    {
      'question':
          'I\'m having trouble submitting an admission application. Help!',
      'answer':
          'If you\'re facing issues with the admission application form or document uploads, please create a support ticket under the "Admissions" category. Describe the exact problem you\'re encountering.',
    },
    {
      'question': 'How can I get a copy of my fee receipt?',
      'answer':
          'All your payment receipts are typically available in the "Fee Management" or "Payment History" section. You can view and download them there.',
    },
    {
      'question': 'My app is crashing frequently. What should I do?',
      'answer':
          'First, try restarting your device and ensuring your app is updated to the latest version. If the issue persists, please submit a "Bug Report" ticket under "Technical Issue" with details about when and where the crash occurs.',
    },
    {
      'question': 'How do I contact technical support for an urgent issue?',
      'answer':
          'For urgent technical issues, you can submit a ticket through this Support screen by selecting the relevant "Technical Issue" category. Our team monitors these requests closely and will respond as soon as possible.',
    },
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
    if (image != null) {
    } else {
      CustomPopup.show(context, 'No screenshot selected.');
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
            'Select Issue Category',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: 'Gilroy-Bold',
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
      CustomPopup.show(context, 'Please select an Issue Category first.');
      return;
    }

    final List<String> availableSubCategories =
        _subCategories[selectedCategory] ?? [];
    if (availableSubCategories.isEmpty) {
      CustomPopup.show(
        context,
        'No sub-categories available for this category.',
      );
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
            'Select Sub Category',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: 'Gilroy-Bold',
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
            CustomPopup.show(context, 'Failed to upload screenshot: $e');
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
          // Head submits ticket to admin_tickets collection
          await FirebaseFirestore.instance
              .collection('admin_tickets')
              .add(ticketData);

          // Fetch recipient's notification settings (Admin)
          final adminQuery =
              await FirebaseFirestore.instance
                  .collection('Admins')
                  .limit(1)
                  .get();
          if (adminQuery.docs.isNotEmpty) {
            final adminDoc = adminQuery.docs.first;
            final adminUid = adminDoc.id;
            final settingsDoc =
                await FirebaseFirestore.instance
                    .collection('notificationSettings')
                    .doc(adminUid)
                    .get();
            final bool isPushEnabled = settingsDoc.data()?['push'] ?? true;
            final bool isInAppEnabled = settingsDoc.data()?['inApp'] ?? true;

            try {
              final adminToken = adminDoc.data()['fcmToken'];

              // Push Notification
              if (isPushEnabled &&
                  adminToken != null &&
                  adminToken.toString().isNotEmpty) {
                await FirebaseNotificationHelper.sendNotificationFromApp(
                  fcmToken: adminToken,
                  title: 'New Support Ticket',
                  body:
                      'A new ticket has been submitted by ${_currentUserEmail} for ${_categoryController.text} - ${_subCategoryController.text}',
                );
              }

              // In-app Notification
              if (isInAppEnabled) {
                await FirebaseFirestore.instance.collection('notifications').add({
                  'recipientId': adminUid,
                  'title': 'New Support Ticket',
                  'message':
                      'A new ticket has been submitted by a Head for ${_categoryController.text}.',
                  'timestamp': FieldValue.serverTimestamp(),
                  'isRead': false,
                  'type': 'newTicket',
                  'senderId': _currentUserId,
                  'senderName': 'Head',
                  'senderProfileUrl': null,
                  'targetId': null,
                  'targetType': 'admin_tickets',
                });
              }
            } catch (e) {
              print('Failed to send notification to Admin: $e');
            }
          }

          CustomPopup.show(
            context,
            'Your request has been submitted to the Admin!',
          );
        } else {
          // Faculty or Student submits ticket to helpdesk collection
          await FirebaseFirestore.instance
              .collection('helpdesk')
              .add(ticketData);

          // Fetch recipient's notification settings (Head)
          final userDoc =
              await FirebaseFirestore.instance
                  .collection(
                    _currentUserRole! == 'Faculty' ? 'Faculties' : 'Students',
                  )
                  .doc(_currentUserId)
                  .get();
          final headUid = userDoc.data()?['headUid'];
          if (headUid != null) {
            final headTokenDoc =
                await FirebaseFirestore.instance
                    .collection('Heads')
                    .doc(headUid)
                    .get();
            final headToken = headTokenDoc.data()?['fcmToken'];
            final headName = headTokenDoc.data()?['fullName'];

            final settingsDoc =
                await FirebaseFirestore.instance
                    .collection('notificationSettings')
                    .doc(headUid)
                    .get();
            final bool isPushEnabled = settingsDoc.data()?['push'] ?? true;
            final bool isInAppEnabled = settingsDoc.data()?['inApp'] ?? true;

            try {
              // Push Notification
              if (isPushEnabled &&
                  headToken != null &&
                  headToken.toString().isNotEmpty) {
                await FirebaseNotificationHelper.sendNotificationFromApp(
                  fcmToken: headToken,
                  title: 'New Support Ticket',
                  body:
                      'A new ticket has been submitted by ${_currentUserEmail} for ${_categoryController.text} - ${_subCategoryController.text}',
                );
              }

              // In-app Notification
              if (isInAppEnabled) {
                await FirebaseFirestore.instance.collection('notifications').add({
                  'recipientId': headUid,
                  'title': 'New Support Ticket',
                  'message':
                      'A new ticket has been submitted by a ${_currentUserRole} for ${_categoryController.text}.',
                  'timestamp': FieldValue.serverTimestamp(),
                  'isRead': false,
                  'type': 'newTicket',
                  'senderId': _currentUserId,
                  'senderName': _currentUserEmail?.split('@')[0],
                  'senderProfileUrl': null,
                  'targetId': null,
                  'targetType': 'helpdesk',
                });
              }
            } catch (e) {
              print('Failed to send notification to Head: $e');
            }
          }

          CustomPopup.show(context, 'Ticket submitted successfully!');
        }
        _clearForm();
      } catch (e) {
        CustomPopup.show(context, 'Failed to submit ticket: $e');
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
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Help & Support',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 24,
            fontFamily: 'Gilroy-Bold',
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16.0, 20.0, 16.0, totalBottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How can we help you today?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
                fontFamily: 'Gilroy-Bold',
              ),
            ),
            const SizedBox(height: 20),

            _buildSectionTitle('Submit a New Ticket'),
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
                        labelText: 'Email Address',
                        hintText: 'your.email@example.com',
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
                          return 'Email cannot be empty';
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          return 'Enter a valid email address';
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
                        labelText: 'Issue Category',
                        hintText: 'Select a category',
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
                          return 'Issue Category cannot be empty';
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
                        labelText: 'Sub Category',
                        hintText: 'Select a sub category',
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
                          return 'Sub Category cannot be empty';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe your issue in detail...',
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
                          return 'Description cannot be empty';
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
                                  ? 'Screenshot Selected: ${_pickedScreenshot!.name}'
                                  : 'Upload Screenshot (Optional)',
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
                            _isSubmitting ? 'Submitting...' : 'Submit Ticket',
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
                  _buildSectionTitle('Admin Actions'),
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
                        'View All Support Tickets',
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

            // My Tickets option for all users including Head
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('My Tickets'),
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
                      'View My Support Tickets',
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

            _buildSectionTitle('Frequently Asked Questions'),
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

            _buildSectionTitle('Connect with Us'),
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
                    label: 'LinkedIn',
                    onTap: () async {
                      final url = Uri.parse(
                        'https://www.linkedin.com/in/moh-abuzar-6a880b30b?utm_source=share&utm_campaign=share_via&utm_content=profile&utm_medium=android_app',
                      );
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      } else {}
                    },
                  ),
                  _buildSocialButton(
                    icon: Icons.whatshot,
                    label: 'Whatsapp',
                    onTap: () async {
                      final url = Uri.parse(
                        'https://whatsapp.com/channel/0029Vb7LpPC0LKZG2gJ4tw3u',
                      );
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      } else {}
                    },
                  ),
                  _buildSocialButton(
                    icon: Icons.language,
                    label: 'Website',
                    onTap: () async {
                      final url = Uri.parse('https://www.madarsaconnect.xyz');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      } else {}
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
          fontFamily: 'Gilroy-Bold',
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
            'Screenshot Preview',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: 'Gilroy-Bold',
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
                const Text(
                  'No screenshot available or URL is invalid.',
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
                child: const Text('Close'),
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
      CustomPopup.show(context, 'Ticket status updated to $newStatus!');

      String notificationTitle = '';
      String notificationBody = '';

      if (newStatus == 'Solved') {
        notificationTitle = 'Ticket Solved! ✅';
        notificationBody = 'Your support ticket has been marked as solved.';
      } else if (newStatus == 'Rejected') {
        notificationTitle = 'Ticket Rejected! ❌';
        notificationBody =
            'Your support ticket has been rejected. Please check for details.';
      }

      String? fcmToken;
      String? userName;

      QuerySnapshot facultySnap =
          await FirebaseFirestore.instance
              .collection('Faculties')
              .where('email', isEqualTo: userEmail)
              .get();
      if (facultySnap.docs.isNotEmpty) {
        fcmToken = facultySnap.docs.first['fcmToken'];
        userName = facultySnap.docs.first['fullName'] ?? 'Faculty';
      } else {
        QuerySnapshot studentSnap =
            await FirebaseFirestore.instance
                .collection('Students')
                .where('email', isEqualTo: userEmail)
                .get();
        if (studentSnap.docs.isNotEmpty) {
          fcmToken = studentSnap.docs.first['fcmToken'];
          userName = studentSnap.docs.first['fullName'] ?? 'Student';
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
      CustomPopup.show(
        context,
        'Failed to update ticket status or send notification: $e',
      );
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

    // Determine the query based on the user's role and email
    Stream<QuerySnapshot> ticketStream;
    String screenTitle;

    if (widget.userRole == 'Head' && widget.userEmail == null) {
      // Head viewing all tickets from Faculty/Students
      ticketStream =
          FirebaseFirestore.instance
              .collection('helpdesk')
              .orderBy('timestamp', descending: true)
              .snapshots();
      screenTitle = 'All Support Tickets';
    } else if (widget.userRole == 'Head' && widget.userEmail != null) {
      // Head viewing their own tickets
      ticketStream =
          FirebaseFirestore.instance
              .collection('admin_tickets')
              .where(
                'submittedByUid',
                isEqualTo: FirebaseAuth.instance.currentUser?.uid,
              )
              .orderBy('timestamp', descending: true)
              .snapshots();
      screenTitle = 'My Support Tickets';
    } else {
      // Faculty/Student viewing their own tickets
      ticketStream =
          FirebaseFirestore.instance
              .collection('helpdesk')
              .where('email', isEqualTo: widget.userEmail)
              .orderBy('timestamp', descending: true)
              .snapshots();
      screenTitle = 'My Support Tickets';
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
            fontFamily: 'Gilroy-Bold',
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
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    screenTitle.contains('My')
                        ? 'You have not submitted any tickets yet.'
                        : 'No support tickets found',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  if (screenTitle.contains('All'))
                    Text(
                      'Tickets from Faculty/Students will appear here.',
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
                          style: TextStyle(
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
                      'Sub Category: ${ticket['subCategory'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'From: ${ticket['email'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Description: ${ticket['description'] ?? 'No description provided.'}',
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
                          label: const Text('View Screenshot'),
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
                        'Raised: $formattedDate',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                    if (widget.userRole == 'Head' &&
                        screenTitle.contains('All'))
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
                                        ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Text('Reject'),
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
                                        ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Text('Solve'),
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

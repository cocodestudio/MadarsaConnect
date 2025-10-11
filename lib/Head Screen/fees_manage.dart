import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:madarsaConnect/Data/loader.dart';

import '../Data/dynamic_popup.dart';

enum AdminSection { dashboard, qr, fees }

class AdminQrUpdateScreen extends StatefulWidget {
  const AdminQrUpdateScreen({super.key});

  @override
  State<AdminQrUpdateScreen> createState() => _AdminQrUpdateScreenState();
}

class _AdminQrUpdateScreenState extends State<AdminQrUpdateScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  bool _isUploadingMainQr = false;
  bool _isUploadingDonationQr = false;
  bool _isSettingFees = false;
  bool _isLoading = true;
  String? _currentQrCodeUrl;
  String? _currentDonationQrCodeUrl;
  double _currentTotalFees = 0.0;
  String? _headUid;
  List<Map<String, dynamic>> _courses = [];
  Map<String, dynamic>? _selectedCourse;
  final TextEditingController _feesController = TextEditingController();

  AdminSection _currentSection = AdminSection.dashboard;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _feesController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    await _fetchHeadUid();
    if (_headUid != null) {
      if (_currentSection == AdminSection.qr) {
        await _fetchCurrentQrCodes();
      } else if (_currentSection == AdminSection.fees) {
        await _fetchCourses();
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchHeadUid() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc =
          await FirebaseFirestore.instance
              .collection('Heads')
              .doc(user.uid)
              .get();
      if (mounted) {
        setState(() {
          _headUid = doc.id;
        });
      }
    }
  }

  Future<void> _fetchCurrentQrCodes() async {
    try {
      final qrDoc =
          await FirebaseFirestore.instance
              .collection('adminSettings')
              .doc('qrCode')
              .get();
      if (mounted) {
        setState(() {
          _currentQrCodeUrl = qrDoc.data()?['mainQrCodeUrl'];
          _currentDonationQrCodeUrl = qrDoc.data()?['donationQrCodeUrl'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching current QR code URL: $e");
    }
  }

  Future<void> _fetchCourses() async {
    if (_headUid == null) return;
    try {
      final courseSnapshot =
          await FirebaseFirestore.instance
              .collection('courses')
              .where('headUid', isEqualTo: _headUid)
              .get();

      if (mounted) {
        setState(() {
          _courses = courseSnapshot.docs.map((doc) => doc.data()).toList();
          if (_courses.isNotEmpty && _selectedCourse == null) {
            _selectedCourse = _courses.first;
            _fetchCurrentTotalFees();
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching courses: $e");
    }
  }

  Future<void> _fetchCurrentTotalFees() async {
    if (_selectedCourse == null) {
      if (mounted) {
        setState(() {
          _currentTotalFees = 0.0;
          _feesController.text = '';
        });
      }
      return;
    }
    try {
      final courseName =
          _selectedCourse!['name'] as String? ?? 'invalid_course';
      final feeDoc =
          await FirebaseFirestore.instance
              .collection('fees')
              .doc(courseName)
              .get();
      if (mounted) {
        setState(() {
          _currentTotalFees =
              (feeDoc.data()?['totalFees'] as num?)?.toDouble() ?? 0.0;
          _feesController.text = _currentTotalFees.toStringAsFixed(2);
        });
      }
    } catch (e) {
      debugPrint("Error fetching current total fees: $e");
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (mounted) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    }
  }

  Future<void> _uploadQrCode(String type) async {
    if (_imageFile == null) {
      if (mounted) {
        CustomPopup.show(context, 'Please select a QR code image.');
      }
      return;
    }

    setState(() {
      if (type == 'main') {
        _isUploadingMainQr = true;
      } else if (type == 'donation') {
        _isUploadingDonationQr = true;
      }
    });

    try {
      final storageRef = FirebaseStorage.instance.ref().child(
        'qr_codes/$type.png',
      );
      await storageRef.putFile(_imageFile!);
      final downloadUrl = await storageRef.getDownloadURL();

      final updateData = {
        '${type}QrCodeUrl': downloadUrl,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('adminSettings')
          .doc('qrCode')
          .set(updateData, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          if (type == 'main') {
            _currentQrCodeUrl = downloadUrl;
          } else if (type == 'donation') {
            _currentDonationQrCodeUrl = downloadUrl;
          }
          _imageFile = null;
        });
        CustomPopup.show(context, 'QR code successfully updated.');
      }
    } catch (e) {
      debugPrint("Error uploading QR code: $e");
      if (mounted) {
        CustomPopup.show(context, 'Failed to upload QR code: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingMainQr = false;
          _isUploadingDonationQr = false;
        });
      }
    }
  }

  Future<void> _deleteQrCode(String type) async {
    String? urlToDelete;
    if (type == 'main') {
      urlToDelete = _currentQrCodeUrl;
    } else if (type == 'donation') {
      urlToDelete = _currentDonationQrCodeUrl;
    }

    if (urlToDelete == null) {
      if (mounted) {
        CustomPopup.show(context, 'No QR code to delete.');
      }
      return;
    }

    try {
      await FirebaseStorage.instance.refFromURL(urlToDelete).delete();

      final updateData = {'${type}QrCodeUrl': FieldValue.delete()};
      await FirebaseFirestore.instance
          .collection('adminSettings')
          .doc('qrCode')
          .update(updateData);

      if (mounted) {
        setState(() {
          if (type == 'main') {
            _currentQrCodeUrl = null;
          } else if (type == 'donation') {
            _currentDonationQrCodeUrl = null;
          }
          _imageFile = null;
        });
        CustomPopup.show(context, 'QR code successfully deleted.');
      }
    } catch (e) {
      debugPrint("Error deleting QR code: $e");
      if (mounted) {
        CustomPopup.show(context, 'Failed to delete QR code: $e');
      }
    }
  }

  Future<void> _setTotalFees() async {
    if (_selectedCourse == null || _feesController.text.isEmpty) {
      if (mounted) {
        CustomPopup.show(
          context,
          'Please select a course and enter the total fees.',
        );
      }
      return;
    }

    setState(() {
      _isSettingFees = true;
    });

    try {
      final courseName =
          _selectedCourse!['name'] as String? ?? 'invalid_course';
      final totalFees = double.tryParse(_feesController.text) ?? 0.0;

      await FirebaseFirestore.instance.collection('fees').doc(courseName).set({
        'totalFees': totalFees,
        'headUid': _headUid,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _currentTotalFees = totalFees;
        });
        CustomPopup.show(context, 'Total fees successfully updated.');
      }
    } catch (e) {
      debugPrint("Error setting total fees: $e");
      if (mounted) {
        CustomPopup.show(context, 'Failed to set total fees: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSettingFees = false;
        });
      }
    }
  }

  void _showSelectorDialog({
    required BuildContext context,
    required String title,
    required List<Map<String, dynamic>> options,
    required void Function(Map<String, dynamic>) onSelected,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      pageBuilder: (_, __, ___) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                ...options.map((option) {
                  final optionName = option['name'] as String;
                  return GestureDetector(
                    onTap: () {
                      onSelected(option);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Text(
                        optionName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getAppBarTitle() {
    switch (_currentSection) {
      case AdminSection.dashboard:
        return 'Admin Panel';
      case AdminSection.qr:
        return 'QR Management';
      case AdminSection.fees:
        return 'Fee Management';
    }
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );
  }

  Widget _buildQrCodeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('QR Code Management'),
        const SizedBox(height: 24),
        _buildQrCard(
          title: 'Main QR Code',
          url: _currentQrCodeUrl,
          isUploading: _isUploadingMainQr,
          onUpload: () => _uploadQrCode('main'),
          onDelete: () => _deleteQrCode('main'),
        ),
        const SizedBox(height: 24),
        _buildQrCard(
          title: 'Donation QR Code',
          url: _currentDonationQrCodeUrl,
          isUploading: _isUploadingDonationQr,
          onUpload: () => _uploadQrCode('donation'),
          onDelete: () => _deleteQrCode('donation'),
        ),
      ],
    );
  }

  Widget _buildQrCard({
    required String title,
    required String? url,
    required bool isUploading,
    required VoidCallback onUpload,
    required VoidCallback onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: Center(
                child:
                    _imageFile != null
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_imageFile!, fit: BoxFit.cover),
                        )
                        : (url != null
                            ? Image.network(
                              url,
                              fit: BoxFit.contain,
                              loadingBuilder: (
                                context,
                                child,
                                loadingProgress,
                              ) {
                                if (loadingProgress == null) return child;
                                return const CircularProgressIndicator(
                                  color: Colors.redAccent,
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.qr_code_rounded,
                                      size: 60,
                                      color: Colors.black54,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'QR code loading failed',
                                      style: TextStyle(color: Colors.black54),
                                    ),
                                  ],
                                );
                              },
                            )
                            : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cloud_upload_rounded,
                                  size: 60,
                                  color: Colors.black54,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Tap to upload QR code',
                                  style: TextStyle(color: Colors.black54),
                                ),
                              ],
                            )),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isUploading ? null : onUpload,
                  icon:
                      isUploading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Icon(Icons.upload_rounded),
                  label: const Text(
                    'Upload QR Code',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: url != null ? onDelete : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: const Icon(Icons.delete_forever),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Fee Management'),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: () {
                  if (_courses.isNotEmpty) {
                    _showSelectorDialog(
                      context: context,
                      title: 'Select Course',
                      options: _courses,
                      onSelected: (course) {
                        setState(() {
                          _selectedCourse = course;
                          _fetchCurrentTotalFees();
                        });
                      },
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedCourse != null
                              ? (_selectedCourse!['name'] as String? ??
                                  'Select a course')
                              : 'Select a course',
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                _selectedCourse != null
                                    ? Colors.black
                                    : Colors.black.withOpacity(0.6),
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.black54),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildFeesInfoCard(),
              const SizedBox(height: 16),
              _buildFeesTextField(),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isSettingFees ? null : _setTotalFees,
                icon:
                    _isSettingFees
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Icon(Icons.edit_rounded),
                label: const Text(
                  'Set Total Fees',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeesInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Fees',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${_currentTotalFees.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeesTextField() {
    return TextField(
      controller: _feesController,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: 'Enter New Total Fees',
        labelStyle: TextStyle(color: Colors.black.withOpacity(0.6)),
        hintText: 'e.g., 5000',
        hintStyle: TextStyle(color: Colors.black.withOpacity(0.4)),
        prefixIcon: const Icon(
          Icons.currency_rupee_rounded,
          color: Colors.black,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDashboardOption(
            title: 'QR Code Management',
            description: 'Update your payment QR code.',
            icon: Icons.qr_code_rounded,
            onTap: () {
              setState(() {
                _currentSection = AdminSection.qr;
                _bootstrap();
              });
            },
            color: Colors.deepPurple,
          ),
          const SizedBox(height: 15),
          _buildDashboardOption(
            title: 'Fees Management',
            description: 'Set total fees for courses.',
            icon: Icons.monetization_on_rounded,
            onTap: () {
              setState(() {
                _currentSection = AdminSection.fees;
                _bootstrap();
              });
            },
            color: Colors.teal,
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardOption({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentSection != AdminSection.dashboard) {
          setState(() {
            _currentSection = AdminSection.dashboard;
            _imageFile = null;
          });
          return false;
        }
        return true;
      },
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
              if (_currentSection == AdminSection.dashboard) {
                Navigator.pop(context);
              } else {
                setState(() {
                  _currentSection = AdminSection.dashboard;
                  _imageFile = null;
                });
              }
            },
          ),
          title: Text(
            _getAppBarTitle(),
            style: const TextStyle(
              fontSize: 20,
              fontFamily: 'Gilroy-Bold',
              color: Colors.black,
            ),
          ),
          centerTitle: true,
        ),
        body:
            _isLoading
                ? const Center(child: GradientSpinner())
                : Builder(
                  builder: (context) {
                    switch (_currentSection) {
                      case AdminSection.dashboard:
                        return _buildDashboard();
                      case AdminSection.qr:
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(24.0),
                          child: _buildQrCodeSection(),
                        );
                      case AdminSection.fees:
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(24.0),
                          child: _buildFeesSection(),
                        );
                      default:
                        return const Center(child: GradientSpinner());
                    }
                  },
                ),
      ),
    );
  }
}
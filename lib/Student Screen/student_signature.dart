import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../Data/dynamic_popup.dart';
import '../Data/loader.dart';
import '../l10n/app_localizations.dart';

class SignatureUploadScreen extends StatefulWidget {
  final String studentSucId;

  const SignatureUploadScreen({super.key, required this.studentSucId});

  @override
  State<SignatureUploadScreen> createState() => _SignatureUploadScreenState();
}

class _SignatureUploadScreenState extends State<SignatureUploadScreen> {
  File? _selectedSignatureFile;
  String? _signatureUrl;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final CropController _cropController = CropController();

  Uint8List? _imageDataForCropping;
  bool _isCropping = false;

  @override
  void initState() {
    super.initState();
    _loadSignatureUrl();
  }

  // Load the existing signature URL from Firestore
  Future<void> _loadSignatureUrl() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final docSnapshot =
          await FirebaseFirestore.instance
              .collection('Students')
              .doc(user.uid)
              .get();
      if (docSnapshot.exists &&
          docSnapshot.data()!.containsKey('signatureUrl')) {
        setState(() {
          _signatureUrl = docSnapshot.data()!['signatureUrl'];
        });
      }
    } catch (e) {
      debugPrint('Error loading signature URL: $e');
    }
  }

  // Pick and crop image securely
  Future<void> _pickAndCropImage() async {
    final bool status = await _requestPermission();
    if (!status) return;

    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

      if (image == null) {
        if (mounted) {
          CustomPopup.show(
            context,
            AppLocalizations.of(context)!.noImageSelected,
          );
        }
        return;
      }

      final imageBytes = await image.readAsBytes();
      _imageDataForCropping = imageBytes;

      if (mounted) _showCropper();
    } catch (e) {
      debugPrint('Error picking/cropping image: $e');
      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.errorPickingImage,
        );
      }
    }
  }

  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      final PermissionStatus status;
      if (sdkInt >= 33) {
        status = await Permission.photos.request();
      } else {
        status = await Permission.storage.request();
      }
      if (!status.isGranted) {
        if (mounted) {
          CustomPopup.show(
            context,
            AppLocalizations.of(context)!.galleryPermissionDenied,
          );
        }
        return false;
      }
    }
    return true;
  }

  void _showCropper() {
    if (_imageDataForCropping == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, localSetState) {
            return Stack(
              children: [
                _buildCropperSheet(localSetState),
                if (_isCropping)
                  const Positioned.fill(
                    child: Center(child: GradientSpinner()),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCropperSheet(StateSetter localSetState) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDragHandle(),
          Text(
            AppLocalizations.of(context)!.cropSignature,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(0),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Crop(
                controller: _cropController,
                image: _imageDataForCropping!,
                onCropped: (croppedData) async {
                  if (!mounted) return;
                  localSetState(() => _isCropping = true);
                  final tempDir = await getTemporaryDirectory();
                  final filePath =
                      '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
                  final file = File(filePath);
                  await file.writeAsBytes(croppedData);
                  if (mounted) {
                    setState(() {
                      _selectedSignatureFile = file;
                    });
                    Navigator.pop(context);
                  }
                  if (mounted) {
                    localSetState(() => _isCropping = false);
                  }
                },
                withCircleUi: false,
                initialSize: 1.0,
                baseColor: Colors.grey.shade200,
                maskColor: Colors.white,
                cornerDotBuilder:
                    (size, edgeAlignment) =>
                        const DotControl(color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildCropperButton(
                  AppLocalizations.of(context)!.tryAgain,
                  Icons.refresh,
                  _pickAndCropImage,
                  isPrimary: false,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCropperButton(
                  AppLocalizations.of(context)!.apply,
                  Icons.check_circle_outline,
                  () async {
                    localSetState(() => _isCropping = true);
                    await Future.delayed(const Duration(milliseconds: 100));
                    _cropController.crop();
                  },
                  isPrimary: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildCropperButton(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool isPrimary = false,
  }) {
    return isPrimary
        ? ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        )
        : OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            elevation: 0,
            foregroundColor: Colors.black87,
            side: BorderSide(color: Colors.grey.shade400),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        );
  }

  Widget _buildDragHandle() {
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(top: 8, bottom: 14),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  // Upload signature securely
  Future<void> _uploadSignature() async {
    if (_selectedSignatureFile == null) {
      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.selectSignatureToUpload,
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User is not logged in");
      }

      final String fileName = '${widget.studentSucId}_signature.png';
      final storageRef = _storage.ref().child('signatures/$fileName');

      final uploadTask = storageRef.putFile(_selectedSignatureFile!);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('Students')
          .doc(user.uid)
          .update({
            'signatureUrl': downloadUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.signatureUploadedSuccess,
        );
      }

      setState(() {
        _selectedSignatureFile = null;
        _signatureUrl = downloadUrl;
      });
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.errorUploadingSignature,
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
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
          icon: const Icon(Icons.arrow_back, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.uploadSignatureTitle,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCardSection(
                      title: AppLocalizations.of(context)!.digitalSignature,
                      description:
                          AppLocalizations.of(context)!.digitalSignatureDesc,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.redAccent, width: 2),
                        ),
                        child:
                            _selectedSignatureFile != null
                                ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.file(
                                    _selectedSignatureFile!,
                                    fit: BoxFit.contain,
                                  ),
                                )
                                : _signatureUrl != null
                                ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    _signatureUrl!,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (
                                      context,
                                      child,
                                      loadingProgress,
                                    ) {
                                      if (loadingProgress == null) {
                                        return child;
                                      }
                                      return Center(
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              const AlwaysStoppedAnimation<
                                                Color
                                              >(Colors.redAccent),
                                          value:
                                              loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                  : null,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.error_outline,
                                              size: 50,
                                              color: Colors.red,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              AppLocalizations.of(
                                                context,
                                              )!.errorLoadingImage,
                                              style: const TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                )
                                : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.image_outlined,
                                        size: 50,
                                        color: Colors.grey[500],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.noSignatureSelected,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _pickAndCropImage,
                      icon: const Icon(Icons.upload_file),
                      label: Text(
                        AppLocalizations.of(context)!.selectSignatureBtn,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed:
                          _isLoading || _selectedSignatureFile == null
                              ? null
                              : _uploadSignature,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _selectedSignatureFile != null
                                ? Colors.blueAccent
                                : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(AppLocalizations.of(context)!.uploadBtn),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardSection({
    required String title,
    required String description,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

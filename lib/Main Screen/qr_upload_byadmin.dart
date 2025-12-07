import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../Data/loader.dart';

class QrUploadScreen extends StatefulWidget {
  const QrUploadScreen({super.key});

  @override
  State<QrUploadScreen> createState() => _QrUploadScreenState();
}

class _QrUploadScreenState extends State<QrUploadScreen> {
  File? _selectedQrFile;
  String? _currentQrUrl;
  bool _isLoading = false;
  bool _isFetching = true;

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadCurrentQrCode();
  }

  // Fetch the currently active QR code URL from Firestore
  Future<void> _loadCurrentQrCode() async {
    setState(() {
      _isFetching = true;
    });
    try {
      final doc =
          await _firestore.collection('Config').doc('paymentInfo').get();
      if (mounted && doc.exists && doc.data()!.containsKey('qrCodeUrl')) {
        setState(() {
          _currentQrUrl = doc.data()!['qrCodeUrl'];
        });
      }
    } catch (e) {
      debugPrint('Failed to load current QR code: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load current QR code.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetching = false;
        });
      }
    }
  }

  // Pick an image from the gallery
  Future<void> _pickQrImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedQrFile = File(image.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking QR image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error selecting image.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Upload the selected image and update the URL in Firestore
  Future<void> _uploadQrCode() async {
    if (_selectedQrFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a QR code image first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      const String filePath = 'assets/images/qr.png';
      final storageRef = _storage.ref().child(filePath);

      // Upload the file
      final uploadTask = await storageRef.putFile(_selectedQrFile!);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Save the URL to Firestore in a specific document
      await _firestore.collection('Config').doc('paymentInfo').set({
        'qrCodeUrl': downloadUrl,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR Code uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _currentQrUrl = downloadUrl;
          _selectedQrFile = null;
        });
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error uploading QR code.'),
            backgroundColor: Colors.red,
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Upload Payment QR'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Manage Payment QR Code',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Upload a new QR code image. This will replace the existing one for all users.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              height: 250,
              width: 250,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: _buildImagePreview(),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickQrImage,
              icon: const Icon(Icons.image),
              label: const Text('Select New QR Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed:
                  (_isLoading || _selectedQrFile == null)
                      ? null
                      : _uploadQrCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  _isLoading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: GradientSpinner(),
                      )
                      : const Text('Upload and Replace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_selectedQrFile != null) {
      // Show the newly selected file
      return Image.file(_selectedQrFile!, fit: BoxFit.contain);
    } else if (_isFetching) {
      // Show loader while fetching current QR
      return const Center(child: GradientSpinner());
    } else if (_currentQrUrl != null) {
      // Show the current QR from the network
      return Image.network(
        _currentQrUrl!,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          return progress == null
              ? child
              : const Center(child: GradientSpinner());
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(child: Text('Could not load image.'));
        },
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, size: 50, color: Colors.grey[500]),
            const SizedBox(height: 8),
            Text(
              'No QR code uploaded yet.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as p;

import '../Data/dynamic_popup.dart';

class UploadCarouselImagesScreen extends StatefulWidget {
  const UploadCarouselImagesScreen({super.key});

  @override
  State<UploadCarouselImagesScreen> createState() =>
      _UploadCarouselImagesScreenState();
}

class _UploadCarouselImagesScreenState
    extends State<UploadCarouselImagesScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  final List<String> _categories = ["home", "events", "promotions"];
  final Map<String, List<XFile>> _selectedImages = {
    "home": [],
    "events": [],
    "promotions": [],
  };
  final Map<String, List<String>> _currentImageUrls = {
    "home": [],
    "events": [],
    "promotions": [],
  };

  @override
  void initState() {
    super.initState();
    for (var category in _categories) {
      _fetchCurrentImages(category);
    }
  }

  Future<void> _fetchCurrentImages(String category) async {
    try {
      final docSnapshot =
          await FirebaseFirestore.instance
              .collection('app_data')
              .doc('carousel_$category')
              .get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null && data.containsKey('imageUrls')) {
          setState(() {
            _currentImageUrls[category] = List<String>.from(data['imageUrls']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching $category images: $e');
    }
  }

  Future<void> _pickImages(String category) async {
    final List<XFile>? selectedImages = await _picker.pickMultiImage();
    if (selectedImages != null) {
      setState(() {
        _selectedImages[category]!.addAll(selectedImages);
      });
    }
  }

  Future<void> _deleteAllImagesFromStorage(String category) async {
    for (var imageUrl in _currentImageUrls[category]!) {
      try {
        final storageRef = FirebaseStorage.instance.refFromURL(imageUrl);
        await storageRef.delete();
      } catch (e) {
        debugPrint('Error deleting old image $imageUrl: $e');
      }
    }
  }

  Future<void> _uploadImages(String category) async {
    if (_selectedImages[category]!.isEmpty) {
      CustomPopup.show(context, 'Please select at least one image to upload.');
      return;
    }

    setState(() {
      _isUploading = true;
      _currentImageUrls[category] = [];
    });

    try {
      // Delete old images from Storage
      await _deleteAllImagesFromStorage(category);

      List<String> uploadedUrls = [];

      for (var image in _selectedImages[category]!) {
        final fileName =
            "${DateTime.now().millisecondsSinceEpoch}_${p.basename(image.path)}";
        final storageRef = FirebaseStorage.instance.ref().child(
          'carousel_images/$category/$fileName',
        );
        final uploadTask = storageRef.putFile(File(image.path));
        final snapshot = await uploadTask.whenComplete(() {});
        final downloadUrl = await snapshot.ref.getDownloadURL();
        uploadedUrls.add(downloadUrl);
      }

      // Update Firestore with new URLs
      await FirebaseFirestore.instance
          .collection('app_data')
          .doc('carousel_$category')
          .set({
            'imageUrls': uploadedUrls,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

      setState(() {
        _selectedImages[category]!.clear();
        _currentImageUrls[category] = uploadedUrls;
        _isUploading = false;
      });

      if (!mounted) return;
      CustomPopup.show(context, 'Images uploaded successfully to $category!');
    } catch (e) {
      debugPrint('Error uploading $category images: $e');
      setState(() {
        _isUploading = false;
      });
      if (!mounted) return;
      CustomPopup.show(context, 'Failed to upload images: ${e.toString()}');
    }
  }

  Future<void> _deleteImage(String category, String imageUrl) async {
    try {
      final storageRef = FirebaseStorage.instance.refFromURL(imageUrl);
      await storageRef.delete();

      final newUrls = List<String>.from(_currentImageUrls[category]!);
      newUrls.remove(imageUrl);

      await FirebaseFirestore.instance
          .collection('app_data')
          .doc('carousel_$category')
          .update({'imageUrls': newUrls});

      setState(() {
        _currentImageUrls[category] = newUrls;
      });

      if (!mounted) return;
      CustomPopup.show(context, 'Image deleted from $category successfully!');
    } catch (e) {
      debugPrint('Error deleting $category image: $e');
      if (!mounted) return;
      CustomPopup.show(context, 'Failed to delete image: ${e.toString()}');
    }
  }

  Widget _buildCategoryCard(String category) {
    return Card(
      elevation: 5,
      margin: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              category.toUpperCase(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Already uploaded
            _currentImageUrls[category]!.isEmpty
                ? const Center(child: Text('No images uploaded yet.'))
                : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _currentImageUrls[category]!.length,
                  itemBuilder: (context, index) {
                    final imageUrl = _currentImageUrls[category]![index];
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) => const Center(
                                  child: Icon(Icons.broken_image),
                                ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _deleteImage(category, imageUrl),
                            child: const Icon(
                              Icons.delete_forever,
                              color: Colors.red,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

            const SizedBox(height: 20),

            // Pick new images
            Center(
              child: ElevatedButton.icon(
                onPressed: () => _pickImages(category),
                icon: const Icon(Icons.photo_library),
                label: const Text('Pick Images from Gallery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            if (_selectedImages[category]!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                "Selected Images Preview:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _selectedImages[category]!.length,
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_selectedImages[category]![index].path),
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              _isUploading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                    onPressed: () => _uploadImages(category),
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Upload Images'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Carousel Images'),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: _categories.map((c) => _buildCategoryCard(c)).toList(),
        ),
      ),
    );
  }
}

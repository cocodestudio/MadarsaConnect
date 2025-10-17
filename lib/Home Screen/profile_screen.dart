import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:madarsaConnect/Head%20Screen/fees_manage.dart';
import 'package:madarsaConnect/Home%20Screen/change_password.dart';
import 'package:madarsaConnect/Home%20Screen/madarsa_management.dart';
import 'package:madarsaConnect/Home%20Screen/notification_settings.dart';
import 'package:madarsaConnect/Home%20Screen/personal_details.dart';
import 'package:madarsaConnect/Login%20&%20Signup%20Screen/loginpage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:madarsaConnect/Data/loader.dart';
import 'package:madarsaConnect/Data/dynamic_popup.dart';
import '../Data/const.dart';
import '../Data/fullimageview.dart';
import '../Data/main_page.dart';
import '../Head Screen/kitchen_manage.dart';
import '../Head Screen/student_pass_reset.dart';
import '../Student Screen/student_signature.dart';
import 'about.dart';
import 'home_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onProfileUpdated;

  const ProfileScreen({super.key, this.onProfileUpdated});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final CropController _cropController = CropController();

  bool _showEditDetails = false;
  File? _selectedImageFile;
  bool _isUploading = false;
  String? _uploadedImageUrl;
  Uint8List? _imageDataForCropping;
  bool _isCropping = false;
  String? _selectedGender;
  String? _initialEmail;
  String? _initialBio;
  String? _initialGender;
  String? _userId;
  String? _userCourse;
  String? _userDuration;
  String? _userBio;
  String? _userName;
  String? _role;
  Timer? _countdownTimer;
  bool _isLoggingOut = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    _primeFromCache();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _bioController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _handleBackButton() {
    if (_showEditDetails) {
      setState(() => _showEditDetails = false);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _primeFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cachedProfile');
    if (cached == null) return;
    final data = jsonDecode(cached) as Map<String, dynamic>;
    setState(() {
      _userName = data['fullName'] ?? 'N/A';
      _userBio = data['bio'] ?? '';
      _selectedGender = data['gender'];
      _emailController.text = data['email'] ?? '';
      _initialEmail = data['email'] ?? '';
      _initialGender = data['gender'];
      _bioController.text = data['bio'] ?? '';
      _initialBio = data['bio'] ?? '';
      _uploadedImageUrl = data['profilePictureUrl'];
      _userId = data['hucId'] ?? data['fucId'] ?? data['sucId'];
      _userCourse = data['course'];
      _userDuration = data['courseDuration'];
      _role = data['role'];
    });
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedAt = prefs.getInt('cachedProfileAtMs');
    if (cachedAt != null &&
        DateTime.now().millisecondsSinceEpoch - cachedAt < 10 * 60 * 1000) {
      return;
    }
    final user = _auth.currentUser;
    if (user == null) return;

    final isHead = prefs.getBool('isHead') ?? false;
    final isFaculty = prefs.getBool('isFaculty') ?? false;
    final isStudent = prefs.getBool('isStudent') ?? false;

    String collectionName;
    String idPrefix;
    if (isHead) {
      collectionName = 'Heads';
      _role = 'Head';
      idPrefix = 'HUC';
    } else if (isFaculty) {
      collectionName = 'Faculties';
      _role = 'Faculty';
      idPrefix = 'FUC';
    } else if (isStudent) {
      collectionName = 'Students';
      _role = 'Student';
      idPrefix = 'SUC';
    } else {
      return;
    }

    try {
      final docSnapshot =
          await _firestore.collection(collectionName).doc(user.uid).get();
      if (!mounted) return;
      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        setState(() {
          _userName = data['fullName'] ?? 'N/A';
          _userBio = data['bio'] ?? '';
          _selectedGender = data['gender'];
          _emailController.text = data['email'] ?? '';
          _initialEmail = data['email'] ?? '';
          _initialGender = data['gender'];
          _bioController.text = data['bio'] ?? '';
          _initialBio = data['bio'] ?? '';
          _uploadedImageUrl = data['profilePictureUrl'];
          _userId =
              data[isHead
                  ? 'hucId'
                  : isFaculty
                  ? 'fucId'
                  : 'sucId'] ??
              '${idPrefix}${user.uid}';
          if (isStudent) {
            _userCourse = data['course'] ?? 'N/A';
            _userDuration = data['courseDuration'] ?? 'N/A';
            _role = 'Student';
          } else {
            _userCourse = null;
            _userDuration = null;
            _role = data['role'] ?? 'N/A';
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      CustomPopup.show(context, 'Failed to load profile data.');
    }
  }

  Future<void> _uploadProfilePicture(File file) async {
    setState(() => _isUploading = true);
    try {
      final compressed = await _compressImage(file);
      if (compressed != null) {
        file = compressed;
      }

      final user = _auth.currentUser;
      if (user == null) {
        CustomPopup.show(context, 'User not logged in.');
        setState(() => _isUploading = false);
        return;
      }
      final storageRef = _storage.ref().child(
        'profile_pictures/${user.uid}.jpg',
      );
      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      final prefs = await SharedPreferences.getInstance();
      final isHead = prefs.getBool('isHead') ?? false;
      final isFaculty = prefs.getBool('isFaculty') ?? false;
      final isStudent = prefs.getBool('isStudent') ?? false;
      String collectionName =
          isHead
              ? 'Heads'
              : isFaculty
              ? 'Faculties'
              : 'Students';

      await _firestore.collection(collectionName).doc(user.uid).update({
        'profilePictureUrl': downloadUrl,
      });

      setState(() {
        _uploadedImageUrl = downloadUrl;
        _isUploading = false;
      });

      final cached = prefs.getString('cachedProfile');
      Map<String, dynamic> profile = {};
      if (cached != null) {
        profile = jsonDecode(cached) as Map<String, dynamic>;
      }
      profile['profilePictureUrl'] = downloadUrl;
      await prefs.setString('cachedProfile', jsonEncode(profile));
      await prefs.setInt(
        'cachedProfileAtMs',
        DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.setString('cachedProfileUrl', downloadUrl);

      CustomPopup.show(context, 'Profile picture uploaded successfully!');
    } catch (e) {
      setState(() => _isUploading = false);
      debugPrint('❌ Profile picture upload error: $e');
      CustomPopup.show(context, 'Failed to upload profile picture.');
    }
  }

  Future<void> _deleteProfilePicture() async {
    if (_uploadedImageUrl == null) {
      CustomPopup.show(context, "No image found to delete.");
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final storageRef = _storage.refFromURL(_uploadedImageUrl!);
      await storageRef.delete();

      final prefs = await SharedPreferences.getInstance();
      final isHead = prefs.getBool('isHead') ?? false;
      final isFaculty = prefs.getBool('isFaculty') ?? false;
      final isStudent = prefs.getBool('isStudent') ?? false;
      String collectionName =
          isHead
              ? 'Heads'
              : isFaculty
              ? 'Faculties'
              : 'Students';

      await _firestore.collection(collectionName).doc(user.uid).update({
        'profilePictureUrl': FieldValue.delete(),
      });

      setState(() {
        _selectedImageFile = null;
        _uploadedImageUrl = null;
        _isUploading = false;
      });

      final cached = prefs.getString('cachedProfile');
      if (cached != null) {
        final profile = jsonDecode(cached) as Map<String, dynamic>;
        profile.remove('profilePictureUrl');
        await prefs.setString('cachedProfile', jsonEncode(profile));
        await prefs.setInt(
          'cachedProfileAtMs',
          DateTime.now().millisecondsSinceEpoch,
        );
        await prefs.remove('cachedProfileUrl');
      }

      CustomPopup.show(context, "Profile picture deleted 🗑️");
    } catch (e) {
      setState(() => _isUploading = false);
      debugPrint("❌ Profile picture delete error: $e");
      CustomPopup.show(context, "Failed to delete profile picture.");
    }
  }

  Future<void> _updateProfileDetails() async {
    setState(() => _isUploading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        CustomPopup.show(context, 'User not logged in.');
        setState(() => _isUploading = false);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final isHead = prefs.getBool('isHead') ?? false;
      final isFaculty = prefs.getBool('isFaculty') ?? false;
      final isStudent = prefs.getBool('isStudent') ?? false;
      String collectionName =
          isHead
              ? 'Heads'
              : isFaculty
              ? 'Faculties'
              : 'Students';

      final Map<String, dynamic> updateData = {
        'bio': _bioController.text.trim(),
        'gender': _selectedGender,
      };
      await _firestore
          .collection(collectionName)
          .doc(user.uid)
          .update(updateData);

      final cached = prefs.getString('cachedProfile');
      Map<String, dynamic> profile = {};
      if (cached != null) {
        profile = jsonDecode(cached) as Map<String, dynamic>;
      }
      profile['bio'] = _bioController.text.trim();
      profile['gender'] = _selectedGender;
      await prefs.setString('cachedProfile', jsonEncode(profile));
      await prefs.setInt(
        'cachedProfileAtMs',
        DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.setString('cachedFullName', profile['fullName'] ?? '');
      await prefs.setString(
        'cachedProfileUrl',
        profile['profilePictureUrl'] ?? '',
      );

      setState(() {
        _initialEmail = _emailController.text.trim();
        _initialGender = _selectedGender;
        _initialBio = _bioController.text.trim();
        _userBio = _bioController.text.trim();
        _isUploading = false;
        _showEditDetails = false;
      });
      CustomPopup.show(context, "Profile updated successfully ✅");
      widget.onProfileUpdated?.call();
    } catch (e) {
      setState(() => _isUploading = false);
      debugPrint("❌ Update Profile Error: $e");
      if (mounted) {
        CustomPopup.show(
          context,
          "Failed to update profile. Please try again.",
        );
      }
    }
  }

  Future<void> _logout() async {
    if (!mounted) return;
    setState(() => _isLoggingOut = true);

    try {
      Provider.of<ProfileProvider>(context, listen: false).resetState();
      await _auth.signOut();
    } catch (e) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_role');
    await prefs.remove('cachedProfile');
    await prefs.remove('cachedProfileAtMs');
    await prefs.remove('cachedFullName');
    await prefs.remove('cachedProfileUrl');
    await prefs.remove('isHead');
    await prefs.remove('isFaculty');
    await prefs.remove('isStudent');
    await prefs.remove('headPassword');
    await prefs.remove('loginAttempts');
    await prefs.remove('blockedUntil');

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final status = await _requestPermission();
      if (!status) return;
      final pickedImage = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
      );
      if (pickedImage != null) {
        final imageBytes = await pickedImage.readAsBytes();
        _imageDataForCropping = imageBytes;
        if (mounted) _showCropper();
      } else {
        CustomPopup.show(context, "No image selected.");
      }
    } catch (e) {
      debugPrint("❌ Error picking image: $e");
      CustomPopup.show(context, "Something went wrong while picking image.");
    }
  }

  Future<void> _pickImageFromCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      CustomPopup.show(context, "Camera permission denied");
      return;
    }
    try {
      final pickedImage = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (pickedImage != null) {
        final imageBytes = await pickedImage.readAsBytes();
        setState(() => _imageDataForCropping = imageBytes);
        _showCropper();
      } else {
        CustomPopup.show(context, "Camera cancelled");
      }
    } catch (e) {
      debugPrint("❌ Error picking from camera: $e");
      CustomPopup.show(
        context,
        "Something went wrong while picking from camera.",
      );
    }
  }

  Future<File?> _compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath =
        "${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg";
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 50,
      format: CompressFormat.jpeg,
    );
    return result != null ? File(result.path) : null;
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
        CustomPopup.show(context, "Gallery permission denied.");
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
          const Text(
            "Adjust & Crop Image",
            style: TextStyle(fontSize: 18, fontFamily: 'Gilroy-Bold'),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 1,
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
                      _selectedImageFile = file;
                    });
                    Navigator.pop(context);
                    await _uploadProfilePicture(file);
                  }
                  if (mounted) {
                    localSetState(() => _isCropping = false);
                  }
                },
                withCircleUi: true,
                baseColor: Colors.grey.shade200,
                maskColor: Colors.white,
                radius: 999,
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
                  "Try Again",
                  Icons.refresh,
                  _pickImageFromGallery,
                  isPrimary: false,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCropperButton(
                  "Apply",
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

  void _showImageOptionBottomSheet() {
    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDragHandle(),
              _buildImageOptionListTile(
                iconPath: 'assets/icons/library.svg',
                title: 'Choose from library',
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              _buildImageOptionListTile(
                iconPath: 'assets/icons/camera.svg',
                title: 'Take photo',
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromCamera();
                },
              ),
              _buildImageOptionListTile(
                iconPath: 'assets/icons/delete.svg',
                title: 'Delete',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _deleteProfilePicture();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageOptionListTile({
    required String iconPath,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.black,
  }) {
    return ListTile(
      leading: SvgPicture.asset(
        iconPath,
        width: 26,
        height: 26,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
      title: Text(
        title,
        style: TextStyle(fontFamily: 'Gilroy-Bold', fontSize: 15, color: color),
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_showEditDetails) {
          setState(() => _showEditDetails = false);
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
            icon: const Icon(Icons.arrow_back, size: 26),
            onPressed: _handleBackButton,
          ),
          title: const Text(
            'Profile',
            style: TextStyle(
              fontSize: 20,
              fontFamily: 'Gilroy-Bold',
              color: Colors.black,
            ),
          ),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.only(
                      top: constraints.maxHeight * 0.03,
                      bottom: MediaQuery.of(context).padding.bottom + 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileHeader(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        ),
                        if (!_showEditDetails)
                          _buildEditDetailsButton(constraints.maxWidth),
                        Divider(thickness: 0, color: Colors.grey[300]),
                        if (_showEditDetails)
                          _buildEditDetailsForm(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          )
                        else
                          _buildSettingsList(constraints.maxWidth),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (_isUploading)
              Container(
                color: Colors.black.withOpacity(0.25),
                child: const Center(child: GradientSpinner()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(double screenWidth, double screenHeight) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              if (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullImageView(imageUrl: _uploadedImageUrl!),
                  ),
                );
              }
            },
            child: CircleAvatar(
              radius: screenWidth * 0.11,
              backgroundColor: Colors.grey.shade200,
              backgroundImage:
                  (_selectedImageFile != null &&
                          _selectedImageFile!.path.isNotEmpty)
                      ? FileImage(_selectedImageFile!)
                      : (_uploadedImageUrl != null &&
                          _uploadedImageUrl!.trim().isNotEmpty &&
                          _uploadedImageUrl!.startsWith("http"))
                      ? CachedNetworkImageProvider(_uploadedImageUrl!)
                      : null,
              child:
                  (_selectedImageFile == null && _uploadedImageUrl == null)
                      ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: SvgPicture.asset(
                          'assets/icons/users.svg',
                          fit: BoxFit.contain,
                        ),
                      )
                      : null,
            ),
          ),
          SizedBox(height: screenHeight * 0.01),
          if (_showEditDetails) ...[
            SizedBox(height: screenHeight * 0.01),
            GestureDetector(
              onTap: _showImageOptionBottomSheet,
              child: Text(
                "Change Profile Picture",
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(height: screenHeight * 0.02),
          ] else ...[
            Text(
              _userName ?? "",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: screenWidth * 0.048,
              ),
            ),
            SizedBox(height: 4),
            Text(
              _userId?.toUpperCase() ?? "",
              style: TextStyle(
                fontSize: screenWidth * 0.038,
                color: Colors.grey,
              ),
            ),
            if (_role == 'Student' &&
                _userCourse != null &&
                _userDuration != null) ...[
              SizedBox(height: 4),
              Text(
                "$_userCourse | $_userDuration",
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  color: Colors.grey,
                ),
              ),
            ],
            if (_userBio != null && _userBio!.trim().isNotEmpty) ...[
              SizedBox(height: 4),
              Text(
                _userBio!,
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  color: Colors.black87,
                ),
              ),
            ],
            SizedBox(height: screenHeight * 0.01),
          ],
        ],
      ),
    );
  }

  Widget _buildEditDetailsButton(double screenWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: screenWidth * 0.02),
      child: Center(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _showEditDetails = true),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: screenWidth * 0.020,
              horizontal: screenWidth * 0.035,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Edit Details",
                  style: TextStyle(
                    fontSize: screenWidth * 0.040,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[800],
                    fontFamily: 'Gilroy-Bold',
                  ),
                ),
                SizedBox(width: screenWidth * 0.02),
                Icon(
                  Icons.edit,
                  size: screenWidth * 0.058,
                  color: Colors.blue[800],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditDetailsForm(double screenWidth, double screenHeight) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: screenHeight * 0.02,
        horizontal: screenWidth * 0.05,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEmailTextField(),
          const SizedBox(height: 12),
          _buildGenderDropdown(),
          const SizedBox(height: 12),
          _buildBioTextField(),
          const SizedBox(height: 20),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildEmailTextField() {
    return TextField(
      controller: _emailController,
      readOnly: true,
      style: const TextStyle(color: Colors.black, fontSize: 14),
      decoration: InputDecoration(
        labelText: "Email Address",
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        prefixIcon: const Icon(Icons.email_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.grey, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.black, width: 1),
        ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedGender,
        iconEnabledColor: Colors.black,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          icon: SvgPicture.asset(
            'assets/icons/gender.svg',
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
          "Gender",
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        items:
            ["MALE", "FEMALE", "OTHER"]
                .map(
                  (String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
        onChanged:
            (String? newValue) => setState(() => _selectedGender = newValue),
      ),
    );
  }

  Widget _buildBioTextField() {
    return TextField(
      controller: _bioController,
      maxLines: 1,
      style: const TextStyle(color: Colors.black, fontSize: 14),
      decoration: InputDecoration(
        labelText: "Bio",
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        prefixIcon: const Icon(Icons.note_add_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.grey, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.black, width: 1),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isUploading ? null : _updateProfileDetails,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child:
            _isUploading
                ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                : const Text(
                  'Save',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontFamily: 'Gilroy-Bold',
                  ),
                ),
      ),
    );
  }

  Widget _buildSettingsList(double screenWidth) {
    const String userIcons = 'assets/icons/user.svg';
    const String notificationIcon = 'assets/icons/notification.svg';
    const String signatureIcon = 'assets/icons/signature.svg';
    const String feesIcon = 'assets/icons/receipt.svg';
    const String passwordResetIcon = 'assets/icons/lock_reset.svg';
    const String kitchenIcon = 'assets/icons/kitchen.svg';
    const String inventoryIcon = 'assets/icons/inventory.svg';
    const String aboutIcon = 'assets/icons/info.svg';
    const String logoutIcon = 'assets/icons/logout.svg';
    const String passwordChange = 'assets/icons/password_change.svg';
    final List<Map<String, dynamic>> upiSettings = [
      {
        "icon": userIcons,
        "title": "Personal Details",
        "subtitle": "View or manage your personal information",
        "onTap": () {
          navigateWithPremiumTransition(context, const PersonalDetailsScreen());
        },
      },
      {
        "icon": notificationIcon,
        "title": "Notification Alerts",
        "subtitle": "Get alerts before any activity",
        "onTap": () {
          navigateWithPremiumTransition(
            context,
            const ManageNotificationsScreen(),
          );
        },
      },
      if (_role == 'Student')
        {
          "icon": signatureIcon,
          "title": "Signature Upload",
          "subtitle": "Upload or manage your digital signature.",
          "onTap": () {
            navigateWithPremiumTransition(
              context,
              SignatureUploadScreen(studentSucId: _userId ?? ''),
            );
          },
        },
      if (_role == "Head")
        {
          "icon": feesIcon,
          "title": "Fees Management",
          "subtitle": "Manage and track all fee-related payments",
          "onTap": () {
            navigateWithPremiumTransition(context, AdminQrUpdateScreen());
          },
        },
      if (_role == "Head")
        {
          "icon": passwordResetIcon,
          "title": "Reset Student Password",
          "subtitle": "Reset student password to default password",
          "onTap": () {
            navigateWithPremiumTransition(
              context,
              const ResetStudentPasswordPage(),
            );
          },
        },
      if (_role == "Head")
        {
          "icon": kitchenIcon,
          "title": "Kitchen Management",
          "subtitle": "Manage ingredients and recipes for the kitchen",
          "onTap": () {
            navigateWithPremiumTransition(
              context,
              const KitchenAdminPanelScreen(),
            );
          },
        },
      if (_role == "Head")
        {
          "icon": inventoryIcon,
          "title": "Madarsa Management",
          "subtitle": "Manage expenses and inventory items",
          "onTap": () {
            navigateWithPremiumTransition(
              context,
              const AdminManagementScreen(),
            );
          },
        },
    ];

    final List<Map<String, dynamic>> paytmSettings = [
      {
        "icon": passwordChange,
        "title": "Change Your Password",
        "subtitle": "Update your credentials securely",
        "onTap": () {
          navigateWithPremiumTransition(context, const ChangePasswordScreen());
        },
      },
      {
        "icon": aboutIcon,
        "title": "About",
        "subtitle": "Learn more about the app",
        "onTap": () {
          navigateWithPremiumTransition(context, const AboutScreen());
        },
      },
      {
        "icon": logoutIcon,
        "title": "Logout",
        "subtitle": "Close your app",
        "onTap": _showLogoutDialog,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("PREFERENCES", screenWidth),
        ...upiSettings
            .map((item) => _buildSettingItem(item, screenWidth))
            .toList(),
        _buildSectionHeader("OTHER SETTINGS", screenWidth),
        ...paytmSettings
            .map((item) => _buildSettingItem(item, screenWidth))
            .toList(),
      ],
    );
  }

  Widget _buildSettingItem(Map<String, dynamic> item, double screenWidth) {
    return ListTile(
      leading: SvgPicture.asset(
        item['icon'],
        width: screenWidth * 0.06,
        height: screenWidth * 0.06,
        colorFilter: const ColorFilter.mode(Colors.black54, BlendMode.srcIn),
      ),
      title: Text(
        item['title'],
        style: TextStyle(
          fontSize: screenWidth * 0.04,
          color: Colors.black,
          fontFamily: 'Gilroy-Regular',
        ),
      ),
      subtitle:
          item['subtitle'] != null
              ? Text(
                item['subtitle'],
                style: TextStyle(
                  fontSize: screenWidth * 0.034,
                  color: Colors.grey,
                  fontFamily: 'Gilroy-Regular',
                ),
              )
              : null,
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: screenWidth * 0.038,
        color: Colors.grey,
      ),
      onTap: item['onTap'],
    );
  }

  Widget _buildSectionHeader(String title, double screenWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.045,
        vertical: 10,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: screenWidth * 0.035,
          fontFamily: 'Gilroy-Regular',
          color: Colors.grey,
        ),
      ),
    );
  }

  void _showLogoutDialog() async {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: screenHeight * 0.04,
                horizontal: screenWidth * 0.06,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.logout,
                    size: screenWidth * 0.12,
                    color: Colors.redAccent,
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  Text(
                    'Are you sure you want to logout?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.03),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLogoutButton(
                          context,
                          true,
                          screenHeight,
                          screenWidth,
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.03),
                      Expanded(
                        child: _buildLogoutButton(
                          context,
                          false,
                          screenHeight,
                          screenWidth,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );

    if (shouldLogout == true) {
      _logout();
    }
  }

  Widget _buildLogoutButton(
    BuildContext context,
    bool isConfirm,
    double screenHeight,
    double screenWidth,
  ) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isConfirm ? Colors.redAccent : Colors.grey[300],
        foregroundColor: isConfirm ? Colors.white : Colors.black87,
        padding: EdgeInsets.symmetric(vertical: screenHeight * 0.018),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      onPressed:
          isConfirm
              ? () async {
                setState(() => _isLoggingOut = true);
                await _logout();
                setState(() => _isLoggingOut = false);
              }
              : () => Navigator.of(context).pop(false),
      child:
          _isLoggingOut && isConfirm
              ? SizedBox(
                width: screenWidth * 0.05,
                height: screenWidth * 0.05,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
              : Text(
                isConfirm ? 'Logout' : 'Cancel',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  fontWeight: FontWeight.w600,
                ),
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
}

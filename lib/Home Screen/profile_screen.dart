import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:madarsaconnect/Home%20Screen/personal_details.dart';
import '../Data/dynamic_popup.dart';
import '../Data/loader.dart';
import '../Head Screen/fees_manage.dart';
import '../Login & Signup Screen/loginpage.dart';
import '../l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Data/fullimageview.dart';
import '../Data/main_page.dart';
import '../Head Screen/kitchen_manage.dart';
import '../Head Screen/student_pass_reset.dart';
import '../Student Screen/student_signature.dart';
import 'about.dart';
import 'change_password.dart';
import 'home_screen.dart';
import 'language_change.dart';
import 'madarsa_management.dart';
import 'notification_settings.dart';

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

  // ----- YAHAN FIX KIYA HAI (BOOLEANS ADD KIYE) -----
  bool _isHead = false;
  bool _isFaculty = false;
  bool _isStudent = false;

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
    if (!mounted) return;
    final appLocalizations = AppLocalizations.of(context)!;
    setState(() {
      _userName = data['fullName'] ?? appLocalizations.na;
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

      // ----- YAHAN BHI FIX KIYA HAI -----
      _isHead = prefs.getBool('isHead') ?? false;
      _isFaculty = prefs.getBool('isFaculty') ?? false;
      _isStudent = prefs.getBool('isStudent') ?? false;
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
    if (!mounted) return;
    final appLocalizations = AppLocalizations.of(context)!;

    final isHead = prefs.getBool('isHead') ?? false;
    final isFaculty = prefs.getBool('isFaculty') ?? false;
    final isStudent = prefs.getBool('isStudent') ?? false;

    // ----- YAHAN FIX KIYA HAI (STATE SET KIYA) -----
    setState(() {
      _isHead = isHead;
      _isFaculty = isFaculty;
      _isStudent = isStudent;
    });

    String collectionName;
    String idPrefix;
    if (isHead) {
      collectionName = 'Heads';
      _role = appLocalizations.roleHead;
      idPrefix = 'HUC';
    } else if (isFaculty) {
      collectionName = 'Faculties';
      _role = appLocalizations.roleFaculty;
      idPrefix = 'FUC';
    } else if (isStudent) {
      collectionName = 'Students';
      _role = appLocalizations.roleStudent;
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
          _userName = data['fullName'] ?? appLocalizations.na;
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
            _userCourse = data['course'] ?? appLocalizations.na;
            _userDuration = data['courseDuration'] ?? appLocalizations.na;
            _role = appLocalizations.roleStudent;
          } else {
            _userCourse = null;
            _userDuration = null;
            _role = data['role'] ?? appLocalizations.na;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.failedToLoadProfileData,
        );
      }
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
        if (mounted) {
          CustomPopup.show(
            context,
            AppLocalizations.of(context)!.userNotLoggedIn,
          );
        }
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

      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.profilePicUploaded,
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      debugPrint('❌ Profile picture upload error: $e');
      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.failedToUploadProfilePic,
        );
      }
    }
  }

  Future<void> _deleteProfilePicture() async {
    if (_uploadedImageUrl == null) {
      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.noImageToDelete,
        );
      }
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

      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.profilePicDeleted,
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      debugPrint("❌ Profile picture delete error: $e");
      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.failedToDeleteProfilePic,
        );
      }
    }
  }

  Future<void> _updateProfileDetails() async {
    setState(() => _isUploading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) {
          CustomPopup.show(
            context,
            AppLocalizations.of(context)!.userNotLoggedIn,
          );
        }
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
      if (mounted) {
        CustomPopup.show(context, AppLocalizations.of(context)!.profileUpdated);
      }
      widget.onProfileUpdated?.call();
    } catch (e) {
      setState(() => _isUploading = false);
      debugPrint("❌ Update Profile Error: $e");
      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.failedToUpdateProfile,
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
        if (mounted) {
          CustomPopup.show(
            context,
            AppLocalizations.of(context)!.noImageSelected,
          );
        }
      }
    } catch (e) {
      debugPrint("❌ Error picking image: $e");
      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.errorPickingImage,
        );
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.cameraPermissionDenied,
        );
      }
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
        if (mounted) {
          CustomPopup.show(
            context,
            AppLocalizations.of(context)!.cameraCancelled,
          );
        }
      }
    } catch (e) {
      debugPrint("❌ Error picking from camera: $e");
      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.errorPickingFromCamera,
        );
      }
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
            AppLocalizations.of(context)!.adjustCropImage,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  AppLocalizations.of(context)!.tryAgain,
                  Icons.refresh,
                  _pickImageFromGallery,
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
                title: AppLocalizations.of(context)!.chooseFromLibrary,
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              _buildImageOptionListTile(
                iconPath: 'assets/icons/camera.svg',
                title: AppLocalizations.of(context)!.takePhoto,
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromCamera();
                },
              ),
              _buildImageOptionListTile(
                iconPath: 'assets/icons/delete.svg',
                title: AppLocalizations.of(context)!.delete,
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
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: color,
        ),
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
          title: Text(
            AppLocalizations.of(context)!.profile,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
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
                AppLocalizations.of(context)!.changeProfilePicture,
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
            // ----- YAHAN FIX KIYA HAI (_role ki jagah _isStudent) -----
            if (_isStudent && _userCourse != null && _userDuration != null) ...[
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
                  AppLocalizations.of(context)!.editDetails,
                  style: TextStyle(
                    fontSize: screenWidth * 0.040,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[800],
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
        labelText: AppLocalizations.of(context)!.emailAddress,
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
    final Map<String, String> genderMap = {
      "MALE": AppLocalizations.of(context)!.male,
      "FEMALE": AppLocalizations.of(context)!.female,
      "OTHER": AppLocalizations.of(context)!.other,
    };

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
        hint: Text(
          AppLocalizations.of(context)!.gender,
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
        items:
            ["MALE", "FEMALE", "OTHER"]
                .map(
                  (String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(genderMap[value] ?? value),
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
        labelText: AppLocalizations.of(context)!.bio,
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
                : Text(
                  AppLocalizations.of(context)!.save,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
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
    const String languageIcon = 'assets/icons/language.svg';
    const String passwordChange = 'assets/icons/password_change.svg';
    final List<Map<String, dynamic>> upiSettings = [
      {
        "icon": userIcons,
        "title": AppLocalizations.of(context)!.personalDetails,
        "subtitle": AppLocalizations.of(context)!.viewManagePersonalIntro,
        "onTap": () {
          navigateWithPremiumTransition(context, const PersonalDetailsScreen());
        },
      },
      {
        "icon": notificationIcon,
        "title": AppLocalizations.of(context)!.notificationAlerts,
        "subtitle": AppLocalizations.of(context)!.getAlertsActivity,
        "onTap": () {
          navigateWithPremiumTransition(
            context,
            const ManageNotificationsScreen(),
          );
        },
      },
      if (_isStudent)
        {
          "icon": signatureIcon,
          "title": AppLocalizations.of(context)!.signatureUpload,
          "subtitle": AppLocalizations.of(context)!.uploadManageSignature,
          "onTap": () {
            navigateWithPremiumTransition(
              context,
              SignatureUploadScreen(studentSucId: _userId ?? ''),
            );
          },
        },
      if (_isHead)
        {
          "icon": feesIcon,
          "title": AppLocalizations.of(context)!.feesQRManagement,
          "subtitle": AppLocalizations.of(context)!.manageQRTrackPayments,
          "onTap": () {
            navigateWithPremiumTransition(context, AdminQrUpdateScreen());
          },
        },
      // ----- YAHAN FIX KIYA HAI (_role ki jagah _isHead) -----
      if (_isHead)
        {
          "icon": passwordResetIcon,
          "title": AppLocalizations.of(context)!.resetStudentPassword,
          "subtitle": AppLocalizations.of(context)!.resetStudentPasswordSub,
          "onTap": () {
            navigateWithPremiumTransition(
              context,
              const ResetStudentPasswordPage(),
            );
          },
        },
      // ----- YAHAN FIX KIYA HAI (_role ki jagah _isHead) -----
      if (_isHead)
        {
          "icon": kitchenIcon,
          "title": AppLocalizations.of(context)!.kitchenManagement,
          "subtitle": AppLocalizations.of(context)!.manageIngredientsRecipes,
          "onTap": () {
            navigateWithPremiumTransition(
              context,
              const KitchenAdminPanelScreen(),
            );
          },
        },
      // ----- YAHAN FIX KIYA HAI (_role ki jagah _isHead) -----
      if (_isHead)
        {
          "icon": inventoryIcon,
          "title": AppLocalizations.of(context)!.madarsaManagement,
          "subtitle": AppLocalizations.of(context)!.manageExpensesInventory,
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
        "title": AppLocalizations.of(context)!.changeYourPassword,
        "subtitle": AppLocalizations.of(context)!.updateCredentialsSecurely,
        "onTap": () {
          navigateWithPremiumTransition(context, const ChangePasswordScreen());
        },
      },
      {
        "icon": languageIcon,
        "title": AppLocalizations.of(context)!.changeYourLanguage,
        "subtitle": AppLocalizations.of(context)!.applyMultipleLanguage,
        "onTap": () {
          navigateWithPremiumTransition(context, const ChooseLanguageScreen());
        },
      },
      {
        "icon": aboutIcon,
        "title": AppLocalizations.of(context)!.about,
        "subtitle": AppLocalizations.of(context)!.learnMoreAboutApp,
        "onTap": () {
          navigateWithPremiumTransition(context, const AboutScreen());
        },
      },
      {
        "icon": logoutIcon,
        "title": AppLocalizations.of(context)!.logout,
        "subtitle": AppLocalizations.of(context)!.closeYourApp,
        "onTap": _showLogoutDialog,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          AppLocalizations.of(context)!.preferences,
          screenWidth,
        ),
        ...upiSettings
            .map((item) => _buildSettingItem(item, screenWidth))
            .toList(),
        _buildSectionHeader(
          AppLocalizations.of(context)!.otherSettings,
          screenWidth,
        ),
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
        style: TextStyle(fontSize: screenWidth * 0.04, color: Colors.black),
      ),
      subtitle:
          item['subtitle'] != null
              ? Text(
                item['subtitle'],
                style: TextStyle(
                  fontSize: screenWidth * 0.034,
                  color: Colors.grey,
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
        style: TextStyle(fontSize: screenWidth * 0.035, color: Colors.grey),
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
                    AppLocalizations.of(context)!.areYouSureLogout,
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
                isConfirm
                    ? AppLocalizations.of(context)!.logout
                    : AppLocalizations.of(context)!.cancel,
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

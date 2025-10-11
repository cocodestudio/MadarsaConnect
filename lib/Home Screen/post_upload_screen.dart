import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:madarsaConnect/Home%20Screen/upload_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Data/dynamic_popup.dart';

class PostUploadScreen extends StatefulWidget {
  const PostUploadScreen({super.key});

  @override
  State<PostUploadScreen> createState() => _PostUploadScreenState();
}

enum MediaType { image }

class _PostUploadScreenState extends State<PostUploadScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _captionController = TextEditingController();
  final List<File> _selectedMedia = [];
  final List<MediaType> _selectedMediaTypes = [];
  String _privacySetting = 'Public';
  int _captionCharacterCount = 0;
  String? userName;
  String? userProfileUrl;
  String? userRole;
  String? userId;
  String? userEmail;
  String? userHeadUid;

  final FocusNode _captionFocusNode = FocusNode();
  late AnimationController _animationController;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _captionController.addListener(_updateCharacterCount);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_captionFocusNode);
    });
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final isHead = prefs.getBool('isHead') ?? false;
    final isFaculty = prefs.getBool('isFaculty') ?? false;
    final isStudent = prefs.getBool('isStudent') ?? false;

    String collectionName = '';
    if (isHead) {
      collectionName = 'Heads';
    } else if (isFaculty) {
      collectionName = 'Faculties';
    } else if (isStudent) {
      collectionName = 'Students';
    } else {
      return;
    }

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection(collectionName)
              .doc(user.uid)
              .get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          userId = user.uid;
          userRole = data['role'] ?? '';
          userEmail = data['email'] ?? '';
          userName = data['fullName'] ?? '';
          userProfileUrl = data['profilePictureUrl'] ?? '';
          userHeadUid = data['headUid'];
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to fetch user data: $e');
    }
  }

  @override
  void dispose() {
    _captionController.removeListener(_updateCharacterCount);
    _captionController.dispose();
    _captionFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _updateCharacterCount() {
    setState(() {
      _captionCharacterCount = _captionController.text.length;
    });
  }

  Future<void> _pickMedia() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> pickedFiles = await picker.pickMultiImage();

    if (pickedFiles.isNotEmpty) {
      setState(() {
        for (var pickedFile in pickedFiles) {
          _selectedMedia.add(File(pickedFile.path));
          _selectedMediaTypes.add(MediaType.image);
        }
      });
    } else {
      if (mounted) {}
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _selectedMedia.removeAt(index);
      _selectedMediaTypes.removeAt(index);
    });
  }

  void _uploadPost() {
    if (_captionController.text.trim().isEmpty && _selectedMedia.isEmpty) {
      CustomPopup.show(context,"Please write something or add media to post.");
      return;
    }

    Provider.of<UploadProvider>(context, listen: false).uploadPost(
      caption: _captionController.text.trim(),
      mediaFiles: _selectedMedia,
      userId: userId,
      userName: userName,
      userProfileUrl: userProfileUrl,
      userRole: userRole,
      userHeadUid: userHeadUid,
      privacySetting: _privacySetting,
    );

    Navigator.pop(context);
  }

  void _showPrivacyOptions() {
    _animationController.forward();
    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      transitionAnimationController: _animationController,
      builder: (BuildContext context) {
        return SlideTransition(
          position: _offsetAnimation,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Who can see this post?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 10),
                _buildPrivacyOption(
                  'Public',
                  'Anyone on the platform',
                  Icons.public,
                ),
                _buildPrivacyOption(
                  'Only Me',
                  'Only you can see this post',
                  Icons.lock,
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      _animationController.reverse();
    });
  }

  Widget _buildPrivacyOption(String title, String subtitle, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
      trailing:
          _privacySetting == title
              ? const Icon(Icons.check_circle, color: Colors.redAccent)
              : null,
      onTap: () {
        setState(() {
          _privacySetting = title;
        });
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return WillPopScope(
      onWillPop: () async {
        FocusScope.of(context).unfocus();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            Container(
              height: 75,
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black),
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        Navigator.pop(context);
                      },
                    ),
                    TextButton(
                      onPressed: _uploadPost,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 0),
                      ),
                      child: const Text(
                        "Post",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.04,
                        vertical: 15,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.grey[200],
                            backgroundImage:
                                userProfileUrl != null &&
                                        userProfileUrl!.isNotEmpty
                                    ? NetworkImage(userProfileUrl!)
                                    : null,
                            child:
                                userProfileUrl == null ||
                                        userProfileUrl!.isEmpty
                                    ? SvgPicture.asset(
                                      'assets/icons/users.svg',
                                      width: 30,
                                      height: 30,
                                    )
                                    : null,
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: _showPrivacyOptions,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.blueGrey.shade100,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _privacySetting == 'Public'
                                              ? Icons.public
                                              : Icons.lock,
                                          size: 16,
                                          color: Colors.blueGrey[700],
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          _privacySetting,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blueGrey[700],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.arrow_drop_down,
                                          size: 20,
                                          color: Colors.blueGrey,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.04,
                      ),
                      child: TextField(
                        controller: _captionController,
                        focusNode: _captionFocusNode,
                        maxLines: null,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: "What's happening?",
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_selectedMedia.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.04,
                          vertical: 15.0,
                        ),
                        child: Wrap(
                          spacing: 10.0,
                          runSpacing: 10.0,
                          children: List.generate(_selectedMedia.length, (
                            index,
                          ) {
                            final file = _selectedMedia[index];
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    file,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: -8,
                                  right: -8,
                                  child: GestureDetector(
                                    onTap: () => _removeMedia(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.black87,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.03,
                vertical: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: SvgPicture.asset(
                      'assets/icons/attach.svg',
                      width: 26,
                      height: 26,
                      colorFilter: const ColorFilter.mode(
                        Colors.black,
                        BlendMode.srcIn,
                      ),
                    ),
                    onPressed: _pickMedia,
                    tooltip: 'Add Photo',
                  ),
                  Text(
                    '${_captionCharacterCount}/2200',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                      fontFamily: 'Gilroy-Bold',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

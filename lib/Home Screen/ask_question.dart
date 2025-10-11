import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Data/dynamic_popup.dart';
import '../utils/firebase_notification_helper.dart';

class AskQuestionScreen extends StatefulWidget {
  const AskQuestionScreen({super.key});

  @override
  State<AskQuestionScreen> createState() => _AskQuestionScreenState();
}

class _AskQuestionScreenState extends State<AskQuestionScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _pollQuestionController = TextEditingController();
  final List<TextEditingController> _pollOptionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool _isAsking = false;
  bool _isPollActive = false;
  String _privacySetting = 'Public';
  String? userName;
  String? userProfileUrl;
  String? userRole;
  String? userId;
  String? userEmail;
  String? userHeadUid;

  final FocusNode _questionFocusNode = FocusNode();
  final List<FocusNode> _pollOptionFocusNodes = [FocusNode(), FocusNode()];
  final FocusNode _pollQuestionFocusNode = FocusNode();

  late AnimationController _animationController;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_questionFocusNode);
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
  }

  @override
  void dispose() {
    _questionController.dispose();
    _questionFocusNode.dispose();
    _pollQuestionController.dispose();
    _pollQuestionFocusNode.dispose();
    for (var controller in _pollOptionControllers) {
      controller.dispose();
    }
    for (var focusNode in _pollOptionFocusNodes) {
      focusNode.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        userName = 'User';
        userRole = 'Student';
      });
      return;
    }

    final isHead = prefs.getBool('isHead') ?? false;
    final isFaculty = prefs.getBool('isFaculty') ?? false;
    final isStudent = prefs.getBool('isStudent') ?? false;

    String collectionName = '';
    if (isHead) {
      collectionName = 'Heads';
      userRole = 'Head';
    } else if (isFaculty) {
      collectionName = 'Faculties';
      userRole = 'Faculty';
    } else if (isStudent) {
      collectionName = 'Students';
      userRole = 'Student';
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
          userEmail = data['email'] ?? '';
          userName = data['fullName'] ?? '';
          userProfileUrl = data['profilePictureUrl'] ?? '';
          // 🔹 Fetch headUid directly from the user's document
          userHeadUid = data['headUid'];
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to fetch user data: $e');
    }
  }

  void _addPollOption() {
    if (_pollOptionControllers.length < 4) {
      setState(() {
        _pollOptionControllers.add(TextEditingController());
        _pollOptionFocusNodes.add(FocusNode());
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_pollOptionFocusNodes.last);
      });
    } else {
      CustomPopup.show(context, "You can add a maximum of 4 options.");
    }
  }

  void _removePollOption(int index) {
    if (_pollOptionControllers.length > 2) {
      setState(() {
        _pollOptionControllers[index].dispose();
        _pollOptionFocusNodes[index].dispose();
        _pollOptionControllers.removeAt(index);
        _pollOptionFocusNodes.removeAt(index);
      });
    } else {
      CustomPopup.show(context, "You need at least 2 options for a poll.");
    }
  }

  void _togglePollActive() {
    setState(() {
      _isPollActive = !_isPollActive;
      if (_isPollActive) {
        _questionController.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FocusScope.of(context).requestFocus(_pollQuestionFocusNode);
        });
      } else {
        _pollQuestionController.clear();
        for (var controller in _pollOptionControllers) {
          controller.clear();
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FocusScope.of(context).requestFocus(_questionFocusNode);
        });
      }
    });
  }

  void _askQuestionOrPoll() async {
    if (userId == null) {
      CustomPopup.show(context, "User not logged in.");
      return;
    }

    setState(() {
      _isAsking = true;
    });

    try {
      final newPostDoc = await FirebaseFirestore.instance
          .collection('posts')
          .add({
            'userId': userId,
            'userName': userName,
            'userProfileUrl': userProfileUrl,
            'userRole': userRole,
            'caption':
                _isPollActive
                    ? _pollQuestionController.text.trim()
                    : _questionController.text.trim(),
            'timestamp': FieldValue.serverTimestamp(),
            'privacySetting': _privacySetting,
            'isQuestion': true,
            'isPoll': _isPollActive,
            'answersCount': 0,
            'mediaUrls': [],
            'mediaTypes': [],
            'likesCount': 0,
            'likedBy': [],
            'commentsCount': 0,
            'savedBy': [],
            if (_isPollActive) ...{
              'pollOptions':
                  _pollOptionControllers
                      .map(
                        (controller) => {
                          'text': controller.text.trim(),
                          'votes': 0,
                        },
                      )
                      .toList(),
              'votedBy': <String, int>{},
            },
          });

      List<String> recipientUids = [];
      String notificationTitle = '';
      String notificationMessage = '';
      String postContentPreview =
          (_isPollActive
                  ? _pollQuestionController.text
                  : _questionController.text)
              .trim();
      postContentPreview =
          postContentPreview.length > 50
              ? postContentPreview.substring(0, 50)
              : postContentPreview;

      // 🔹 Updated logic to send notifications based on user role and UIDs
      if (userRole == 'Head' && userId != null) {
        notificationTitle = 'New Question/Poll from ${userName ?? 'Head'}';
        notificationMessage =
            '${userName ?? 'A Head'} has posted a new question/poll: "$postContentPreview..."';

        // Fetch all Faculty and Students associated with this Head
        final facultySnapshot =
            await FirebaseFirestore.instance
                .collection('Faculties')
                .where('headUid', isEqualTo: userId)
                .get();
        final studentSnapshot =
            await FirebaseFirestore.instance
                .collection('Students')
                .where('headUid', isEqualTo: userId)
                .get();

        for (var doc in facultySnapshot.docs) {
          final fcmToken = doc.data()['fcmToken'];
          if (fcmToken != null && fcmToken.toString().isNotEmpty) {
            FirebaseNotificationHelper.sendNotificationFromApp(
              fcmToken: fcmToken.toString(),
              title: notificationTitle,
              body: notificationMessage,
            );
          }
          recipientUids.add(doc.id);
        }
        for (var doc in studentSnapshot.docs) {
          final fcmToken = doc.data()['fcmToken'];
          if (fcmToken != null && fcmToken.toString().isNotEmpty) {
            FirebaseNotificationHelper.sendNotificationFromApp(
              fcmToken: fcmToken.toString(),
              title: notificationTitle,
              body: notificationMessage,
            );
          }
          recipientUids.add(doc.id);
        }
      } else if (userRole == 'Faculty' &&
          userId != null &&
          userHeadUid != null) {
        notificationTitle = 'New Question/Poll from ${userName ?? 'Faculty'}';
        notificationMessage =
            '${userName ?? 'A Faculty'} has posted a new question/poll: "$postContentPreview..."';

        // Fetch the Head of this Faculty
        final headDoc =
            await FirebaseFirestore.instance
                .collection('Heads')
                .doc(userHeadUid)
                .get();
        if (headDoc.exists) {
          final fcmToken = headDoc.data()?['fcmToken'];
          if (fcmToken != null && fcmToken.toString().isNotEmpty) {
            FirebaseNotificationHelper.sendNotificationFromApp(
              fcmToken: fcmToken.toString(),
              title: notificationTitle,
              body: notificationMessage,
            );
          }
          recipientUids.add(headDoc.id);
        }

        // Fetch all Students of this Head
        final studentSnapshot =
            await FirebaseFirestore.instance
                .collection('Students')
                .where('headUid', isEqualTo: userHeadUid)
                .get();
        for (var doc in studentSnapshot.docs) {
          final fcmToken = doc.data()['fcmToken'];
          if (fcmToken != null && fcmToken.toString().isNotEmpty) {
            FirebaseNotificationHelper.sendNotificationFromApp(
              fcmToken: fcmToken.toString(),
              title: notificationTitle,
              body: notificationMessage,
            );
          }
          recipientUids.add(doc.id);
        }
      }

      for (String recipientUid in recipientUids) {
        if (recipientUid != userId && recipientUid.isNotEmpty) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'recipientId': recipientUid,
            'senderId': userId,
            'senderName': userName,
            'userProfileUrl': userProfileUrl,
            'title': notificationTitle,
            'message': notificationMessage,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'type': 'newQuestion',
            'targetId': newPostDoc.id,
            'targetType': 'post',
          });
        }
      }

      if (mounted) {
        setState(() {
          _isAsking = false;
          _questionController.clear();
          _pollQuestionController.clear();
          for (var controller in _pollOptionControllers) {
            controller.clear();
          }
          _isPollActive = false;
        });
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAsking = false;
        });
        CustomPopup.show(context, "Failed to post: $e");
      }
    }
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
                  'Who can see this ${_isPollActive ? 'poll' : 'question'}?',
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
                  'Only you can see this ${_isPollActive ? 'poll' : 'question'}',
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
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black),
                          onPressed: () {
                            FocusScope.of(context).unfocus();
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 1),
                        child: TextButton(
                          onPressed: _isAsking ? null : _askQuestionOrPoll,
                          style: TextButton.styleFrom(
                            backgroundColor:
                                _isAsking ? Colors.grey : Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            minimumSize: const Size(0, 0),
                          ),
                          child:
                              _isAsking
                                  ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.0,
                                      color: Colors.white,
                                    ),
                                  )
                                  : Text(
                                    _isPollActive ? "Post Poll" : "Ask",
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
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
                              userProfileUrl == null || userProfileUrl!.isEmpty
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
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.04,
                      ),
                      child:
                          _isPollActive
                              ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    controller: _pollQuestionController,
                                    focusNode: _pollQuestionFocusNode,
                                    maxLines: null,
                                    minLines: 1,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: "Your poll question?",
                                      hintStyle: TextStyle(
                                        color: Colors.grey[500],
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  Expanded(
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      physics: const ClampingScrollPhysics(),
                                      itemCount: _pollOptionControllers.length,
                                      itemBuilder: (context, index) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10.0,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  controller:
                                                      _pollOptionControllers[index],
                                                  focusNode:
                                                      _pollOptionFocusNodes[index],
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        "Option ${index + 1}",
                                                    filled: true,
                                                    fillColor: Colors.grey[50],
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      borderSide:
                                                          BorderSide.none,
                                                    ),
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          borderSide: BorderSide(
                                                            color:
                                                                Colors
                                                                    .grey
                                                                    .shade200,
                                                            width: 1,
                                                          ),
                                                        ),
                                                    focusedBorder: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      borderSide:
                                                          const BorderSide(
                                                            color:
                                                                Colors
                                                                    .blueAccent,
                                                            width: 1.5,
                                                          ),
                                                    ),
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                          vertical: 12,
                                                        ),
                                                    hintStyle: TextStyle(
                                                      color: Colors.grey[400],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              if (_pollOptionControllers
                                                      .length >
                                                  2)
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.remove_circle_outline,
                                                    color: Colors.redAccent,
                                                  ),
                                                  onPressed:
                                                      () => _removePollOption(
                                                        index,
                                                      ),
                                                ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  if (_pollOptionControllers.length < 4)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: _addPollOption,
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                          color: Colors.blueAccent,
                                        ),
                                        label: const Text(
                                          "Add Option",
                                          style: TextStyle(
                                            color: Colors.blueAccent,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              )
                              : TextField(
                                controller: _questionController,
                                focusNode: _questionFocusNode,
                                maxLines: null,
                                expands: true,
                                textAlignVertical: TextAlignVertical.top,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  hintText: "What question do you have?",
                                  hintStyle: TextStyle(color: Colors.grey[500]),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.03,
                vertical: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      _isPollActive ? Icons.text_fields : Icons.poll,
                      color: Colors.black,
                      size: 26,
                    ),
                    onPressed: _togglePollActive,
                    tooltip:
                        _isPollActive
                            ? 'Switch to Text Question'
                            : 'Create Poll',
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

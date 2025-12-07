import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:madarsaconnect/Home%20Screen/upload_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../Data/dynamic_popup.dart';
import '../Data/loader.dart';
import '../Data/main_page.dart';
import '../l10n/app_localizations.dart';

class UserCache {
  static final UserCache _instance = UserCache._internal();
  factory UserCache() => _instance;
  UserCache._internal();
  final Map<String, Map<String, dynamic>> _cache = {};

  Map<String, dynamic>? get(String userId) {
    return _cache[userId];
  }

  void set(String userId, Map<String, dynamic> userData) {
    _cache[userId] = userData;
  }

  bool contains(String userId) {
    return _cache.containsKey(userId);
  }
}

String getMonthAbbreviation(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  if (month >= 1 && month <= 12) {
    return months[month - 1];
  }
  return '';
}

Future<Map<String, dynamic>> fetchUserData(String userId) async {
  final userCache = UserCache();
  if (userCache.contains(userId)) {
    return userCache.get(userId)!;
  }

  try {
    DocumentSnapshot userDoc;
    const collections = ['Heads', 'Faculties', 'Students'];
    for (final collection in collections) {
      userDoc =
          await FirebaseFirestore.instance
              .collection(collection)
              .doc(userId)
              .get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        userCache.set(userId, data);
        return data;
      }
    }
  } catch (e) {
    debugPrint('Error fetching user data for ID $userId: $e');
  }

  final defaultData = {'fullName': 'Unknown User', 'profilePictureUrl': ''};
  userCache.set(userId, defaultData);
  return defaultData;
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with AutomaticKeepAliveClientMixin<FeedScreen> {
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  @override
  bool get wantKeepAlive => true;

  Future<void> _refreshPosts() async {
    if (mounted) {
      setState(() {});
    }
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentUserId = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child:
            !context.read<ProfileProvider>().isRoleLoaded
                ? const Center(child: GradientSpinner())
                : RefreshIndicator(
                  key: _refreshIndicatorKey,
                  onRefresh: _refreshPosts,
                  color: Colors.redAccent,
                  backgroundColor: Colors.white,
                  child: CustomScrollView(
                    slivers: [
                      SliverAppBar(
                        backgroundColor: Colors.white,
                        surfaceTintColor: Colors.transparent,
                        automaticallyImplyLeading: false,
                        elevation: 0,
                        floating: true,
                        snap: true,
                        centerTitle: false,
                        title: Text(
                          AppLocalizations.of(context)!.feedTitle,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                        actions: [
                          const SizedBox(width: 8),
                          Consumer<ProfileProvider>(
                            builder: (context, profileProvider, child) {
                              final currentUserProfileUrl =
                                  profileProvider.profileUrl;
                              return GestureDetector(
                                onTap: () {
                                  if (currentUserId != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => UserProfileScreen(
                                              userId: currentUserId,
                                            ),
                                      ),
                                    );
                                  }
                                },
                                child: CircleAvatar(
                                  radius: 15,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage:
                                      currentUserProfileUrl != null &&
                                              currentUserProfileUrl.isNotEmpty
                                          ? NetworkImage(currentUserProfileUrl)
                                          : null,
                                  child:
                                      currentUserProfileUrl == null ||
                                              currentUserProfileUrl.isEmpty
                                          ? SvgPicture.asset(
                                            'assets/icons/users.svg',
                                            width: 24,
                                            height: 24,
                                            colorFilter: const ColorFilter.mode(
                                              Colors.black,
                                              BlendMode.srcIn,
                                            ),
                                          )
                                          : null,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 15),
                        ],
                      ),
                      SliverToBoxAdapter(
                        child: Consumer<UploadProvider>(
                          builder: (context, uploadProvider, child) {
                            if (uploadProvider.isUploading) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                color: Colors.white,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      uploadProvider.uploadStatus,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: uploadProvider.uploadProgress,
                                      backgroundColor: Colors.grey[300],
                                      color: Colors.redAccent,
                                      minHeight: 6,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              return const SizedBox.shrink();
                            }
                          },
                        ),
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream:
                            _firestore
                                .collection('posts')
                                .where('privacySetting', isEqualTo: 'Public')
                                .orderBy('timestamp', descending: true)
                                .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => const _PostShimmer(),
                                childCount: 5,
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return SliverFillRemaining(
                              child: Center(
                                child: Text(
                                  '${AppLocalizations.of(context)!.error}: ${snapshot.error}',
                                ),
                              ),
                            );
                          }
                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return const SliverFillRemaining(
                              child: Center(child: Text('No posts yet.')),
                            );
                          }

                          final posts = snapshot.data!.docs;

                          return SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final postData =
                                  posts[index].data() as Map<String, dynamic>;
                              final postId = posts[index].id;
                              final profileProvider =
                                  context.read<ProfileProvider>();
                              return _FeedPost(
                                key: ValueKey(postId),
                                postId: postId,
                                postData: postData,
                                currentUserId: currentUserId,
                                currentUserName: profileProvider.userName,
                                currentUserProfileUrl:
                                    profileProvider.profileUrl,
                              );
                            }, childCount: posts.length),
                          );
                        },
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}

class _PostShimmer extends StatelessWidget {
  const _PostShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(radius: 24),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 16, width: 150, color: Colors.white),
                    const SizedBox(height: 4),
                    Container(height: 12, width: 100, color: Colors.white),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 14, width: double.infinity, color: Colors.white),
            const SizedBox(height: 6),
            Container(height: 14, width: double.infinity, color: Colors.white),
            const SizedBox(height: 6),
            Container(height: 14, width: 200, color: Colors.white),
            const SizedBox(height: 16),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedPost extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;
  final String? currentUserId;
  final String? currentUserName;
  final String? currentUserProfileUrl;
  final bool isFromUserProfile;
  final String? profileViewUserId;

  const _FeedPost({
    super.key,
    required this.postId,
    required this.postData,
    this.currentUserId,
    this.currentUserName,
    this.currentUserProfileUrl,
    this.isFromUserProfile = false,
    this.profileViewUserId,
  });

  @override
  State<_FeedPost> createState() => _FeedPostState();
}

class _FeedPostState extends State<_FeedPost>
    with AutomaticKeepAliveClientMixin {
  bool _showFullText = false;
  final int _maxLines = 3;
  late int _likesCount;
  late List<String> _likedBy;
  late int _commentsCount;
  late List<String> _savedBy;
  StreamSubscription<DocumentSnapshot>? _pollSubscription;
  late List<Map<String, dynamic>> _pollOptions;
  late Map<String, int> _votedBy;
  late int _answersCount;
  late DateTime? _pollCreationTime;
  Timer? _pollExpiryTimer;

  late Future<Map<String, dynamic>> _authorDataFuture;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _updateStateFromWidget();

    _authorDataFuture = fetchUserData(widget.postData['userId'] ?? '');

    if (widget.postData['isPoll'] ?? false) {
      _startPollListener();
      _startPollExpiryTimer();
    }
  }

  void _updateStateFromWidget() {
    final postData = widget.postData;
    _likesCount = postData['likesCount'] ?? 0;
    _likedBy = List<String>.from(postData['likedBy'] ?? []);
    _commentsCount = postData['commentsCount'] ?? 0;
    _savedBy = List<String>.from(postData['savedBy'] ?? []);
    _pollOptions = List<Map<String, dynamic>>.from(
      postData['pollOptions'] ?? [],
    );

    final votedByRaw = postData['votedBy'];
    _votedBy =
        (votedByRaw is Map)
            ? Map<String, int>.from(
              votedByRaw.map((k, v) => MapEntry(k.toString(), v as int)),
            )
            : {};

    _answersCount = postData['answersCount'] ?? 0;
    _pollCreationTime = (postData['timestamp'] as Timestamp?)?.toDate();
  }

  @override
  void didUpdateWidget(covariant _FeedPost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.postData != oldWidget.postData) {
      if (mounted) {
        setState(() {
          _updateStateFromWidget();
        });
      }
    }

    if (widget.postId != oldWidget.postId ||
        widget.postData['isPoll'] != oldWidget.postData['isPoll']) {
      _pollSubscription?.cancel();
      _pollExpiryTimer?.cancel();
      if (widget.postData['isPoll'] ?? false) {
        _startPollListener();
        _startPollExpiryTimer();
      }
    }
  }

  void _startPollListener() {
    _pollSubscription = _firestore
        .collection('posts')
        .doc(widget.postId)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists && snapshot.data() != null && mounted) {
              final data = snapshot.data()!;
              setState(() {
                _pollOptions = List<Map<String, dynamic>>.from(
                  data['pollOptions'] ?? [],
                );
                final votedByRaw = data['votedBy'];
                _votedBy =
                    (votedByRaw is Map)
                        ? Map<String, int>.from(
                          votedByRaw.map(
                            (k, v) => MapEntry(k.toString(), v as int),
                          ),
                        )
                        : {};
              });
            }
          },
          onError: (error) {
            debugPrint("Poll listener error: $error");
          },
        );
  }

  void _startPollExpiryTimer() {
    if (_pollCreationTime == null) return;
    final timeUntilExpiry = _pollCreationTime!
        .add(const Duration(hours: 24))
        .difference(DateTime.now());
    if (timeUntilExpiry.isNegative) {
      if (mounted) setState(() {});
      return;
    }
    _pollExpiryTimer = Timer(timeUntilExpiry, () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pollSubscription?.cancel();
    _pollExpiryTimer?.cancel();
    super.dispose();
  }

  void _toggleLike() async {
    if (widget.currentUserId == null) {
      CustomPopup.show(context, AppLocalizations.of(context)!.loginToLike);
      return;
    }

    final postRef = _firestore.collection('posts').doc(widget.postId);
    final bool hasLiked = _likedBy.contains(widget.currentUserId);

    if (mounted) {
      setState(() {
        if (hasLiked) {
          _likesCount--;
          _likedBy.remove(widget.currentUserId);
        } else {
          _likesCount++;
          _likedBy.add(widget.currentUserId!);
        }
      });
    }

    try {
      if (hasLiked) {
        await postRef.update({
          'likesCount': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([widget.currentUserId]),
        });
      } else {
        await postRef.update({
          'likesCount': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([widget.currentUserId]),
        });
      }
    } catch (e) {
      debugPrint("Failed to update like status: $e");
      if (mounted) {
        setState(() {
          if (hasLiked) {
            _likesCount++;
            _likedBy.add(widget.currentUserId!);
          } else {
            _likesCount--;
            _likedBy.remove(widget.currentUserId);
          }
        });
        CustomPopup.show(context, "Failed to update like status.");
      }
    }
  }

  void _toggleSave() async {
    if (widget.currentUserId == null) {
      CustomPopup.show(context, AppLocalizations.of(context)!.loginToSave);
      return;
    }

    final bool hasSaved = _savedBy.contains(widget.currentUserId);

    if (mounted) {
      setState(() {
        if (hasSaved) {
          _savedBy.remove(widget.currentUserId);
        } else {
          _savedBy.add(widget.currentUserId!);
        }
      });
    }

    try {
      if (hasSaved) {
        await _firestore.collection('posts').doc(widget.postId).update({
          'savedBy': FieldValue.arrayRemove([widget.currentUserId]),
        });
      } else {
        await _firestore.collection('posts').doc(widget.postId).update({
          'savedBy': FieldValue.arrayUnion([widget.currentUserId]),
        });
      }
      if (mounted) {
        CustomPopup.show(
          context,
          hasSaved
              ? AppLocalizations.of(context)!.postUnsaved
              : AppLocalizations.of(context)!.postSaved,
        );
      }
    } catch (e) {
      debugPrint("Failed to update save status: $e");
      if (mounted) {
        setState(() {
          if (hasSaved) {
            _savedBy.add(widget.currentUserId!);
          } else {
            _savedBy.remove(widget.currentUserId);
          }
        });
        CustomPopup.show(context, "Failed to update save status.");
      }
    }
  }

  void _showCommentsOrAnswers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 15),
                Container(
                  height: 2,
                  width: 45,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    (widget.postData['isQuestion'] ?? false)
                        ? AppLocalizations.of(context)!.answers
                        : AppLocalizations.of(context)!.comments,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: CommentsScreen(
                    postId: widget.postId,
                    scrollController: controller,
                    currentUserId: widget.currentUserId,
                    currentUserName: widget.currentUserName,
                    currentUserProfileUrl: widget.currentUserProfileUrl,
                    isQuestionOrPoll: widget.postData['isQuestion'] ?? false,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deletePost() async {
    final postUserId = widget.postData['userId'] ?? '';
    if (widget.currentUserId == null || widget.currentUserId != postUserId) {
      return;
    }

    final bool confirmDelete =
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 25),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 22,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.redAccent,
                      size: 42,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      AppLocalizations.of(context)!.deletePost,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppLocalizations.of(context)!.deletePostConfirmation,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            backgroundColor: Colors.grey[200],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(
                            AppLocalizations.of(context)!.cancel,
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(
                            AppLocalizations.of(context)!.delete,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ) ??
        false;

    if (!confirmDelete) return;

    try {
      if (!(widget.postData['isQuestion'] ?? false) &&
          !(widget.postData['isPoll'] ?? false)) {
        for (String url in List<String>.from(
          widget.postData['mediaUrls'] ?? [],
        )) {
          try {
            await _storage.refFromURL(url).delete();
          } catch (e) {
            debugPrint("Could not delete media at $url: $e");
          }
        }
      }

      final commentsSnapshot =
          await _firestore
              .collection('posts')
              .doc(widget.postId)
              .collection('comments')
              .get();
      final WriteBatch batch = _firestore.batch();
      for (QueryDocumentSnapshot doc in commentsSnapshot.docs) {
        final repliesSnapshot = await doc.reference.collection('replies').get();
        for (QueryDocumentSnapshot replyDoc in repliesSnapshot.docs) {
          batch.delete(replyDoc.reference);
        }
        batch.delete(doc.reference);
      }
      await batch.commit();

      await _firestore.collection('posts').doc(widget.postId).delete();
      if (mounted) CustomPopup.show(context, "Post deleted successfully!");
    } catch (e) {
      debugPrint("Failed to delete post: $e");
      if (mounted) CustomPopup.show(context, "Failed to delete post.");
    }
  }

  void _updatePostText(
    String initialText,
    bool isPoll,
    List<Map<String, dynamic>> initialPollOptions,
  ) async {
    final postUserId = widget.postData['userId'] ?? '';
    if (widget.currentUserId == null || widget.currentUserId != postUserId) {
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => _UpdatePostTextScreen(
              initialText: initialText,
              isPoll: isPoll,
              initialPollOptions: initialPollOptions,
            ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      final updatedCaption = result['caption'] as String?;
      final updatedPollOptions =
          result['pollOptions'] as List<Map<String, dynamic>>?;

      if (updatedCaption != null && updatedCaption.trim().isNotEmpty) {
        try {
          Map<String, dynamic> updateData = {'caption': updatedCaption.trim()};
          if (isPoll && updatedPollOptions != null) {
            updateData['pollOptions'] = updatedPollOptions;
          }
          await _firestore
              .collection('posts')
              .doc(widget.postId)
              .update(updateData);
        } catch (e) {
          if (mounted) CustomPopup.show(context, "Failed to update post: $e");
        }
      } else if (updatedCaption != null && updatedCaption.trim().isEmpty) {
        if (mounted) {
          CustomPopup.show(
            context,
            AppLocalizations.of(context)!.postTextCannotBeEmpty,
          );
        }
      }
    }
  }

  void _showPostOptions() {
    final postUserId = widget.postData['userId'] ?? '';
    if (widget.currentUserId == null || widget.currentUserId != postUserId) {
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 15),
              Container(
                height: 2,
                width: 45,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              const SizedBox(height: 5),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.black87),
                title: Text(
                  AppLocalizations.of(context)!.updatePost,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _updatePostText(
                    widget.postData['caption'] ?? '',
                    widget.postData['isPoll'] ?? false,
                    List<Map<String, dynamic>>.from(
                      widget.postData['pollOptions'] ?? [],
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(
                  AppLocalizations.of(context)!.deletePost,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deletePost();
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _viewMediaFullScreen(String mediaUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaViewerScreen(mediaUrl: mediaUrl),
      ),
    );
  }

  void _voteOnPoll(int selectedOptionIndex) async {
    if (widget.currentUserId == null) {
      CustomPopup.show(context, AppLocalizations.of(context)!.loginToVote);
      return;
    }

    final postRef = _firestore.collection('posts').doc(widget.postId);

    try {
      await _firestore.runTransaction((transaction) async {
        final docSnapshot = await transaction.get(postRef);
        if (!docSnapshot.exists) {
          throw Exception("Poll not found.");
        }

        List<Map<String, dynamic>> currentPollOptions =
            List<Map<String, dynamic>>.from(
              docSnapshot.data()?['pollOptions'] ?? [],
            );
        Map<String, int> currentVotedBy = {};
        final dynamic votedByRaw = docSnapshot.data()?['votedBy'];
        if (votedByRaw is Map) {
          currentVotedBy = Map<String, int>.from(
            votedByRaw.map((k, v) => MapEntry(k.toString(), v as int)),
          );
        }

        final String userId = widget.currentUserId!;
        final bool hasVoted = currentVotedBy.containsKey(userId);
        final int? oldVotedOptionIndex = currentVotedBy[userId];

        if (hasVoted && oldVotedOptionIndex == selectedOptionIndex) {
          return;
        }

        if (hasVoted && oldVotedOptionIndex != null) {
          if (oldVotedOptionIndex >= 0 &&
              oldVotedOptionIndex < currentPollOptions.length) {
            currentPollOptions[oldVotedOptionIndex]['votes'] =
                (currentPollOptions[oldVotedOptionIndex]['votes'] as int? ??
                    1) -
                1;
          }
        }

        if (selectedOptionIndex >= 0 &&
            selectedOptionIndex < currentPollOptions.length) {
          currentPollOptions[selectedOptionIndex]['votes'] =
              (currentPollOptions[selectedOptionIndex]['votes'] as int? ?? 0) +
              1;
        }

        currentVotedBy[userId] = selectedOptionIndex;

        transaction.update(postRef, {
          'pollOptions': currentPollOptions,
          'votedBy': currentVotedBy,
        });
      });
    } catch (e) {
      debugPrint("Failed to cast vote: $e");
      if (mounted) CustomPopup.show(context, "Failed to cast vote: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final postData = widget.postData;
    final String postText = postData['caption'] ?? '';
    final List<String> mediaUrls = List<String>.from(
      postData['mediaUrls'] ?? [],
    );
    final Timestamp? timestamp = postData['timestamp'] as Timestamp?;
    final String postUserId = postData['userId'] ?? '';
    final String privacySetting = postData['privacySetting'] ?? 'Private';
    final bool isQuestion = postData['isQuestion'] ?? false;
    final bool isPoll = postData['isPoll'] ?? false;

    String timeAgoString =
        (timestamp != null) ? timeago.format(timestamp.toDate()) : '';
    if (timestamp != null &&
        DateTime.now().difference(timestamp.toDate()).inDays > 0) {
      final postDateTime = timestamp.toDate();
      timeAgoString =
          '${postDateTime.day} ${getMonthAbbreviation(postDateTime.month)}';
    }

    final bool isLiked =
        widget.currentUserId != null && _likedBy.contains(widget.currentUserId);
    final bool isSaved =
        widget.currentUserId != null && _savedBy.contains(widget.currentUserId);
    final bool hasVoted =
        widget.currentUserId != null &&
        _votedBy.containsKey(widget.currentUserId);
    final bool isPollExpired =
        _pollCreationTime != null &&
        DateTime.now().difference(_pollCreationTime!).inHours >= 24;
    final bool canSeePollResults =
        hasVoted || (widget.currentUserId == postUserId) || isPollExpired;

    String? pollWinnerText;
    if (isPoll && isPollExpired) {
      int maxVotes = 0;
      for (var option in _pollOptions) {
        maxVotes =
            (option['votes'] as int? ?? 0) > maxVotes
                ? (option['votes'] as int? ?? 0)
                : maxVotes;
      }
      List<String> winners =
          _pollOptions
              .where(
                (opt) =>
                    (opt['votes'] as int? ?? 0) == maxVotes && maxVotes > 0,
              )
              .map((opt) => opt['text'] as String)
              .toList();

      if (winners.length == 1) {
        pollWinnerText = AppLocalizations.of(
          context,
        )!.pollWinner(winners.first);
      } else if (winners.length > 1) {
        pollWinnerText = AppLocalizations.of(
          context,
        )!.pollTie(winners.join(' and '));
      } else {
        pollWinnerText = AppLocalizations.of(context)!.noVotesCast;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FutureBuilder<Map<String, dynamic>>(
              future: _authorDataFuture,
              builder: (context, snapshot) {
                String displayName = AppLocalizations.of(context)!.loading;
                String displayAvatarUrl = '';

                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData) {
                  displayName = snapshot.data?['fullName'] ?? 'Unknown User';
                  displayAvatarUrl = snapshot.data?['profilePictureUrl'] ?? '';
                } else if (snapshot.hasError) {
                  displayName = AppLocalizations.of(context)!.error;
                }

                return Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (postUserId.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      UserProfileScreen(userId: postUserId),
                            ),
                          );
                        }
                      },
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey[200],
                        backgroundImage:
                            displayAvatarUrl.isNotEmpty
                                ? NetworkImage(displayAvatarUrl)
                                : null,
                        child:
                            displayAvatarUrl.isEmpty
                                ? SvgPicture.asset(
                                  'assets/icons/users.svg',
                                  width: 30,
                                  height: 30,
                                  colorFilter: const ColorFilter.mode(
                                    Colors.black,
                                    BlendMode.srcIn,
                                  ),
                                )
                                : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (postUserId.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        UserProfileScreen(userId: postUserId),
                              ),
                            );
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: Colors.black87,
                              ),
                            ),
                            Row(
                              children: [
                                if (privacySetting == 'Public') ...[
                                  Icon(
                                    Icons.public,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  timeAgoString,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.currentUserId == postUserId)
                      IconButton(
                        icon: Icon(Icons.more_horiz, color: Colors.grey[600]),
                        onPressed: _showPostOptions,
                      ),
                  ],
                );
              },
            ),
          ),
          if (postText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    postText,
                    style: const TextStyle(
                      fontSize: 15.5,
                      color: Colors.black87,
                    ),
                    maxLines: _showFullText ? null : _maxLines,
                    overflow:
                        _showFullText
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                  ),
                  if (!_showFullText && postText.length > (_maxLines * 50))
                    GestureDetector(
                      onTap: () {
                        if (mounted) setState(() => _showFullText = true);
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          AppLocalizations.of(context)!.seeMore,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (isPoll)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Column(
                children:
                    _pollOptions.asMap().entries.map((entry) {
                      int idx = entry.key;
                      Map<String, dynamic> option = entry.value;
                      int votes = option['votes'] as int? ?? 0;
                      int totalVotes = _pollOptions.fold(
                        0,
                        (sum, item) => sum + (item['votes'] as int? ?? 0),
                      );
                      double percentage =
                          totalVotes == 0 ? 0.0 : (votes / totalVotes) * 100;
                      bool isSelectedOption =
                          hasVoted && _votedBy[widget.currentUserId] == idx;

                      return GestureDetector(
                        onTap: isPollExpired ? null : () => _voteOnPoll(idx),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0,
                            end: canSeePollResults ? percentage : 0,
                          ),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                          builder: (context, animatedPercentage, child) {
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 5.0),
                              height: 50.0,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                  color:
                                      isSelectedOption
                                          ? Colors.redAccent
                                          : Colors.black,
                                  width: isSelectedOption ? 1.5 : 1.0,
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  if (canSeePollResults)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6.0),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 500,
                                        ),
                                        width:
                                            (MediaQuery.of(context).size.width -
                                                64) *
                                            (animatedPercentage / 100),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withOpacity(
                                            0.25,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            option['text'],
                                            style: const TextStyle(
                                              fontSize: 15.0,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                        if (canSeePollResults)
                                          Text(
                                            '($votes)',
                                            style: const TextStyle(
                                              fontSize: 14.0,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
              ),
            ),
          if (isPoll && isPollExpired && pollWinnerText != null)
            Padding(
              padding: const EdgeInsets.only(
                right: 16.0,
                top: 8.0,
                bottom: 8.0,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  pollWinnerText,
                  style: const TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          if (mediaUrls.isNotEmpty && !isQuestion)
            GestureDetector(
              onTap: () => _viewMediaFullScreen(mediaUrls.first),
              onDoubleTap: _toggleLike,
              child: ClipRRect(
                child: Image.network(
                  mediaUrls.first,
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.45,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: MediaQuery.of(context).size.height * 0.45,
                      color: Colors.grey[200],
                      child: Center(
                        child: CircularProgressIndicator(
                          value:
                              loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.redAccent,
                          ),
                          strokeWidth: 3.0,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: MediaQuery.of(context).size.height * 0.25,
                      color: Colors.grey[300],
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: Colors.grey[600],
                          size: 50,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          const SizedBox(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 13.0,
              vertical: 2.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _PostActionIcon(
                      svgPath: 'assets/icons/like.svg',
                      count: _likesCount,
                      isLiked: isLiked,
                      onTap: _toggleLike,
                    ),
                    const SizedBox(width: 15),
                    _PostActionIcon(
                      svgPath: 'assets/icons/comment.svg',
                      count: isQuestion ? _answersCount : _commentsCount,
                      onTap: _showCommentsOrAnswers,
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: isSaved ? Colors.redAccent : Colors.grey[700],
                    size: 26,
                  ),
                  onPressed: _toggleSave,
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
        ],
      ),
    );
  }
}

class _PostActionIcon extends StatelessWidget {
  final String svgPath;
  final int count;
  final bool isLiked;
  final VoidCallback onTap;

  const _PostActionIcon({
    required this.svgPath,
    required this.count,
    this.isLiked = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              svgPath,
              height: 23,
              width: 23,
              colorFilter: ColorFilter.mode(
                svgPath == 'assets/icons/like.svg' && isLiked
                    ? Colors.redAccent
                    : Colors.grey[700]!,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CommentsScreen extends StatefulWidget {
  final String postId;
  final ScrollController scrollController;
  final String? currentUserId;
  final String? currentUserName;
  final String? currentUserProfileUrl;
  final bool isQuestionOrPoll;

  const CommentsScreen({
    super.key,
    required this.postId,
    required this.scrollController,
    this.currentUserId,
    this.currentUserName,
    this.currentUserProfileUrl,
    this.isQuestionOrPoll = false,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _replyingToCommentId;
  String? _replyingToReplyId;
  String? _replyingToUserName;

  final Set<String> _expandedComments = {};

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _sendCommentOrReply() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || widget.currentUserId == null) return;

    _commentController.clear();
    _commentFocusNode.unfocus();

    final originalReplyingToCommentId = _replyingToCommentId;
    final originalReplyingToReplyId = _replyingToReplyId;
    final originalReplyingToUserName = _replyingToUserName;

    setState(() {
      _replyingToCommentId = null;
      _replyingToReplyId = null;
      _replyingToUserName = null;
    });

    try {
      final userDetails = await fetchUserData(widget.currentUserId!);
      final userName =
          userDetails['fullName'] ?? widget.currentUserName ?? "Unknown";
      final userProfileUrl =
          userDetails['profilePictureUrl'] ??
          widget.currentUserProfileUrl ??
          "";

      final Map<String, dynamic> data = {
        'userId': widget.currentUserId,
        'userName': userName,
        'userProfileUrl': userProfileUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'likedBy': [],
      };

      if (originalReplyingToCommentId != null) {
        String replyText = text;
        if (originalReplyingToUserName != null &&
            text.startsWith('@$originalReplyingToUserName')) {
          replyText =
              text.substring('@$originalReplyingToUserName'.length).trim();
        }
        data['replyText'] = replyText;

        if (originalReplyingToReplyId != null) {
          data['parentReplyId'] = originalReplyingToReplyId;
        }

        await _firestore
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .doc(originalReplyingToCommentId)
            .collection('replies')
            .add(data);
      } else {
        data['commentText'] = text;
        await _firestore
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .add(data);

        final fieldToIncrement =
            widget.isQuestionOrPoll ? 'answersCount' : 'commentsCount';
        await _firestore.collection('posts').doc(widget.postId).update({
          fieldToIncrement: FieldValue.increment(1),
        });
      }
    } catch (e) {
      debugPrint("Error sending comment/reply: $e");
      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.failedToSendMessage,
        );
      }
    }
  }

  void _toggleCommentLike(String commentId, List<String> currentLikedBy) {
    if (widget.currentUserId == null) {
      CustomPopup.show(
        context,
        AppLocalizations.of(context)!.loginToLikeComment,
      );
      return;
    }
    final commentRef = _firestore
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId);

    if (currentLikedBy.contains(widget.currentUserId)) {
      commentRef.update({
        'likesCount': FieldValue.increment(-1),
        'likedBy': FieldValue.arrayRemove([widget.currentUserId!]),
      });
    } else {
      commentRef.update({
        'likesCount': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([widget.currentUserId!]),
      });
    }
  }

  void _toggleReplyLike(
    String commentId,
    String replyId,
    List<String> currentLikedBy,
  ) {
    if (widget.currentUserId == null) {
      CustomPopup.show(context, AppLocalizations.of(context)!.loginToLikeReply);
      return;
    }
    final replyRef = _firestore
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId);

    if (currentLikedBy.contains(widget.currentUserId)) {
      replyRef.update({
        'likesCount': FieldValue.increment(-1),
        'likedBy': FieldValue.arrayRemove([widget.currentUserId!]),
      });
    } else {
      replyRef.update({
        'likesCount': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([widget.currentUserId!]),
      });
    }
  }

  void _startReplyTo(String commentId, String? replyId, String userName) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToReplyId = replyId;
      _replyingToUserName = userName;
      _commentController.text = '@$userName ';
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: _commentController.text.length),
      );
      _commentFocusNode.requestFocus();
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToReplyId = null;
      _replyingToUserName = null;
      _commentController.clear();
      _commentFocusNode.unfocus();
    });
  }

  Future<void> _deleteComment(String commentId, String commentUserId) async {
    if (widget.currentUserId != commentUserId) return;

    try {
      final writeBatch = _firestore.batch();
      final commentRef = _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId);
      final repliesSnapshot = await commentRef.collection('replies').get();

      for (final doc in repliesSnapshot.docs) {
        writeBatch.delete(doc.reference);
      }
      writeBatch.delete(commentRef);

      await writeBatch.commit();

      final fieldToDecrement =
          widget.isQuestionOrPoll ? 'answersCount' : 'commentsCount';
      await _firestore.collection('posts').doc(widget.postId).update({
        fieldToDecrement: FieldValue.increment(-1),
      });
    } catch (e) {
      debugPrint("Error deleting comment atomically: $e");
    }
  }

  Future<void> _deleteReply(
    String commentId,
    String replyId,
    String replyUserId,
  ) async {
    if (widget.currentUserId != replyUserId) return;
    try {
      await _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .doc(replyId)
          .delete();
    } catch (e) {
      debugPrint("Error deleting reply: $e");
      if (mounted) CustomPopup.show(context, "Failed to delete reply.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                _firestore
                    .collection('posts')
                    .doc(widget.postId)
                    .collection('comments')
                    .orderBy('timestamp', descending: false)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ListView.builder(
                  itemCount: 5,
                  itemBuilder: (_, __) => const _CommentShimmer(),
                );
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
                  child: Text(
                    widget.isQuestionOrPoll
                        ? AppLocalizations.of(context)!.beFirstToAnswer
                        : AppLocalizations.of(context)!.beFirstToComment,
                  ),
                );
              }

              final commentDocs = snapshot.data!.docs;
              return ListView.builder(
                controller: widget.scrollController,
                itemCount: commentDocs.length,
                itemBuilder: (context, index) {
                  final commentDoc = commentDocs[index];
                  final commentData = commentDoc.data() as Map<String, dynamic>;

                  return _CommentItem(
                    key: ValueKey(commentDoc.id),
                    postId: widget.postId,
                    commentId: commentDoc.id,
                    commentData: commentData,
                    currentUserId: widget.currentUserId,
                    onToggleLike: _toggleCommentLike,
                    onStartReply:
                        (userName) =>
                            _startReplyTo(commentDoc.id, null, userName),
                    onDelete: _deleteComment,
                    onToggleExpandReplies:
                        (id) => setState(() {
                          _expandedComments.contains(id)
                              ? _expandedComments.remove(id)
                              : _expandedComments.add(id);
                        }),
                    isCommentExpanded: _expandedComments.contains(
                      commentDoc.id,
                    ),
                    toggleReplyLike: _toggleReplyLike,
                    deleteReply: _deleteReply,
                    startReplyToReply: _startReplyTo,
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 16.0,
            bottom: 16.0 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_replyingToCommentId != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppLocalizations.of(
                            context,
                          )!.replyingTo(_replyingToUserName ?? 'User'),
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: _cancelReply,
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      decoration: InputDecoration(
                        hintText:
                            _replyingToCommentId != null
                                ? AppLocalizations.of(context)!.addReplyHint
                                : (widget.isQuestionOrPoll
                                    ? AppLocalizations.of(
                                      context,
                                    )!.addAnswerHint
                                    : AppLocalizations.of(
                                      context,
                                    )!.addCommentHint),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton(
                    onPressed: _sendCommentOrReply,
                    mini: true,
                    backgroundColor: Colors.redAccent,
                    elevation: 0,
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommentShimmer extends StatelessWidget {
  const _CommentShimmer();
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(radius: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 120, color: Colors.white),
                  const SizedBox(height: 6),
                  Container(
                    height: 12,
                    width: double.infinity,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 4),
                  Container(height: 12, width: 200, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentActionIcon extends StatelessWidget {
  final String svgPath;
  final int count;
  final bool isLiked;
  final VoidCallback onTap;
  const _CommentActionIcon({
    required this.svgPath,
    required this.count,
    this.isLiked = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              svgPath,
              height: 18,
              width: 18,
              colorFilter: ColorFilter.mode(
                svgPath == 'assets/icons/like.svg' && isLiked
                    ? Colors.redAccent
                    : Colors.grey[700]!,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentItem extends StatelessWidget {
  final String postId;
  final String commentId;
  final Map<String, dynamic> commentData;
  final String? currentUserId;
  final Function(String commentId, List<String> currentLikedBy) onToggleLike;
  final Function(String userName) onStartReply;
  final Function(String commentId, String commentUserId) onDelete;
  final Function(String commentId) onToggleExpandReplies;
  final bool isCommentExpanded;
  final Function(String commentId, String replyId, List<String> currentLikedBy)
  toggleReplyLike;
  final Function(String commentId, String replyId, String replyUserId)
  deleteReply;
  final Function(String commentId, String? replyId, String userName)
  startReplyToReply;

  const _CommentItem({
    super.key,
    required this.postId,
    required this.commentId,
    required this.commentData,
    this.currentUserId,
    required this.onToggleLike,
    required this.onStartReply,
    required this.onDelete,
    required this.onToggleExpandReplies,
    required this.isCommentExpanded,
    required this.toggleReplyLike,
    required this.deleteReply,
    required this.startReplyToReply,
  });

  void _showDeleteOptions(BuildContext context, String commentUserId) {
    if (currentUserId != commentUserId) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (bc) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 45,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.only(bottom: 10),
                ),
                Text(
                  AppLocalizations.of(context)!.commentOptions,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(bc);
                      onDelete(commentId, commentUserId);
                    },
                    icon: const Icon(
                      Icons.delete_forever,
                      color: Colors.redAccent,
                    ),
                    label: Text(
                      AppLocalizations.of(context)!.deleteComment,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(
                          color: Colors.redAccent,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(bc),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.cancel,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final String commentUserName = commentData['userName'] ?? 'Unknown';
    final String commentUserAvatarUrl = commentData['userProfileUrl'] ?? '';
    final String commentText = commentData['commentText'] ?? '';
    final String commentUserId = commentData['userId'] ?? '';
    final Timestamp? commentTimestamp = commentData['timestamp'] as Timestamp?;
    final int commentLikesCount = commentData['likesCount'] ?? 0;
    final List<String> commentLikedBy = List<String>.from(
      commentData['likedBy'] ?? [],
    );
    final bool isCommentLiked =
        currentUserId != null && commentLikedBy.contains(currentUserId);

    String timeAgoString = '';
    if (commentTimestamp != null) {
      final postTime = commentTimestamp.toDate();
      timeAgoString = timeago.format(postTime, locale: 'en_short');
      if (DateTime.now().difference(postTime).inDays > 0) {
        timeAgoString =
            '${postTime.day} ${getMonthAbbreviation(postTime.month)}';
      }
    }

    return GestureDetector(
      onLongPress: () => _showDeleteOptions(context, commentUserId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<Map<String, dynamic>>(
                  future: fetchUserData(commentUserId),
                  builder: (context, snapshot) {
                    final avatarUrl =
                        snapshot.data?['profilePictureUrl'] ??
                        commentUserAvatarUrl;
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => UserProfileScreen(userId: commentUserId),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.grey[200],
                        backgroundImage:
                            avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                        child:
                            avatarUrl.isEmpty
                                ? SvgPicture.asset(
                                  'assets/icons/users.svg',
                                  width: 20,
                                  height: 20,
                                )
                                : null,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          FutureBuilder<Map<String, dynamic>>(
                            future: fetchUserData(commentUserId),
                            builder: (context, snapshot) {
                              final displayName =
                                  snapshot.data?['fullName'] ?? commentUserName;
                              return Text(
                                displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeAgoString,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        commentText,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => onStartReply(commentUserName),
                        child: Text(
                          AppLocalizations.of(context)!.replyBtn,
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _CommentActionIcon(
                  svgPath: 'assets/icons/like.svg',
                  count: commentLikesCount,
                  isLiked: isCommentLiked,
                  onTap: () => onToggleLike(commentId, commentLikedBy),
                ),
              ],
            ),
            StreamBuilder<QuerySnapshot>(
              stream:
                  firestore
                      .collection('posts')
                      .doc(postId)
                      .collection('comments')
                      .doc(commentId)
                      .collection('replies')
                      .orderBy('timestamp', descending: false)
                      .snapshots(),
              builder: (context, replySnapshot) {
                if (!replySnapshot.hasData ||
                    replySnapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }
                final replyDocs = replySnapshot.data!.docs;
                final int replyCount = replyDocs.length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 50.0,
                        top: 4.0,
                        bottom: 4.0,
                      ),
                      child: GestureDetector(
                        onTap: () => onToggleExpandReplies(commentId),
                        child: Text(
                          isCommentExpanded
                              ? AppLocalizations.of(context)!.hideReplies
                              : (replyCount > 1
                                  ? AppLocalizations.of(
                                    context,
                                  )!.viewReplies(replyCount.toString())
                                  : AppLocalizations.of(
                                    context,
                                  )!.viewReply(replyCount.toString())),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    if (isCommentExpanded)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: replyCount,
                        itemBuilder: (context, replyIndex) {
                          final replyDoc = replyDocs[replyIndex];
                          final replyData =
                              replyDoc.data() as Map<String, dynamic>;
                          return _ReplyItem(
                            key: ValueKey(replyDoc.id),
                            commentId: commentId,
                            replyId: replyDoc.id,
                            replyData: replyData,
                            currentUserId: currentUserId,
                            onTapLike: toggleReplyLike,
                            onDelete: deleteReply,
                            onReply: startReplyToReply,
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyItem extends StatelessWidget {
  final String commentId;
  final String replyId;
  final Map<String, dynamic> replyData;
  final String? currentUserId;
  final Function(String commentId, String replyId, List<String> currentLikedBy)
  onTapLike;
  final Function(String commentId, String replyId, String replyUserId) onDelete;
  final Function(String commentId, String? replyId, String userName) onReply;

  const _ReplyItem({
    super.key,
    required this.commentId,
    required this.replyId,
    required this.replyData,
    this.currentUserId,
    required this.onTapLike,
    required this.onDelete,
    required this.onReply,
  });

  void _showDeleteOptions(BuildContext context, String replyUserId) {
    if (currentUserId != replyUserId) return;
  }

  @override
  Widget build(BuildContext context) {
    final String replyUserName = replyData['userName'] ?? 'Unknown';
    final String replyUserAvatarUrl = replyData['userProfileUrl'] ?? '';
    final String replyText = replyData['replyText'] ?? '';
    final String replyUserId = replyData['userId'] ?? '';
    final Timestamp? replyTimestamp = replyData['timestamp'] as Timestamp?;
    final int likesCount = replyData['likesCount'] ?? 0;
    final List<String> likedBy = List<String>.from(replyData['likedBy'] ?? []);
    final bool isLiked =
        currentUserId != null && likedBy.contains(currentUserId);

    String timeAgo = '';
    if (replyTimestamp != null) {
      final replyTime = replyTimestamp.toDate();
      timeAgo = timeago.format(replyTime, locale: 'en_short');
      if (DateTime.now().difference(replyTime).inDays > 0) {
        timeAgo = '${replyTime.day} ${getMonthAbbreviation(replyTime.month)}';
      }
    }

    return GestureDetector(
      onLongPress: () => _showDeleteOptions(context, replyUserId),
      child: Padding(
        padding: const EdgeInsets.only(left: 50.0, top: 4.0, bottom: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<Map<String, dynamic>>(
              future: fetchUserData(replyUserId),
              builder: (context, snapshot) {
                final avatarUrl =
                    snapshot.data?['profilePictureUrl'] ?? replyUserAvatarUrl;
                return CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.grey[200],
                  backgroundImage:
                      avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child:
                      avatarUrl.isEmpty
                          ? SvgPicture.asset(
                            'assets/icons/users.svg',
                            width: 16,
                            height: 16,
                          )
                          : null,
                );
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FutureBuilder<Map<String, dynamic>>(
                        future: fetchUserData(replyUserId),
                        builder: (context, snapshot) {
                          final displayName =
                              snapshot.data?['fullName'] ?? replyUserName;
                          return Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timeAgo,
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    replyText,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => onReply(commentId, replyId, replyUserName),
                    child: Text(
                      AppLocalizations.of(context)!.replyBtn,
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _CommentActionIcon(
              svgPath: 'assets/icons/like.svg',
              count: likesCount,
              isLiked: isLiked,
              onTap: () => onTapLike(commentId, replyId, likedBy),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdatePostTextScreen extends StatefulWidget {
  final String initialText;
  final bool isPoll;
  final List<Map<String, dynamic>> initialPollOptions;

  const _UpdatePostTextScreen({
    super.key,
    required this.initialText,
    this.isPoll = false,
    this.initialPollOptions = const [],
  });

  @override
  State<_UpdatePostTextScreen> createState() => _UpdatePostTextScreenState();
}

class _UpdatePostTextScreenState extends State<_UpdatePostTextScreen> {
  late TextEditingController _textController;
  List<TextEditingController> _pollOptionControllers = [];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
    if (widget.isPoll) {
      _pollOptionControllers =
          widget.initialPollOptions
              .map(
                (option) => TextEditingController(
                  text: option['text'] as String? ?? '',
                ),
              )
              .toList();
      if (_pollOptionControllers.isEmpty) {
        _pollOptionControllers.add(TextEditingController());
        _pollOptionControllers.add(TextEditingController());
      } else if (_pollOptionControllers.length == 1) {
        _pollOptionControllers.add(TextEditingController());
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    for (var controller in _pollOptionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          AppLocalizations.of(context)!.updatePost,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextButton(
              onPressed: () {
                final updatedCaption = _textController.text.trim();
                if (widget.isPoll) {
                  List<Map<String, dynamic>> updatedPollOptions = [];
                  for (int i = 0; i < _pollOptionControllers.length; i++) {
                    final newText = _pollOptionControllers[i].text.trim();
                    if (newText.isNotEmpty) {
                      int originalVotes = 0;
                      if (i < widget.initialPollOptions.length &&
                          widget.initialPollOptions[i]['text'] == newText) {
                        originalVotes =
                            widget.initialPollOptions[i]['votes'] as int? ?? 0;
                      }
                      updatedPollOptions.add({
                        'text': newText,
                        'votes': originalVotes,
                      });
                    }
                  }
                  if (updatedPollOptions.length < 2) {
                    CustomPopup.show(
                      context,
                      AppLocalizations.of(context)!.pollMustHaveOptions,
                    );
                    return;
                  }
                  Navigator.pop(context, {
                    'caption': updatedCaption,
                    'pollOptions': updatedPollOptions,
                  });
                } else {
                  Navigator.pop(context, {'caption': updatedCaption});
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 0),
              ),
              child: Text(
                AppLocalizations.of(context)!.updateBtn,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.15),
                    spreadRadius: 0,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  minLines: 5,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  decoration: InputDecoration(
                    hintText:
                        AppLocalizations.of(context)!.enterUpdatedTextHint,
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            if (widget.isPoll)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.15),
                        spreadRadius: 0,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.pollOptions,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _pollOptionControllers.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _pollOptionControllers[index],
                                      decoration: InputDecoration(
                                        hintText: AppLocalizations.of(
                                          context,
                                        )!.optionHint((index + 1).toString()),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8.0,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[100],
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                      ),
                                    ),
                                  ),
                                  if (_pollOptionControllers.length > 2)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _pollOptionControllers[index]
                                              .dispose();
                                          _pollOptionControllers.removeAt(
                                            index,
                                          );
                                        });
                                      },
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        if (_pollOptionControllers.length < 5)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _pollOptionControllers.add(
                                    TextEditingController(),
                                  );
                                });
                              },
                              icon: const Icon(
                                Icons.add,
                                color: Colors.blueAccent,
                              ),
                              label: Text(
                                AppLocalizations.of(context)!.addOption,
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                side: const BorderSide(
                                  color: Colors.blueAccent,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MediaViewerScreen extends StatefulWidget {
  final String mediaUrl;

  const MediaViewerScreen({super.key, required this.mediaUrl});

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            widget.mediaUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value:
                      loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Icon(Icons.broken_image, color: Colors.white, size: 80),
              );
            },
          ),
        ),
      ),
    );
  }
}

class UserProfileScreen extends StatefulWidget {
  final String? userId;
  const UserProfileScreen({super.key, this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  String? userName;
  String? userProfileUrl;
  String? userRole;
  String? userEmail;
  String? userBio;
  String? currentUserId;
  String? displayedUserId;
  String? currentUserNameForNotifications;
  String? currentUserProfileUrlForNotifications;
  bool _isLoading = true;

  int postCount = 0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    currentUserId = _auth.currentUser?.uid;

    final cached = prefs.getString('cachedProfile');
    if (cached != null) {
      final data = jsonDecode(cached) as Map<String, dynamic>;
      currentUserNameForNotifications = data['fullName'];
      currentUserProfileUrlForNotifications = data['profilePictureUrl'];
    }

    String? idToLookup = widget.userId;

    if (idToLookup == null) {
      idToLookup = currentUserId;
    }

    if (idToLookup == null) {
      CustomPopup.show(context, "No user ID to display profile.");
      setState(() {
        _isLoading = false;
      });
      return;
    }

    DocumentSnapshot? userDoc;
    String? fetchedRole;
    String? matchedUserIdForPosts;

    List<String> collectionNames = ['Heads', 'Faculties', 'Students'];

    for (var name in collectionNames) {
      userDoc = await _firestore.collection(name).doc(idToLookup).get();
      if (userDoc.exists) {
        fetchedRole =
            (userDoc.data() as Map<String, dynamic>?)?['role'] ?? 'User';
        break;
      }
    }

    if (userDoc != null && userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>;
      matchedUserIdForPosts = idToLookup;

      setState(() {
        userName = data['fullName'] ?? 'User';
        userProfileUrl = data['profilePictureUrl'];
        userRole = fetchedRole;
        userEmail = data['email'];
        userBio = data['bio'];
        displayedUserId = matchedUserIdForPosts;
      });

      if (displayedUserId != null) {
        await _fetchPostCount(displayedUserId!);
      }
    } else {
      QuerySnapshot headQuery =
          await _firestore
              .collection('Heads')
              .where('hucId', isEqualTo: idToLookup)
              .limit(1)
              .get();
      if (headQuery.docs.isNotEmpty) {
        userDoc = headQuery.docs.first;
        fetchedRole = 'Head';
        matchedUserIdForPosts = headQuery.docs.first['hucId'];
      }

      if (userDoc == null) {
        QuerySnapshot facultyQuery =
            await _firestore
                .collection('Faculties')
                .where('fucId', isEqualTo: idToLookup)
                .limit(1)
                .get();
        if (facultyQuery.docs.isNotEmpty) {
          userDoc = facultyQuery.docs.first;
          fetchedRole = 'Faculty';
          matchedUserIdForPosts = facultyQuery.docs.first['fucId'];
        }
      }

      if (userDoc == null) {
        QuerySnapshot studentQuery =
            await _firestore
                .collection('Students')
                .where('sucId', isEqualTo: idToLookup)
                .limit(1)
                .get();
        if (studentQuery.docs.isNotEmpty) {
          userDoc = studentQuery.docs.first;
          fetchedRole = 'Student';
          matchedUserIdForPosts = studentQuery.docs.first['sucId'];
        }
      }

      if (userDoc != null && userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          userName = data['fullName'] ?? 'User';
          userProfileUrl = data['profilePictureUrl'];
          userRole = fetchedRole;
          userEmail = data['email'];
          userBio = data['bio'];
          displayedUserId = matchedUserIdForPosts;
        });
        if (displayedUserId != null) {
          await _fetchPostCount(displayedUserId!);
        }
      } else {
        CustomPopup.show(
          context,
          "User data not found for ID: $idToLookup. Please check Firestore.",
        );
        setState(() {
          userName = AppLocalizations.of(context)!.userNotFound;
          userRole = 'N/A';
          userEmail = 'N/A';
          userBio = AppLocalizations.of(context)!.profileNotAvailable;
          displayedUserId = null;
        });
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchPostCount(String userId) async {
    final QuerySnapshot postSnapshot =
        await _firestore
            .collection('posts')
            .where('userId', isEqualTo: userId)
            .get();
    setState(() {
      postCount = postSnapshot.docs.length;
    });
  }

  String getMonthAbbreviation(int month) {
    switch (month) {
      case 1:
        return 'Jan';
      case 2:
        return 'Feb';
      case 3:
        return 'Mar';
      case 4:
        return 'Apr';
      case 5:
        return 'May';
      case 6:
        return 'Jun';
      case 7:
        return 'Jul';
      case 8:
        return 'Aug';
      case 9:
        return 'Sep';
      case 10:
        return 'Oct';
      case 11:
        return 'Nov';
      case 12:
        return 'Dec';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isCurrentUserProfile = (currentUserId == displayedUserId);

    return DefaultTabController(
      length: isCurrentUserProfile ? 2 : 1,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: Text(
            AppLocalizations.of(context)!.profile,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
        ),
        body:
            _isLoading
                ? const Center(child: GradientSpinner())
                : Column(
                  children: [
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 20.0,
                        horizontal: 16.0,
                      ),
                      child: Column(
                        children: [
                          Center(
                            child: CircleAvatar(
                              radius: 50,
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
                                        width: 60,
                                        height: 60,
                                      )
                                      : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            userName ?? 'User Name',
                            style: const TextStyle(
                              fontSize: 22,
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (isCurrentUserProfile)
                            Text(
                              userEmail ?? 'user@example.com',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          if (userBio != null && userBio!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                userBio!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey[700],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    TabBar(
                      indicatorColor: Colors.redAccent,
                      labelColor: Colors.redAccent,
                      unselectedLabelColor: Colors.grey,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                      tabs:
                          isCurrentUserProfile
                              ? [
                                Tab(
                                  text: AppLocalizations.of(context)!.myPosts,
                                ),
                                Tab(
                                  text:
                                      AppLocalizations.of(context)!.savedPosts,
                                ),
                              ]
                              : [
                                Tab(
                                  text: AppLocalizations.of(context)!.myPosts,
                                ),
                              ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          StreamBuilder<QuerySnapshot>(
                            stream:
                                _firestore
                                    .collection('posts')
                                    .where('userId', isEqualTo: displayedUserId)
                                    .orderBy('timestamp', descending: true)
                                    .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(child: GradientSpinner());
                              }
                              if (snapshot.hasError) {
                                return Center(
                                  child: Text(
                                    '${AppLocalizations.of(context)!.error}: ${snapshot.error}',
                                  ),
                                );
                              }
                              final userPosts =
                                  snapshot.data!.docs.where((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final privacySetting =
                                        data['privacySetting'] as String?;
                                    return (displayedUserId == currentUserId) ||
                                        (privacySetting == 'Public');
                                  }).toList();

                              if (userPosts.isEmpty) {
                                return Center(
                                  child: Text(
                                    displayedUserId == currentUserId
                                        ? AppLocalizations.of(
                                          context,
                                        )!.noPostsYetUser
                                        : AppLocalizations.of(
                                          context,
                                        )!.noPostsYetOther,
                                  ),
                                );
                              }
                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                itemCount: userPosts.length,
                                itemBuilder: (context, index) {
                                  final postData =
                                      userPosts[index].data()
                                          as Map<String, dynamic>;
                                  final postId = userPosts[index].id;
                                  final Timestamp? timestamp =
                                      postData['timestamp'] as Timestamp?;

                                  return _FeedPost(
                                    key: ValueKey(postId),
                                    postId: postId,
                                    postData: postData,
                                    currentUserId: currentUserId,
                                    currentUserName:
                                        currentUserNameForNotifications,
                                    currentUserProfileUrl:
                                        currentUserProfileUrlForNotifications,
                                    isFromUserProfile: true,
                                    profileViewUserId: displayedUserId,
                                  );
                                },
                              );
                            },
                          ),
                          if (isCurrentUserProfile)
                            StreamBuilder<QuerySnapshot>(
                              stream:
                                  _firestore
                                      .collection('posts')
                                      .where(
                                        'savedBy',
                                        arrayContains: displayedUserId,
                                      )
                                      .orderBy('timestamp', descending: true)
                                      .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(child: GradientSpinner());
                                }
                                if (snapshot.hasError) {
                                  return Center(
                                    child: Text(
                                      '${AppLocalizations.of(context)!.error}: ${snapshot.error}',
                                    ),
                                  );
                                }
                                final savedPosts =
                                    snapshot.data!.docs.where((doc) {
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      final privacySetting =
                                          data['privacySetting'] as String?;
                                      return (displayedUserId ==
                                              currentUserId) ||
                                          (privacySetting == 'Public');
                                    }).toList();

                                if (savedPosts.isEmpty) {
                                  return Center(
                                    child: Text(
                                      displayedUserId == currentUserId
                                          ? AppLocalizations.of(
                                            context,
                                          )!.noSavedPostsUser
                                          : AppLocalizations.of(
                                            context,
                                          )!.noSavedPostsOther,
                                    ),
                                  );
                                }
                                return ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  itemCount: savedPosts.length,
                                  itemBuilder: (context, index) {
                                    final postData =
                                        savedPosts[index].data()
                                            as Map<String, dynamic>;
                                    final postId = savedPosts[index].id;

                                    return _FeedPost(
                                      key: ValueKey(postId),
                                      postId: postId,
                                      postData: postData,
                                      currentUserId: currentUserId,
                                      currentUserName:
                                          currentUserNameForNotifications,
                                      currentUserProfileUrl:
                                          currentUserProfileUrlForNotifications,
                                      isFromUserProfile: true,
                                      profileViewUserId: displayedUserId,
                                    );
                                  },
                                );
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
}

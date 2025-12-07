import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Data/dynamic_popup.dart';
import '../Data/loader.dart';
import '../l10n/app_localizations.dart';
import 'feed_screen.dart';

enum NotificationType {
  newPost,
  like,
  comment,
  follow,
  generic,
  profileView,
  newQuiz,
  leaveRequest,
  newSession,
  newExam,
  studentPromotion,
  resultApproved,
  newTicket,
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  bool isRead;
  final IconData icon;
  final NotificationType type;
  final String? targetId;
  final String? targetType;
  final String? senderId;
  final String? senderName;
  final String? senderProfileUrl;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.icon = Icons.notifications_none,
    this.type = NotificationType.generic,
    this.targetId,
    this.targetType,
    this.senderId,
    required this.senderName,
    required this.senderProfileUrl,
  });
}

class NotifyScreen extends StatefulWidget {
  const NotifyScreen({super.key});

  @override
  State<NotifyScreen> createState() => _NotifyScreenState();
}

class _NotifyScreenState extends State<NotifyScreen> {
  String? _currentUserId;
  final List<NotificationItem> _notifications = [];
  bool _isInAppNotificationsEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId().then((_) {
      if (_currentUserId != null) {
        _checkInAppNotificationSettings();
      }
    });
  }

  Future<void> _loadCurrentUserId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("User not logged in. Cannot load user ID.");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }
    setState(() {
      _currentUserId = user.uid;
    });
  }

  Future<void> _checkInAppNotificationSettings() async {
    try {
      final settingsDoc =
          await FirebaseFirestore.instance
              .collection('notificationSettings')
              .doc(_currentUserId)
              .get();

      if (settingsDoc.exists) {
        final data = settingsDoc.data();
        if (data != null && data.containsKey('inApp')) {
          _isInAppNotificationsEnabled = data['inApp'];
        }
      }
    } catch (e) {
      debugPrint("Error fetching notification settings: $e");
    } finally {
      if (mounted) {
        setState(() {});
        if (_isInAppNotificationsEnabled) {
          _listenForNotifications();
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _listenForNotifications() {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: _currentUserId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() {
              _notifications.clear();
              for (var doc in snapshot.docs) {
                final data = doc.data();
                _notifications.add(
                  NotificationItem(
                    id: doc.id,
                    title: data['title'] ?? 'New Notification',
                    message: data['message'] ?? 'You have a new update.',
                    timestamp:
                        (data['timestamp'] as Timestamp?)?.toDate() ??
                        DateTime.now(),
                    isRead: data['isRead'] ?? false,
                    icon: _getIconForNotificationType(data['type']),
                    type: _getNotificationTypeFromString(data['type']),
                    targetId: data['targetId'],
                    targetType: data['targetType'],
                    senderId: data['senderId'],
                    senderName: data['senderName'] ?? '',
                    senderProfileUrl: data['senderProfileUrl'] ?? '',
                  ),
                );
              }
              _isLoading = false;
            });
          }
        });
  }

  IconData _getIconForNotificationType(String? type) {
    switch (type) {
      case 'newPost':
        return Icons.post_add;
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'follow':
        return Icons.person_add;
      case 'profileView':
        return Icons.person;
      case 'newQuiz':
        return Icons.assignment;
      case 'leaveRequest':
        return Icons.pending_actions;
      case 'newSession':
        return Icons.school;
      case 'newExam':
        return Icons.assignment;
      case 'studentPromotion':
        return Icons.school;
      case 'resultApproved':
        return Icons.assignment_turned_in;
      case 'newTicket':
        return Icons.support_agent;
      default:
        return Icons.notifications_none;
    }
  }

  NotificationType _getNotificationTypeFromString(String? typeString) {
    switch (typeString) {
      case 'newPost':
        return NotificationType.newPost;
      case 'like':
        return NotificationType.like;
      case 'comment':
        return NotificationType.comment;
      case 'follow':
        return NotificationType.follow;
      case 'profileView':
        return NotificationType.profileView;
      case 'newQuiz':
        return NotificationType.newQuiz;
      case 'leaveRequest':
        return NotificationType.leaveRequest;
      case 'newSession':
        return NotificationType.newSession;
      case 'newExam':
        return NotificationType.newExam;
      case 'studentPromotion':
        return NotificationType.studentPromotion;
      case 'resultApproved':
        return NotificationType.resultApproved;
      case 'newTicket':
        return NotificationType.newTicket;
      default:
        return NotificationType.generic;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 1) {
      return AppLocalizations.of(context)!.justNow;
    }
    if (difference.inHours < 1) {
      return AppLocalizations.of(
        context,
      )!.minutesAgo(difference.inMinutes.toString());
    }
    if (difference.inHours < 24) {
      return AppLocalizations.of(
        context,
      )!.hoursAgo(difference.inHours.toString());
    }
    if (difference.inDays < 7) {
      return AppLocalizations.of(
        context,
      )!.daysAgo(difference.inDays.toString());
    }
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  void _markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) _notifications[index].isRead = true;
      });
    } catch (e) {
      CustomPopup.show(
        context,
        '${AppLocalizations.of(context)!.failedToMarkRead}: $e',
      );
    }
  }

  void _handleNotificationTap(NotificationItem notification) {
    _markAsRead(notification.id);
    if (notification.type == NotificationType.newPost &&
        notification.senderId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => UserProfileScreen(userId: notification.senderId!),
        ),
      );
    } else if (notification.type == NotificationType.profileView &&
        notification.targetId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => UserProfileScreen(userId: notification.targetId!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double systemBottomPadding = MediaQuery.of(context).padding.bottom;
    const double bottomNavHeightInMainPage = 0;
    final double totalBottomInset =
        systemBottomPadding + bottomNavHeightInMainPage;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context)!.notificationsTitle,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: Colors.black54),
            tooltip: AppLocalizations.of(context)!.markAllRead,
            onPressed: () async {
              final batch = FirebaseFirestore.instance.batch();
              for (var n in _notifications.where((n) => !n.isRead)) {
                batch.update(
                  FirebaseFirestore.instance
                      .collection('notifications')
                      .doc(n.id),
                  {'isRead': true},
                );
              }
              await batch.commit();
              setState(() {
                for (var n in _notifications) {
                  n.isRead = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.black54),
            tooltip: AppLocalizations.of(context)!.clearAllNotifications,
            onPressed: () async {
              final batch = FirebaseFirestore.instance.batch();
              for (var n in _notifications) {
                batch.delete(
                  FirebaseFirestore.instance
                      .collection('notifications')
                      .doc(n.id),
                );
              }
              await batch.commit();
              setState(() => _notifications.clear());
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: GradientSpinner())
              : !_isInAppNotificationsEnabled
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.inAppNotificationsOff,
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    Text(
                      AppLocalizations.of(context)!.enableFromSettings,
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
              : _notifications.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.noNewNotifications,
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    Text(
                      AppLocalizations.of(context)!.checkBackLater,
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  16.0,
                  16.0,
                  16.0,
                  totalBottomInset,
                ),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final n = _notifications[index];
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.only(bottom: 12.0),
                    decoration: BoxDecoration(
                      color: n.isRead ? Colors.white : Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            n.isRead ? 0.04 : 0.08,
                          ),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      border: Border.all(
                        color:
                            n.isRead
                                ? Colors.grey.shade200
                                : Colors.indigo.shade100,
                        width: 0.8,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _handleNotificationTap(n),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!n.isRead)
                                Container(
                                  width: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.shade700,
                                    borderRadius: const BorderRadius.horizontal(
                                      left: Radius.circular(12),
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(width: 6),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        n.icon,
                                        color:
                                            n.isRead
                                                ? Colors.grey.shade600
                                                : Colors.indigo.shade700,
                                        size: 28,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              n.title,
                                              style: TextStyle(
                                                fontWeight:
                                                    n.isRead
                                                        ? FontWeight.w600
                                                        : FontWeight.bold,
                                                fontSize: 16,
                                                color:
                                                    n.isRead
                                                        ? Colors.grey.shade700
                                                        : Colors
                                                            .indigo
                                                            .shade900,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            if (n.type !=
                                                NotificationType.newPost)
                                              Text(
                                                n.message,
                                                style: TextStyle(
                                                  fontSize: 14.5,
                                                  color:
                                                      n.isRead
                                                          ? Colors.grey.shade500
                                                          : Colors
                                                              .grey
                                                              .shade800,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            if (n.type !=
                                                NotificationType.newPost)
                                              const SizedBox(height: 8),
                                            Text(
                                              _formatTimestamp(n.timestamp),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

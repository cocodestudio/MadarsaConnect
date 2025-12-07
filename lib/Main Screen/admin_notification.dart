import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:madarsaconnect/Main%20Screen/subscription_request.dart';
import '../Data/dynamic_popup.dart';
import '../Data/loader.dart';
import 'admin_screen.dart';

enum AdminNotificationType { newTicket, subscriptionRequest, generic }

class AdminNotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  bool isRead;
  final IconData icon;
  final AdminNotificationType type;
  final String? senderId;
  final String? senderName;

  AdminNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.icon = Icons.notifications_none,
    this.type = AdminNotificationType.generic,
    this.senderId,
    this.senderName,
  });
}

class AdminNotificationScreen extends StatefulWidget {
  const AdminNotificationScreen({super.key});

  @override
  State<AdminNotificationScreen> createState() =>
      _AdminNotificationScreenState();
}

class _AdminNotificationScreenState extends State<AdminNotificationScreen> {
  String? _currentUserId;
  final List<AdminNotificationItem> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId().then((_) {
      if (_currentUserId != null) {
        _listenForNotifications();
      } else {
        setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _loadCurrentUserId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      _currentUserId = user.uid;
    });
  }

  void _listenForNotifications() {
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
                  AdminNotificationItem(
                    id: doc.id,
                    title: data['title'] ?? 'New Notification',
                    message: data['message'] ?? 'You have a new update.',
                    timestamp:
                        (data['timestamp'] as Timestamp?)?.toDate() ??
                        DateTime.now(),
                    isRead: data['isRead'] ?? false,
                    icon: _getIconForNotificationType(data['type']),
                    type: _getNotificationTypeFromString(data['type']),
                    senderId: data['senderId'],
                    senderName: data['senderName'] ?? 'A Head',
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
      case 'newTicket':
        return Icons.support_agent;
      case 'subscriptionRequest':
        return Icons.monetization_on_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  AdminNotificationType _getNotificationTypeFromString(String? typeString) {
    switch (typeString) {
      case 'newTicket':
        return AdminNotificationType.newTicket;
      case 'subscriptionRequest':
        return AdminNotificationType.subscriptionRequest;
      default:
        return AdminNotificationType.generic;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  void _markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      if (mounted) CustomPopup.show(context, 'Failed to mark as read: $e');
    }
  }

  void _handleNotificationTap(AdminNotificationItem notification) {
    _markAsRead(notification.id);
    if (notification.type == AdminNotificationType.newTicket) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AdminTicketViewerScreen(),
        ),
      );
    } else if (notification.type == AdminNotificationType.subscriptionRequest) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SubscriptionRequestsScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 24,
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: Colors.black54),
            tooltip: 'Mark all as read',
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
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.black54),
            tooltip: 'Clear all notifications',
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
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: GradientSpinner())
              : _notifications.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_active_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No new notifications',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    Text(
                      'Updates from Heads will appear here.',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final n = _notifications[index];
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 12.0),
                    decoration: BoxDecoration(
                      color: n.isRead ? Colors.white : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            n.isRead
                                ? Colors.grey.shade200
                                : Colors.blue.shade100,
                        width: 0.8,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _handleNotificationTap(n),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(
                                n.icon,
                                color:
                                    n.isRead
                                        ? Colors.grey.shade600
                                        : Colors.blue.shade700,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                                : Colors.blue.shade900,
                                        fontFamily: 'Gilroy-Bold',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      n.message,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        color:
                                            n.isRead
                                                ? Colors.grey.shade500
                                                : Colors.grey.shade800,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
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
                    ),
                  );
                },
              ),
    );
  }
}

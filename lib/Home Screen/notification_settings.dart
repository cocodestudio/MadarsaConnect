import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../Data/dynamic_popup.dart';

class ManageNotificationsScreen extends StatefulWidget {
  const ManageNotificationsScreen({super.key});

  @override
  State<ManageNotificationsScreen> createState() =>
      _ManageNotificationsScreenState();
}

class _ManageNotificationsScreenState extends State<ManageNotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userUid = FirebaseAuth.instance.currentUser!.uid;

  bool _isPushEnabled = true;
  bool _isInAppEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final doc =
          await _firestore
              .collection('notificationSettings')
              .doc(_userUid)
              .get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          _isPushEnabled = data['push'] ?? true;
          _isInAppEnabled = data['inApp'] ?? true;
        }
      }
    } catch (e) {
      print('Failed to load notification settings: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleNotification(String type, bool value) async {
    setState(() {
      if (type == 'push') {
        _isPushEnabled = value;
      } else {
        _isInAppEnabled = value;
      }
    });

    try {
      await _firestore.collection('notificationSettings').doc(_userUid).set({
        type: value,
      }, SetOptions(merge: true));

      if (type == 'push') {
        if (value) {
          String? fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            await _updateFcmTokenInUserDocument(fcmToken);
          }
        } else {
          await FirebaseMessaging.instance.deleteToken();
          await _updateFcmTokenInUserDocument(null);
        }
      }

      CustomPopup.show(
        context,
        '${type.toUpperCase()} Notifications ${value ? 'Enabled' : 'Disabled'}',
      );
    } catch (e) {
      CustomPopup.show(context, 'Failed to update settings. Please try again.');
      if (mounted) {
        setState(() {
          if (type == 'push') {
            _isPushEnabled = !value;
          } else {
            _isInAppEnabled = !value;
          }
        });
      }
    }
  }

  Future<void> _updateFcmTokenInUserDocument(String? token) async {
    final studentDocRef = _firestore.collection('Students').doc(_userUid);
    final facultyDocRef = _firestore.collection('Faculties').doc(_userUid);
    final headDocRef = _firestore.collection('Heads').doc(_userUid);
    final studentDoc = await studentDocRef.get();
    if (studentDoc.exists) {
      await studentDocRef.set({'fcmToken': token}, SetOptions(merge: true));
      return;
    }

    final facultyDoc = await facultyDocRef.get();
    if (facultyDoc.exists) {
      await facultyDocRef.set({'fcmToken': token}, SetOptions(merge: true));
      return;
    }

    final headDoc = await headDocRef.get();
    if (headDoc.exists) {
      await headDocRef.set({'fcmToken': token}, SetOptions(merge: true));
      return;
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
        title: const Text(
          'Manage Notification',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Gilroy-Bold',
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _isLoading
                ? const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.redAccent),
                  ),
                )
                : Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildCardSection(
                        title: 'Notifications',
                        description:
                            'Receive real-time alerts on your device for attendance, homework, and other key updates to stay informed instantly.',
                        children: [
                          _buildToggleTile(
                            label: 'Push Notifications',
                            icon: Icons.notifications_outlined,
                            value: _isPushEnabled,
                            onChanged:
                                (val) => _toggleNotification('push', val),
                          ),
                          _buildToggleTile(
                            label: 'In-App Notifications',
                            icon: Icons.notifications_active_outlined,
                            value: _isInAppEnabled,
                            onChanged:
                                (val) => _toggleNotification('inApp', val),
                          ),
                        ],
                      ),
                    ],
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
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
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
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildToggleTile({
    required String label,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Switch(
            value: value,
            activeColor: Colors.redAccent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

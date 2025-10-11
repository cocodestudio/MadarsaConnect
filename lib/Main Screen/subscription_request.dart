import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/firebase_notification_helper.dart';

class SubscriptionRequestsScreen extends StatefulWidget {
  const SubscriptionRequestsScreen({super.key});

  @override
  State<SubscriptionRequestsScreen> createState() =>
      _SubscriptionRequestsScreenState();
}

class _SubscriptionRequestsScreenState
    extends State<SubscriptionRequestsScreen> {
  String _selectedStatus = 'pending';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text(
          'Subscription Requests',
          style: TextStyle(fontFamily: 'Gilroy-Bold', fontSize: 20),
        ),
        backgroundColor: const Color(0xFF1B263B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                // Refresh the stream by rebuilding the widget
              });
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 16.0,
            ),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children:
                  ['pending', 'approved', 'rejected']
                      .map(
                        (status) => FilterChip(
                          label: Text(status.toUpperCase()),
                          selected: _selectedStatus == status,
                          onSelected: (isSelected) {
                            if (isSelected) {
                              setState(() {
                                _selectedStatus = status;
                              });
                            }
                          },
                          selectedColor:
                              status == 'pending'
                                  ? Colors.orange
                                  : status == 'approved'
                                  ? Colors.green
                                  : Colors.red,
                          labelStyle: TextStyle(
                            color:
                                _selectedStatus == status
                                    ? Colors.white
                                    : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          checkmarkColor: Colors.white,
                        ),
                      )
                      .toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('subscriptionRequests')
                      .where('status', isEqualTo: _selectedStatus)
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final requests = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    return SubscriptionRequestCard(requestDoc: requests[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No ${_selectedStatus} requests found',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class SubscriptionRequestCard extends StatelessWidget {
  final QueryDocumentSnapshot requestDoc;
  const SubscriptionRequestCard({super.key, required this.requestDoc});

  Future<void> _updateRequestStatus(String status, BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('subscriptionRequests')
          .doc(requestDoc.id)
          .update({
            'status': status,
            'verificationTimestamp': FieldValue.serverTimestamp(),
            'verifiedBy': FirebaseAuth.instance.currentUser?.email ?? 'Admin',
          });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request successfully ${status.toLowerCase()}!'),
          backgroundColor: status == 'approved' ? Colors.green : Colors.red,
        ),
      );

      // --- NEW NOTIFICATION LOGIC ---
      if (status == 'approved') {
        try {
          final requestData = requestDoc.data() as Map<String, dynamic>?;
          final userId = requestData?['userId'];

          // Fetch user's headUid from Students or Faculties collection
          final userDoc =
              await FirebaseFirestore.instance
                  .collection('Students')
                  .doc(userId)
                  .get();

          String? headUid;
          if (userDoc.exists) {
            headUid = userDoc.data()?['headUid'];
          } else {
            final facultyDoc =
                await FirebaseFirestore.instance
                    .collection('Faculties')
                    .doc(userId)
                    .get();
            if (facultyDoc.exists) {
              headUid = facultyDoc.data()?['headUid'];
            }
          }

          if (headUid != null) {
            final headDoc =
                await FirebaseFirestore.instance
                    .collection('Heads')
                    .doc(headUid)
                    .get();
            final headToken = headDoc.data()?['fcmToken'];

            // Fetch Head's notification settings
            final settingsDoc =
                await FirebaseFirestore.instance
                    .collection('notificationSettings')
                    .doc(headUid)
                    .get();
            final bool isPushEnabled = settingsDoc.data()?['push'] ?? true;
            final bool isInAppEnabled = settingsDoc.data()?['inApp'] ?? true;

            // Send push notification only if enabled
            if (isPushEnabled &&
                headToken != null &&
                headToken.toString().isNotEmpty) {
              await FirebaseNotificationHelper.sendNotificationFromApp(
                fcmToken: headToken,
                title: 'New Subscription Approval',
                body:
                    '${requestData?['email'] ?? 'A user'} has been approved for a new subscription.',
              );
            }

            // Add in-app notification only if enabled
            if (isInAppEnabled) {
              await FirebaseFirestore.instance.collection('notifications').add({
                'recipientId': headUid,
                'title': 'New Subscription Approval',
                'message':
                    '${requestData?['email'] ?? 'A user'} has been approved for a new subscription.',
                'timestamp': FieldValue.serverTimestamp(),
                'isRead': false,
                'type': 'subscriptionApproval',
                'senderId': FirebaseAuth.instance.currentUser?.uid,
                'senderName': 'Admin',
                'targetId': requestDoc.id,
                'targetType': 'subscriptionRequests',
              });
            }
          }
        } catch (e) {
          print('❌ Failed to send notification to Head: $e');
        }
      }
      // --- END NEW NOTIFICATION LOGIC ---
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = requestDoc.data() as Map<String, dynamic>?;
    final timestamp = (data?['timestamp'] as Timestamp?)?.toDate();
    final formattedDate =
        timestamp != null
            ? DateFormat('dd-MMM-yyyy hh:mm a').format(timestamp)
            : 'N/A';

    Color statusColor;
    String statusText;
    switch (data?['status']) {
      case 'pending':
        statusColor = Colors.orange.shade700;
        statusText = 'PENDING';
        break;
      case 'approved':
        statusColor = Colors.green;
        statusText = 'APPROVED';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'REJECTED';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'UNKNOWN';
    }

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'User: ${data?['email'] ?? 'N/A'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(statusText),
                  backgroundColor: statusColor,
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Submitted on: $formattedDate',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const Divider(height: 20),
            _buildInfoRow(
              Icons.subscriptions_rounded,
              'Plan',
              data?['planName'] ?? 'N/A',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.payments_rounded,
              'Amount',
              '₹${data?['price'] ?? 'N/A'}',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.receipt_long_rounded,
              'UTR Number',
              data?['utrNumber'] ?? 'N/A',
              isBold: true,
            ),

            const Divider(height: 20),
            if (data?['status'] == 'pending')
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _updateRequestStatus('rejected', context),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _updateRequestStatus('approved', context),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                  ),
                ],
              )
            else
              Center(
                child: Text(
                  'This request is ${data?['status'].toUpperCase()}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String title,
    String value, {
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 8),
        Text('$title:', style: TextStyle(color: Colors.grey.shade800)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey.shade800,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

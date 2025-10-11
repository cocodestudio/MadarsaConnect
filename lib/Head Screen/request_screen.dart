import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:madarsaConnect/Data/loader.dart';
import '../Data/dynamic_popup.dart';
import '../utils/firebase_notification_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key});
  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  bool showDetails = false;
  bool showFilters = false;
  List<Map<String, dynamic>> pendingLeaveRequests = [];
  List<Map<String, dynamic>> pendingFeeRequests = [];
  List<Map<String, dynamic>> pendingDonationRequests = []; // <-- NEW
  bool isLoading = true;
  Map<String, dynamic>? selectedRequest;
  String? selectedSession;
  String? selectedRole;
  String? selectedCategory;
  List<Map<String, dynamic>> filteredRequests = [];
  bool showFilteredResults = false;
  bool isFilteredLoading = false;
  bool showFilteredDetails = false;
  bool isActionProcessing = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> handleRequestAction(BuildContext context, String action) async {
    if (selectedRequest == null) return;

    try {
      setState(() => isActionProcessing = true);

      final requestType = selectedRequest!['type']?.toString().toLowerCase();
      String notificationTitle = '';
      String notificationBody = '';
      String notificationType = '';
      String? recipientId;

      // --- LEAVE REQUEST LOGIC ---
      if (requestType == 'leave') {
        final docId = selectedRequest?['id'];
        final session = getCurrentSession();
        final leaveId = selectedRequest?['leaveId'];
        final userEmail = selectedRequest?['email'] as String?;
        final userRole = selectedRequest?['role'] as String?;

        if (docId == null ||
            leaveId == null ||
            userEmail == null ||
            userRole == null) {
          if (mounted)
            CustomPopup.show(context, "⚠️ Request data is incomplete.");
          setState(() => isActionProcessing = false);
          return;
        }

        final docRef = _firestore.collection('leaveRequests').doc(docId);
        await _firestore.runTransaction((transaction) async {
          final docSnap = await transaction.get(docRef);
          if (!docSnap.exists) {
            throw Exception("Leave request not found ❌");
          }

          final data = docSnap.data()!;
          final sessions = data['sessions'] as Map<String, dynamic>?;
          if (sessions == null || !sessions.containsKey(session)) {
            throw Exception("⚠️ No session found: $session");
          }

          final List<dynamic> leaves = List.from(sessions[session] ?? []);
          if (leaves.isEmpty) {
            throw Exception("⚠️ No leaves to process.");
          }

          final nowTimestamp = Timestamp.now();
          if (action == 'Decline') {
            final filteredLeaves =
                leaves.where((leave) => leave['leaveId'] != leaveId).toList();
            final updates = <String, dynamic>{
              'sessions.$session':
                  filteredLeaves.isEmpty ? FieldValue.delete() : filteredLeaves,
              'lastDeclined': {'status': 'Declined', 'updatedAt': nowTimestamp},
            };
            transaction.update(docRef, updates);
            notificationTitle = 'Leave Declined ❌';
            notificationBody = 'Your leave request has been declined.';
          } else if (action == 'Accept') {
            final updatedLeaves =
                leaves.map((leave) {
                  final leaveMap = Map<String, dynamic>.from(leave);
                  if (leaveMap['leaveId'] == leaveId) {
                    leaveMap['status'] = 'Approved';
                    leaveMap['updatedAt'] = nowTimestamp;
                  }
                  return leaveMap;
                }).toList();
            transaction.set(docRef, {
              'sessions': {session: updatedLeaves},
            }, SetOptions(merge: true));
            notificationTitle = 'Leave Approved ✅';
            notificationBody = 'Your leave request has been approved.';
          }
        });

        notificationType = 'leaveStatus';
        final collectionName = userRole == 'Faculty' ? 'Faculties' : 'Students';
        final userSnap =
            await _firestore
                .collection(collectionName)
                .where('email', isEqualTo: userEmail)
                .limit(1)
                .get();
        if (userSnap.docs.isNotEmpty) {
          final userDoc = userSnap.docs.first;
          recipientId = userDoc.id;
          final userToken = userDoc.data()['fcmToken'];
          if (userToken != null && userToken.toString().isNotEmpty) {
            await FirebaseNotificationHelper.sendNotificationFromApp(
              fcmToken: userToken,
              title: notificationTitle,
              body: notificationBody,
            );
          }
        }
      } else if (requestType == 'fee') {
        final mainDocId = selectedRequest!['id'];
        final studentUid = selectedRequest!['userId'];

        final mainDocRef = _firestore.collection('feePayments').doc(mainDocId);
        if (action == 'Decline') {
          await mainDocRef.update({'status': 'rejected'});
          notificationTitle = 'Fee Payment Declined ❌';
          notificationBody = 'Your fee payment request has been declined.';
        } else if (action == 'Accept') {
          await mainDocRef.update({'status': 'approved'});
          notificationTitle = 'Fee Payment Approved ✅';
          notificationBody = 'Your fee payment request has been approved.';
        }
        notificationType = 'feeStatus';
        final studentDoc =
            await _firestore.collection('Students').doc(studentUid).get();
        if (studentDoc.exists) {
          recipientId = studentDoc.id;
          final studentToken = studentDoc.data()?['fcmToken'];
          if (studentToken != null && studentToken.toString().isNotEmpty) {
            await FirebaseNotificationHelper.sendNotificationFromApp(
              fcmToken: studentToken,
              title: notificationTitle,
              body: notificationBody,
            );
          }
        }
      }
      else if (requestType == 'donation') {
        final docId = selectedRequest!['id'];
        final userId = selectedRequest!['userId'];
        final amount = selectedRequest!['amount'];
        final docRef = _firestore.collection('donationRequests').doc(docId);

        if (action == 'Decline') {
          await docRef.update({'status': 'rejected'});
          notificationTitle = 'Donation Declined ❌';
          notificationBody =
              'Your donation of ₹${amount.toStringAsFixed(2)} has been declined.';
        } else if (action == 'Accept') {
          await docRef.update({'status': 'approved'});
          notificationTitle = 'Donation Approved ✅';
          notificationBody =
              'Thank you! Your donation of ₹${amount.toStringAsFixed(2)} has been approved.';
        }

        notificationType = 'donationStatus';
        recipientId = userId;

        // Find user's FCM token from any user collection
        DocumentSnapshot userSnap;
        String? fcmToken;
        userSnap = await _firestore.collection('Students').doc(userId).get();
        if (userSnap.exists && userSnap.data() != null) {
          fcmToken = (userSnap.data() as Map<String, dynamic>)['fcmToken'];
        } else {
          userSnap = await _firestore.collection('Faculties').doc(userId).get();
          if (userSnap.exists && userSnap.data() != null) {
            fcmToken = (userSnap.data() as Map<String, dynamic>)['fcmToken'];
          } else {
            userSnap = await _firestore.collection('Heads').doc(userId).get();
            if (userSnap.exists && userSnap.data() != null) {
              fcmToken = (userSnap.data() as Map<String, dynamic>)['fcmToken'];
            }
          }
        }

        if (fcmToken != null && fcmToken.isNotEmpty) {
          await FirebaseNotificationHelper.sendNotificationFromApp(
            fcmToken: fcmToken,
            title: notificationTitle,
            body: notificationBody,
          );
        }
      }

      // --- In-app notification logic for all types ---
      if (recipientId != null && notificationType.isNotEmpty) {
        await _firestore.collection('notifications').add({
          'recipientId': recipientId,
          'title': notificationTitle,
          'message': notificationBody,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'type': notificationType,
          'senderId': _auth.currentUser?.uid,
          'senderName': 'Admin',
          'targetId': selectedRequest?['id'],
          'targetType': requestType,
        });
      }

      setState(() {
        if (requestType == 'leave') {
          pendingLeaveRequests.removeWhere(
            (req) => req['leaveId'] == selectedRequest?['leaveId'],
          );
        } else if (requestType == 'fee') {
          pendingFeeRequests.removeWhere(
            (req) => req['id'] == selectedRequest?['id'],
          );
        } else if (requestType == 'donation') {
          pendingDonationRequests.removeWhere(
            (req) => req['id'] == selectedRequest?['id'],
          );
        }
        showDetails = false;
        selectedRequest = null;
      });
    } catch (e) {
      if (mounted) CustomPopup.show(context, 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => isActionProcessing = false);
    }
  }

  Future<void> fetchAllPendingRequests() async {
    if (mounted) setState(() => isLoading = true);
    await Future.wait([
      fetchLeaveRequests(),
      fetchFeeRequests(),
      fetchDonationRequests(), // <-- NEW
    ]);
    if (mounted) setState(() => isLoading = false);
  }

  // --- NEW: Fetch Donation Requests ---
  Future<void> fetchDonationRequests() async {
    try {
      final headUid = _auth.currentUser?.uid;
      if (headUid == null) return;
      final snapshot =
          await _firestore
              .collection('donationRequests')
              .where('status', isEqualTo: 'pending')
              .where('headUid', isEqualTo: headUid)
              .get();

      final List<Map<String, dynamic>> allRequests = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        String? profilePictureUrl;
        final userId = data['userId'] as String?;
        if (userId != null) {
          DocumentSnapshot userSnap;
          // Check Students, Faculties, and Heads collections for the user's profile picture
          userSnap = await _firestore.collection('Students').doc(userId).get();
          if (userSnap.exists && userSnap.data() != null) {
            profilePictureUrl =
                (userSnap.data() as Map<String, dynamic>)['profilePictureUrl'];
          } else {
            userSnap =
                await _firestore.collection('Faculties').doc(userId).get();
            if (userSnap.exists && userSnap.data() != null) {
              profilePictureUrl =
                  (userSnap.data()
                      as Map<String, dynamic>)['profilePictureUrl'];
            } else {
              userSnap = await _firestore.collection('Heads').doc(userId).get();
              if (userSnap.exists && userSnap.data() != null) {
                profilePictureUrl =
                    (userSnap.data()
                        as Map<String, dynamic>)['profilePictureUrl'];
              }
            }
          }
        }
        allRequests.add({
          'id': doc.id,
          'type': 'donation',
          'name': data['userName'] ?? 'N/A',
          'email': data['userEmail'] ?? 'N/A',
          'profilePictureUrl': profilePictureUrl,
          'purpose': data['category'] ?? 'N/A',
          'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
          'utrNumber': data['utrNumber'] ?? 'N/A',
          'userId': data['userId'],
          'timestamp': data['timestamp'] as Timestamp? ?? Timestamp.now(),
        });
      }
      if (mounted) {
        setState(() {
          pendingDonationRequests = allRequests;
        });
      }
    } catch (e) {
      debugPrint("Error fetching donation requests: $e");
    }
  }

  Future<void> fetchFeeRequests() async {
    try {
      final headUid = _auth.currentUser?.uid;
      if (headUid == null) return;
      final snapshot =
          await _firestore
              .collection('feePayments')
              .where('status', isEqualTo: 'pending')
              .where('headUid', isEqualTo: headUid)
              .get();

      final List<Map<String, dynamic>> allRequests = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        String? profilePictureUrl;
        final studentUid = data['userId'] as String?;
        if (studentUid != null) {
          final studentDoc =
              await _firestore.collection('Students').doc(studentUid).get();
          if (studentDoc.exists) {
            profilePictureUrl =
                (studentDoc.data()
                    as Map<String, dynamic>)['profilePictureUrl'];
          }
        }
        allRequests.add({
          'id': doc.id,
          'type': 'fee',
          'name': data['name'] as String? ?? 'N/A',
          'email': data['email'] as String? ?? 'N/A',
          'profilePictureUrl': profilePictureUrl,
          'purpose': data['purpose'] as String? ?? 'N/A',
          'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
          'utrNumber': data['utrNumber'] as String? ?? 'N/A',
          'userId': data['userId'],
          'headUid': data['headUid'],
          'timestamp': data['timestamp'] as Timestamp? ?? Timestamp.now(),
        });
      }
      if (mounted) {
        setState(() {
          pendingFeeRequests = allRequests;
        });
      }
    } catch (e) {
      debugPrint("Error fetching fee requests: $e");
    }
  }

  Future<void> fetchLeaveRequests() async {
    try {
      final headUid = _auth.currentUser?.uid;
      if (headUid == null) return;
      final snapshot =
          await _firestore
              .collection('leaveRequests')
              .where('headUid', isEqualTo: headUid)
              .get();
      final session = getCurrentSession();

      final List<Map<String, dynamic>> allRequests = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        if (data.containsKey('sessions') && data['sessions'][session] != null) {
          final List<dynamic> requests = data['sessions'][session];

          for (var leave in requests) {
            if (leave['status'] != 'Pending') continue;
            final endDate = (leave['endDate'] as Timestamp).toDate();
            final now = DateTime.now();
            if (endDate.isBefore(now)) continue;

            final email = data['email'] as String? ?? '';
            final role = data.containsKey('fucId') ? 'Faculty' : 'Student';
            String? profilePictureUrl;

            try {
              final collectionName =
                  role == 'Faculty' ? 'Faculties' : 'Students';
              final userSnap =
                  await _firestore
                      .collection(collectionName)
                      .where('email', isEqualTo: email)
                      .limit(1)
                      .get();

              if (userSnap.docs.isNotEmpty) {
                profilePictureUrl =
                    userSnap.docs.first.data()['profilePictureUrl'];
              }
            } catch (e) {
              profilePictureUrl = null;
            }

            allRequests.add({
              'name': data['name'] ?? '',
              'email': email,
              'id': doc.id,
              'role': role,
              'profilePictureUrl': profilePictureUrl,
              'type': 'leave',
              'startDate': DateFormat(
                'dd MMM yyyy',
              ).format((leave['startDate'] as Timestamp).toDate()),
              'endDate': DateFormat('dd MMM yyyy').format(endDate),
              'startTime': leave['startTime'],
              'endTime': leave['endTime'],
              'reason': leave['reason'],
              'leaveId': leave['leaveId'],
              'remarks': leave['remarks'] ?? 'Leave Request',
              'timestamp': leave['timestamp'] as Timestamp? ?? Timestamp.now(),
            });
          }
        }
      }

      if (mounted)
        setState(() {
          pendingLeaveRequests = allRequests;
        });
    } catch (e) {
      debugPrint("Error fetching leave requests: $e");
    }
  }

  String getCurrentSession() {
    final now = DateTime.now();
    final year = now.month >= 4 ? now.year : now.year - 1;
    return "$year-${year + 1}";
  }

  Future<void> fetchFilteredRequests() async {
    setState(() {
      isFilteredLoading = true;
    });

    if (selectedSession == null ||
        selectedCategory == null ||
        selectedRole == null) {
      debugPrint("⚠️ Please select session, role, and category.");
      setState(() => isFilteredLoading = false);
      return;
    }

    final snapshot = await _firestore.collection('leaveRequests').get();
    List<Map<String, dynamic>> tempList = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final isFaculty = data.containsKey('fucId');
      final isStudent = data.containsKey('sucId');

      if ((selectedRole == 'Faculty' && !isFaculty) ||
          (selectedRole == 'Student' && !isStudent)) {
        continue;
      }

      if (!data.containsKey('sessions') ||
          data['sessions'][selectedSession] == null) {
        continue;
      }

      final sessionLeaves = data['sessions'][selectedSession];
      for (var leave in sessionLeaves) {
        final status = (leave['status'] ?? '').toString().toLowerCase();
        final remarks = (leave['remarks'] ?? '').toString();

        if (status != 'approved') {
          continue;
        }

        if (selectedCategory == 'Leave Request') {
          if (remarks != 'Submit Request' && remarks != 'Extend Leave') {
            continue;
          }
        } else if (selectedCategory != 'All' && remarks != selectedCategory) {
          continue;
        }

        final startDateObj = (leave['startDate'] as Timestamp).toDate();
        final endDateObj = (leave['endDate'] as Timestamp).toDate();
        final role = isFaculty ? 'Faculty' : 'Student';
        String? profilePictureUrl;

        try {
          final collectionName = role == 'Faculty' ? 'Faculties' : 'Students';
          final email = data['email'] as String? ?? '';
          if (email.isNotEmpty) {
            final userSnap =
                await _firestore
                    .collection(collectionName)
                    .where('email', isEqualTo: email)
                    .limit(1)
                    .get();

            if (userSnap.docs.isNotEmpty) {
              profilePictureUrl =
                  userSnap.docs.first.data()['profilePictureUrl'];
            }
          }
        } catch (e) {
          profilePictureUrl = null;
        }

        tempList.add({
          'name': data['name'] ?? '',
          'email': data['email'] ?? '',
          'id': doc.id,
          'role': role,
          'remarks': remarks,
          'status': leave['status'] ?? '',
          'leaveId': leave['leaveId'] ?? '',
          'type': 'leave',
          'startDate': DateFormat('dd MMM yyyy').format(startDateObj),
          'endDate': DateFormat('dd MMM yyyy').format(endDateObj),
          'startTime': leave['startTime'] ?? '',
          'endTime': leave['endTime'] ?? '',
          'reason': leave['reason'] ?? '',
          'profilePictureUrl': profilePictureUrl,
        });
      }
    }

    setState(() {
      filteredRequests = tempList;
      isFilteredLoading = false;
    });
  }

  void _showSessionDialog() async {
    final sessions = <String>{};

    final snapshot = await _firestore.collection('leaveRequests').get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data.containsKey('sessions')) {
        try {
          final Map<String, dynamic> sessionMap = Map<String, dynamic>.from(
            data['sessions'],
          );
          sessions.addAll(sessionMap.keys);
        } catch (e) {
          debugPrint('Error parsing sessions: $e');
        }
      }
    }

    final sortedList = sessions.toList()..sort((a, b) => b.compareTo(a));

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            "Select Session",
            style: TextStyle(fontFamily: 'Gilroy-Bold', fontSize: 20),
          ),
          content: SizedBox(
            height: MediaQuery.of(context).size.height * 0.3,
            width: MediaQuery.of(context).size.width * 0.9,
            child: ListView.builder(
              itemCount: sortedList.length,
              itemBuilder: (context, index) {
                final session = sortedList[index];
                final isSelected = selectedSession == session;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: Colors.redAccent,
                  ),
                  title: Text(
                    session,
                    style: const TextStyle(
                      fontSize: 16,
                      fontFamily: 'Gilroy-Medium',
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      selectedSession = session;
                    });
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showRoleDialog() {
    final roles = ['Faculty', 'Student'];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            "Select Role",
            style: TextStyle(fontFamily: 'Gilroy-Bold', fontSize: 20),
          ),
          content: SizedBox(
            height: MediaQuery.of(context).size.height * 0.25,
            width: MediaQuery.of(context).size.width * 0.9,
            child: ListView.builder(
              itemCount: roles.length,
              itemBuilder: (context, index) {
                final role = roles[index];
                final isSelected = selectedRole == role;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: Colors.redAccent,
                  ),
                  title: Text(
                    role,
                    style: const TextStyle(
                      fontSize: 16,
                      fontFamily: 'Gilroy-Medium',
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      selectedRole = role;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showCategoryDialog() {
    final categories = ['All', 'Urgent', 'Personal', 'Leave Request'];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            "Select Category",
            style: TextStyle(fontFamily: 'Gilroy-Bold', fontSize: 20),
          ),
          content: SizedBox(
            height: MediaQuery.of(context).size.height * 0.3,
            width: MediaQuery.of(context).size.width * 0.9,
            child: ListView.builder(
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = selectedCategory == cat;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: Colors.redAccent,
                  ),
                  title: Text(
                    cat,
                    style: const TextStyle(
                      fontSize: 16,
                      fontFamily: 'Gilroy-Medium',
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      selectedCategory = cat;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    fetchAllPendingRequests();
  }

  Widget _buildFilterPage() {
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F7FB),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Select Session"),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _showSessionDialog,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        selectedSession ?? 'Select Session',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("Role"),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _showRoleDialog,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        selectedRole ?? 'Select Role (Faculty/Student)',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("Categories"),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _showCategoryDialog,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        selectedCategory ?? 'Select Category',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (selectedSession == null ||
                      selectedRole == null ||
                      selectedCategory == null) {
                    CustomPopup.show(
                      context,
                      "Please select all filters properly.",
                    );
                    return;
                  }
                  setState(() {
                    isFilteredLoading = true;
                    showFilters = false;
                    showFilteredResults = true;
                  });
                  await fetchFilteredRequests();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Search',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontFamily: 'Gilroy-Bold',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredCards() {
    if (filteredRequests.isEmpty) {
      return const Center(child: Text("No matching data found."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredRequests.length,
      itemBuilder: (context, index) {
        final request = filteredRequests[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    request['name'] as String? ?? 'No Name',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          request['role'] == 'Student'
                              ? Colors.yellow.shade300
                              : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(request['role']),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text("ID: ${request['id'] ?? 'N/A'}"),
              Text("Remarks: ${request['remarks'] ?? 'N/A'}"),
              Text(
                "Start Date: ${request['startDate'] ?? 'N/A'} at ${request['startTime'] ?? 'N/A'}",
              ),
              Text(
                "End Date: ${request['endDate'] ?? 'N/A'} at ${request['endTime'] ?? 'N/A'}",
              ),
              Text("Reason: ${request['reason'] ?? 'N/A'}"),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestList() {
    final allRequests = [
      ...pendingLeaveRequests,
      ...pendingFeeRequests,
      ...pendingDonationRequests, // <-- NEW
    ];
    allRequests.sort((a, b) {
      final aTimestamp = a['timestamp'] as Timestamp?;
      final bTimestamp = b['timestamp'] as Timestamp?;
      if (aTimestamp == null && bTimestamp == null) return 0;
      if (aTimestamp == null) return 1; // Put nulls at the end
      if (bTimestamp == null) return -1; // Keep non-nulls at the start
      return bTimestamp.compareTo(aTimestamp); // Sort descending
    });

    if (allRequests.isEmpty) {
      return const Center(child: Text("No pending requests."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allRequests.length,
      itemBuilder: (context, index) {
        final request = allRequests[index];
        return _buildRequestCard(request);
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final type = request['type'];
    String remarks;
    Color typeColor;
    String typeLabel;

    switch (type) {
      case 'fee':
        remarks = '${request['purpose']}';
        typeColor = Colors.blue;
        typeLabel = 'Fee';
        break;
      case 'donation':
        remarks = '${request['purpose']}';
        typeColor = Colors.purple;
        typeLabel = 'Donation';
        break;
      case 'leave':
      default:
        remarks = request['remarks'];
        typeColor =
            request['role'] == 'Student'
                ? Colors.orange.shade300
                : Colors.grey.shade400;
        typeLabel = request['role'] ?? 'Leave';
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedRequest = request;
          showDetails = true;
          showFilteredDetails = false;
          showFilters = false;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.grey.shade200,
              backgroundImage:
                  request['profilePictureUrl'] != null &&
                          request['profilePictureUrl'].toString().isNotEmpty
                      ? NetworkImage(request['profilePictureUrl'])
                      : null,
              child:
                  request['profilePictureUrl'] == null ||
                          request['profilePictureUrl'].toString().isEmpty
                      ? SvgPicture.asset(
                        'assets/icons/users.svg',
                        width: 26,
                        height: 26,
                        fit: BoxFit.contain,
                      )
                      : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        request['name'] ?? 'No Name',
                        style: const TextStyle(
                          fontFamily: 'Gilroy-Bold',
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          typeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: typeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (type == 'fee' || type == 'donation')
                    Text(
                      "Amount: ₹${(request['amount'] as double).toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontFamily: 'Gilroy-Regular',
                      ),
                    )
                  else
                    Text(
                      "ID: ${request['id'] ?? 'N/A'}",
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontFamily: 'Gilroy-Regular',
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    "Remarks: $remarks",
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'Gilroy-Regular',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsView() {
    final request = selectedRequest ?? {};
    final type = request['type'];

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Common Header ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage:
                            request['profilePictureUrl'] != null &&
                                    request['profilePictureUrl']
                                        .toString()
                                        .isNotEmpty
                                ? NetworkImage(request['profilePictureUrl'])
                                : null,
                        child:
                            request['profilePictureUrl'] == null ||
                                    request['profilePictureUrl']
                                        .toString()
                                        .isEmpty
                                ? SvgPicture.asset(
                                  'assets/icons/users.svg',
                                  width: 26,
                                  height: 26,
                                  fit: BoxFit.contain,
                                )
                                : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request['name'] ?? 'No Name',
                              style: const TextStyle(
                                fontFamily: 'Gilroy-Bold',
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Email: ${request['email'] ?? 'N/A'}",
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                                fontFamily: 'Gilroy-Regular',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(thickness: 1),
                  const SizedBox(height: 10),

                  // --- Type-Specific Details ---
                  if (type == 'leave') ...[
                    const Text(
                      "Role",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(request['role'] ?? '--'),
                    const SizedBox(height: 12),
                    const Text(
                      "Remarks",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(request['remarks'] ?? '--'),
                    const SizedBox(height: 12),
                    const Text(
                      "Start Date & Time",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "${request['startDate'] ?? '--'} at ${request['startTime'] ?? ''}",
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "End Date & Time",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "${request['endDate'] ?? '--'} at ${request['endTime'] ?? ''}",
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Reason",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(request['reason'] ?? '--'),
                  ] else ...[
                    // Common for Fee & Donation
                    const Text(
                      "Category / Purpose",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(request['purpose'] ?? '--'),
                    const SizedBox(height: 12),
                    const Text(
                      "Amount",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "₹${(request['amount'] as double).toStringAsFixed(2)}",
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "UTR Number",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(request['utrNumber'] ?? '--'),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              // Decline
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed:
                      isActionProcessing
                          ? null
                          : () => handleRequestAction(context, 'Decline'),
                  child: const Text(
                    "Decline",
                    style: TextStyle(
                      fontFamily: 'Gilroy-Bold',
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Accept
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed:
                      isActionProcessing
                          ? null
                          : () => handleRequestAction(context, 'Accept'),
                  child: const Text(
                    "Accept",
                    style: TextStyle(
                      fontFamily: 'Gilroy-Bold',
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        if (showDetails) {
          setState(() {
            showDetails = false;
            selectedRequest = null;
          });
        } else if (showFilteredDetails) {
          setState(() {
            showFilteredDetails = false;
            selectedRequest = null;
          });
        } else if (showFilteredResults) {
          setState(() {
            showFilteredResults = false;
            showFilters = true;
          });
        } else if (showFilters) {
          setState(() {
            showFilters = false;
          });
        } else {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.grey.withOpacity(0.2),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 26),
            onPressed: () {
              if (showDetails) {
                setState(() {
                  showDetails = false;
                  selectedRequest = null;
                });
              } else if (showFilteredDetails) {
                setState(() {
                  showFilteredDetails = false;
                  selectedRequest = null;
                });
              } else if (showFilteredResults) {
                setState(() {
                  showFilteredResults = false;
                  showFilters = true;
                });
              } else if (showFilters) {
                setState(() {
                  showFilters = false;
                });
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(
            showDetails
                ? '${selectedRequest?['type'].toString().capitalize()} Request'
                : showFilteredDetails
                ? 'Approved Request'
                : showFilters
                ? 'Filters'
                : 'Requests',
            style: const TextStyle(
              fontSize: 20,
              fontFamily: 'Gilroy-Bold',
              color: Colors.black,
            ),
          ),
          centerTitle: true,
          actions: [
            (showDetails || showFilters || showFilteredResults)
                ? const SizedBox(width: 48)
                : IconButton(
                  onPressed: () {
                    setState(() {
                      showFilters = true;
                    });
                  },
                  icon: SvgPicture.asset(
                    'assets/icons/filter.svg',
                    height: 24,
                    width: 24,
                    colorFilter: const ColorFilter.mode(
                      Colors.black,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
          ],
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Builder(
              builder: (context) {
                if (isLoading || isActionProcessing || isFilteredLoading) {
                  return const Center(child: GradientSpinner());
                }
                if (showDetails) return _buildDetailsView();
                if (showFilteredDetails) return _buildFilteredCards();
                if (showFilters) return _buildFilterPage();
                if (showFilteredResults) return _buildFilteredCards();
                return _buildRequestList();
              },
            ),
          ),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) {
      return this;
    }
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

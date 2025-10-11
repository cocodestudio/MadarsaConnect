import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:madarsaConnect/Data/loader.dart';
import '../Data/check_internet.dart';
import '../Data/dynamic_popup.dart';
import '../utils/firebase_notification_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  TextEditingController reasonController = TextEditingController();
  bool isSubmitting = false;
  bool isLoadingData = true;
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now().add(const Duration(days: 4));
  TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 18, minute: 30);
  String leaveType = 'Annual Leave';
  int usedLeaveDays = 0;
  int remainingLiveDays = 0;
  bool isPastRequestSelected = false;
  late PageController _pageController;
  List<String> availableSessions = [];
  String? selectedSession;
  List<Map<String, dynamic>> sessionLeaves = [];
  String usedLeaveLabel = '';
  String remainingLeaveLabel = '';
  String userName = '';
  String userId = '';
  String userRole = ''; // Added a variable to store the user's role
  bool buttonLocked = false;
  String leaveStatus = 'None';
  DateTime? leaveUpdatedAt;
  String buttonText = 'Submit Request';
  bool isExtendedRequest = false;
  DateTime? lastLeaveEndDate;
  List<Map<String, dynamic>> pastRequests = [];
  bool hasExtendedOnce = false;
  String? profilePictureUrl;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, now.day);
    endDate = startDate.add(const Duration(days: 4));
    startTime = TimeOfDay(hour: now.hour, minute: now.minute);

    _loadAllData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    reasonController.dispose();
    super.dispose();
  }

  Future<void> loadUserProfileInfo() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot userDocSnap =
          await _firestore.collection('Students').doc(user.uid).get();
      if (userDocSnap.exists) {
        userRole = 'student';
      } else {
        userDocSnap =
            await _firestore.collection('Faculties').doc(user.uid).get();
        if (userDocSnap.exists) {
          userRole = 'faculty';
        } else {
          userDocSnap =
              await _firestore.collection('Heads').doc(user.uid).get();
          if (userDocSnap.exists) {
            userRole = 'head';
          } else {
            return;
          }
        }
      }

      final userDoc = userDocSnap.data() as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          userName = userDoc?['fullName'] ?? '';
          if (userRole == 'faculty') {
            userId = userDoc?['fucId'] ?? '';
          } else if (userRole == 'student') {
            userId = userDoc?['sucId'] ?? '';
          }
          profilePictureUrl = userDoc?['profilePictureUrl'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  Future<void> calculateUsedLeaves() async {
    final user = _auth.currentUser;
    if (user == null || userRole.isEmpty) return;

    final session = getCurrentSession();

    String collectionName = userRole == 'faculty' ? 'Faculties' : 'Students';
    String docIdField = userRole == 'faculty' ? 'fucId' : 'sucId';

    try {
      final userDocSnap =
          await _firestore.collection(collectionName).doc(user.uid).get();

      if (!userDocSnap.exists) return;
      final userDoc = userDocSnap.data();
      final String? docId = userDoc?[docIdField];
      if (docId == null || docId.isEmpty) return;

      final leaveDoc =
          await _firestore.collection('leaveRequests').doc(docId).get();

      if (!leaveDoc.exists) {
        if (mounted) {
          setState(() {
            usedLeaveLabel = '';
            remainingLeaveLabel = '';
          });
        }
        return;
      }

      final data = leaveDoc.data();
      final currentSessionLeaves = data?['sessions']?[session];

      double usedHours = 0;
      double remainingHours = 0;
      final now = DateTime.now();

      bool hasApprovedLeave = false;

      if (currentSessionLeaves != null && currentSessionLeaves is List) {
        for (var leave in currentSessionLeaves) {
          if (leave['status'] != 'Approved') continue;

          hasApprovedLeave = true;

          final DateTime start = (leave['startDate'] as Timestamp).toDate();
          final DateTime end = (leave['endDate'] as Timestamp).toDate();

          final String? startTimeStr = leave['startTime'];
          final String? endTimeStr = leave['endTime'];

          final DateTime startDateTime = DateTime(
            start.year,
            start.month,
            start.day,
            int.parse(startTimeStr?.split(':')[0] ?? '9'),
            int.parse(startTimeStr?.split(':')[1] ?? '0'),
          );

          final DateTime endDateTime = DateTime(
            end.year,
            end.month,
            end.day,
            int.parse(endTimeStr?.split(':')[0] ?? '18'),
            int.parse(endTimeStr?.split(':')[1] ?? '0'),
          );

          final totalLeaveHours =
              endDateTime.difference(startDateTime).inHours.toDouble();

          if (now.isAfter(endDateTime)) {
            usedHours += totalLeaveHours;
          } else if (now.isBefore(startDateTime)) {
            remainingHours += totalLeaveHours;
          } else {
            final used = now.difference(startDateTime).inHours.toDouble();
            final remain = totalLeaveHours - used;

            usedHours += used;
            remainingHours += remain;
          }
        }
      }

      String formatDays(double hours) {
        double days = hours / 24;
        return days.truncateToDouble() == days
            ? '${days.toInt()} days'
            : '${days.toStringAsFixed(1)} days';
      }

      if (mounted) {
        setState(() {
          if (!hasApprovedLeave) {
            usedLeaveLabel = '';
            remainingLeaveLabel = '';
          } else {
            usedLeaveLabel =
                usedHours <= 24
                    ? '${usedHours.toInt()} hrs'
                    : formatDays(usedHours);
            remainingLeaveLabel =
                remainingHours <= 24
                    ? '${remainingHours.toInt()} hrs'
                    : formatDays(remainingHours);
          }
        });
      }
    } catch (e) {
      print('Error in calculateUsedLeaves: $e');
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime now = DateTime.now();
    final DateTime initial = isStart ? startDate : endDate;
    final DateTime firstDate = isStart ? now : startDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate) ? firstDate : initial,
      firstDate: firstDate,
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: Colors.white,
            colorScheme: const ColorScheme.light(
              primary: Colors.redAccent,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (mounted) {
        setState(() {
          if (isStart) {
            startDate = picked;
            if (endDate.isBefore(startDate)) {
              endDate = picked;
            }
          } else {
            endDate = picked;
          }
        });
      }
    }
  }

  Future<void> _submitLeaveRequest() async {
    if (leaveType.trim().isEmpty || reasonController.text.trim().isEmpty) {
      CustomPopup.show(context, "Please fill all required fields");
      return;
    }

    if (userRole == 'head') {
      CustomPopup.show(context, "Heads cannot submit leave requests.");
      return;
    }

    setState(() => isSubmitting = true);
    showLoadingDialog(context);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final session = getCurrentSession();

      Map<String, dynamic> userData = {};
      String? docId;
      String? headUid;
      String collectionName = '';

      if (userRole == 'student') {
        collectionName = 'Students';
        final docSnap =
            await _firestore.collection(collectionName).doc(user.uid).get();
        if (!docSnap.exists) throw Exception('Student not found');
        userData = docSnap.data()!;
        docId = userData['sucId'];
        headUid = userData['headUid'];
      } else if (userRole == 'faculty') {
        collectionName = 'Faculties';
        final docSnap =
            await _firestore.collection(collectionName).doc(user.uid).get();
        if (!docSnap.exists) throw Exception('Faculty not found');
        userData = docSnap.data()!;
        docId = userData['fucId'];
        headUid = userData['headUid'];
      } else {
        throw Exception('Invalid user role');
      }

      if (docId == null || headUid == null) {
        throw Exception('User data is incomplete');
      }

      final docRef = _firestore.collection('leaveRequests').doc(docId);

      final newLeave = {
        'leaveId': DateTime.now().millisecondsSinceEpoch.toString(),
        'type': leaveType,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'startTime': '${startTime.hour}:${startTime.minute}',
        'endTime': '${endTime.hour}:${endTime.minute}',
        'reason': reasonController.text.trim(),
        'remarks': isExtendedRequest ? 'Extend Leave' : 'Submit Request',
        'status': 'Pending',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      final Map<String, dynamic> leaveData = {
        'name': userData['fullName'],
        'email': userData['email'],
        'headUid': headUid,
        'sessions': {
          session: FieldValue.arrayUnion([newLeave]),
        },
      };

      if (userRole == 'student') {
        leaveData['sucId'] = userData['sucId'];
        leaveData['courseName'] = userData['course'];
        leaveData['duration'] = userData['courseDuration'];
        leaveData['facultyUid'] = userData['facultyUid'];
      } else if (userRole == 'faculty') {
        leaveData['fucId'] = userData['fucId'];
      }

      await docRef.set(leaveData, SetOptions(merge: true));

      final settingsDoc =
          await _firestore
              .collection('notificationSettings')
              .doc(headUid)
              .get();
      final bool isPushEnabled = settingsDoc.data()?['push'] ?? true;
      final bool isInAppEnabled = settingsDoc.data()?['inApp'] ?? true;

      try {
        final headQuery =
            await _firestore.collection('Heads').doc(headUid).get();
        if (headQuery.exists) {
          final headData = headQuery.data();
          final token = headData?['fcmToken'];

          if (isPushEnabled && token != null && token.toString().isNotEmpty) {
            await FirebaseNotificationHelper.sendNotificationFromApp(
              fcmToken: token,
              title: 'New Leave Request',
              body: '${userData['fullName']} has submitted a leave request',
            );
          }
        }
      } catch (e) {
        print('❌ Error while sending push notification to Head: $e');
      }

      if (isInAppEnabled) {
        await _firestore.collection('notifications').add({
          'recipientId': headUid,
          'title': 'New Leave Request',
          'message': '${userData['fullName']} has submitted a leave request.',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'type': 'leaveRequest',
          'senderId': user.uid,
          'senderName': userData['fullName'],
          'senderProfileUrl': userData['profilePictureUrl'] ?? '',
          'targetId': docId,
          'targetType': 'leaveRequest',
        });
      }

      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) Navigator.pop(context);
      if (mounted)
        CustomPopup.show(context, "Leave request submitted successfully");

      if (mounted) {
        setState(() {
          leaveStatus = 'Pending';
          leaveUpdatedAt = DateTime.now();
          buttonLocked = true;
          buttonText = 'Pending';
        });
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Something went wrong: $e")));
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? startTime : endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: Colors.white,
            colorScheme: const ColorScheme.light(
              primary: Colors.redAccent,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final now = DateTime.now();
      final DateTime selectedDate = isStart ? startDate : endDate;
      final DateTime selectedDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        picked.hour,
        picked.minute,
      );

      if (selectedDateTime.isBefore(now)) {
        CustomPopup.show(context, "Cannot select past time.");
        return;
      }

      if (mounted) {
        setState(() {
          if (isStart) {
            startTime = picked;
          } else {
            endTime = picked;
          }
        });
      }
    }
  }

  void showLoadingDialog(BuildContext context) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return const Center(child: GradientSpinner());
      },
    );
  }

  void updateButtonStateBasedOnStatus() {
    if (leaveStatus == 'Pending') {
      buttonLocked = true;
      buttonText = 'Pending';
    } else if (leaveStatus == 'Approved') {
      if (isExtendedRequest) {
        if (lastLeaveEndDate != null &&
            DateTime.now().isAfter(lastLeaveEndDate!)) {
          buttonLocked = false;
          buttonText = 'Submit Request';
          isExtendedRequest = false;
          leaveStatus = 'None';
        } else {
          buttonLocked = true;
          buttonText = 'Approved (extended)';
        }
      } else {
        final diff =
            leaveUpdatedAt != null
                ? DateTime.now().difference(leaveUpdatedAt!)
                : Duration.zero;
        if (diff.inMinutes >= 15) {
          buttonLocked = false;
          buttonText = 'Extend Leave';
          isExtendedRequest = true;
        } else {
          buttonLocked = true;
          buttonText = 'Approved (waiting...)';
        }
      }
    } else if (leaveStatus == 'Declined') {
      final diff =
          leaveUpdatedAt != null
              ? DateTime.now().difference(leaveUpdatedAt!)
              : Duration.zero;
      if (diff.inMinutes >= 5) {
        buttonLocked = false;
        buttonText = 'Submit Request';
        isExtendedRequest = false;
      } else {
        buttonLocked = true;
        buttonText = 'Declined (wait 5 min)';
      }
    } else {
      buttonLocked = false;
      buttonText = 'Submit Request';
      isExtendedRequest = false;
    }
  }

  Future<void> checkLeaveStatusFromFirestore() async {
    final user = _auth.currentUser;
    if (user == null || userRole.isEmpty) return;

    final session = getCurrentSession();
    String collectionName = userRole == 'faculty' ? 'Faculties' : 'Students';
    String docIdField = userRole == 'faculty' ? 'fucId' : 'sucId';
    String? docId;

    final userDocSnap =
        await _firestore.collection(collectionName).doc(user.uid).get();
    if (!userDocSnap.exists) return;

    final userDoc = userDocSnap.data();
    docId = userDoc?[docIdField];
    if (docId == null || docId.isEmpty) return;

    final docSnap =
        await _firestore.collection('leaveRequests').doc(docId).get();

    if (!docSnap.exists) {
      if (mounted) {
        setState(() {
          leaveStatus = 'None';
          leaveUpdatedAt = null;
          lastLeaveEndDate = null;
          updateButtonStateBasedOnStatus();
        });
      }
      return;
    }

    final data = docSnap.data();
    final currentLeaves = data?['sessions']?[session];

    if (currentLeaves != null &&
        currentLeaves is List &&
        currentLeaves.isNotEmpty) {
      final latest = currentLeaves.last;
      leaveStatus = latest['status'] ?? 'None';
      lastLeaveEndDate = (latest['endDate'] as Timestamp).toDate();
      leaveUpdatedAt = (latest['updatedAt'] as Timestamp).toDate();
      isExtendedRequest = (latest['remarks'] ?? '')
          .toString()
          .toLowerCase()
          .contains('extend');
      hasExtendedOnce = isExtendedRequest;
    } else if (data != null && data.containsKey('lastDeclined')) {
      final declined = data['lastDeclined'];
      leaveStatus = declined['status'];
      leaveUpdatedAt = (declined['updatedAt'] as Timestamp).toDate();
      lastLeaveEndDate = null;
    } else {
      leaveStatus = 'None';
      leaveUpdatedAt = null;
      lastLeaveEndDate = null;
    }

    if (mounted) {
      setState(() {
        updateButtonStateBasedOnStatus();
      });
    }
  }

  Future<void> _loadAllData() async {
    if (mounted) setState(() => isLoadingData = true);
    await loadUserProfileInfo();
    await calculateUsedLeaves();
    await checkLeaveStatusFromFirestore();
    if (mounted) setState(() => isLoadingData = false);
  }

  Future<void> _loadSessionLeaves(String sessionName) async {
    final user = _auth.currentUser;
    if (user == null || userRole.isEmpty) return;
    String? docId;

    try {
      if (userRole == 'student') {
        final docSnap =
            await _firestore.collection('Students').doc(user.uid).get();
        if (docSnap.exists) docId = docSnap.data()?['sucId'];
      } else if (userRole == 'faculty') {
        final docSnap =
            await _firestore.collection('Faculties').doc(user.uid).get();
        if (docSnap.exists) docId = docSnap.data()?['fucId'];
      }
      if (docId == null || docId.isEmpty) return;

      final docSnap =
          await _firestore.collection('leaveRequests').doc(docId).get();
      if (!docSnap.exists) return;

      final data = docSnap.data();
      final allLeaves = <Map<String, dynamic>>[];

      if (data != null && data.containsKey('sessions')) {
        final Map<String, dynamic> sessionsMap = Map<String, dynamic>.from(
          data['sessions'],
        );
        if (sessionsMap.containsKey(sessionName)) {
          final List<dynamic> userLeaves = sessionsMap[sessionName];
          final now = DateTime.now();

          for (var leave in userLeaves) {
            final DateTime end = (leave['endDate'] as Timestamp).toDate();
            final String? endTimeStr = leave['endTime'];
            final DateTime endDateTime = DateTime(
              end.year,
              end.month,
              end.day,
              int.parse(endTimeStr?.split(':')[0] ?? '18'),
              int.parse(endTimeStr?.split(':')[1] ?? '0'),
            );
            if ((leave['status'] == 'Approved') && now.isAfter(endDateTime)) {
              allLeaves.add({
                'type': leave['type'],
                'startDate': (leave['startDate'] as Timestamp).toDate(),
                'endDate': end,
                'startTime': leave['startTime'],
                'endTime': endTimeStr,
                'reason': leave['reason'],
                'remarks': leave['remarks'] ?? 'Leave Request',
              });
            }
          }
        }
      }
      if (mounted) setState(() => sessionLeaves = allLeaves);
    } catch (e) {
      print("❌ Error loading session leaves: $e");
    }
  }

  String getCurrentSession() {
    final now = DateTime.now();
    final year = now.month >= 4 ? now.year : now.year - 1;
    return "$year-${year + 1}";
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
          print('Error parsing sessions: $e');
        }
      }
    }

    final sortedList = sessions.toList()..sort((a, b) => b.compareTo(a));

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
            height: MediaQuery.of(context).size.height * 0.25,
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
                    if (mounted) {
                      setState(() {
                        selectedSession = session;
                      });
                    }
                    _loadSessionLeaves(session);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showLeaveTypeDialog() {
    String? tempSelected = leaveType;
    final types = ['Annual Leave', 'Quarterly Leave'];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            "Select Leave Type",
            style: TextStyle(fontFamily: 'Gilroy-Bold', fontSize: 20),
          ),
          content: SizedBox(
            height: MediaQuery.of(context).size.height * 0.25,
            width: MediaQuery.of(context).size.width * 0.9,
            child: ListView.builder(
              itemCount: types.length,
              itemBuilder: (context, index) {
                final label = types[index];
                return RadioListTile<String>(
                  value: label,
                  groupValue: tempSelected,
                  title: Text(label),
                  activeColor: Colors.redAccent,
                  onChanged: (val) {
                    Navigator.pop(context);
                    if (mounted) {
                      setState(() {
                        leaveType = val!;
                      });
                    }
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.grey.withOpacity(0.2),
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 26, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Leave Request',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Gilroy-Bold',
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body:
          isLoadingData
              ? const Center(child: GradientSpinner())
              : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C2230),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage:
                                    (profilePictureUrl != null &&
                                            profilePictureUrl!.isNotEmpty)
                                        ? NetworkImage(profilePictureUrl!)
                                        : null,
                                child:
                                    (profilePictureUrl == null ||
                                            profilePictureUrl!.isEmpty)
                                        ? SvgPicture.asset(
                                          'assets/icons/users.svg',
                                          width: 28,
                                          height: 28,
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
                                      userName.isNotEmpty
                                          ? userName
                                          : 'Loading...',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontFamily: 'Gilroy-Bold',
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      userId.isNotEmpty ? userId : '',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.white70,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (usedLeaveLabel.isNotEmpty)
                                Expanded(
                                  child: Text(
                                    'Used: $usedLeaveLabel',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                      fontFamily: 'Gilroy-Regular',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              if (remainingLeaveLabel.isNotEmpty)
                                Text(
                                  'Remaining: $remainingLeaveLabel',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                    fontFamily: 'Gilroy-Regular',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F7FB),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 45,
                            width: double.infinity,
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(40),
                            ),
                            child: Stack(
                              children: [
                                AnimatedAlign(
                                  duration: const Duration(milliseconds: 200),
                                  alignment:
                                      isPastRequestSelected
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                  child: Container(
                                    width:
                                        MediaQuery.of(context).size.width / 2 -
                                        30,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(40),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          if (mounted)
                                            setState(
                                              () =>
                                                  isPastRequestSelected = false,
                                            );
                                        },
                                        child: Container(
                                          alignment: Alignment.center,
                                          child: Text(
                                            'New Request',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  !isPastRequestSelected
                                                      ? Colors.black
                                                      : Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          if (mounted)
                                            setState(
                                              () =>
                                                  isPastRequestSelected = true,
                                            );
                                        },
                                        child: Container(
                                          alignment: Alignment.center,
                                          child: Text(
                                            'Past Requests',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  isPastRequestSelected
                                                      ? Colors.black
                                                      : Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (!isPastRequestSelected) ...[
                            const Text('Type *'),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _showLeaveTypeDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(leaveType)),
                                    const Icon(Icons.arrow_drop_down),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text('Start Date *'),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _selectDate(context, true),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Text(
                                        DateFormat(
                                          'dd MMM yyyy',
                                        ).format(startDate),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                InkWell(
                                  onTap: () => _selectTime(context, true),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Text(startTime.format(context)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text('End Date *'),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _selectDate(context, false),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Text(
                                        DateFormat(
                                          'dd MMM yyyy',
                                        ).format(endDate),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                InkWell(
                                  onTap: () => _selectTime(context, false),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Text(endTime.format(context)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text('Reason *'),
                            const SizedBox(height: 6),
                            TextField(
                              controller: reasonController,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter your reason',
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(
                                    color: Colors.black,
                                    width: 1,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.all(14),
                              ),
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                            ),
                          ],
                          if (isPastRequestSelected) ...[
                            const SizedBox(height: 1),
                            InkWell(
                              onTap: _showSessionDialog,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        selectedSession ?? 'Select Session',
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    ),
                                    const Icon(Icons.arrow_drop_down),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (sessionLeaves.isNotEmpty) ...[
                              const Text("Total Leaves in this session:"),
                              const SizedBox(height: 5),
                              ...sessionLeaves.map((leave) {
                                final int totalDays =
                                    leave['endDate']
                                        .difference(leave['startDate'])
                                        .inDays +
                                    1;
                                return Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 30),
                                          Text(
                                            "Start: ${DateFormat('dd MMM yyyy').format(leave['startDate'])} ${leave['startTime'] ?? ''}",
                                          ),
                                          Text(
                                            "End: ${DateFormat('dd MMM yyyy').format(leave['endDate'])} ${leave['endTime'] ?? ''}",
                                          ),
                                          Text("Reason: ${leave['reason']}"),
                                          Text(
                                            "Remarks: ${leave['remarks'] ?? 'Leave Request'}",
                                          ),
                                        ],
                                      ),
                                      Positioned(
                                        top: 0,
                                        left: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 11,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            "Leaves: $totalDays",
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade200,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            leave['type'],
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (!isPastRequestSelected)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                buttonLocked ? Colors.grey : Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 0,
                          ),
                          onPressed:
                              buttonLocked
                                  ? null
                                  : () {
                                    InternetUtils.checkAndRunAsync(
                                      context: context,
                                      onConnected: () async {
                                        await _submitLeaveRequest();
                                        if (mounted) {
                                          setState(() {
                                            leaveStatus = 'Pending';
                                            leaveUpdatedAt = DateTime.now();
                                            updateButtonStateBasedOnStatus();
                                          });
                                        }
                                      },
                                    );
                                  },
                          child: Text(
                            buttonText,
                            style: const TextStyle(
                              fontFamily: 'Gilroy-Bold',
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 20,
                    ),
                  ],
                ),
              ),
    );
  }
}
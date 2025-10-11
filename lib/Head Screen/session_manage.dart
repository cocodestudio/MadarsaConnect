import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:madarsaConnect/Head%20Screen/previous_session.dart';
import '../Data/dynamic_popup.dart';
import '../Data/loader.dart';
import '../Home Screen/home_screen.dart';
import '../utils/firebase_notification_helper.dart';

class SessionManagementScreen extends StatefulWidget {
  final String headUid;

  const SessionManagementScreen({super.key, required this.headUid});

  @override
  _SessionManagementScreenState createState() =>
      _SessionManagementScreenState();
}

class _SessionManagementScreenState extends State<SessionManagementScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  Map<String, dynamic>? _selectedCourse;
  Map<String, dynamic>? _selectedDuration;
  String? _selectedTerm;

  List<Map<String, dynamic>> _courses = [];

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    setState(() => _isLoading = true);
    try {
      final courseSnapshot =
          await FirebaseFirestore.instance
              .collection('courses')
              .where('headUid', isEqualTo: widget.headUid)
              .get();

      final fetchedCourses =
          courseSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] as String?,
              'duration': data['duration'] as int?,
            };
          }).toList();

      setState(() {
        _courses = fetchedCourses;
      });
    } catch (e) {
      if (mounted) {
        CustomPopup.show(context, 'Failed to fetch courses: $e');
      }
      print('Error fetching courses: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    HapticFeedback.lightImpact();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2050),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.redAccent,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          if (_startDate != null && picked.isBefore(_startDate!)) {
            CustomPopup.show(context, 'End date cannot be before start date.');
            return;
          }
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _createSession() async {
    if (_selectedCourse == null ||
        _selectedDuration == null ||
        _selectedTerm == null ||
        _startDate == null ||
        _endDate == null) {
      CustomPopup.show(context, 'Please fill all session details.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final sessionData = {
        'course': _selectedCourse!['name'],
        'duration': _selectedDuration!['name'],
        'term': _selectedTerm,
        'yearNumber': _selectedDuration!['number'],
      };

      final overlappingSessionSnapshot =
          await FirebaseFirestore.instance
              .collection('sessions')
              .where('headUid', isEqualTo: widget.headUid)
              .where('course', isEqualTo: sessionData['course'])
              .where('duration', isEqualTo: sessionData['duration'])
              .where('term', isEqualTo: sessionData['term'])
              .where(
                'endDate',
                isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!),
              )
              .limit(1)
              .get();

      bool isOverlapping = false;
      if (overlappingSessionSnapshot.docs.isNotEmpty) {
        for (final doc in overlappingSessionSnapshot.docs) {
          final existingStartDate =
              (doc.data()['startDate'] as Timestamp).toDate();
          if (existingStartDate.isBefore(_endDate!)) {
            isOverlapping = true;
            break;
          }
        }
      }

      if (isOverlapping) {
        CustomPopup.show(
          context,
          'A session for ${sessionData['course']} - ${sessionData['duration']} (${sessionData['term']}) is already overlapping with the selected dates.',
        );
        setState(() => _isLoading = false);
        return;
      }

      DocumentReference sessionRef =
          FirebaseFirestore.instance.collection('sessions').doc();

      await sessionRef.set({
        'headUid': widget.headUid,
        'course': sessionData['course'],
        'duration': sessionData['duration'],
        'term': sessionData['term'],
        'yearNumber': sessionData['yearNumber'],
        'startDate': Timestamp.fromDate(_startDate!),
        'endDate': Timestamp.fromDate(_endDate!),
        'createdAt': FieldValue.serverTimestamp(),
      });

      final studentsSnapshot =
          await FirebaseFirestore.instance
              .collection('Students')
              .where('headUid', isEqualTo: widget.headUid)
              .get();

      final facultiesSnapshot =
          await FirebaseFirestore.instance
              .collection('Faculties')
              .where('headUid', isEqualTo: widget.headUid)
              .get();

      final allUsers = [...studentsSnapshot.docs, ...facultiesSnapshot.docs];

      for (var userDoc in allUsers) {
        final userId = userDoc.id;
        final notificationTitle = 'New Academic Session';
        final notificationBody =
            'A new academic session has been created by the administration.';
        final settingsDoc =
            await FirebaseFirestore.instance
                .collection('notificationSettings')
                .doc(userId)
                .get();
        final bool isPushEnabled = settingsDoc.data()?['push'] ?? true;
        final bool isInAppEnabled = settingsDoc.data()?['inApp'] ?? true;
        final token = userDoc.data()['fcmToken'];

        if (isPushEnabled && token != null && token.toString().isNotEmpty) {
          try {
            await FirebaseNotificationHelper.sendNotificationFromApp(
              fcmToken: token,
              title: notificationTitle,
              body: notificationBody,
            );
          } catch (e) {
            print('❌ Error sending push notification to user $userId: $e');
          }
        }

        if (isInAppEnabled) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'recipientId': userId,
            'title': notificationTitle,
            'message': notificationBody,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'type': 'newSession',
            'senderId': widget.headUid,
            'senderName': 'Admin',
            'targetId': null,
            'targetType': null,
          });
        }
      }

      CustomPopup.show(context, 'Session created successfully!');
      setState(() {
        _selectedCourse = null;
        _selectedDuration = null;
        _selectedTerm = null;
        _startDate = null;
        _endDate = null;
      });
    } catch (e) {
      CustomPopup.show(context, 'Failed to create session: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSelectorDialog({
    required BuildContext context,
    required String title,
    required List<Map<String, dynamic>> options,
    required void Function(Map<String, dynamic>) onSelected,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      pageBuilder: (_, __, ___) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                ...options.map((option) {
                  final optionName = option['name'] as String;
                  return GestureDetector(
                    onTap: () {
                      onSelected(option);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Text(
                        optionName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

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
          'Session Management',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Gilroy-Bold',
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body:
          _isLoading
              ? const Center(child: GradientSpinner())
              : SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.06,
                  vertical: screenWidth * 0.04,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: screenWidth * 0.02),
                    SelectorCard(
                      value: _selectedCourse?['name'] ?? 'Select Course',
                      onTap: () {
                        final options =
                            _courses
                                .map(
                                  (c) => {
                                    'name': c['name'] as String,
                                    'duration': c['duration'] as int?,
                                  },
                                )
                                .toList();
                        if (options.isEmpty) {
                          CustomPopup.show(
                            context,
                            'No courses found. Please add a course first.',
                          );
                          return;
                        }
                        _showSelectorDialog(
                          context: context,
                          title: 'Select Course',
                          options: options,
                          onSelected: (course) {
                            setState(() {
                              _selectedCourse = course;
                              _selectedDuration = null;
                            });
                          },
                        );
                      },
                    ),
                    SizedBox(height: screenWidth * 0.04),
                    SelectorCard(
                      value: _selectedDuration?['name'] ?? 'Select Duration',
                      onTap: () {
                        if (_selectedCourse == null) {
                          CustomPopup.show(
                            context,
                            'Please select a course first.',
                          );
                          return;
                        }

                        final options = <Map<String, dynamic>>[];
                        final duration =
                            _selectedCourse!['duration'] as int? ?? 1;
                        final yearSuffixes = ['st', 'nd', 'rd', 'th'];
                        for (int i = 1; i <= duration; i++) {
                          final suffix =
                              (i <= 3 && i > 0) ? yearSuffixes[i - 1] : 'th';
                          options.add({'name': '$i$suffix Year', 'number': i});
                        }

                        _showSelectorDialog(
                          context: context,
                          title: 'Select Duration',
                          options: options,
                          onSelected: (duration) {
                            setState(() {
                              _selectedDuration = duration;
                            });
                          },
                        );
                      },
                    ),
                    SizedBox(height: screenWidth * 0.04),
                    SelectorCard(
                      value: _selectedTerm ?? 'Select Term',
                      onTap: () {
                        final options = [
                          {'name': 'Odd Term'},
                          {'name': 'Even Term'},
                        ];
                        _showSelectorDialog(
                          context: context,
                          title: 'Select Term',
                          options: options,
                          onSelected: (term) {
                            setState(() {
                              _selectedTerm = term['name'] as String;
                            });
                          },
                        );
                      },
                    ),
                    SizedBox(height: screenWidth * 0.04),
                    DateSelectorCard(
                      selectedDate: _startDate,
                      onTap: () => _selectDate(context, true),
                      borderColor: Colors.black12,
                      labelText: 'Select Start Date',
                    ),
                    SizedBox(height: screenWidth * 0.04),
                    DateSelectorCard(
                      selectedDate: _endDate,
                      onTap: () => _selectDate(context, false),
                      borderColor: Colors.black12,
                      labelText: 'Select End Date',
                    ),
                    SizedBox(height: screenWidth * 0.08),
                    SizedBox(
                      height: screenWidth * 0.15,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _isLoading ? null : _createSession,
                        borderRadius: BorderRadius.circular(screenWidth * 0.04),
                        child: Container(
                          alignment: Alignment.center,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(
                              screenWidth * 0.04,
                            ),
                          ),
                          child:
                              _isLoading
                                  ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                  : const Text(
                                    'Create Session',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                        ),
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.04),
                    SizedBox(
                      height: screenWidth * 0.15,
                      child: OutlinedButton(
                        onPressed: () {
                          navigateWithPremiumTransition(
                            context,
                            PreviousSessionsScreen(headUid: widget.headUid),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Colors.redAccent,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              screenWidth * 0.04,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Show Previous Sessions',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.08),
                  ],
                ),
              ),
    );
  }
}

class SelectorCard extends StatelessWidget {
  final String value;
  final VoidCallback onTap;

  const SelectorCard({super.key, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.06,
          vertical: screenWidth * 0.05,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(screenWidth * 0.04),
          border: Border.all(color: Colors.black12, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 15, color: Colors.black),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}

class DateSelectorCard extends StatelessWidget {
  final DateTime? selectedDate;
  final VoidCallback onTap;
  final Color borderColor;
  final String labelText;

  const DateSelectorCard({
    super.key,
    required this.selectedDate,
    required this.onTap,
    required this.borderColor,
    required this.labelText,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final formattedDate =
        selectedDate != null
            ? DateFormat('d MMMM yyyy').format(selectedDate!)
            : labelText;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.06,
          vertical: screenWidth * 0.05,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(screenWidth * 0.04),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              color: Colors.redAccent,
              size: screenWidth * 0.06,
            ),
            SizedBox(width: screenWidth * 0.04),
            Text(
              formattedDate,
              style: const TextStyle(fontSize: 15, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color bgColor;
  final Color textColor;

  const InfoCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.06),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(screenWidth * 0.04),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 16, color: textColor.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../Data/loader.dart';
import '../Data/dynamic_popup.dart';
import '../l10n/app_localizations.dart';

class MarkFacultyAttendanceScreen extends StatefulWidget {
  const MarkFacultyAttendanceScreen({super.key});

  @override
  State<MarkFacultyAttendanceScreen> createState() =>
      _MarkFacultyAttendanceScreenState();
}

class _MarkFacultyAttendanceScreenState
    extends State<MarkFacultyAttendanceScreen> {
  bool isLoading = true;
  bool isPresent = true;
  String facultyName = '';
  String? headUid;
  String? sessionId;
  String? facultyId;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => isLoading = true);
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.userNotLoggedIn,
        );
        setState(() => isLoading = false);
      }
      return;
    }

    try {
      facultyId = user.uid;

      final facultyDoc =
          await _firestore.collection('Faculties').doc(facultyId).get();
      if (facultyDoc.exists) {
        facultyName = facultyDoc.data()?['fullName'] ?? 'No Name';
        headUid = facultyDoc.data()?['headUid'];
      } else {
        throw Exception(AppLocalizations.of(context)!.facultyRecordNotFound);
      }

      if (headUid != null) {
        final sessionSnap =
            await _firestore
                .collection('sessions')
                .where('headUid', isEqualTo: headUid)
                .orderBy('createdAt', descending: true)
                .limit(1)
                .get();

        if (sessionSnap.docs.isNotEmpty) {
          sessionId = sessionSnap.docs.first.id;
        } else {
          throw Exception(AppLocalizations.of(context)!.noActiveSession);
        }
      } else {
        throw Exception(AppLocalizations.of(context)!.institutionNotFound);
      }

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final docId = '${today}_$facultyId';
      final attendanceDoc =
          await _firestore.collection('faculty_attendance').doc(docId).get();

      if (attendanceDoc.exists) {
        isPresent = attendanceDoc.data()?['status'] == 'Present';
      }
    } catch (e) {
      if (mounted) {
        CustomPopup.show(
          context,
          '${AppLocalizations.of(context)!.error}: ${e.toString()}',
        );
      }
    }

    setState(() => isLoading = false);
  }

  Future<void> _submitAttendance() async {
    if (sessionId == null || facultyId == null) {
      CustomPopup.show(
        context,
        AppLocalizations.of(context)!.missingSessionFacultyId,
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: GradientSpinner()),
    );

    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final docId = '${today}_$facultyId';
      final docRef = _firestore.collection('faculty_attendance').doc(docId);

      final attendanceData = {
        'faculty_id': facultyId,
        'name': facultyName,
        'date': today,
        'status': isPresent ? 'Present' : 'Absent',
        'marked_by': facultyId,
        'sessionId': sessionId,
      };

      await docRef.set(attendanceData, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.attendanceSaved,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        CustomPopup.show(
          context,
          '${AppLocalizations.of(context)!.errorSavingAttendance}: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat(
      'EEEE, MMMM dd, yyyy',
    ).format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.grey.withOpacity(0.2),
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.markMyAttendance,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child:
            isLoading
                ? const Center(child: GradientSpinner())
                : Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.todaysDate,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 32,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                AppLocalizations.of(
                                  context,
                                )!.helloFaculty(facultyName),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppLocalizations.of(
                                  context,
                                )!.markAttendanceStatus,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 40),
                              GestureDetector(
                                onTap:
                                    () =>
                                        setState(() => isPresent = !isPresent),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  width: 130,
                                  height: 50,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isPresent
                                            ? Colors.green.shade400
                                            : Colors.red.shade400,
                                    borderRadius: BorderRadius.circular(25),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            isPresent
                                                ? Colors.green.withOpacity(0.3)
                                                : Colors.red.withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      AnimatedAlign(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        alignment: Alignment.centerLeft,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            left: 15.0,
                                          ),
                                          child: Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.present,
                                            style: TextStyle(
                                              color:
                                                  isPresent
                                                      ? Colors.white
                                                      : Colors.white
                                                          .withOpacity(0.0),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      AnimatedAlign(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        alignment: Alignment.centerRight,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            right: 15.0,
                                          ),
                                          child: Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.absent,
                                            style: TextStyle(
                                              color:
                                                  !isPresent
                                                      ? Colors.white
                                                      : Colors.white
                                                          .withOpacity(0.0),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      AnimatedAlign(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeIn,
                                        alignment:
                                            isPresent
                                                ? Alignment.centerRight
                                                : Alignment.centerLeft,
                                        child: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                          ),
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
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitAttendance,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.confirmSubmit,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}

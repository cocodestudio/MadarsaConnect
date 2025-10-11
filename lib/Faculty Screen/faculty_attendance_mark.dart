import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';

// Asegúrate de que la ruta de importación sea correcta para tu proyecto
import '../Data/loader.dart';
import '../Data/dynamic_popup.dart';

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
      // Si no hay usuario, salir
      if (mounted) {
        CustomPopup.show(context, '❌ Error: Not logged in.');
        setState(() => isLoading = false);
      }
      return;
    }

    try {
      facultyId = user.uid;

      // 1. Obtener datos del profesor y su headUid
      final facultyDoc =
          await _firestore.collection('Faculties').doc(facultyId).get();
      if (facultyDoc.exists) {
        facultyName = facultyDoc.data()?['fullName'] ?? 'No Name';
        headUid = facultyDoc.data()?['headUid'];
      } else {
        throw Exception("Faculty record not found.");
      }

      // 2. Obtener la sesión activa usando el headUid
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
          throw Exception("No active session found for your institution.");
        }
      } else {
        throw Exception("Could not determine the institution (headUid).");
      }

      // 3. Comprobar si ya se ha marcado la asistencia hoy
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final docId = '${today}_$facultyId';
      final attendanceDoc =
          await _firestore.collection('faculty_attendance').doc(docId).get();

      if (attendanceDoc.exists) {
        isPresent = attendanceDoc.data()?['status'] == 'Present';
      }
    } catch (e) {
      if (mounted) {
        CustomPopup.show(context, '❌ Error: ${e.toString()}');
      }
    }

    setState(() => isLoading = false);
  }

  Future<void> _submitAttendance() async {
    if (sessionId == null || facultyId == null) {
      CustomPopup.show(
        context,
        '❌ Cannot save. Missing session or faculty ID.',
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
        'marked_by': facultyId, // Marcado por sí mismo
        'sessionId': sessionId,
      };

      await docRef.set(attendanceData, SetOptions(merge: true));

      Navigator.pop(context); // Cierra el loader
      CustomPopup.show(context, '✅ Attendance saved successfully!');
    } catch (e) {
      Navigator.pop(context); // Cierra el loader
      CustomPopup.show(context, '❌ Error saving attendance: $e');
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
        title: const Text(
          'Mark My Attendance',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Gilroy-Bold',
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
                      // --- Date Display ---
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
                              "TODAY'S DATE",
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
                                fontFamily: 'Gilroy-Bold',
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
                                "Hello, $facultyName!",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontFamily: 'Gilroy-Bold',
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Please mark your attendance status below.",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 40),
                              // --- Animated Toggle Switch ---
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
                                      // Text for "Present"
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
                                            'Present',
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
                                      // Text for "Absent"
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
                                            'Absent',
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
                                      // The moving circle
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

                      // --- Submit Button ---
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
                          child: const Text(
                            'Confirm & Submit',
                            style: TextStyle(
                              fontFamily: 'Gilroy-Bold',
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

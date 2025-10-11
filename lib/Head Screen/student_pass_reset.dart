import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;

import '../Data/dynamic_popup.dart';

class ResetStudentPasswordPage extends StatefulWidget {
  const ResetStudentPasswordPage({super.key});

  @override
  State<ResetStudentPasswordPage> createState() =>
      _ResetStudentPasswordPageState();
}

class _ResetStudentPasswordPageState extends State<ResetStudentPasswordPage> {
  final TextEditingController _sucIdController = TextEditingController();
  final FocusNode _sucIdFocusNode = FocusNode();

  bool _isLoading = false;
  Map<String, dynamic>? _studentData;
  String? _studentUid;
  bool _searchPerformed = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  @override
  void dispose() {
    _sucIdController.dispose();
    _sucIdFocusNode.dispose();
    super.dispose();
  }

  Future<void> _findStudentBySucId() async {
    _sucIdFocusNode.unfocus();
    if (_sucIdController.text.trim().isEmpty) {
      CustomPopup.show(context, "Please enter a SUC ID to search.");
      return;
    }

    setState(() {
      _isLoading = true;
      _searchPerformed = true;
      _studentData = null;
      _studentUid = null;
    });

    try {
      final sucId = _sucIdController.text.trim().toLowerCase();

      final querySnapshot =
          await _firestore
              .collection('Students')
              .where('sucId', isEqualTo: sucId)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _studentData = querySnapshot.docs.first.data();
          _studentUid = querySnapshot.docs.first.id;
        });
      }
    } catch (e) {
      CustomPopup.show(context, "Error searching for student: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_studentUid == null) {
      CustomPopup.show(context, "No student selected...");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        CustomPopup.show(context, "Please sign in first.");
        return;
      }

      final idToken = await user.getIdToken(true);
      final url = Uri.parse(
        "https://us-central1-madarsaconnect-c96d3.cloudfunctions.net/resetStudentPassword",
      );

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({"studentUid": _studentUid}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        _showSuccessDialog(data['message']);
      } else {
        CustomPopup.show(context, data['error'] ?? "Something went wrong");
      }
    } catch (e) {
      CustomPopup.show(context, "An unexpected error occurred: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: const Text(
              "Success!",
              style: TextStyle(fontFamily: 'Gilroy-Bold'),
            ),
            content: const Text(
              "Password has been reset to the default: 'mc@12345'",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _sucIdController.clear();
                    _studentData = null;
                    _studentUid = null;
                    _searchPerformed = false;
                  });
                },
                child: const Text(
                  "OK",
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
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
          icon: const Icon(Icons.arrow_back, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reset Student Password',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Gilroy-Bold',
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => _sucIdFocusNode.unfocus(),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset(
                        'assets/images/passwordIcon.png',
                        height: 120,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Find and Reset",
                        style: TextStyle(
                          fontSize: 24,
                          fontFamily: 'Gilroy-Bold',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Enter the student's SUC ID to find their profile and reset their password to the default.",
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 30),
                      TextField(
                        controller: _sucIdController,
                        focusNode: _sucIdFocusNode,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: "Enter SUC ID (e.g., suc0000001)",
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.redAccent,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _findStudentBySucId,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child:
                              _isLoading && _studentData == null
                                  ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text(
                                    "Find Student",
                                    style: TextStyle(
                                      fontFamily: 'Gilroy-Bold',
                                      fontSize: 16,
                                    ),
                                  ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildResultSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultSection() {
    if (_studentData != null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black, width: 1.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Student Found",
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'Gilroy-Bold',
                  color: Colors.black,
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person, color: Colors.redAccent),
                title: Text(_studentData!['fullName'] ?? 'N/A'),
                subtitle: const Text("Full Name"),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.school, color: Colors.redAccent),
                title: Text(_studentData!['course'] ?? 'N/A'),
                subtitle: const Text("Course"),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.email, color: Colors.redAccent),
                title: Text(_studentData!['email'] ?? 'N/A'),
                subtitle: const Text("Registered Email"),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _resetPassword,
                  icon:
                      _isLoading
                          ? Container(
                            width: 24,
                            height: 24,
                            padding: const EdgeInsets.all(2.0),
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                          : const Icon(Icons.lock_reset),
                  label: const Text("Reset Password to Default"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_searchPerformed && _studentData == null && !_isLoading) {
      return const Center(
        child: Text(
          "No student found with this SUC ID. Please check the ID and try again.",
          textAlign: TextAlign.center,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

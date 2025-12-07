import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import '../Data/dynamic_popup.dart';
import '../l10n/app_localizations.dart';

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
      CustomPopup.show(
        context,
        AppLocalizations.of(context)!.enterSucIdToSearch,
      );
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
      if (mounted) {
        CustomPopup.show(
          context,
          "${AppLocalizations.of(context)!.errorSearchingStudent}: $e",
        );
      }
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
      CustomPopup.show(
        context,
        AppLocalizations.of(context)!.noStudentSelected,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        CustomPopup.show(context, AppLocalizations.of(context)!.signInFirst);
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
        if (mounted) {
          _showSuccessDialog(data['message']);
        }
      } else {
        if (mounted) {
          CustomPopup.show(
            context,
            data['error'] ?? AppLocalizations.of(context)!.somethingWentWrong,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        CustomPopup.show(
          context,
          "${AppLocalizations.of(context)!.unexpectedError}: $e",
        );
      }
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
            title: Text(
              AppLocalizations.of(context)!.success,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(AppLocalizations.of(context)!.passwordResetMessage),
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
                child: Text(
                  AppLocalizations.of(context)!.ok,
                  style: const TextStyle(color: Colors.redAccent),
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
        title: Text(
          AppLocalizations.of(context)!.resetStudentPassword,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
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
                      Text(
                        AppLocalizations.of(context)!.findAndReset,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.resetPasswordDescription,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 30),
                      TextField(
                        controller: _sucIdController,
                        focusNode: _sucIdFocusNode,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText:
                              AppLocalizations.of(context)!.enterSucIdHint,
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
                                  : Text(
                                    AppLocalizations.of(context)!.findStudent,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
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
              Text(
                AppLocalizations.of(context)!.studentFound,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person, color: Colors.redAccent),
                title: Text(
                  _studentData!['fullName'] ?? AppLocalizations.of(context)!.na,
                ),
                subtitle: Text(AppLocalizations.of(context)!.fullName),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.school, color: Colors.redAccent),
                title: Text(
                  _studentData!['course'] ?? AppLocalizations.of(context)!.na,
                ),
                subtitle: Text(AppLocalizations.of(context)!.course),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.email, color: Colors.redAccent),
                title: Text(
                  _studentData!['email'] ?? AppLocalizations.of(context)!.na,
                ),
                subtitle: Text(AppLocalizations.of(context)!.registeredEmail),
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
                  label: Text(AppLocalizations.of(context)!.resetToDefault),
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
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noStudentFoundSuc,
          textAlign: TextAlign.center,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

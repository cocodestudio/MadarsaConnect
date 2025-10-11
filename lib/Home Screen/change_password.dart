import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../Data/dynamic_popup.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _isCurrentHidden = true;
  bool _isNewHidden = true;
  bool _isConfirmHidden = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String? _validateNewPassword(String oldPass, String newPass, String confirm) {
    if (newPass.isEmpty || confirm.isEmpty) {
      return "⚠️ Please fill all fields";
    }
    if (newPass.length < 8) {
      return "⚠️ Password must be at least 8 characters";
    }
    final strongPattern = RegExp(
      r'^(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#\$%^&*]).{8,}$',
    );
    if (!strongPattern.hasMatch(newPass)) {
      return "⚠️ Password must contain uppercase, number & special char";
    }
    if (newPass != confirm) {
      return "⚠️ Passwords do not match";
    }
    if (oldPass == newPass) {
      return "⚠️ New password must be different from current password";
    }
    return null;
  }

  Future<void> _handleChangePassword() async {
    final oldPass = _currentPassword.text.trim();
    final newPass = _newPassword.text.trim();
    final confirm = _confirmPassword.text.trim();

    final validationError = _validateNewPassword(oldPass, newPass, confirm);
    if (validationError != null) {
      CustomPopup.show(context, validationError);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        CustomPopup.show(context, "❌ User not logged in.");
        return;
      }

      // 🔐 Re-authenticate with current password
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: oldPass,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPass);

      if (!mounted) return;
      CustomPopup.show(context, "✅ Password changed successfully");
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'wrong-password':
          msg = "❌ Current password is incorrect";
          break;
        case 'weak-password':
          msg = "⚠️ Password too weak";
          break;
        case 'requires-recent-login':
          msg = "⚠️ Please login again to change password";
          break;
        default:
          msg = "❌ ${e.message}";
      }
      CustomPopup.show(context, msg);
    } catch (e) {
      CustomPopup.show(context, "❌ Error: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField({
    required String hint,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback toggleVisibility,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey.shade700,
          ),
          onPressed: toggleVisibility,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.black),
        ),
      ),
      style: const TextStyle(color: Colors.black, fontSize: 14),
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
          'Change Password',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Gilroy-Bold',
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        height: 120,
                        child: Image.asset('assets/images/reset.png'),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'Secure Your Account',
                        style: TextStyle(
                          fontSize: 25,
                          fontFamily: 'Gilroy-Bold',
                        ),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'Please enter your current and new password',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontFamily: 'Gilroy-Medium',
                        ),
                      ),
                      const SizedBox(height: 18),

                      // TextFields
                      _buildTextField(
                        hint: "Current Password",
                        controller: _currentPassword,
                        obscureText: _isCurrentHidden,
                        toggleVisibility: () {
                          setState(() => _isCurrentHidden = !_isCurrentHidden);
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildTextField(
                        hint: "New Password",
                        controller: _newPassword,
                        obscureText: _isNewHidden,
                        toggleVisibility: () {
                          setState(() => _isNewHidden = !_isNewHidden);
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildTextField(
                        hint: "Confirm Password",
                        controller: _confirmPassword,
                        obscureText: _isConfirmHidden,
                        toggleVisibility: () {
                          setState(() => _isConfirmHidden = !_isConfirmHidden);
                        },
                      ),
                      const SizedBox(height: 15),

                      // Submit Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleChangePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child:
                            _isLoading
                                ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                                : const Text(
                                  "Change Password",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontFamily: 'Gilroy-Bold',
                                  ),
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
  }
}

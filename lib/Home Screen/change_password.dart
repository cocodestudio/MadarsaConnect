import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../Data/dynamic_popup.dart';
import '../l10n/app_localizations.dart';

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

  // Modified to use context for localization
  String? _validateNewPassword(
    BuildContext context,
    String oldPass,
    String newPass,
    String confirm,
  ) {
    final localizations = AppLocalizations.of(context)!;

    if (newPass.isEmpty || confirm.isEmpty) {
      return localizations.fillAllFields;
    }
    if (newPass.length < 8) {
      return localizations.passwordMinLength;
    }
    final strongPattern = RegExp(
      r'^(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#\$%^&*]).{8,}$',
    );
    if (!strongPattern.hasMatch(newPass)) {
      return localizations.passwordComplexity;
    }
    if (newPass != confirm) {
      return localizations.passwordsDoNotMatch;
    }
    if (oldPass == newPass) {
      return localizations.newPasswordDifferent;
    }
    return null;
  }

  Future<void> _handleChangePassword() async {
    final oldPass = _currentPassword.text.trim();
    final newPass = _newPassword.text.trim();
    final confirm = _confirmPassword.text.trim();

    final validationError = _validateNewPassword(
      context,
      oldPass,
      newPass,
      confirm,
    );
    if (validationError != null) {
      CustomPopup.show(context, validationError);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        if (mounted) {
          CustomPopup.show(
            context,
            AppLocalizations.of(context)!.userNotLoggedIn,
          );
        }
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
      CustomPopup.show(
        context,
        AppLocalizations.of(context)!.passwordChangedSuccess,
      );
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'wrong-password':
          msg = AppLocalizations.of(context)!.currentPasswordIncorrect;
          break;
        case 'weak-password':
          msg = AppLocalizations.of(context)!.passwordTooWeak;
          break;
        case 'requires-recent-login':
          msg = AppLocalizations.of(context)!.loginAgain;
          break;
        default:
          msg = "❌ ${e.message}";
      }
      if (mounted) CustomPopup.show(context, msg);
    } catch (e) {
      if (mounted) CustomPopup.show(context, "❌ Error: ${e.toString()}");
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
        title: Text(
          AppLocalizations.of(context)!.changePassword,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold, // Replaced Gilroy-Bold
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
                      Text(
                        AppLocalizations.of(context)!.secureYourAccount,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold, // Replaced Gilroy-Bold
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        AppLocalizations.of(context)!.enterPasswords,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500, // Replaced Gilroy-Medium
                        ),
                      ),
                      const SizedBox(height: 18),

                      // TextFields
                      _buildTextField(
                        hint: AppLocalizations.of(context)!.currentPassword,
                        controller: _currentPassword,
                        obscureText: _isCurrentHidden,
                        toggleVisibility: () {
                          setState(() => _isCurrentHidden = !_isCurrentHidden);
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildTextField(
                        hint: AppLocalizations.of(context)!.newPassword,
                        controller: _newPassword,
                        obscureText: _isNewHidden,
                        toggleVisibility: () {
                          setState(() => _isNewHidden = !_isNewHidden);
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildTextField(
                        hint: AppLocalizations.of(context)!.confirmPassword,
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
                                : Text(
                                  AppLocalizations.of(context)!.changePassword,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight.bold, // Replaced Gilroy-Bold
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

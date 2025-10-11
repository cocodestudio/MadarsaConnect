import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:madarsaConnect/Data/main_page.dart';
import 'package:madarsaConnect/Login%20&%20Signup%20Screen/create_account.dart';
import 'package:madarsaConnect/Login%20&%20Signup%20Screen/forgot_password.dart';
import 'package:madarsaConnect/Main%20Screen/admin_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Data/const.dart';
import '../Data/dynamic_popup.dart';
import '../Home Screen/home_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController _passwordController =
      TextEditingController();
  late final TextEditingController _inputController = TextEditingController();
  late final FocusNode _inputFocusNode = FocusNode();
  late final FocusNode _passwordFocusNode = FocusNode();

  bool _isObscure = true;
  bool isButtonActive = false;
  bool _isLoading = false;
  int _loginAttempts = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDarkMode = brightness == Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: isDarkMode ? Colors.black : Colors.white,
        statusBarIconBrightness:
            isDarkMode ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDarkMode ? Colors.black : Colors.white,
        systemNavigationBarIconBrightness:
            isDarkMode ? Brightness.light : Brightness.dark,
      ),
    );

    super.initState();
    _inputController.addListener(updateButtonState);
    _passwordController.addListener(updateButtonState);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _inputFocusNode.dispose();
    _passwordFocusNode.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void updateButtonState() {
    setState(() {
      isButtonActive =
          _inputController.text.isNotEmpty &&
          _passwordController.text.isNotEmpty &&
          _passwordController.text.length >= 8;
    });
  }

  void _unfocusTextFields() {
    _inputFocusNode.unfocus();
    _passwordFocusNode.unfocus();
  }

  Future<void> _cacheProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cachedProfile', jsonEncode(profile));
    await prefs.setInt(
      'cachedProfileAtMs',
      DateTime.now().millisecondsSinceEpoch,
    );
    await prefs.setString('cachedFullName', profile['fullName'] ?? '');
    await prefs.setString(
      'cachedProfileUrl',
      profile['profilePictureUrl'] ?? '',
    );
  }

  Future<void> _loadAndCacheProfileOnLogin(
    String collection,
    String uid,
  ) async {
    final snap = await _firestore.collection(collection).doc(uid).get();
    if (!snap.exists) return;

    final data = snap.data() as Map<String, dynamic>;
    final profile = {
      'role': data['role'],
      'fullName': data['fullName'] ?? '',
      'email': data['email'] ?? '',
      'profilePictureUrl': data['profilePictureUrl'] ?? '',
      'bio': data['bio'] ?? '',
      'gender': data['gender'],
      'course': data['course'],
      'courseDuration': data['courseDuration'],
      'hucId': data['hucId'],
      'fucId': data['fucId'],
      'sucId': data['sucId'],
    };

    await _cacheProfile(profile);
  }

  Future<void> _getAndSaveFcmToken(String uid, String role) async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;
      const collections = {
        'Head': 'Heads',
        'Faculty': 'Faculties',
        'Student': 'Students',
        'Admin': 'Admins',
      };

      final collectionName = collections[role];
      if (collectionName == null) {
        print("Invalid role provided: $role");
        return;
      }

      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(uid)
          .update({'fcmToken': fcmToken});
      print("FCM Token saved for $role with UID: $uid");
    } catch (e) {
      print("Error saving FCM token: $e");
    }
  }

  Future<void> _login() async {
    _unfocusTextFields();
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final blockedUntil = prefs.getInt('blockedUntil');
      if (blockedUntil != null &&
          DateTime.now().millisecondsSinceEpoch < blockedUntil) {
        final remainingTime =
            (blockedUntil - DateTime.now().millisecondsSinceEpoch) ~/ 1000;
        CustomPopup.show(
          context,
          'You are blocked for $remainingTime seconds due to multiple failed attempts.',
        );
        setState(() => _isLoading = false);
        return;
      }

      String input = _inputController.text.trim();
      String password = _passwordController.text.trim();
      if (!input.contains("@")) input = "$input@mc.com";

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: input,
        password: password,
      );
      final uid = userCredential.user!.uid;
      _resetLoginAttempts(prefs);
      await prefs.setString('user_email', input);

      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (userDoc.exists && userDoc.data()!.containsKey('role')) {
        final String role = userDoc.data()!['role'];
        const roleToCollectionMap = {
          'Head': 'Heads',
          'Faculty': 'Faculties',
          'Student': 'Students',
          'Admin': 'Admins',
        };

        final collectionName = roleToCollectionMap[role];

        if (collectionName != null) {
          await _saveRoleToPrefs(prefs, role, password: password);
          await _getAndSaveFcmToken(uid, role);
          await _loadAndCacheProfileOnLogin(collectionName, uid);

          if (context.mounted) {
            await Provider.of<ProfileProvider>(
              context,
              listen: false,
            ).loadUserProfile();
          }

          if (context.mounted) {
            if (role == 'Admin') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const AdminSupportScreen()),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => MainPage(userRole: role)),
              );
            }
          }
          return;
        }
      }
      await _auth.signOut();
      CustomPopup.show(
        context,
        'Access Denied: You do not have the required privileges.',
      );
    } on FirebaseAuthException catch (e) {
      await _handleAuthError(e);
    } catch (e) {
      CustomPopup.show(context, 'An unexpected error occurred: $e');
    } finally {
      if (context.mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveRoleToPrefs(
    SharedPreferences prefs,
    String role, {
    String? password,
  }) async {
    await prefs.setBool('isHead', role == 'Head');
    await prefs.setBool('isFaculty', role == 'Faculty');
    await prefs.setBool('isStudent', role == 'Student');
    await prefs.setString('user_role', role);

    if (role == 'Head' && password != null) {
      await prefs.setString('headPassword', password);
    }
  }

  Future<void> _resetLoginAttempts(SharedPreferences prefs) async {
    _loginAttempts = 0;
    await prefs.remove('loginAttempts');
    await prefs.remove('blockedUntil');
  }

  Future<void> _handleAuthError(FirebaseAuthException e) async {
    final prefs = await SharedPreferences.getInstance();
    String message;

    if (e.code == 'wrong-password') {
      _loginAttempts++;
      await prefs.setInt('loginAttempts', _loginAttempts);
    }

    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
        message = 'Invalid credentials. Please check your email and password.';
        if (_loginAttempts >= 3) {
          final blockedUntil =
              DateTime.now().millisecondsSinceEpoch + 15 * 60 * 1000;
          await prefs.setInt('blockedUntil', blockedUntil);
          message = 'Too many failed attempts. You are blocked for 15 minutes.';
          _loginAttempts = 0;
          await prefs.setInt('loginAttempts', _loginAttempts);
        }
        break;
      case 'user-disabled':
        message = 'This user account has been disabled.';
        break;
      case 'network-request-failed':
        message = 'Please check your internet connection and try again.';
        break;
      default:
        message = 'An authentication error occurred. Please try again later.';
        print('Firebase Auth Error: ${e.message}');
    }

    CustomPopup.show(context, (message));
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Stack(
            children: [
              GestureDetector(
                onTap: _unfocusTextFields,
                child: Container(
                  height: double.infinity,
                  color: Colors.white,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Padding(
                      padding: EdgeInsets.all(size.height * 0.030),
                      child: Column(
                        children: [
                          // Image
                          SizedBox(
                            width: size.width * 0.4,
                            height: size.height * 0.25,
                            child: Image.asset(image4, fit: BoxFit.contain),
                          ),

                          Text(
                            'Let’s Get You Secured',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Gilroy-Bold',
                              fontSize: size.width * 0.06,
                              color: Colors.black,
                            ),
                          ),

                          Text(
                            'Safe always with you.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: size.width * 0.045,
                              color: Colors.grey.withValues(alpha: 25),
                            ),
                          ),

                          SizedBox(height: size.height * 0.030),

                          TextField(
                            enableInteractiveSelection: false,
                            enableSuggestions: true,
                            autocorrect: true,
                            controller: _inputController,
                            focusNode: _inputFocusNode,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(color: Colors.black),
                            selectionControls: MaterialTextSelectionControls(),
                            onEditingComplete: () {
                              FocusScope.of(
                                context,
                              ).requestFocus(_passwordFocusNode);
                            },
                            onChanged: (value) {
                              setState(() {
                                if (!value.contains('@') ||
                                    !value.contains('.')) {
                                  _emailError = "Please enter a valid email";
                                } else {
                                  _emailError = null;
                                }
                              });
                            },
                            decoration: InputDecoration(
                              hintText: "Email",
                              hintStyle: const TextStyle(color: Colors.grey),
                              prefixIcon: Padding(
                                padding: EdgeInsets.all(size.width * 0.03),
                                child: SvgPicture.asset(
                                  userIcon,
                                  height: size.width * 0.06,
                                  width: size.width * 0.06,
                                  colorFilter: const ColorFilter.mode(
                                    Colors.black,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                              fillColor: whiteColor.withValues(alpha: 128),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: Colors.grey,
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
                            ),
                          ),

                          SizedBox(height: size.height * 0.010),
                          // Password Input Field
                          TextField(
                            enableInteractiveSelection: false,
                            controller: _passwordController,
                            obscureText: _isObscure,
                            focusNode: _passwordFocusNode,
                            keyboardType: TextInputType.text,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            onEditingComplete: () {
                              _unfocusTextFields();
                            },
                            style: const TextStyle(color: Colors.black),
                            onChanged: (value) {
                              setState(() {
                                if (value.length < 8) {
                                  _passwordError =
                                      "Password must be at least 8 characters";
                                } else {
                                  _passwordError = null;
                                }
                              });
                            },
                            decoration: InputDecoration(
                              filled: true,
                              hintText: "Password",
                              hintStyle: const TextStyle(color: Colors.grey),
                              prefixIcon: Padding(
                                padding: EdgeInsets.all(size.width * 0.03),
                                child: SvgPicture.asset(
                                  keyIcon,
                                  height: size.width * 0.06,
                                  width: size.width * 0.06,
                                  colorFilter: const ColorFilter.mode(
                                    Colors.black,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                              suffixIcon: SizedBox(
                                height: size.width * 0.06,
                                width: size.width * 0.06,
                                child: IconButton(
                                  iconSize: 20,
                                  icon: Icon(
                                    _isObscure
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey.shade700,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isObscure = !_isObscure;
                                    });
                                  },
                                ),
                              ),
                              fillColor: Colors.white,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: Colors.grey,
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
                            ),
                          ),

                          SizedBox(height: size.height * 0.020),

                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: isButtonActive ? _login : null,
                            child: Container(
                              alignment: Alignment.center,
                              width: double.infinity,
                              height: size.height * 0.070,
                              decoration: BoxDecoration(
                                color:
                                    isButtonActive
                                        ? Colors.redAccent
                                        : Colors.redAccent.withValues(
                                          alpha: 0.5,
                                        ), //Continue button opacity
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child:
                                  _isLoading
                                      ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text(
                                        "Continue",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'Gilroy-Bold',
                                          fontSize: 18,
                                        ),
                                      ),
                            ),
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: () {
                                  navigateWithPremiumTransition(
                                    context,
                                    const ForgotPasswordPage(),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  splashFactory: NoSplash.splashFactory,
                                  elevation: 0,
                                  padding: EdgeInsets.zero,
                                ),
                                child: Text(
                                  "Forgot Password?",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: size.height * 0.02,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: size.width * 0.038,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        navigateWithPremiumTransition(context, CreateAccount());
                      },
                      child: Text(
                        "Register!",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: size.width * 0.038,
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
    );
  }
}

import 'package:flutter/material.dart';
import '../Home Screen/change_password.dart';
import '../Home Screen/notification_settings.dart';
import '../Home Screen/support_screen.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/manage_notifications': (context) => const ManageNotificationsScreen(),
  '/support_tickets': (context) => const SupportScreen(),
  '/password_settings': (context) => const ChangePasswordScreen(),
};
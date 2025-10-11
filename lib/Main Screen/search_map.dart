import 'package:flutter/material.dart';
import 'package:madarsaConnect/Home%20Screen/change_password.dart';
import 'package:madarsaConnect/Home%20Screen/support_screen.dart';
import '../Home Screen/notification_settings.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/manage_notifications': (context) => const ManageNotificationsScreen(),
  '/support_tickets': (context) => const SupportScreen(),
  '/password_settings': (context) => const ChangePasswordScreen(),
};
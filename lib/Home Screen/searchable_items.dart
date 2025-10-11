import 'package:flutter/material.dart';

class SearchableItem {
  final String title;
  final String subtitle;
  final String route;
  final IconData icon;

  const SearchableItem({
    required this.title,
    required this.subtitle,
    required this.route,
    required this.icon,
  });
}

final List<SearchableItem> allSearchableItems = [
  const SearchableItem(
    title: 'Manage Notifications',
    subtitle: 'Manage push and in-app alerts.',
    route: '/manage_notifications',
    icon: Icons.notifications_active,
  ),
  const SearchableItem(
    title: 'Change Password',
    subtitle: 'Change your password.',
    route: '/password_settings',
    icon: Icons.assignment,
  ),
  const SearchableItem(
    title: 'Support Tickets',
    subtitle: 'View and manage user support tickets.',
    route: '/support_tickets',
    icon: Icons.support_agent,
  ),
];

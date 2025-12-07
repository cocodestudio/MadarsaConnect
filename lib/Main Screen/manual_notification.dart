import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class BroadcastNotificationService {
  static Future<Map<String, dynamic>> sendBroadcastNotification({
    required String title,
    required String body,
  }) async {
    final url = Uri.parse(
      'https://us-central1-madarsaconnect-c96d3.cloudfunctions.net/sendBroadcastNotification',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'title': title, 'body': body}),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Broadcast request sent successfully.',
        };
      } else {
        debugPrint(
          'Failed to send broadcast. Status code: ${response.statusCode}',
        );
        debugPrint('Response body: ${response.body}');
        return {'success': false, 'message': 'Server error: ${response.body}'};
      }
    } catch (e) {
      debugPrint('Error sending broadcast request: $e');
      return {'success': false, 'message': 'Client-side error: $e'};
    }
  }
}

class BroadcastNotificationScreen extends StatefulWidget {
  const BroadcastNotificationScreen({Key? key}) : super(key: key);

  @override
  State<BroadcastNotificationScreen> createState() =>
      _BroadcastNotificationScreenState();
}

class _BroadcastNotificationScreenState
    extends State<BroadcastNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _handleSendNotification() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final String title = _titleController.text.trim();
    final String body = _bodyController.text.trim();

    final result = await BroadcastNotificationService.sendBroadcastNotification(
      title: title,
      body: body,
    );

    if (context.mounted) {
      if (result['success'] == true) {
        _titleController.clear();
        _bodyController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification sent to all users!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (context.mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Broadcast Notification'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 12.0),
                          Expanded(
                            child: Text(
                              'Notifications sent from here will go to ALL Heads, Faculties, and Students.',
                              style: TextStyle(color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title (Required)',
                        hintText: 'e.g., "Urgent Meeting"',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12.0)),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Title cannot be empty';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _bodyController,
                      decoration: const InputDecoration(
                        labelText: 'Message (Required)',
                        hintText: 'Enter the full message body...',
                        prefixIcon: Icon(Icons.message_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12.0)),
                        ),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Message cannot be empty';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24.0),
                    SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: FilledButton.icon(
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
                                : const Icon(Icons.send_rounded),
                        label: Text(
                          _isLoading ? 'Sending...' : 'Send to All',
                          style: const TextStyle(fontSize: 16),
                        ),
                        onPressed: _isLoading ? null : _handleSendNotification,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

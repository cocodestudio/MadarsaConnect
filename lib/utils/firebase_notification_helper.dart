import 'package:http/http.dart' as http;
import 'dart:convert';

class FirebaseNotificationHelper {
  static Future<void> sendNotificationFromApp({
    required String fcmToken,
    required String title,
    required String body,
  }) async {
    final url = Uri.parse(
      'https://us-central1-madarsaconnect-c96d3.cloudfunctions.net/sendLeaveNotification',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'fcmToken': fcmToken, 'title': title, 'body': body}),
    );
  }
}

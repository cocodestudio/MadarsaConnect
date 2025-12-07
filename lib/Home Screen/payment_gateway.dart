import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:madarsaconnect/Home%20Screen/pending_payment.dart';
import '../Data/dynamic_popup.dart';
import '../Data/loader.dart';
import '../l10n/app_localizations.dart';
import '../utils/firebase_notification_helper.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> planDetails;
  const PaymentScreen({super.key, required this.planDetails});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final TextEditingController _utrController = TextEditingController();
  bool _isVerifying = false;
  String? _qrCodeUrl;
  bool _isQrLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQrCode();
  }

  Future<void> _loadQrCode() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('Config')
              .doc('paymentInfo')
              .get();
      if (mounted && doc.exists && doc.data()!.containsKey('qrCodeUrl')) {
        setState(() {
          _qrCodeUrl = doc.data()!['qrCodeUrl'];
        });
      }
    } catch (e) {
      debugPrint('Failed to load QR code: $e');
      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.couldNotLoadQrCode,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isQrLoading = false;
        });
      }
    }
  }

  Future<void> _handleVerification() async {
    final utr = _utrController.text.trim();
    if (utr.isEmpty) {
      CustomPopup.show(context, AppLocalizations.of(context)!.pleaseEnterUtr);
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception(AppLocalizations.of(context)!.userNotLoggedIn);
      }

      await FirebaseFirestore.instance.collection('subscriptionRequests').add({
        'userId': user.uid,
        'email': user.email,
        'planName': widget.planDetails['planName'],
        'price': widget.planDetails['price'],
        'utrNumber': utr,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
      _utrController.clear();

      try {
        final adminQuery =
            await FirebaseFirestore.instance
                .collection('Admins')
                .limit(1)
                .get();

        if (adminQuery.docs.isNotEmpty) {
          final adminDoc = adminQuery.docs.first;
          final adminToken = adminDoc.data()['fcmToken'];
          final adminUid = adminDoc.id;

          if (adminToken != null && adminToken.toString().isNotEmpty) {
            await FirebaseNotificationHelper.sendNotificationFromApp(
              fcmToken: adminToken,
              title: 'New Subscription Request',
              body:
                  '${user.email} has submitted a subscription request for the ${widget.planDetails['planName']} plan.',
            );
          }
          await FirebaseFirestore.instance.collection('notifications').add({
            'recipientId': adminUid,
            'title': 'New Subscription Request',
            'message':
                '${user.email} has requested the ${widget.planDetails['planName']} plan.',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'type': 'subscriptionRequest',
            'senderId': user.uid,
            'senderName': user.email,
          });
        }
      } catch (e) {
        print('❌ Failed to send notification to admin: $e');
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const PendingScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      print("Error submitting payment request: $e");
      if (mounted) {
        CustomPopup.show(
          context,
          '${AppLocalizations.of(context)!.failedToSubmitRequest}: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _utrController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocalizations.of(context)!.completePayment,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.scanQrInstructions,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      AppLocalizations.of(context)!.scanQrForPayment,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AspectRatio(
                      aspectRatio: 1.0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child:
                            _isQrLoading
                                ? const Center(child: GradientSpinner())
                                : _qrCodeUrl != null
                                ? Image.network(
                                  _qrCodeUrl!,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (
                                    context,
                                    child,
                                    loadingProgress,
                                  ) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value:
                                            loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                                : null,
                                      ),
                                    );
                                  },
                                  errorBuilder:
                                      (context, error, stackTrace) => Center(
                                        child: Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.qrCodeLoadingFailed,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                )
                                : Center(
                                  child: Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.qrCodeNotAvailable,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _utrController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.enterUtrNumber,
                  labelStyle: TextStyle(color: Colors.black.withOpacity(0.6)),
                  hintText: AppLocalizations.of(context)!.utrExample,
                  hintStyle: TextStyle(color: Colors.black.withOpacity(0.4)),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.5)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Colors.redAccent,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isVerifying ? null : _handleVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child:
                    _isVerifying
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: GradientSpinner(),
                        )
                        : Text(
                          AppLocalizations.of(context)!.verifyPayment,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

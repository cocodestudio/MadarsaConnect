import 'package:flutter/material.dart';
import 'package:madarsaConnect/Data/loader.dart';
import 'package:madarsaConnect/Home%20Screen/payment_gateway.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:madarsaConnect/Home%20Screen/pending_payment.dart';
import 'package:intl/intl.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  int _selectedPlanIndex = 1;
  bool _isLoading = true;
  String? _userStatus;
  Map<String, dynamic>? _approvedPlanDetails;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _checkSubscriptionStatus();
  }

  Future<void> _checkSubscriptionStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final approvedSnapshot =
        await FirebaseFirestore.instance
            .collection('subscriptionRequests')
            .where('userId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'approved')
            .orderBy('verificationTimestamp', descending: true)
            .limit(1)
            .get();

    if (approvedSnapshot.docs.isNotEmpty) {
      final data = approvedSnapshot.docs.first.data();
      final planName = data['planName'] as String;
      final timestamp = data['verificationTimestamp'] as Timestamp;
      final verificationDate = timestamp.toDate();

      DateTime expiryDate;
      if (planName.contains('5 Years')) {
        expiryDate = verificationDate.add(const Duration(days: 365 * 5));
      } else if (planName.contains('Monthly')) {
        expiryDate = verificationDate.add(const Duration(days: 30));
      } else {
        // Yearly
        expiryDate = verificationDate.add(const Duration(days: 365));
      }

      if (expiryDate.isBefore(DateTime.now())) {
        // Subscription is EXPIRED
        if (mounted) {
          setState(() {
            _userStatus = 'none';
            _isExpired = true;
            _isLoading = false;
          });
        }
      } else {
        // Subscription is ACTIVE
        if (mounted) {
          setState(() {
            _userStatus = 'approved';
            _approvedPlanDetails = data;
            _isLoading = false;
          });
        }
      }
      return;
    }

    final pendingSnapshot =
        await FirebaseFirestore.instance
            .collection('subscriptionRequests')
            .where('userId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();

    if (pendingSnapshot.docs.isNotEmpty) {
      if (mounted) {
        setState(() {
          _userStatus = 'pending';
          _isLoading = false;
        });
      }
      _navigateToPendingScreen();
    } else {
      if (mounted) {
        setState(() {
          _userStatus = 'none';
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToPendingScreen() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const PendingScreen()),
      (Route<dynamic> route) => false,
    );
  }

  void _onPlanTapped(int index) {
    setState(() {
      _selectedPlanIndex = index;
    });
  }

  void _handleSubscription() {
    final selectedPlanDetails =
        _selectedPlanIndex == 0
            ? {'planName': '5 Years Plan', 'price': '4499'}
            : {'planName': 'Yearly Plan', 'price': '999'};

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaymentScreen(planDetails: selectedPlanDetails),
      ),
    );
  }

  void _showTermsAndConditions() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                const TermsAndConditionsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: GradientSpinner()),
      );
    }

    if (_userStatus == 'approved' && _approvedPlanDetails != null) {
      return ActiveSubscriptionScreen(planDetails: _approvedPlanDetails!);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 1),
              const Text(
                'Choose your plan',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Unlock exclusive features and enhance your experience.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              SubscriptionPlanCard(
                title: '5 Years Plan',
                price: '₹4499',
                features: const [
                  'All Yearly Plan features',
                  'All future updates included',
                  'Highest priority support',
                ],
                isHighlighted: _selectedPlanIndex == 0,
                onTap: () => _onPlanTapped(0),
              ),
              const SizedBox(height: 24),
              SubscriptionPlanCard(
                title: 'Yearly Plan',
                price: '₹999',
                tag: 'SAVE 15%',
                isHighlighted: _selectedPlanIndex == 1,
                features: const [
                  'Unlimited student accounts',
                  'Attendance tracking',
                  'Advanced analytics',
                  'Priority support',
                ],
                onTap: () => _onPlanTapped(1),
              ),
              const Spacer(flex: 3),
              ElevatedButton(
                onPressed: _handleSubscription,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: Text(
                  _isExpired ? 'Renew Subscription' : 'Continue',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _showTermsAndConditions,
                  child: const Text(
                    'Terms & Conditions',
                    style: TextStyle(
                      color: Colors.black,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

class ActiveSubscriptionScreen extends StatelessWidget {
  final Map<String, dynamic> planDetails;
  const ActiveSubscriptionScreen({super.key, required this.planDetails});

  @override
  Widget build(BuildContext context) {
    final String planName = planDetails['planName'] ?? 'N/A';
    final String price = '₹${planDetails['price'] ?? 'N/A'}';
    final Timestamp? timestamp =
        planDetails['verificationTimestamp'] as Timestamp?;

    DateTime? verificationDate;
    if (timestamp != null) {
      verificationDate = timestamp.toDate();
    }

    DateTime validityDate;
    if (planName.contains('5 Years')) {
      validityDate =
          verificationDate?.add(const Duration(days: 365 * 5)) ??
          DateTime.now().add(const Duration(days: 365 * 5));
    } else if (planName.contains('Monthly')) {
      validityDate =
          verificationDate?.add(const Duration(days: 30)) ??
          DateTime.now().add(const Duration(days: 30));
    } else {
      validityDate =
          verificationDate?.add(const Duration(days: 365)) ??
          DateTime.now().add(const Duration(days: 365));
    }

    final String formattedValidity = DateFormat(
      'dd MMMM, yyyy',
    ).format(validityDate);
    final int daysRemaining = validityDate.difference(DateTime.now()).inDays;

    final double progressValue =
        daysRemaining > 0
            ? 1 -
                (daysRemaining /
                    (planName.contains('5 Years')
                        ? (365 * 5)
                        : planName.contains('Monthly')
                        ? 30
                        : 365))
            : 1.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 100,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Subscription Active!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enjoy all premium features with your active plan.',
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.7),
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDFDFD),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                            Icons.star_rounded,
                            'Current Plan',
                            planName,
                            const Color(0xFFFF9800),
                          ),
                          const Divider(color: Colors.black12, height: 32),
                          _buildInfoRow(
                            Icons.payments_rounded,
                            'Amount Paid',
                            price,
                            Colors.green,
                          ),
                          const Divider(color: Colors.black12, height: 32),
                          _buildInfoRow(
                            Icons.calendar_month_rounded,
                            'Valid Until',
                            formattedValidity,
                            Colors.blue,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Days Remaining: $daysRemaining',
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progressValue,
                            backgroundColor: Colors.black12,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.green,
                            ),
                            borderRadius: BorderRadius.circular(5),
                            minHeight: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.home_rounded, color: Colors.white),
                  label: const Text(
                    'Go to Home',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String title,
    String value,
    Color iconColor,
  ) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 30),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.black.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SubscriptionPlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String? tag;
  final bool isHighlighted;
  final List<String> features;
  final VoidCallback onTap;

  const SubscriptionPlanCard({
    super.key,
    required this.title,
    required this.price,
    this.tag,
    this.isHighlighted = false,
    required this.features,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border:
              isHighlighted
                  ? Border.all(color: Colors.redAccent, width: 3)
                  : Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isHighlighted ? 0.1 : 0.05),
              blurRadius: isHighlighted ? 20 : 10,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                if (tag != null) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      tag!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  features
                      .map(
                        (feature) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Terms & Conditions',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'By subscribing, you agree to our terms of service and privacy policy.',
              style: TextStyle(
                color: Colors.black.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '1. Terms of Service',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'These terms govern your use of the application and its features. The subscription renews automatically unless canceled at least 24 hours before the end of the current period.',
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              '2. Privacy Policy',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We are committed to protecting your privacy. Data collected is used solely for improving our services and providing personalized content.',
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 24),
            const Text(
              '3. Billing and Payments',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your subscription will automatically renew at the end of each billing cycle (monthly or yearly), and your chosen payment method will be charged accordingly. We may, at our discretion, change pricing and features at any time, but you will be notified of this in advance. In case of failed payments, your subscription may be temporarily suspended.',
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              '4. Cancellation and Refunds',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You can cancel your subscription at any time. Even after cancellation, you will continue to have access to all features until the end of the current billing cycle. We do not provide any refunds for any active subscription period. Once cancelled, your account will be converted to a free plan.',
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              '5. Account Security',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You are responsible for the security of your account and for keeping your password confidential. Immediately notify us of any unauthorized use.',
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:madarsaconnect/Home%20Screen/payment_gateway.dart';
import 'package:madarsaconnect/Home%20Screen/pending_payment.dart';
import '../Data/loader.dart';
import '../l10n/app_localizations.dart';

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
        expiryDate = verificationDate.add(const Duration(days: 365));
      }

      if (expiryDate.isBefore(DateTime.now())) {
        if (mounted) {
          setState(() {
            _userStatus = 'none';
            _isExpired = true;
            _isLoading = false;
          });
        }
      } else {
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
            ? {'planName': '5 Years Plan', 'price': '19999'}
            : {'planName': 'Yearly Plan', 'price': '4999'};

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
        backgroundColor: Color(0xFFF9F9F9),
        body: Center(child: GradientSpinner()),
      );
    }

    if (_userStatus == 'approved' && _approvedPlanDetails != null) {
      return ActiveSubscriptionScreen(planDetails: _approvedPlanDetails!);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F9F9),
        elevation: 0,
        surfaceTintColor: const Color(0xFFF9F9F9),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)!.choosePlan,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context)!.unlockFeatures,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SubscriptionPlanCard(
                title: AppLocalizations.of(context)!.plan5Years,
                price: '₹19999',
                tag: AppLocalizations.of(context)!.save20,
                features: [
                  AppLocalizations.of(context)!.allYearlyFeatures,
                  AppLocalizations.of(context)!.futureUpdates,
                  AppLocalizations.of(context)!.highestPriority,
                ],
                isHighlighted: _selectedPlanIndex == 0,
                onTap: () => _onPlanTapped(0),
              ),
              const SizedBox(height: 24),
              SubscriptionPlanCard(
                title: AppLocalizations.of(context)!.yearlyPlan,
                price: '₹4999',
                isHighlighted: _selectedPlanIndex == 1,
                features: [
                  AppLocalizations.of(context)!.unlimitedAccounts,
                  AppLocalizations.of(context)!.attendanceTracking,
                  AppLocalizations.of(context)!.advancedAnalytics,
                  AppLocalizations.of(context)!.prioritySupport,
                ],
                onTap: () => _onPlanTapped(1),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _handleSubscription,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: Text(
                  _isExpired
                      ? AppLocalizations.of(context)!.renewSubscription
                      : AppLocalizations.of(context)!.continueText,
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
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.termsConditions,
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
    DateTime? verificationDate = timestamp?.toDate();

    DateTime validityDate;
    int totalDays;
    if (planName.contains('5 Years')) {
      totalDays = 365 * 5;
    } else if (planName.contains('Monthly')) {
      totalDays = 30;
    } else {
      totalDays = 365;
    }
    validityDate =
        verificationDate?.add(Duration(days: totalDays)) ??
        DateTime.now().add(Duration(days: totalDays));

    final String formattedValidity = DateFormat(
      'dd MMMM, yyyy',
    ).format(validityDate);
    final int daysRemaining = validityDate.difference(DateTime.now()).inDays;

    final double progressValue =
        daysRemaining > 0 ? (daysRemaining / totalDays) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
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
                    Text(
                      AppLocalizations.of(context)!.subscriptionActive,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.enjoyFeatures,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.7),
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                            Icons.star_rounded,
                            AppLocalizations.of(context)!.currentPlan,
                            planName,
                            const Color(0xFFFF9800),
                          ),
                          const Divider(color: Colors.black12, height: 32),
                          _buildInfoRow(
                            Icons.payments_rounded,
                            AppLocalizations.of(context)!.amountPaid,
                            price,
                            Colors.green,
                          ),
                          const Divider(color: Colors.black12, height: 32),
                          _buildInfoRow(
                            Icons.calendar_month_rounded,
                            AppLocalizations.of(context)!.validUntil,
                            formattedValidity,
                            Colors.blue,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            AppLocalizations.of(
                              context,
                            )!.daysRemaining(daysRemaining.toString()),
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progressValue,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.green,
                              ),
                              minHeight: 10,
                            ),
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
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.home_rounded, color: Colors.white),
                  label: Text(
                    AppLocalizations.of(context)!.goToHome,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
  final List<String> features;
  final bool isHighlighted;
  final VoidCallback onTap;

  const SubscriptionPlanCard({
    super.key,
    required this.title,
    required this.price,
    this.tag,
    required this.features,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
                color: isHighlighted ? Colors.redAccent : Colors.grey[200]!,
                width: isHighlighted ? 2.0 : 1.0,
              ),
              boxShadow:
                  isHighlighted
                      ? [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.15),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ]
                      : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.grey[200]),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      features
                          .map((feature) => _buildFeatureRow(feature))
                          .toList(),
                ),
              ],
            ),
          ),
        ),
        if (tag != null)
          Positioned(
            top: -14,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Text(
                tag!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFeatureRow(String feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              feature,
              style: TextStyle(fontSize: 15, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppLocalizations.of(context)!.termsConditions,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.termsIntro,
              style: TextStyle(
                color: Colors.black.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ..._buildSection(
              AppLocalizations.of(context)!.termsTitle1,
              AppLocalizations.of(context)!.termsBody1,
            ),
            ..._buildSection(
              AppLocalizations.of(context)!.termsTitle2,
              AppLocalizations.of(context)!.termsBody2,
            ),
            ..._buildSection(
              AppLocalizations.of(context)!.termsTitle3,
              AppLocalizations.of(context)!.termsBody3,
            ),
            ..._buildSection(
              AppLocalizations.of(context)!.termsTitle4,
              AppLocalizations.of(context)!.termsBody4,
            ),
            ..._buildSection(
              AppLocalizations.of(context)!.termsTitle5,
              AppLocalizations.of(context)!.termsBody5,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSection(String title, String content) {
    return [
      Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black,
          fontSize: 18,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        content,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 24),
    ];
  }
}

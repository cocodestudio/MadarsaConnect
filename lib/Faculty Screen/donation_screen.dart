import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:madarsaConnect/Data/loader.dart';
import 'package:madarsaConnect/Data/dynamic_popup.dart';
import '../utils/firebase_notification_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';

// MAIN SCREEN WIDGET
class DonationScreen extends StatefulWidget {
  const DonationScreen({super.key});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _amountController = TextEditingController();
  String _selectedCategory = 'Sadaqah';
  late final AnimationController _buttonAnimationController;
  late final Animation<double> _buttonScaleAnimation;

  String? _donationQrUrl;
  bool _isQrLoading = true;
  // --- LOADER STATE (isVerifying) YAHAN SE HATA DIYA GAYA HAI ---

  final List<Map<String, dynamic>> donationCategories = [
    {'name': 'Sadaqah', 'icon': Icons.favorite_border},
    {'name': 'Zakat', 'icon': Icons.account_balance_wallet_outlined},
    {'name': 'Fitra', 'icon': Icons.local_dining_outlined},
    {'name': 'Imdad', 'icon': Icons.volunteer_activism_outlined},
    {'name': 'Hadiya', 'icon': Icons.card_giftcard_outlined},
    {'name': 'Others', 'icon': Icons.more_horiz},
  ];

  @override
  void initState() {
    super.initState();
    _buttonAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _buttonAnimationController.forward();
    _buttonScaleAnimation = CurvedAnimation(
      parent: _buttonAnimationController,
      curve: Curves.easeInOut,
    );
    _fetchAndPrecacheQrCode();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _buttonAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchAndPrecacheQrCode() async {
    if (mounted) setState(() => _isQrLoading = true);
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('adminSettings')
              .doc('qrCode')
              .get();
      if (doc.exists) {
        final url = doc.data()?['donationQrCodeUrl'];
        if (mounted) setState(() => _donationQrUrl = url);
        if (url != null && url.isNotEmpty) {
          if (!mounted) return;
          final imageProvider = NetworkImage(url);
          await precacheImage(imageProvider, context);
        }
      }
    } catch (e) {
      debugPrint('Error fetching QR code: $e');
    } finally {
      if (mounted) setState(() => _isQrLoading = false);
    }
  }

  void _onDonationTap() async {
    final double? amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      CustomPopup.show(context, 'Please enter a valid amount.');
      return;
    }

    final result = await showModalBottomSheet<bool?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _PaymentSheetContent(
            amount: amount,
            selectedCategory: _selectedCategory,
            donationQrUrl: _donationQrUrl,
            amountController: _amountController,
          ),
    );
    if (result == true && mounted) {}
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
          icon: const Icon(Icons.arrow_back, size: 26, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Donation',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Gilroy-Bold',
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body:
          _isQrLoading
              ? const Center(child: GradientSpinner())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select a Donation Category',
                      style: TextStyle(
                        fontFamily: 'Gilroy-Bold',
                        fontSize: 18,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children:
                          donationCategories
                              .map(
                                (category) => _buildCategoryChip(
                                  category['name'],
                                  category['icon'],
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Enter Amount',
                      style: TextStyle(
                        fontFamily: 'Gilroy-Bold',
                        fontSize: 18,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        fontFamily: 'Gilroy-Bold',
                        fontSize: 24,
                        color: Colors.black87,
                      ),
                      decoration: const InputDecoration(
                        prefixText: '₹',
                        prefixStyle: TextStyle(
                          fontFamily: 'Gilroy-Bold',
                          fontSize: 24,
                          color: Colors.black87,
                        ),
                        hintText: '0',
                        hintStyle: TextStyle(
                          fontFamily: 'Gilroy-Bold',
                          fontSize: 24,
                          color: Colors.black38,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          borderSide: BorderSide(
                            color: Color(0xFFE0E0E0),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          borderSide: BorderSide(
                            color: Color(0xFF42A5F5),
                            width: 2.0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildAmountButtons(),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTapDown: (_) => _buttonAnimationController.reverse(),
                        onTapUp: (_) => _buttonAnimationController.forward(),
                        onTap: _onDonationTap,
                        child: ScaleTransition(
                          scale: _buttonScaleAnimation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.redAccent.withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Text(
                              'Donate',
                              style: TextStyle(
                                fontFamily: 'Gilroy-Bold',
                                fontSize: 20,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => const DonationHistoryScreen(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(
                            color: Colors.redAccent,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: const Text(
                          'Show History',
                          style: TextStyle(
                            fontFamily: 'Gilroy-Bold',
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        'Your donation goes directly to the Madarsa account.',
                        style: TextStyle(
                          fontFamily: 'Gilroy-Regular',
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildCategoryChip(String name, IconData icon) {
    final bool isSelected = _selectedCategory == name;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = name;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.redAccent : const Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  isSelected
                      ? Colors.redAccent.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.redAccent : Colors.black54,
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                fontFamily: isSelected ? 'Gilroy-Bold' : 'Gilroy-Regular',
                fontSize: 16,
                color: isSelected ? Colors.redAccent.shade700 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountButtons() {
    final List<int> amounts = [500, 1000, 2000, 5000];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children:
          amounts
              .map(
                (amount) => GestureDetector(
                  onTap: () {
                    setState(() {
                      _amountController.text = amount.toString();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      '₹$amount',
                      style: const TextStyle(
                        fontFamily: 'Gilroy-Regular',
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }
}

// --- NAYA STATEFUL WIDGET JO BOTTOM SHEET KE LIYE BANAYA GAYA HAI ---
class _PaymentSheetContent extends StatefulWidget {
  final double amount;
  final String selectedCategory;
  final String? donationQrUrl;
  final TextEditingController amountController;

  const _PaymentSheetContent({
    required this.amount,
    required this.selectedCategory,
    required this.donationQrUrl,
    required this.amountController,
  });

  @override
  State<_PaymentSheetContent> createState() => _PaymentSheetContentState();
}

class _PaymentSheetContentState extends State<_PaymentSheetContent> {
  final TextEditingController _utrController = TextEditingController();
  bool _isVerifying = false; // Iski state ab is widget ke andar hai

  @override
  void dispose() {
    _utrController.dispose();
    super.dispose();
  }

  // Submit function ab is widget ke andar hai
  Future<void> _submitDonationRequest() async {
    final utr = _utrController.text.trim();

    if (utr.isEmpty) {
      if (mounted) CustomPopup.show(context, 'Please enter the UTR Number.');
      return;
    }

    if (mounted) setState(() => _isVerifying = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in.');

      String? headUid;
      String userName = "Anonymous";
      final userId = user.uid;
      DocumentSnapshot userDoc;

      userDoc =
          await FirebaseFirestore.instance
              .collection('Heads')
              .doc(userId)
              .get();
      //... (baaki logic same hai)
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>?;
        headUid = userId;
        userName = data?['fullName'] ?? "Anonymous";
      } else {
        userDoc =
            await FirebaseFirestore.instance
                .collection('Faculties')
                .doc(userId)
                .get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>?;
          headUid = data?['headUid'];
          userName = data?['fullName'] ?? "Anonymous";
        } else {
          userDoc =
              await FirebaseFirestore.instance
                  .collection('Students')
                  .doc(userId)
                  .get();
          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>?;
            headUid = data?['headUid'];
            userName = data?['fullName'] ?? "Anonymous";
          }
        }
      }

      if (headUid == null) throw Exception('Head account not found.');

      await FirebaseFirestore.instance.collection('donationRequests').add({
        'userId': user.uid,
        'headUid': headUid,
        'userEmail': user.email,
        'userName': userName,
        'category': widget.selectedCategory,
        'amount': widget.amount,
        'utrNumber': utr,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
      // ... (notification logic)
      final headDoc =
          await FirebaseFirestore.instance
              .collection('Heads')
              .doc(headUid)
              .get();
      if (headDoc.exists) {
        final data = headDoc.data() as Map<String, dynamic>?;
        final headToken = data?['fcmToken'];
        if (headToken != null && headToken.toString().isNotEmpty) {
          await FirebaseNotificationHelper.sendNotificationFromApp(
            fcmToken: headToken,
            title: 'New Donation Request',
            body:
                '$userName has submitted a donation of ₹${widget.amount.toStringAsFixed(2)}.',
          );
        }
      }

      _utrController.clear();
      widget.amountController.clear();

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint("Error submitting donation request: $e");
      if (mounted) {
        CustomPopup.show(context, 'Failed to submit request: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  Text(
                    '₹${widget.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontFamily: 'Gilroy-Bold',
                      fontSize: 48,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You are donating for: ${widget.selectedCategory}',
                    style: const TextStyle(
                      fontFamily: 'Gilroy-Regular',
                      fontSize: 18,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _buildPaymentCard(),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _utrController,
                    keyboardType: TextInputType.text,
                    style: const TextStyle(
                      fontFamily: 'Gilroy-Bold',
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Enter UTR Number / Transaction ID',
                      labelStyle: const TextStyle(
                        fontFamily: 'Gilroy-Regular',
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                      hintText: 'e.g., 123456789012',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Color(0xFFE0E0E0),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Colors.redAccent,
                          width: 2.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isVerifying ? null : _submitDonationRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        elevation: 0,
                      ),
                      child:
                          _isVerifying
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.0,
                                ),
                              )
                              : const Text(
                                'Verify Payment',
                                style: TextStyle(
                                  fontFamily: 'Gilroy-Bold',
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Your donation goes directly to the Madarsa account.',
                    style: TextStyle(
                      fontFamily: 'Gilroy-Regular',
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Scan to Pay',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child:
                  widget.donationQrUrl != null &&
                          widget.donationQrUrl!.isNotEmpty
                      ? Image.network(
                        widget.donationQrUrl!,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value:
                                  loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                            ),
                          );
                        },
                        errorBuilder:
                            (context, error, stackTrace) => const Center(
                              child: Text(
                                'QR Code failed to load',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.black87),
                              ),
                            ),
                      )
                      : const Center(
                        child: Text(
                          'QR Code not available',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- HISTORY SCREEN (NO CHANGES) ---
class DonationHistoryScreen extends StatelessWidget {
  const DonationHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Donation History')),
        body: const Center(child: Text('User not logged in.')),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.grey.withOpacity(0.2),
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 26, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Donation History',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Gilroy-Bold',
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('donationRequests')
                .where('userId', isEqualTo: user.uid)
                .orderBy('timestamp', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: GradientSpinner());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 80,
                    color: Colors.grey.withOpacity(0.5),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No donations made yet.',
                    style: TextStyle(
                      fontFamily: 'Gilroy-Regular',
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          final transactions = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction =
                  transactions[index].data() as Map<String, dynamic>;
              final category = transaction['category'] ?? 'N/A';
              final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
              final utrNumber = transaction['utrNumber'] ?? 'N/A';
              final status = transaction['status'] ?? 'pending';
              final timestamp = transaction['timestamp'] as Timestamp?;
              final formattedDate =
                  timestamp != null
                      ? DateFormat('MMM d, yyyy').format(timestamp.toDate())
                      : 'N/A';
              Color statusColor;
              switch (status) {
                case 'approved':
                  statusColor = Colors.green;
                  break;
                case 'rejected':
                  statusColor = Colors.red;
                  break;
                default:
                  statusColor = Colors.orange;
              }
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          category,
                          style: const TextStyle(
                            fontFamily: 'Gilroy-Bold',
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          '₹${amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontFamily: 'Gilroy-Bold',
                            fontSize: 16,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'UTR: $utrNumber',
                          style: const TextStyle(
                            fontFamily: 'Gilroy-Regular',
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'Gilroy-Bold',
                              fontSize: 12,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        formattedDate,
                        style: const TextStyle(
                          fontFamily: 'Gilroy-Regular',
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
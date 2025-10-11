import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../Data/loader.dart';
import '../Home Screen/kitchen.dart';

class DonationAnalyticsScreen extends StatefulWidget {
  final String headUid;

  const DonationAnalyticsScreen({super.key, required this.headUid});

  @override
  State<DonationAnalyticsScreen> createState() =>
      _DonationAnalyticsScreenState();
}

class _DonationAnalyticsScreenState extends State<DonationAnalyticsScreen> {
  String? _selectedCategory;

  void _handleBackButton() {
    if (_selectedCategory != null) {
      setState(() {
        _selectedCategory = null;
      });
    } else {
      Navigator.pop(context);
    }
  }

  void _showCashDonationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CashDonationSheet(headUid: widget.headUid),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedCategory != null) {
          setState(() {
            _selectedCategory = null;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.grey.withOpacity(0.2),
          surfaceTintColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 26),
            onPressed: _handleBackButton,
          ),
          title: Text(
            _selectedCategory == null ? 'Donation Board' : _selectedCategory!,
            style: const TextStyle(
              fontSize: 20,
              fontFamily: 'Gilroy-Bold',
              color: Colors.black,
            ),
          ),
          centerTitle: true,
        ),
        body:
            _selectedCategory == null
                ? _buildMainDashboard()
                : _buildTransactionHistory(),
      ),
    );
  }

  Widget _buildMainDashboard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('donationRequests')
          .where('headUid', isEqualTo: widget.headUid)
          .where('status', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: GradientSpinner());
        }
        if (!snapshot.hasData) {
          return _buildNoDataScreen();
        }

        final donations = snapshot.data!.docs;
        final Map<String, double> categoryTotals = {};
        double totalAmount = 0.0;
        final List<Color> palette = [
          Colors.redAccent,
          Colors.orange,
          Colors.purple,
          Colors.green,
          Colors.blue,
          Colors.teal,
        ];

        final List<String> allCategories = [
          'Sadaqah',
          'Zakat',
          'Fitra',
          'Imdad',
          'Hadiya',
          'Others',
        ];
        for (var category in allCategories) {
          categoryTotals[category] = 0.0;
        }

        for (var doc in donations) {
          final data = doc.data() as Map<String, dynamic>;
          final category = data['category'] as String? ?? 'Others';
          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

          if (allCategories.contains(category)) {
            totalAmount += amount;
            categoryTotals.update(
              category,
              (value) => value + amount,
              ifAbsent: () => amount,
            );
          } else {
            totalAmount += amount;
            categoryTotals.update(
              'Others',
              (value) => value + amount,
              ifAbsent: () => amount,
            );
          }
        }

        final List<_ChartData> chartData =
            categoryTotals.entries.where((e) => e.value > 0).map((e) {
              final index = allCategories.indexOf(e.key);
              return _ChartData(
                e.key,
                e.value,
                palette[index % palette.length],
              );
            }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPayByCashCard(),
              const SizedBox(height: 24),
              _buildAnalyticsCard(chartData, totalAmount),
              const SizedBox(height: 24),
              _buildCategoryList(categoryTotals, palette),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPayByCashCard() {
    return GestureDetector(
      onTap: _showCashDonationSheet,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1.5),
        ),
        child: const Row(
          children: [
            Icon(Icons.money_rounded, color: Colors.green, size: 32),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'Pay by Cash',
                style: TextStyle(
                  fontFamily: 'Gilroy-Bold',
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard(List<_ChartData> chartData, double totalAmount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Donations',
            style: TextStyle(
              fontFamily: 'Gilroy-Bold',
              fontSize: 20,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontFamily: 'Gilroy-Bold',
              fontSize: 32,
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(height: 20),
          if (chartData.isNotEmpty)
            SizedBox(
              height: 200,
              child: SfCircularChart(
                margin: EdgeInsets.zero,
                series: <CircularSeries>[
                  DoughnutSeries<_ChartData, String>(
                    dataSource: chartData,
                    pointColorMapper: (_ChartData data, _) => data.color,
                    xValueMapper: (_ChartData data, _) => data.label,
                    yValueMapper: (_ChartData data, _) => data.value,
                    innerRadius: '65%',
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: false,
                    ),
                  ),
                ],
                legend: Legend(
                  isVisible: true,
                  position: LegendPosition.right,
                  itemPadding: 8,
                  textStyle: const TextStyle(
                    fontFamily: 'Gilroy-Regular',
                    fontSize: 12,
                  ),
                  legendItemBuilder: (
                    String name,
                    dynamic series,
                    dynamic point,
                    int index,
                  ) {
                    return SizedBox(
                      width: 110,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: chartData[index].color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontFamily: 'Gilroy-Regular',
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(
    Map<String, double> categoryTotals,
    List<Color> palette,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Category Totals',
            style: TextStyle(
              fontFamily: 'Gilroy-Bold',
              fontSize: 20,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categoryTotals.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final category = categoryTotals.keys.elementAt(index);
              final amount = categoryTotals[category]!;
              final color = palette[index % palette.length];

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategory = category;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          category,
                          style: const TextStyle(
                            fontFamily: 'Gilroy-Regular',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '₹${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontFamily: 'Gilroy-Bold',
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('donationRequests')
              .where('headUid', isEqualTo: widget.headUid)
              .where('category', isEqualTo: _selectedCategory)
              .orderBy('timestamp', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: GradientSpinner());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoDataScreen(
            message: 'No transactions for this category yet.',
            icon: Icons.history,
          );
        }

        final transactions = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final transaction =
                transactions[index].data() as Map<String, dynamic>;
            final userName = transaction['userName'] ?? 'Unknown User';
            final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
            final utrNumber = transaction['utrNumber'] ?? 'N/A';
            final timestamp = transaction['timestamp'] as Timestamp?;
            final formattedDate =
                timestamp != null
                    ? DateFormat('MMM d, yyyy').format(timestamp.toDate())
                    : 'N/A';
            final formattedTime =
                timestamp != null
                    ? DateFormat('h:mm a').format(timestamp.toDate())
                    : 'N/A';

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        userName,
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
                  const SizedBox(height: 4),
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
                      Text(
                        '$formattedDate at $formattedTime',
                        style: const TextStyle(
                          fontFamily: 'Gilroy-Regular',
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CashDonationSheet extends StatefulWidget {
  final String headUid;
  const _CashDonationSheet({required this.headUid});

  @override
  State<_CashDonationSheet> createState() => _CashDonationSheetState();
}

class _CashDonationSheetState extends State<_CashDonationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _categoryDisplayController = TextEditingController();
  String? _selectedCategory;
  final List<String> _categories = [
    'Sadaqah',
    'Zakat',
    'Fitra',
    'Imdad',
    'Hadiya',
    'Others',
  ];
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _categoryDisplayController.dispose();
    super.dispose();
  }

  Future<void> _recordDonation() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in.');

      // Since this is for the head, the head is the user.
      final headDoc =
          await FirebaseFirestore.instance
              .collection('Heads')
              .doc(widget.headUid)
              .get();
      final userName = headDoc.data()?['fullName'] ?? 'Head (Cash)';

      await FirebaseFirestore.instance.collection('donationRequests').add({
        'userId': widget.headUid,
        'headUid': widget.headUid,
        'userName': userName,
        'userEmail': headDoc.data()?['email'] ?? 'N/A',
        'category': _selectedCategory,
        'amount': double.parse(_amountController.text.trim()),
        'utrNumber': 'CASH',
        'timestamp': FieldValue.serverTimestamp(),
        'paymentMethod': 'Cash',
        'status': 'approved',
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record donation: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showCategorySelectionDialog() async {
    final String? result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            title: const Text(
              'Select a Category',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Gilroy-Bold'),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 20.0),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final bool isSelected = _selectedCategory == category;
                  return ListTile(
                    title: Text(
                      category,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing:
                        isSelected
                            ? const Icon(
                              Icons.check_circle,
                              color: Colors.redAccent,
                            )
                            : null,
                    onTap: () => Navigator.pop(context, category),
                  );
                },
              ),
            ),
          ),
    );

    if (result != null) {
      setState(() {
        _selectedCategory = result;
        _categoryDisplayController.text = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Record Cash Donation',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontFamily: 'Gilroy-Bold',
                    color: Color(0xFF1B263B),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _amountController,
                  decoration: premiumInputDecoration('Amount (in ₹)'),
                  keyboardType: TextInputType.number,
                  validator:
                      (v) => v!.trim().isEmpty ? 'Amount is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _categoryDisplayController,
                  readOnly: true,
                  decoration: premiumInputDecoration(
                    'Select Category',
                  ).copyWith(
                    suffixIcon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.grey,
                    ),
                  ),
                  onTap: _showCategorySelectionDialog,
                  validator:
                      (v) => v!.trim().isEmpty ? 'Category is required' : null,
                ),
                const SizedBox(height: 32),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                      onPressed: _recordDonation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Record Donation',
                        style: TextStyle(fontFamily: 'Gilroy-Bold'),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartData {
  final String label;
  final double value;
  final Color color;

  _ChartData(this.label, this.value, this.color);
}

Widget _buildNoDataScreen({
  String message = 'No donations received yet.',
  IconData icon = Icons.pie_chart_outline,
}) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 80, color: Colors.grey.withOpacity(0.5)),
        const SizedBox(height: 24),
        Text(
          message,
          style: const TextStyle(
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

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Data/loader.dart';
import '../l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
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

  String _getLocalizedCategory(String key) {
    switch (key) {
      case 'Sadaqah':
        return AppLocalizations.of(context)!.sadaqah;
      case 'Zakat':
        return AppLocalizations.of(context)!.zakat;
      case 'Fitra':
        return AppLocalizations.of(context)!.fitra;
      case 'Imdad':
        return AppLocalizations.of(context)!.imdad;
      case 'Hadiya':
        return AppLocalizations.of(context)!.hadiya;
      case 'Others':
        return AppLocalizations.of(context)!.others;
      default:
        return key;
    }
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
            _selectedCategory == null
                ? AppLocalizations.of(context)!.donationBoard
                : _getLocalizedCategory(_selectedCategory!),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
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
      stream:
          FirebaseFirestore.instance
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
        child: Row(
          children: [
            const Icon(Icons.money_rounded, color: Colors.green, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.payByCash,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
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
          Text(
            AppLocalizations.of(context)!.totalDonations,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
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
                  textStyle: const TextStyle(fontSize: 12),
                  legendItemBuilder: (
                    String name,
                    dynamic series,
                    dynamic point,
                    int index,
                  ) {
                    // Localize category name in legend
                    String localizedName = _getLocalizedCategory(name);
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
                              localizedName,
                              style: const TextStyle(fontSize: 12),
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
          Text(
            AppLocalizations.of(context)!.categoryTotals,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
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
              final categoryKey = categoryTotals.keys.elementAt(index);
              final categoryLabel = _getLocalizedCategory(categoryKey);
              final amount = categoryTotals[categoryKey]!;
              final color = palette[index % palette.length];

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategory = categoryKey;
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
                          categoryLabel,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '₹${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
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
            message: AppLocalizations.of(context)!.noTransactionsCategory,
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
            final userName =
                transaction['userName'] ??
                AppLocalizations.of(context)!.unknownUser;
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
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '₹${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
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
                        '${AppLocalizations.of(context)!.utr}: $utrNumber',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '$formattedDate ${formattedTime}',
                        style: const TextStyle(
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

  Widget _buildNoDataScreen({
    String? message,
    IconData icon = Icons.pie_chart_outline,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 24),
          Text(
            message ?? AppLocalizations.of(context)!.noDonationsReceived,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
      if (user == null)
        throw Exception(AppLocalizations.of(context)!.userNotLoggedIn);

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
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.failedRecordDonation}: $e',
            ),
          ),
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
            title: Text(
              AppLocalizations.of(context)!.selectACategory,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 20.0),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  // Localize category
                  String localizedLabel = category;
                  switch (category) {
                    case 'Sadaqah':
                      localizedLabel = AppLocalizations.of(context)!.sadaqah;
                      break;
                    case 'Zakat':
                      localizedLabel = AppLocalizations.of(context)!.zakat;
                      break;
                    case 'Fitra':
                      localizedLabel = AppLocalizations.of(context)!.fitra;
                      break;
                    case 'Imdad':
                      localizedLabel = AppLocalizations.of(context)!.imdad;
                      break;
                    case 'Hadiya':
                      localizedLabel = AppLocalizations.of(context)!.hadiya;
                      break;
                    case 'Others':
                      localizedLabel = AppLocalizations.of(context)!.others;
                      break;
                  }

                  return ListTile(
                    title: Text(
                      localizedLabel,
                      style: TextStyle(
                        fontWeight:
                            _selectedCategory == category
                                ? FontWeight.bold
                                : FontWeight.normal,
                      ),
                    ),
                    trailing:
                        _selectedCategory == category
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
        // Display localized, store internal
        switch (result) {
          case 'Sadaqah':
            _categoryDisplayController.text =
                AppLocalizations.of(context)!.sadaqah;
            break;
          case 'Zakat':
            _categoryDisplayController.text =
                AppLocalizations.of(context)!.zakat;
            break;
          case 'Fitra':
            _categoryDisplayController.text =
                AppLocalizations.of(context)!.fitra;
            break;
          case 'Imdad':
            _categoryDisplayController.text =
                AppLocalizations.of(context)!.imdad;
            break;
          case 'Hadiya':
            _categoryDisplayController.text =
                AppLocalizations.of(context)!.hadiya;
            break;
          case 'Others':
            _categoryDisplayController.text =
                AppLocalizations.of(context)!.others;
            break;
          default:
            _categoryDisplayController.text = result;
        }
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
                Text(
                  AppLocalizations.of(context)!.recordCashDonation,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B263B),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _amountController,
                  decoration: premiumInputDecoration(
                    AppLocalizations.of(context)!.amountInRupees,
                  ),
                  keyboardType: TextInputType.number,
                  validator:
                      (v) =>
                          v!.trim().isEmpty
                              ? AppLocalizations.of(context)!.amountIsRequired
                              : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _categoryDisplayController,
                  readOnly: true,
                  decoration: premiumInputDecoration(
                    AppLocalizations.of(context)!.selectCategory,
                  ).copyWith(
                    suffixIcon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.grey,
                    ),
                  ),
                  onTap: _showCategorySelectionDialog,
                  validator:
                      (v) =>
                          v!.trim().isEmpty
                              ? AppLocalizations.of(context)!.categoryIsRequired
                              : null,
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
                      child: Text(
                        AppLocalizations.of(context)!.recordDonationBtn,
                        style: const TextStyle(fontWeight: FontWeight.bold),
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

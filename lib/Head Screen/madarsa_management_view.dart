import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../Data/loader.dart';
import '../l10n/app_localizations.dart';

class DashboardViewScreen extends StatefulWidget {
  const DashboardViewScreen({super.key});

  @override
  State<DashboardViewScreen> createState() => _DashboardViewScreenState();
}

class _DashboardViewScreenState extends State<DashboardViewScreen> {
  DateTime _selectedMonth = DateTime.now();
  DateTime _selectedYear = DateTime.now();

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: Colors.white,
            colorScheme: const ColorScheme.light(
              primary: Colors.redAccent,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = picked;
      });
    }
  }

  Future<void> _selectYear(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) {
        return Theme(
          data: Theme.of(context).copyWith(dialogBackgroundColor: Colors.white),
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(AppLocalizations.of(context)!.selectYear),
            content: SizedBox(
              width: 300,
              height: 300,
              child: YearPicker(
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDate: _selectedYear,
                selectedDate: _selectedYear,
                onChanged: (DateTime dateTime) {
                  setState(() {
                    _selectedYear = dateTime;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        );
      },
    );
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
          icon: const Icon(Icons.arrow_back, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.madarsaDashboard,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildExpenseSummary(),
            const SizedBox(height: 32),
            _buildInventorySummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('expenses').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: GradientSpinner());
        }

        final expenses = snapshot.data!.docs;
        final now = DateTime.now();

        final todayStart = DateTime(now.year, now.month, now.day);
        final selectedMonthStart = DateTime(
          _selectedMonth.year,
          _selectedMonth.month,
          1,
        );
        final selectedMonthEnd = DateTime(
          _selectedMonth.year,
          _selectedMonth.month + 1,
          0,
          23,
          59,
          59,
        );
        final selectedYearStart = DateTime(_selectedYear.year, 1, 1);
        final selectedYearEnd = DateTime(
          _selectedYear.year,
          12,
          31,
          23,
          59,
          59,
        );

        double todayTotal = 0;
        double monthTotal = 0;
        double yearTotal = 0;
        Map<String, double> monthCategoryTotals = {};

        for (var doc in expenses) {
          final data = doc.data() as Map<String, dynamic>;
          final date = (data['date'] as Timestamp).toDate();
          final amount = (data['amount'] as num).toDouble();
          final category = data['category'] as String? ?? 'Other';

          if (date.isAfter(todayStart)) todayTotal += amount;
          if (date.isAfter(selectedMonthStart) &&
              date.isBefore(selectedMonthEnd)) {
            monthTotal += amount;
            monthCategoryTotals[category] =
                (monthCategoryTotals[category] ?? 0) + amount;
          }
          if (date.isAfter(selectedYearStart) && date.isBefore(selectedYearEnd))
            yearTotal += amount;
        }

        final currencyFormat = NumberFormat.currency(
          locale: 'en_IN',
          symbol: '₹',
        );
        final isCurrentYear = _selectedYear.year == now.year;

        return Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: AppLocalizations.of(context)!.today,
                      amount: currencyFormat.format(todayTotal),
                      icon: Icons.today,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title:
                          isCurrentYear
                              ? AppLocalizations.of(context)!.thisYear
                              : _selectedYear.year.toString(),
                      amount: currencyFormat.format(yearTotal),
                      icon: Icons.calendar_today,
                      color: Colors.black,
                      onIconTap: () => _selectYear(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _PieChartCard(
              title: DateFormat.yMMMM().format(_selectedMonth),
              totalAmount: currencyFormat.format(monthTotal),
              categoryData: monthCategoryTotals,
              onIconTap: () => _selectMonth(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInventorySummary() {
    const double lowStockThreshold = 10.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.inventoryStatus,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('inventoryItems')
                  .orderBy('currentStock')
                  .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: GradientSpinner());

            final allItems = snapshot.data!.docs;
            final lowStockItems =
                allItems.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return (data['currentStock'] as num) <= lowStockThreshold;
                }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (lowStockItems.isNotEmpty) ...[
                  Card(
                    elevation: 0,
                    color: Colors.red.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.redAccent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                AppLocalizations.of(context)!.lowStockAlerts,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...lowStockItems
                              .map((doc) => _InventoryItemTile(doc: doc))
                              .toList(),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 30),
                ],
                Text(
                  AppLocalizations.of(context)!.allItems,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...allItems.map((doc) => _InventoryItemTile(doc: doc)).toList(),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final Color color;
  final VoidCallback? onIconTap;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    this.onIconTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              InkWell(
                onTap: onIconTap,
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(icon, color: color, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PieChartCard extends StatefulWidget {
  final String title;
  final String totalAmount;
  final Map<String, double> categoryData;
  final VoidCallback onIconTap;

  const _PieChartCard({
    required this.title,
    required this.totalAmount,
    required this.categoryData,
    required this.onIconTap,
  });

  @override
  State<_PieChartCard> createState() => _PieChartCardState();
}

class _PieChartCardState extends State<_PieChartCard> {
  int touchedIndex = -1;

  final List<Color> _chartColors = const [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.pink,
  ];

  @override
  Widget build(BuildContext context) {
    double totalValue = widget.categoryData.values.fold(0, (a, b) => a + b);

    final chartSections =
        widget.categoryData.entries.toList().asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          final isTouched = index == touchedIndex;
          final radius = isTouched ? 35.0 : 30.0;
          final fontSize = isTouched ? 14.0 : 12.0;
          final percentage =
              totalValue > 0 ? (data.value / totalValue * 100) : 0;

          return PieChartSectionData(
            color: _chartColors[index % _chartColors.length],
            value: data.value,
            title: isTouched ? '${percentage.toStringAsFixed(0)}%' : '',
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
            ),
            borderSide:
                isTouched
                    ? BorderSide(
                      color: _chartColors[index % _chartColors.length]
                          .withOpacity(0.5),
                      width: 6,
                    )
                    : BorderSide.none,
          );
        }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_month, color: Colors.black),
                onPressed: widget.onIconTap,
              ),
            ],
          ),
          Text(
            widget.totalAmount,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B263B),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                height: 140,
                width: 140,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            touchedIndex = -1;
                            return;
                          }
                          touchedIndex =
                              pieTouchResponse
                                  .touchedSection!
                                  .touchedSectionIndex;
                        });
                      },
                    ),
                    sections:
                        chartSections.isNotEmpty
                            ? chartSections
                            : [
                              PieChartSectionData(
                                color: Colors.grey[300],
                                value: 1,
                                title: '',
                                radius: 30,
                              ),
                            ],
                    centerSpaceRadius: 40,
                    sectionsSpace: 4,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      widget.categoryData.entries.toList().asMap().entries.map((
                        entry,
                      ) {
                        final index = entry.key;
                        final data = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color:
                                      _chartColors[index % _chartColors.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                data.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InventoryItemTile extends StatelessWidget {
  final DocumentSnapshot doc;

  const _InventoryItemTile({required this.doc});

  double _calculateStockPercentage(double currentStock, String unit) {
    double maxStock = 100.0;
    if (unit == 'gram') maxStock = 1000.0;
    if (unit == 'piece') maxStock = 50.0;
    if (unit == 'liter') maxStock = 20.0;

    if (currentStock <= 0) return 0.0;
    final percentage = currentStock / maxStock;
    return percentage > 1.0 ? 1.0 : percentage;
  }

  Color _getStockColor(double currentStock) {
    if (currentStock > 20) return Colors.green;
    if (currentStock > 10) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final currentStock = (data['currentStock'] as num).toDouble();
    final unit = data['unit'] as String? ?? '';
    final stockColor = _getStockColor(currentStock);

    return Card(
      elevation: 0,
      color: Colors.grey.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  data['itemName'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "$currentStock $unit",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: stockColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _calculateStockPercentage(currentStock, unit),
                backgroundColor: stockColor.withOpacity(0.2),
                color: stockColor,
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

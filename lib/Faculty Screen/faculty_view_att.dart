import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../Data/loader.dart';
import '../l10n/app_localizations.dart';

class FacultyViewAttendanceScreen extends StatefulWidget {
  const FacultyViewAttendanceScreen({super.key});

  @override
  State<FacultyViewAttendanceScreen> createState() =>
      _FacultyViewAttendanceScreenState();
}

class _FacultyViewAttendanceScreenState
    extends State<FacultyViewAttendanceScreen> {
  bool isLoading = true;
  late int _selectedYear;
  int? _selectedMonth;
  List<int> _years = [];
  Map<String, String> _attendanceForYear = {};
  int totalDaysInYear = 0;
  int presentDaysInYear = 0;
  double attendancePercentage = 0.0;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() {
    _generateYearsList();
    _selectedYear = _years.first;
    _fetchAttendanceForYear(_selectedYear);
  }

  void _generateYearsList() {
    final int currentYear = DateTime.now().year;
    for (int i = 2025; i <= currentYear; i++) {
      _years.add(i);
    }
    _years = _years.reversed.toList();
  }

  Future<void> _fetchAttendanceForYear(int year) async {
    setState(() {
      isLoading = true;
      _attendanceForYear.clear();
      _selectedMonth = null;
    });

    final user = _auth.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final startDate = DateTime(year, 1, 1);
      final endDate = DateTime(year, 12, 31);

      final snap =
          await _firestore
              .collection('faculty_attendance')
              .where('faculty_id', isEqualTo: user.uid)
              .where(
                'date',
                isGreaterThanOrEqualTo: DateFormat(
                  'yyyy-MM-dd',
                ).format(startDate),
              )
              .where(
                'date',
                isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(endDate),
              )
              .get();

      final fetchedAttendance = <String, String>{};
      int presentCount = 0;

      for (var doc in snap.docs) {
        final data = doc.data();
        final date = data['date'] as String;
        final status = data['status'] as String;
        fetchedAttendance[date] = status;
        if (status.toLowerCase() == 'present') {
          presentCount++;
        }
      }

      setState(() {
        _attendanceForYear = fetchedAttendance;
        totalDaysInYear = snap.docs.length;
        presentDaysInYear = presentCount;
        attendancePercentage =
            totalDaysInYear == 0 ? 0.0 : presentDaysInYear / totalDaysInYear;
      });
    } catch (e) {
      debugPrint('Error fetching attendance: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
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
          AppLocalizations.of(context)!.attendance,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (isLoading)
            const Expanded(child: Center(child: GradientSpinner()))
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildSummaryCard(),
                    const SizedBox(height: 20),
                    _buildYearSelector(),
                    const SizedBox(height: 20),
                    _buildContentBody(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularPercentIndicator(
          radius: 70.0,
          lineWidth: 24.0,
          percent: attendancePercentage.clamp(0.0, 1.0),
          animation: true,
          center: Text(
            "${(attendancePercentage * 100).toStringAsFixed(1)}%",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          circularStrokeCap: CircularStrokeCap.round,
          backgroundColor: const Color(0xFFE1E4EC),
          progressColor: Colors.redAccent,
        ),
        const SizedBox(width: 30),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.presentDays,
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              "$presentDaysInYear",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.totalMarkedDays,
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              "$totalDaysInYear",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildYearSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedYear,
          isExpanded: true,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
          onChanged: (int? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedYear = newValue;
              });
              _fetchAttendanceForYear(newValue);
            }
          },
          items:
              _years.map<DropdownMenuItem<int>>((int year) {
                return DropdownMenuItem<int>(
                  value: year,
                  child: Text(
                    "${AppLocalizations.of(context)!.year}: $year",
                    style: const TextStyle(fontSize: 16),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildContentBody() {
    if (_selectedMonth == null) {
      return _buildMonthSelector();
    } else {
      return _buildDateListForMonth(_selectedMonth!);
    }
  }

  Widget _buildMonthSelector() {
    // Get current locale to format months in Hindi/Urdu
    final locale = Localizations.localeOf(context).toString();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 12,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.2,
      ),
      itemBuilder: (context, index) {
        final month = index + 1;
        final monthName = DateFormat(
          'MMM',
          locale,
        ).format(DateTime(_selectedYear, month));
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedMonth = month;
            });
          },
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Text(
              monthName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateListForMonth(int month) {
    final daysInMonth = DateUtils.getDaysInMonth(_selectedYear, month);
    final locale = Localizations.localeOf(context).toString();
    final monthName = DateFormat(
      'MMMM',
      locale,
    ).format(DateTime(_selectedYear, month));

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              monthName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              icon: const Icon(
                Icons.arrow_back_ios,
                size: 14,
                color: Colors.black,
              ),
              label: Text(
                AppLocalizations.of(context)!.months,
                style: const TextStyle(color: Colors.black),
              ),
              onPressed: () => setState(() => _selectedMonth = null),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: daysInMonth,
          itemBuilder: (context, index) {
            final day = index + 1;
            final date = DateTime(_selectedYear, month, day);
            final dateStr = DateFormat('yyyy-MM-dd').format(date);
            final rawStatus = _attendanceForYear[dateStr];
            return _buildDateListItem(date, rawStatus, locale);
          },
        ),
      ],
    );
  }

  Widget _buildDateListItem(DateTime date, String? rawStatus, String locale) {
    final isPresent = rawStatus != null && rawStatus.toLowerCase() == 'present';
    final isMarked = rawStatus != null;

    String displayStatus;
    if (!isMarked) {
      displayStatus = AppLocalizations.of(context)!.notMarked;
    } else if (isPresent) {
      displayStatus = AppLocalizations.of(context)!.present;
    } else {
      displayStatus = AppLocalizations.of(context)!.absent;
    }

    Color statusColor;
    Color statusBgColor;

    if (isMarked) {
      statusColor =
          isPresent ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
      statusBgColor = statusColor.withOpacity(0.1);
    } else {
      statusColor = Colors.grey;
      statusBgColor = Colors.grey.withOpacity(0.1);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('MMM dd, EEEE', locale).format(date),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Text(
              displayStatus,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

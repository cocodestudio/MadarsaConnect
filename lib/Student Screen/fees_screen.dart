import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../Data/dynamic_popup.dart';
import '../Data/loader.dart';
import '../l10n/app_localizations.dart';

class StudentFeePaymentScreen extends StatefulWidget {
  const StudentFeePaymentScreen({super.key});

  @override
  State<StudentFeePaymentScreen> createState() =>
      _StudentFeePaymentScreenState();
}

class _StudentFeePaymentScreenState extends State<StudentFeePaymentScreen> {
  final TextEditingController _utrController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  bool _isVerifying = false;
  bool _isLoading = true;
  String _qrCodeUrl = '';
  String? _studentUid;
  String? _headUid;
  String? _studentCourseName;
  String? _normalizedCourseId;
  String? _profilePictureUrl;
  String _studentName = '';
  double _totalFees = 0.0;
  double _paidAmount = 0.0;
  double _dueAmount = 0.0;

  List<Map<String, dynamic>> _paymentHistory = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _fetchStudentContext() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _studentUid = null;
      _headUid = null;
      _studentCourseName = null;
      _normalizedCourseId = null;
      _profilePictureUrl = null;
      return;
    }
    _studentUid = user.uid;

    final doc =
        await FirebaseFirestore.instance
            .collection('Students')
            .doc(_studentUid)
            .get();
    final data = doc.data() ?? {};

    _headUid = data['headUid'] as String?;
    _profilePictureUrl = data['profilePictureUrl'] as String?;
    final rawCourse =
        (data['courseName'] ??
                data['course'] ??
                data['course_id'] ??
                data['courseId'] ??
                '')
            .toString();
    final trimmed = rawCourse.trim();
    if (trimmed.isEmpty) {
      _studentCourseName = null;
      _normalizedCourseId = null;
    } else {
      _studentCourseName = trimmed;
      _normalizedCourseId = _studentCourseName!
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '_')
          .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    }

    String name = (user.displayName ?? '').toString().trim();
    final possibleKeys = [
      data['name'],
      data['fullName'],
      data['studentName'],
      data['displayName'],
    ];

    for (final cand in possibleKeys) {
      if (cand != null && cand.toString().trim().isNotEmpty) {
        name = cand.toString().trim();
        break;
      }
    }

    if (name.isEmpty && (user.email ?? '').isNotEmpty) {
      name = user.email!.split('@').first;
    }
    if (name.isEmpty) name = 'Student';

    setState(() {
      _studentName = name;
    });
  }

  Future<void> _fetchPaymentHistory() async {
    if (_studentUid == null) return;
    try {
      final historySnapshot =
          await FirebaseFirestore.instance
              .collection('feePayments')
              .where('userId', isEqualTo: _studentUid)
              .orderBy('timestamp', descending: true)
              .get();

      _paymentHistory =
          historySnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
              'purpose': data['purpose'] as String? ?? 'N/A',
              'status': data['status'] as String? ?? 'pending',
              'timestamp': (data['timestamp'] as Timestamp?)?.toDate(),
            };
          }).toList();

      _paidAmount = _paymentHistory
          .where((payment) => payment['status'] == 'approved')
          .fold(0.0, (sum, item) => sum + (item['amount'] as double));
    } catch (e) {
      print('Error fetching payment history: $e');
    }
  }

  Future<void> _fetchFeeDetails() async {
    if (_studentCourseName == null && _normalizedCourseId == null) {
      if (mounted) {
        setState(() {
          _totalFees = 0.0;
          _dueAmount = 0.0;
        });
      }
      return;
    }

    try {
      final candidates = <String>{};
      if (_normalizedCourseId != null && _normalizedCourseId!.isNotEmpty) {
        candidates.add(_normalizedCourseId!);
      }
      if (_studentCourseName != null && _studentCourseName!.isNotEmpty) {
        candidates.add(_studentCourseName!.trim());
        candidates.add(_studentCourseName!.toLowerCase().trim());
        candidates.add(
          _studentCourseName!
              .trim()
              .replaceAll(RegExp(r'\s+'), '_')
              .toLowerCase(),
        );
      }

      DocumentSnapshot<Map<String, dynamic>>? found;
      for (final id in candidates) {
        final doc =
            await FirebaseFirestore.instance.collection('fees').doc(id).get();
        if (doc.exists) {
          found = doc;
          break;
        }
      }

      if (mounted) {
        setState(() {
          if (found != null && found.exists) {
            final data = found.data()!;
            _totalFees = (data['totalFees'] as num?)?.toDouble() ?? 0.0;
          } else {
            _totalFees = 0.0;
          }
          _dueAmount = _totalFees - _paidAmount;
        });
      }
    } catch (e) {
      print('Error fetching fee details: $e');
      if (mounted) {
        CustomPopup.show(
          context,
          '${AppLocalizations.of(context)!.failedToFetchFeeDetails}: $e',
        );
      }
    }
  }

  Future<void> _bootstrap() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    await _fetchStudentContext();
    await _fetchPaymentHistory();
    await _fetchFeeDetails();
    await _fetchQrCodeUrl();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchQrCodeUrl() async {
    try {
      final qrDoc =
          await FirebaseFirestore.instance
              .collection('adminSettings')
              .doc('qrCode')
              .get();
      if (mounted) {
        setState(() {
          _qrCodeUrl = qrDoc.data()?['qrCodeUrl'] ?? '';
        });
      }
    } catch (e) {
      print('Error fetching QR code URL: $e');
    }
  }

  Future<void> _handleVerification(double amountToPay, String purpose) async {
    final utrRaw = _utrController.text;
    final utr = utrRaw.trim().replaceAll(RegExp(r'\s+'), '');
    if (utr.isEmpty) {
      if (mounted) {
        CustomPopup.show(context, AppLocalizations.of(context)!.pleaseEnterUtr);
      }
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null)
        throw Exception(AppLocalizations.of(context)!.userNotLoggedIn);

      final paymentData = <String, dynamic>{
        'userId': user.uid,
        'headUid': _headUid,
        'email': user.email,
        'name': _studentName,
        'profilePictureUrl': _profilePictureUrl,
        'amount': amountToPay,
        'purpose': purpose,
        'utrNumber': utr,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      };

      final mainRef = await FirebaseFirestore.instance
          .collection('feePayments')
          .add(paymentData);
      final mainDocId = mainRef.id;

      final headCopy = Map<String, dynamic>.from(paymentData);
      headCopy['mainDocId'] = mainDocId;
      if (_headUid != null && _headUid!.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('Heads')
            .doc(_headUid)
            .collection('feePayments')
            .doc(mainDocId)
            .set(headCopy);
      }

      await FirebaseFirestore.instance
          .collection('feePayments')
          .doc(mainDocId)
          .set({'mainDocId': mainDocId}, SetOptions(merge: true));

      _utrController.clear();
      _amountController.clear();
      _purposeController.clear();

      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.feeDepositSubmitted,
        );
        _bootstrap();
      }
    } catch (e) {
      print("Error submitting fee request: $e");
      if (mounted) {
        CustomPopup.show(
          context,
          '${AppLocalizations.of(context)!.failedToSubmitRequest}: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  void _showDepositScreen({
    required double initialAmount,
    required String purpose,
  }) {
    _amountController.text = initialAmount.toStringAsFixed(2);
    _purposeController.text = purpose;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppLocalizations.of(context)!.completeYourPayment,
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
                      color: Colors.black.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (_qrCodeUrl.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            _qrCodeUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.qrCodeLoadingFailed,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.black),
                      ),
                    ),
                  const SizedBox(height: 24),
                  _buildTextField(
                    controller: _amountController,
                    labelText: AppLocalizations.of(context)!.amountInRupees,
                    keyboardType: TextInputType.number,
                    icon: Icons.currency_rupee_rounded,
                    readOnly: true,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _purposeController,
                    labelText: AppLocalizations.of(context)!.paymentPurpose,
                    icon: Icons.description_rounded,
                    readOnly: true,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _utrController,
                    labelText: AppLocalizations.of(context)!.enterUtrNumber,
                    hintText: AppLocalizations.of(context)!.utrExample,
                    keyboardType: TextInputType.number,
                    icon: Icons.numbers_rounded,
                    readOnly: false,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed:
                        _isVerifying
                            ? null
                            : () {
                              _handleVerification(
                                double.tryParse(_amountController.text) ?? 0,
                                _purposeController.text,
                              );
                              Navigator.pop(context);
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE50914),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: 10,
                    ),
                    child:
                        _isVerifying
                            ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : Text(
                              AppLocalizations.of(context)!.verifyPayment,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _utrController.dispose();
    _amountController.dispose();
    _purposeController.dispose();
    super.dispose();
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
          AppLocalizations.of(context)!.fees,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: GradientSpinner())
                      : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 32.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              AppLocalizations.of(
                                context,
                              )!.helloStudent(_studentName),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black.withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(context)!.manageYourPayments,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 32),
                            _buildFeeOverviewCard(),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildActionButton(
                                    title:
                                        AppLocalizations.of(
                                          context,
                                        )!.payFullAmount,
                                    icon: Icons.monetization_on_rounded,
                                    onTap: () {
                                      if (_dueAmount > 0) {
                                        _showDepositScreen(
                                          initialAmount: _dueAmount,
                                          purpose:
                                              AppLocalizations.of(
                                                context,
                                              )!.fullFeesPayment,
                                        );
                                      } else {
                                        if (mounted) {
                                          CustomPopup.show(
                                            context,
                                            AppLocalizations.of(
                                              context,
                                            )!.noDueAmount,
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildActionButton(
                                    title:
                                        AppLocalizations.of(
                                          context,
                                        )!.payOtherAmount,
                                    icon: Icons.account_balance_rounded,
                                    onTap: () {
                                      if (_dueAmount > 0) {
                                        _showCustomAmountDialog();
                                      } else {
                                        if (mounted) {
                                          CustomPopup.show(
                                            context,
                                            AppLocalizations.of(
                                              context,
                                            )!.noDueAmount,
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            _buildHistorySection(),
                          ],
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            title: AppLocalizations.of(context)!.totalFees,
            value: '₹${_totalFees.toStringAsFixed(2)}',
            icon: Icons.account_balance_wallet_rounded,
            iconColor: Colors.blue.shade600,
          ),
          const Divider(color: Colors.black26, height: 32),
          _buildInfoRow(
            title: AppLocalizations.of(context)!.paidAmount,
            value: '₹${_paidAmount.toStringAsFixed(2)}',
            icon: Icons.check_circle_rounded,
            iconColor: Colors.green.shade600,
          ),
          const Divider(color: Colors.black26, height: 32),
          _buildInfoRow(
            title: AppLocalizations.of(context)!.dueAmount,
            value: '₹${_dueAmount.toStringAsFixed(2)}',
            icon: Icons.warning_rounded,
            iconColor:
                _dueAmount > 0 ? Colors.red.shade600 : Colors.green.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
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
                color: Colors.black.withOpacity(0.7),
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

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 120,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              Colors.redAccent.shade100,
              Colors.red.shade400,
              Colors.red.shade300,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.redAccent.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 36),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomAmountDialog() {
    double? customAmount = _dueAmount > 0 ? _dueAmount / 2 : 0;
    _amountController.text = customAmount.toStringAsFixed(2);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            AppLocalizations.of(context)!.enterPaymentAmount,
            style: const TextStyle(color: Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.enterAmountHint,
                  hintStyle: TextStyle(color: Colors.black.withOpacity(0.5)),
                  prefixIcon: const Icon(
                    Icons.currency_rupee_rounded,
                    color: Colors.black,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                onChanged: (value) {
                  customAmount = double.tryParse(value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: const TextStyle(color: Colors.black54),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (customAmount != null &&
                    customAmount! > 0 &&
                    customAmount! <= _dueAmount) {
                  Navigator.of(context).pop();
                  _showDepositScreen(
                    initialAmount: customAmount!,
                    purpose: AppLocalizations.of(context)!.partialFeesPayment,
                  );
                } else {
                  if (mounted) {
                    CustomPopup.show(
                      context,
                      AppLocalizations.of(context)!.invalidAmountError,
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(AppLocalizations.of(context)!.pay),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHistorySection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.paymentHistory,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          if (_paymentHistory.isEmpty)
            Center(
              child: Text(
                AppLocalizations.of(context)!.noPaymentHistory,
                style: TextStyle(color: Colors.black.withOpacity(0.5)),
              ),
            )
          else
            ..._paymentHistory.map((payment) {
              final timestamp = payment['timestamp'] as DateTime?;
              final formattedDate =
                  timestamp != null
                      ? DateFormat('MMM d, yyyy').format(timestamp)
                      : 'N/A';
              final status = (payment['status'] as String).toLowerCase();
              final statusColor =
                  status == 'approved'
                      ? Colors.green.shade600
                      : status == 'rejected'
                      ? Colors.red.shade600
                      : Colors.orange.shade600;
              final statusText = status.toUpperCase();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₹${(payment['amount'] as double).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            payment['purpose'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    required IconData icon,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: Colors.black.withOpacity(0.7)),
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.black.withOpacity(0.4)),
        prefixIcon: Icon(icon, color: Colors.black),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
    );
  }
}

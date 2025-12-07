import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:madarsaconnect/Student%20Screen/quiz_attempt.dart';
import '../Data/dynamic_popup.dart';
import '../Data/loader.dart';
import '../l10n/app_localizations.dart';

class StudentQuizListScreen extends StatefulWidget {
  const StudentQuizListScreen({super.key});

  @override
  State<StudentQuizListScreen> createState() => _StudentQuizListScreenState();
}

class _StudentQuizListScreenState extends State<StudentQuizListScreen>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? _studentCourse;
  String? _studentCourseDuration;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStudentDetails();
  }

  Future<void> _fetchStudentDetails() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final studentDoc =
          await _firestore.collection('Students').doc(currentUserId).get();
      if (studentDoc.exists) {
        final data = studentDoc.data() as Map<String, dynamic>;
        setState(() {
          _studentCourse = data['course'];
          _studentCourseDuration = data['courseDuration'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        CustomPopup.show(
          context,
          '${AppLocalizations.of(context)!.failedToFetchStudentDetails}: $e',
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: GradientSpinner()),
      );
    }
    if (_studentCourse == null || _studentCourseDuration == null) {
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
            AppLocalizations.of(context)!.availableQuizzes,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Text(AppLocalizations.of(context)!.courseDetailsNotFound),
        ),
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
          icon: const Icon(Icons.arrow_back, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.availableQuizzes,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream:
              _firestore
                  .collection('quizzes')
                  .where('courseName', isEqualTo: _studentCourse)
                  .where('courseDuration', isEqualTo: _studentCourseDuration)
                  .snapshots(),
          builder: (context, quizSnapshot) {
            if (quizSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: GradientSpinner());
            }
            if (quizSnapshot.hasError) {
              return Center(
                child: Text(
                  '${AppLocalizations.of(context)!.failedToLoadQuizzes}: ${quizSnapshot.error}',
                ),
              );
            }
            if (!quizSnapshot.hasData || quizSnapshot.data!.docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.assignment_late_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.noQuizzesAvailable,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final quizzes = quizSnapshot.data!.docs;
            final currentUserId = _auth.currentUser?.uid;

            if (currentUserId == null) {
              return const SizedBox.shrink();
            }

            return FutureBuilder<QuerySnapshot>(
              future:
                  _firestore
                      .collection('quiz_attempts')
                      .doc(currentUserId)
                      .collection('completed')
                      .get(),
              builder: (context, attemptSnapshot) {
                if (attemptSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: GradientSpinner());
                }
                if (attemptSnapshot.hasError) {
                  return Center(
                    child: Text(
                      '${AppLocalizations.of(context)!.failedToLoadAttempts}: ${attemptSnapshot.error}',
                    ),
                  );
                }

                final attemptedQuizIds =
                    attemptSnapshot.data!.docs.map((doc) => doc.id).toSet();

                final sortedQuizzes = quizzes.toList();
                sortedQuizzes.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aStatus = _getQuizStatus(aData, a.id, attemptedQuizIds);
                  final bStatus = _getQuizStatus(bData, b.id, attemptedQuizIds);

                  final statusOrder = {
                    'Active': 0,
                    'Upcoming': 1,
                    'Completed': 2,
                    'Expired': 3,
                  };

                  final aOrder = statusOrder[aStatus] ?? 4;
                  final bOrder = statusOrder[bStatus] ?? 4;

                  return aOrder.compareTo(bOrder);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: sortedQuizzes.length,
                  itemBuilder: (context, index) {
                    final quiz = sortedQuizzes[index];
                    final quizData = quiz.data() as Map<String, dynamic>;
                    final quizId = quiz.id;

                    final statusKey = _getQuizStatus(
                      quizData,
                      quizId,
                      attemptedQuizIds,
                    );
                    final statusColor = _getQuizStatusColor(statusKey);
                    final hasAttempted = statusKey == 'Completed';

                    String displayStatus;
                    switch (statusKey) {
                      case 'Active':
                        displayStatus =
                            AppLocalizations.of(context)!.quizStatusActive;
                        break;
                      case 'Upcoming':
                        displayStatus =
                            AppLocalizations.of(context)!.quizStatusUpcoming;
                        break;
                      case 'Completed':
                        displayStatus =
                            AppLocalizations.of(context)!.quizStatusCompleted;
                        break;
                      case 'Expired':
                        displayStatus =
                            AppLocalizations.of(context)!.quizStatusExpired;
                        break;
                      default:
                        displayStatus = statusKey;
                    }

                    return GestureDetector(
                      onTap: () {
                        if (hasAttempted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => StudentQuizViewResultScreen(
                                    quizId: quizId,
                                  ),
                            ),
                          );
                        } else if (statusKey == 'Active') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => StudentQuizWarningScreen(
                                    quizId: quizId,
                                    quizData: quizData,
                                  ),
                            ),
                          );
                        }
                      },
                      child: Card(
                        color: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: Colors.black.withOpacity(0.5),
                            width: 1.0,
                          ),
                        ),
                        margin: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.quiz,
                                    color: statusColor,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      quizData['title'],
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF333333),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(25),
                                      border: Border.all(
                                        color: statusColor,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      displayStatus,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(
                                height: 24,
                                thickness: 0.5,
                                color: Colors.grey,
                              ),
                              _buildInfoRow(
                                icon: Icons.access_time,
                                label: AppLocalizations.of(context)!.starts,
                                value: DateFormat(
                                  'dd MMM yyyy, hh:mm a',
                                ).format(
                                  (quizData['startDate'] as Timestamp).toDate(),
                                ),
                                color: Colors.blueGrey,
                              ),
                              _buildInfoRow(
                                icon: Icons.timer_off_outlined,
                                label: AppLocalizations.of(context)!.ends,
                                value: DateFormat(
                                  'dd MMM yyyy, hh:mm a',
                                ).format(
                                  (quizData['endDate'] as Timestamp).toDate(),
                                ),
                                color: Colors.blueGrey,
                              ),
                              const SizedBox(height: 15),
                              Text(
                                '${AppLocalizations.of(context)!.rules}:',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF555555),
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                quizData['rules'],
                                style: const TextStyle(
                                  color: Color(0xFF777777),
                                  fontSize: 14,
                                ),
                              ),
                              if (hasAttempted) ...[
                                const SizedBox(height: 15),
                                FutureBuilder<DocumentSnapshot>(
                                  future:
                                      _firestore
                                          .collection('quiz_attempts')
                                          .doc(currentUserId)
                                          .collection('completed')
                                          .doc(quizId)
                                          .get(),
                                  builder: (context, scoreSnapshot) {
                                    if (!scoreSnapshot.hasData) {
                                      return const SizedBox.shrink();
                                    }
                                    final scoreData =
                                        scoreSnapshot.data!.data()
                                            as Map<String, dynamic>;
                                    return _buildInfoRow(
                                      icon: Icons.bar_chart,
                                      label:
                                          AppLocalizations.of(
                                            context,
                                          )!.yourScore,
                                      value:
                                          '${scoreData['score']} / ${quizData['questions'].length}',
                                      color: Colors.purple,
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _getQuizStatus(
    Map<String, dynamic> quizData,
    String quizId,
    Set<String> attemptedQuizIds,
  ) {
    if (attemptedQuizIds.contains(quizId)) {
      return 'Completed';
    }
    final startDate = (quizData['startDate'] as Timestamp).toDate();
    final endDate = (quizData['endDate'] as Timestamp).toDate();
    final now = DateTime.now();

    if (now.isBefore(startDate)) {
      return 'Upcoming';
    } else if (now.isAfter(endDate)) {
      return 'Expired';
    } else {
      return 'Active';
    }
  }

  Color _getQuizStatusColor(String status) {
    switch (status) {
      case 'Upcoming':
        return Colors.orange;
      case 'Expired':
        return Colors.red;
      case 'Active':
        return Colors.green;
      case 'Completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black54),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class StudentQuizWarningScreen extends StatelessWidget {
  final String quizId;
  final Map<String, dynamic> quizData;

  const StudentQuizWarningScreen({
    super.key,
    required this.quizId,
    required this.quizData,
  });

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
          AppLocalizations.of(context)!.rulesRegulations,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.redAccent, width: 1),
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.redAccent.withOpacity(0.05),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.redAccent,
                              size: 60,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(
                                context,
                              )!.importantInstructions,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInstructionRow(
                        AppLocalizations.of(context)!.quizInstruction1,
                      ),
                      _buildInstructionRow(
                        AppLocalizations.of(context)!.quizInstruction2,
                      ),
                      _buildInstructionRow(
                        AppLocalizations.of(context)!.quizInstruction3,
                      ),
                      _buildInstructionRow(
                        AppLocalizations.of(
                          context,
                        )!.timeDuration(quizData['estimationTime'].toString()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => StudentQuizAttemptScreen(
                            quizId: quizId,
                            quizData: quizData,
                          ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  AppLocalizations.of(context)!.startQuiz,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Colors.redAccent,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, color: Color(0xFF424242)),
            ),
          ),
        ],
      ),
    );
  }
}

class StudentQuizViewResultScreen extends StatefulWidget {
  final String quizId;

  const StudentQuizViewResultScreen({super.key, required this.quizId});

  @override
  State<StudentQuizViewResultScreen> createState() =>
      _StudentQuizViewResultScreenState();
}

class _StudentQuizViewResultScreenState
    extends State<StudentQuizViewResultScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late final Stream<DocumentSnapshot> _attemptStream;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    if (user != null) {
      _attemptStream =
          _firestore
              .collection('quiz_attempts')
              .doc(user.uid)
              .collection('completed')
              .doc(widget.quizId)
              .snapshots();
    } else {
      _attemptStream = Stream.empty();
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
          AppLocalizations.of(context)!.quizResult,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: _attemptStream,
          builder: (context, attemptSnapshot) {
            if (attemptSnapshot.connectionState == ConnectionState.waiting) {
              return _buildWaitingScreen(
                AppLocalizations.of(context)!.loadingResult,
              );
            }

            if (attemptSnapshot.hasError ||
                !attemptSnapshot.hasData ||
                !attemptSnapshot.data!.exists) {
              return _buildErrorScreen(
                AppLocalizations.of(context)!.failedToLoadResult,
              );
            }

            final attemptData =
                attemptSnapshot.data!.data() as Map<String, dynamic>;
            final score = attemptData['score'] as int? ?? 0;
            final totalMarks = attemptData['totalMarks'] as int? ?? 0;
            final totalQuestions = attemptData['totalQuestions'] as int? ?? 0;

            return _buildResultScreen(score, totalMarks, totalQuestions);
          },
        ),
      ),
    );
  }

  Widget _buildWaitingScreen(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.redAccent),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF424242),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen(int score, int totalMarks, int totalQuestions) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 80),
                  const SizedBox(height: 24),
                  Text(
                    AppLocalizations.of(context)!.quizCompleted,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: CircularProgressIndicator(
                            value: totalMarks > 0 ? score / totalMarks : 0,
                            strokeWidth: 20,
                            backgroundColor: Colors.grey[300]!,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.green,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              totalMarks > 0
                                  ? '${(score / totalMarks * 100).toStringAsFixed(0)}%'
                                  : 'N/A',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppLocalizations.of(
                                context,
                              )!.scoreDisplay(score, totalMarks),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 0,
            ),
            child: Text(
              AppLocalizations.of(context)!.done,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorScreen(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

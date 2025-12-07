import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../Data/dynamic_popup.dart';
import '../l10n/app_localizations.dart';

class StudentQuizAttemptScreen extends StatefulWidget {
  final String quizId;
  final Map<String, dynamic> quizData;

  const StudentQuizAttemptScreen({
    super.key,
    required this.quizId,
    required this.quizData,
  });

  @override
  State<StudentQuizAttemptScreen> createState() =>
      _StudentQuizAttemptScreenState();
}

class _StudentQuizAttemptScreenState extends State<StudentQuizAttemptScreen> {
  int _currentQuestionIndex = 0;
  int? _selectedOptionIndex;
  final Map<int, int> _userAnswers = {};
  late final List<Map<String, dynamic>> _questions;
  Timer? _timer;
  int _remainingTime = 0;
  final PageController _pageController = PageController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    _questions =
        (widget.quizData['questions'] as List).cast<Map<String, dynamic>>();

    if (widget.quizData['randomizeOrder'] == true) {
      final List<Map<String, dynamic>> shuffledQuestions = List.from(
        _questions,
      );
      shuffledQuestions.shuffle();
      _questions.clear();
      _questions.addAll(shuffledQuestions);

      for (var q in _questions) {
        final options = List<String>.from(q['options']);
        final correctOption = options[q['correctAnswerIndex']];
        options.shuffle();
        q['options'] = options;
        q['correctAnswerIndex'] = options.indexOf(correctOption);
      }
    }
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer() {
    final estimationTime = widget.quizData['estimationTime'] as int? ?? 10;
    _remainingTime = estimationTime * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        if (mounted) {
          setState(() {
            _remainingTime--;
          });
        }
      } else {
        _timer?.cancel();
        _submitQuiz(isTimedOut: true);
      }
    });
  }

  void _onOptionSelected(int index) {
    if (mounted) {
      setState(() {
        _selectedOptionIndex = index;
      });
    }
  }

  void _nextQuestion() {
    if (_selectedOptionIndex != null) {
      _userAnswers[_currentQuestionIndex] = _selectedOptionIndex!;
      if (_currentQuestionIndex < _questions.length - 1) {
        if (mounted) {
          setState(() {
            _currentQuestionIndex++;
            _selectedOptionIndex = null;
          });
        }
        _pageController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } else {
        _submitQuiz();
      }
    } else {
      CustomPopup.show(
        context,
        AppLocalizations.of(context)!.selectOptionWarning,
      );
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      if (mounted) {
        setState(() {
          _currentQuestionIndex--;
          _selectedOptionIndex = _userAnswers[_currentQuestionIndex];
        });
      }
      _pageController.previousPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _submitQuiz(isTimedOut: true);
    }
  }

  Future<void> _submitQuiz({bool isTimedOut = false}) async {
    _timer?.cancel();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSubmitting = true;
      });
    }

    if (_selectedOptionIndex != null) {
      _userAnswers[_currentQuestionIndex] = _selectedOptionIndex!;
    }

    final int score = _calculateScore();
    final int totalMarks =
        _questions.length * (widget.quizData['marksPerQuestion'] as int? ?? 1);

    await FirebaseFirestore.instance
        .collection('quiz_attempts')
        .doc(user.uid)
        .collection('completed')
        .doc(widget.quizId)
        .set({
          'quizId': widget.quizId,
          'score': score,
          'totalQuestions': _questions.length,
          'totalMarks': totalMarks,
          'attemptedAt': FieldValue.serverTimestamp(),
          'answers': _userAnswers.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
          'isTimedOut': isTimedOut,
          'quizTitle': widget.quizData['title'],
        }, SetOptions(merge: true));

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                      size: 80,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      AppLocalizations.of(context)!.quizSubmittedTitle,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isTimedOut
                          ? AppLocalizations.of(context)!.quizTimeoutMessage
                          : AppLocalizations.of(context)!.quizSuccessMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
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
                  ],
                ),
              ),
            ),
      );
    }
  }

  int _calculateScore() {
    int score = 0;
    final int marksPerQuestion =
        widget.quizData['marksPerQuestion'] as int? ?? 1;
    for (int i = 0; i < _questions.length; i++) {
      final userAnswer = _userAnswers[i];
      if (userAnswer != null) {
        final currentQuestion = _questions[i];
        final correctIndex = currentQuestion['correctAnswerIndex'] as int;

        if (userAnswer == correctIndex) {
          score += marksPerQuestion;
        }
      }
    }
    return score;
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    final formattedMinutes = minutes.toString().padLeft(2, '0');
    final formattedSeconds = remainingSeconds.toString().padLeft(2, '0');
    return '$formattedMinutes:$formattedSeconds';
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _previousQuestion();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: screenSize.height * 0.28,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withAlpha(220),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 12.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 40),
                        Expanded(
                          child: Text(
                            widget.quizData['title'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTime(_remainingTime),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.questionProgress(
                        (_currentQuestionIndex + 1).toString(),
                        _questions.length.toString(),
                      ),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _questions.length,
                        itemBuilder: (context, index) {
                          final currentQuestion = _questions[index];
                          return Column(
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  currentQuestion['question'],
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 50),
                              Expanded(
                                child: ListView.builder(
                                  itemCount:
                                      (currentQuestion['options'] as List)
                                          .length,
                                  itemBuilder: (context, optionIndex) {
                                    return GestureDetector(
                                      onTap:
                                          () => _onOptionSelected(optionIndex),
                                      child: _buildOptionCard(
                                        optionText:
                                            currentQuestion['options'][optionIndex],
                                        isSelected:
                                            _selectedOptionIndex == optionIndex,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed:
                                      _selectedOptionIndex != null
                                          ? _nextQuestion
                                          : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                  ),
                                  child: Text(
                                    _currentQuestionIndex ==
                                            _questions.length - 1
                                        ? AppLocalizations.of(context)!.submit
                                        : AppLocalizations.of(context)!.next,
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
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isSubmitting)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.submittingQuiz,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.submissionThankYou,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String optionText,
    required bool isSelected,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isSelected ? Colors.redAccent.withOpacity(0.15) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isSelected ? Colors.redAccent : Colors.grey.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: isSelected ? [] : [],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              optionText,
              style: TextStyle(
                fontSize: 16,
                color: isSelected ? Colors.redAccent : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? Colors.redAccent : Colors.transparent,
              border: Border.all(
                color:
                    isSelected
                        ? Colors.redAccent
                        : Colors.grey.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child:
                isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
          ),
        ],
      ),
    );
  }
}

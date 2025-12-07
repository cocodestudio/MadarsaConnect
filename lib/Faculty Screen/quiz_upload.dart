import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import '../Data/dynamic_popup.dart';
import '../Data/loader.dart';
import '../Data/main_page.dart';
import '../l10n/app_localizations.dart';
import '../utils/firebase_notification_helper.dart';

class FacultyQuizUploadScreen extends StatefulWidget {
  const FacultyQuizUploadScreen({super.key});

  @override
  State<FacultyQuizUploadScreen> createState() =>
      _FacultyQuizUploadScreenState();
}

class _FacultyQuizUploadScreenState extends State<FacultyQuizUploadScreen> {
  final _quizNameController = TextEditingController();
  final _estimationTimeController = TextEditingController(text: '10');
  final _marksPerQuestionController = TextEditingController(text: '1');
  final _quizRulesController =
      TextEditingController(); // Removed default text to localize later
  final _startDateController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endDateController = TextEditingController();
  final _endTimeController = TextEditingController();

  // Localized strings will be fetched in build
  List<String> _quizTypes = ['Multiple Choice', 'True/False'];
  String _selectedQuizType = 'Multiple Choice';

  List<String> _randomizeOptions = [
    'Keep choices in current order',
    'Randomize',
  ];
  String _selectedRandomizeOption = 'Keep choices in current order';

  int _numberOfQuestions = 1;
  final List<Map<String, dynamic>> _questions = [
    {
      'questionText': '',
      'options': ['Option 1', 'Option 2'],
      'correctIndex': 0,
    },
  ];

  bool _isUploading = false;
  DateTime? _selectedStartDate;
  TimeOfDay? _selectedStartTime;
  DateTime? _selectedEndDate;
  TimeOfDay? _selectedEndTime;

  String? _headUid;
  List<Map<String, dynamic>> _courses = [];
  String? _selectedCourseId;
  String? _selectedCourseName;
  List<String> _durations = [];
  String? _selectedDuration;

  @override
  void initState() {
    super.initState();
    _updateQuestionList();
    _fetchHeadUidAndCourses();

    // We can't access context here for localization of default values.
    // Handled in build or by checking empty/defaults.
  }

  @override
  void dispose() {
    _quizNameController.dispose();
    _estimationTimeController.dispose();
    _marksPerQuestionController.dispose();
    _quizRulesController.dispose();
    _startDateController.dispose();
    _startTimeController.dispose();
    _endDateController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  Future<void> _fetchHeadUidAndCourses() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.loginToUploadQuiz,
        );
      }
      return;
    }

    try {
      final facultyDoc =
          await FirebaseFirestore.instance
              .collection('Faculties')
              .doc(user.uid)
              .get();

      if (facultyDoc.exists) {
        final facultyData = facultyDoc.data();
        if (facultyData != null && facultyData.containsKey('headUid')) {
          setState(() {
            _headUid = facultyData['headUid'];
          });

          if (_headUid != null) {
            final courseSnapshot =
                await FirebaseFirestore.instance
                    .collection('courses')
                    .where('headUid', isEqualTo: _headUid)
                    .get();

            setState(() {
              _courses =
                  courseSnapshot.docs.map((doc) {
                    return {
                      'id': doc.id,
                      'name': doc.data()['name'],
                      'duration': doc.data()['duration'],
                    };
                  }).toList();
            });
          }
        }
      }
    } catch (e) {
      if (mounted)
        CustomPopup.show(
          context,
          '${AppLocalizations.of(context)!.errorFetchingData}: $e',
        );
    }
  }

  void _updateQuestionList() {
    setState(() {
      while (_questions.length < _numberOfQuestions) {
        _questions.add({
          'questionText': '',
          'options':
              (_selectedQuizType == 'True/False')
                  ? ['True', 'False']
                  : ['Option 1', 'Option 2'],
          'correctIndex': 0,
        });
      }
      while (_questions.length > _numberOfQuestions) {
        _questions.removeLast();
      }
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.redAccent,
            colorScheme: const ColorScheme.light(primary: Colors.redAccent),
            buttonTheme: const ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _selectedStartDate = picked;
          _startDateController.text =
              "${picked.day}/${picked.month}/${picked.year}";
        } else {
          _selectedEndDate = picked;
          _endDateController.text =
              "${picked.day}/${picked.month}/${picked.year}";
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.redAccent,
            colorScheme: const ColorScheme.light(primary: Colors.redAccent),
            buttonTheme: const ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _selectedStartTime = picked;
          _startTimeController.text = picked.format(context);
        } else {
          _selectedEndTime = picked;
          _endTimeController.text = picked.format(context);
        }
      });
    }
  }

  Future<void> _uploadQuiz() async {
    if (_quizNameController.text.isEmpty ||
        _startDateController.text.isEmpty ||
        _startTimeController.text.isEmpty ||
        _endDateController.text.isEmpty ||
        _endTimeController.text.isEmpty ||
        _selectedCourseId == null ||
        _selectedDuration == null) {
      CustomPopup.show(
        context,
        AppLocalizations.of(context)!.fillAllRequiredFields,
      );
      return;
    }

    final startDateTime = DateTime(
      _selectedStartDate!.year,
      _selectedStartDate!.month,
      _selectedStartDate!.day,
      _selectedStartTime!.hour,
      _selectedStartTime!.minute,
    );
    final endDateTime = DateTime(
      _selectedEndDate!.year,
      _selectedEndDate!.month,
      _selectedEndDate!.day,
      _selectedEndTime!.hour,
      _selectedEndTime!.minute,
    );

    if (endDateTime.isBefore(startDateTime)) {
      CustomPopup.show(
        context,
        AppLocalizations.of(context)!.endDateBeforeStartDateError,
      );
      return;
    }

    for (var i = 0; i < _questions.length; i++) {
      if (_questions[i]['questionText'].isEmpty) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.enterTextForAllQuestions,
        );
        return;
      }
      if (_questions[i]['options'].length < 2) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.twoOptionsRequired,
        );
        return;
      }
      for (var option in _questions[i]['options']) {
        if (option.isEmpty) {
          CustomPopup.show(
            context,
            AppLocalizations.of(context)!.fillAllOptionFields,
          );
          return;
        }
      }
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.loginToUploadQuiz,
        );
        return;
      }

      final quizId = const Uuid().v4();

      // Using default rules if empty
      String rules = _quizRulesController.text.trim();
      if (rules.isEmpty) {
        rules = AppLocalizations.of(context)!.defaultQuizRules;
      }

      final quizData = {
        'quizId': quizId,
        'title': _quizNameController.text.trim(),
        'type':
            _selectedQuizType, // Keeping internal English values for DB if needed, or map
        'numberOfQuestions': _numberOfQuestions,
        'estimationTime': int.tryParse(_estimationTimeController.text) ?? 10,
        'marksPerQuestion': int.tryParse(_marksPerQuestionController.text) ?? 1,
        'randomizeOrder':
            _selectedRandomizeOption ==
            'Randomize', // Mapping based on English string? Better use index or bool
        'rules': rules,
        'startDate': Timestamp.fromDate(startDateTime),
        'endDate': Timestamp.fromDate(endDateTime),
        'facultyId': user.uid,
        'courseId': _selectedCourseId,
        'courseName': _selectedCourseName,
        'courseDuration': _selectedDuration,
        'createdAt': FieldValue.serverTimestamp(),
        'questions':
            _questions.map((q) {
              final options = List<String>.from(q['options']);
              final correctAnswerIndex = q['correctIndex'];
              final shuffledOptions = List<String>.from(options);

              // Check against localized string if UI is localized, or better, rely on index/bool logic.
              // Assuming _selectedRandomizeOption holds the localized string or English?
              // In initState we initialized with English.
              // To support localization, we should compare against index or maintain a separate value.
              // For simplicity here, assuming English value is stored in variable.

              // Correct approach: Use index or separate value.
              // _selectedRandomizeOption currently holds string.
              // Let's assume we keep English strings in variable for logic, but display localized.

              if (_selectedRandomizeOption == 'Randomize') {
                shuffledOptions.shuffle(Random());
              }

              final newCorrectIndex = shuffledOptions.indexOf(
                options[correctAnswerIndex],
              );

              return {
                'question': q['questionText'],
                'options': shuffledOptions,
                'correctAnswerIndex': newCorrectIndex,
              };
            }).toList(),
      };

      await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(quizId)
          .set(quizData);

      final studentsSnapshot =
          await FirebaseFirestore.instance
              .collection('Students')
              .where('course', isEqualTo: _selectedCourseName)
              .where('courseDuration', isEqualTo: _selectedDuration)
              .get();

      final batch = FirebaseFirestore.instance.batch();
      final quizTitle = _quizNameController.text.trim();
      // Localizing notification message is tricky as it goes to DB.
      // We can store English or construct based on receiver language (hard).
      // Storing in English or sender's language is standard for MVP.
      final notificationMessage =
          "A new quiz, '$quizTitle', is now available for your course. It starts on ${DateFormat('dd MMM hh:mm a').format(startDateTime)}.";

      for (final studentDoc in studentsSnapshot.docs) {
        final studentUid = studentDoc.id;

        final settingsDoc =
            await FirebaseFirestore.instance
                .collection('notificationSettings')
                .doc(studentUid)
                .get();
        final bool isPushEnabled = settingsDoc.data()?['push'] ?? true;
        final bool isInAppEnabled = settingsDoc.data()?['inApp'] ?? true;

        if (isInAppEnabled) {
          final notificationDocRef =
              FirebaseFirestore.instance.collection('notifications').doc();
          batch.set(notificationDocRef, {
            'recipientId': studentUid,
            'title': 'New Quiz Uploaded',
            'message': notificationMessage,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'type': 'newQuiz',
            'targetId': quizId,
            'targetType': 'quiz',
            'senderId': user.uid,
            'senderName': user.displayName ?? 'Faculty',
            'senderProfileUrl': user.photoURL,
          });
        }

        if (isPushEnabled) {
          final fcmToken = studentDoc.data()['fcmToken'] as String?;
          if (fcmToken != null && fcmToken.isNotEmpty) {
            FirebaseNotificationHelper.sendNotificationFromApp(
              fcmToken: fcmToken,
              title: 'New Quiz Alert!',
              body: notificationMessage,
            );
          }
        }
      }
      await batch.commit();

      CustomPopup.show(
        context,
        AppLocalizations.of(context)!.quizUploadedSuccessfully,
      );

      _quizNameController.clear();
      _estimationTimeController.clear();
      _marksPerQuestionController.clear();
      _quizRulesController.clear();
      _startDateController.clear();
      _startTimeController.clear();
      _endDateController.clear();
      _endTimeController.clear();
      _questions.clear();
      _numberOfQuestions = 1;
      _updateQuestionList();
      _selectedStartDate = null;
      _selectedStartTime = null;
      _selectedEndDate = null;
      _selectedEndTime = null;
      _startDateController.clear();
      _startTimeController.clear();
      _endDateController.clear();
      _endTimeController.clear();
      setState(() {
        _selectedCourseId = null;
        _selectedCourseName = null;
        _selectedDuration = null;
        _durations.clear();
      });

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted)
        CustomPopup.show(
          context,
          '${AppLocalizations.of(context)!.failedToUploadQuiz}: $e',
        );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_quizRulesController.text.isEmpty) {
      _quizRulesController.text =
          AppLocalizations.of(context)!.defaultQuizRules;
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
          AppLocalizations.of(context)!.createNewQuiz,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, size: 26),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MyUploadedQuizzesScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCardWrapper(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.quizNameRequired,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8.0),
                          TextFormField(
                            controller: _quizNameController,
                            decoration: _inputDecoration(
                              hintText:
                                  AppLocalizations.of(context)!.quizNameHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildCardWrapper(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.quizType,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8.0),
                          _buildAnimatedDropdown(
                            selectedOption: _selectedQuizType,
                            options: _quizTypes,
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedQuizType = newValue!;
                                if (_selectedQuizType == 'True/False') {
                                  for (var question in _questions) {
                                    question['options'] = ['True', 'False'];
                                    question['correctIndex'] = 0;
                                  }
                                } else {
                                  for (var question in _questions) {
                                    if (question['options'].length < 2) {
                                      question['options'] = [
                                        'Option 1',
                                        'Option 2',
                                      ];
                                    }
                                  }
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    _buildCardWrapper(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.numberOfQuestions,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8.0),
                          TextFormField(
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration(hintText: 'e.g., 5'),
                            initialValue: _numberOfQuestions.toString(),
                            onChanged: (value) {
                              int? parsedValue = int.tryParse(value);
                              if (parsedValue != null && parsedValue > 0) {
                                setState(() {
                                  _numberOfQuestions = parsedValue;
                                  _updateQuestionList();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    _buildCardWrapper(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.courseRequired,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8.0),
                          _buildAnimatedDropdown(
                            selectedOption:
                                _selectedCourseName ??
                                AppLocalizations.of(context)!.selectCourse,
                            options:
                                _courses
                                    .map((e) => e['name'] as String)
                                    .toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                final selectedCourseData = _courses.firstWhere(
                                  (element) => element['name'] == newValue,
                                );
                                setState(() {
                                  _selectedCourseName = newValue;
                                  _selectedCourseId = selectedCourseData['id'];
                                  _selectedDuration = null;
                                  _durations.clear();
                                  final durationCount =
                                      selectedCourseData['duration'] as int;
                                  final yearSuffixes = ['st', 'nd', 'rd', 'th'];
                                  _durations = List.generate(durationCount, (
                                    index,
                                  ) {
                                    final year = index + 1;
                                    final suffix =
                                        year > 3
                                            ? yearSuffixes[3]
                                            : yearSuffixes[year - 1];
                                    return '$year$suffix Year';
                                  });
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    _buildCardWrapper(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.durationRequired,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8.0),
                          _buildAnimatedDropdown(
                            selectedOption:
                                _selectedDuration ??
                                AppLocalizations.of(context)!.selectDuration,
                            options: _durations,
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedDuration = newValue;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15.0),
                    Text(
                      AppLocalizations.of(context)!.quizSettings,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    _buildSettingField(
                      title: AppLocalizations.of(context)!.randomizeOrder,
                      child: _buildAnimatedDropdown(
                        selectedOption: _selectedRandomizeOption,
                        options: _randomizeOptions,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedRandomizeOption = newValue!;
                          });
                        },
                      ),
                    ),
                    _buildSettingField(
                      title: AppLocalizations.of(context)!.estimationTimeMins,
                      child: TextFormField(
                        controller: _estimationTimeController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(),
                      ),
                    ),
                    _buildSettingField(
                      title: AppLocalizations.of(context)!.marksPerQuestion,
                      child: TextFormField(
                        controller: _marksPerQuestionController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(),
                      ),
                    ),
                    _buildSettingField(
                      title: AppLocalizations.of(context)!.quizRules,
                      child: TextFormField(
                        controller: _quizRulesController,
                        maxLines: null,
                        decoration: _inputDecoration(
                          hintText: AppLocalizations.of(context)!.quizRulesHint,
                        ),
                      ),
                    ),
                    _buildSettingField(
                      title: AppLocalizations.of(context)!.startDateRequired,
                      child: GestureDetector(
                        onTap: () => _selectDate(context, true),
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: _startDateController,
                            decoration: _inputDecoration(
                              hintText:
                                  AppLocalizations.of(context)!.selectDate,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildSettingField(
                      title: AppLocalizations.of(context)!.startTimeRequired,
                      child: GestureDetector(
                        onTap: () => _selectTime(context, true),
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: _startTimeController,
                            decoration: _inputDecoration(
                              hintText:
                                  AppLocalizations.of(context)!.selectTime,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildSettingField(
                      title: AppLocalizations.of(context)!.endDateRequired,
                      child: GestureDetector(
                        onTap: () => _selectDate(context, false),
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: _endDateController,
                            decoration: _inputDecoration(
                              hintText:
                                  AppLocalizations.of(context)!.selectDate,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildSettingField(
                      title: AppLocalizations.of(context)!.endTimeRequired,
                      child: GestureDetector(
                        onTap: () => _selectTime(context, false),
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: _endTimeController,
                            decoration: _inputDecoration(
                              hintText:
                                  AppLocalizations.of(context)!.selectTime,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10.0),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _questions.length,
                      itemBuilder: (context, index) {
                        return _buildQuestionContainer(
                          context,
                          index,
                          Key('$index-$_selectedQuizType'),
                        );
                      },
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: _isUploading ? null : _uploadQuiz,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child:
                          _isUploading
                              ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: GradientSpinner(),
                              )
                              : Text(
                                AppLocalizations.of(context)!.uploadQuiz,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              ),
            ),
            if (_isUploading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(child: GradientSpinner()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardWrapper({required Widget child}) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.black54, width: 1.0),
      ),
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(padding: const EdgeInsets.all(16.0), child: child),
    );
  }

  Widget _buildAnimatedDropdown({
    required String selectedOption,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return GestureDetector(
      onTap: () {
        if (options.isEmpty) {
          CustomPopup.show(
            context,
            AppLocalizations.of(context)!.noOptionsAvailable,
          );
          return;
        }
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.selectOption,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        return RadioListTile<String>(
                          title: Text(options[index]),
                          value: options[index],
                          groupValue: selectedOption,
                          onChanged: (value) {
                            onChanged(value);
                            Navigator.of(context).pop();
                          },
                          activeColor: Colors.redAccent,
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black, width: 0.3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(selectedOption, overflow: TextOverflow.ellipsis),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Colors.black),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black, width: 0.3),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.redAccent.withOpacity(0.5),
          width: 1.0,
        ),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
    );
  }

  Widget _buildQuestionContainer(
    BuildContext context,
    int questionIndex,
    Key key,
  ) {
    return _buildCardWrapper(
      child: Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${AppLocalizations.of(context)!.question} ${questionIndex + 1} *',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8.0),
          TextFormField(
            initialValue: _questions[questionIndex]['questionText'],
            decoration: _inputDecoration(
              hintText: AppLocalizations.of(context)!.writeQuestionHere,
            ),
            maxLines: null,
            onChanged: (value) {
              _questions[questionIndex]['questionText'] = value;
            },
          ),
          const Divider(height: 24, color: Colors.grey),
          Text(
            '${AppLocalizations.of(context)!.choices} *',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8.0),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _questions[questionIndex]['options'].length,
            itemBuilder: (context, optionIndex) {
              return _buildOptionRow(
                _questions[questionIndex]['options'][optionIndex],
                questionIndex,
                optionIndex,
              );
            },
          ),
          const SizedBox(height: 10),
          if (_selectedQuizType == 'Multiple Choice')
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _questions[questionIndex]['options'].add(
                    '${AppLocalizations.of(context)!.option} ${_questions[questionIndex]['options'].length + 1}',
                  );
                });
              },
              icon: const Icon(Icons.add, color: Colors.black),
              label: Text(
                AppLocalizations.of(context)!.addAnswers,
                style: const TextStyle(color: Colors.black),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.black, width: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOptionRow(String hintText, int questionIndex, int optionIndex) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Radio<int>(
            value: optionIndex,
            groupValue: _questions[questionIndex]['correctIndex'],
            onChanged: (int? value) {
              setState(() {
                _questions[questionIndex]['correctIndex'] = value;
              });
            },
            activeColor: Colors.redAccent,
          ),
          Expanded(
            child: TextFormField(
              initialValue: hintText,
              decoration: _inputDecoration(),
              readOnly: _selectedQuizType == 'True/False',
              onChanged: (value) {
                _questions[questionIndex]['options'][optionIndex] = value;
              },
            ),
          ),
          if (_questions[questionIndex]['options'].length > 2 &&
              _selectedQuizType == 'Multiple Choice')
            IconButton(
              onPressed: () {
                setState(() {
                  _questions[questionIndex]['options'].removeAt(optionIndex);
                  if (_questions[questionIndex]['options'].length <=
                      _questions[questionIndex]['correctIndex']) {
                    _questions[questionIndex]['correctIndex'] =
                        _questions[questionIndex]['options'].length - 1;
                  }
                });
              },
              icon: const Icon(Icons.delete, color: Colors.red),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingField({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8.0),
          child,
        ],
      ),
    );
  }
}

class MyUploadedQuizzesScreen extends StatelessWidget {
  const MyUploadedQuizzesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(AppLocalizations.of(context)!.loginToViewPage),
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
          AppLocalizations.of(context)!.myUploadedQuizzes,
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
              FirebaseFirestore.instance
                  .collection('quizzes')
                  .where('facultyId', isEqualTo: user.uid)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.redAccent),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  '${AppLocalizations.of(context)!.error}: ${snapshot.error}',
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  AppLocalizations.of(context)!.noQuizzesUploaded,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              );
            }

            final quizzes = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: quizzes.length,
              itemBuilder: (context, index) {
                final quiz = quizzes[index];
                final quizData = quiz.data() as Map<String, dynamic>;
                final quizId = quiz.id;

                final startDate = (quizData['startDate'] as Timestamp).toDate();
                final endDate = (quizData['endDate'] as Timestamp).toDate();
                final now = DateTime.now();

                String status;
                Color statusColor;
                if (now.isBefore(startDate)) {
                  status = AppLocalizations.of(context)!.quizStatusUpcoming;
                  statusColor = Colors.orange;
                } else if (now.isAfter(endDate)) {
                  status = AppLocalizations.of(context)!.quizStatusExpired;
                  statusColor = Colors.red;
                } else {
                  status = AppLocalizations.of(context)!.quizStatusActive;
                  statusColor = Colors.green;
                }

                return FutureBuilder<QuerySnapshot>(
                  future:
                      FirebaseFirestore.instance
                          .collectionGroup('completed')
                          .where('quizId', isEqualTo: quizId)
                          .get(),
                  builder: (context, attemptSnapshot) {
                    final int attempts = attemptSnapshot.data?.docs.length ?? 0;

                    return Card(
                      color: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    quizData['title'],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF333333),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: statusColor,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24, thickness: 0.5),
                            _buildInfoRow(
                              Icons.timer,
                              AppLocalizations.of(context)!.duration,
                              '${quizData['estimationTime']} ${AppLocalizations.of(context)!.mins}',
                            ),
                            _buildInfoRow(
                              Icons.calendar_today,
                              AppLocalizations.of(context)!.starts,
                              DateFormat(
                                'dd MMM yyyy, hh:mm a',
                              ).format(startDate),
                            ),
                            _buildInfoRow(
                              Icons.event_busy,
                              AppLocalizations.of(context)!.ends,
                              DateFormat(
                                'dd MMM yyyy, hh:mm a',
                              ).format(endDate),
                            ),
                            _buildInfoRow(
                              Icons.person_outline,
                              AppLocalizations.of(context)!.attempts,
                              '$attempts ${AppLocalizations.of(context)!.totalStudents}',
                            ),
                            if (quizData.containsKey('courseName') &&
                                quizData['courseName'] != null)
                              _buildInfoRow(
                                Icons.school,
                                AppLocalizations.of(context)!.course,
                                '${quizData['courseName'] ?? 'N/A'} - ${quizData['courseDuration'] ?? 'N/A'}',
                              ),
                          ],
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey[700]),
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

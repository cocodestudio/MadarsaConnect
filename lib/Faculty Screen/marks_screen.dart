import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../Data/dynamic_popup.dart';
import '../Data/loader.dart';

class MarksManagementScreen extends StatefulWidget {
  final String headUid;
  const MarksManagementScreen({Key? key, required this.headUid})
    : super(key: key);

  @override
  State<MarksManagementScreen> createState() => _MarksManagementScreenState();
}

class _MarksManagementScreenState extends State<MarksManagementScreen> {
  // Controllers for text fields
  final TextEditingController _scheduleController = TextEditingController();
  final TextEditingController _courseController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _studentController = TextEditingController();
  final TextEditingController _maxMarksController = TextEditingController();
  final TextEditingController _passingMarksController = TextEditingController();
  final TextEditingController _reportYearController = TextEditingController();
  final TextEditingController _selectedYearController = TextEditingController();
  final TextEditingController _obtainedMarksController =
      TextEditingController();
  final TextEditingController _sucIdController = TextEditingController();
  final TextEditingController _examController = TextEditingController();

  // State variables for UI and logic
  List<Map<String, dynamic>> _allSchedules = [];
  Timer? _clearTimer;
  int _selectedTab = 0;
  List<Map<String, dynamic>> _allCourses = [];
  List<String> _subjectOptions = [];
  Map<String, dynamic>? _selectedCourse;
  int? _selectedYear;
  bool _isLocked = false;
  List<Map<String, dynamic>> _filteredStudents = [];
  int _step = 0;
  Map<String, dynamic>? _selectedStudent;
  Map<String, dynamic>? _selectedScheduleData;
  bool _isLoading = true;
  Map<String, dynamic>? _studentData;
  int _manageTabStep = 0;
  bool _showMarksFields = false;
  bool _marksLocked = false;
  Map<String, dynamic>? _studentMarksData;
  List<String> _availableDurationsForStudent = [];
  List<String> _availableSubjectsForStudent = [];
  final Map<String, String> _subjectCodeMap = {};

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _startClearTimer();

    _courseController.addListener(_onRecordsManageFieldChange);
    _durationController.addListener(_onRecordsManageFieldChange);
    _subjectController.addListener(_onRecordsManageFieldChange);
    _courseController.addListener(_onCourseControllerChange);
    _durationController.addListener(_onDurationControllerChange);
  }

  void _onCourseControllerChange() {
    if (mounted) {
      _selectedCourse = _allCourses.firstWhere(
        (e) => e['name'].toString() == _courseController.text,
        orElse: () => {},
      );
      _durationController.clear();
      _subjectController.clear();
      _selectedYear = null;
      _subjectOptions.clear();
    }
  }

  void _onDurationControllerChange() {
    if (mounted) {
      if (_durationController.text.isNotEmpty) {
        final match = RegExp(r'^(\d+)').firstMatch(_durationController.text);
        if (match != null) {
          _selectedYear = int.tryParse(match.group(1)!);
        }
      }
      _subjectController.clear();
    }
  }

  void _onRecordsManageFieldChange() {
    if (_selectedTab == 1 && _manageTabStep == 1 && !mounted) {
      return;
    }

    final bool allFieldsFilled =
        _courseController.text.isNotEmpty &&
        _durationController.text.isNotEmpty &&
        _subjectController.text.isNotEmpty;

    if (allFieldsFilled) {
      _loadMarksForSelectedStudent();
    } else {
      if (mounted) {
        setState(() {
          _showMarksFields = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scheduleController.dispose();
    _courseController.dispose();
    _subjectController.dispose();
    _durationController.dispose();
    _studentController.dispose();
    _maxMarksController.dispose();
    _passingMarksController.dispose();
    _reportYearController.dispose();
    _selectedYearController.dispose();
    _obtainedMarksController.dispose();
    _sucIdController.dispose();
    _examController.dispose();

    _clearTimer?.cancel();
    _courseController.removeListener(_onRecordsManageFieldChange);
    _durationController.removeListener(_onRecordsManageFieldChange);
    _subjectController.removeListener(_onRecordsManageFieldChange);
    _courseController.removeListener(_onCourseControllerChange);
    _durationController.removeListener(_onDurationControllerChange);
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (mounted) setState(() => _isLoading = true);
    await _fetchSchedules();
    await _fetchCourses();
    if (mounted) setState(() => _isLoading = false);
  }

  void _startClearTimer() {
    _clearTimer?.cancel();
    _clearTimer = Timer(const Duration(days: 90), () {
      _scheduleController.clear();
    });
  }

  Future<void> _fetchCourses() async {
    if (widget.headUid.isEmpty) {
      if (mounted) CustomPopup.show(context, "Head UID not available.");
      return;
    }

    try {
      final courseSnapshot =
          await FirebaseFirestore.instance
              .collection('courses')
              .where('headUid', isEqualTo: widget.headUid)
              .get();

      _allCourses =
          courseSnapshot.docs.map((e) => {'id': e.id, ...e.data()}).toList();

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) CustomPopup.show(context, "Error fetching courses: $e");
    }
  }

  Future<void> _fetchSchedules() async {
    if (widget.headUid.isEmpty) {
      if (mounted) CustomPopup.show(context, "Head UID not available.");
      return;
    }

    try {
      final all =
          await FirebaseFirestore.instance
              .collection('examination')
              .where('headUid', isEqualTo: widget.headUid)
              .orderBy('createdAt', descending: true)
              .get();

      final now = DateTime.now();

      _allSchedules =
          all.docs
              .where((doc) {
                final data = doc.data();
                final ts = data['createdAt'] as Timestamp?;
                if (ts == null) return false;
                final expiry = ts.toDate().add(const Duration(days: 90));
                return expiry.isAfter(now);
              })
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) CustomPopup.show(context, "Error fetching schedules: $e");
    }
  }

  Future<void> _searchStudentBySUC() async {
    final sucId = _sucIdController.text.trim();
    final session = _reportYearController.text.trim();
    final examType = _examController.text.trim();

    if (sucId.isEmpty || session.isEmpty || examType.isEmpty) {
      if (mounted) CustomPopup.show(context, "Please fill all fields");
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _studentData = null;
        _obtainedMarksController.clear();
        _passingMarksController.clear();
      });
    }

    try {
      final studentSnap =
          await FirebaseFirestore.instance
              .collection('Students')
              .where('sucId', isEqualTo: sucId)
              .where('headUid', isEqualTo: widget.headUid)
              .limit(1)
              .get();

      if (studentSnap.docs.isEmpty) {
        if (mounted) CustomPopup.show(context, "Student not found");
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final student = studentSnap.docs.first.data();
      final studentUid = studentSnap.docs.first.id;

      final marksDoc =
          await FirebaseFirestore.instance
              .collection('studentMarks')
              .doc(studentUid)
              .get();

      if (marksDoc.exists) {
        _studentMarksData = marksDoc.data();
      } else {
        _studentMarksData = null;
      }

      final profilePictureUrl = student['profilePictureUrl'] ?? '';

      if (mounted) {
        setState(() {
          _studentData = {
            ...student,
            'profilePictureUrl': profilePictureUrl,
            'uid': studentUid,
          };
          _selectedScheduleData = {'examType': examType, 'session': session};
        });
      }
    } catch (e) {
      if (mounted) CustomPopup.show(context, "❌ Error in fetch: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _calculateAndSaveResultSummary(
    String studentUid,
    String examType,
  ) async {
    try {
      final updatedDoc =
          await FirebaseFirestore.instance
              .collection('studentMarks')
              .doc(studentUid)
              .get();
      final allData = updatedDoc.data()?['records'] ?? {};
      final examData = allData[examType] as Map<String, dynamic>?;

      if (examData != null) {
        double totalObtained = 0;
        double totalMax = 0;
        int subjectCount = 0;
        int failedSubjects = 0;

        for (final durationEntry in examData.entries) {
          if (durationEntry.key == 'totalPercentage' ||
              durationEntry.key == 'resultStatus') {
            continue;
          }

          final subjectsInDuration =
              durationEntry.value as Map<String, dynamic>?;

          if (subjectsInDuration != null) {
            for (final subjectEntry in subjectsInDuration.entries) {
              final markData = subjectEntry.value as Map<String, dynamic>?;

              if (markData == null ||
                  !markData.containsKey('obtainedMarks') ||
                  !markData.containsKey('maxMarks')) {
                continue;
              }

              final obtained =
                  (markData['obtainedMarks'] is int)
                      ? (markData['obtainedMarks'] as int).toDouble()
                      : (markData['obtainedMarks'] ?? 0.0);
              final max =
                  (markData['maxMarks'] is int)
                      ? (markData['maxMarks'] as int).toDouble()
                      : (markData['maxMarks'] ?? 100.0);
              final grade = markData['grade'] ?? "F";

              totalObtained += obtained;
              totalMax += max;
              subjectCount++;

              if (grade == 'F') failedSubjects++;
            }
          }
        }

        if (subjectCount >= 1 && totalMax > 0) {
          final overallPercent = (totalObtained / totalMax) * 100;
          final result = failedSubjects > 0 ? "Fail" : "Pass";

          await FirebaseFirestore.instance
              .collection('studentMarks')
              .doc(studentUid)
              .update({
                'records.$examType.totalPercentage': double.parse(
                  overallPercent.toStringAsFixed(2),
                ),
                'records.$examType.resultStatus': result,
              });
        }
      }
    } catch (e) {
      debugPrint("Result summary error: $e");
    }
  }

  void _showSelectionDialog({
    required BuildContext context,
    required String title,
    required List<String> options,
    required TextEditingController controller,
  }) {
    String? tempSelected = controller.text;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            title,
            style: const TextStyle(fontFamily: 'Gilroy-Bold', fontSize: 20),
          ),
          content: SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            width: MediaQuery.of(context).size.width * 0.9,
            child: ListView.builder(
              itemCount: options.length,
              itemBuilder: (context, index) {
                final label = options[index];
                return RadioListTile<String>(
                  value: label,
                  groupValue: tempSelected,
                  title: Text(label),
                  activeColor: Colors.redAccent,
                  onChanged: (val) {
                    Navigator.pop(context);
                    if (val != null) {
                      controller.text = val;
                    }
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showExamTypeDialog() {
    final types = ['Half Yearly Exam', 'Annually Exam'];
    _showSelectionDialog(
      context: context,
      title: "Select Exam Type",
      options: types,
      controller: _examController,
    );
  }

  void _showScheduleDialog() {
    String? tempSelected = _scheduleController.text;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            "Select Schedule",
            style: TextStyle(fontFamily: 'Gilroy-Bold', fontSize: 20),
          ),
          content: SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            width: MediaQuery.of(context).size.width * 0.9,
            child: ListView.builder(
              itemCount: _allSchedules.length,
              itemBuilder: (context, index) {
                final data = _allSchedules[index];
                final label = "${data['examType']} (${data['date']})";
                return RadioListTile<String>(
                  value: label,
                  groupValue: tempSelected,
                  title: Text(label, style: const TextStyle(fontSize: 16)),
                  activeColor: Colors.redAccent,
                  onChanged: (val) {
                    Navigator.pop(context);
                    if (mounted) {
                      setState(() {
                        tempSelected = val;
                        _scheduleController.text = val!;
                        _selectedScheduleData = _allSchedules[index];
                        _startClearTimer();
                      });
                    }
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required VoidCallback onTap,
    bool enabled = true,
    bool readOnly = true,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(color: Colors.black, fontSize: 14),
      enabled: enabled,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.black.withOpacity(0.8)),
        fillColor: Colors.white,
        filled: true,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.grey, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.black, width: 1),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.grey, width: 1),
        ),
      ),
    );
  }

  Widget _buildElevatedButton({
    required String text,
    required VoidCallback onPressed,
    bool enabled = true,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? Colors.redAccent : Colors.grey.shade400,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        onPressed: enabled ? onPressed : null,
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Gilroy-Bold',
            fontSize: 15,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildTabBox(String label, int index) {
    bool isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedTab != index) {
            if (mounted) {
              setState(() {
                _selectedTab = index;
                _step = 0;
                _manageTabStep = 0;
                _courseController.clear();
                _durationController.clear();
                _subjectController.clear();
                _showMarksFields = false;
                _marksLocked = false;
              });
            }
          }
        },
        child: Container(
          height: MediaQuery.of(context).size.height * 0.1,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: isSelected ? Colors.redAccent.shade200 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Gilroy-Bold',
              fontSize: 15,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormUI() {
    if (_allSchedules.isEmpty) {
      return const Center(
        child: Text(
          "No Available Schedule or Examination!",
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'Gilroy-Bold',
            color: Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTextField(
            controller: _scheduleController,
            hint: "Select Schedule",
            icon: Icons.schedule,
            onTap: _showScheduleDialog,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _courseController,
            hint: "Select Course",
            icon: Icons.book,
            onTap:
                () => _showSelectionDialog(
                  context: context,
                  title: "Select Course",
                  options:
                      _allCourses.map((e) => e['name'].toString()).toList(),
                  controller: _courseController,
                ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _durationController,
            hint: "Select Duration",
            icon: Icons.access_time_filled,
            onTap: () {
              if (_selectedCourse == null) {
                CustomPopup.show(context, 'Please select a course first');
                return;
              }
              final int duration = _selectedCourse?['duration'] ?? 0;
              final List<String> yearOptions = List.generate(duration, (i) {
                final y = i + 1;
                final suffix = ['st', 'nd', 'rd', 'th'][y > 3 ? 3 : y - 1];
                return '$y$suffix Year';
              });
              _showSelectionDialog(
                context: context,
                title: "Select Duration",
                options: yearOptions,
                controller: _durationController,
              );
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _subjectController,
            hint: "Select Subject",
            icon: Icons.menu_book,
            onTap: _fetchAndShowSubjects,
          ),
          const SizedBox(height: 30),
          _buildElevatedButton(
            text: "Fetch Students",
            onPressed: _fetchStudents,
          ),
        ],
      ),
    );
  }

  Widget _buildStudentListUI() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTotalStudentsCard(),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredStudents.length,
              itemBuilder: (context, index) {
                final student = _filteredStudents[index];
                return _buildStudentListItem(student);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalStudentsCard() {
    return Container(
      height: 110,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF1DC), Color(0xFFE2C290)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _filteredStudents.length.toString(),
            style: const TextStyle(fontSize: 24, fontFamily: 'Gilroy-Bold'),
          ),
          const SizedBox(height: 5),
          const Text("Total Students", style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildStudentListItem(Map<String, dynamic> student) {
    return GestureDetector(
      onTap: () => _onStudentSelected(student),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(student['fullName'] ?? ''),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(student['rollNo'].toString()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarksEntryUI() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStudentDetailsCard(),
            const SizedBox(height: 10),
            _buildObtainedMarksField(),
            const SizedBox(height: 15),
            _buildGradeField(),
            const SizedBox(height: 30),
            _buildElevatedButton(
              text: "Save",
              onPressed: _saveMarks,
              enabled: !_marksLocked,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow("Name", _selectedStudent?['fullName'] ?? ''),
          _buildDetailRow(
            "Roll No",
            _selectedStudent?['rollNo']?.toString() ?? '',
          ),
          _buildDetailRow(
            "Course",
            _selectedStudent?['course']?.toString() ?? '',
          ),
          _buildDetailRow(
            "Duration",
            _selectedStudent?['courseDuration']?.toString() ?? '',
          ),
        ],
      ),
    );
  }

  Widget _buildObtainedMarksField() {
    return TextField(
      enabled: !_marksLocked,
      style: const TextStyle(color: Colors.black, fontSize: 14),
      controller: _obtainedMarksController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: "Obtained Marks",
        prefixIcon: const Icon(Icons.score),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.grey, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.black, width: 1),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.grey, width: 1),
        ),
      ),
      onChanged: (value) => _calculateGrade(value),
    );
  }

  Widget _buildGradeField() {
    return TextField(
      enabled: !_marksLocked,
      style: const TextStyle(color: Colors.black, fontSize: 14),
      controller: _passingMarksController,
      readOnly: true,
      decoration: InputDecoration(
        hintText: "Grade",
        prefixIcon: const Icon(Icons.check_circle),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.grey, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.black, width: 1),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.grey, width: 1),
        ),
      ),
    );
  }

  Widget _buildRecordsManageStep0() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Find & Update Marks',
                    style: TextStyle(
                      fontFamily: 'Gilroy-Bold',
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(
                    controller: _examController,
                    hint: "Select Exam Types",
                    icon: Icons.badge_outlined,
                    onTap: _showExamTypeDialog,
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _reportYearController,
                    hint: 'Select Session',
                    icon: Icons.calendar_month,
                    onTap: _showYearBottomSheet,
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _sucIdController,
                    hint: "Enter SUC ID",
                    icon: Icons.badge_outlined,
                    onTap: () {},
                    readOnly: false,
                  ),
                  const SizedBox(height: 16),
                  _buildElevatedButton(
                    text: 'Search',
                    onPressed: _searchStudentBySUC,
                  ),
                ],
              ),
            ),
          ),
          if (_studentData != null) _buildStudentFoundCard(),
        ],
      ),
    );
  }

  Widget _buildStudentFoundCard() {
    final imageUrl = _studentData?['profilePictureUrl'];
    return GestureDetector(
      onTap: _onStudentFound,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.5), width: 1),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.grey.shade300,
              backgroundImage:
                  (imageUrl != null && imageUrl.isNotEmpty)
                      ? NetworkImage(imageUrl)
                      : null,
              child:
                  (imageUrl == null || imageUrl.isEmpty)
                      ? const Icon(Icons.person, color: Colors.white, size: 30)
                      : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _studentData?['fullName'] ?? '',
                    style: const TextStyle(
                      fontFamily: 'Gilroy-Bold',
                      fontSize: 16,
                    ),
                  ),
                  Text("Roll No: ${_studentData?['rollNo'] ?? ''}"),
                  Text("SUC ID: ${_studentData?['sucId'] ?? ''}"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordsManageStep1() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStudentDetailsCard(),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _courseController,
              hint: "Course",
              icon: Icons.book,
              onTap: () {},
              enabled: false,
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _durationController,
              hint: "Select Duration",
              icon: Icons.access_time_filled,
              onTap: _showDurationForStudent,
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _subjectController,
              hint: "Select Subject",
              icon: Icons.menu_book,
              onTap: _showSubjectsForStudent,
            ),
            const SizedBox(height: 18),
            if (_showMarksFields) _buildRecordsManageMarksFields(),
            const SizedBox(height: 20),
            if (_showMarksFields)
              _buildElevatedButton(text: "Update", onPressed: _updateMarks),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordsManageMarksFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "${_subjectController.text} (${_durationController.text})",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _obtainedMarksController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.black, fontSize: 14),
          decoration: InputDecoration(
            hintText: "Obtained Marks",
            prefixIcon: const Icon(Icons.score),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.grey, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.black, width: 1),
            ),
          ),
          onChanged: (value) => _calculateGrade(value),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passingMarksController,
          readOnly: true,
          style: const TextStyle(color: Colors.black, fontSize: 14),
          decoration: InputDecoration(
            hintText: "Grade",
            prefixIcon: const Icon(Icons.check_circle),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.grey, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.black, width: 1),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _fetchAndShowSubjects() async {
    if (_selectedCourse == null || _selectedYear == null) {
      if (mounted)
        CustomPopup.show(context, 'Please select course and duration first');
      return;
    }

    if (mounted)
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const GradientSpinner(),
      );

    try {
      final courseId = _selectedCourse?['id'];
      final subjectSnap =
          await FirebaseFirestore.instance
              .collection('subjects')
              .where('headUid', isEqualTo: widget.headUid)
              .where('courseId', isEqualTo: courseId)
              .where('year', isEqualTo: _selectedYear)
              .get();

      _subjectOptions =
          subjectSnap.docs.map((e) => e['name'].toString()).toList();

      for (var doc in subjectSnap.docs) {
        _subjectCodeMap[doc['name']] = doc['code'];
      }
    } catch (e) {
      debugPrint("Error fetching subjects: $e");
    } finally {
      if (mounted) Navigator.pop(context);
    }

    if (_subjectOptions.isEmpty) {
      if (mounted) CustomPopup.show(context, 'No subjects found for this year');
    } else {
      _showSelectionDialog(
        context: context,
        title: "Select Subject",
        options: _subjectOptions,
        controller: _subjectController,
      );
    }
  }

  Future<void> _fetchStudents() async {
    if (_scheduleController.text.isEmpty ||
        _courseController.text.isEmpty ||
        _durationController.text.isEmpty ||
        _subjectController.text.isEmpty) {
      if (mounted) CustomPopup.show(context, "Please select all fields");
      return;
    }

    if (mounted)
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const GradientSpinner(),
      );

    final courseName = _courseController.text.trim();
    final durationText = _durationController.text.trim();

    try {
      Query query = FirebaseFirestore.instance
          .collection('Students')
          .where('headUid', isEqualTo: widget.headUid)
          .where('course', isEqualTo: courseName)
          .where('courseDuration', isEqualTo: durationText)
          .orderBy('rollNo');

      final resultSnap = await query.get();

      _filteredStudents =
          resultSnap.docs
              .map(
                (doc) => {
                  'uid': doc.id,
                  'fullName': doc['fullName'] ?? '',
                  'rollNo': doc['rollNo'] ?? '',
                  'course': doc['course'] ?? '',
                  'courseDuration': doc['courseDuration'] ?? '',
                  'sucId': doc['sucId'] ?? '',
                },
              )
              .toList();

      if (mounted) Navigator.pop(context);

      if (_filteredStudents.isEmpty) {
        if (mounted) CustomPopup.show(context, "No students found");
      } else {
        if (mounted) {
          setState(() {
            _step = 1;
            _isLocked = true;
          });
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) CustomPopup.show(context, "Error fetching students: $e");
    }
  }

  Future<void> _onStudentSelected(Map<String, dynamic> student) async {
    if (mounted)
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const GradientSpinner(),
      );

    final studentUid = student['uid'] ?? '';
    final subjectName = _subjectController.text.trim();
    final scheduleName = _selectedScheduleData?['examType'] ?? '';
    final durationText = _durationController.text.trim();

    final docRef = FirebaseFirestore.instance
        .collection('studentMarks')
        .doc(studentUid);
    final docSnap = await docRef.get();

    Map<String, dynamic>? subjectData;
    if (docSnap.exists) {
      final data = docSnap.data();
      final records = data?['records'] as Map<String, dynamic>?;
      if (records != null && records.containsKey(scheduleName)) {
        final scheduleRecords = records[scheduleName] as Map<String, dynamic>;
        if (scheduleRecords.containsKey(durationText)) {
          subjectData = scheduleRecords[durationText][subjectName];
        }
      }
    }

    if (mounted) Navigator.pop(context);

    if (mounted) {
      setState(() {
        _selectedStudent = student;
        _step = 2;
        _marksLocked = subjectData?['locked'] ?? false;
        _obtainedMarksController.text =
            subjectData?['obtainedMarks']?.toString() ?? '';
        _passingMarksController.text = subjectData?['grade']?.toString() ?? '';
      });
    }
  }

  Future<void> _onStudentFound() async {
    if (mounted)
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const GradientSpinner(),
      );

    final studentUid = _studentData?['uid'];
    final doc =
        await FirebaseFirestore.instance
            .collection('studentMarks')
            .doc(studentUid)
            .get();

    _studentMarksData = doc.data();
    final examType = _examController.text.trim();

    final availableDurations =
        _studentMarksData?['records']?[examType] as Map<String, dynamic>?;

    if (availableDurations != null) {
      _availableDurationsForStudent =
          availableDurations.keys
              .where(
                (key) => !['totalPercentage', 'resultStatus'].contains(key),
              )
              .toList()
            ..sort();
    } else {
      _availableDurationsForStudent = [];
    }

    if (mounted) Navigator.pop(context);

    if (mounted) {
      setState(() {
        _selectedStudent = _studentData;
        _manageTabStep = 1;
        _courseController.text = _studentData?['course'] ?? '';
        _durationController.clear();
        _subjectController.clear();
        _showMarksFields = false;
      });
    }
  }

  void _showDurationForStudent() {
    if (_availableDurationsForStudent.isEmpty) {
      if (mounted)
        CustomPopup.show(context, "No durations found for this exam.");
      return;
    }
    _showSelectionDialog(
      context: context,
      title: "Select Duration",
      options: _availableDurationsForStudent,
      controller: _durationController,
    );
  }

  void _showSubjectsForStudent() {
    final selectedExamType = _examController.text.trim();
    final selectedDuration = _durationController.text.trim();

    if (selectedDuration.isEmpty) {
      if (mounted) CustomPopup.show(context, "Please select a duration first");
      return;
    }

    final subjectsInDuration =
        _studentMarksData?['records']?[selectedExamType]?[selectedDuration]
            as Map<String, dynamic>?;

    if (subjectsInDuration != null) {
      _availableSubjectsForStudent =
          subjectsInDuration.keys
              .where(
                (key) =>
                    ![
                      'course',
                      'duration',
                      'totalPercentage',
                      'resultStatus',
                    ].contains(key),
              )
              .toList()
            ..sort();
    } else {
      _availableSubjectsForStudent = [];
    }

    if (_availableSubjectsForStudent.isEmpty) {
      if (mounted) CustomPopup.show(context, "No subjects available");
      return;
    }

    _showSelectionDialog(
      context: context,
      title: "Select Subject",
      options: _availableSubjectsForStudent,
      controller: _subjectController,
    );
  }

  Future<void> _updateMarks() async {
    if (_selectedStudent == null ||
        _examController.text.isEmpty ||
        _durationController.text.isEmpty ||
        _subjectController.text.isEmpty ||
        _obtainedMarksController.text.isEmpty) {
      if (mounted) CustomPopup.show(context, "Please fill all required fields");
      return;
    }

    if (mounted)
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const GradientSpinner(),
      );

    try {
      final obtainedMarks =
          int.tryParse(_obtainedMarksController.text.trim()) ?? 0;
      final studentUid = _selectedStudent?['uid'] ?? '';
      final sucId = _selectedStudent?['sucId'] ?? '';
      final subjectName = _subjectController.text.trim();
      final examType = _examController.text.trim();
      final duration = _durationController.text.trim();
      final course = _courseController.text.trim();

      if (sucId.isEmpty) {
        if (mounted) Navigator.pop(context);
        if (mounted)
          CustomPopup.show(
            context,
            "Student SUC ID not found. Cannot update marks.",
          );
        return;
      }

      final docRef = FirebaseFirestore.instance
          .collection('studentMarks')
          .doc(sucId);
      final docSnapshot = await docRef.get();

      int maxMarks = 100;
      int passingMarks = 33;

      if (docSnapshot.exists) {
        final existingData = docSnapshot.data();
        final subjectData =
            existingData?['records']?[examType]?[duration]?[subjectName];
        if (subjectData != null) {
          maxMarks =
              (subjectData['maxMarks'] is String)
                  ? int.tryParse(subjectData['maxMarks']) ?? 100
                  : subjectData['maxMarks'] ?? 100;
          passingMarks =
              (subjectData['passingMarks'] is String)
                  ? int.tryParse(subjectData['passingMarks']) ?? 33
                  : subjectData['passingMarks'] ?? 33;
        } else {
          final matchingSchedule = _allSchedules.firstWhere(
            (s) => s['examType'] == examType && s['courseDuration'] == duration,
            orElse: () => {'maxMarks': 100, 'passingMarks': 33},
          );
          maxMarks =
              (matchingSchedule['maxMarks'] is String)
                  ? int.tryParse(matchingSchedule['maxMarks']) ?? 100
                  : matchingSchedule['maxMarks'] ?? 100;
          passingMarks =
              (matchingSchedule['passingMarks'] is String)
                  ? int.tryParse(matchingSchedule['passingMarks']) ?? 33
                  : matchingSchedule['passingMarks'] ?? 33;
        }
      } else {
        final matchingSchedule = _allSchedules.firstWhere(
          (s) => s['examType'] == examType && s['courseDuration'] == duration,
          orElse: () => {'maxMarks': 100, 'passingMarks': 33},
        );
        maxMarks =
            (matchingSchedule['maxMarks'] is String)
                ? int.tryParse(matchingSchedule['maxMarks']) ?? 100
                : matchingSchedule['maxMarks'] ?? 100;
        passingMarks =
            (matchingSchedule['passingMarks'] is String)
                ? int.tryParse(matchingSchedule['passingMarks']) ?? 33
                : matchingSchedule['passingMarks'] ?? 33;
      }

      if (obtainedMarks > maxMarks) {
        if (mounted) Navigator.pop(context);
        if (mounted)
          CustomPopup.show(
            context,
            "❌ Obtained marks cannot exceed Max Marks ($maxMarks)",
          );
        return;
      }

      final percent = (obtainedMarks / maxMarks) * 100;
      final grade = _getGradeFromPercentage(percent, passingMarks);
      _passingMarksController.text = grade;

      final subjectCode = await _fetchSubjectCode(
        subjectName: subjectName,
        headUid: widget.headUid,
        courseName: course,
        yearText: duration,
      );

      final marksData = {
        'obtainedMarks': obtainedMarks,
        'maxMarks': maxMarks,
        'passingMarks': passingMarks,
        'grade': grade,
        'percentage': double.parse(percent.toStringAsFixed(2)),
        'course': course,
        'duration': duration,
        'subjectCode': subjectCode,
        'locked': false,
        'isApproved': false,
      };

      final studentBasicData = {
        'fullName': _selectedStudent?['fullName'] ?? '',
        'rollNo': _selectedStudent?['rollNo'] ?? '',
        'course': _selectedStudent?['course'] ?? '',
        'courseDuration': _selectedStudent?['courseDuration'] ?? '',
        'sucId': _selectedStudent?['sucId'] ?? '',
        'headUid': widget.headUid,
      };

      final updatePath = 'records.$examType.$duration.$subjectName';
      final pendingDocId = '${sucId}_${examType}_${duration}_${subjectName}';

      if (docSnapshot.exists) {
        await docRef.update({updatePath: marksData});
      } else {
        await docRef.set({
          ...studentBasicData,
          'createdAt': FieldValue.serverTimestamp(),
          'records': {
            examType: {
              duration: {subjectName: marksData},
            },
          },
        });
      }

      await FirebaseFirestore.instance
          .collection('pendingApprovals')
          .doc(pendingDocId)
          .set({
            'headUid': widget.headUid,
            'studentUid': studentUid,
            'course': course,
            'courseDuration': duration,
            'examType': examType,
            'subjectName': subjectName,
            'createdAt': FieldValue.serverTimestamp(),
          });

      await _calculateAndSaveResultSummary(sucId, examType);

      if (mounted) Navigator.pop(context);
      if (mounted) CustomPopup.show(context, 'Marks updated successfully');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) CustomPopup.show(context, 'Error: ${e.toString()}');
    }
  }

  Future<void> _saveMarks() async {
    if (_selectedScheduleData?['maxMarks'] == null ||
        _selectedScheduleData?['passingMarks'] == null) {
      if (mounted)
        CustomPopup.show(
          context,
          "Admin has not set Max Marks and Passing Marks for this exam. Please contact admin.",
        );
      return;
    }

    if (_selectedStudent == null ||
        _scheduleController.text.isEmpty ||
        _subjectController.text.isEmpty) {
      return;
    }

    if (mounted)
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const GradientSpinner(),
      );

    try {
      final obtainedMarks =
          int.tryParse(_obtainedMarksController.text.trim()) ?? 0;
      final studentUid = _selectedStudent?['uid'] ?? '';
      final sucId = _selectedStudent?['sucId'] ?? '';
      final subjectName = _subjectController.text.trim();
      final scheduleName = _selectedScheduleData?['examType'] ?? '';
      final durationText = _durationController.text;
      final courseName = _courseController.text;
      final maxMarks = _selectedScheduleData?['maxMarks'] ?? 100;
      final passing = _selectedScheduleData?['passingMarks'] ?? 33;

      if (sucId.isEmpty) {
        if (mounted) Navigator.pop(context);
        if (mounted)
          CustomPopup.show(
            context,
            "Student SUC ID not found. Cannot save marks.",
          );
        return;
      }

      if (obtainedMarks > maxMarks) {
        if (mounted) Navigator.pop(context);
        if (mounted)
          CustomPopup.show(
            context,
            "❌ Obtained marks cannot exceed Max Marks ($maxMarks)",
          );
        return;
      }

      final percent = (obtainedMarks / maxMarks) * 100;
      final grade = _getGradeFromPercentage(percent, passing);
      _passingMarksController.text = grade;

      final docRef = FirebaseFirestore.instance
          .collection('studentMarks')
          .doc(sucId);
      final docSnapshot = await docRef.get();

      final subjectCode = await _fetchSubjectCode(
        subjectName: subjectName,
        headUid: widget.headUid,
        courseName: courseName,
        yearText: durationText,
      );

      final marksData = {
        'obtainedMarks': obtainedMarks,
        'maxMarks': maxMarks,
        'passingMarks': passing,
        'grade': grade,
        'locked': true,
        'isApproved': false,
        'percentage': double.parse(percent.toStringAsFixed(2)),
        'subjectCode': subjectCode,
      };

      final updatePath = 'records.$scheduleName.$durationText.$subjectName';
      final pendingDocId =
          '${sucId}_${scheduleName}_${durationText}_${subjectName}';

      if (docSnapshot.exists) {
        await docRef.update({updatePath: marksData});
      } else {
        final studentBasicData = {
          'headUid': widget.headUid,
          'sucId': _selectedStudent?['sucId'] ?? '',
          'fullName': _selectedStudent?['fullName'] ?? '',
          'rollNo': _selectedStudent?['rollNo'] ?? '',
          'course': courseName,
          'courseDuration': durationText,
          'createdAt': FieldValue.serverTimestamp(),
        };
        await docRef.set({
          ...studentBasicData,
          'records': {
            scheduleName: {
              durationText: {subjectName: marksData},
            },
          },
        });
      }

      await FirebaseFirestore.instance
          .collection('pendingApprovals')
          .doc(pendingDocId)
          .set({
            'headUid': widget.headUid,
            'studentUid': studentUid,
            'course': courseName,
            'courseDuration': durationText,
            'examType': scheduleName,
            'subjectName': subjectName,
            'createdAt': FieldValue.serverTimestamp(),
          });

      await _calculateAndSaveResultSummary(sucId, scheduleName);

      if (mounted) {
        setState(() {
          _marksLocked = true;
        });
      }
      if (mounted) Navigator.pop(context);
      if (mounted) CustomPopup.show(context, 'Marks updated successfully');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) CustomPopup.show(context, 'Error: ${e.toString()}');
    }
  }

  String _getGradeFromPercentage(double percent, int passing) {
    if (percent < passing) {
      return 'F';
    } else if (percent >= 90) {
      return 'A+';
    } else if (percent >= 80) {
      return 'A';
    } else if (percent >= 70) {
      return 'B+';
    } else if (percent >= 60) {
      return 'B';
    } else if (percent >= 50) {
      return 'C';
    } else {
      return 'D';
    }
  }

  void _calculateGrade(String value) {
    if (!mounted) return;

    final marks = int.tryParse(value) ?? 0;
    int max = 100;
    int passing = 33;

    if (_selectedTab == 0 && _selectedScheduleData != null) {
      final maxRaw = _selectedScheduleData!['maxMarks'];
      final passingRaw = _selectedScheduleData!['passingMarks'];
      max = (maxRaw is String) ? int.tryParse(maxRaw) ?? 100 : maxRaw ?? 100;
      passing =
          (passingRaw is String)
              ? int.tryParse(passingRaw) ?? 33
              : passingRaw ?? 33;
    } else if (_selectedTab == 1 &&
        _examController.text.isNotEmpty &&
        _durationController.text.isNotEmpty) {
      final matchingSchedule = _allSchedules.firstWhere(
        (s) =>
            s['examType'] == _examController.text &&
            s['courseDuration'] == _durationController.text,
        orElse: () => {'maxMarks': 100, 'passingMarks': 33},
      );
      final maxRaw = matchingSchedule['maxMarks'];
      final passingRaw = matchingSchedule['passingMarks'];
      max = (maxRaw is String) ? int.tryParse(maxRaw) ?? 100 : maxRaw ?? 100;
      passing =
          (passingRaw is String)
              ? int.tryParse(passingRaw) ?? 33
              : passingRaw ?? 33;
    }

    if (marks > max) {
      if (mounted)
        CustomPopup.show(
          context,
          "❌ Obtained marks cannot exceed Max Marks ($max)",
        );
      _obtainedMarksController.text = max.toString();
      _passingMarksController.text = _getGradeFromPercentage(
        max.toDouble(),
        passing,
      );
      return;
    }

    final percent = (marks / max) * 100;
    String grade = _getGradeFromPercentage(percent, passing);

    if (mounted) {
      setState(() {
        _passingMarksController.text = grade;
      });
    }
  }

  Future<void> _loadMarksForSelectedStudent() async {
    _obtainedMarksController.clear();
    _passingMarksController.clear();
    if (mounted) {
      setState(() {
        _marksLocked = false;
        _showMarksFields = false;
      });
    }

    if (_selectedStudent == null) return;

    final studentUid = _selectedStudent?['uid'];
    final subjectName = _subjectController.text.trim();
    final examType = _examController.text.trim();
    final duration = _durationController.text.trim();

    if (studentUid == null ||
        subjectName.isEmpty ||
        examType.isEmpty ||
        duration.isEmpty) {
      return;
    }

    final docRef = FirebaseFirestore.instance
        .collection('studentMarks')
        .doc(studentUid);
    final docSnap = await docRef.get();

    if (docSnap.exists) {
      final data = docSnap.data();
      final subjectData = data?['records']?[examType]?[duration]?[subjectName];
      if (subjectData != null) {
        final obtained = subjectData['obtainedMarks']?.toString() ?? '';
        final grade = subjectData['grade']?.toString() ?? '';
        final lockedState = subjectData['locked'] ?? false;

        _obtainedMarksController.text = obtained;
        _passingMarksController.text = grade;

        if (mounted) {
          setState(() {
            _marksLocked = lockedState;
            _showMarksFields = true;
          });
        }
      } else {
        if (mounted) setState(() => _showMarksFields = true);
      }
    } else {
      if (mounted) setState(() => _showMarksFields = true);
    }
  }

  void _showYearBottomSheet() {
    final now = DateTime.now();
    const int startYear = 2025;
    final int currentYear = now.month >= 4 ? now.year : now.year - 1;
    final List<String> sessionList = <String>[];

    for (int year = startYear; year <= currentYear; year++) {
      sessionList.add("$year-${year + 1}");
    }

    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sessionList.length,
              itemBuilder: (context, index) {
                final session = sessionList.reversed.toList()[index];
                return ListTile(
                  title: Text(session),
                  onTap: () {
                    if (mounted) {
                      setState(() {
                        _reportYearController.text = session;
                      });
                    }
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<String> _fetchSubjectCode({
    required String subjectName,
    required String headUid,
    required String courseName,
    required String yearText,
  }) async {
    try {
      final courseSnapshot =
          await FirebaseFirestore.instance
              .collection('courses')
              .where('headUid', isEqualTo: headUid)
              .where('name', isEqualTo: courseName)
              .get();
      if (courseSnapshot.docs.isEmpty) return 'N/A';
      final courseId = courseSnapshot.docs.first.id;
      final yearNumberMatch = RegExp(r'^(\d+)').firstMatch(yearText);
      final yearNumber = int.tryParse(yearNumberMatch?.group(1) ?? '');
      if (yearNumber == null) return 'N/A';

      final subjectSnapshot =
          await FirebaseFirestore.instance
              .collection('subjects')
              .where('headUid', isEqualTo: headUid)
              .where('courseId', isEqualTo: courseId)
              .where('year', isEqualTo: yearNumber)
              .where('name', isEqualTo: subjectName)
              .limit(1)
              .get();
      if (subjectSnapshot.docs.isEmpty) return 'N/A';
      final subjectData = subjectSnapshot.docs.first.data();
      return subjectData['code'] ?? 'N/A';
    } catch (e) {
      debugPrint("Error fetching subject code: $e");
      return 'N/A';
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    if (_selectedTab == 0) {
      switch (_step) {
        case 0:
          return 'Marks Management';
        case 1:
          return 'Select Student';
        case 2:
          return 'Enter Marks';
        default:
          return 'Marks Management';
      }
    } else {
      switch (_manageTabStep) {
        case 0:
          return 'Manage Records';
        case 1:
          return 'Update Marks';
        default:
          return 'Manage Records';
      }
    }
  }

  void _onBackPressed() {
    if (_selectedTab == 0) {
      if (_step == 2) {
        if (mounted)
          setState(() {
            _step = 1;
            _obtainedMarksController.clear();
            _passingMarksController.clear();
            _marksLocked = false;
          });
      } else if (_step == 1) {
        if (mounted) setState(() => _step = 0);
      } else {
        Navigator.pop(context);
      }
    } else if (_selectedTab == 1) {
      if (_manageTabStep == 1) {
        if (mounted)
          setState(() {
            _manageTabStep = 0;
            _courseController.clear();
            _durationController.clear();
            _subjectController.clear();
            _showMarksFields = false;
            _marksLocked = false;
          });
      } else {
        Navigator.pop(context);
      }
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
          icon: const Icon(Icons.arrow_back, size: 26, color: Colors.black),
          onPressed: _onBackPressed,
        ),
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(
            fontSize: 20,
            fontFamily: 'Gilroy-Bold',
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 17),
              child: Row(
                children: [
                  _buildTabBox("Edit / Update Marks", 0),
                  _buildTabBox("Records Manage", 1),
                ],
              ),
            ),
            const SizedBox(height: 5),
            if (_isLoading)
              const Expanded(child: Center(child: GradientSpinner()))
            else
              Expanded(
                child:
                    _selectedTab == 0
                        ? (_step == 0
                            ? _buildFormUI()
                            : _step == 1
                            ? _buildStudentListUI()
                            : _buildMarksEntryUI())
                        : (_manageTabStep == 0
                            ? _buildRecordsManageStep0()
                            : _buildRecordsManageStep1()),
              ),
          ],
        ),
      ),
    );
  }
}

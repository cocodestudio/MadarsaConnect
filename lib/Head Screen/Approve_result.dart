import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:permission_handler/permission_handler.dart';
import '../Data/dynamic_popup.dart';
import '../Data/loader.dart';
import '../utils/firebase_notification_helper.dart';

class ApproveMarksScreen extends StatefulWidget {
  final String headUid;
  const ApproveMarksScreen({super.key, required this.headUid});

  @override
  State<ApproveMarksScreen> createState() => _ApproveMarksScreenState();
}

enum _ScreenState {
  initial,
  loading,
  courseList,
  durationList,
  studentList,
  noResults,
  searching,
  management,
}

class _ApproveMarksScreenState extends State<ApproveMarksScreen> {
  _ScreenState _screenState = _ScreenState.initial;
  List<Map<String, dynamic>> _unapprovedResults = [];
  List<Map<String, dynamic>> _pendingCourses = [];
  List<String> _pendingDurations = [];

  String? _selectedCourseName;
  String? _selectedDuration;

  final ValueNotifier<Set<String>> _selectedResults = ValueNotifier({});
  final TextEditingController _searchController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final CropController _cropController = CropController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Uint8List? _imageDataForCropping;
  bool _isCropping = false;
  File? _logoFile;
  File? _signatureFile;
  String? _currentLogoUrl;
  String? _currentSignatureUrl;
  bool _isLogoUploading = false;
  bool _isSignatureUploading = false;
  String? _imageTypeToUpload;

  @override
  void initState() {
    super.initState();
    _loadCertificateData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _selectedResults.dispose();
    super.dispose();
  }

  Future<void> _loadCertificateData() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('Heads')
              .doc(widget.headUid)
              .get();
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _currentLogoUrl = data?['logoUrl'];
          _currentSignatureUrl = data?['signatureUrl'];
        });
      }
    } catch (e) {
      debugPrint("Error loading certificate data: $e");
    }
  }

  Future<void> _pickImage(String type) async {
    final status = await _requestPermission();
    if (!status) return;

    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final imageBytes = await image.readAsBytes();
      _imageDataForCropping = imageBytes;
      _imageTypeToUpload = type;
      if (mounted) _showCropper();
    } else {
      CustomPopup.show(context, "No image selected.");
    }
  }

  Future<void> _uploadImage(File file, String type) async {
    if (!mounted) return;
    setState(() {
      if (type == 'logo') {
        _isLogoUploading = true;
      } else if (type == 'signature') {
        _isSignatureUploading = true;
      }
    });

    try {
      final compressed = await _compressImage(file);
      final fileToUpload = compressed ?? file;

      final String filePath = '$type/${widget.headUid}.png';
      final Reference ref = _storage.ref().child(filePath);
      final UploadTask uploadTask = ref.putFile(fileToUpload);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('Heads')
          .doc(widget.headUid)
          .set({'${type}Url': downloadUrl}, SetOptions(merge: true));

      setState(() {
        if (type == 'logo') {
          _currentLogoUrl = downloadUrl;
          _isLogoUploading = false;
        } else if (type == 'signature') {
          _currentSignatureUrl = downloadUrl;
          _isSignatureUploading = false;
        }
      });
      CustomPopup.show(context, "$type updated successfully!");
    } catch (e) {
      debugPrint("Failed to upload image: $e");
      CustomPopup.show(context, "Failed to upload $type.");
    } finally {
      if (mounted) {
        setState(() {
          _isLogoUploading = false;
          _isSignatureUploading = false;
        });
      }
    }
  }

  Future<void> _deleteImage(String type) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const GradientSpinner(),
    );
    try {
      final String filePath = '$type/${widget.headUid}.png';
      final Reference ref = _storage.ref().child(filePath);
      await ref.delete();

      await FirebaseFirestore.instance
          .collection('Heads')
          .doc(widget.headUid)
          .update({'${type}Url': FieldValue.delete()});

      setState(() {
        if (type == 'logo') {
          _currentLogoUrl = null;
        } else if (type == 'signature') {
          _currentSignatureUrl = null;
        }
      });

      if (mounted) Navigator.pop(context);
      CustomPopup.show(context, "$type deleted successfully!");
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error deleting image: $e");
      CustomPopup.show(context, "Failed to delete $type.");
    }
  }

  Future<File?> _compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath =
        "${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg";
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 50,
      format: CompressFormat.jpeg,
    );
    return result != null ? File(result.path) : null;
  }

  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      final PermissionStatus status;
      if (sdkInt >= 33) {
        status = await Permission.photos.request();
      } else {
        status = await Permission.storage.request();
      }
      if (!status.isGranted) {
        CustomPopup.show(context, "Gallery permission denied.");
        return false;
      }
    }
    return true;
  }

  void _showCropper() {
    if (_imageDataForCropping == null || _imageTypeToUpload == null) return;
    final isLogo = _imageTypeToUpload == 'logo';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, localSetState) {
            return Stack(
              children: [
                _buildCropperSheet(localSetState, isLogo),
                if (_isCropping)
                  const Positioned.fill(
                    child: Center(child: GradientSpinner()),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCropperSheet(StateSetter localSetState, bool isLogo) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDragHandle(),
          Text(
            isLogo ? "Crop Logo" : "Crop Signature",
            style: const TextStyle(fontSize: 18, fontFamily: 'Gilroy-Bold'),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(isLogo ? 20 : 0),
            child: AspectRatio(
              aspectRatio: isLogo ? 1 : 4 / 1,
              child: Crop(
                controller: _cropController,
                image: _imageDataForCropping!,
                onCropped: (croppedData) async {
                  if (!mounted) return;
                  localSetState(() => _isCropping = true);
                  final tempDir = await getTemporaryDirectory();
                  final filePath =
                      '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
                  final file = File(filePath);
                  await file.writeAsBytes(croppedData);
                  if (mounted) {
                    Navigator.pop(context);
                    await _uploadImage(file, _imageTypeToUpload!);
                  }
                  if (mounted) {
                    localSetState(() => _isCropping = false);
                  }
                },
                withCircleUi: isLogo,
                baseColor: Colors.grey.shade200,
                maskColor: Colors.white,
                radius: 999,
                cornerDotBuilder:
                    (size, edgeAlignment) =>
                        const DotControl(color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildCropperButton("Try Again", Icons.refresh, () {
                  Navigator.pop(context);
                  _pickImage(_imageTypeToUpload!);
                }, isPrimary: false),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCropperButton(
                  "Apply",
                  Icons.check_circle_outline,
                  () async {
                    localSetState(() => _isCropping = true);
                    await Future.delayed(const Duration(milliseconds: 100));
                    _cropController.crop();
                  },
                  isPrimary: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildCropperButton(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool isPrimary = false,
  }) {
    return isPrimary
        ? ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        )
        : OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            elevation: 0,
            foregroundColor: Colors.black87,
            side: BorderSide(color: Colors.grey.shade400),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        );
  }

  Widget _buildDragHandle() {
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(top: 8, bottom: 14),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Future<void> _fetchPendingCourses() async {
    if (!mounted) return;
    setState(() => _screenState = _ScreenState.loading);
    _pendingCourses.clear();

    try {
      final pendingDocs =
          await FirebaseFirestore.instance
              .collection('pendingApprovals')
              .where('headUid', isEqualTo: widget.headUid)
              .get();

      final pendingCourseNames = <String>{};
      for (final doc in pendingDocs.docs) {
        final courseName = doc['course'] as String?;
        if (courseName != null) {
          pendingCourseNames.add(courseName);
        }
      }

      _pendingCourses =
          pendingCourseNames.map((name) => {'courseName': name}).toList();

      setState(() {
        _screenState =
            _pendingCourses.isEmpty
                ? _ScreenState.noResults
                : _ScreenState.courseList;
      });
    } catch (e) {
      debugPrint("Error fetching pending courses: $e");
      if (mounted) {
        CustomPopup.show(context, "Error fetching courses: $e");
        setState(() => _screenState = _ScreenState.initial);
      }
    }
  }

  Future<void> _fetchPendingDurationsForCourse(String courseName) async {
    if (!mounted) return;
    setState(() => _screenState = _ScreenState.loading);
    _pendingDurations.clear();
    _selectedCourseName = courseName;

    try {
      final pendingDocs =
          await FirebaseFirestore.instance
              .collection('pendingApprovals')
              .where('headUid', isEqualTo: widget.headUid)
              .where('course', isEqualTo: courseName)
              .get();

      final pendingDurationSet = <String>{};
      for (final doc in pendingDocs.docs) {
        final duration = doc['courseDuration'] as String?;
        if (duration != null) {
          pendingDurationSet.add(duration);
        }
      }

      _pendingDurations = pendingDurationSet.toList();
      _pendingDurations.sort();

      setState(() {
        _screenState =
            _pendingDurations.isEmpty
                ? _ScreenState.noResults
                : _ScreenState.durationList;
      });
    } catch (e) {
      debugPrint("Error fetching pending durations: $e");
      if (mounted) {
        CustomPopup.show(context, "Error fetching durations: $e");
        setState(() => _screenState = _ScreenState.courseList);
      }
    }
  }

  Future<void> _fetchUnapprovedStudentsByDuration(String duration) async {
    if (!mounted) return;
    setState(() => _screenState = _ScreenState.loading);
    _unapprovedResults.clear();
    _selectedResults.value = {};
    _selectedDuration = duration;

    try {
      final pendingDocs =
          await FirebaseFirestore.instance
              .collection('pendingApprovals')
              .where('headUid', isEqualTo: widget.headUid)
              .where('course', isEqualTo: _selectedCourseName)
              .where('courseDuration', isEqualTo: duration)
              .get();

      final studentInfoMap = <String, Map<String, dynamic>>{};
      for (final doc in pendingDocs.docs) {
        final studentUid = doc['studentUid'] as String;
        if (!studentInfoMap.containsKey(studentUid)) {
          final studentDoc =
              await FirebaseFirestore.instance
                  .collection('Students')
                  .doc(studentUid)
                  .get();
          if (studentDoc.exists) {
            studentInfoMap[studentUid] = studentDoc.data()!;
          }
        }

        if (studentInfoMap.containsKey(studentUid)) {
          final studentData = studentInfoMap[studentUid]!;
          _unapprovedResults.add({
            'studentUid': studentUid,
            'fullName': studentData['fullName'] ?? 'N/A',
            'rollNo': studentData['rollNo'] ?? 'N/A',
            'course': doc['course'] ?? 'N/A',
            'courseDuration': doc['courseDuration'] ?? 'N/A',
            'examType': doc['examType'] ?? 'N/A',
            'duration': duration,
            'id': '${studentUid}_${doc['examType']}_${duration}',
          });
        }
      }

      final uniqueIds = <String>{};
      final uniqueResults = <Map<String, dynamic>>[];
      for (var result in _unapprovedResults) {
        if (uniqueIds.add(result['id'] as String)) {
          uniqueResults.add(result);
        }
      }

      setState(() {
        _unapprovedResults = uniqueResults;
        _screenState =
            _unapprovedResults.isEmpty
                ? _ScreenState.noResults
                : _ScreenState.studentList;
        _selectedResults.value = {};
      });
    } catch (e) {
      debugPrint("Error fetching unapproved results: $e");
      if (mounted) {
        CustomPopup.show(context, "Error fetching data: $e");
        setState(() => _screenState = _ScreenState.durationList);
      }
    }
  }

  Future<void> _searchStudent(String sucId) async {
    if (!mounted) return;
    setState(() => _screenState = _ScreenState.loading);
    _unapprovedResults.clear();
    _selectedResults.value = {};

    try {
      final studentQuery =
          await FirebaseFirestore.instance
              .collection('Students')
              .where('sucId', isEqualTo: sucId)
              .where('headUid', isEqualTo: widget.headUid)
              .get();

      if (studentQuery.docs.isEmpty) {
        setState(() => _screenState = _ScreenState.noResults);
        if (mounted) {
          CustomPopup.show(context, "No student found with this SUC ID.");
        }
        return;
      }

      final studentDoc = studentQuery.docs.first;
      final studentUid = studentDoc.id;

      final pendingDocs =
          await FirebaseFirestore.instance
              .collection('pendingApprovals')
              .where('headUid', isEqualTo: widget.headUid)
              .where('studentUid', isEqualTo: studentUid)
              .get();

      final pendingResults = <Map<String, dynamic>>[];
      for (final doc in pendingDocs.docs) {
        final data = doc.data();
        pendingResults.add({
          'studentUid': studentUid,
          'fullName': studentDoc['fullName'] ?? 'N/A',
          'rollNo': studentDoc['rollNo'] ?? 'N/A',
          'course': data['course'] ?? 'N/A',
          'courseDuration': data['courseDuration'] ?? 'N/A',
          'examType': data['examType'] ?? 'N/A',
          'duration': data['courseDuration'] ?? 'N/A',
          'id': '${studentUid}_${data['examType']}_${data['courseDuration']}',
        });
      }

      final uniqueIds = <String>{};
      final uniqueResults = <Map<String, dynamic>>[];
      for (var result in pendingResults) {
        if (uniqueIds.add(result['id'] as String)) {
          uniqueResults.add(result);
        }
      }

      setState(() {
        _unapprovedResults = uniqueResults;
        _screenState =
            _unapprovedResults.isEmpty
                ? _ScreenState.noResults
                : _ScreenState.studentList;
      });
    } catch (e) {
      debugPrint("Error searching for student: $e");
      if (mounted) {
        CustomPopup.show(context, "Failed to search for student: $e");
        setState(() => _screenState = _ScreenState.noResults);
      }
    }
  }

  Future<void> _approveSelectedResults() async {
    if (_selectedResults.value.isEmpty) {
      CustomPopup.show(
        context,
        "Please select at least one result to approve.",
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const GradientSpinner(),
    );

    try {
      final batch = FirebaseFirestore.instance.batch();
      final notificationsToSend = <Map<String, dynamic>>[];
      final inAppNotifications = <Map<String, dynamic>>[];

      for (var id in _selectedResults.value) {
        final parts = id.split('_');
        final studentUid = parts[0];
        final examType = parts[1];
        final duration = parts[2];

        final studentDoc =
            await FirebaseFirestore.instance
                .collection('Students')
                .doc(studentUid)
                .get();

        if (!studentDoc.exists) continue;

        final studentData = studentDoc.data();
        final fcmToken = studentData?['fcmToken'] as String?;
        final sucId = studentData?['sucId'] as String?;

        if (sucId == null || sucId.isEmpty) continue;

        final settingsDoc =
            await FirebaseFirestore.instance
                .collection('notificationSettings')
                .doc(studentUid)
                .get();
        final isPushEnabled = settingsDoc.data()?['push'] ?? true;
        final isInAppEnabled = settingsDoc.data()?['inApp'] ?? true;

        final notificationTitle = 'Result Approved!';
        final notificationBody =
            'Your result for the $examType exam ($duration) has been approved.';

        if (isPushEnabled && fcmToken != null && fcmToken.isNotEmpty) {
          notificationsToSend.add({
            'fcmToken': fcmToken,
            'title': notificationTitle,
            'body': notificationBody,
            'studentUid': studentUid,
          });
        }

        if (isInAppEnabled) {
          inAppNotifications.add({
            'recipientId': studentUid,
            'title': notificationTitle,
            'message': notificationBody,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'type': 'resultApproved',
            'senderId': _auth.currentUser!.uid,
            'senderName': 'Admin',
          });
        }

        final docRef = FirebaseFirestore.instance
            .collection('studentMarks')
            .doc(sucId);
        final marksDoc = await docRef.get();

        if (marksDoc.exists) {
          final data = marksDoc.data();
          final records = data?['records'] as Map<String, dynamic>?;
          final examRecords = records?[examType] as Map<String, dynamic>?;
          final durationRecords =
              examRecords?[duration] as Map<String, dynamic>?;

          if (durationRecords != null) {
            durationRecords.forEach((subjectName, subjectData) {
              if (subjectData is Map<String, dynamic> &&
                  !(subjectData['isApproved'] ?? false)) {
                batch.update(docRef, {
                  'records.$examType.$duration.$subjectName.isApproved': true,
                });
                final pendingDocId =
                    '${studentUid}_${examType}_${duration}_${subjectName}';
                final pendingDocRef = FirebaseFirestore.instance
                    .collection('pendingApprovals')
                    .doc(pendingDocId);
                batch.delete(pendingDocRef);
              }
            });
          }
        }
      }

      for (var notification in inAppNotifications) {
        final notificationRef =
            FirebaseFirestore.instance.collection('notifications').doc();
        batch.set(notificationRef, notification);
      }

      await batch.commit();

      for (var notification in notificationsToSend) {
        try {
          await FirebaseNotificationHelper.sendNotificationFromApp(
            fcmToken: notification['fcmToken'],
            title: notification['title'],
            body: notification['body'],
          );
        } catch (e) {
          print(
            'Error sending push notification to student ${notification['studentUid']}: $e',
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
        CustomPopup.show(
          context,
          "All selected results approved successfully!",
        );

        if (_screenState == _ScreenState.searching) {
          setState(() {
            _searchController.clear();
            _unapprovedResults.clear();
            _selectedResults.value = {};
            _screenState = _ScreenState.initial;
          });
        } else {
          _fetchUnapprovedStudentsByDuration(_selectedDuration!);
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error approving selected results: $e");
      CustomPopup.show(context, "Failed to approve selected results.");
    }
  }

  void _onSelectAll(bool? isChecked) {
    if (isChecked == true) {
      _selectedResults.value =
          _unapprovedResults.map((e) => e['id'] as String).toSet();
    } else {
      _selectedResults.value = {};
    }
  }

  void _onBackPressed() {
    if (_screenState == _ScreenState.studentList) {
      setState(() {
        _screenState = _ScreenState.durationList;
        _unapprovedResults.clear();
        _selectedResults.value = {};
        _selectedDuration = null;
      });
    } else if (_screenState == _ScreenState.durationList) {
      setState(() {
        _screenState = _ScreenState.courseList;
        _pendingDurations.clear();
        _selectedCourseName = null;
      });
    } else if (_screenState == _ScreenState.courseList ||
        _screenState == _ScreenState.searching ||
        _screenState == _ScreenState.management) {
      setState(() {
        _screenState = _ScreenState.initial;
        _unapprovedResults.clear();
        _pendingCourses.clear();
        _pendingDurations.clear();
        _selectedResults.value = {};
        _searchController.clear();
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _onBackPressed();
        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _buildCustomHeader(),
              _buildTopOptions(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomHeader() {
    String titleText;
    switch (_screenState) {
      case _ScreenState.initial:
        titleText = 'Approve Marks';
        break;
      case _ScreenState.courseList:
      case _ScreenState.durationList:
      case _ScreenState.studentList:
        titleText = 'Pending Results';
        break;
      case _ScreenState.searching:
        titleText = 'Search by SUC ID';
        break;
      case _ScreenState.management:
        titleText = 'Certificate Management';
        break;
      default:
        titleText = 'Approve Marks';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _onBackPressed,
            child: const Icon(Icons.arrow_back, size: 26),
          ),
          Text(
            titleText,
            style: const TextStyle(fontSize: 20, fontFamily: 'Gilroy-Bold'),
          ),
          const SizedBox(width: 26),
        ],
      ),
    );
  }

  Widget _buildTopOptions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    if (_screenState != _ScreenState.courseList) {
                      _fetchPendingCourses();
                      _searchController.clear();
                    }
                  },
                  child: _buildOptionCard(
                    'Pending Results',
                    'View all pending results',
                    Icons.pending_actions,
                    _screenState == _ScreenState.courseList ||
                        _screenState == _ScreenState.durationList ||
                        _screenState == _ScreenState.studentList,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _screenState = _ScreenState.searching;
                      _unapprovedResults.clear();
                      _selectedResults.value = {};
                    });
                  },
                  child: _buildOptionCard(
                    'Search Student',
                    'Search by student ID',
                    Icons.search,
                    _screenState == _ScreenState.searching,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: InkWell(
              onTap: () {
                setState(() => _screenState = _ScreenState.management);
              },
              child: _buildOptionCard(
                'Certificate',
                'Manage logo and signature',
                Icons.settings,
                _screenState == _ScreenState.management,
              ),
            ),
          ),
          if (_screenState == _ScreenState.searching)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      controller: _searchController,
                      hintText: 'Enter Student SUC ID',
                      icon: Icons.qr_code,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      if (_searchController.text.isNotEmpty) {
                        _searchStudent(_searchController.text.trim());
                      } else {
                        CustomPopup.show(
                          context,
                          "Please enter a SUC ID to search.",
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.search, color: Colors.white),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(
    String title,
    String subtitle,
    IconData icon,
    bool isSelected,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isSelected
                ? Colors.redAccent.withOpacity(0.1)
                : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border:
            isSelected
                ? Border.all(color: Colors.redAccent, width: 1.5)
                : Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.redAccent, size: 28),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Gilroy-Bold',
              fontSize: 14,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCourseList() {
    return _pendingCourses.isEmpty
        ? _buildNoResultsScreen(
          message: "No pending results found.",
          subMessage: "All marks have been approved.",
        )
        : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _pendingCourses.length,
          itemBuilder: (context, index) {
            final course = _pendingCourses[index];
            return InkWell(
              onTap:
                  () => _fetchPendingDurationsForCourse(course['courseName']),
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_open, color: Colors.redAccent),
                    const SizedBox(width: 16),
                    Text(
                      course['courseName'],
                      style: const TextStyle(
                        fontFamily: 'Gilroy-Bold',
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.black54,
                      size: 16,
                    ),
                  ],
                ),
              ),
            );
          },
        );
  }

  Widget _buildDurationList() {
    return _pendingDurations.isEmpty
        ? _buildNoResultsScreen(
          message: "No pending results found.",
          subMessage: "All marks have been approved.",
        )
        : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _pendingDurations.length,
          itemBuilder: (context, index) {
            final duration = _pendingDurations[index];
            return InkWell(
              onTap: () => _fetchUnapprovedStudentsByDuration(duration),
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time_filled,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      duration,
                      style: const TextStyle(
                        fontFamily: 'Gilroy-Bold',
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.black54,
                      size: 16,
                    ),
                  ],
                ),
              ),
            );
          },
        );
  }

  Widget _buildManagementScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildManagementCard(
            title: 'Madarsa Logo',
            subtitle: 'Upload or update the logo for marksheets.',
            currentUrl: _currentLogoUrl,
            onUpload: () => _pickImage('logo'),
            onDelete: () => _deleteImage('logo'),
            isUploading: _isLogoUploading,
          ),
          const SizedBox(height: 16.0),
          _buildManagementCard(
            title: 'Head Signature',
            subtitle: 'Upload or update your signature for marksheets.',
            currentUrl: _currentSignatureUrl,
            onUpload: () => _pickImage('signature'),
            onDelete: () => _deleteImage('signature'),
            isUploading: _isSignatureUploading,
          ),
        ],
      ),
    );
  }

  Widget _buildManagementCard({
    required String title,
    required String subtitle,
    String? currentUrl,
    required VoidCallback onUpload,
    required VoidCallback onDelete,
    required bool isUploading,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: Colors.grey, width: 1.0),
      ),
      child: InkWell(
        onTap: isUploading ? null : (currentUrl == null ? onUpload : null),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Gilroy-Bold',
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        currentUrl != null && currentUrl.isNotEmpty
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                currentUrl,
                                height: 100,
                                width: double.infinity,
                                fit: BoxFit.contain,
                                loadingBuilder: (
                                  context,
                                  child,
                                  loadingProgress,
                                ) {
                                  if (loadingProgress == null) return child;
                                  return SizedBox(
                                    height: 100,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                              Colors.redAccent,
                                            ),
                                        value:
                                            loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                                : null,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder:
                                    (context, error, stackTrace) =>
                                        const SizedBox(
                                          height: 100,
                                          child: Center(
                                            child: Icon(Icons.error),
                                          ),
                                        ),
                              ),
                            )
                            : Center(
                              child:
                                  isUploading
                                      ? const GradientSpinner()
                                      : const Icon(
                                        Icons.image,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                            ),
                  ),
                  if (isUploading)
                    const Positioned.fill(
                      child: Center(child: GradientSpinner()),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (currentUrl != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isUploading ? null : onUpload,
                        icon: const Icon(Icons.edit, color: Colors.white),
                        label: const Text(
                          'Update',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  if (currentUrl != null) const SizedBox(width: 8),
                  if (currentUrl != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isUploading ? null : onDelete,
                        icon: const Icon(Icons.delete, color: Colors.white),
                        label: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  if (currentUrl == null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isUploading ? null : onUpload,
                        icon: const Icon(Icons.upload, color: Colors.white),
                        label: const Text(
                          'Upload',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_screenState) {
      case _ScreenState.initial:
        return _buildNoResultsScreen();
      case _ScreenState.loading:
        return const Center(child: GradientSpinner());
      case _ScreenState.courseList:
        return _buildCourseList();
      case _ScreenState.durationList:
        return _buildDurationList();
      case _ScreenState.studentList:
        return _buildResultsList();
      case _ScreenState.noResults:
        return _buildNoResultsScreen(
          message: "No pending results found.",
          subMessage: "All marks have been approved.",
        );
      case _ScreenState.searching:
        return _unapprovedResults.isEmpty && _searchController.text.isEmpty
            ? _buildNoResultsScreen(
              message: "Enter SUC ID",
              subMessage: "Enter student's ID to search for pending marks.",
            )
            : _buildResultsList();
      case _ScreenState.management:
        return _buildManagementScreen();
    }
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(
        color: Colors.black87,
        fontFamily: 'Gilroy-Regular',
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.redAccent),
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Colors.black54,
          fontFamily: 'Gilroy-Regular',
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              ValueListenableBuilder<Set<String>>(
                valueListenable: _selectedResults,
                builder: (context, selectedIds, child) {
                  return Checkbox(
                    value:
                        selectedIds.isNotEmpty &&
                        selectedIds.length == _unapprovedResults.length,
                    onChanged: _onSelectAll,
                    activeColor: Colors.redAccent,
                  );
                },
              ),
              const Text('Select All'),
              const Spacer(),
              ValueListenableBuilder<Set<String>>(
                valueListenable: _selectedResults,
                builder: (context, selectedIds, child) {
                  return ElevatedButton.icon(
                    onPressed:
                        selectedIds.isEmpty ? null : _approveSelectedResults,
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: Text(
                      'Approve Selected (${selectedIds.length})',
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _unapprovedResults.length,
            itemBuilder: (context, index) {
              final result = _unapprovedResults[index];
              return ValueListenableBuilder<Set<String>>(
                valueListenable: _selectedResults,
                builder: (context, selectedIds, child) {
                  final isSelected = selectedIds.contains(result['id']);
                  return _buildResultCard(result, isSelected);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(Map<String, dynamic> result, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.redAccent.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border:
            isSelected ? Border.all(color: Colors.redAccent, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () {
            if (isSelected) {
              _selectedResults.value = {..._selectedResults.value}
                ..remove(result['id']);
            } else {
              _selectedResults.value = {..._selectedResults.value}
                ..add(result['id'] as String);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result['fullName'] ?? 'N/A',
                        style: TextStyle(
                          fontFamily: 'Gilroy-Bold',
                          fontSize: 18,
                          color:
                              isSelected
                                  ? Colors.redAccent.shade700
                                  : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Course: ${result['course'] ?? 'N/A'} - ${result['courseDuration'] ?? 'N/A'}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                      Text(
                        'Exam: ${result['examType'] ?? 'N/A'} - ${result['duration'] ?? 'N/A'}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) {
                    if (value == true) {
                      _selectedResults.value = {..._selectedResults.value}
                        ..add(result['id'] as String);
                    } else {
                      _selectedResults.value = {..._selectedResults.value}
                        ..remove(result['id']);
                    }
                  },
                  activeColor: Colors.redAccent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsScreen({
    String message = "Welcome!",
    String subMessage = "Select an option above to get started.",
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_screenState != _ScreenState.noResults)
              Icon(
                Icons.school,
                color: Colors.redAccent.withOpacity(0.5),
                size: 50,
              ),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(
                fontSize: 24,
                fontFamily: 'Gilroy-Bold',
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontFamily: 'Gilroy-Regular',
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

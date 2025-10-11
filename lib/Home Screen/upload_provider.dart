import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class UploadProvider with ChangeNotifier {
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = "";

  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  String get uploadStatus => _uploadStatus;

  Future<void> uploadPost({
    required String caption,
    required List<File> mediaFiles,
    required String? userId,
    required String? userName,
    required String? userProfileUrl,
    required String? userRole,
    required String? userHeadUid,
    required String privacySetting,
  }) async {
    if (userId == null) {
      _uploadStatus = "Error: User not logged in.";
      notifyListeners();
      return;
    }

    _isUploading = true;
    _uploadProgress = 0.0;
    _uploadStatus = "Preparing...";
    notifyListeners();

    try {
      List<String> mediaUrls = [];
      List<String> mediaTypes = [];

      if (mediaFiles.isNotEmpty) {
        _uploadStatus = "Uploading media...";
        notifyListeners();

        for (int i = 0; i < mediaFiles.length; i++) {
          File file = mediaFiles[i];
          String fileName = p.basename(file.path);
          Reference ref = FirebaseStorage.instance.ref().child(
            'posts/${DateTime.now().millisecondsSinceEpoch}_$fileName',
          );

          final dir = await getTemporaryDirectory();
          final targetPath =
              "${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg";
          final XFile? compressedXFile =
              await FlutterImageCompress.compressAndGetFile(
                file.absolute.path,
                targetPath,
                minWidth: 1080,
                minHeight: 1080,
                quality: 70,
              );

          File fileToUpload =
              (compressedXFile != null) ? File(compressedXFile.path) : file;

          UploadTask uploadTask = ref.putFile(fileToUpload);

          uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
            _uploadStatus =
                "Uploading... ${(_uploadProgress * 100).toStringAsFixed(0)}%";
            notifyListeners();
          });

          TaskSnapshot snapshot = await uploadTask;
          String downloadUrl = await snapshot.ref.getDownloadURL();
          mediaUrls.add(downloadUrl);
          mediaTypes.add('image');
        }
      }

      _uploadStatus = "Finishing up...";
      notifyListeners();

      final postDocRef = await FirebaseFirestore.instance
          .collection('posts')
          .add({
            'userId': userId,
            'userName': userName,
            'userProfileUrl': userProfileUrl,
            'userRole': userRole,
            'caption': caption,
            'mediaUrls': mediaUrls,
            'mediaTypes': mediaTypes,
            'timestamp': FieldValue.serverTimestamp(),
            'privacySetting': privacySetting,
            'likesCount': 0,
            'likedBy': [],
            'commentsCount': 0,
            'savedBy': [],
            'isQuestion': false,
            'isPoll': false,
          });

      await _sendNotifications(
        userRole: userRole,
        userName: userName,
        userId: userId,
        userHeadUid: userHeadUid,
        caption: caption,
        postId: postDocRef.id,
        userProfileUrl: userProfileUrl,
      );

      _uploadStatus = "Completed";
    } catch (e) {
      _uploadStatus = "Upload Failed: ${e.toString()}";
      print(e);
    } finally {
      await Future.delayed(const Duration(seconds: 2));
      _isUploading = false;
      _uploadProgress = 0.0;
      _uploadStatus = "";
      notifyListeners();
    }
  }

  Future<void> _sendNotifications({
    required String? userRole,
    required String? userName,
    required String? userId,
    required String? userHeadUid,
    required String caption,
    required String postId,
    required String? userProfileUrl,
  }) async {
    List<String> recipientUids = [];
    String notificationTitle = '';
    String notificationMessage = '';
    String postContentPreview =
        caption.length > 50 ? "${caption.substring(0, 50)}..." : caption;

    if (userRole == 'Head' && userId != null) {
      notificationTitle = 'New Post from ${userName ?? 'Head'}';
      notificationMessage =
          '${userName ?? 'A Head'} has posted: "$postContentPreview"';

      final facultySnapshot =
          await FirebaseFirestore.instance
              .collection('Faculties')
              .where('headUid', isEqualTo: userId)
              .get();
      final studentSnapshot =
          await FirebaseFirestore.instance
              .collection('Students')
              .where('headUid', isEqualTo: userId)
              .get();

      recipientUids.addAll(facultySnapshot.docs.map((doc) => doc.id));
      recipientUids.addAll(studentSnapshot.docs.map((doc) => doc.id));
    } else if (userRole == 'Faculty' && userId != null && userHeadUid != null) {
      notificationTitle = 'New Post from ${userName ?? 'Faculty'}';
      notificationMessage =
          '${userName ?? 'A Faculty'} has posted: "$postContentPreview"';

      recipientUids.add(userHeadUid);
      final studentSnapshot =
          await FirebaseFirestore.instance
              .collection('Students')
              .where('headUid', isEqualTo: userHeadUid)
              .get();
      recipientUids.addAll(studentSnapshot.docs.map((doc) => doc.id));
    }

    for (String recipientUid in recipientUids.toSet()) {
      if (recipientUid != userId && recipientUid.isNotEmpty) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'recipientId': recipientUid,
          'senderId': userId,
          'senderName': userName,
          'userProfileUrl': userProfileUrl,
          'title': notificationTitle,
          'message': notificationMessage,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'type': 'newPost',
          'targetId': postId,
          'targetType': 'post',
        });
      }
    }
  }
}

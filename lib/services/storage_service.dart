import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  /// Upload an image file and return the download URL.
  /// Returns null on failure.
  Future<String?> uploadMealImage({
    required String userId,
    required File imageFile,
    String? mealId, // optional, for folder naming
  }) async {
    try {
      // Create a unique filename
      final fileName = '${_uuid.v4()}.jpg';
      final ref = _storage.ref().child('meals/$userId/$fileName');

      // Upload the file
      final uploadTask = await ref.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }
}
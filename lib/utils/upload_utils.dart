import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

// API endpoint for signed URL generation
const String _apiBaseUrl = 'https://asia-south1-event-manager-dfd26.cloudfunctions.net/api';

// Helper function to get Firebase ID token
Future<String> _getFirebaseIdToken() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('User not authenticated');
  }
  return await user.getIdToken() ?? '';
}

// Helper function to detect content type from file extension
String _getContentType(String filePath) {
  final ext = filePath.split('.').last.toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'svg':
      return 'image/svg+xml';
    default:
      return 'application/octet-stream';
  }
}

// Core function to upload file using signed URL
Future<String> _uploadWithSignedUrl(String filePath, String storagePath) async {
  try {
    final file = File(filePath);
    final contentType = _getContentType(filePath);
    final idToken = await _getFirebaseIdToken();

    // Step 1: Get signed URL from Cloud Function
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/upload/signed-url'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'filePath': storagePath,
        'contentType': contentType,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get signed URL: ${response.body}');
    }

    final responseData = jsonDecode(response.body);
    final signedUrl = responseData['signedUrl'] as String;
    final publicUrl = responseData['publicUrl'] as String;
    final token = responseData['token'] as String;

    // Step 2: Upload file to signed URL with token in headers
    final fileBytes = await file.readAsBytes();
    final uploadResponse = await http.put(
      Uri.parse(signedUrl),
      headers: {
        'Content-Type': contentType,
        'x-goog-meta-firebasestoragedownloadtokens': token,
      },
      body: fileBytes,
    );

    if (uploadResponse.statusCode != 200) {
      throw Exception('Failed to upload file: ${uploadResponse.statusCode}');
    }

    return publicUrl;
  } catch (e) {
    rethrow;
  }
}

// Upload announcement image
Future<String> uploadAnnouncementImage(String filePath) async {
  try {
    final fileExt = filePath.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final storagePath = 'announcements/$fileName';

    return await _uploadWithSignedUrl(filePath, storagePath);
  } catch (e) {
    rethrow;
  }
}

// Upload club image (logo or background)
Future<String> uploadClubImage(String clubId, String filePath, String type) async {
  try {
    final fileExt = filePath.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final storagePath = 'clubs/$clubId/${type}_$fileName';

    return await _uploadWithSignedUrl(filePath, storagePath);
  } catch (e) {
    rethrow;
  }
}

// Upload map marker image
Future<String> uploadMapMarkerImage(String filePath) async {
  try {
    final fileExt = filePath.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final storagePath = 'mapMarkers/$fileName';

    return await _uploadWithSignedUrl(filePath, storagePath);
  } catch (e) {
    rethrow;
  }
}

// Upload user profile image and update Firestore
Future<String> uploadUserProfileImage(String uid, String filePath) async {
  try {
    final fileExt = filePath.split('.').last;
    final storagePath = 'users/$uid/profile.$fileExt';

    return await _uploadWithSignedUrl(filePath, storagePath);
  } catch (e) {
    rethrow;
  }
}

// Upload user background image and update Firestore
Future<String> uploadUserBackgroundImage(String uid, String filePath) async {
  try {
    final fileExt = filePath.split('.').last;
    final storagePath = 'users/$uid/background.$fileExt';

    return await _uploadWithSignedUrl(filePath, storagePath);
  } catch (e) {
    rethrow;
  }
}

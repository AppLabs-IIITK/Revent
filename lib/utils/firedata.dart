import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_manager/models/announcement.dart';
import 'package:events_manager/models/map_marker.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Export upload utilities
export 'upload_utils.dart';

// Utility function to get current user metadata
Map<String, dynamic> _getUserMetadata() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return {
      'userId': 'system',
      'userEmail': 'system',
    };
  }

  return {
    'userId': user.uid,
    'userEmail': user.email ?? 'unknown',
  };
}

// Utility function to add metadata to data
Map<String, dynamic> _addMetadata(Map<String, dynamic> data) {
  // Create a copy of the data to avoid modifying the original
  final result = Map<String, dynamic>.from(data);
  // Add metadata
  result['_metadata'] = _getUserMetadata();
  return result;
}

// Utility function to add delete metadata before deletion
Future<void> _addDeleteMetadata(String collection, String documentId) async {
  try {
    final metadata = _getUserMetadata();
    await FirebaseFirestore.instance
        .collection(collection)
        .doc(documentId)
        .update({'_deleteMetadata': metadata});
  } catch (e) {
    // Silently fail - we don't want to interrupt the main flow if metadata update fails
  }
}

Future<String> sendEvent(Map<String, dynamic> eventJson) async {
  final firestore = FirebaseFirestore.instance;

  // Create document reference first to get the ID
  final docRef = firestore.collection('events').doc();

  // Add the ID to the event data
  eventJson['id'] = docRef.id;
  eventJson = _addMetadata(eventJson);

  // Create the document with ID in one write operation
  await docRef.set(eventJson);

  return docRef.id;
}

Future<void> updateEvent(String eventId, Map<String, dynamic> eventJson) async {
  final firestore = FirebaseFirestore.instance;
  eventJson['id'] = eventId;
  // Add metadata to the event data
  final eventWithMetadata = _addMetadata(eventJson);
  await firestore.collection('events').doc(eventId).update(eventWithMetadata);
}

Future<void> deleteEvent(String eventId) async {
  try {
    final firestore = FirebaseFirestore.instance;

    // First, add delete metadata to the document that's about to be deleted
    await _addDeleteMetadata('events', eventId);

    // Then delete the document
    await firestore.collection('events').doc(eventId).delete();
  } catch (e) {
    rethrow;
  }
}

// Announcements Firebase Functions
Future<List<Announcement>> loadAnnouncementsbyClubId(String clubId) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final doc = await firestore.collection('announcements').doc(clubId).get();

    if (!doc.exists || !doc.data()!.containsKey('announcementsList')) {
      return [];
    }

    final List<dynamic> announcementsList = doc.data()!['announcementsList'];
    return announcementsList
        .map((json) => Announcement.fromJson(json))
        .toList();
  } catch (e) {
    return [];
  }
}

Future<List<Announcement>> loadAllAnnouncements() async {
  final firestore = FirebaseFirestore.instance;
  final clubIdsList = await firestore.collection('announcements').get();
  final clubIds = clubIdsList.docs.map((doc) => doc.id).toList();
  final announcements = await Future.wait(
      clubIds.map((clubId) => loadAnnouncementsbyClubId(clubId)));
  final allAnnouncements =
      announcements.expand((announcements) => announcements).toList();
  allAnnouncements.sort((a, b) =>
      b.date.compareTo(a.date)); // Order announcements by date ascending
  return allAnnouncements;
}

Future<void> addAnnouncement(Announcement announcement) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final docRef =
        firestore.collection('announcements').doc(announcement.clubId);

    final doc = await docRef.get();
    List<Map<String, dynamic>> announcementsList = [];

    if (doc.exists && doc.data()!.containsKey('announcementsList')) {
      announcementsList =
          List<Map<String, dynamic>>.from(doc.data()!['announcementsList']);
    }

    // Add the announcement without metadata to the list
    // No need to add metadata to individual announcements
    announcementsList.insert(0, announcement.toJson());
    announcementsList = announcementsList.take(50).toList();

    // Add metadata only to the entire document update
    final dataWithMetadata = _addMetadata({'announcementsList': announcementsList});
    await docRef.set(dataWithMetadata);
  } catch (e) {
    rethrow;
  }
}

Future<void> updateAnnouncement(
    String clubId, int index, Announcement announcement) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final docRef = firestore.collection('announcements').doc(clubId);

    final doc = await docRef.get();
    if (!doc.exists || !doc.data()!.containsKey('announcementsList')) {
      throw Exception('No announcements found');
    }

    List<Map<String, dynamic>> announcementsList =
        List<Map<String, dynamic>>.from(doc.data()!['announcementsList']);
    if (index >= announcementsList.length) {
      throw Exception('Invalid announcement index');
    }

    // Update the announcement without adding metadata to it
    announcementsList[index] = announcement.toJson();

    // Add metadata only to the entire document update
    final dataWithMetadata = _addMetadata({'announcementsList': announcementsList});
    await docRef.update(dataWithMetadata);
  } catch (e) {
    rethrow;
  }
}

Future<void> deleteAnnouncement(String clubId, int index) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final docRef = firestore.collection('announcements').doc(clubId);

    final doc = await docRef.get();
    if (!doc.exists || !doc.data()!.containsKey('announcementsList')) {
      throw Exception('No announcements found');
    }

    List<Map<String, dynamic>> announcementsList =
        List<Map<String, dynamic>>.from(doc.data()!['announcementsList']);
    if (index >= announcementsList.length) {
      throw Exception('Invalid announcement index');
    }

    // First, add delete metadata to the document
    await _addDeleteMetadata('announcements', clubId);

    // Then remove the announcement and update
    announcementsList.removeAt(index);

    // Add metadata to the entire document update
    final dataWithMetadata = _addMetadata({'announcementsList': announcementsList});
    await docRef.update(dataWithMetadata);
  } catch (e) {
    rethrow;
  }
}

Future<void> updateClubBackground(String clubId, String imageUrl) async {
  final firestore = FirebaseFirestore.instance;
  // Add metadata to the update
  final dataWithMetadata = _addMetadata({'backgroundImageUrl': imageUrl});
  await firestore.collection('clubs').doc(clubId).update(dataWithMetadata);
}

Future<void> updateClubLogo(String clubId, String imageUrl) async {
  final firestore = FirebaseFirestore.instance;
  // Add metadata to the update
  final dataWithMetadata = _addMetadata({'logoUrl': imageUrl});
  await firestore.collection('clubs').doc(clubId).update(dataWithMetadata);
}

Future<void> updateClubDetails(String clubId, {
  String? name,
  String? about,
  List<String>? adminEmails,
  List<String>? socialLinks,
}) async {
  final firestore = FirebaseFirestore.instance;
  final Map<String, dynamic> updateData = {};

  if (name != null) updateData['name'] = name;
  if (about != null) updateData['about'] = about;
  if (adminEmails != null) updateData['adminEmails'] = adminEmails;
  if (socialLinks != null) updateData['socialLinks'] = socialLinks;

  if (updateData.isNotEmpty) {
    // Add metadata to the update
    final dataWithMetadata = _addMetadata(updateData);
    await firestore.collection('clubs').doc(clubId).update(dataWithMetadata);
  }
}

// Map Marker Functions
Future<List<MapMarker>> loadMapMarkers() async {
  try {
    final firestore = FirebaseFirestore.instance;
    final markersSnapshot = await firestore.collection('mapMarkers')
        .orderBy('createdAt', descending: true)
        .get();

    return markersSnapshot.docs
        .map((doc) => MapMarker.fromJson(doc.data()))
        .toList();
  } catch (e) {
    return [];
  }
}

Future<void> addMapMarker(MapMarker marker) async {
  try {
    final firestore = FirebaseFirestore.instance;
    // Add metadata to the marker data
    final markerWithMetadata = _addMetadata(marker.toJson());
    await firestore.collection('mapMarkers')
        .doc(marker.id)
        .set(markerWithMetadata);
  } catch (e) {
    rethrow;
  }
}

Future<void> updateMapMarker(MapMarker marker) async {
  try {
    final firestore = FirebaseFirestore.instance;
    // Add metadata to the marker data
    final markerWithMetadata = _addMetadata(marker.toJson());
    await firestore.collection('mapMarkers')
        .doc(marker.id)
        .update(markerWithMetadata);
  } catch (e) {
    rethrow;
  }
}

Future<void> deleteMapMarker(String markerId) async {
  try {
    final firestore = FirebaseFirestore.instance;

    // First, add delete metadata to the document that's about to be deleted
    await _addDeleteMetadata('mapMarkers', markerId);

    // Then delete the document
    await firestore.collection('mapMarkers')
        .doc(markerId)
        .delete();
  } catch (e) {
    rethrow;
  }
}

Future<void> updateUserProfile(String uid, {String? name, String? photoURL, String? backgroundImageUrl}) async {
  final Map<String, dynamic> updates = {};
  if (name != null) updates['name'] = name;
  if (photoURL != null) updates['photoURL'] = photoURL;
  if (backgroundImageUrl != null) updates['backgroundImageUrl'] = backgroundImageUrl;

  if (updates.isNotEmpty) {
    // Add metadata to the update
    final updatesWithMetadata = _addMetadata(updates);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update(updatesWithMetadata);
  }
}
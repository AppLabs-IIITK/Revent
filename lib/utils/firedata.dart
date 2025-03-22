import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_manager/models/announcement.dart';
import 'package:events_manager/models/map_marker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

Future<List<Map<String, dynamic>>> loadEvents() async {
  final firestore = FirebaseFirestore.instance;
  final events =
      await firestore.collection('events').orderBy('startTime').get();

  final eventList = events.docs.map((doc) => doc.data()).toList();
  return eventList;
}

Future<List<Map<String, dynamic>>> loadEventsByDate(DateTime date) async {
  final events = await loadEvents();
  final eventsByDate = events.where((event) {
    final eventDate = event['startTime'].toDate();
    return eventDate.year == date.year &&
        eventDate.month == date.month &&
        eventDate.day == date.day;
  }).toList();
  return eventsByDate;
}

Future<List<Map<String, dynamic>>> loadTodayEvents() async {
  return loadEventsByDate(DateTime.now());
}

Future<List<Map<String, dynamic>>> loadEventsByDateRange(
    DateTime startDate, DateTime endDate) async {
  final firestore = FirebaseFirestore.instance;

  // Convert to Timestamps for Firestore query
  final startTimestamp = Timestamp.fromDate(startDate);
  final endTimestamp = Timestamp.fromDate(endDate);

  final events = await firestore
      .collection('events')
      .where('startTime', isGreaterThanOrEqualTo: startTimestamp)
      .where('startTime', isLessThanOrEqualTo: endTimestamp)
      .orderBy('startTime')
      .get();

  final eventList = events.docs.map((doc) => doc.data()).toList();

  return eventList;
}

Future<String> sendEvent(Map<String, dynamic> eventJson) async {
  final firestore = FirebaseFirestore.instance;
  // Add metadata to the event data
  final eventWithMetadata = _addMetadata(eventJson);
  final docRef = await firestore.collection('events').add(eventWithMetadata);
  await docRef.update({'id': docRef.id});

  // Create a notification for the new event
  await _createEventNotification(eventJson, docRef.id);

  return docRef.id;
}

// Function to create a notification when an event is added
Future<void> _createEventNotification(Map<String, dynamic> eventJson, String eventId) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final clubId = eventJson['clubId'] as String;

    // Get club name
    final clubDoc = await firestore.collection('clubs').doc(clubId).get();
    String clubName = 'Unknown Club';
    if (clubDoc.exists && clubDoc.data() != null) {
      final data = clubDoc.data()!;
      if (data.containsKey('name')) {
        clubName = data['name'] as String;
      }
    }

    // Get all users
    final usersSnapshot = await firestore.collection('users').get();

    // Create a notification for each user
    for (var userDoc in usersSnapshot.docs) {
      final userId = userDoc.id;

      await firestore.collection('notifications').add({
        'title': 'New Event: ${eventJson['title']}',
        'message': 'A new event has been added by $clubName',
        'time': Timestamp.now(),
        'eventId': eventId,
        'clubId': clubId,
        'tags': [clubName],
        'read': false,
        'userId': userId,
      });
    }
  } catch (e) {
    print('Error creating event notification: $e');
  }
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

// Supabase Storage Function
Future<String> uploadAnnouncementImage(String filePath) async {
  try {
    final supabase = Supabase.instance.client;
    final file = File(filePath);
    final fileExt = filePath.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final path = 'announcements/$fileName';

    supabase.storage.from('assets').upload(path, file);
    final imageUrl = supabase.storage.from('assets').getPublicUrl(path);

    return imageUrl;
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

Future<String> uploadClubImage(String clubId, String filePath, String type) async {
  try {
    final file = File(filePath);
    final fileExt = filePath.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final path = 'clubs/$clubId/${type}_$fileName';

    final storageRef = FirebaseStorage.instance.ref(path);
    await storageRef.putFile(file);
    final imageUrl = await storageRef.getDownloadURL();

    return imageUrl;
  } catch (e) {
    rethrow;
  }
}

Future<void> updateEventLinks(String eventId, {String? registrationLink, String? feedbackLink}) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final Map<String, dynamic> updateData = {};

    if (registrationLink != null) {
      updateData['registrationLink'] = registrationLink;
    }

    if (feedbackLink != null) {
      updateData['feedbackLink'] = feedbackLink;
    }

    if (updateData.isNotEmpty) {
      // Add metadata to the update
      final dataWithMetadata = _addMetadata(updateData);
      await firestore.collection('events').doc(eventId).update(dataWithMetadata);
    }
  } catch (e) {
    rethrow;
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

Future<String> uploadMapMarkerImage(String filePath) async {
  try {
    final supabase = Supabase.instance.client;
    final file = File(filePath);
    final fileExt = filePath.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final path = 'mapMarkers/$fileName';

    supabase.storage.from('assets').upload(path, file);
    final imageUrl = supabase.storage.from('assets').getPublicUrl(path);

    return imageUrl;
  } catch (e) {
    rethrow;
  }
}

Future<String> uploadUserProfileImage(String uid, String filePath) async {
  try {
    final file = File(filePath);
    final fileExt = filePath.split('.').last;
    final path = 'users/$uid/profile.$fileExt';

    final storageRef = FirebaseStorage.instance.ref(path);
    await storageRef.putFile(file);
    final imageUrl = await storageRef.getDownloadURL();

    // Update the user document with the new photo URL
    final updateData = {'photoURL': imageUrl};
    final dataWithMetadata = _addMetadata(updateData);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update(dataWithMetadata);

    return imageUrl;
  } catch (e) {
    rethrow;
  }
}

Future<String> uploadUserBackgroundImage(String uid, String filePath) async {
  try {
    final file = File(filePath);
    final fileExt = filePath.split('.').last;
    final path = 'users/$uid/background.$fileExt';

    final storageRef = FirebaseStorage.instance.ref(path);
    await storageRef.putFile(file);
    final imageUrl = await storageRef.getDownloadURL();

    // Update the user document with the new background URL
    final updateData = {'backgroundImageUrl': imageUrl};
    final dataWithMetadata = _addMetadata(updateData);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update(dataWithMetadata);

    return imageUrl;
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
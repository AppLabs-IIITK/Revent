import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_manager/models/admin_log.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Admin logs providers with pagination
class AdminLogsPaginationState {
  final List<AdminLog> logs;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final bool isLoading;

  AdminLogsPaginationState({
    required this.logs,
    this.lastDocument,
    required this.hasMore,
    required this.isLoading,
  });

  AdminLogsPaginationState copyWith({
    List<AdminLog>? logs,
    DocumentSnapshot? lastDocument,
    bool? hasMore,
    bool? isLoading,
  }) {
    return AdminLogsPaginationState(
      logs: logs ?? this.logs,
      lastDocument: lastDocument ?? this.lastDocument,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AdminLogsPaginationNotifier extends StateNotifier<AdminLogsPaginationState> {
  static const int _pageSize = 50;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AdminLogsPaginationNotifier() : super(AdminLogsPaginationState(
    logs: [],
    hasMore: true,
    isLoading: false,
  )) {
    loadInitialLogs();
  }

  Future<void> loadInitialLogs() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true);

    try {
      final querySnapshot = await _firestore
          .collection('admin_logs')
          .orderBy('timestamp', descending: true)
          .limit(_pageSize)
          .get();

      final logs = querySnapshot.docs
          .map((doc) => AdminLog.fromFirestore(doc))
          .toList();

      state = AdminLogsPaginationState(
        logs: logs,
        lastDocument: querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
        hasMore: querySnapshot.docs.length == _pageSize,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadMoreLogs() async {
    if (state.isLoading || !state.hasMore || state.lastDocument == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final querySnapshot = await _firestore
          .collection('admin_logs')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(state.lastDocument!)
          .limit(_pageSize)
          .get();

      final newLogs = querySnapshot.docs
          .map((doc) => AdminLog.fromFirestore(doc))
          .toList();

      state = AdminLogsPaginationState(
        logs: [...state.logs, ...newLogs],
        lastDocument: querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : state.lastDocument,
        hasMore: querySnapshot.docs.length == _pageSize,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  void refresh() {
    state = AdminLogsPaginationState(
      logs: [],
      hasMore: true,
      isLoading: false,
    );
    loadInitialLogs();
  }
}

final adminLogsPaginationProvider = StateNotifierProvider.autoDispose<AdminLogsPaginationNotifier, AdminLogsPaginationState>((ref) {
  return AdminLogsPaginationNotifier();
});

// Admin logs filter providers
final adminLogsSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');
final adminLogsCollectionFilterProvider = StateProvider.autoDispose<String>((ref) => 'All');
final adminLogsOperationFilterProvider = StateProvider.autoDispose<String>((ref) => 'All');
final adminLogsSortOptionProvider = StateProvider.autoDispose<String>((ref) => 'Newest First');

final filteredAdminLogsProvider = Provider.autoDispose<List<AdminLog>>((ref) {
  final searchQuery = ref.watch(adminLogsSearchQueryProvider);
  final collectionFilter = ref.watch(adminLogsCollectionFilterProvider);
  final operationFilter = ref.watch(adminLogsOperationFilterProvider);
  final sortOption = ref.watch(adminLogsSortOptionProvider);
  final paginationState = ref.watch(adminLogsPaginationProvider);
  final logs = paginationState.logs;

  // Filter by search query
  var filtered = searchQuery.isEmpty
      ? logs
      : logs.where((log) =>
          log.collection.toLowerCase().contains(searchQuery.toLowerCase()) ||
          log.documentId.toLowerCase().contains(searchQuery.toLowerCase()) ||
          log.operation.toLowerCase().contains(searchQuery.toLowerCase()) ||
          log.userEmail.toLowerCase().contains(searchQuery.toLowerCase()) ||
          log.changeDescription.toLowerCase().contains(searchQuery.toLowerCase())).toList();

  // Filter by collection
  if (collectionFilter != 'All') {
    // Normalize the filter value to match Firestore collection names
    String targetCollection;
    switch (collectionFilter) {
      case 'Map Markers':
        targetCollection = 'mapmarkers'; // Firestore collection is 'mapMarkers'
        break;
      default:
        targetCollection = collectionFilter.toLowerCase();
    }
    filtered = filtered.where((log) => log.collection.toLowerCase() == targetCollection).toList();
  }

  // Filter by operation type
  if (operationFilter != 'All') {
    String operationPrefix;
    switch (operationFilter) {
      case 'Create':
        operationPrefix = 'create';
        break;
      case 'Update':
        operationPrefix = 'update';
        break;
      case 'Delete':
        operationPrefix = 'delete';
        break;
      default:
        operationPrefix = '';
    }
    filtered = filtered.where((log) =>
      log.operation.toLowerCase().contains(operationPrefix.toLowerCase())
    ).toList();
  }

  // Sort logs
  switch (sortOption) {
    case 'Oldest First':
      filtered.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      break;
    case 'Newest First':
    default:
      filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      break;
  }

  return filtered;
});
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_manager/models/admin_log.dart';
import 'package:events_manager/providers/stream_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    // Reset filter state when screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminLogsSearchQueryProvider.notifier).state = '';
      ref.read(adminLogsCollectionFilterProvider.notifier).state = 'All';
      ref.read(adminLogsOperationFilterProvider.notifier).state = 'All';
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _submitSearch() {
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = ref.watch(filteredAdminLogsProvider);
    final isUserAdmin = ref.watch(isUserAdminProvider);

    return PopScope(
      canPop: !_isSearchExpanded,
      onPopInvokedWithResult: (didPop, result) {
        if (_isSearchExpanded) {
          setState(() {
            _isSearchExpanded = false;
            _searchController.clear();
            ref.read(adminLogsSearchQueryProvider.notifier).state = '';
          });
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: _isSearchExpanded
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFAEE7FF)),
                  onPressed: () {
                    setState(() {
                      _isSearchExpanded = false;
                      _searchController.clear();
                      ref.read(adminLogsSearchQueryProvider.notifier).state = '';
                    });
                  },
                )
              : IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFAEE7FF)),
                  onPressed: () => Navigator.pop(context),
                ),
          title: _isSearchExpanded
              ? TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: false,
                  style: const TextStyle(color: Color(0xFFAEE7FF)),
                  decoration: const InputDecoration(
                    hintText: 'Search logs...',
                    hintStyle: TextStyle(color: Color(0xFF83ACBD)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (value) {
                    ref.read(adminLogsSearchQueryProvider.notifier).state = value;
                  },
                  onSubmitted: (_) => _submitSearch(),
                )
              : const Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFAEE7FF),
                  ),
                ),
          actions: [
            if (!_isSearchExpanded)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.search, color: Color(0xFFAEE7FF)),
                  onPressed: () {
                    setState(() {
                      _isSearchExpanded = true;
                    });
                    // Focus the search field when expanding
                    _searchFocusNode.requestFocus();
                  },
                ),
              ),
          ],
        ),
        body: !isUserAdmin
            ? _buildNotAdminView()
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF07181F), Color(0xFF000000)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: CustomScrollView(
                    slivers: [
                      // Filter options
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildFilterChip('All', adminLogsCollectionFilterProvider),
                                    _buildFilterChip('Events', adminLogsCollectionFilterProvider),
                                    _buildFilterChip('Announcements', adminLogsCollectionFilterProvider),
                                    _buildFilterChip('Clubs', adminLogsCollectionFilterProvider),
                                    _buildFilterChip('Users', adminLogsCollectionFilterProvider),
                                    _buildFilterChip('Map Markers', adminLogsCollectionFilterProvider),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildFilterChip('All', adminLogsOperationFilterProvider),
                                    _buildFilterChip('Create', adminLogsOperationFilterProvider),
                                    _buildFilterChip('Update', adminLogsOperationFilterProvider),
                                    _buildFilterChip('Delete', adminLogsOperationFilterProvider),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Logs list
                      filteredLogs.isEmpty
                          ? SliverFillRemaining(child: _buildEmptyState())
                          : SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final log = filteredLogs[index];
                                    // Only skip pure ID updates that have no other changes
                                    if (log.operation.startsWith('update_') &&
                                        log.getChangedFields().length == 1 &&
                                        log.getChangedFields().first == 'id' &&
                                        log.beforeData?['id'] != null &&
                                        log.afterData?['id'] != null) {
                                      return null;
                                    }
                                    return _buildLogCard(log);
                                  },
                                  childCount: filteredLogs.length,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildNotAdminView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF07181F), Color(0xFF000000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.admin_panel_settings,
                color: Color(0xFF83ACBD),
                size: 64,
              ),
              const SizedBox(height: 24),
              const Text(
                'Admin Access Required',
                style: TextStyle(
                  color: Color(0xFFAEE7FF),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'You need to be an admin of at least one club to access the admin dashboard.',
                style: TextStyle(
                  color: Color(0xFF83ACBD),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E668A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, StateProvider<String> provider) {
    final selectedValue = ref.watch(provider);
    final isSelected = selectedValue == label;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFFAEE7FF) : const Color(0xFF83ACBD),
            fontSize: 12,
          ),
        ),
        backgroundColor: const Color(0xFF0F2026),
        selectedColor: const Color(0xFF17323D),
        checkmarkColor: const Color(0xFFAEE7FF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? const Color(0xFF71C2E4) : const Color(0xFF17323D),
          ),
        ),
        onSelected: (selected) {
          ref.read(provider.notifier).state = selected ? label : 'All';
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off,
            color: Color(0xFF83ACBD),
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'No logs found',
            style: TextStyle(
              color: Color(0xFFAEE7FF),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isEmpty
                ? 'Try selecting a different filter'
                : 'Try a different search term',
            style: const TextStyle(
              color: Color(0xFF83ACBD),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(AdminLog log) {
    // Determine operation color
    Color operationColor;
    IconData operationIcon;

    if (log.operation.startsWith('create_')) {
      operationColor = Colors.green;
      operationIcon = FontAwesomeIcons.plus;
    } else if (log.operation.startsWith('update_')) {
      operationColor = Colors.blue;
      operationIcon = FontAwesomeIcons.pen;
    } else if (log.operation.startsWith('delete_')) {
      operationColor = Colors.red;
      operationIcon = FontAwesomeIcons.trash;
    } else {
      operationColor = Colors.grey;
      operationIcon = FontAwesomeIcons.question;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF0F2027),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF17323D), width: 1),
      ),
      elevation: 4,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: CircleAvatar(
          backgroundColor: operationColor.withValues(alpha:0.2),
          child: Icon(operationIcon, color: operationColor, size: 16),
        ),
        title: Text(
          log.changeDescription,
          style: const TextStyle(
            color: Color(0xFFAEE7FF),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  FontAwesomeIcons.solidClock,
                  color: const Color(0xFF83ACBD),
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM d, yyyy • h:mm a').format(log.timestamp),
                  style: const TextStyle(
                    color: Color(0xFF83ACBD),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  FontAwesomeIcons.solidUser,
                  color: const Color(0xFF83ACBD),
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  log.userEmail,
                  style: const TextStyle(
                    color: Color(0xFF83ACBD),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          const Divider(color: Color(0xFF17323D)),
          if (log.beforeData != null || log.afterData != null)
            _buildDataComparisonTable(log),
        ],
      ),
    );
  }

  Widget _buildDataComparisonTable(AdminLog log) {
    // Special handling for optimized announcement logs
    if (log.collection == 'announcements') {
      return _buildAnnouncementLogDetails(log);
    }

    // Default handling for other collections
    final changedFields = log.getChangedFields().where((field) => field != 'id').toList();
    final allFields = <String>{};

    if (log.beforeData != null) {
      allFields.addAll(log.beforeData!.keys.where((key) => key != 'id'));
    }
    if (log.afterData != null) {
      allFields.addAll(log.afterData!.keys.where((key) => key != 'id'));
    }

    if (log.operation.startsWith('create_')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Created Data:',
            style: TextStyle(
              color: Color(0xFFAEE7FF),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildDataTable(Map<String, dynamic>.from(log.afterData ?? {})..remove('id')),
        ],
      );
    } else if (log.operation.startsWith('delete_')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deleted Data:',
            style: TextStyle(
              color: Color(0xFFAEE7FF),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildDataTable(Map<String, dynamic>.from(log.beforeData ?? {})..remove('id')),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'All Fields:',
            style: TextStyle(
              color: Color(0xFFAEE7FF),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
            },
            border: TableBorder.all(
              color: const Color(0xFF17323D),
              width: 1,
            ),
            children: [
              const TableRow(
                decoration: BoxDecoration(
                  color: Color(0xFF17323D),
                ),
                children: [
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Field',
                      style: TextStyle(
                        color: Color(0xFFAEE7FF),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Before',
                      style: TextStyle(
                        color: Color(0xFFAEE7FF),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'After',
                      style: TextStyle(
                        color: Color(0xFFAEE7FF),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              ...allFields.map((field) {
                final isChanged = changedFields.contains(field);
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        field,
                        style: const TextStyle(
                          color: Color(0xFFAEE7FF),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        _formatFieldValue(log.beforeData?[field]),
                        style: TextStyle(
                          color: isChanged ? Colors.red : const Color(0xFFAEE7FF),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        _formatFieldValue(log.afterData?[field]),
                        style: TextStyle(
                          color: isChanged ? Colors.green : const Color(0xFFAEE7FF),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildAnnouncementLogDetails(AdminLog log) {
    if (log.operation == 'add_announcement') {
      final announcement = log.afterData?['announcement'] as Map<String, dynamic>?;
      final totalCount = log.afterData?['totalCount'] ?? 0;
      final previousCount = log.beforeData?['totalCount'] ?? 0;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF83ACBD), size: 16),
              const SizedBox(width: 8),
              Text(
                'Total announcements: $previousCount → $totalCount',
                style: const TextStyle(color: Color(0xFF83ACBD), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'New Announcement:',
            style: TextStyle(
              color: Color(0xFFAEE7FF),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (announcement != null) _buildAnnouncementCard(announcement),
        ],
      );
    } else if (log.operation == 'delete_announcement') {
      final announcement = log.beforeData?['announcement'] as Map<String, dynamic>?;
      final index = log.beforeData?['index'] ?? '?';
      final totalCount = log.beforeData?['totalCount'] ?? 0;
      final newCount = log.afterData?['totalCount'] ?? 0;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF83ACBD), size: 16),
              const SizedBox(width: 8),
              Text(
                'Total announcements: $totalCount → $newCount • Position: $index',
                style: const TextStyle(color: Color(0xFF83ACBD), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Deleted Announcement:',
            style: TextStyle(
              color: Color(0xFFAEE7FF),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (announcement != null) _buildAnnouncementCard(announcement),
        ],
      );
    } else if (log.operation == 'update_announcement') {
      final beforeAnn = log.beforeData?['announcement'] as Map<String, dynamic>?;
      final afterAnn = log.afterData?['announcement'] as Map<String, dynamic>?;
      final index = log.afterData?['index'] ?? '?';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF83ACBD), size: 16),
              const SizedBox(width: 8),
              Text(
                'Position: $index',
                style: const TextStyle(color: Color(0xFF83ACBD), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Before:',
            style: TextStyle(
              color: Colors.red,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (beforeAnn != null) _buildAnnouncementCard(beforeAnn),
          const SizedBox(height: 12),
          const Text(
            'After:',
            style: TextStyle(
              color: Colors.green,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (afterAnn != null) _buildAnnouncementCard(afterAnn),
        ],
      );
    } else {
      // Fallback for create/delete document operations
      return _buildDataTable(log.afterData ?? log.beforeData ?? {});
    }
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF17323D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A4A5A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            announcement['title'] ?? 'No title',
            style: const TextStyle(
              color: Color(0xFFAEE7FF),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (announcement['description'] != null) ...[
            const SizedBox(height: 8),
            Text(
              announcement['description'],
              style: const TextStyle(
                color: Color(0xFF83ACBD),
                fontSize: 12,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (announcement['date'] != null)
                _buildInfoChip(Icons.calendar_today, _formatFieldValue(announcement['date'])),
              if (announcement['clubId'] != null)
                _buildInfoChip(Icons.group, announcement['clubId']),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2027),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF83ACBD)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF83ACBD),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return const Text(
        'No data available',
        style: TextStyle(
          color: Color(0xFF83ACBD),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(3),
      },
      border: TableBorder.all(
        color: const Color(0xFF17323D),
        width: 1,
      ),
      children: [
        const TableRow(
          decoration: BoxDecoration(
            color: Color(0xFF17323D),
          ),
          children: [
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Field',
                style: TextStyle(
                  color: Color(0xFFAEE7FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Value',
                style: TextStyle(
                  color: Color(0xFFAEE7FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        ...data.entries.map((entry) {
          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  entry.key,
                  style: const TextStyle(
                    color: Color(0xFFAEE7FF),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _formatFieldValue(entry.value),
                  style: const TextStyle(
                    color: Color(0xFFAEE7FF),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  String _formatFieldValue(dynamic value) {
    if (value == null) {
      return 'null';
    } else if (value is Timestamp) {
      return DateFormat('MMM d, yyyy • h:mm a').format(value.toDate());
    } else if (value is List) {
      if (value.isEmpty) {
        return '[]';
      }
      return '[${value.take(3).join(', ')}${value.length > 3 ? ', ...' : ''}]';
    } else if (value is Map) {
      if (value.isEmpty) {
        return '{}';
      }
      // For announcements, only show relevant fields
      final displayMap = Map<String, dynamic>.from(value);
      displayMap.removeWhere((key, _) => !['title', 'description', 'clubId', 'date'].contains(key));
      return '{${displayMap.keys.take(3).join(', ')}${displayMap.length > 3 ? ', ...' : ''}}';
    } else {
      return value.toString();
    }
  }
}
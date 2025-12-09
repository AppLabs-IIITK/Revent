import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void showNotificationSettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const NotificationSettingsSheet(),
  );
}

class NotificationSettingsSheet extends StatefulWidget {
  const NotificationSettingsSheet({super.key});

  @override
  State<NotificationSettingsSheet> createState() => _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState extends State<NotificationSettingsSheet> {
  NotificationSettings? _notificationSettings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (mounted) {
        setState(() {
          _notificationSettings = settings;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool get _isEnabled {
    return _notificationSettings?.authorizationStatus == AuthorizationStatus.authorized ||
        _notificationSettings?.authorizationStatus == AuthorizationStatus.provisional;
  }

  String get _statusText {
    if (_notificationSettings == null) return 'Checking...';

    switch (_notificationSettings!.authorizationStatus) {
      case AuthorizationStatus.authorized:
        return 'Enabled';
      case AuthorizationStatus.provisional:
        return 'Enabled';
      case AuthorizationStatus.denied:
        return 'Disabled';
      case AuthorizationStatus.notDetermined:
        return 'Not Set';
    }
  }

  Future<void> _handleSettingsAction() async {
    if (kIsWeb) {
      // For web, request permission directly
      try {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        if (mounted) {
          setState(() {
            _notificationSettings = settings;
          });
        }
      } catch (e) {
        debugPrint('Error requesting notification permission for web: $e');
      }
    } else {
      // For mobile, open app settings
      await openAppSettings();
    }
    if(mounted){
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F2026),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF17323D),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_outlined,
                  color: Color(0xFF71C2E4),
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: TextStyle(
                          color: Color(0xFFAEE7FF),
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Manage notification settings',
                        style: TextStyle(
                          color: Color(0xFF83ACBD),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close,
                    color: Color(0xFF83ACBD),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF17323D), height: 1),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        color: Color(0xFF71C2E4),
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Status',
                            style: TextStyle(
                              color: Color(0xFF83ACBD),
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _isEnabled
                                  ? const Color(0xFF0E668A).withValues(alpha: 0.3)
                                  : const Color(0xFF17323D),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isEnabled
                                    ? const Color(0xFF71C2E4)
                                    : const Color(0xFF83ACBD),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isEnabled
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: _isEnabled
                                      ? const Color(0xFF71C2E4)
                                      : const Color(0xFF83ACBD),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _statusText,
                                  style: TextStyle(
                                    color: _isEnabled
                                        ? const Color(0xFF71C2E4)
                                        : const Color(0xFF83ACBD),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Info items
                      _buildInfoItem(
                        Icons.event,
                        'Event Reminders',
                        'Get notified 30 min before events start',
                      ),
                      const SizedBox(height: 12),
                      _buildInfoItem(
                        Icons.campaign,
                        'Announcements',
                        'Instant notifications for new announcements',
                      ),

                      const SizedBox(height: 24),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _handleSettingsAction,
                          icon: Icon(
                            kIsWeb ? Icons.notifications_active : Icons.settings,
                            size: 20,
                          ),
                          label: Text(
                            kIsWeb ? 'Request Permission' : 'Open Device Settings',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0E668A),
                            foregroundColor: const Color.fromARGB(255, 250, 250, 255),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        kIsWeb
                            ? 'Click to request browser notification permission'
                            : 'Manage notification permissions in your device settings',
                        style: const TextStyle(
                          color: Color(0xFF83ACBD),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: const Color(0xFF71C2E4),
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFAEE7FF),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF83ACBD),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

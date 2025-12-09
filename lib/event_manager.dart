import 'dart:io';
import 'dart:math';

import 'package:events_manager/bottom_navbar.dart';
import 'package:events_manager/models/version_info.dart';
import 'package:events_manager/screens/screens.dart';
import 'package:events_manager/utils/common_utils.dart';
import 'package:events_manager/utils/markdown_renderer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:events_manager/providers/stream_providers.dart';

bool hasCheckedForUpdates = false;
final String _currentVersion = '0.4.2'; // Replace with your app's current version

class EventManager extends ConsumerStatefulWidget {
  const EventManager({super.key, required this.user});

  final User user;
  @override
  ConsumerState<EventManager> createState() => _EventManagerState();
}

class _EventManagerState extends ConsumerState<EventManager> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    // Check if providers need to be refreshed (after logout)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final needsRefresh = ref.read(needsProviderRefreshProvider);
      if (needsRefresh) {
        invalidateAllProviders(ref);
        // Reset the flag
        ref.read(needsProviderRefreshProvider.notifier).state = false;
      }
    });

    _screens = [
      DashboardScreen(user: widget.user),
      const EventsScreen(),
      const SearchScreen(),
      const MapScreen(),
    ];

    // Check for updates after the UI is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 1), () {
        if(Platform.isAndroid){
          _checkForUpdates();
        }
      });
    });
  }

   // Simple function to check for app updates
  Future<void> _checkForUpdates() async {
    if (hasCheckedForUpdates) return;
    hasCheckedForUpdates = true;

    try {
      final versionInfo = await VersionInfo.getVersionInfo();

      // Only show dialog if new version is available
      if (versionInfo.isUpdateAvailable(_currentVersion)) {
        _showUpdateDialog(versionInfo);
      }
    } catch (e) {
      // Silently fail - we don't want to interrupt the user experience
      debugPrint('Error checking for updates: $e');
    }
  }

  // Show update dialog with markdown rendering
  void _showUpdateDialog(VersionInfo versionInfo) {
    if (!mounted) return;
    final isRequired = versionInfo.isForceUpdateRequired(_currentVersion);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: const Color(0xFF0F2026),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF17323D)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF173240),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(
                        Icons.system_update,
                        color: Color(0xFFAEE7FF),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isRequired ? 'Required Update' : 'Update Available',
                      style: const TextStyle(
                        color: Color(0xFFAEE7FF),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: SingleChildScrollView(
                    child: MarkdownRenderer(
                      data: versionInfo.getFormattedMessage(),
                      selectable: false,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isRequired)
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'LATER',
                          style: TextStyle(
                            color: Color(0xFF83ACBD),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0E668A),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        final String fallbackUrl = 'https://github.com/E-m-i-n-e-n-c-e/Revent/releases/download/beta1/REvent.v${versionInfo.latestVer}-beta.apk';
                        final String? downloadUrl = versionInfo.downloadUrl;
                        Uri? parsedUri = downloadUrl != null ? Uri.tryParse(downloadUrl) : null;

                        String urlToLaunch;
                        if (parsedUri != null && parsedUri.isAbsolute) {
                          urlToLaunch = downloadUrl!;
                        } else {
                          urlToLaunch = fallbackUrl;
                        }
                        launchUrlExternal(urlToLaunch);
                      },
                      child: const Text(
                        'UPDATE NOW',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive sizing
    final Size screenSize = MediaQuery.of(context).size;
    const double baseWidth = 375.0;
    final double scaleFactor = min(screenSize.width, screenSize.height) / baseWidth;

    // Watch all required providers to check their loading states
    final currentUser = ref.watch(currentUserProvider);
    final clubs = ref.watch(clubsStreamProvider);
    final todaysEvents = ref.watch(todaysEventsStreamProvider);
    final recentAnnouncements = ref.watch(recentAnnouncementsStreamProvider);

    // Show loading screen if any of the providers are loading
    if (currentUser.isLoading || clubs.isLoading || todaysEvents.isLoading || recentAnnouncements.isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF07181F),
                Colors.black,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 4),
                Text(
                  "Welcome to",
                  style: GoogleFonts.dmSans(
                    fontSize: 22 * scaleFactor,
                    fontWeight: FontWeight.w300,
                    color: const Color(0xFF83ACBD),
                  ),
                ),
                SizedBox(height: 10 * scaleFactor),
                SvgPicture.asset(
                  'assets/icons/app_icon.svg',
                  height: 115 * scaleFactor,
                  width: 119 * scaleFactor,
                ),
                SizedBox(height: 8 * scaleFactor),
                Text(
                  'Revent',
                  style: GoogleFonts.dmSans(
                    fontSize: 22 * scaleFactor,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF73A3B6),
                    shadows: const [
                      Shadow(
                        color: Color(0x40000000),
                        blurRadius: 4,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 40 * scaleFactor),
                SizedBox(
                  width: 30 * scaleFactor,
                  height: 30 * scaleFactor,
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF83ACBD)),
                  ),
                ),
                const Spacer(flex: 4),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: CustomBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onItemSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
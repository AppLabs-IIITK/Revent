import 'package:events_manager/bottom_navbar.dart';
import 'package:events_manager/screens/screens.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:events_manager/providers/stream_providers.dart';

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
    _screens = [
      DashboardScreen(user: widget.user),
      const EventsScreen(),
      const SearchScreen(),
      const MapScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive sizing
    final Size screenSize = MediaQuery.of(context).size;
    const double baseWidth = 375.0;
    final double scaleFactor = screenSize.width / baseWidth;

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
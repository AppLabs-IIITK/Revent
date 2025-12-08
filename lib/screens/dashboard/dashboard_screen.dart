import 'package:events_manager/providers/stream_providers.dart';
import 'package:events_manager/screens/announcements/announcements_page.dart';
import 'package:events_manager/screens/dashboard/widgets/add_announcement_form.dart';
import 'package:events_manager/screens/dashboard/widgets/announcement_card.dart';
import 'package:events_manager/screens/dashboard/widgets/announcements_slider.dart';
import 'package:events_manager/utils/firedata.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'widgets/event_card.dart';
import 'widgets/profile_header.dart';
import 'widgets/clubs_container.dart';
import 'package:events_manager/models/announcement.dart';
import 'package:events_manager/screens/events/events_page.dart';
import 'package:events_manager/screens/clubs/all_clubs_page.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({
    super.key,
    required this.user,
  });

  final User user;

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final PageController _pageController = PageController();

  Future<void> _addAnnouncement(Announcement newAnnouncement) async {
    try {
      await addAnnouncement(newAnnouncement);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add announcement: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(todaysEventsStreamProvider);
    final recentAnnouncements = ref.watch(recentAnnouncementsStreamProvider);
    final clubs = ref.watch(clubsStreamProvider);
    final currentUserAsync = ref.watch(currentUserProvider);

    bool isLoading = recentAnnouncements.isLoading || events.isLoading || clubs.isLoading || currentUserAsync.isLoading;

    return Scaffold(
      body: SafeArea(
        child: isLoading
            ? Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF07181F),
                      Color(0xFF000000),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(child: CircularProgressIndicator()))
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF07181F),
                      Color(0xFF000000),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(15, 3, 15, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 2),
                    currentUserAsync.when(
                      data: (user) => ProfileHeader(
                        profileImage: user?.photoURL ?? widget.user.photoURL ?? '',
                      ),
                      loading: () => const ProfileHeader(profileImage: ''),
                      error: (_, __) => const ProfileHeader(profileImage: ''),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.only(left: 14),
                      child: Row(
                        children: [
                          Text(
                            'Announcements',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Inter',
                                ),
                          ),
                          const SizedBox(width: 5),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              ref.read(announcementsFilterClubProvider.notifier).state = 'All Clubs';
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AnnouncementsPage(),
                                ),
                              );
                            },
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'See all',
                                  style: TextStyle(
                                    color: Color.fromRGBO(131, 172, 189, 0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_right,
                                  color: Color.fromRGBO(131, 172, 189, 0.7),
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                            IconButton(
                              style: IconButton.styleFrom(
                                padding: const EdgeInsets.all(0),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddAnnouncementForm(
                                      addAnnouncement: _addAnnouncement,
                                    ),
                                  ),
                                );
                              },
                              icon: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.black,
                                  size: 20,
                                ),
                              ),
                            ) ,
                        ],
                      ),
                    ),
                    recentAnnouncements.when(
                      data: (announcementsList) {
                        if (announcementsList.isEmpty) {
                          return const SizedBox(
                            height: 200,
                            child: AnnouncementCard(
                              title: 'You have no announcements',
                              image:
                                  'https://i.pinimg.com/originals/c0/88/7d/c0887d39121ff3649f04e249942b8fec.jpg',
                            ),
                          );
                        }
                        return Column(
                          children: [
                            AnnouncementsSlider(
                              pageController: _pageController,
                              announcements: announcementsList,
                            ),
                            const SizedBox(height: 10),
                            SmoothPageIndicator(
                              controller: _pageController,
                              count: announcementsList.length,
                              effect: WormEffect(
                                dotHeight: 8,
                                dotWidth: 8,
                                activeDotColor:
                                    Theme.of(context).colorScheme.primary,
                                spacing: 6,
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const SizedBox(),
                      error: (error, stack) => Center(
                        child: Text('Error loading announcements: $error'),
                      ),
                    ),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        const SizedBox(width: 14),
                        Text(
                          'Your Clubs',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(width: 5),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AllClubsPage(),
                              ),
                            );
                          },
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'See all',
                                style: TextStyle(
                                  color: Color.fromRGBO(131, 172, 189, 0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_right,
                                color: Color.fromRGBO(131, 172, 189, 0.7),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    clubs.when(
                      data: (clubsList) => ClubsContainer(clubs: clubsList),
                      loading: () => const SizedBox(),
                      error: (error, stack) => Center(
                        child: Text('Error loading clubs: $error'),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const SizedBox(width: 14),
                        Text(
                          "Upcoming Events",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(width: 5),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4,vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            ref.read(eventsFilterClubProvider.notifier).state = 'All Clubs';
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const EventsPage(),
                              ),
                            );
                          },
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'See all',
                                style: TextStyle(
                                  color: Color.fromRGBO(131, 172, 189, 0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_right,
                                color: Color.fromRGBO(131, 172, 189, 0.7),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    events.when(
                      data: (eventsList) => EventCard(events: eventsList),
                      loading: () => const SizedBox(),
                      error: (error, stack) => Center(
                        child: Text('Error loading events: $error'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

import 'package:events_manager/screens/profile/profile.dart';
import 'package:events_manager/screens/dashboard/widgets/notification_settings_sheet.dart';
import 'package:events_manager/utils/common_utils.dart';
import 'package:flutter/material.dart';

class ProfileHeader extends StatefulWidget {
  final String profileImage;

  const ProfileHeader({
    super.key,
    required this.profileImage,
  });

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 16) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  @override
  Widget build(BuildContext context) {

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                _getGreeting(),
                style: const TextStyle(
                  color: Color(0xFFAEE7FF),
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              onPressed: () {
                showNotificationSettingsSheet(context);
              },
              icon: Stack(
                children: [
                  const Icon(
                    Icons.notifications_outlined,
                    color: Color(0xFF71C2E4),
                    size: 28,
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFFB30000),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
              child: Container(
                width: 45,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: widget.profileImage != ''
                        ? getCachedNetworkImageProvider(
                            imageUrl: widget.profileImage,
                            imageType: ImageType.profile,
                          )
                        : const AssetImage('assets/default_avatar.png') as ImageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String extractRollNumber(String email) {
  {
    final String userMail = email.split('@')[0];
    final RegExp regExp = RegExp(r'(\d+)([a-zA-Z]+)(\d+)');
    final match = regExp.firstMatch(userMail);

    if (match != null) {
      final String year = match.group(1)!;
      final String branch = match.group(2)!.toUpperCase();
      final String number = match.group(3)!.padLeft(4, '0');
      return '20$year$branch$number';
    }

    return "Unknown";
  }
}

import 'dart:math';

import 'package:events_manager/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  bool isSigningIn = false;

  void signIn() async {
    setState(() {
      isSigningIn = true;
    });

    try {
      final GoogleSignInAccount? user = await AuthService().signInWithGoogle();

      if (!mounted) return;  // Early return if widget is unmounted

      if (user != null && !user.email.endsWith("iiitkottayam.ac.in")) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in with your IIIT Kottayam account'),
          ),
        );
      }
    } finally {
      if (mounted) {  // Only update state if still mounted
        setState(() {
          isSigningIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive sizing
    final Size screenSize = MediaQuery.of(context).size;
    const double baseWidth = 375.0; // Base width for reference (iPhone X)
    final double scaleFactor = min(screenSize.width,screenSize.height) / baseWidth;

    // Responsive text sizes
    final double smallTextSize = 11 * scaleFactor;
    final double mediumTextSize = 13 * scaleFactor;
    final double largeTextSize = 22 * scaleFactor;

    // Responsive spacing
    final double horizontalPadding = 20.0 * scaleFactor;

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
        child: SafeArea(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 4),
                        Text(
                          "Let's plan with",
                          style: GoogleFonts.dmSans(
                            fontSize: largeTextSize,
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
                            fontSize: largeTextSize,
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
                        SizedBox(height: 65 * scaleFactor),
                        isSigningIn
                          ? SizedBox(
                              width: 30 * scaleFactor,
                              height: 30 * scaleFactor,
                              child: const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF83ACBD)),
                              ),
                            )
                          : GestureDetector(
                              onTap: signIn,
                              child: Container(
                                width: 213 * scaleFactor,
                                height: 43 * scaleFactor,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF06222F),
                                  borderRadius: BorderRadius.circular(15 * scaleFactor),
                                ),
                                child: Row(
                                  children: [
                                    // Google logo
                                    Container(
                                      width: 32 * scaleFactor,
                                      height: 32 * scaleFactor,
                                      margin: EdgeInsets.only(
                                        left: 27 * scaleFactor,
                                        right: 2 * scaleFactor
                                      ),
                                      child: Image.asset(
                                        'assets/icons/google_logo.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    // Sign in text
                                    Text(
                                      'Sign in with Google',
                                      style: GoogleFonts.dmSans(
                                        color: Colors.white.withValues(alpha:0.5),
                                        fontSize: mediumTextSize,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        const Spacer(flex: 3),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                          child: Text(
                            'By signing in, you agree to Revent\'s terms of service and privacy policy.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: smallTextSize,
                              color: const Color(0xFF448DAE).withValues(alpha:0.7),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        SizedBox(height: 20 * scaleFactor),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

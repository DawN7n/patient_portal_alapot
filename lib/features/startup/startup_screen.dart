import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_theme.dart';
import '../auth/auth_screen.dart';
import 'onboarding_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({
    super.key,
    required this.prefs,
  });

  final SharedPreferences prefs;

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _scale = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _controller.forward();
    _navigationTimer = Timer(
      const Duration(milliseconds: 1700),
      _openNextScreen,
    );
  }

  void _openNextScreen() {
    if (!mounted) return;

    final hasCompletedOnboarding =
        widget.prefs.getBool('onboarded') ??
        widget.prefs.getBool('onboarding_complete') ??
        false;

    final nextScreen = hasCompletedOnboarding
        ? AuthScreen(prefs: widget.prefs)
        : OnboardingScreen(prefs: widget.prefs);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => nextScreen,
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/alapot_logo.png',
                  width: 112,
                  height: 112,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 15),
                const Text(
                  'Alapot Dental Clinic',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Dental Care Beyond Ordinary!',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

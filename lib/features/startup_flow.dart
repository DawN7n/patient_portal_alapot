import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_theme.dart';
import 'auth_screens.dart';

class StartupFlow extends StatefulWidget {
  const StartupFlow({super.key, required this.preferences});

  final SharedPreferences preferences;

  @override
  State<StartupFlow> createState() => _StartupFlowState();
}

class _StartupFlowState extends State<StartupFlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scale = Tween<double>(begin: .88, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 2100), () {
      if (!mounted) return;
      final onboarded =
          widget.preferences.getBool('onboarding_complete') ?? false;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => onboarded
              ? LoginScreen(preferences: widget.preferences)
              : OnboardingScreen(preferences: widget.preferences),
        ),
      );
    });
  }

  @override
  void dispose() {
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
                Container(
                  width: 112,
                  height: 112,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.peach,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Image.asset('assets/images/alapot_logo.png',
                      fit: BoxFit.contain),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Alapot Dental Clinic',
                  style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Dental Care Beyond Ordinary!',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.muted, letterSpacing: .2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.preferences});

  final SharedPreferences preferences;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;
  final _items = const [
    _OnboardData(
      Icons.sentiment_satisfied_alt_rounded,
      'Your Smile Matters',
      'Discover thoughtful dental care designed to keep your smile healthy and confident.',
    ),
    _OnboardData(
      Icons.calendar_month_rounded,
      'Care Made Convenient',
      'Request appointments, explore dental services, and keep your visits organized.',
    ),
    _OnboardData(
      Icons.favorite_rounded,
      'Your Dental Journey',
      'Stay connected with your clinic and take one small step toward a healthier smile.',
    ),
  ];

  Future<void> _finish() async {
    await widget.preferences.setBool('onboarding_complete', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
          builder: (_) => RegisterScreen(preferences: widget.preferences)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 18, 26, 24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        onPressed: _finish, child: const Text('Skip')),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _page,
                      itemCount: _items.length,
                      onPageChanged: (value) => setState(() => _index = value),
                      itemBuilder: (_, index) {
                        final item = _items[index];
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 230,
                              height: 230,
                              decoration: BoxDecoration(
                                color: AppColors.peach,
                                borderRadius: BorderRadius.circular(70),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 170,
                                    height: 170,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Icon(item.icon,
                                      size: 94, color: AppColors.teal),
                                  Positioned(
                                    right: 30,
                                    top: 36,
                                    child: Icon(
                                      Icons.auto_awesome,
                                      size: 25,
                                      color:
                                          AppColors.coral.withValues(alpha: .8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 42),
                            Text(
                              item.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 13),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                item.description,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.7,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (indexValue) => AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _index == indexValue ? 24 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _index == indexValue
                              ? AppColors.teal
                              : const Color(0xFFD9E5E6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _index == 2
                          ? _finish
                          : () => _page.nextPage(
                                duration: const Duration(milliseconds: 320),
                                curve: Curves.easeInOut,
                              ),
                      child: Text(_index == 2 ? 'Get Started' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardData {
  const _OnboardData(this.icon, this.title, this.description);

  final IconData icon;
  final String title;
  final String description;
}

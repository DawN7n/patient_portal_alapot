import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_theme.dart';
import '../auth/auth_screen.dart';
import '../../shared/widgets/ui.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.prefs,
  });

  final SharedPreferences prefs;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  int _index = 0;

  final List<(
    String,
    String,
    IconData,
    Color,
  )> _data = const [
    (
      'Your smile matters',
      'A healthy smile begins with thoughtful dental care.',
      Icons.sentiment_satisfied_alt_rounded,
      AppColors.peach,
    ),
    (
      'Care made convenient',
      'Find your dentist, explore services, and request visits with ease.',
      Icons.calendar_month_rounded,
      AppColors.sky,
    ),
    (
      'Your smile journey',
      'Keep your appointments and dental care updates in one place.',
      Icons.auto_awesome_rounded,
      AppColors.mint,
    ),
  ];

  Future<void> _finish() async {
    await widget.prefs.setBool('onboarded', true);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AuthScreen(prefs: widget.prefs),
      ),
    );
  }

  void _nextPage() {
    if (_index == _data.length - 1) {
      _finish();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Skip'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _data.length,
                  onPageChanged: (value) {
                    setState(() => _index = value);
                  },
                  itemBuilder: (context, pageIndex) {
                    final item = _data[pageIndex];

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 230,
                          height: 230,
                          decoration: BoxDecoration(
                            color: item.$4,
                            borderRadius: BorderRadius.circular(70),
                          ),
                          child: Icon(
                            item.$3,
                            size: 105,
                            color: AppColors.teal,
                          ),
                        ),
                        const SizedBox(height: 38),
                        Text(
                          item.$1,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 25),
                          child: Text(
                            item.$2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                              height: 1.6,
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
                  _data.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.all(4),
                    width: _index == index ? 25 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _index == index
                          ? AppColors.teal
                          : AppColors.line,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                label: _index == _data.length - 1 ? 'Get started' : 'Next',
                onPressed: _nextPage,
                icon: _index == _data.length - 1
                    ? Icons.check_rounded
                    : Icons.arrow_forward_rounded,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

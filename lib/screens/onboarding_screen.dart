import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_theme.dart';
import '../config/page_transitions.dart';
import '../config/prefs_keys.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _lastPageIndex = 2;

  int _currentPageIndex = 0;
  bool _isCompleting = false;

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;

    setState(() => _isCompleting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppPrefsKeys.onboardingSeen, true);
    } catch (_) {
      // Continue to login even if local preference persistence fails.
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      SlideFadeRoute(
        page: const LoginScreen(),
        direction: SlideDirection.up,
      ),
    );
  }

  Widget _buildImage(String assetPath, {required Color primaryColor, required Color dotInactiveColor}) {
    final isSvg = assetPath.toLowerCase().endsWith('.svg');

    return SizedBox(
      width: double.infinity,
      height: 300,
      child: isSvg
          ? SvgPicture.asset(
              assetPath,
              fit: BoxFit.contain,
              placeholderBuilder: (_) => Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primaryColor,
                ),
              ),
            )
          : Image.asset(
              assetPath,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.image_not_supported_outlined,
                size: 72,
                color: dotInactiveColor,
              ),
            ),
    );
  }

  PageDecoration _pageDecoration(
    TextTheme textTheme, {
    required Color surfaceColor,
    required Color titleColor,
    required Color bodyColor,
  }) {
    return PageDecoration(
      pageColor: surfaceColor,
      imagePadding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.lg),
      imageFlex: 5,
      bodyFlex: 4,
      titleTextStyle: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: titleColor,
            height: 1.15,
          ) ??
          const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      bodyTextStyle: textTheme.bodyLarge?.copyWith(
            color: bodyColor,
            height: 1.4,
          ) ??
          const TextStyle(fontSize: 16, height: 1.4),
      titlePadding: const EdgeInsets.only(bottom: AppSpacing.md),
      bodyPadding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      contentMargin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
    );
  }

  List<PageViewModel> _pages(
    TextTheme textTheme, {
    required Color surfaceColor,
    required Color titleColor,
    required Color bodyColor,
    required Color primaryColor,
    required Color dotInactiveColor,
  }) {
    final decoration = _pageDecoration(
      textTheme,
      surfaceColor: surfaceColor,
      titleColor: titleColor,
      bodyColor: bodyColor,
    );

    return [
      PageViewModel(
        title: 'Welcome to Time Sphere',
        body:
            'Track your attendance effortlessly with location-based clock in & out.',
        image: _buildImage(
          'assets/images/onboarding_1.svg',
          primaryColor: primaryColor,
          dotInactiveColor: dotInactiveColor,
        ),
        decoration: decoration,
      ),
      PageViewModel(
        title: 'Clock In with One Tap',
        body:
            'Simply tap Clock In when you arrive at your workplace. We handle the rest.',
        image: _buildImage(
          'assets/images/onboarding_2.svg',
          primaryColor: primaryColor,
          dotInactiveColor: dotInactiveColor,
        ),
        decoration: decoration,
      ),
      PageViewModel(
        title: 'Your Attendance, Your History',
        body:
            'View your complete attendance history and records anytime.',
        image: _buildImage(
          'assets/images/onboarding_3.svg',
          primaryColor: primaryColor,
          dotInactiveColor: dotInactiveColor,
        ),
        decoration: decoration,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final surfaceColor = colorScheme.surface;
    final titleColor = colorScheme.onSurface;
    final bodyColor = colorScheme.onSurfaceVariant;
    final primaryColor = colorScheme.primary;
    final dotInactiveColor = isDark
        ? colorScheme.onSurface.withValues(alpha: 0.35)
        : colorScheme.onSurface.withValues(alpha: 0.25);

    return Scaffold(
      backgroundColor: surfaceColor,
      body: SafeArea(
        child: IntroductionScreen(
          pages: _pages(
            textTheme,
            surfaceColor: surfaceColor,
            titleColor: titleColor,
            bodyColor: bodyColor,
            primaryColor: primaryColor,
            dotInactiveColor: dotInactiveColor,
          ),
          onDone: _completeOnboarding,
          onSkip: _completeOnboarding,
          showSkipButton: _currentPageIndex != _lastPageIndex,
          globalBackgroundColor: surfaceColor,
          skip: Text(
            'Skip',
            textAlign: TextAlign.center,
            style: textTheme.labelLarge?.copyWith(
              color: primaryColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          next: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.24),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          done: _isCompleting
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: primaryColor,
                  ),
                )
              : Text(
                  'Get Started ->',
                  maxLines: 1,
                  softWrap: false,
                  style: textTheme.labelLarge?.copyWith(
                    color: primaryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
          overrideDone: Align(
            alignment: Alignment.center,
            child: InkWell(
              onTap: _completeOnboarding,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: SizedBox(
                  width: 110,
                  child: _isCompleting
                      ? Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: primaryColor,
                            ),
                          ),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: Text(
                            'Get Started ->',
                            maxLines: 1,
                            softWrap: false,
                            style: textTheme.labelLarge?.copyWith(
                              color: primaryColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
          onChange: (index) {
            if (!mounted) return;
            setState(() => _currentPageIndex = index);
          },
          dotsDecorator: DotsDecorator(
            size: const Size.square(10),
            activeSize: const Size(34, 10),
            activeColor: primaryColor,
            color: dotInactiveColor,
            spacing: const EdgeInsets.symmetric(horizontal: 4),
            activeShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
          curve: Curves.easeOutCubic,
          dotsContainerDecorator: const ShapeDecoration(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(),
          ),
          skipOrBackFlex: _currentPageIndex == _lastPageIndex ? 2 : 1,
          dotsFlex: 2,
          nextFlex: _currentPageIndex == _lastPageIndex ? 2 : 1,
          controlsPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../main.dart';
import '../config/app_theme.dart';
import '../config/page_transitions.dart';
import '../screens/change_password_screen.dart';
import '../screens/home_screen.dart';
import '../services/api_service.dart';
import '../services/auth_session_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // Shake animation
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: AppDurations.emphasis,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12, end: 12), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: 0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await _apiService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!user.isEmployee) {
        ApiService.clearSession();
        await AuthSessionStorage.clear();

        if (!mounted) return;
        _shakeController.forward(from: 0);
        _showErrorSnackBar(
          'This mobile app is for Employee accounts only. Use the admin web console for Admin access.',
        );
        return;
      }

      await AuthSessionStorage.saveUser(user);

      if (!mounted) return;

      if (user.requirePasswordChangeOnNextLogin) {
        Navigator.of(context).pushReplacement(
          SlideFadeRoute(
            page: const ChangePasswordScreen(),
            direction: SlideDirection.up,
          ),
        );
        return;
      }

      if (user.companyId == null) {
        _shakeController.forward(from: 0);
        _showErrorSnackBar(
          'Your account is not assigned to a company. Contact support.',
        );
        return;
      }

      Navigator.of(context).pushReplacement(
        SlideFadeRoute(
          page: HomeScreen(
            userId: user.id,
            companyId: user.companyId!,
            companyName: user.companyName,
            userName: user.name,
          ),
          direction: SlideDirection.up,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _shakeController.forward(from: 0);
      _showErrorSnackBar(e.message);
    } on TimeoutException {
      if (!mounted) return;
      _shakeController.forward(from: 0);
      _showErrorSnackBar('Connection timed out. Please try again.');
    } catch (_) {
      if (!mounted) return;
      _shakeController.forward(from: 0);
      _showErrorSnackBar('Network error. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: colors.onErrorContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          ],
        ),
        backgroundColor: colors.errorContainer,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppSpacing.md),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.primary,
              colors.primary.withValues(alpha: 0.85),
              colors.primaryContainer,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value, 0),
                    child: child,
                  );
                },
                child: _buildCard(colors, textTheme),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(ColorScheme colors, TextTheme textTheme) {
    return Card(
      elevation: 8,
      shadowColor: colors.shadow.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Logo / Icon ──
              Hero(
                tag: 'app-logo',
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.access_time_filled_rounded,
                    size: 36,
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Title ──
              Text(
                'Welcome Back',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Sign in to mark your attendance',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Email Field ──
              TextFormField(
                controller: _emailController,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) {
                    return 'Email is required';
                  }
                  final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                  if (!emailRegex.hasMatch(value)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Password Field ──
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _handleLogin(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Password is required' : null,
              ),
              const SizedBox(height: AppSpacing.sm),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.of(context).pushNamed(
                            AttendanceApp.forgotPasswordRoute,
                          );
                        },
                  child: const Text('Forgot Password?'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Login Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: AnimatedSwitcher(
                    duration: AppDurations.fast,
                    child: _isLoading
                        ? const SizedBox(
                            key: ValueKey('loader'),
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            key: ValueKey('text'),
                            'Sign In',
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: AppDurations.emphasis)
        .slideY(
          begin: 0.3,
          end: 0,
          duration: AppDurations.emphasis,
          curve: Curves.easeOutCubic,
        );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_theme.dart';

enum _ButtonState { idle, loading, success, error }

/// Large pill-shaped button with gradient background, icon + label,
/// scale-down press animation, and animated success/error overlays.
class AnimatedClockButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final List<Color> gradientColors;
  final Future<void> Function() onPressed;

  const AnimatedClockButton({
    super.key,
    required this.label,
    required this.icon,
    required this.gradientColors,
    required this.onPressed,
  });

  @override
  State<AnimatedClockButton> createState() => _AnimatedClockButtonState();
}

class _AnimatedClockButtonState extends State<AnimatedClockButton>
    with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;
  late final AnimationController _overlayController;
  late final Animation<double> _overlayScale;
  late final Animation<double> _overlayOpacity;

  _ButtonState _state = _ButtonState.idle;

  @override
  void initState() {
    super.initState();

    // Scale-down on press
    _scaleController = AnimationController(
      vsync: this,
      duration: AppDurations.fast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    // Success / error overlay entrance
    _overlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _overlayScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _overlayController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _overlayOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _overlayController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _overlayController.dispose();
    super.dispose();
  }

  bool get _isBusy => _state != _ButtonState.idle;

  Future<void> _handleTap() async {
    if (_isBusy) return;

    _scaleController.forward();
    setState(() => _state = _ButtonState.loading);

    try {
      await widget.onPressed();
      if (!mounted) return;
      await _scaleController.reverse();
      setState(() => _state = _ButtonState.success);
      _overlayController.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 1500));
    } catch (_) {
      if (!mounted) return;
      await _scaleController.reverse();
      setState(() => _state = _ButtonState.error);
      _overlayController.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 1500));
    } finally {
      if (mounted) {
        _overlayController.reset();
        setState(() => _state = _ButtonState.idle);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: SizedBox(
        width: double.infinity,
        height: 64,
        child: Material(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _isBusy ? null : _handleTap,
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.gradientColors,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // ── Main content (label / spinner) ──
                  AnimatedOpacity(
                    opacity: _state == _ButtonState.success ||
                            _state == _ButtonState.error
                        ? 0.0
                        : 1.0,
                    duration: AppDurations.fast,
                    child: _state == _ButtonState.loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(widget.icon,
                                  color: Colors.white, size: 24),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                widget.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),

                  // ── Success overlay ──
                  if (_state == _ButtonState.success)
                    AnimatedBuilder(
                      animation: _overlayController,
                      builder: (context, _) {
                        return Opacity(
                          opacity: _overlayOpacity.value,
                          child: Transform.scale(
                            scale: _overlayScale.value,
                            child: const _ResultIcon(
                              icon: Icons.check_rounded,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),

                  // ── Error overlay ──
                  if (_state == _ButtonState.error)
                    AnimatedBuilder(
                      animation: _overlayController,
                      builder: (context, _) {
                        // Subtle horizontal shake on error
                        final shake = math.sin(
                                _overlayController.value * math.pi * 4) *
                            3;
                        return Opacity(
                          opacity: _overlayOpacity.value,
                          child: Transform.translate(
                            offset: Offset(shake, 0),
                            child: Transform.scale(
                              scale: _overlayScale.value,
                              child: const _ResultIcon(
                                icon: Icons.close_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
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

/// Circular icon badge used for success / error overlays.
class _ResultIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _ResultIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.25),
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }
}

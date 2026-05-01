import 'dart:ui';

import 'package:flutter/cupertino.dart';

class _IslandAnimator extends StatefulWidget {
  final bool visible;
  final Widget child;

  const _IslandAnimator({required this.visible, required this.child});

  @override
  State<_IslandAnimator> createState() => _IslandAnimatorState();
}

class _IslandAnimatorState extends State<_IslandAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _blurAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack, // 👈 this is the jiggle/overshoot
    );

    _blurAnim = Tween<double>(begin: 8.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _opacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
      ),
    );

    // Always auto-forward — AnimatedSwitcher handles when to show this widget
    _controller.forward();
  }

  @override
  void didUpdateWidget(_IslandAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          alignment: Alignment.topCenter, // scale from top like iOS
          child: Opacity(
            opacity: _opacityAnim.value.clamp(0.0, 1.0),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: _blurAnim.value,
                sigmaY: _blurAnim.value,
              ),
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

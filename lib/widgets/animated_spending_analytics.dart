import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../services/spending_service.dart';
import '../models/spending_insight.dart';

class AnimatedSpendingAnalytics extends StatefulWidget {
  const AnimatedSpendingAnalytics({super.key});

  @override
  State<AnimatedSpendingAnalytics> createState() =>
      _AnimatedSpendingAnalyticsState();
}

class _AnimatedSpendingAnalyticsState extends State<AnimatedSpendingAnalytics> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        final insights = context.read<SpendingService>().insights;
        if (insights.isNotEmpty) {
          setState(() {
            _currentIndex = (_currentIndex + 1) % insights.length;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<SpendingInsight> insights = context
        .watch<SpendingService>()
        .insights;

    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

    // Safety check in case the list shrunk while index stayed high
    if (_currentIndex >= insights.length) {
      _currentIndex = 0;
    }

    final insight = insights[_currentIndex];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      transitionBuilder: (Widget child, Animation<double> animation) {
        final offsetAnimation =
            Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeInOutBack),
            );

        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeIn,
        );

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(opacity: fadeAnimation, child: child),
        );
      },
      child: Container(
        key: ValueKey<String>(insight.key),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        width: double.infinity, // Take available space to center within parent
        child: RichText(
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel,
              fontWeight: FontWeight.w500,
            ),
            children: [
              if (insight.prefix != null) TextSpan(text: insight.prefix),
              TextSpan(
                text: insight.highlight,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (insight.suffix != null) TextSpan(text: insight.suffix),
            ],
          ),
        ),
      ),
    );
  }
}

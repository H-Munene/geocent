import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/spending_service.dart';
import '../models/category_analytics.dart';

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
        final analytics = context.read<SpendingService>().categoryComparison;
        if (analytics.isNotEmpty) {
          setState(() {
            _currentIndex = (_currentIndex + 1) % analytics.length;
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
    final List<CategoryAnalytics> analytics = context
        .watch<SpendingService>()
        .categoryComparison;

    if (analytics.isEmpty) {
      return const SizedBox.shrink();
    }

    // Safety check in case the list shrunk while index stayed high
    if (_currentIndex >= analytics.length) {
      _currentIndex = 0;
    }

    final data = analytics[_currentIndex];
    // Green if spending less than yesterday (negative difference)
    // Red if spending more than yesterday (positive difference)
    final color = data.isNegative
        ? CupertinoColors.systemGreen
        : data.isPositive
        ? CupertinoColors.systemRed
        : CupertinoColors.systemGrey;

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
      child: SizedBox(
        key: ValueKey<String>('${data.category}_${data.formattedDifference}'),
        width: 160,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                data.trimmedCategory,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              data.formattedDifference,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class AnalyticsData {
  final String category;
  final String amount;
  final bool isNegative;
  AnalyticsData(this.category, this.amount, this.isNegative);
}

class AnimatedSpendingAnalytics extends StatefulWidget {
  const AnimatedSpendingAnalytics({super.key});

  @override
  State<AnimatedSpendingAnalytics> createState() =>
      _AnimatedSpendingAnalyticsState();
}

class _AnimatedSpendingAnalyticsState extends State<AnimatedSpendingAnalytics> {
  final List<AnalyticsData> _analytics = [
    AnalyticsData('Shopping', '+KES 500', false),
    AnalyticsData('Dining', '-KES 1,200', true),
    AnalyticsData('Transport', '-KES 300', true),
    AnalyticsData('Utilities', '+KES 4,500', false),
    AnalyticsData('Entertainment', '-KES 2,100', true),
    AnalyticsData('Supermarket Groceries', '-KES 8,500', true),
    AnalyticsData('Coffee Break', '-KES 450', true),
    AnalyticsData('Monthly Rent Payment', '+KES 45,000', false),
  ];

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
        setState(() {
          _currentIndex = (_currentIndex + 1) % _analytics.length;
        });
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
    final data = _analytics[_currentIndex];
    final color = data.isNegative
        ? CupertinoColors.systemGreen
        : CupertinoColors.systemRed;

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
        key: ValueKey<int>(_currentIndex),
        width: 160, // Sufficient width for the analytics
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                data.category,
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
              data.amount,
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

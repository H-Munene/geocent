import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

class EmptyStateWidget extends StatelessWidget {
  final String animationPath;
  final String message;
  final bool repeat;
  final double animationSize;

  const EmptyStateWidget({
    super.key,
    required this.animationPath,
    required this.message,
    this.repeat = true,
    this.animationSize = 150,
  });

  @override
  Widget build(BuildContext context) {
    // We reduce the layout height of the animation container to pull the text closer.
    // This allows the Center widget to accurately center the combined Lottie + Text group.
    final double layoutHeight = animationSize - 25;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: layoutHeight,
            child: OverflowBox(
              minHeight: animationSize,
              maxHeight: animationSize,
              child: Lottie.asset(
                animationPath,
                width: animationSize,
                height: animationSize,
                repeat: repeat,
                fit: BoxFit.contain,
              ),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeIn,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    color: CupertinoColors.systemGrey,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
          ),
          // Add a small spacer at the bottom to balance the visual weight
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

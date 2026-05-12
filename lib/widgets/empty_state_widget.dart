import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../utils/lottie_files.dart';

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
    final bool isDoneAnimation = animationPath == doneLottieAnimation;

    // We reduce the layout height of the animation container to pull the text closer.
    // This allows the Center widget to accurately center the combined Lottie + Text group.
    final double layoutHeight = animationSize - (isDoneAnimation ? 30 : 20);

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
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              color: CupertinoColors.systemGrey,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          // Add a small spacer at the bottom to balance the visual weight
          // if the animation still feels top-heavy.
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';

class MapActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final GlobalKey? buttonKey;
  final Color backgroundColor;
  final Color iconColor;
  final bool isAnimating;

  const MapActionButton({
    super.key,
    this.onPressed,
    required this.child,
    this.buttonKey,
    this.backgroundColor = CupertinoColors.white,
    this.iconColor = CupertinoColors.black,
    this.isAnimating = false,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        key: buttonKey,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAnimating ? CupertinoColors.systemGrey3 : backgroundColor,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

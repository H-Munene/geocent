import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class AnalyticsSelectorModal extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const AnalyticsSelectorModal({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey4,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: CupertinoColors.label,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class SelectorOption extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Widget? trailing;

  const SelectorOption({
    super.key,
    required this.label,
    this.isActive = false,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      onPressed: onTap,
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              color: isActive
                  ? CupertinoColors.activeBlue
                  : CupertinoColors.label,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            trailing!
          else if (isActive)
            const Icon(
              CupertinoIcons.checkmark_alt,
              size: 20,
              color: CupertinoColors.activeBlue,
            ),
        ],
      ),
    );
  }
}

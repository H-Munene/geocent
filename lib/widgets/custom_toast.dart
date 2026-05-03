import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

/// Global key to access the navigator for toast overlays.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void showCustomToast(String message) {
  final overlay = rootNavigatorKey.currentState?.overlay;
  if (overlay == null) return;

  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => _ToastWidget(
      message: message,
      onDismiss: () {
        if (entry.mounted) {
          entry.remove();
        }
      },
    ),
  );

  overlay.insert(entry);
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ToastWidget({required this.message, required this.onDismiss});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with TickerProviderStateMixin {
  late AnimationController _yController;
  late AnimationController _xController;
  late Animation<Offset> _yAnimation;
  late Animation<Offset> _xAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _yController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _xController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _yAnimation = Tween<Offset>(begin: const Offset(0, 2), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _yController, curve: Curves.easeOutCubic),
        );

    _xAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1, 0),
    ).animate(CurvedAnimation(parent: _xController, curve: Curves.easeIn));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _xController, curve: Curves.easeIn));

    _yController.forward();

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) _dismiss();
    });
  }

  void _dismiss() async {
    await _xController.forward();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _yController.dispose();
    _xController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 20,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _xAnimation,
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: SlideTransition(
            position: _yAnimation,
            child: Center(
              child: IntrinsicWidth(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF00CC96), // Energy Green
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.check_mark,
                          color: CupertinoColors.white,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1D1D1F),
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _dismiss,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1D1D1F),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.xmark,
                            color: CupertinoColors.white,
                            size: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

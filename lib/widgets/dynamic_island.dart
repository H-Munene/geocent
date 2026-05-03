import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class DynamicIsland extends StatelessWidget {
  final double spent;
  final double limit;
  final bool amountsVisible;
  final bool islandExpanded;
  final String selectedPeriod;
  final Animation<double> bounceScale;
  final VoidCallback onTapCircle;
  final VoidCallback onTapClose;
  final VoidCallback onToggleExpand;
  final VoidCallback onTapEditLimit;
  final Function(String) onPeriodSelected;

  const DynamicIsland({
    super.key,
    required this.spent,
    required this.limit,
    required this.amountsVisible,
    required this.islandExpanded,
    required this.selectedPeriod,
    required this.bounceScale,
    required this.onTapCircle,
    required this.onTapClose,
    required this.onToggleExpand,
    required this.onTapEditLimit,
    required this.onPeriodSelected,
  });

  String _formatKsh(double val) =>
      'Ksh ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';

  @override
  Widget build(BuildContext context) {
    final bool isLimitSet = limit > 0;
    final double progress = isLimitSet ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final double remaining = isLimitSet
        ? (limit - spent).clamp(0.0, double.infinity)
        : 0.0;
    final double maxWidth = MediaQuery.of(context).size.width - 32;

    final Duration currentDuration = amountsVisible
        ? const Duration(milliseconds: 600)
        : const Duration(milliseconds: 300);
    final Curve currentCurve = amountsVisible
        ? Curves.easeOutBack
        : Curves.linear;

    return Align(
      alignment: Alignment.topRight,
      child: ScaleTransition(
        scale: bounceScale,
        alignment: Alignment.topRight,
        child: AnimatedContainer(
          duration: currentDuration,
          curve: currentCurve,
          width: amountsVisible ? maxWidth : 64,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(amountsVisible ? 22 : 32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: AnimatedSize(
            duration: currentDuration,
            curve: currentCurve,
            alignment: Alignment.topRight,
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: amountsVisible ? 300 : 450),
              layoutBuilder:
                  (Widget? currentChild, List<Widget> previousChildren) {
                    return Stack(
                      alignment: Alignment.topRight,
                      children: <Widget>[...previousChildren, ?currentChild],
                    );
                  },
              transitionBuilder: (Widget child, Animation<double> animation) {
                if (child.key == const ValueKey('circle_content')) {
                  if (!amountsVisible) {
                    final blurAnim = Tween<double>(begin: 8.0, end: 0.0)
                        .animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          ),
                        );
                    final opacityAnim = Tween<double>(begin: 0.0, end: 1.0)
                        .animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: const Interval(0.0, 0.4),
                          ),
                        );
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, ch) {
                        return Opacity(
                          opacity: opacityAnim.value,
                          child: ImageFiltered(
                            imageFilter: ui.ImageFilter.blur(
                              sigmaX: blurAnim.value,
                              sigmaY: blurAnim.value,
                            ),
                            child: ch,
                          ),
                        );
                      },
                      child: child,
                    );
                  } else {
                    final fastFadeOut = CurvedAnimation(
                      parent: animation,
                      curve: Curves.linear,
                      reverseCurve: const Interval(0.9, 1.0),
                    );
                    return FadeTransition(opacity: fastFadeOut, child: child);
                  }
                }
                return FadeTransition(opacity: animation, child: child);
              },
              child: amountsVisible
                  ? _buildExpandedContent(
                      progress,
                      remaining,
                      maxWidth,
                      isLimitSet,
                    )
                  : _buildCircleContent(progress, isLimitSet),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircleContent(double progress, bool isLimitSet) {
    return GestureDetector(
      key: const ValueKey('circle_content'),
      onTap: onTapCircle,
      child: Container(
        width: 64,
        height: 64,
        color: Colors.transparent,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                value: isLimitSet ? progress : 0.0,
                strokeWidth: 3.5,
                backgroundColor: const Color(0xFF333333),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF4488FF),
                ),
              ),
            ),
            Text(
              isLimitSet ? '${(progress * 100).toStringAsFixed(0)}%' : '-%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent(
    double progress,
    double remaining,
    double maxWidth,
    bool isLimitSet,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      reverse: true,
      child: SizedBox(
        width: maxWidth,
        child: Container(
          key: const ValueKey('expanded_content'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
                child: islandExpanded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF222222),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: ['Today', 'This Week', 'Month'].map(
                                    (period) {
                                      final isSelected =
                                          selectedPeriod == period;
                                      return GestureDetector(
                                        onTap: () => onPeriodSelected(period),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 250,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            period,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.black
                                                  : Colors.grey,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ).toList(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: onTapEditLimit,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF222222),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.grey,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 1,
                            color: const Color(0xFF2A2A2A),
                            margin: const EdgeInsets.only(top: 10, bottom: 10),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: onTapClose,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'SPENT',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 8,
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              _formatKsh(spent),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 1,
                          height: 26,
                          color: const Color(0xFF333333),
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'LIMIT',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 8,
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              isLimitSet ? _formatKsh(limit) : 'Not Set',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: onTapClose,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLimitSet
                                ? '${(progress * 100).toStringAsFixed(0)}% used'
                                : '-% used',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: isLimitSet ? progress : 0.0,
                              minHeight: 5,
                              backgroundColor: const Color(0xFF333333),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF4488FF),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isLimitSet
                                ? '${_formatKsh(remaining)} left'
                                : 'N/A',
                            style: const TextStyle(
                              color: Color(0xFF4488FF),
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onToggleExpand,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: AnimatedRotation(
                        turns: islandExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.grey,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
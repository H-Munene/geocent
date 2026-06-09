import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geocent/models/app_transaction.dart';
import 'package:geocent/services/spending_service.dart';
import 'package:geocent/widgets/animated_spending_analytics.dart';
import 'package:geocent/widgets/search_messages_sheet.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MapSearchHeader extends StatefulWidget {
  final Function(AppTransaction) onTransactionSelected;

  const MapSearchHeader({super.key, required this.onTransactionSelected});

  @override
  State<MapSearchHeader> createState() => MapSearchHeaderState();
}

class MapSearchHeaderState extends State<MapSearchHeader> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _showAnalytics = true;
  bool _isSearching = false;

  bool _showDynamicIsland = false;
  final List<AppTransaction> _newTransactions = [];
  Timer? _txDisplayTimer;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchController.removeListener(_onSearchTextChanged);
    _searchFocusNode.dispose();
    _searchController.dispose();
    _txDisplayTimer?.cancel();
    super.dispose();
  }

  void _onSearchFocusChanged() {
    setState(() {
      _showAnalytics =
          !_searchFocusNode.hasFocus && _searchController.text.isEmpty;
    });
  }

  void _onSearchTextChanged() {
    setState(() {
      _showAnalytics =
          !_searchFocusNode.hasFocus && _searchController.text.isEmpty;
    });
  }

  Future<void> showDynamicIslandForTransaction(AppTransaction tx) async {
    final prefs = await SharedPreferences.getInstance();
    final shownList = prefs.getStringList('seen_island_tx_ids') ?? [];

    if (shownList.contains(tx.id)) return;

    shownList.add(tx.id);
    if (shownList.length > 50) {
      shownList.removeRange(0, shownList.length - 50);
    }
    await prefs.setStringList('seen_island_tx_ids', shownList);

    if (!mounted) return;

    setState(() {
      if (!_newTransactions.any((t) => t.id == tx.id)) {
        _newTransactions.add(tx);
      }
    });
    _processTransactionQueue();
  }

  void _processTransactionQueue() {
    if (_newTransactions.isEmpty) {
      if (_showDynamicIsland) {
        setState(() {
          _showDynamicIsland = false;
        });
      }
      return;
    }

    if (_txDisplayTimer?.isActive ?? false) return;

    setState(() {
      _showDynamicIsland = true;
    });

    _txDisplayTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          if (_newTransactions.isNotEmpty) {
            _newTransactions.removeAt(0);
          }
        });
        _txDisplayTimer = null;
        _processTransactionQueue();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.only(bottom: 12, left: 12),
            child: Row(
              children: [
                CupertinoActivityIndicator(radius: 8),
                SizedBox(width: 8),
                Text(
                  'Searching...',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOutBack,
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(_showDynamicIsland ? 32 : 14),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.black.withValues(alpha: 0.1),
                blurRadius: _showDynamicIsland ? 24 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_showDynamicIsland ? 32 : 14),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 550),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 550),
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: <Widget>[...previousChildren, ?currentChild],
                  );
                },
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final isIsland = child.key == const ValueKey('island');

                  if (isIsland) {
                    final blurCurve = CurvedAnimation(
                      parent: animation,
                      curve: const Interval(0.0, 0.8, curve: Curves.easeIn),
                    );
                    return AnimatedBuilder(
                      animation: blurCurve,
                      builder: (context, child) {
                        final blurAmount = (1.0 - blurCurve.value) * 15.0;
                        return ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(
                            sigmaX: blurAmount,
                            sigmaY: blurAmount,
                          ),
                          child: child!,
                        );
                      },
                      child: child,
                    );
                  } else {
                    final delayedOpacity = CurvedAnimation(
                      parent: animation,
                      curve: const Interval(0.9, 1.0, curve: Curves.easeIn),
                    );
                    return FadeTransition(
                      opacity: delayedOpacity,
                      child: child,
                    );
                  }
                },
                child: _showDynamicIsland
                    ? _buildIslandContent()
                    : _buildSearchBarContent(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIslandContent() {
    if (_newTransactions.isEmpty) return const SizedBox.shrink();
    final tx = _newTransactions.first;

    return Container(
      key: const ValueKey('island'),
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (Widget child, Animation<double> animation) {
          final inAnimation =
              Tween<Offset>(
                begin: const Offset(0.0, 1.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );

          final outAnimation =
              Tween<Offset>(
                begin: const Offset(0.0, -1.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );

          if (child.key == ValueKey(tx.id)) {
            return SlideTransition(
              position: inAnimation,
              child: FadeTransition(opacity: animation, child: child),
            );
          } else {
            return SlideTransition(
              position: outAnimation,
              child: FadeTransition(opacity: animation, child: child),
            );
          }
        },
        child: _buildTransactionCard(tx),
      ),
    );
  }

  Widget _buildSearchBarContent() {
    return Container(
      key: const ValueKey('search'),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          TapRegion(
            onTapOutside: (event) {
              if (_searchFocusNode.hasFocus) {
                _searchFocusNode.unfocus();
              }
            },
            child: CupertinoSearchTextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              suffixIcon: _isSearching
                  ? const Icon(CupertinoIcons.clear_thick_circled)
                  : const Icon(CupertinoIcons.search),
              suffixMode: OverlayVisibilityMode.editing,
              onSubmitted: (value) async {
                if (value.trim().isEmpty) return;

                setState(() => _isSearching = true);

                try {
                  final spendingService = context.read<SpendingService>();
                  final results = await spendingService.searchMessages(value);

                  if (!mounted) return;

                  FocusScope.of(context).unfocus();

                  showCupertinoSheet(
                    context: context,
                    builder: (context) => SearchMessagesSheet(
                      results: results,
                      query: value,
                      onMessageSelected: (tx) {
                        spendingService.selectTransaction(tx.id);
                        widget.onTransactionSelected(tx);
                      },
                    ),
                  );
                } catch (e) {
                  debugPrint('Search error: $e');
                } finally {
                  if (mounted) {
                    setState(() => _isSearching = false);
                  }
                }
              },
              placeholder: _showAnalytics ? '' : 'Search transactions...',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                color: const Color(0xFF1D1D1F),
              ),
              backgroundColor: Colors.transparent,
              borderRadius: BorderRadius.zero,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          Positioned(
            left: 40,
            right: 40,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _showAnalytics ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: const SizedBox(
                  height: 44,
                  child: Center(child: AnimatedSpendingAnalytics()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(AppTransaction tx) {
    final spending = context.read<SpendingService>();
    final cat = spending.getCategoryByName(tx.category);

    return Container(
      key: ValueKey(tx.id),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: cat != null && cat.icon is IconData
                    ? Icon(
                        cat.icon as IconData,
                        color: const Color(0xFF007AFF),
                        size: 20,
                      )
                    : HugeIcon(
                        icon: cat?.icon ?? HugeIcons.strokeRoundedTag01,
                        color: const Color(0xFF007AFF),
                        size: 20,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.merchant,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1C1C1E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mapped Location',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        color: CupertinoColors.systemGrey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, thickness: 0.5, color: Color(0xFFE5E5EA)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.clock,
                    color: Color(0xFF007AFF),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatTime(tx.timestamp),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.creditcard,
                    color: Color(0xFF007AFF),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tx.formattedAmount,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    int hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }
    return '$hour:$minute $period';
  }
}

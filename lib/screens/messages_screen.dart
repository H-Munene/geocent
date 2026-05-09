import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_transaction.dart';
import '../services/spending_service.dart';
import '../widgets/category_dropdown_widget.dart';
import '../widgets/custom_toast.dart';
import '../widgets/unmapped_message_tile.dart';

enum SelectionMode { none, categorize, forget }

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final ScrollController _scrollController = ScrollController();
  GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<dynamic> _displayList = [];
  String _activeFilter = 'all';
  final Set<String> _selectedIds = {};
  SelectionMode _selectionMode = SelectionMode.none;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  final FocusNode _searchFocusNode = FocusNode();
  SpendingService? _spendingService;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _spendingService = context.read<SpendingService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      _spendingService?.addListener(_onServiceStateChanged);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _spendingService?.removeListener(_onServiceStateChanged);
    _scrollController.dispose();
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onServiceStateChanged() {
    if (!mounted) return;
    final spendingService = context.read<SpendingService>();
    final messages = spendingService.paginatedMessages;

    // Synchronize local search text if it was reset globally (e.g. on tab switch)
    if (spendingService.searchQuery.isEmpty &&
        _searchController.text.isNotEmpty) {
      _searchController.clear();
    }

    // Sync filter state
    if (spendingService.currentFilter != _activeFilter) {
      setState(() {
        _activeFilter = spendingService.currentFilter;
      });
    }

    // Sync the animated list
    final grouped = _groupWithHeaders(messages);
    if (grouped.length != _displayList.length ||
        _hasContentChanged(_displayList, grouped)) {
      _syncList(messages);
    }
  }

  bool _hasContentChanged(List<dynamic> oldList, List<dynamic> newList) {
    if (oldList.length != newList.length) return true;
    for (int i = 0; i < oldList.length; i++) {
      final oldItem = oldList[i];
      final newItem = newList[i];

      if (oldItem.runtimeType != newItem.runtimeType) return true;

      if (oldItem is String) {
        if (oldItem != newItem) return true;
      } else if (oldItem is AppTransaction) {
        final newTx = newItem as AppTransaction;
        if (oldItem.id != newTx.id ||
            oldItem.category != newTx.category ||
            oldItem.latitude != newTx.latitude ||
            oldItem.longitude != newTx.longitude) {
          return true;
        }
      }
    }
    return false;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<SpendingService>().fetchMessages();
    }
  }

  Future<void> _loadInitialData() async {
    final service = context.read<SpendingService>();
    await service.fetchMessages(refresh: true);
  }

  void _syncList(List<AppTransaction> newMessages) {
    if (!mounted) return;
    final List<dynamic> flatListWithHeaders = _groupWithHeaders(newMessages);

    // 1. If the list is shorter (deletion) or completely different (filter change),
    // swap the key for a safe, instant rebuild.
    if (flatListWithHeaders.length < _displayList.length ||
        (flatListWithHeaders.isNotEmpty &&
            _displayList.isNotEmpty &&
            _getItemId(flatListWithHeaders.first) !=
                _getItemId(_displayList.first))) {
      setState(() {
        _displayList.clear();
        _displayList.addAll(flatListWithHeaders);
        _listKey = GlobalKey<AnimatedListState>();
      });
      return;
    }

    // 2. If length is the same, synchronize the contents of the existing items
    if (flatListWithHeaders.length == _displayList.length) {
      setState(() {
        for (int i = 0; i < flatListWithHeaders.length; i++) {
          _displayList[i] = flatListWithHeaders[i];
        }
      });
      return;
    }

    // 3. Otherwise, append new items (pagination)
    final int oldLength = _displayList.length;
    setState(() {
      _displayList.addAll(flatListWithHeaders.sublist(oldLength));
    });
    for (int i = oldLength; i < flatListWithHeaders.length; i++) {
      _listKey.currentState?.insertItem(i);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      context.read<SpendingService>().fetchMessages(
        refresh: true,
        searchQuery: query,
      );
    });
  }

  void _showFilterMenu() {
    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) => Container(
        padding: const EdgeInsets.only(top: 12),
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                'Options',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.label,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 24,
                ),
                onPressed: () {
                  Navigator.pop(modalContext);
                  _showDurationFilter();
                },
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.calendar, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      'Filter by Duration',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        color: CupertinoColors.label,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 24,
                ),
                onPressed: () {
                  Navigator.pop(modalContext);
                  setState(() {
                    _selectionMode = SelectionMode.forget;
                    _selectedIds.clear();
                  });
                },
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.delete, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      'Forget Messages',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        color: CupertinoColors.label,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showDurationFilter() {
    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) => Container(
        padding: const EdgeInsets.only(top: 12),
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                'Filter by Duration',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.label,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 16),
              _buildDurationOption(modalContext, 'All Time', 'all'),
              _buildDurationOption(modalContext, 'Today', 'today'),
              _buildDurationOption(modalContext, 'Yesterday', 'yesterday'),
              _buildDurationOption(modalContext, 'Last 3 days', 'last 3 days'),
              _buildDurationOption(modalContext, 'This week', 'this week'),
              _buildDurationOption(
                modalContext,
                'Older than a week',
                'older than a week',
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _onForgetPressed() {
    if (_selectedIds.isEmpty) return;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Forget Messages'),
        content: Text(
          'Geocent will forget these ${_selectedIds.length} messages. They will never be available for mapping or categorization again, but will remain in your native messages app.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              final service = context.read<SpendingService>();
              final count = _selectedIds.length;
              final idsToForget = _selectedIds.toList();

              Navigator.pop(context); // Pop dialog

              try {
                await service.forgetMessages(idsToForget);
                setState(() {
                  _selectedIds.clear();
                  _selectionMode = SelectionMode.none;
                });
                showCustomToast('Successfully forgot $count messages');
              } catch (e) {
                showCustomToast('Failed to forget messages');
              }
            },
            child: const Text('Forget'),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationOption(
    BuildContext modalContext,
    String label,
    String value,
  ) {
    final spendingService = context.read<SpendingService>();
    final isActive = spendingService.currentDurationFilter == value;

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      onPressed: () {
        Navigator.pop(modalContext);
        spendingService.setDurationFilter(value);
      },
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
          if (isActive)
            const Icon(
              CupertinoIcons.checkmark_alt,
              size: 20,
              color: CupertinoColors.activeBlue,
            ),
        ],
      ),
    );
  }

  String _getItemId(dynamic item) {
    if (item is String) return item;
    if (item is AppTransaction) return item.id;
    return '';
  }

  List<dynamic> _groupWithHeaders(List<AppTransaction> transactions) {
    final List<dynamic> result = [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final List<AppTransaction> todayItems = [];
    final List<AppTransaction> yesterdayItems = [];
    final List<AppTransaction> olderItems = [];

    for (var tx in transactions) {
      final txDate = DateTime(
        tx.timestamp.year,
        tx.timestamp.month,
        tx.timestamp.day,
      );
      if (txDate == today) {
        todayItems.add(tx);
      } else if (txDate == yesterday) {
        yesterdayItems.add(tx);
      } else {
        olderItems.add(tx);
      }
    }

    if (todayItems.isNotEmpty) {
      result.add('Today');
      result.addAll(todayItems);
    }
    if (yesterdayItems.isNotEmpty) {
      result.add('Yesterday');
      result.addAll(yesterdayItems);
    }
    if (olderItems.isNotEmpty) {
      result.add('Older');
      result.addAll(olderItems);
    }
    return result;
  }

  void _onFilterChanged(String filter) async {
    if (_activeFilter == filter) return;
    setState(() {
      _activeFilter = filter;
      _selectedIds.clear();
    });

    final service = context.read<SpendingService>();
    await service.setFilter(filter);
  }

  void _toggleSelection(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _onBulkCategorize() {
    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Center(
        child: DefaultTextStyle(
          style: GoogleFonts.spaceGrotesk(
            color: CupertinoColors.label,
            decoration: TextDecoration.none,
          ),
          child: CategoryDropdownWidget(
            onCategorySelectedOverride: (categoryName) {
              _confirmBulkCategorization(categoryName);
            },
          ),
        ),
      ),
    );
  }

  void _confirmBulkCategorization(String categoryName) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Bulk Categorize'),
        content: Text(
          'Assign "$categoryName" to ${_selectedIds.length} messages?',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Confirm'),
            onPressed: () async {
              final service = context.read<SpendingService>();
              final selectedCount = _selectedIds.length;
              final idsToUpdate = _selectedIds.toList();

              // Pop confirm dialog and category dialog
              Navigator.pop(context);
              Navigator.pop(context);

              try {
                await service.bulkUpdateCategory(idsToUpdate, categoryName);
                setState(() {
                  _selectedIds.clear();
                });
                showCustomToast(
                  'Successfully categorized $selectedCount messages',
                );
              } catch (e) {
                showCustomToast('Failed to categorize messages');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
    dynamic item,
    Animation<double> animation,
    bool isLastInGroup,
  ) {
    if (item is String) {
      final sectionIndex = _displayList.indexOf(item);
      final List<AppTransaction> sectionItems = [];
      for (int i = sectionIndex + 1; i < _displayList.length; i++) {
        if (_displayList[i] is String) break;
        sectionItems.add(_displayList[i] as AppTransaction);
      }

      final allSelected =
          sectionItems.isNotEmpty &&
          sectionItems.every((tx) => _selectedIds.contains(tx.id));

      return FadeTransition(
        opacity: animation,
        child: _SectionHeader(
          title: item,
          showSelectAll: _selectionMode == SelectionMode.forget,
          allSelected: allSelected,
          onToggleSelectAll: () {
            setState(() {
              if (allSelected) {
                for (var tx in sectionItems) {
                  _selectedIds.remove(tx.id);
                }
              } else {
                for (var tx in sectionItems) {
                  _selectedIds.add(tx.id);
                }
              }
            });
          },
        ),
      );
    }

    final tx = item as AppTransaction;
    return SlideTransition(
      position: animation.drive(
        Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
      ),
      child: FadeTransition(
        opacity: animation,
        child: UnmappedMessageTile(
          transaction: tx,
          showDivider: !isLastInGroup,
          isSelectionMode: _selectionMode != SelectionMode.none,
          isSelected: _selectedIds.contains(tx.id),
          onSelectToggle: () => _toggleSelection(tx.id),
          searchQuery: context
              .read<SpendingService>()
              .searchQuery, // Use service's search query
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spendingService = context.watch<SpendingService>();
    final messages = spendingService.paginatedMessages;

    return PopScope(
      canPop: _selectedIds.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedIds.isNotEmpty) {
          setState(() {
            _selectedIds.clear();
          });
        }
      },
      child: CupertinoPageScaffold(
        backgroundColor: Colors.white,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: Colors.white.withValues(alpha: 0.8),
          border: null,
          leading: _selectionMode != SelectionMode.none
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      _selectionMode = SelectionMode.none;
                      _selectedIds.clear();
                    });
                  },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: CupertinoColors.activeBlue,
                    ),
                  ),
                )
              : null,
          middle: Text(
            'Messages',
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          trailing: _selectionMode == SelectionMode.forget
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _onForgetPressed,
                  child: Text(
                    'Forget',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: _selectedIds.isEmpty
                          ? CupertinoColors.systemGrey
                          : CupertinoColors.destructiveRed,
                    ),
                  ),
                )
              : _selectedIds.isNotEmpty
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _onBulkCategorize,
                  child: Text(
                    'Bulk Categorize',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                )
              : null,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Add this search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: TapRegion(
                  onTapOutside: (event) {
                    if (_searchFocusNode.hasFocus) {
                      _searchFocusNode.unfocus();
                    }
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoSearchTextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode, // Assign the focus node
                          onChanged: _onSearchChanged,
                          placeholder: 'Search messages',
                        ),
                      ),
                      if (_selectionMode != SelectionMode.forget)
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          onPressed: _showFilterMenu,
                          child: Icon(
                            CupertinoIcons.slider_horizontal_3,
                            color:
                                spendingService.currentDurationFilter != 'all'
                                ? CupertinoColors.activeBlue
                                : CupertinoColors.systemGrey,
                            size: 22,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              _buildFilterBar(),
              Expanded(
                child: Stack(
                  children: [
                    // UI based on spendingService.isLoading
                    if (spendingService.isLoading && _displayList.isEmpty)
                      const Center(child: CupertinoActivityIndicator())
                    else if (messages.isEmpty && !spendingService.isLoading)
                      Center(
                        child: Text(
                          spendingService.searchQuery.isEmpty
                              ? 'No messages found'
                              : 'No results for "${spendingService.searchQuery}"',
                          style: GoogleFonts.spaceGrotesk(
                            color: CupertinoColors.systemGrey,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    AnimatedList(
                      key: _listKey,
                      controller: _scrollController,
                      initialItemCount: _displayList.length,
                      itemBuilder: (context, index, animation) {
                        if (index >= _displayList.length) {
                          return const SizedBox();
                        }
                        final item = _displayList[index];
                        bool isLastInGroup = true;
                        if (index + 1 < _displayList.length) {
                          isLastInGroup = _displayList[index + 1] is String;
                        }
                        return _buildItem(item, animation, isLastInGroup);
                      },
                    ),
                    // Loading indicator for initial load or pagination, only if no search is active
                    if (spendingService.isLoading && _displayList.isNotEmpty)
                      const Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Center(child: CupertinoActivityIndicator()),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _FilterChip(
              label: 'All',
              isActive: _activeFilter == 'all',
              onTap: () => _onFilterChanged('all'),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Mapping',
              isActive: _activeFilter == 'mapping',
              onTap: () => _onFilterChanged('mapping'),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Categorization',
              isActive: _activeFilter == 'categorization',
              onTap: () => _onFilterChanged('categorization'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.black : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            color: isActive ? Colors.white : Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool showSelectAll;
  final bool allSelected;
  final VoidCallback? onToggleSelectAll;

  const _SectionHeader({
    required this.title,
    this.showSelectAll = false,
    this.allSelected = false,
    this.onToggleSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          if (showSelectAll)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onToggleSelectAll,
              child: Text(
                allSelected ? 'Unselect All' : 'Select All',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.activeBlue,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

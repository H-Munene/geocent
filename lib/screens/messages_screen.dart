import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_transaction.dart';
import '../services/spending_service.dart';
import '../widgets/unmapped_message_tile.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<AppTransaction> _displayList = [];
  String _activeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
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
    _syncList(service.paginatedMessages);
  }

  void _syncList(List<AppTransaction> newMessages) {
    if (newMessages.length < _displayList.length ||
        (newMessages.isNotEmpty &&
            _displayList.isNotEmpty &&
            newMessages.first.id != _displayList.first.id)) {
      // Full refresh needed
      _clearList();
      Future.delayed(const Duration(milliseconds: 300), () {
        for (int i = 0; i < newMessages.length; i++) {
          _displayList.add(newMessages[i]);
          _listKey.currentState?.insertItem(i);
        }
      });
      return;
    }

    // Basic sync for pagination (appending)
    for (int i = _displayList.length; i < newMessages.length; i++) {
      _displayList.add(newMessages[i]);
      _listKey.currentState?.insertItem(i);
    }
  }

  void _clearList() {
    for (int i = _displayList.length - 1; i >= 0; i--) {
      final removedItem = _displayList.removeAt(i);
      _listKey.currentState?.removeItem(
        i,
        (context, animation) => _buildItem(removedItem, animation, i == 0),
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  void _onFilterChanged(String filter) async {
    if (_activeFilter == filter) return;
    setState(() {
      _activeFilter = filter;
    });

    _clearList();

    final service = context.read<SpendingService>();
    await service.setFilter(filter);
    _syncList(service.paginatedMessages);
  }

  Widget _buildItem(
    AppTransaction tx,
    Animation<double> animation,
    bool isLast,
  ) {
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
          showDivider: !isLast,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spendingService = context.watch<SpendingService>();
    final messages = spendingService.paginatedMessages;

    // Sync if service updated (e.g. pagination loaded more)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (messages.length > _displayList.length) {
        _syncList(messages);
      }
    });

    return CupertinoPageScaffold(
      backgroundColor: Colors.white,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.white.withValues(alpha: 0.8),
        border: null,
        middle: Text(
          'Messages',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: Stack(
                children: [
                  if (_displayList.isEmpty && !spendingService.isLoading)
                    Center(
                      child: Text(
                        'No messages found',
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
                      if (index >= _displayList.length) return const SizedBox();
                      return _buildItem(
                        _displayList[index],
                        animation,
                        index == _displayList.length - 1,
                      );
                    },
                  ),
                  if (spendingService.isLoading && _displayList.isEmpty)
                    const Center(child: CupertinoActivityIndicator()),
                  if (spendingService.isLoading && _displayList.isNotEmpty)
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: const Center(child: CupertinoActivityIndicator()),
                    ),
                ],
              ),
            ),
          ],
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

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.black,
        ),
      ),
    );
  }
}

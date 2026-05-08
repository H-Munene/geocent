import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:geocent/models/category_item.dart';
import 'package:geocent/services/spending_service.dart';
import 'package:geocent/widgets/custom_toast.dart';
import 'package:provider/provider.dart';

class CreateCategorySheet extends StatefulWidget {
  final String transactionId;

  const CreateCategorySheet({super.key, required this.transactionId});

  @override
  State<CreateCategorySheet> createState() => _CreateCategorySheetState();
}

class _CreateCategorySheetState extends State<CreateCategorySheet> {
  final TextEditingController _controller = TextEditingController();
  CategoryItem? _selectedIcon;
  Color? _selectedColor;

  final List<Color> _availableColors = [
    CupertinoColors.systemRed,
    CupertinoColors.systemOrange,
    CupertinoColors.systemYellow,
    const Color(0xFFAF52DE), // Orchid
    CupertinoColors.systemMint,
    CupertinoColors.systemTeal,
    CupertinoColors.systemCyan,
    CupertinoColors.systemBlue,
    CupertinoColors.systemIndigo,
    CupertinoColors.systemPurple,
    CupertinoColors.systemPink,
    CupertinoColors.systemBrown,
    CupertinoColors.systemGreen,
    const Color(0xFFFF2D55), // Rose
    const Color(0xFF5856D6), // Indigo deep
    const Color(0xFF34C759), // Success Green
    const Color(0xFFFF9500), // Warning Orange
    const Color(0xFF007AFF), // Link Blue
    const Color(0xFF5AC8FA), // Sky Blue
    const Color(0xFFFFCC00), // Gold
  ];

  @override
  Widget build(BuildContext context) {
    final spending = context.watch<SpendingService>();
    final availableIcons = spending.availableIconsPool;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white,
        border: null,
        middle: Text(
          'New Category',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: const Color(0xFF1D1D1F),
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            var name = _controller.text.trim();
            if (name.isNotEmpty &&
                _selectedIcon != null &&
                _selectedColor != null) {
              final existingCategories = spending.categories;

              // Check for duplicates (case-insensitive)
              if (existingCategories.any(
                (cat) => cat.name.toLowerCase() == name.toLowerCase(),
              )) {
                showCustomToast('Category name already exists');
                return;
              }

              // Capitalize the first letter
              name = name.substring(0, 1).toUpperCase() + name.substring(1);

              final newCategory = CategoryItem(
                name: name,
                icon: _selectedIcon!.icon,
              );
              spending.addCategory(newCategory, _selectedColor!);
              spending.updateCategory(widget.transactionId, name);
              Navigator.pop(context);
            }
          },
          child: Text(
            'Create',
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0071E3),
            ),
          ),
        ),
      ),
      child: DefaultTextStyle(
        style: GoogleFonts.spaceGrotesk(
          color: const Color(0xFF1D1D1F),
          decoration: TextDecoration.none,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NAME',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: CupertinoColors.systemGrey,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: _controller,
                  placeholder: 'e.g. Entertainment',
                  maxLength: 30,
                  placeholderStyle: GoogleFonts.spaceGrotesk(
                    color: CupertinoColors.systemGrey4,
                  ),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1D1D1F),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: CupertinoColors.systemGrey6,
                        width: 1.5,
                      ),
                    ),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 32),
                Text(
                  'SELECT COLOR',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: CupertinoColors.systemGrey,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 100,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: _availableColors
                              .take(10)
                              .map((color) => _buildColorItem(color))
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: _availableColors
                              .skip(10)
                              .map((color) => _buildColorItem(color))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'SELECT ICON',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: CupertinoColors.systemGrey,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                        ),
                    itemCount: availableIcons.length,
                    itemBuilder: (context, index) {
                      final item = availableIcons[index];
                      final isSelected = _selectedIcon == item;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedIcon = item),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (_selectedColor ?? CupertinoColors.activeBlue)
                                      .withValues(alpha: 0.15)
                                : CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? (_selectedColor ??
                                        CupertinoColors.activeBlue)
                                  : CupertinoColors.transparent,
                              width: 2,
                            ),
                          ),
                          child: HugeIcon(
                            icon: item.icon,
                            color: isSelected
                                ? (_selectedColor ?? CupertinoColors.activeBlue)
                                : CupertinoColors.systemGrey2,
                            size: 26,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorItem(Color color) {
    final isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: CupertinoColors.black, width: 2.5)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? const Icon(
                CupertinoIcons.checkmark,
                color: CupertinoColors.white,
                size: 20,
              )
            : null,
      ),
    );
  }
}

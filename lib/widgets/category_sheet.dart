import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mapbox_tut/models/category_item.dart';
import 'package:mapbox_tut/models/map_place.dart';
import 'package:mapbox_tut/services/spending_service.dart';
import 'package:provider/provider.dart';

class CreateCategorySheet extends StatefulWidget {
  final MapPlace place;
  final List<CategoryItem> availableIcons;

  const CreateCategorySheet({
    super.key,
    required this.place,
    required this.availableIcons,
  });

  @override
  State<CreateCategorySheet> createState() => _CreateCategorySheetState();
}

class _CreateCategorySheetState extends State<CreateCategorySheet> {
  final TextEditingController _controller = TextEditingController();
  CategoryItem? _selectedIcon;
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(
        context,
      ).copyWith(textTheme: GoogleFonts.spaceGroteskTextTheme()),
      child: Material(
        child: CupertinoPageScaffold(
          backgroundColor: Colors.white,
          navigationBar: CupertinoNavigationBar(
            backgroundColor: Colors.white,
            border: null,
            middle: Text(
              'New Category',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                final name = _controller.text.trim();
                if (name.isNotEmpty && _selectedIcon != null) {
                  final spending = context.read<SpendingService>();
                  final newCategory = CategoryItem(
                    name: name,
                    icon: _selectedIcon!.icon,
                    color: _selectedIcon!.color,
                  );
                  spending.addCategory(newCategory);
                  spending.updateCategory(widget.place.id, name);
                  Navigator.pop(context);
                }
              },
              child: Text(
                'Create',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.activeBlue,
                ),
              ),
            ),
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
                      color: Colors.grey[500],
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: _controller,
                    placeholder: 'e.g. Entertainment',
                    placeholderStyle: GoogleFonts.spaceGrotesk(
                      color: Colors.grey[400],
                    ),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1A1A1A),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFFEEEEEE),
                          width: 1.5,
                        ),
                      ),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'SELECT ICON',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[500],
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
                      itemCount: widget.availableIcons.length,
                      itemBuilder: (context, index) {
                        final item = widget.availableIcons[index];
                        final isSelected = _selectedIcon == item;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedIcon = item),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? item.color.withValues(alpha: 0.15)
                                  : const Color(0xFFF8F8F8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? item.color
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: HugeIcon(
                              icon: item.icon,
                              color: isSelected
                                  ? item.color
                                  : Colors.grey[400]!,
                              size: 15,
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
      ),
    );
  }
}

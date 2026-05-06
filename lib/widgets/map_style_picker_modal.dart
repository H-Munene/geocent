import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import '../utils/images.dart' as img;

class MapStylePickerModal extends StatefulWidget {
  final String currentStyle;
  final ValueChanged<String> onStyleChanged;

  const MapStylePickerModal({
    super.key,
    required this.currentStyle,
    required this.onStyleChanged,
  });

  @override
  State<MapStylePickerModal> createState() => _MapStylePickerModalState();
}

class _MapStylePickerModalState extends State<MapStylePickerModal> {
  late String _localCurrentStyle;

  @override
  void initState() {
    super.initState();
    _localCurrentStyle = widget.currentStyle;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 32), // Balance for center alignment
                Text(
                  'Map Style',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1D1D1F),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: CupertinoColors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.clear,
                      size: 20,
                      color: CupertinoColors.black,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildStyleOption(
                    'Standard',
                    mp.MapboxStyles.STANDARD,
                    img.standardMapStyle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStyleOption(
                    'Satellite',
                    mp.MapboxStyles.STANDARD_SATELLITE,
                    img.satelliteMapStyle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStyleOption(
                    'Light',
                    mp.MapboxStyles.LIGHT,
                    img.lightMapStyle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStyleOption(
                    'Dark',
                    mp.MapboxStyles.DARK,
                    img.darkMapStyle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleOption(String title, String styleUri, String imagePath) {
    final isSelected = _localCurrentStyle == styleUri;
    return GestureDetector(
      onTap: () {
        setState(() => _localCurrentStyle = styleUri);
        widget.onStyleChanged(styleUri);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0071E3).withValues(alpha: 0.1)
              : CupertinoColors.systemGrey6,
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0071E3)
                : CupertinoColors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: Image.asset(imagePath, height: 80, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF0071E3)
                        : const Color(0xFF1D1D1F),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

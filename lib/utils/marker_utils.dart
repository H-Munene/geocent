import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/call_out_result.dart';

// ── Callout (name + price tag) ─────────────────────────────────────────────

Future<CalloutResult> createCalloutImage(
  String name,
  String price, {
  Color? color,
}) async {
  const double cardHeight = 44.0;
  const double namePaddingH = 14.0;
  const double pricePaddingH = 14.0;
  const double borderWidth = 1.5;

  // Stem + dot dimensions
  const double stemWidth = 2.0;
  const double stemHeight = 20.0;
  const double dotRadius = 5.0;

  // Total canvas height = card + stem + dot diameter
  const double totalHeight = cardHeight + stemHeight + dotRadius * 2;

  // ── Text painters ──────────────────────────────────────────────────────────

  final namePainter = TextPainter(
    text: TextSpan(
      text: name.toUpperCase(),
      style: GoogleFonts.spaceGrotesk(
        color: const Color(0xFF1D1D1F),
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final pricePainter = TextPainter(
    text: TextSpan(
      text: price,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.8,
        fontFeatures: [const ui.FontFeature.tabularFigures()],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  // ── Canvas sizing ──────────────────────────────────────────────────────────

  final double nameBlockW = (namePaddingH + namePainter.width + namePaddingH)
      .ceilToDouble();
  final double priceBlockW =
      (pricePaddingH + pricePainter.width + pricePaddingH).ceilToDouble();
  final double totalWidth = nameBlockW + priceBlockW;

  // Stem is centred on the card midpoint
  final double stemCentreX = totalWidth / 2;
  // Dot centre sits at the very bottom of the canvas (radius 5.0, so centre is 5.0 from bottom)
  final double dotCentreX = stemCentreX;
  final double dotCentreY = cardHeight + stemHeight + dotRadius;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // ── 0. Institutional Shadow (Strictly for Markers) ─────────────────────────

  final shadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.15)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

  // Shadow for the card
  canvas.drawRect(Rect.fromLTWH(4, 4, totalWidth, cardHeight), shadowPaint);
  // Shadow for the stem
  canvas.drawLine(
    Offset(stemCentreX + 2, cardHeight + 2),
    Offset(stemCentreX + 2, cardHeight + stemHeight + 2),
    shadowPaint..strokeWidth = stemWidth,
  );

  // ── 1. White name section ──────────────────────────────────────────────────

  final Rect nameRect = Rect.fromLTWH(0, 0, nameBlockW, cardHeight);
  canvas.drawRect(nameRect, Paint()..color = Colors.white);

  namePainter.paint(
    canvas,
    Offset(namePaddingH, (cardHeight - namePainter.height) / 2),
  );

  // ── 2. Color price section ───────────────────────────────────────────────────

  final Color accentColor =
      color ?? const Color(0xFF0071E3); // default to Apple Blue
  final Rect priceRect = Rect.fromLTWH(nameBlockW, 0, priceBlockW, cardHeight);
  canvas.drawRect(priceRect, Paint()..color = accentColor);

  pricePainter.paint(
    canvas,
    Offset(nameBlockW + pricePaddingH, (cardHeight - pricePainter.height) / 2),
  );

  // ── 3. Outer border (drawn last so it sits on top of both fills) ───────────

  canvas.drawRect(
    Rect.fromLTWH(0, 0, totalWidth, cardHeight),
    Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth,
  );

  // ── 4. Thin accented stem ───────────────────────────────────────────────────────

  canvas.drawLine(
    Offset(stemCentreX, cardHeight),
    Offset(stemCentreX, cardHeight + stemHeight),
    Paint()
      ..color = accentColor
      ..strokeWidth = stemWidth
      ..strokeCap = StrokeCap.butt,
  );

  // ── 5. Filled accented dot ──────────────────────────────────────────────────────

  canvas.drawCircle(
    Offset(dotCentreX, dotCentreY),
    dotRadius,
    Paint()..color = accentColor,
  );

  // ── Rasterise ──────────────────────────────────────────────────────────────

  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(
    totalWidth.ceil(),
    totalHeight.ceil(),
  );
  final ByteData? byteData = await image.toByteData(
    format: ui.ImageByteFormat.png,
  );

  return CalloutResult(
    image: byteData!.buffer.asUint8List(),
    width: totalWidth,
  );
}

// ── Icon image (unchanged) ─────────────────────────────────────────────────

Future<Uint8List> createIconImage(String iconAsset) async {
  const double size = 50;
  const double iconSize = 28;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  final ByteData iconByteData = await rootBundle.load('assets/$iconAsset.png');
  final Uint8List iconBytes = iconByteData.buffer.asUint8List();
  final ui.Codec codec = await ui.instantiateImageCodec(
    iconBytes,
    targetWidth: iconSize.toInt(),
    targetHeight: iconSize.toInt(),
  );
  final ui.FrameInfo frameInfo = await codec.getNextFrame();
  final ui.Image iconImg = frameInfo.image;

  canvas.drawImageRect(
    iconImg,
    Rect.fromLTWH(0, 0, iconImg.width.toDouble(), iconImg.height.toDouble()),
    Rect.fromLTWH(
      (size - iconSize) / 2,
      (size - iconSize) / 2,
      iconSize,
      iconSize,
    ),
    Paint(),
  );

  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(size.toInt(), size.toInt());
  final ByteData? byteData = await image.toByteData(
    format: ui.ImageByteFormat.png,
  );
  return byteData!.buffer.asUint8List();
}

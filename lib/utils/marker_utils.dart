import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/call_out_result.dart';

Future<CalloutResult> createCalloutImage(String name, String price) async {
  const double height = 50;
  const double padding = 12;
  const double shadowBlur = 8;
  const double shadowOffsetY = 4;

  final namePainter = TextPainter(
    text: TextSpan(
      text: name,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final pricePainter = TextPainter(
    text: TextSpan(
      text: price,
      style: const TextStyle(
        color: Color(0xFFE53935),
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final double width =
      padding +
      namePainter.width +
      padding +
      1.5 +
      padding +
      pricePainter.width +
      padding;
  final double canvasHeight = height + shadowOffsetY + shadowBlur;
  final double canvasWidth = width + shadowBlur;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final rect = Rect.fromLTWH(shadowBlur / 2, 0, width, height);

  canvas.drawRect(
    rect,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, shadowBlur / 2),
  );

  canvas.drawRect(
    Rect.fromLTWH(shadowBlur / 2, shadowOffsetY, width, height),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, shadowBlur),
  );

  canvas.drawRect(
    rect,
    Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );

  canvas.drawRect(rect, Paint()..color = Colors.white);

  namePainter.paint(
    canvas,
    Offset(shadowBlur / 2 + padding, (height - namePainter.height) / 2),
  );
  final double dividerX =
      shadowBlur / 2 + padding + namePainter.width + padding;

  canvas.drawLine(
    Offset(dividerX, 10),
    Offset(dividerX, height - 10),
    Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.5,
  );

  pricePainter.paint(
    canvas,
    Offset(dividerX + padding, (height - pricePainter.height) / 2),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    canvasWidth.toInt(),
    canvasHeight.toInt(),
  );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

  return CalloutResult(
    image: byteData!.buffer.asUint8List(),
    width: canvasWidth,
  );
}

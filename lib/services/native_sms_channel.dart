// lib/services/native_sms_channel.dart
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:mapbox_tut/models/sms_message.dart';

/// Dart-side wrapper for the native SMS MethodChannel.
///
/// Usage:
///   NativeSmsChannel.instance.smsStream.listen((body) { ... });
class NativeSmsChannel {
  NativeSmsChannel._();
  static final NativeSmsChannel instance = NativeSmsChannel._();

  static const _channel = MethodChannel('com.spendmap/sms');

  // StreamController that re-emits every SMS the native side pushes
  final _controller = StreamController<SmsMessage>.broadcast();

  /// Emits a [SmsMessage] every time a new SMS arrives on the device.
  Stream<SmsMessage> get smsStream => _controller.stream;

  /// Call once — typically from SmsService.init().
  void register() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSmsReceived') {
        final args = Map<String, String>.from(call.arguments as Map);
        _controller.add(
          SmsMessage(sender: args['sender'] ?? '', body: args['body'] ?? ''),
        );
      }
    });
  }

  void dispose() {
    _controller.close();
  }
}

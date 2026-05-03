import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/svg.dart';

const String assetsPath = 'assets/icon'; // Use forward slash

String _pin = '$assetsPath/pin.svg';
String _pinActive = '$assetsPath/pin_active.svg';
String _unmap = '$assetsPath/unmap.svg';
String _unmapActive = '$assetsPath/unmapActive.svg';

const double iconSize = 25;
final cl = const Color(0xFF8E8E93);
final cl2 = const Color(0xFF0071E3); // Apple Blue

SvgPicture pinActive = SvgPicture.asset(
  _pinActive,
  width: iconSize,
  height: iconSize,
  // colorFilter: _colorFilter,
);

SvgPicture pin = SvgPicture.asset(_pin, width: iconSize, height: iconSize);

SvgPicture unmap = SvgPicture.asset(_unmap, width: iconSize, height: iconSize);
SvgPicture unmapActive = SvgPicture.asset(
  _unmapActive,
  width: iconSize,
  height: iconSize,
);

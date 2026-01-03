import 'dart:io';

import 'package:wild/methods.dart';

import 'package:wild/features/settings/screen/screen_up_on_reading_property.dart';
import 'package:wild/features/settings/screen/screen_up_on_scroll_property.dart';

bool _screenKeepOn = false;

Future _setKeepScreenOn(bool keepScreenOn) async {
  if (!(Platform.isAndroid || Platform.isIOS)) {
    return;
  }
  if (_screenKeepOn == keepScreenOn) {
    return;
  }
  _screenKeepOn = keepScreenOn;
  return setKeepScreenOn(keepScreenOn);
}

bool _keepScreenUpOnReading = false;
bool _keepScreenUpOnScroll = false;

Future setKeepScreenUpOnReading(bool keepScreenUpOnReading) async {
  if (_keepScreenUpOnReading == keepScreenUpOnReading) {
    return;
  }
  _keepScreenUpOnReading = keepScreenUpOnReading;
  await _setKeepScreenOn(
    (_keepScreenUpOnReading && currentScreenUpOnReading) ||
        (_keepScreenUpOnScroll && currentScreenUpOnScroll),
  );
}

Future setKeepScreenUpOnScroll(bool keepScreenUpOnScroll) async {
  if (_keepScreenUpOnScroll == keepScreenUpOnScroll) {
    return;
  }
  _keepScreenUpOnScroll = keepScreenUpOnScroll;
  await _setKeepScreenOn(
    (_keepScreenUpOnReading && currentScreenUpOnReading) ||
        (_keepScreenUpOnScroll && currentScreenUpOnScroll),
  );
}

import 'package:flutter/services.dart';

MethodChannel _channel = const MethodChannel('methods');

Future<String> dataRoot() async {
  return await _channel.invokeMethod("dataRoot");
}

Future<bool> getKeepScreenOn() async {
  return await _channel.invokeMethod("getKeepScreenOn");
}

Future setKeepScreenOn(bool keepScreenOn) async {
  return await _channel.invokeMethod("setKeepScreenOn", keepScreenOn);
}

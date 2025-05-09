import 'package:flutter/services.dart';

MethodChannel _channel = const MethodChannel('methods');

Future<String> dataRoot() async {
  return await _channel.invokeMethod("dataRoot");
}

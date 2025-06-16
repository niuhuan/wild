import 'dart:io';

import 'package:flutter/material.dart';
import '../src/rust/api/database.dart';

const key = "_screenUpOnReadingProperty";
var _screenUpOnReadingProperty = false;

bool get currentScreenUpOnReading => _screenUpOnReadingProperty;

Future initScreenUpOnReading() async {
  var v = await loadProperty(key: key);
  if (v != "") {
    var a = bool.tryParse(v);
    if (a != null) {
      _screenUpOnReadingProperty = a;
    }
  }
}

Widget screenUpOnReadingSetting() {
  if (Platform.isAndroid || Platform.isIOS) {
    return StatefulBuilder(
      builder: (BuildContext context, void Function(void Function()) setState) {
        return SwitchListTile(
          title: Text("打开阅读器时保持亮屏"),
          value: _screenUpOnReadingProperty,
          onChanged: (v) {
            setState(() {
              _screenUpOnReadingProperty = v;
            });
            saveProperty(key: key, value: "$v");
          },
        );
      },
    );
  }
  return Container();
}

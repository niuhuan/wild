import 'dart:io';

import 'package:flutter/material.dart';
import 'package:wild/src/rust/api/database.dart';

const key = "_screenUpOnScrollProperty";
var _screenUpOnScrollProperty = true;

bool get currentScreenUpOnScroll => _screenUpOnScrollProperty;

Future initScreenUpOnScroll() async {
  var v = await loadProperty(key: key);
  if (v != "") {
    var a = bool.tryParse(v);
    if (a != null) {
      _screenUpOnScrollProperty = a;
    }
  }
}

Widget screenUpOnScrollSetting() {
  if (Platform.isAndroid || Platform.isIOS) {
    return StatefulBuilder(
      builder: (BuildContext context, void Function(void Function()) setState) {
        return SwitchListTile(
          title: Text("滚屏时保持亮屏"),
          value: _screenUpOnScrollProperty,
          onChanged: (v) {
            setState(() {
              _screenUpOnScrollProperty = v;
            });
            saveProperty(key: key, value: "$v");
          },
        );
      },
    );
  }
  return Container();
}




import 'dart:async';
import 'dart:io';

import 'package:event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

///////////////

final keyboardController = false;

Event<ReaderControllerEventArgs> readerControllerEvent =
Event<ReaderControllerEventArgs>();

class ReaderControllerEventArgs extends EventArgs {
  final String key;

  ReaderControllerEventArgs(this.key);
}

Widget readerKeyboardHolder(Widget widget) {
  if (keyboardController &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    widget = RawKeyboardListener(
      focusNode: FocusNode(),
      child: widget,
      autofocus: true,
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
            readerControllerEvent.broadcast(ReaderControllerEventArgs("UP"));
          }
          if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
            readerControllerEvent
                .broadcast(ReaderControllerEventArgs("DOWN"));
          }
        }
      },
    );
  }
  return widget;
}

void _onVolumeEvent(dynamic args) {
  readerControllerEvent.broadcast(ReaderControllerEventArgs("$args"));
}

var _volumeListenCount = 0;

// 仅支持安卓
// 监听后会拦截安卓手机音量键
// 仅最后一次监听生效
// event可能为DOWN/UP
EventChannel volumeButtonChannel = const EventChannel("volume_button");
StreamSubscription? volumeS;

void addVolumeListen() {
  _volumeListenCount++;
  if (_volumeListenCount == 1) {
    volumeS =
        volumeButtonChannel.receiveBroadcastStream().listen(_onVolumeEvent);
  }
}

void delVolumeListen() {
  _volumeListenCount--;
  if (_volumeListenCount == 0) {
    volumeS?.cancel();
  }
}

///////////////////////////////////////////////////////////////////////////////

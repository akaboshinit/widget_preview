// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

class DaemonRequest {
  DaemonRequest({required this.method, this.params});

  factory DaemonRequest.hotRestart({required String appId}) =>
      DaemonRequest._reloadOrRestart(
        appId: appId,
        restart: true,
      );

  factory DaemonRequest.hotReload({required String appId}) =>
      DaemonRequest._reloadOrRestart(
        appId: appId,
        restart: false,
      );

  factory DaemonRequest._reloadOrRestart({
    required String appId,
    required bool restart,
  }) {
    return DaemonRequest(
      method: 'app.restart',
      params: {
        'appId': appId,
        'fullRestart': restart,
        'pause': false,
        'reason': 'File changed',
        'debounce': true,
      },
    );
  }

  String encode() => _encoded ??= json.encode(
        [
          {
            'id': '${_id++}',
            'method': method,
            if (params != null) 'params': params,
          }
        ],
      );

  final String method;
  final Map<String, Object?>? params;

  String? _encoded;

  static int _id = 0;
}

class Daemon {
  Daemon({required this.onAppStart});

  void Function(String) onAppStart;

  void handleEvent(String event) {
    List<Object?> root;
    try {
      root = json.decode(event) as List<Object?>;
    } on FormatException {
      return;
    }
    final data = root.first as Map<String, Object?>;
    if (data
        case {
          'event': 'app.started',
          'params': {
            'appId': String id,
          }
        } when appId == null) {
      appId = id;
      onAppStart(id);
    }
  }

  String? appId;
}

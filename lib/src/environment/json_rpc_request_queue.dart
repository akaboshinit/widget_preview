// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:json_rpc_2/json_rpc_2.dart';

typedef RequestExecutor = FutureOr<void> Function();

/// A queue used to handle JSON RPC requests in the order they're received.
///
/// Since [Peer] can handle multiple simultaneous requests, it's possible for
/// asynchronous calls in the request handlers to result in asynchronous work
/// from multiple requests being interleaved, possibly corrupting state.
///
/// [JsonRpcRequestQueue] injects a wrapper around each RPC handlers that
/// executes it within a critical section, blocking subsequent requests from
/// being handled until the current handler completes.
///
/// WARNING: the ordering of this code is extremely brittle and relies on
/// the behavior of asynchronous execution in Dart to ensure that operations are
/// performed atomically.
/// 
/// Do not introduce any additional asynchronous code in any of the
/// private functions in this class as it will likely break the execution
/// ordering guarantees made by this queue by introducing asynchronous gaps.
class JsonRpcRequestQueue {
  JsonRpcRequestQueue({required this.connection});

  final Peer connection;

  void registerMethod(String name, Future<void> Function(Parameters) callback) {
    connection.registerMethod(
      name,
      (Parameters params) {
        _schedule(
          () async => await callback(params),
        );
      },
    );
  }

  void _schedule(RequestExecutor requestCallback) async {
    try {
      await _acquireLock();
      return await requestCallback();
    } finally {
      _releaseLock();
    }
  }

  Future<void> _acquireLock() async {
    if (!_locked) {
      _locked = true;
      return;
    }

    final request = Completer<void>();
    _outstandingRequests.add(request);
    await request.future;
  }

  void _releaseLock() {
    if (_outstandingRequests.isNotEmpty) {
      final request = _outstandingRequests.removeFirst();
      request.complete();
      return;
    }
    // Only release the lock if no other requests are pending to prevent races
    // between the next request from the queue to be handled and incoming
    // requests.
    _locked = false;
  }

  bool _locked = false;
  final _outstandingRequests = Queue<Completer<void>>();
}
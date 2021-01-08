// Copyright (c) 2017, the gRPC project authors. Please see the AUTHORS file
// for details. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';

import 'package:async/async.dart';

import '../shared/status.dart';
import 'call.dart';

/// A gRPC response.
abstract class Response {
  /// Header metadata returned from the server.
  ///
  /// The [headers] future will complete before any response objects become
  /// available. If [cancel] is called before the headers are available, the
  /// returned future will complete with an error.
  Future<Map<String, String>> get headers;

  /// Trailer metadata returned from the server.
  ///
  /// The [trailers] future will complete after all responses have been received
  /// from the server. If [cancel] is called before the trailers are available,
  /// the returned future will complete with an error.
  Future<Map<String, String>> get trailers;

  /// Cancel this gRPC call. Any remaining request objects will not be sent, and
  /// no further responses will be received.
  Future<void> cancel();
}

/// A gRPC response producing a single value.
class ResponseFuture<R> extends DelegatingFuture<R>
    with _ResponseMixin<dynamic, R> {
  final ClientCall _call;

  static R _ensureOnlyOneResponse<R>(R previous, R element) {
    if (previous != null) {
      throw GrpcError.unimplemented('More than one response received');
    }
    return element;
  }

  static R _ensureOneResponse<R>(R value) {
    if (value == null) throw GrpcError.unimplemented('No responses received');
    return value;
  }

  ResponseFuture(ClientCall<dynamic, R> call)
      : _call = call,
        super(call.response
            .fold(null, _ensureOnlyOneResponse)
            .then(_ensureOneResponse));

  ResponseFuture._clone(Future<R> future, {ClientCall clientCall})
      : _call = clientCall,
        super(future);

  ResponseFuture<S> copy<S>(Future<S> future) =>
      ResponseFuture._clone(future, clientCall: _getClientCall(future, _call));

  /// clientCall maybe be lost when converting from Future to ResponseFuture
  static ResponseFuture<T> wrap<T>(Future<T> future, {ClientCall clientCall}) {
    return ResponseFuture._clone(
      future,
      clientCall: (_getClientCall(future, clientCall)),
    );
  }

  static ClientCall _getClientCall(Future future, [ClientCall fallback]) {
    return (future is ResponseFuture ? future._call : null) ?? fallback;
  }

  @override
  ResponseFuture<S> then<S>(FutureOr<S> Function(R p1) onValue,
      {Function onError}) {
    return copy(super.then(onValue, onError: onError));
  }

  @override
  Future<R> catchError(Function onError, {bool Function(Object error) test}) {
    return copy(super.catchError(onError, test: test));
  }

  @override
  Future<R> whenComplete(FutureOr Function() action) {
    return copy(super.whenComplete(action));
  }

  @override
  Future<R> timeout(Duration timeLimit, {FutureOr<R> Function() onTimeout}) {
    return copy(super.timeout(timeLimit, onTimeout: onTimeout));
  }
}

/// A gRPC response producing a stream of values.
class ResponseStream<R> extends DelegatingStream<R>
    with _ResponseMixin<dynamic, R> {
  final ClientCall<dynamic, R> _call;

  ResponseStream(this._call) : super(_call.response);

  ResponseFuture<R> get single => ResponseFuture(this._call);
}

abstract class _ResponseMixin<Q, R> implements Response {
  ClientCall get _call;

  @override
  Future<Map<String, String>> get headers => _call.headers;

  @override
  Future<Map<String, String>> get trailers => _call.trailers;

  @override
  Future<void> cancel() => _call?.cancel();
}

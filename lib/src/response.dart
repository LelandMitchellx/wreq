import 'dart:ffi';

import 'bindings.dart';

/// 强类型响应对象，支持自动 GC 回收与主动显式 dispose 释放原生资源
final class WreqResponse implements Finalizable {
  final int statusCode;
  final String _body;
  Pointer<CWreqResponse>? _nativePtr;
  bool _isDisposed = false;

  /// 底层原生资源是否已被释放
  bool get isDisposed => _isDisposed;

  /// HTTP 响应正文。若对象已被 dispose 释放，抛出 StateError 避免访问脏内存
  String get body {
    if (_isDisposed) {
      throw StateError('Cannot access body on a disposed WreqResponse');
    }
    return _body;
  }

  /// 内部构造方法，用于绑定底层原生指针与 Finalizer
  // ignore: prefer_initializing_formals
  WreqResponse.fromNative({
    required this.statusCode,
    required this._body,
    Pointer<CWreqResponse>? nativePtr,
  })  : _nativePtr = nativePtr {
    if (nativePtr != null && nativePtr != nullptr) {
      responseFinalizer.attach(this, nativePtr.cast(), detach: this);
    }
  }

  /// 构造方法，用于兼容无需底层指针绑定的场景
  factory WreqResponse({required int statusCode, required String body}) =>
      WreqResponse.fromNative(statusCode: statusCode, body: body);

  /// 显式释放底层 Rust 分配的响应内存
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    responseFinalizer.detach(this);
    final ptr = _nativePtr;
    if (ptr != null && ptr != nullptr) {
      wreqFreeResponse(ptr);
      _nativePtr = null;
    }
  }

  @override
  String toString() =>
      'WreqResponse(status: $statusCode, bodyLength: ${_isDisposed ? "[disposed]" : _body.length})';
}

import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'exception.dart';
import 'profile.dart';
import 'response.dart';

/// 获取底层 wreq 原生库语义化版本号
String getWreqVersion() {
  final ptr = wreqVersion();
  if (ptr == nullptr) return 'unknown';
  try {
    return ptr.toDartString();
  } finally {
    wreqFreeStr(ptr);
  }
}

/// 发送异步 HTTP GET 请求，支持自定义请求头、超时时间及浏览器指纹模拟
Future<WreqResponse> wreqGet(
  String url, {
  Map<String, String>? headers,
  Duration? timeout,
  EmulationProfile? emulation,
}) async {
  final payload = jsonEncode({
    'method': 'GET',
    'url': url,
    'headers': ?headers,
    if (timeout != null) 'timeout_ms': timeout.inMilliseconds,
    if (emulation != null) 'emulation': emulation.name,
  });

  final rawRes = await Isolate.run(() {
    final jsonPtr = payload.toNativeUtf8();
    try {
      final resPtr = wreqRequest(jsonPtr);
      if (resPtr == nullptr) {
        throw const WreqException(
          'Failed to execute wreq request: null pointer returned',
        );
      }
      final ref = resPtr.ref;
      if (ref.error != nullptr) {
        final errStr = ref.error.toDartString();
        final status = ref.statusCode;
        wreqFreeResponse(resPtr);
        throw WreqException(errStr, statusCode: status);
      }
      final bodyStr = ref.body != nullptr ? ref.body.toDartString() : '';
      final status = ref.statusCode;
      return (status, bodyStr, resPtr.address);
    } finally {
      malloc.free(jsonPtr);
    }
  });

  final ptr = Pointer<CWreqResponse>.fromAddress(rawRes.$3);
  return WreqResponse.fromNative(
    statusCode: rawRes.$1,
    body: rawRes.$2,
    nativePtr: ptr,
  );
}

/// 运行 README 示例，请求 https://pingly.us.kg/api/all 并返回正文
Future<String> runReadmeExample() async {
  final res = await wreqGet('https://pingly.us.kg/api/all');
  try {
    return res.body;
  } finally {
    res.dispose();
  }
}

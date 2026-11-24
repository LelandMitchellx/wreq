import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// C-ABI 结构体，匹配 Rust CWreqResponse
final class CWreqResponse extends Struct {
  @Int32()
  external int statusCode;

  external Pointer<Utf8> body;
  external Pointer<Utf8> error;
}

final NativeFinalizer responseFinalizer = NativeFinalizer(
  Native.addressOf<NativeFunction<Void Function(Pointer<CWreqResponse>)>>(
    wreqFreeResponse,
  ).cast(),
);

@Native<Pointer<Utf8> Function()>(symbol: 'wreq_version')
external Pointer<Utf8> wreqVersion();

@Native<Pointer<CWreqResponse> Function(Pointer<Utf8>)>(symbol: 'wreq_request')
external Pointer<CWreqResponse> wreqRequest(Pointer<Utf8> reqJson);

@Native<Void Function(Pointer<CWreqResponse>)>(symbol: 'wreq_free_response')
external void wreqFreeResponse(Pointer<CWreqResponse> ptr);

@Native<Void Function(Pointer<Utf8>)>(symbol: 'wreq_free_str')
external void wreqFreeStr(Pointer<Utf8> ptr);

/// Wreq 网络与 FFI 异常
class WreqException implements Exception {
  final String message;
  final int statusCode;

  const WreqException(this.message, {this.statusCode = -1});

  @override
  String toString() => 'WreqException: $message (statusCode: $statusCode)';
}

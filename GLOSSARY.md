# Wreq FFI Context

Cross-platform Dart & Flutter native bindings for the `wreq` high-fidelity HTTP and browser emulation client.

## Language

**WreqClient**:
The primary client abstraction in Dart managing request execution, configuration, and emulation settings.
_Avoid_: HttpClient, Session, Requester

**EmulationProfile**:
A predefined browser TLS and HTTP/2 fingerprint configuration (e.g. Chrome, Safari, Firefox).
_Avoid_: FingerprintPreset, DeviceProfile, UserAgent

**NativeBridge**:
The C-ABI FFI boundary linking Dart via Native Assets (`native_toolchain_rust`) to the Rust dynamic library.
_Avoid_: PluginChannel, MethodChannel, GlueLayer

**RequestEnvelope**:
The serialized JSON payload passed across the FFI boundary containing HTTP method, URL, headers, body, and emulation settings.
_Avoid_: RequestPacket, FfiMessage, HttpPayload

**ResponseEnvelope**:
The serialized data returned asynchronously from the Rust Tokio runtime to the Dart event loop.
_Avoid_: ResultTuple, FfiResponse

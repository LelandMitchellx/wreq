pub mod abi;
pub mod emulation;
pub mod request;
pub mod runtime;

use std::ffi::{c_char, CStr, CString};

use abi::{error_response, success_response};
pub use abi::{wreq_free_response, wreq_free_str, CWreqResponse};
use request::{execute_envelope, RequestEnvelope};
use runtime::runtime;

#[no_mangle]
pub extern "C" fn wreq_version() -> *mut c_char {
    let version = b"wreq-0.16.3\0";
    match CString::from_vec_with_nul(version.to_vec()) {
        Ok(c_str) => c_str.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}

#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn wreq_request(req_json_ptr: *const c_char) -> *mut CWreqResponse {
    let panic_result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        if req_json_ptr.is_null() {
            return error_response(-1, "Error: null request pointer");
        }

        let json_str = match unsafe { CStr::from_ptr(req_json_ptr) }.to_str() {
            Ok(s) => s,
            Err(e) => {
                return error_response(-1, &format!("Error parsing request JSON string: {}", e));
            }
        };

        let envelope: RequestEnvelope = match serde_json::from_str(json_str) {
            Ok(env) => env,
            Err(e) => {
                return error_response(-1, &format!("Error deserializing RequestEnvelope: {}", e));
            }
        };

        let rt = runtime();
        match rt.block_on(execute_envelope(envelope)) {
            Ok((status_code, body)) => success_response(status_code, &body),
            Err(err) => error_response(-1, &err),
        }
    }));

    match panic_result {
        Ok(ptr) => ptr,
        Err(_) => error_response(-1, "Internal error: caught panic across C-ABI boundary"),
    }
}

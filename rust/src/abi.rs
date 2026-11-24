use std::ffi::{c_char, CString};

#[repr(C)]
pub struct CWreqResponse {
    pub status_code: i32,
    pub body: *mut c_char,
    pub error: *mut c_char,
}

pub fn to_c_string(s: &str) -> *mut c_char {
    match CString::new(s) {
        Ok(c_str) => c_str.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}

pub fn error_response(status_code: i32, err_msg: &str) -> *mut CWreqResponse {
    Box::into_raw(Box::new(CWreqResponse {
        status_code,
        body: std::ptr::null_mut(),
        error: to_c_string(err_msg),
    }))
}

pub fn success_response(status_code: i32, body: &str) -> *mut CWreqResponse {
    Box::into_raw(Box::new(CWreqResponse {
        status_code,
        body: to_c_string(body),
        error: std::ptr::null_mut(),
    }))
}

#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn wreq_free_response(resp: *mut CWreqResponse) {
    if !resp.is_null() {
        unsafe {
            let b = Box::from_raw(resp);
            if !b.body.is_null() {
                drop(CString::from_raw(b.body));
            }
            if !b.error.is_null() {
                drop(CString::from_raw(b.error));
            }
        }
    }
}

#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn wreq_free_str(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            drop(CString::from_raw(ptr));
        }
    }
}

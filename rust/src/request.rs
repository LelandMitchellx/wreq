use serde::Deserialize;
use std::collections::HashMap;
use std::time::Duration;
use wreq::Client;

use crate::emulation::resolve_emulation;

#[derive(Deserialize)]
pub struct RequestEnvelope {
    #[serde(default = "default_method")]
    pub method: String,
    pub url: String,
    pub headers: Option<HashMap<String, String>>,
    pub timeout_ms: Option<u64>,
    pub emulation: Option<String>,
}

fn default_method() -> String {
    "GET".to_string()
}

pub async fn execute_envelope(envelope: RequestEnvelope) -> Result<(i32, String), String> {
    let emu = resolve_emulation(envelope.emulation.as_deref());
    let mut builder = Client::builder().emulation(emu);

    if let Some(ms) = envelope.timeout_ms {
        builder = builder.timeout(Duration::from_millis(ms));
    }

    let client = builder.build().map_err(|e| e.to_string())?;

    let mut req = match envelope.method.to_uppercase().as_str() {
        "POST" => client.post(&envelope.url),
        "PUT" => client.put(&envelope.url),
        "DELETE" => client.delete(&envelope.url),
        "HEAD" => client.head(&envelope.url),
        _ => client.get(&envelope.url),
    };

    if let Some(ms) = envelope.timeout_ms {
        req = req.timeout(Duration::from_millis(ms));
    }

    if let Some(headers) = envelope.headers {
        for (k, v) in headers {
            if let (Ok(hname), Ok(hval)) = (
                wreq::header::HeaderName::from_bytes(k.as_bytes()),
                wreq::header::HeaderValue::from_str(&v),
            ) {
                req = req.header(hname, hval);
            }
        }
    }

    let resp = req.send().await.map_err(|e| e.to_string())?;
    let status_code = resp.status().as_u16() as i32;
    let body = resp.text().await.map_err(|e| e.to_string())?;

    Ok((status_code, body))
}

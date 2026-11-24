// secrets.rs — Environment secret redaction and handles (§6.14/§12.7).
// Redacted<T> renders as *** in logs; audit stores hashes only.

use std::collections::BTreeMap;
use std::fmt;

#[derive(Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct Redacted<T> {
    value: T,
}

impl<T> Redacted<T> {
    pub fn new(value: T) -> Self { Self { value } }
    pub fn reveal(&self) -> &T { &self.value }
}

impl<T> fmt::Debug for Redacted<T> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result { write!(f, "***") }
}

impl<T: fmt::Display> fmt::Display for Redacted<T> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result { write!(f, "***") }
}

/// Environment map where secret values are redacted on display.
pub type RedactedEnv = BTreeMap<String, Redacted<String>>;

/// Redact secret-looking values from a free text blob before it reaches logs/UI.
/// Matches KEY=VALUE, token headers, and bearer tokens.
pub fn redact_text(input: &str) -> String {
    let mut out = String::with_capacity(input.len());
    for line in input.lines() {
        let mut redacted = line.to_string();
        for key in ["TOKEN", "PASSWORD", "PASSWD", "SECRET", "API_KEY", "APIKEY", "AUTH", "KEY", "CREDENTIAL"] {
            if let Some(pos) = redacted.to_uppercase().find(key) {
                // Find the '=' after the key and replace the value up to whitespace.
                if let Some(eq_rel) = redacted[pos..].find('=') {
                    let eq = pos + eq_rel;
                    let val_start = eq + 1;
                    let mut val_end = val_start;
                    let bytes = redacted.as_bytes();
                    while val_end < bytes.len() && !bytes[val_end].is_ascii_whitespace() {
                        val_end += 1;
                    }
                    if val_end > val_start {
                        redacted.replace_range(val_start..val_end, "***");
                    }
                }
            }
        }
        // Bearer tokens
        if let Some(pos) = redacted.to_lowercase().find("bearer ") {
            let start = pos + 7;
            let mut end = start;
            let bytes = redacted.as_bytes();
            while end < bytes.len() && !bytes[end].is_ascii_whitespace() { end += 1; }
            if end > start { redacted.replace_range(start..end, "***"); }
        }
        out.push_str(&redacted);
        out.push('\n');
    }
    out
}

/// Stable non-crypto fingerprint of a secret for audit storage (never the value).
pub fn secret_fingerprint(value: &str) -> String {
    let mut h: u64 = 0xcbf29ce484222325;
    for b in value.bytes() {
        h ^= b as u64;
        h = h.wrapping_mul(0x100000001b3);
    }
    format!("fp_{:016x}", h)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn redacted_display_hides_value() {
        let r = Redacted::new("supersecret".to_string());
        assert_eq!(format!("{}", r), "***");
        assert_eq!(format!("{:?}", r), "***");
        assert_eq!(r.reveal(), "supersecret");
    }

    #[test]
    fn redacts_kv_and_bearer() {
        let line = "TOKEN=abc123 Authorization: Bearer xyz789 done";
        let r = redact_text(line);
        assert!(r.contains("TOKEN=***"));
        assert!(r.contains("Bearer ***"));
        assert!(!r.contains("abc123"));
        assert!(!r.contains("xyz789"));
    }

    #[test]
    fn fingerprint_is_stable_and_not_value() {
        let f = secret_fingerprint("hunter2");
        assert!(f.starts_with("fp_"));
        assert!(!f.contains("hunter2"));
        assert_eq!(f, secret_fingerprint("hunter2"));
    }
}

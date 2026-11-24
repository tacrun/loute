// cache.rs — Result cache keyed (provider_version, capability, inputs, catalog_hash) (§6.11).
// TTL from capability cache_ttl (0 = off). DNS/HTTP fingerprint caches always on, 15 min.

use std::collections::HashMap;
use std::sync::Mutex;
use std::time::{Duration, Instant};

#[derive(Debug, Clone)]
struct Entry<T> {
    value: T,
    created: Instant,
    ttl: Duration,
}

pub struct Cache<T: Clone> {
    entries: Mutex<HashMap<String, Entry<T>>>,
}

impl<T: Clone> Default for Cache<T> {
    fn default() -> Self { Self::new() }
}

impl<T: Clone> Cache<T> {
    pub fn new() -> Self {
        Self { entries: Mutex::new(HashMap::new()) }
    }

    pub fn key(provider_version: &str, capability: &str, inputs: &str, catalog_hash: &str) -> String {
        let raw = format!("{}|{}|{}|{}", provider_version, capability, inputs, catalog_hash);
        // Stable non-crypto hash (FNV-1a) for an in-process key.
        let mut h: u64 = 0xcbf29ce484222325;
        for b in raw.bytes() {
            h ^= b as u64;
            h = h.wrapping_mul(0x100000001b3);
        }
        format!("{:016x}", h)
    }

    /// Insert with a TTL. ttl == 0 disables caching for this entry.
    pub fn put(&self, key: String, value: T, ttl_secs: u64) {
        if ttl_secs == 0 { return; }
        let mut m = self.entries.lock().unwrap();
        m.insert(key, Entry {
            value,
            created: Instant::now(),
            ttl: Duration::from_secs(ttl_secs),
        });
    }

    pub fn get(&self, key: &str) -> Option<T> {
        let m = self.entries.lock().unwrap();
        m.get(key).and_then(|e| {
            if e.created.elapsed() < e.ttl { Some(e.value.clone()) } else { None }
        })
    }

    pub fn invalidate(&self, key: &str) {
        self.entries.lock().unwrap().remove(key);
    }

    pub fn clear(&self) {
        self.entries.lock().unwrap().clear();
    }

    /// Evict expired entries. Call periodically (background GC).
    pub fn gc(&self) -> usize {
        let mut m = self.entries.lock().unwrap();
        let before = m.len();
        m.retain(|_, e| e.created.elapsed() < e.ttl);
        before - m.len()
    }
}

pub const DNS_TTL: u64 = 900;
pub const HTTP_TTL: u64 = 900;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn put_get_and_ttl_zero() {
        let c = Cache::new();
        c.put("a".into(), 42, 900);
        assert_eq!(c.get("a"), Some(42));
        c.put("b".into(), 7, 0); // disabled
        assert_eq!(c.get("b"), None);
    }

    #[test]
    fn key_is_stable() {
        assert_eq!(Cache::<String>::key("v1", "cap", "{}", "hash"), Cache::<String>::key("v1", "cap", "{}", "hash"));
        assert_ne!(Cache::<String>::key("v1", "cap", "{}", "hash"), Cache::<String>::key("v2", "cap", "{}", "hash"));
    }
}

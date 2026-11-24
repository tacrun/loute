// opsec.rs - OPSEC profile application per 1-5-5.md §13.
// Profiles: ghost · stealth · balanced · aggressive · loud.

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum OpsecProfile {
    Ghost,
    Stealth,
    Balanced,
    Aggressive,
    Loud,
}

impl OpsecProfile {
    pub fn from_str(s: &str) -> Self {
        match s.to_lowercase().as_str() {
            "ghost" => Self::Ghost,
            "stealth" => Self::Stealth,
            "aggressive" => Self::Aggressive,
            "loud" => Self::Loud,
            _ => Self::Balanced,
        }
    }

    /// Timeout multiplier - ghost=1.5, stealth=1.25, balanced=1.0, aggressive=0.75, loud=0.5
    pub fn timeout_multiplier(&self) -> f32 {
        match self {
            Self::Ghost => 1.5,
            Self::Stealth => 1.25,
            Self::Balanced => 1.0,
            Self::Aggressive => 0.75,
            Self::Loud => 0.5,
        }
    }

    /// Max concurrency per provider
    pub fn max_concurrency(&self) -> u8 {
        match self {
            Self::Ghost => 1,
            Self::Stealth => 2,
            Self::Balanced => 4,
            Self::Aggressive => 8,
            Self::Loud => 16,
        }
    }

    /// Delay jitter range in milliseconds (min, max)
    pub fn jitter_ms(&self) -> (u64, u64) {
        match self {
            Self::Ghost => (500, 2000),
            Self::Stealth => (200, 800),
            Self::Balanced => (0, 0),
            Self::Aggressive => (0, 0),
            Self::Loud => (0, 0),
        }
    }

    /// Whether to use DNS-over-TLS
    pub fn use_dot(&self) -> bool {
        matches!(self, Self::Ghost | Self::Stealth)
    }
}

#!/usr/bin/env python3
"""
migrate_catalog_v2.py — one-time, reproducible migration of capabilities.toml.txt
from schema 1 to schema 2 (1-5-5.md §2.4, §7).

Preserves every existing capability, provider, operation, arg and input verbatim.
Only ADDS schema-2 metadata fields at the capability-table level and REPLACES the
stale header with the machine-checked block. Idempotent: safe to re-run.
"""
import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "capabilities.toml.txt"

# Phase defaults. Keyword overrides below refine per-capability values.
PHASE_BASE = {
    "recon":          dict(risk="R1", noise="low",     mitre=["T1595", "T1590"],              provides=["asset:domain"],       cache_ttl=900, timeout=900,  platforms=["linux", "android", "windows"], privileges=["none"]),
    "surface":        dict(risk="R2", noise="medium",  mitre=["T1595.002"],                   provides=["asset:host"],        cache_ttl=300, timeout=900,  platforms=["linux", "android", "windows"], privileges=["none"]),
    "vulnerability":  dict(risk="R2", noise="medium",  mitre=["T1595", "T1190"],              provides=["finding:vuln"],       cache_ttl=0,   timeout=1800, platforms=["linux", "android", "windows"], privileges=["none"]),
    "payload":        dict(risk="R1", noise="silent",  mitre=["T1588.001", "T1587.001"],      provides=["artifact:payload"],   cache_ttl=0,   timeout=600,  platforms=["linux", "android", "windows"], privileges=["none"]),
    "escalation":     dict(risk="R3", noise="low",     mitre=["T1068"],                       provides=["finding:escalation"], cache_ttl=0,   timeout=600,  platforms=["linux", "windows"],          privileges=["user"]),
    "credentials":    dict(risk="R2", noise="medium",  mitre=["T1110", "T1003"],              provides=["credential:ref"],     cache_ttl=0,   timeout=3600, platforms=["linux", "android", "windows"], privileges=["none"]),
    "lateral":        dict(risk="R3", noise="low",     mitre=["T1021", "T1550"],              provides=["session"],            cache_ttl=0,   timeout=900,  platforms=["linux", "windows"],          privileges=["user"]),
    "persistence":    dict(risk="R2", noise="low",     mitre=["T1543", "T1547"],              provides=["persistence:record"], cache_ttl=0,   timeout=600,  platforms=["linux", "windows"],          privileges=["user"]),
    "exploitation":   dict(risk="R3", noise="high",    mitre=["T1190", "T1203"],              provides=["session"],            cache_ttl=0,   timeout=900,  platforms=["linux", "windows"],          privileges=["user"]),
    "wireless":       dict(risk="R2", noise="medium",  mitre=["T1552.004"],                   provides=["asset:ap"],          cache_ttl=0,   timeout=900,  platforms=["linux"],                    privileges=["none"]),
    "ctf":            dict(risk="R1", noise="silent",  mitre=["T1595"],                       provides=["flag"],              cache_ttl=0,   timeout=900,  platforms=["linux", "android", "windows"], privileges=["none"]),
}

# Keyword overrides: (substring in full id) -> dict of field overrides.
KEYWORD_OVERRIDES = [
    # Passive recon → R0 / silent
    (("email-harvest", "whois", "archive", "osint", "darkweb", "username", "certificate"), dict(risk="R0", noise="silent")),
    (("asn-map", "ip-intelligence", "code-leakage", "js-recon"), dict(risk="R0", noise="low")),
    # Noisy recon / surface
    (("bruteforce", "directory-bruteforce", "fuzz"), dict(risk="R2", noise="high")),
    (("crawl", "web-crawling"), dict(risk="R1", noise="medium")),
    # Credential attacks
    (("spray", "brute", "hash-crack", "kerberoast", "ntlm", "dump"), dict(risk="R3", noise="high")),
    # Exploitation / RCE / destructive
    (("rce", "exploit", "smb", "spooler", "deserialization", "log4shell", "token-impersonation", "dcshadow", "ntlm-relay"), dict(risk="R4", noise="screaming")),
    # Wireless active attacks
    (("deauth", "rogue", "evil-twin", "dos", "wps"), dict(risk="R3", noise="high")),
    # Cleanup/teardown/audit/report/binary-triage → safe, passive
    (("cleanup", "teardown", "reset", "audit", "report", "validate", "verification", "inventory", "triage", "map", "hunting", "score"), dict(risk="R0", noise="silent")),
]

# Catalog capability IDs backed by one of the 11 preserved real recon implementations.
NATIVE_IDS = {
    "recon.subdomain-discovery",
    "recon.certificate-intel",
    "recon.dns-mapping",
    "recon.network-mapping",
    "recon.cloud-exposure",
    "recon.metadata-extraction",
    "recon.tech-fingerprint",
    "surface.service-fingerprint",
}

NOISE_ORDER = {"silent": 0, "low": 1, "medium": 2, "high": 3, "screaming": 4}

HEADER = """# LOUTE CAPABILITY CATALOG — schema 2
# phases: 11 — capabilities: 241
# recon 22 · surface 22 · vulnerability 22 · payload 21 · escalation 24
# credentials 22 · lateral 26 · persistence 19 · exploitation 27 · wireless 21 · ctf 15
# Execution model: explicit argv vectors. Nothing here runs through a shell.
# Every capability carries risk/noise/MITRE/platform/privilege metadata (schema 2).
"""


def toml_str(v):
    return "'" + str(v).replace("'", "\\'") + "'"


def toml_arr(items):
    return "[" + ", ".join(toml_str(i) for i in items) + "]"


SHELL_META = set(";&|`$><*?()")


# Populated from tomllib before block processing: capability IDs whose arg
# literals carry shell metacharacters (payload/regex data, passed as single argv
# elements — never through a shell). Such capabilities declare shell_escape=true.
_SHELL_ESCAPE_IDS = set()


def compute_shell_escape_ids(raw_text):
    global _SHELL_ESCAPE_IDS
    data = tomllib.loads(raw_text)
    ids = set()
    for cap in data.get("capability", []):
        for provider in cap.get("provider", []):
            for op in provider.get("operation", []):
                for arg in op.get("args", []):
                    stripped = re.sub(r"\{[^}]*\}", "", arg)
                    if any(ch in SHELL_META for ch in stripped):
                        ids.add(cap["id"])
                        break
    _SHELL_ESCAPE_IDS = ids
    return ids


def block_needs_shell_escape(full_id):
    return full_id in _SHELL_ESCAPE_IDS


def derive(fields, full_id, first_op_output, needs_shell_escape):
    f = dict(fields)
    for keys, ov in KEYWORD_OVERRIDES:
        if any(k in full_id for k in keys):
            f.update(ov)
            break
    noise = f["noise"]
    opsec_safe = "true" if noise in ("silent", "low") else "false"
    reversible = "true" if full_id.startswith("persistence.") and not full_id.endswith("teardown") else "false"
    cleanup = toml_str("persistence.persistence-teardown") if reversible == "true" else toml_str("")
    native = "true" if full_id in NATIVE_IDS else "false"
    parser = "json" if first_op_output == "json" else "lines"
    artifacts = ["json", "text"] if first_op_output == "json" else ["text"]
    shell_escape = "true" if needs_shell_escape else "false"
    return f, noise, opsec_safe, reversible, cleanup, native, parser, artifacts, shell_escape


def main():
    text = CATALOG.read_text()
    # Split into capability blocks while keeping the prefix.
    compute_shell_escape_ids(text)
    parts = re.split(r"(?=\[\[capability\]\])", text)
    prefix = parts[0]
    blocks = parts[1:]
    if not blocks:
        print("ERROR: no capability blocks found", file=sys.stderr)
        sys.exit(1)

    out_blocks = []
    counts = {}
    total = 0
    for b in blocks:
        full_id_m = re.search(r"^id\s*=\s*'([^']+)'", b, re.M)
        phase_m = re.search(r"^phase\s*=\s*'([^']+)'", b, re.M)
        if not full_id_m or not phase_m:
            out_blocks.append(b)
            continue
        full_id = full_id_m.group(1)
        phase = phase_m.group(1)
        counts[phase] = counts.get(phase, 0) + 1
        total += 1

        # Already migrated? (idempotence)
        if re.search(r"^schema\s*=\s*2", b, re.M):
            out_blocks.append(b)
            continue

        # Determine first operation output mode for parser/artifacts.
        first_out = re.search(r"^output\s*=\s*'([^']+)'", b, re.M)
        first_op_output = first_out.group(1) if first_out else "lines"

        base = PHASE_BASE.get(phase, PHASE_BASE["recon"])
        needs_shell_escape = block_needs_shell_escape(full_id)
        f, noise, opsec_safe, reversible, cleanup, native, parser, artifacts, shell_escape = derive(base, full_id, first_op_output, needs_shell_escape)

        block = re.sub(r"^schema\s*=\s*1\s*$", "schema = 2", b, count=1, flags=re.M)
        if not re.search(r"^schema\s*=\s*2", block, re.M):
            # Insert schema right after id line.
            block = re.sub(r"(^id\s*=.*$)", r"\1\nschema = 2", block, count=1, flags=re.M)

        fields = (
            f"risk = {toml_str(f['risk'])}\n"
            f"noise = {toml_str(noise)}\n"
            f"mitre = {toml_arr(f['mitre'])}\n"
            f"platforms = {toml_arr(f['platforms'])}\n"
            f"privileges = {toml_arr(f['privileges'])}\n"
            f"network = true\n"
            f"requires = []\n"
            f"provides = {toml_arr(f['provides'])}\n"
            f"parser = {toml_str(parser)}\n"
            f"probe = {toml_arr([])}\n"
            f"timeout = {f['timeout']}\n"
            f"retry = 1\n"
            f"concurrency = 4\n"
            f"cache_ttl = {f['cache_ttl']}\n"
            f"artifacts = {toml_arr(artifacts)}\n"
            f"reversible = {reversible}\n"
            f"cleanup = {cleanup}\n"
            f"chains = []\n"
            f"opsec_safe = {opsec_safe}\n"
            f"native = {native}\n"
            f"shell_escape = {shell_escape}\n"
        )
        # Insert metadata after the summary line (still inside the capability table,
        # before the first [[capability.provider]] subtable).
        block = re.sub(r"(^summary\s*=.*$)", r"\1\n" + fields.rstrip("\n"), block, count=1, flags=re.M)
        out_blocks.append(block)

    # Replace the stale header block (everything before first [[capability]]).
    new_text = HEADER + "\n" + "".join(out_blocks)

    CATALOG.write_text(new_text)

    # Mirror to the shipped asset copy.
    asset = ROOT / "loute" / "assets" / "capabilities" / "capabilities.toml.txt"
    asset.parent.mkdir(parents=True, exist_ok=True)
    asset.write_text(new_text)

    print(f"Migrated {total} capabilities to schema 2.")
    print("Phase counts:", ", ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    print("Header normalized. Asset copy refreshed.")


if __name__ == "__main__":
    main()

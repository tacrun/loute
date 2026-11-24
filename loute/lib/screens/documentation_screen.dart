import 'package:flutter/material.dart';
import '../themes/midnight_hacker.dart';

/// Documentation Screen - structured manual detailing all features, modules, inputs, fallbacks, and expected outputs.
/// Production-grade documentation for LOUTE Phase 1 Reconnaissance System
class DocumentationScreen extends StatefulWidget {
  const DocumentationScreen({super.key});

  @override
  State<DocumentationScreen> createState() => _DocumentationScreenState();
}

class _DocumentationScreenState extends State<DocumentationScreen> {
  int _activeTopicIndex = 0;
  final List<_DocTopic> _topics = [
    _DocTopic(
      title: 'PHASE 1: RECONNAISSANCE',
      icon: Icons.radar_outlined,
      content: '''
### System Overview
Phase 1 (Reconnaissance) is a production-grade, non-intrusive discovery module that executes real-world network scanning operations. It coordinates simultaneous probing of DNS records, SSL certificates, cloud infrastructure, and host services without triggering alarms or causing service disruption.

**Execution Model:** All actions are asynchronous, high-concurrency, with genuine network I/O via Rust FFI. Output formats support HTML (interactive), JSON (programmatic), CSV (data analysis), and TXT (logs). This is NOT a simulation-all operations are authentic network queries against real targets.

---

### CATEGORY A: Subdomain Discovery (5 Actions)

### Action 1: DNS Brute-Force Discovery
**Purpose:** Concurrently resolve active subdomains by querying DNS nameservers with a comprehensive wordlist. Uses high-performance async resolver pools with rate limiting and intelligent backoff.

**Input Parameters:**
- `domain` (String, Required): Target domain (e.g., "google.com"). Input sanitization strips protocols, ports, paths.
- `wordlist_path` (String, Optional): File path to custom subdomain wordlist (one per line, comments as #lines).
- `concurrency` (Integer, default 100): Parallel query threads (range: 1-1000). Higher values scan faster but risk rate-limiting.

**Execution Flow:**
1. Input validation: Parse domain, validate FQDN format (e.g., must contain at least one dot), strip protocols/ports.
2. Wordlist loading: Load custom list or fall back to 50+ built-in high-entropy subdomains (www, api, dev, admin, etc.).
3. Async DNS resolution: Spawn concurrent `trust-dns-resolver` queries with 10s timeout per subdomain.
4. Result aggregation: Deduplicate by FQDN, track response times, classify as LIVE (resolved) or NXDOMAIN.
5. Output formatting: Generate HTML table with FQDN, resolved IPs, response times, and execution statistics.

**Expected Output Format:**
- **Success:** HTML table with columns: Subdomain | Resolved IP(s) | Response Time (ms) | Status
- **Stats Row:** "Tested: 150 subdomains | Live: 23 | Duration: 5.42s"
- **Empty Result:** Friendly message "[SAFE] No live subdomains discovered."

**Example Usage:**
- Input: domain="example.com", concurrency=100, wordlist_path=None
- Output: Discovers www.example.com (93.184.216.34), api.example.com (93.184.216.35), etc.

**Potential Error Codes:**
- `DNS_BRUTE_INVALID_DOMAIN`: Domain is empty or malformed after sanitization.
- `DNS_BRUTE_NXDOMAIN`: Base domain itself does not resolve (target unreachable).
- `DNS_BRUTE_TIMEOUT`: Individual queries exceeded 10s window (may indicate rate-limiting).
- `DNS_BRUTE_CONCURRENCY_LIMIT`: Concurrency parameter out of safe range (1-1000).
- `DNS_BRUTE_WORDLIST_INVALID`: Custom wordlist file not readable or missing.

---

### Action 2: Certificate Transparency Logs
**Purpose:** Query Certificate Transparency logs (crt.sh) to extract all SSL certificate records for a domain and its subdomains. This reveals historically issued certificates, including subdomains that may have evolved or been decomissioned.

**Input Parameters:**
- `domain` (String, Required): Target domain (e.g., "github.com").

**Execution Flow:**
1. Input sanitization: Strip protocols, schemas, ports.
2. API query: Issue HTTPS GET request to https://crt.sh/?q=%25.domain&output=json
3. JSON parsing: Extract `common_name` and `name_value` fields from certificate records.
4. Deduplication: Merge all domains into a deduplicated HashSet; strip wildcard prefixes (*.domain → domain).
5. Sorting: Sort by domain name alphabetically.
6. Output generation: Render HTML table with Domain, Issuer, and Certificate Validity Dates.

**Expected Output Format:**
- **Success:** HTML table with columns: Domain | Issuer | Valid Until
- **Stats Row:** "Target: github.com | Unique Domains Found: 142 | Duration: 2.18s"
- **Rate-Limited:** Error message with HTTP 429 and 60s retry recommendation.

**Example Usage:**
- Input: domain="github.com"
- Output: Extracts github.com, www.github.com, api.github.com, [numerous other subdomains discovered through certificate histories]

**Potential Error Codes:**
- `CT_LOGS_INVALID_DOMAIN`: Domain is empty after sanitization.
- `CT_LOGS_RATE_LIMIT`: crt.sh blocking client (HTTP 429). Wait 60 seconds.
- `CT_LOGS_PARSE_ERROR`: Response JSON malformed or unexpected structure.
- `CT_LOGS_NETWORK_ERROR`: Cannot reach crt.sh (network unreachable, DNS resolution failure).
- `CT_LOGS_HTTP_ERROR`: crt.sh returned error HTTP status (e.g., 500, 503).

---

### Action 3: DNS Zone Transfer (AXFR)
**Purpose:** Probe authoritative DNS nameservers for misconfigured AXFR (zone transfer) access. If enabled, exposes the complete zone file, including all DNS records, internal domains, and infrastructure patterns.

**Input Parameters:**
- `domain` (String, Required): Target domain (e.g., "example.org").
- `nameserver` (String, Optional): Specific nameserver IP or FQDN to target. If omitted, queries will be sent to all NS records.

**Execution Flow:**
1. Input validation: Validate domain and optional nameserver.
2. NS resolution: If nameserver not provided, resolve NS records for the domain.
3. TCP connection: For each nameserver, establish TCP socket to port 53.
4. AXFR attempt: Send genuine DNS zone transfer request (OpCode AXFR).
5. Response parsing: Collect zone records or capture "REFUSED" / "NOTAUTH" responses.
6. Output: Report vulnerabilities (successful transfers) and secure configurations (refused).

**Expected Output Format:**
- **Vulnerable:** "Nameserver ns1.example.com (198.51.100.1) - AXFR SUCCESSFUL. Zone records retrieved."
- **Secure:** "Nameserver ns1.example.com (198.51.100.1) - AXFR REFUSED (secure configuration)."
- **Stats:** "Tested: 4 nameservers | Vulnerable: 0 | Duration: 3.21s"

**Potential Error Codes:**
- `ZONE_TRANSFER_INVALID_DOMAIN`: Domain malformed.
- `ZONE_TRANSFER_NS_LOOKUP_FAILED`: Cannot resolve nameserver addresses.
- `ZONE_TRANSFER_NO_NAMESERVERS`: No NS records found for domain.
- `ZONE_TRANSFER_TCP_CLOSED`: TCP connection to nameserver port 53 refused.
- `ZONE_TRANSFER_TIMEOUT`: Query exceeded timeout window.

---

### Action 4: Reverse DNS (PTR) Scanning
**Purpose:** Mass resolve IP ranges to hostnames using reverse DNS (PTR) queries. Useful for mapping IP blocks to internal infrastructure or discovered subnets.

**Input Parameters:**
- `cidr` (String, Required): CIDR notation (e.g., "192.168.1.0/24" or single IPs "203.0.113.5").

**Execution Flow:**
1. CIDR parsing: Parse IP and prefix length; validate subnet.
2. Validation: Ensure IP count is reasonable (typically /24 and larger; cap at 256 per scan).
3. Reverse DNS queries: For each IP, issue PTR query in-addr.arpa zone.
4. Concurrency: Execute 50 parallel queries to avoid overwhelming resolvers.
5. Result collection: Map IP → hostname or mark as "No PTR" if unresolved.
6. Sorting: Sort results by IP address.

**Expected Output Format:**
- HTML table with columns: IP Address | Hostname (PTR)
- "192.168.1.1 → router.local"
- "192.168.1.100 → [NO PTR]"
- **Stats:** "CIDR: 192.168.1.0/24 | IPs Scanned: 256 | Resolved: 18 | Duration: 8.42s"

**Potential Error Codes:**
- `REVERSE_DNS_INVALID_CIDR`: CIDR format unparseable (e.g., "192.168.1.x/99").
- `REVERSE_DNS_INVALID_IP`: IP address out of valid range.
- `REVERSE_DNS_RANGE_TOO_LARGE`: CIDR results in >256 IPs; reduces scope.
- `REVERSE_DNS_TIMEOUT`: Resolver unresponsive for IP range.
- `REVERSE_DNS_NO_RESULTS`: No PTR records found (may be normal).

---

### Action 5: Wildcard DNS Detection
**Purpose:** Detect wildcard DNS records (* entries) to avoid massive false-positive counts during brute-forcing. Wildcard records return a fallback IP for any non-existent subdomain query, invalidating traditional brute-force techniques.

**Input Parameters:**
- `domain` (String, Required): Target domain (e.g., "example.com").

**Execution Flow:**
1. Random generation: Create 5 high-entropy random subdomains (e.g., "loute-wildcard-a1b2c3d4e5.example.com").
2. Query execution: Attempt DNS resolution for each random subdomain.
3. Analysis: If all random subdomains resolve to same IP(s), wildcard is active.
4. Output: Flag indicating presence/absence of wildcard and confidence level.

**Expected Output Format:**
- **Wildcard Detected:** "Domain uses wildcard records. Random query 'loute-wildcard-abc123.example.com' resolves to 10.0.0.1. Brute-forcing not recommended."
- **No Wildcard:** "No wildcard detected. DNS brute-forcing is safe and will provide accurate results."
- **Inconclusive:** "Mixed results; may have partial wildcard. Review manual."

**Potential Error Codes:**
- `WILDCARD_DETECT_INVALID_DOMAIN`: Domain malformed.
- `WILDCARD_DETECT_TIMEOUT`: Resolver unresponsive.
- `WILDCARD_DETECT_INCONCLUSIVE`: Partial or sporadic wildcard behavior detected.

---

### CATEGORY B: Cloud Reconnaissance (5 Actions)

### Action 6: Cloud Provider Detection
**Purpose:** Identify the cloud vendor (AWS, GCP, Azure, Cloudflare, etc.) hosting a target domain or IP by analyzing HTTP response headers, SSL certificates, CNAME records, and server signatures.

**Input Parameters:**
- `target` (String, Required): URL or IP address (e.g., "api.example.com" or "203.0.113.100").

**Execution Flow:**
1. Input sanitization: Add https:// if no protocol present.
2. HTTP request: Issue GET request; disable SSL verification for self-signed certs.
3. Header inspection: Check for cloud-specific headers (x-amz-*, cf-*, x-azure-*, gce-*, etc.).
4. SSL certificate analysis: Parse Subject, Issuer, CN fields for vendor keywords.
5. CNAME chain resolution: Follow CNAME records to identify infrastructure domain patterns.
6. Confidence scoring: Assign confidence score (10-100%) based on evidence strength.
7. Output: Vendor name, confidence, and evidence list.

**Expected Output Format:**
- "Detected Provider: Amazon Web Services (AWS) | Confidence: 95%"
- "Detection Signatures:"
  - "Server header: Amazon ALB"
  - "x-amz-request-id header present"
  - "SSL certificate issued by Amazon"
- **Alternative:** "Unknown / On-Premise - No cloud signatures detected."

**Potential Error Codes:**
- `CLOUD_PROVIDER_INVALID_TARGET`: Target URL/IP malformed.
- `CLOUD_PROVIDER_NETWORK_ERROR`: Cannot reach target (DNS failure, host unreachable).
- `CLOUD_PROVIDER_TIMEOUT`: HTTP request exceeded timeout (default 5s).
- `CLOUD_PROVIDER_NO_SIGNATURE`: No recognizable cloud signatures found (likely on-premises).

---

### Action 7: S3 Bucket Permissions Check
**Purpose:** Probe AWS S3 buckets for misconfigured public access permissions. Attempts LIST, READ, and WRITE operations to identify exposure levels.

**Input Parameters:**
- `bucket_name` (String, Required): S3 bucket name (e.g., "my-backups-2024").

**Execution Flow:**
1. Input sanitization: lowercase bucket name; validate DNS-compatible format.
2. Bucket URL construction: https://{bucket_name}.s3.amazonaws.com
3. LIST test: Issue GET request to root path to check anonymous list permissions.
4. READ test: If bucket is listable, attempt to read a test object (if one exists).
5. WRITE test: Attempt PUT request with a test file; auto-delete if successful.
6. Response classification: Map HTTP status codes to permission levels.
7. Output: Clear permission matrix (Public Read / Public Write / Private).

**Expected Output Format:**
- Bucket Exists: YES
- Read Permissions: [PUBLIC - LIST ALLOWED] or [PRIVATE - FORBIDDEN]
- Write Permissions: [PUBLIC - UPLOAD ALLOWED] or [PRIVATE - FORBIDDEN]
- **Vulnerable Finding:** "Bucket allows anonymous uploads. Critical exposure."

**Potential Error Codes:**
- `S3_INVALID_BUCKET_NAME`: Bucket name doesn't comply with S3 naming rules.
- `S3_BUCKET_NOT_FOUND`: HTTP 404 - Bucket does not exist or is in different region.
- `S3_FORBIDDEN`: HTTP 403 - Bucket exists but is private (SECURE).
- `S3_TIMEOUT`: Request exceeded timeout window (default 5s).
- `S3_UPLOAD_TEST_FAILED`: Cleanup of test file unsuccessful (rare).

---

### Action 8: Metadata Endpoint Probe
**Purpose:** Test for exposed cloud instance metadata servers (AWS IMDS, GCP computeMetadata, Azure metadata) that may leak credentials, instance info, or service account tokens.

**Input Parameters:**
- `target_ip` (String, Required): Target host IP or FQDN (e.g., "10.0.1.15" or "app.internal.example.com").

**Execution Flow:**
1. Input validation: Parse and validate IP or FQDN.
2. Metadata endpoint enumeration: Queue requests for standard metadata paths:
   - AWS IMDS: http://169.254.169.254/latest/meta-data/
   - GCP: http://metadata.google.internal/computeMetadata/v1/?recursive=true
   - Azure: http://169.254.169.254/metadata/instance?api-version=2021-02-01
3. Request execution: Issue HTTP GET with appropriate headers (X-Google-Metadata-Request, etc.).
4. Response analysis: Check for 200 OK responses; extract instance ID, role info, etc.
5. Output: Report accessible endpoints and leaked information.

**Expected Output Format:**
- "AWS IMDS: [ACCESSIBLE]"
  - "Instance ID: i-0a1b2c3d4e5f6g7h8"
  - "IAM Role: EC2-Instance-Role"
- "GCP Metadata: [UNREACHABLE] (expected on non-GCP hosts)"
- "Azure Metadata: [UNREACHABLE] (expected, requires auth header)"

**Potential Error Codes:**
- `METADATA_INVALID_TARGET`: Target IP/FQDN malformed.
- `METADATA_UNREACHABLE`: All metadata endpoints unreachable (SECURE, expected behavior).
- `METADATA_TIMEOUT`: Endpoint slow or unresponsive.
- `METADATA_PERMISSION_DENIED`: Endpoint returns 401/403 (SECURE).

---

### Action 9: Firebase Realtime Database Check
**Purpose:** Query Firebase Realtime Database REST endpoints to detect unprotected anonymous data exposure via insecure security rules.

**Input Parameters:**
- `project_id` (String, Required): Firebase project ID (e.g., "myapp-prod-12345").

**Execution Flow:**
1. Endpoint construction: https://{project_id}.firebaseio.com/.json
2. Anonymous request: Issue HTTP GET without authentication headers.
3. Response analysis: Check HTTP 200 (vulnerable) vs. 401/403 (secure).
4. Data extraction: If accessible, sample top-level keys (do not dump full DB).
5. Output: Report security posture and sample exposed data (if any).

**Expected Output Format:**
- **Secure:** "Firebase DB [PROTECTED] - Anonymous access denied (HTTP 401)."
- **Vulnerable:** "Firebase DB [EXPOSED] - Anonymous read access enabled! Sample data keys: users, messages, config, etc."
- **Not Found:** "Firebase instance not found (HTTP 404). Project ID may be incorrect."

**Potential Error Codes:**
- `FIREBASE_INVALID_PROJECT_ID`: Project ID format invalid.
- `FIREBASE_PROJECT_NOT_FOUND`: HTTP 404 - Project doesn't exist.
- `FIREBASE_PERMISSION_DENIED`: HTTP 401/403 (SECURE, expected).
- `FIREBASE_TIMEOUT`: Request exceeded timeout.
- `FIREBASE_MALFORMED_RESPONSE`: Unexpected response format.

---

### Action 10: CDN Detection
**Purpose:** Identify reverse proxy / CDN layers in front of a target server by analyzing HTTP response headers and SSL certificate details.

**Input Parameters:**
- `target_url` (String, Required): Target domain or URL (e.g., "cdn.example.com" or "https://example.com").

**Execution Flow:**
1. Input sanitization: Add https:// if needed.
2. HTTP request: Issue HEAD or GET request to capture headers.
3. Header matching: Search for CDN-specific headers:
   - Cloudflare: cf-ray, cf-request-id
   - AWS CloudFront: x-amz-cf-*, x-cache, via
   - Fastly: x-fastly-request-id, fastly-restarts
   - Akamai: x-akamai-transformed, akamai-origin-hop
   - Cloudflare, Bunny, etc.
4. SSL certificate inspection: Check SAN (Subject Alternative Name) for CDN domains.
5. CNAME chain analysis: Resolve CNAME records; identify CDN infrastructure domains.
6. Output: CDN vendor name and confidence score.

**Expected Output Format:**
- "Detected CDN: Cloudflare | Confidence: 99%"
- "Evidence: cf-ray header detected, SSL certificate issued by Cloudflare"
- **No CDN:** "Direct hosting - No CDN detected. Target connects directly to origin server."

**Potential Error Codes:**
- `CDN_INVALID_TARGET`: Target URL malformed.
- `CDN_NETWORK_ERROR`: Cannot reach target.
- `CDN_TIMEOUT`: HTTP request timeout.
- `CDN_UNSUPPORTED`: No CDN signature detected (direct routing).

---

### CATEGORY C: Host Auditing (1 Action)

### Action 11: Host Network Services Audit
**Purpose:** Query the local operating system for active listening network services and open ports. Provides visibility into what external clients can connect to on the scanning host.

**Input Parameters:**
- None (Local system operation).

**Execution Flow:**
1. OS detection: Determine operating system (Linux, macOS, Windows).
2. Command selection: Choose appropriate network inspection tool:
   - Linux/macOS: `ss -antp` (modern) or fallback `netstat -an`
   - Windows: `netstat -ano`
3. Execution: Run command with subprocess; capture stdout.
4. Parsing: Parse output to extract protocol, local address, foreign address, process state.
5. Filtering: Display top 30 active listening services; hide numerous TIME_WAIT entries.
6. HTML rendering: Render table with protocol, local:port, state, and process info if available.

**Expected Output Format:**
- HTML table with columns: Protocol | Local Address:Port | Foreign Address:Port | State
- Example rows:
  - "TCP | 0.0.0.0:22 | 0.0.0.0:* | LISTEN (sshd)"
  - "TCP | 127.0.0.1:5432 | 0.0.0.0:* | LISTEN (postgres)"
  - "UDP | 0.0.0.0:53 | * | LISTEN (named)"
- "Detected OS: LINUX | Services Listening: 12 | Execution Time: 0.34s"

**Potential Error Codes:**
- `NETWORK_AUDIT_PERMISSION_DENIED`: Insufficient privileges to run `ss`/`netstat` (requires elevated permissions on some systems).
- `NETWORK_AUDIT_COMMAND_NOT_FOUND`: `ss` and `netstat` not present in system PATH.
- `NETWORK_AUDIT_OS_UNSUPPORTED`: Operating system not supported.
- `NETWORK_AUDIT_PARSING_ERROR`: Output format unexpected or unparseable.

---

### Execution Statistics & Performance

All Phase 1 actions report:
- **Queries/Attempts:** Number of operations performed
- **Results/Discoveries:** Count of positive findings
- **Duration:** Wall-clock time in seconds
- **Concurrency:** Parallel operations (if applicable)
- **Error Count:** Failed queries or timeouts

Example: "DNS Brute-Force: Tested 150 subdomains | Live: 23 | Duration: 5.42s | Concurrency: 100"
''',
    ),
    _DocTopic(
      title: 'ERROR CODE REFERENCE',
      icon: Icons.error_outline,
      content: '''
### Phase 1 Error Codes - Production Debugging Guide

This section details all error codes encountered during Phase 1 Reconnaissance actions. Errors are organized by action, with severity levels, root causes, and remediation steps.

---

## DNS BRUTE-FORCE ERRORS

### DNS_BRUTE_INVALID_DOMAIN
**Severity:** CRITICAL | **HTTP Equivalent:** N/A
**Category:** DNS_BRUTE → Input Validation

**Description:** Domain input is empty, malformed, or blank after protocol/path stripping.

**Root Causes:**
1. User provided empty string or whitespace-only input
2. User provided URL with protocols and paths that stripped to nothing (e.g., "http:///")
3. Domain contains invalid characters (spaces, special symbols)

**Remediation:**
1. Verify the domain format: should be "domain.tld" (e.g., "google.com")
2. Do NOT include protocols (http://) or paths (/path) - only the domain
3. Check for accidental leading/trailing whitespace

**Example Correct Inputs:**
- "google.com" ✓
- "api.example.com" ✓
- "sub.domain.co.uk" ✓

**Example Incorrect Inputs:**
- "http://google.com" ✗ (include protocol)
- "google.com/" ✗ (include path)
- "google.com:8080" ✗ (include port)
- "" ✗ (empty)
- "google" ✗ (no TLD)

---

### DNS_BRUTE_NXDOMAIN
**Severity:** HIGH | **HTTP Equivalent:** N/A
**Category:** DNS_BRUTE → Nameserver Response

**Description:** The base domain itself does not resolve. The target domain is either invalid, expired, or offline.

**Root Causes:**
1. Domain is misspelled or does not exist
2. Domain has expired and is not pointing to active nameservers
3. Nameserver is unreachable due to network issues
4. Firewall blocking outbound DNS queries

**Remediation:**
1. Verify domain spelling: "dig {domain} @8.8.8.8"
2. Check domain expiration: "whois {domain}"
3. Verify public nameservers are set: "dig {domain} NS"
4. Test DNS from another network or using public resolver (8.8.8.8, 1.1.1.1)

**Debugging Command:**
```
dig google.com @8.8.8.8
# Should return ANSWER section with A records
```

---

### DNS_BRUTE_TIMEOUT
**Severity:** MEDIUM | **HTTP Equivalent:** 408 Request Timeout
**Category:** DNS_BRUTE → Query Execution

**Description:** Individual DNS queries exceeded the 10-second timeout window. May indicate the nameserver is slow, rate-limiting, or unreachable.

**Root Causes:**
1. Nameserver is rate-limiting concurrent requests
2. Network latency is high (high-latency, satellite, or congested links)
3. Firewall dropping packets after threshold
4. Nameserver is slow or overloaded
5. Concurrency setting too high, causing resolver pool saturation

**Remediation:**
1. Reduce concurrency setting (e.g., from 100 to 50 or 25)
2. Wait 60 seconds before retrying the same domain
3. Try from a different network (corporate vs. home ISP)
4. Check network connectivity: "ping 8.8.8.8"
5. Test with explicit nameserver: "dig {subdomain}.{domain} @{nameserver}"

**Example Fix:**
Original: `concurrency=100` → Too aggressive
Adjusted: `concurrency=50` → More conservative, avoids rate limits

---

### DNS_BRUTE_CONCURRENCY_LIMIT
**Severity:** LOW | **HTTP Equivalent:** N/A
**Category:** DNS_BRUTE → Input Validation

**Description:** Concurrency parameter is outside the safe range (1-1000). The system auto-corrects to a safe value.

**Root Causes:**
1. User specified concurrency > 1000 (too many parallel threads)
2. User specified concurrency ≤ 0 (invalid)

**Remediation:**
1. Set concurrency between 1 and 1000
2. Recommended values: 50-200 for most networks
3. Higher values (500-1000) risk rate-limiting; use only on high-speed networks
4. Lower values (10-50) conservative; use on slow or rate-limited networks

---

### DNS_BRUTE_WORDLIST_INVALID
**Severity:** HIGH | **HTTP Equivalent:** N/A
**Category:** DNS_BRUTE → Wordlist Loading

**Description:** Custom wordlist file cannot be opened or is unreadable.

**Root Causes:**
1. File path does not exist
2. Insufficient permissions to read file
3. File path contains typo or incorrect path separator
4. File is in use (locked by another process)

**Remediation:**
1. Verify file exists: "ls -la /path/to/wordlist.txt"
2. Check permissions: "chmod 644 /path/to/wordlist.txt"
3. Use absolute file path instead of relative
4. Ensure file is not open in editor or locked by another process

---

## CERTIFICATE TRANSPARENCY ERRORS

### CT_LOGS_INVALID_DOMAIN
**Severity:** CRITICAL | **HTTP Equivalent:** N/A
**Category:** CT_LOGS → Input Validation

**Description:** Domain input is empty or malformed after sanitization.

**Remediation:** Same as DNS_BRUTE_INVALID_DOMAIN. Ensure domain is format "domain.tld"

---

### CT_LOGS_RATE_LIMIT
**Severity:** MEDIUM | **HTTP Equivalent:** 429 Too Many Requests
**Category:** CT_LOGS → API Rate Limiting

**Description:** crt.sh server is rate-limiting client requests. Typically occurs after 3-5 rapid requests from the same IP.

**Root Causes:**
1. User ran CT_LOGS action multiple times in quick succession
2. Multiple clients on same IP are querying crt.sh
3. Shared corporate proxy limiting requests

**Remediation:**
1. Wait 60 seconds before retrying
2. Do not spam CT_LOGS queries for the same domain
3. If on shared network (corporate proxy), contact network admin

**Preventive Measures:**
- Space out CT_LOGS queries: minimum 30s between same domain
- Use different query targets if running batch scans

---

### CT_LOGS_PARSE_ERROR
**Severity:** HIGH | **HTTP Equivalent:** N/A
**Category:** CT_LOGS → JSON Parsing

**Description:** The JSON response from crt.sh is malformed or has unexpected structure.

**Root Causes:**
1. crt.sh returned HTML error page instead of JSON (server error)
2. Network corruption of response
3. crt.sh API endpoint changed

**Remediation:**
1. Verify crt.sh is online: visit https://crt.sh in browser
2. Try manual query: "curl https://crt.sh/?q=%25.domain.com&output=json"
3. If manual query works but LOUTE fails, report issue

---

### CT_LOGS_NETWORK_ERROR
**Severity:** HIGH | **HTTP Equivalent:** N/A
**Category:** CT_LOGS → Network I/O

**Description:** Cannot reach crt.sh server. Network is unreachable, DNS resolution failed, or firewall blocking.

**Root Causes:**
1. No internet connectivity
2. Firewall blocking HTTPS to crt.sh
3. DNS cannot resolve crt.sh hostname
4. crt.sh is temporarily down

**Remediation:**
1. Verify internet connectivity: "ping 8.8.8.8"
2. Test DNS: "nslookup crt.sh"
3. Test HTTPS connection: "curl https://crt.sh"
4. Check firewall / proxy settings

---

## DNS ZONE TRANSFER ERRORS

### ZONE_TRANSFER_INVALID_DOMAIN
**Severity:** CRITICAL
**Description:** Domain is empty or malformed. Same remediation as DNS_BRUTE_INVALID_DOMAIN.

---

### ZONE_TRANSFER_NS_LOOKUP_FAILED
**Severity:** HIGH | **Category:** ZONE_TRANSFER → NS Resolution
**Description:** Cannot resolve nameservers for the domain.

**Remediation:**
1. Verify domain exists: "dig {domain} NS"
2. Ensure base domain resolves: "dig {domain}"
3. Try explicit nameserver: "zone_transfer(domain, nameserver='ns1.example.com')"

---

### ZONE_TRANSFER_NO_NAMESERVERS
**Severity:** HIGH
**Description:** Domain has no NS records. May indicate domain is not configured or is expired.

**Remediation:** Check domain registration; verify nameservers are set via registrar.

---

### ZONE_TRANSFER_TCP_CLOSED
**Severity:** INFO | **Category:** ZONE_TRANSFER → TCP Connection
**Description:** TCP connection to nameserver port 53 was refused. This is SECURE behavior.

**Interpretation:** The nameserver correctly refuses AXFR requests. This is not an error; it's a positive security indicator.

---

### ZONE_TRANSFER_TIMEOUT
**Severity:** MEDIUM
**Description:** AXFR query exceeded timeout. Nameserver is slow or not responding.

**Remediation:** Retry with specific nameserver using shorter timeout.

---

## REVERSE DNS ERRORS

### REVERSE_DNS_INVALID_CIDR
**Severity:** CRITICAL | **Category:** REVERSE_DNS → Input Validation
**Description:** CIDR notation is malformed or unparseable.

**Examples of Invalid CIDR:**
- "192.168.1.999/24" (octet out of range)
- "192.168.1.0/33" (prefix > 32)
- "192.168.1.0/a" (non-numeric prefix)
- "300.0.0.0/24" (invalid IP)

**Corrected Examples:**
- "192.168.1.0/24" ✓
- "10.0.0.1/32" ✓ (single IP)
- "203.0.113.0/25" ✓

---

### REVERSE_DNS_RANGE_TOO_LARGE
**Severity:** HIGH | **Category:** REVERSE_DNS → Input Validation
**Description:** CIDR generates more than ~256 IPs. Scan would be too large and slow.

**Root Cause:** User specified too-broad subnet (e.g., /16 or /8).

**Remediation:** Split into smaller subnets:
- Instead of: "10.0.0.0/16" (65,536 IPs)
- Use: "10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24" (256 IPs each)

---

### REVERSE_DNS_TIMEOUT
**Severity:** MEDIUM
**Description:** PTR resolver unresponsive for one or more IPs in range.

**Remediation:** Retry scan or reduce range size.

---

### REVERSE_DNS_NO_RESULTS
**Severity:** INFO
**Description:** No PTR records found in scanned range. This is normal; not all IPs have PTR records.

**Interpretation:** This is not an error, just a finding. Many internal or temporary IPs lack PTR records.

---

## WILDCARD DETECTION ERRORS

### WILDCARD_DETECT_TIMEOUT
**Severity:** MEDIUM
**Description:** Nameserver unresponsive during wildcard test queries.

**Remediation:** Retry with lower concurrency or wait for nameserver to recover.

---

### WILDCARD_DETECT_INCONCLUSIVE
**Severity:** MEDIUM
**Description:** Test results are mixed or ambiguous. Wildcard detection cannot be confirmed or denied.

**Interpretation:** Exercise caution; DNS brute-force may produce false positives. Review results manually.

---

## CLOUD PROVIDER DETECTION ERRORS

### CLOUD_PROVIDER_INVALID_TARGET
**Severity:** CRITICAL
**Description:** Target URL/IP is malformed.

**Examples of Valid Inputs:**
- "api.example.com" ✓
- "192.168.1.100" ✓
- "https://example.com" ✓
- "example.com:8443" ✓

---

### CLOUD_PROVIDER_NETWORK_ERROR
**Severity:** HIGH
**Description:** Cannot reach target. Connection refused, host unreachable, or DNS failure.

**Remediation:**
1. Verify host online: "ping {target}"
2. Test connectivity: "curl https://{target}"
3. Check firewall rules

---

### CLOUD_PROVIDER_TIMEOUT
**Severity:** MEDIUM
**Description:** HTTP request exceeded timeout (default: 5 seconds). Target is slow or unresponsive.

**Remediation:** Retry; may indicate temporary network congestion.

---

### CLOUD_PROVIDER_NO_SIGNATURE
**Severity:** INFO
**Description:** No cloud provider signatures detected. Target likely on-premises or behind generic hosting.

**Interpretation:** This is not an error. Target is probably self-hosted or on non-major cloud providers.

---

## S3 BUCKET ERRORS

### S3_INVALID_BUCKET_NAME
**Severity:** CRITICAL
**Description:** Bucket name violates S3 naming rules (must be 3-63 chars, lowercase alphanumeric/hyphens, no consecutive hyphens, not IP-like).

---

### S3_BUCKET_NOT_FOUND
**Severity:** HIGH | **HTTP:** 404 Not Found
**Description:** Bucket does not exist or is in a different AWS region.

**Interpretation:** This is SECURE. The bucket name may be available for registration.

---

### S3_FORBIDDEN
**Severity:** INFO | **HTTP:** 403 Forbidden
**Description:** Bucket exists but anonymous access is denied. Expected behavior.

**Interpretation:** SECURE. Bucket is properly protected.

---

### S3_TIMEOUT
**Severity:** MEDIUM
**Description:** S3 endpoint unresponsive. Request exceeded 5-second timeout.

**Remediation:** Retry; may indicate AWS service degradation.

---

## METADATA ENDPOINT ERRORS

### METADATA_UNREACHABLE
**Severity:** INFO
**Description:** Metadata endpoints are not accessible. Expected on non-cloud hosts or properly configured instances.

**Interpretation:** SECURE. No metadata leakage detected.

---

### METADATA_TIMEOUT
**Severity:** MEDIUM
**Description:** Metadata endpoint slow or unresponsive.

### METADATA_PERMISSION_DENIED
**Severity:** INFO | **HTTP:** 401/403
**Description:** Metadata endpoint requires authentication. Expected behavior.

**Interpretation:** SECURE. Credentials are not exposed.

---

## FIREBASE ERRORS

### FIREBASE_PROJECT_NOT_FOUND
**Severity:** INFO | **HTTP:** 404
**Description:** Firebase project does not exist or project ID is incorrect.

**Interpretation:** Either project ID is wrong, or project is deleted/not deployed.

---

### FIREBASE_PERMISSION_DENIED
**Severity:** INFO | **HTTP:** 401/403
**Description:** Firebase database requires authentication. Expected and SECURE.

---

### FIREBASE_TIMEOUT
**Severity:** MEDIUM
**Description:** Firebase endpoint unresponsive.

---

## CDN DETECTION ERRORS

### CDN_NETWORK_ERROR
**Severity:** HIGH
**Description:** Cannot reach CDN endpoint.

---

### CDN_UNSUPPORTED
**Severity:** INFO
**Description:** No CDN signatures detected. Direct hosting or very obscure CDN.

**Interpretation:** Not an error. Target connects directly to origin.

---

## HOST NETWORK AUDIT ERRORS

### NETWORK_AUDIT_PERMISSION_DENIED
**Severity:** MEDIUM
**Description:** Insufficient privileges to query host port tables via `ss`/`netstat`.

**Remediation:**
1. Run LOUTE with `sudo`: "sudo {loute_command}"
2. On Linux, add user to group: "sudo usermod -aG root {username}"
3. On macOS/Windows, run as Administrator

---

### NETWORK_AUDIT_COMMAND_NOT_FOUND
**Severity:** HIGH
**Description:** Required commands (`ss`, `netstat`) not found in system PATH.

**Remediation:**
1. On Linux (Debian/Ubuntu): "sudo apt install net-tools iproute2"
2. On macOS: "brew install net-tools" (or use native `netstat`)
3. Verify installation: "which ss" or "which netstat"

---

### NETWORK_AUDIT_OS_UNSUPPORTED
**Severity:** HIGH
**Description:** Operating system is not supported (typically very old or exotic OSes).

---

### NETWORK_AUDIT_PARSING_ERROR
**Severity:** HIGH
**Description:** Command output format unexpected. May indicate OS-specific variations.

**Remediation:** Report issue with OS version and `ss`/`netstat` output format.

---

## Cross-Cutting Error Resolution Strategies

### Strategy 1: Network Connectivity Check
If ANY action fails, first verify network:
```
ping 8.8.8.8
nslookup google.com
curl https://example.com
```

### Strategy 2: DNS Resolution Test
For DNS-related errors:
```
dig {domain} @8.8.8.8
dig {domain} @1.1.1.1
dig {domain} @{custom-nameserver}
```

### Strategy 3: Rate Limiting Mitigation
If rate-limit errors occur:
1. Reduce concurrency (if applicable)
2. Wait 60-300 seconds
3. Retry with conservative settings
4. Use different source IP (VPN, proxy)

### Strategy 4: Timeout Mitigation
If timeout errors occur:
1. Reduce concurrency
2. Increase timeout window in settings
3. Reduce query volume per batch
4. Try from lower-latency network

---

## Error Code Severity Scale

| Severity | Meaning | Action |
|----------|---------|--------|
| **CRITICAL** | Invalid input or configuration; action cannot proceed | Fix input and retry |
| **HIGH** | Legitimate error (network, permission); may indicate real issue | Troubleshoot; may indicate vulnerability |
| **MEDIUM** | Transient error (timeout, rate limit); may succeed on retry | Retry after short delay |
| **LOW** | Minor issue; action may proceed with reduced functionality | Proceed or ignore |
| **INFO** | Not an error; informational finding | Review result; may be secure |

'''
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MidnightHacker.background,
      body: Row(
        children: [
          // Left Sidebar Navigation within Documentation
          Container(
            width: 240,
            decoration: const BoxDecoration(
              border: Border(right: MidnightHacker.greenBorder),
            ),
            child: ListView.builder(
              itemCount: _topics.length,
              itemBuilder: (context, index) {
                final topic = _topics[index];
                final active = index == _activeTopicIndex;
                return InkWell(
                  onTap: () => setState(() => _activeTopicIndex = index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        left: active ? MidnightHacker.greenBorderThick : const BorderSide(color: Colors.transparent, width: 2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          topic.icon,
                          color: active ? MidnightHacker.positive : MidnightHacker.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            topic.title,
                            style: MidnightHacker.monoSmall.copyWith(
                              color: active ? MidnightHacker.primary : MidnightHacker.dimGreen,
                              fontWeight: active ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Central content displaying selected markdown document
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _topics[_activeTopicIndex].title,
                      style: MidnightHacker.headingLarge.copyWith(fontSize: 28),
                    ),
                    const Divider(height: 32),
                    _renderBodyText(_topics[_activeTopicIndex].content),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _parseMarkdownLine(String line, TextStyle defaultStyle) {
    final parts = line.split('**');
    if (parts.length <= 1) {
      return Text(line, style: defaultStyle);
    }
    
    final List<TextSpan> spans = [];
    for (int i = 0; i < parts.length; i++) {
      final isBold = i % 2 == 1;
      spans.add(
        TextSpan(
          text: parts[i],
          style: isBold
              ? defaultStyle.copyWith(fontWeight: FontWeight.bold, color: MidnightHacker.primary)
              : defaultStyle,
        ),
      );
    }
    
    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _renderBodyText(String rawText) {
    final sections = rawText.split('### ');
    final List<Widget> sectionWidgets = [];

    if (sections.isNotEmpty && sections[0].trim().isNotEmpty) {
      sectionWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _parseMarkdownLine(sections[0].trim(), MidnightHacker.monoStyle.copyWith(color: MidnightHacker.dimGreen)),
        ),
      );
    }

    for (int i = 1; i < sections.length; i++) {
      final sectionContent = sections[i];
      final lines = sectionContent.split('\n');
      if (lines.isEmpty) continue;

      final title = lines[0].trim();
      final bodyLines = lines.skip(1).toList();

      sectionWidgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          width: double.infinity,
          decoration: BoxDecoration(
            color: MidnightHacker.background,
            border: Border.all(color: MidnightHacker.dimGreen, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Styled Header Card segment
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: MidnightHacker.background,
                  border: Border(bottom: BorderSide(color: MidnightHacker.dimGreen, width: 1)),
                ),
                child: Text(
                  title.toUpperCase(),
                  style: MidnightHacker.monoStyle.copyWith(
                    color: MidnightHacker.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              // Body segment
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: bodyLines.map((line) {
                    if (line.startsWith('1. ') || line.startsWith('2. ') || line.startsWith('3. ') || line.startsWith('4. ') || line.startsWith('5. ')) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 4),
                        child: _parseMarkdownLine(line, MidnightHacker.monoStyle.copyWith(fontWeight: FontWeight.bold)),
                      );
                    } else if (line.startsWith('   - ')) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 4),
                        child: _parseMarkdownLine(line, MidnightHacker.monoStyle.copyWith(color: MidnightHacker.primary)),
                      );
                    } else if (line.trim().isEmpty) {
                      return const SizedBox(height: 6);
                    } else {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _parseMarkdownLine(line, MidnightHacker.monoStyle.copyWith(color: MidnightHacker.dimGreen)),
                      );
                    }
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sectionWidgets,
    );
  }
}

class _DocTopic {
  final String title;
  final IconData icon;
  final String content;

  _DocTopic({required this.title, required this.icon, required this.content});
}

#!/usr/bin/env python3
"""Secret scanner — layer 2 of the triple-check before any GitHub upload.

Scans the working tree for:
  L1  sensitive filenames (.env, *.pem, credentials, private keys, ...)
  L2  known secret patterns (AWS keys, GitHub/Slack/Stripe tokens, private
      key headers, api_key/password assignments, credentialed URLs, ...)
  L3  high-entropy strings that look like generated secrets

Usage:  python3 scripts/scan-secrets.py [path]
Exit 0 = clean, 1 = findings (DO NOT UPLOAD), 2 = scanner error.

Stdlib only — runs anywhere.
"""
import os
import re
import sys
import math
from collections import Counter

# ---------------------------------------------------------------- filenames
# Exact names or suffixes that must never be uploaded.
SENSITIVE_NAMES = {
    ".env", ".env.local", ".env.production", ".env.development",
    "credentials.json", "service-account.json", "secrets.yaml", "secrets.yml",
    "secrets.json", ".npmrc", ".pypirc", "id_rsa", "id_ed25519", "id_dsa",
}
SENSITIVE_SUFFIXES = (
    ".pem", ".key", ".p12", ".pfx", ".jks", ".keystore",
    "_rsa", "_ed25519", "_dsa",
)
# Substring matches on the *basename* (kept narrow to avoid doc false-positives).
SENSITIVE_SUBSTRINGS = ("credential", "service_account", "service-account")

# ---------------------------------------------------------------- patterns
# (rule name, regex). Keep specific; placeholders are filtered below.
PATTERNS = [
    ("AWS access key", re.compile(r"AKIA[0-9A-Z]{16}")),
    ("AWS secret assignment",
     re.compile(r"(?i)aws[_-]?secret[_-]?access[_-]?key[\"']?\s*[:=]\s*[\"'][A-Za-z0-9/+=]{20,}[\"']")),
    ("GitHub token",
     re.compile(r"gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}")),
    ("Slack token", re.compile(r"xox[baprs]-[A-Za-z0-9-]{10,}")),
    ("Stripe key", re.compile(r"s[kr]_live_[A-Za-z0-9]{16,}|s[kr]_test_[A-Za-z0-9]{16,}")),
    ("Private key header",
     re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----")),
    ("API key assignment",
     re.compile(r"(?i)(api[_-]?key|apikey|access[_-]?token|auth[_-]?token|"
                r"client[_-]?secret|secret[_-]?key)[\"']?\s*[:=]\s*[\"'][^\"']{8,}[\"']")),
    ("Password assignment",
     re.compile(r"(?i)(password|passwd|pwd)[\"']?\s*[:=]\s*[\"'][^\"']{4,}[\"']")),
    ("Bearer token", re.compile(r"(?i)bearer\s+[A-Za-z0-9\-._~+/]{20,}")),
    ("URL with embedded credentials",
     re.compile(r"https?://[^/\s:()\"']+:[^/\s@()\"']+@[^\s/()\"']+")),
    ("Auth surrogate", re.compile(r"hsurr:[A-Za-z0-9]+")),
]

# Values that are obviously placeholders, not secrets.
PLACEHOLDERS = re.compile(
    r"(?i)^(xxx+|\*+|changeme|password123|your[-_ ]?(api[-_ ]?key|secret|token|password)"
    r"|example|test|test123|null|none|undefined|todo|placeholder|"
    r"\$\{[^}]*\}|%[A-Z_]+%|<[^>]*>)$"
)

# ------------------------------------------------------------- exclusions
SKIP_DIRS = {".git", ".godot", ".venv", "__pycache__", "node_modules",
             "test-results", ".idea", ".vscode"}
# The scanner documents secrets, so it must not flag its own rule text.
SELF = os.path.basename(__file__)

# High-entropy detection tuning.
ENTROPY_MIN_LEN = 24
ENTROPY_THRESHOLD = 4.5
ENTROPY_TOKEN = re.compile(r"[A-Za-z0-9+/=_-]{24,}")


def shannon(s: str) -> float:
    counts = Counter(s)
    n = len(s)
    return -sum((c / n) * math.log2(c / n) for c in counts.values())


def looks_placeholder(value: str) -> bool:
    v = value.strip().strip("\"'")
    return bool(PLACEHOLDERS.match(v)) or "os.environ" in v or "getenv" in v


def scan_file(path: str):
    findings = []
    try:
        with open(path, "r", encoding="utf-8", errors="strict") as f:
            text = f.read()
    except (UnicodeDecodeError, OSError):
        return findings  # binary or unreadable: skip
    for i, line in enumerate(text.splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            pass  # comments still scanned: secrets hide in commented code
        for name, rx in PATTERNS:
            for m in rx.finditer(line):
                hit = m.group(0)
                # For assignment rules, extract the value and allow placeholders.
                if name in ("API key assignment", "Password assignment",
                            "AWS secret assignment"):
                    val = re.split(r"[:=]", hit, maxsplit=1)[-1]
                    if looks_placeholder(val):
                        continue
                findings.append((path, i, name, hit[:60]))
        for tok in ENTROPY_TOKEN.finditer(line):
            t = tok.group(0).strip("=_-")
            if len(t) >= ENTROPY_MIN_LEN and shannon(t) >= ENTROPY_THRESHOLD:
                if re.fullmatch(r"[0-9a-fA-F-]{32,}", t):
                    continue  # uuid / hash, not a secret
                findings.append((path, i, "High-entropy string (review manually)",
                                 t[:40] + "..."))
    return findings


def main() -> int:
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    findings = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fn in filenames:
            base = os.path.basename(fn)
            low = base.lower()
            if base == SELF:
                continue
            if (low in SENSITIVE_NAMES
                    or low.endswith(SENSITIVE_SUFFIXES)
                    or any(s in low for s in SENSITIVE_SUBSTRINGS)):
                findings.append((os.path.join(dirpath, fn), 0,
                                 "Sensitive filename", base))
                continue
            findings.extend(scan_file(os.path.join(dirpath, fn)))
    if findings:
        print("SECRET SCAN: %d finding(s) — DO NOT UPLOAD\n" % len(findings))
        for path, line, rule, snippet in findings:
            loc = "%s:%d" % (path, line) if line else path
            print("  [%s] %s\n      %s" % (rule, loc, snippet))
        return 1
    print("SECRET SCAN: clean — no secrets detected.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

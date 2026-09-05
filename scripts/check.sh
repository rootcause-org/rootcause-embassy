#!/usr/bin/env bash
# Mechanical checks for the contract hub. No dependencies beyond bash + python3.
#
#   fixture bytes    every fixtures/**/*.json ends without a trailing newline;
#                    signing_vectors.json and fixtures/README.md end with one
#   signing vectors  every bodies/query_strings entry recomputed from the file bytes
#   style            no section cross-references (AGENTS.md bans them)
#   links            every relative markdown link + #anchor resolves
#   counts           a decision count in README.md matches decisions.md
#
# Exits non-zero with one line per failure.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 - "$ROOT" <<'PY'
import hashlib
import hmac
import json
import os
import re
import sys

root = sys.argv[1]
failures = []


def fail(msg):
    failures.append(msg)


def rel(path):
    return os.path.relpath(path, root)


def md_files():
    out = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in {".git", ".tmp", ".claude"}]
        for name in sorted(filenames):
            if name.endswith(".md"):
                out.append(os.path.join(dirpath, name))
    return sorted(out)


# --- fixture bytes ---------------------------------------------------------
fixtures = os.path.join(root, "fixtures")
for dirpath, dirnames, filenames in os.walk(fixtures):
    for name in sorted(filenames):
        path = os.path.join(dirpath, name)
        data = open(path, "rb").read()
        if not data:
            fail(f"{rel(path)}: empty file")
            continue
        newline_expected = name in ("signing_vectors.json", "README.md")
        if name.endswith(".json") or newline_expected:
            ends_nl = data.endswith(b"\n")
            if newline_expected and not ends_nl:
                fail(f"{rel(path)}: must end WITH a trailing newline")
            elif not newline_expected and ends_nl:
                fail(f"{rel(path)}: must end WITHOUT a trailing newline (it breaks the signature)")

# --- signing vectors -------------------------------------------------------
vectors_path = os.path.join(fixtures, "signing_vectors.json")
vectors = json.load(open(vectors_path))


def sig(secret, payload):
    return "sha256=" + hmac.new(secret.encode(), payload, hashlib.sha256).hexdigest()


for entry in vectors.get("bodies", []):
    name = entry.get("name", "?")
    path = os.path.join(fixtures, entry["file"])
    if not os.path.exists(path):
        fail(f"signing_vectors bodies[{name}]: missing file {entry['file']}")
        continue
    body = open(path, "rb").read()
    if len(body) != entry["body_bytes"]:
        fail(f"signing_vectors bodies[{name}]: body_bytes {entry['body_bytes']} != actual {len(body)}")
    actual_sha = hashlib.sha256(body).hexdigest()
    if actual_sha != entry["body_sha256"]:
        fail(f"signing_vectors bodies[{name}]: body_sha256 mismatch (actual {actual_sha})")
    actual_sig = sig(entry["secret"], body)
    if actual_sig != entry["signature"]:
        fail(f"signing_vectors bodies[{name}]: signature mismatch (actual {actual_sig})")

for entry in vectors.get("query_strings", []):
    name = entry.get("name", "?")
    raw = entry["raw_query"]
    path = os.path.join(fixtures, entry["file"]) if entry.get("file") else None
    if path:
        if not os.path.exists(path):
            fail(f"signing_vectors query_strings[{name}]: missing file {entry['file']}")
        else:
            on_disk = open(path, "rb").read().decode()
            if on_disk != raw:
                fail(f"signing_vectors query_strings[{name}]: {entry['file']} bytes != raw_query")
    actual_sig = sig(entry["secret"], raw.encode())
    if actual_sig != entry["signature"]:
        fail(f"signing_vectors query_strings[{name}]: signature mismatch (actual {actual_sig})")

# --- style: no section cross-references ------------------------------------
for path in md_files():
    if os.path.basename(path) == "AGENTS.md":
        continue
    for i, line in enumerate(open(path, encoding="utf-8"), 1):
        if re.search(r"§\s*[0-9]", line):
            fail(f"{rel(path)}:{i}: section cross-reference (§) — name the section instead")

# --- links and anchors -----------------------------------------------------
FENCE = re.compile(r"^\s*(```|~~~)")
LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")


def strip_inline(text):
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = text.replace("`", "")
    text = re.sub(r"\*\*|\*|__", "", text)
    return text


def slugs_of(path):
    found = {}
    in_fence = False
    for line in open(path, encoding="utf-8"):
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        m = HEADING.match(line)
        if not m:
            continue
        text = strip_inline(m.group(2))
        # GitHub's slugger: drop punctuation, lowercase, then every remaining
        # space becomes a hyphen. Runs of spaces are NOT collapsed, so a heading
        # with " — " yields a double hyphen.
        slug = re.sub(r"[^\w\s-]", "", text, flags=re.UNICODE).strip().lower()
        slug = slug.replace(" ", "-")
        n = found.get(slug, 0)
        found[slug] = n + 1
    out = set()
    for slug, count in found.items():
        out.add(slug)
        for n in range(1, count):
            out.add(f"{slug}-{n}")
    return out


slug_cache = {}


def slugs_cached(path):
    if path not in slug_cache:
        slug_cache[path] = slugs_of(path)
    return slug_cache[path]


for path in md_files():
    in_fence = False
    for i, line in enumerate(open(path, encoding="utf-8"), 1):
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        for target in LINK.findall(line):
            if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", target) or target.startswith("//"):
                continue
            file_part, _, anchor = target.partition("#")
            if file_part:
                dest = os.path.normpath(os.path.join(os.path.dirname(path), file_part))
                if not os.path.exists(dest):
                    fail(f"{rel(path)}:{i}: link target does not exist: {file_part}")
                    continue
            else:
                dest = path
            if not anchor:
                continue
            if os.path.isdir(dest) or not dest.endswith(".md"):
                fail(f"{rel(path)}:{i}: anchor on a non-markdown target: {target}")
                continue
            if anchor.lower() not in slugs_cached(dest):
                fail(f"{rel(path)}:{i}: anchor not found in {rel(dest)}: #{anchor}")

# --- decision count --------------------------------------------------------
decisions = open(os.path.join(root, "decisions.md"), encoding="utf-8").read()
count = len(re.findall(r"^## [0-9]+\.", decisions, flags=re.M))
readme = open(os.path.join(root, "README.md"), encoding="utf-8").read()
m = re.search(r"the (\d+) pinned decisions", readme)
if m and int(m.group(1)) != count:
    fail(f"README.md: says {m.group(1)} pinned decisions, decisions.md has {count}")

for line in failures:
    print(f"FAIL {line}")
print(f"{'FAILED' if failures else 'OK'}: {len(failures)} failure(s)")
sys.exit(1 if failures else 0)
PY

"""Check every Markdown file in the repository for broken links and anchors."""
# Also reports docs/ links that leave docs/ (GitBook cannot follow them) and GitHub alerts in docs/ (GitBook shows them
# raw; use {% hint %}).
#
# Usage: python3 script/docs/check_links.py   (from the repository root; exits 1 on any problem)
import os
import re
import sys

LINK = re.compile(r"\]\(([^)\s]+?)(?:\s+\"[^\"]*\")?\)")
ATTR = re.compile(r'(?:url|href)="([^"]+)"')
FENCE = re.compile(r"^```.*?^```", re.S | re.M)
SKIP = {".git", ".claude", "lib", "node_modules", "bin", "_site"}


def slug(heading):
    """Return GitHub's and GitBook's anchor for a heading."""
    text = re.sub(r"`", "", heading.strip().lower())
    text = re.sub(r"[^\w\- ]", "", text)
    return text.replace(" ", "-")


def markdown_files():
    """Yield every Markdown file in the repository, outside SKIP directories."""
    for root, dirs, files in os.walk("."):
        dirs[:] = [d for d in dirs if d not in SKIP]
        for name in files:
            if name.endswith(".md"):
                yield os.path.normpath(os.path.join(root, name))


anchor_cache = {}


def anchors(path):
    """Return the heading anchors of *path* (cached)."""
    if path not in anchor_cache:
        text = FENCE.sub("", open(path, encoding="utf-8").read())
        seen, found = {}, set()
        for heading in re.findall(r"^#{1,6} (.+)$", text, re.M):
            base = slug(heading)
            count = seen.get(base, 0)
            found.add(base if count == 0 else f"{base}-{count}")
            seen[base] = count + 1
        anchor_cache[path] = found
    return anchor_cache[path]


broken, bad_anchor, leaving, alerts = [], [], [], []
files = sorted(markdown_files())
for path in files:
    body = FENCE.sub("", open(path, encoding="utf-8").read())
    in_docs = path.startswith("docs/")
    if in_docs and re.search(r"^> \[!", body, re.M):
        alerts.append(path)
    targets = [m.group(1) for m in LINK.finditer(body)] + [m.group(1) for m in ATTR.finditer(body)]
    for target in targets:
        if re.match(r"^[a-z]+:", target):
            continue
        file_part, _, anchor = target.partition("#")
        dest = path if not file_part else os.path.normpath(os.path.join(os.path.dirname(path), file_part))
        if file_part and not os.path.exists(dest):
            broken.append(f"{path} -> {target}")
            continue
        if in_docs and file_part and not dest.startswith("docs"):
            leaving.append(f"{path} -> {target}")
        if anchor and dest.endswith(".md") and anchor not in anchors(dest):
            bad_anchor.append(f"{path} -> {target}")

print("markdown files:", len(files))
problems = 0
for label, items in (("broken links", broken), ("bad anchors", bad_anchor),
                     ("docs/ links leaving docs/", leaving), ("GitHub alerts in docs/", alerts)):
    print(f"{label}: {len(items)}")
    for item in items:
        print("   ", item)
    problems += len(items)
sys.exit(1 if problems else 0)

"""Checks the docs navigation: every page is listed in docs/SUMMARY.md and linked from its section README.md, every
SUMMARY entry exists, and every redirect in docs/.gitbook.yaml points at a page that exists without shadowing one.

Usage: python3 script/docs/check_nav.py   (from the repository root; exits 1 on any problem)
"""
import os
import re
import sys

import yaml

DOCS = "docs"
LINK = re.compile(r'(?:\]\(|href="|url=")([^)"#\s]+\.md)')


def linked_pages(readme):
    base = os.path.dirname(readme)
    text = open(os.path.join(DOCS, readme), encoding="utf-8").read()
    return {os.path.normpath(os.path.join(base, target)) for target in LINK.findall(text)}


pages = {os.path.relpath(os.path.join(root, name), DOCS)
         for root, _, files in os.walk(DOCS) for name in files
         if name.endswith(".md") and name != "SUMMARY.md"}
problems = []

summary = linked_pages("SUMMARY.md")
problems += [f"not in SUMMARY.md: {page}" for page in sorted(pages - summary)]
problems += [f"SUMMARY.md entry missing on disk: {page}" for page in sorted(summary - pages)]

for page in sorted(pages):
    section = page.split(os.sep)[0]
    readme = os.path.join(section, "README.md")
    if os.sep in page and page != readme and page not in linked_pages(readme):
        problems.append(f"not linked from {readme}: {page}")

redirects = (yaml.safe_load(open(os.path.join(DOCS, ".gitbook.yaml"), encoding="utf-8")) or {}).get("redirects") or {}
for source, target in redirects.items():
    if target not in pages:
        problems.append(f"redirect {source} -> {target}: target missing")
    if f"{source}.md" in pages or os.path.join(source, "README.md") in pages:
        problems.append(f"redirect {source} shadows a live page")

print(f"{len(pages)} pages, {len(redirects)} redirects")
for problem in problems:
    print("   ", problem)
sys.exit(1 if problems else 0)

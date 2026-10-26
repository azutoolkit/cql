"""Lint GitBook markup in docs pages: frontmatter, block tags, nesting, targets.

Usage: python3 script/docs/gitbook_lint.py [FILE.md ...]   (default: every page under docs/; run from the repository
root; exits 1 on any problem). The rules are in .claude/docs-style-guide.md.
"""
import os
import re
import sys

import yaml

LANDING = {"docs/README.md", "docs/installation.md", "docs/tutorials/README.md", "docs/how-to/README.md",
           "docs/reference/README.md", "docs/explanation/README.md", "docs/resources/README.md",
           "docs/how-to/postgres-native/README.md"}
BLOCKS = {"hint", "tabs", "tab", "stepper", "step", "code", "content-ref"}
PARENT = {"tab": "tabs", "step": "stepper"}
NO_SELF_NEST = {"tabs", "stepper", "code", "hint", "content-ref"}
TAG = re.compile(r"\{%\s*(end)?([a-z-]+)\b([^%]*)%\}")
FENCE_LINE = re.compile(r"^\s*(```+|~~~+)")


def pages(args):
    if args:
        return args
    out = []
    for root, _, files in os.walk("docs"):
        out += [os.path.join(root, f) for f in files if f.endswith(".md") and f != "SUMMARY.md"]
    return sorted(out)


def lint(path):
    errors = []
    text = open(path, encoding="utf-8").read()
    rel = os.path.normpath(path)

    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end < 0:
            errors.append("frontmatter not closed")
            body, raw = text, ""
        else:
            raw, body = text[4:end], text[end + 5:]
            try:
                meta = yaml.safe_load(raw) or {}
            except yaml.YAMLError as exc:
                errors.append(f"frontmatter YAML: {exc}".splitlines()[0])
                meta = {}
            desc = meta.get("description")
            if not isinstance(desc, str) or not desc.strip():
                errors.append("frontmatter: missing description")
            elif not re.search(r'^description:\s*["\']', raw, re.M):
                errors.append("frontmatter: description must be quoted")
            if "icon" in meta and rel not in LANDING:
                errors.append("frontmatter: icon only on landing pages")
            extra = set(meta) - {"description", "icon"}
            if extra:
                errors.append(f"frontmatter: unexpected keys {sorted(extra)}")
    else:
        errors.append("missing frontmatter")
        body = text

    stack, in_fence, details_depth = [], False, 0
    code_fences = []  # fenced-block count per open {% code %}
    for lineno, line in enumerate(body.splitlines(), 1):
        if FENCE_LINE.match(line):
            if not in_fence and stack and stack[-1][0] == "code":
                code_fences[-1] += 1
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        if re.match(r"^\s*<details", line):
            if any(name in ("tabs", "stepper") for name, _ in stack):
                errors.append(f"{lineno}: <details> inside tabs or stepper")
            details_depth += 1
        if re.match(r"^\s*</details>", line):
            details_depth -= 1
        for match in TAG.finditer(line):
            closing, name, attrs = match.group(1), match.group(2), match.group(3)
            if name not in BLOCKS:
                continue
            if closing:
                if not stack or stack[-1][0] != name:
                    errors.append(f"{lineno}: end{name} without matching {name}")
                else:
                    stack.pop()
                    if name == "code" and code_fences.pop() != 1:
                        errors.append(f"{lineno}: code block must wrap exactly one fenced block")
                continue
            if name in PARENT and (not stack or stack[-1][0] != PARENT[name]):
                errors.append(f"{lineno}: {name} outside {PARENT[name]}")
            if name in NO_SELF_NEST and any(n == name for n, _ in stack):
                errors.append(f"{lineno}: {name} nested inside {name}")
            if name == "tabs" and any(n == "stepper" for n, _ in stack):
                pass  # allowed
            if name == "code":
                code_fences.append(0)
                if 'title="' not in attrs:
                    errors.append(f"{lineno}: code block without title")
            if name == "hint" and not re.search(r'style="(info|success|warning|danger)"', attrs):
                errors.append(f"{lineno}: hint needs style info|success|warning|danger")
            if name == "tab" and 'title="' not in attrs:
                errors.append(f"{lineno}: tab without title")
            if name == "content-ref":
                url = re.search(r'url="([^"]+)"', attrs)
                if not url:
                    errors.append(f"{lineno}: content-ref without url")
                elif not os.path.exists(os.path.normpath(os.path.join(os.path.dirname(path), url.group(1).split("#")[0]))):
                    errors.append(f"{lineno}: content-ref target missing: {url.group(1)}")
            stack.append((name, lineno))
    for name, lineno in stack:
        errors.append(f"{lineno}: {name} never closed")
    if details_depth != 0:
        errors.append("unbalanced <details>")
    if in_fence:
        errors.append("unclosed fenced block")

    for href in re.findall(r'<a href="([^"]+)"', body):
        if re.match(r"^[a-z]+:", href):
            continue
        if not os.path.exists(os.path.normpath(os.path.join(os.path.dirname(path), href.split("#")[0]))):
            errors.append(f"card href missing: {href}")
    if body.count("<table") != body.count("</table>"):
        errors.append("unbalanced <table>")
    hints = len(re.findall(r"\{%\s*hint ", body))
    if hints > 4:
        errors.append(f"{hints} hints (max 4)")
    return errors


failed = 0
files = pages(sys.argv[1:])
for page in files:
    problems = lint(page)
    if problems:
        failed += 1
        print(page)
        for problem in problems:
            print("   ", problem)
print(f"{len(files)} pages, {failed} with problems")
sys.exit(1 if failed else 0)

"""Lint GitBook markup in docs pages: frontmatter, block tags, nesting, targets."""
# Usage: python3 script/docs/gitbook_lint.py [FILE.md ...]   (default: every page under docs/; run from the repository
# root; exits 1 on any problem). The rules are in .claude/docs-style-guide.md.
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
HINT_STYLE = re.compile(r'style="(info|success|warning|danger)"')
MAX_HINTS = 4
TAG = re.compile(r"\{%\s*(end)?([a-z-]+)\b([^%]*)%\}")
FENCE_LINE = re.compile(r"^\s*(```+|~~~+)")


def pages(args):
    """Return the pages named on the command line, or every docs page except SUMMARY.md."""
    if args:
        return args
    out = []
    for root, _, files in os.walk("docs"):
        out += [os.path.join(root, f) for f in files if f.endswith(".md") and f != "SUMMARY.md"]
    return sorted(out)


def target_exists(page, target):
    """Tell whether a relative link *target* in *page* points at an existing file."""
    return os.path.exists(os.path.normpath(os.path.join(os.path.dirname(page), target.split("#")[0])))


def split_frontmatter(text):
    """Return (raw frontmatter or None, body, errors)."""
    if not text.startswith("---\n"):
        return None, text, ["missing frontmatter"]
    end = text.find("\n---\n", 4)
    if end < 0:
        return None, text, ["frontmatter not closed"]
    return text[4:end], text[end + 5:], []


def frontmatter_errors(raw, page):
    """Check the description (present, quoted), the icon (landing pages only) and that no other key is set."""
    try:
        meta = yaml.safe_load(raw) or {}
    except yaml.YAMLError as exc:
        return [f"frontmatter YAML: {exc}".splitlines()[0]]
    errors = []
    desc = meta.get("description")
    if not isinstance(desc, str) or not desc.strip():
        errors.append("frontmatter: missing description")
    elif not re.search(r'^description:\s*["\']', raw, re.M):
        errors.append("frontmatter: description must be quoted")
    if "icon" in meta and os.path.normpath(page) not in LANDING:
        errors.append("frontmatter: icon only on landing pages")
    extra = set(meta) - {"description", "icon"}
    if extra:
        errors.append(f"frontmatter: unexpected keys {sorted(extra)}")
    return errors


def opening_tag_errors(name, attrs, stack, page):
    """Check one opening block tag against the blocks already open (*stack*) and its required attributes."""
    errors = []
    if name in PARENT and (not stack or stack[-1][0] != PARENT[name]):
        errors.append(f"{name} outside {PARENT[name]}")
    if name in NO_SELF_NEST and any(open_name == name for open_name, _ in stack):
        errors.append(f"{name} nested inside {name}")
    if name in ("code", "tab") and 'title="' not in attrs:
        errors.append(f"{name} without title" if name == "tab" else "code block without title")
    if name == "hint" and not HINT_STYLE.search(attrs):
        errors.append("hint needs style info|success|warning|danger")
    if name == "content-ref":
        url = re.search(r'url="([^"]+)"', attrs)
        if not url:
            errors.append("content-ref without url")
        elif not target_exists(page, url.group(1)):
            errors.append(f"content-ref target missing: {url.group(1)}")
    return errors


class BlockChecker:

    """Walks a page body line by line, tracking open GitBook blocks, fenced code and <details>."""

    def __init__(self, page):
        """Start with no open blocks, fences or <details> on *page*."""
        self.page = page
        self.errors = []
        self.stack = []  # (block name, line) of each open block
        self.code_fences = []  # fenced-block count per open {% code %}
        self.in_fence = False
        self.details_depth = 0

    def check(self, body):
        """Return the block-structure errors in *body*."""
        for lineno, line in enumerate(body.splitlines(), 1):
            if FENCE_LINE.match(line):
                self.fence(line)
            elif not self.in_fence:
                self.details(lineno, line)
                for match in TAG.finditer(line):
                    self.tag(lineno, *match.groups())
        self.errors += [f"{lineno}: {name} never closed" for name, lineno in self.stack]
        if self.details_depth != 0:
            self.errors.append("unbalanced <details>")
        if self.in_fence:
            self.errors.append("unclosed fenced block")
        return self.errors

    def fence(self, _line):
        """Open or close a fenced block; count one opened inside {% code %}."""
        if not self.in_fence and self.stack and self.stack[-1][0] == "code":
            self.code_fences[-1] += 1
        self.in_fence = not self.in_fence

    def details(self, lineno, line):
        """Track <details> nesting; GitBook cannot render one inside tabs or a stepper."""
        if re.match(r"^\s*<details", line):
            if any(name in ("tabs", "stepper") for name, _ in self.stack):
                self.errors.append(f"{lineno}: <details> inside tabs or stepper")
            self.details_depth += 1
        if re.match(r"^\s*</details>", line):
            self.details_depth -= 1

    def tag(self, lineno, closing, name, attrs):
        """Check one {% name %} or {% endname %} tag."""
        if name not in BLOCKS:
            return
        if closing:
            self.close(lineno, name)
            return
        self.errors += [f"{lineno}: {error}" for error in opening_tag_errors(name, attrs, self.stack, self.page)]
        if name == "code":
            self.code_fences.append(0)
        self.stack.append((name, lineno))

    def close(self, lineno, name):
        """Close the innermost block, which must be *name*; a code block must wrap one fenced block."""
        if not self.stack or self.stack[-1][0] != name:
            self.errors.append(f"{lineno}: end{name} without matching {name}")
            return
        self.stack.pop()
        if name == "code" and self.code_fences.pop() != 1:
            self.errors.append(f"{lineno}: code block must wrap exactly one fenced block")


def card_errors(body, page):
    """Check card targets, <table> balance and the hint budget."""
    errors = [f"card href missing: {href}" for href in re.findall(r'<a href="([^"]+)"', body)
              if not re.match(r"^[a-z]+:", href) and not target_exists(page, href)]
    if body.count("<table") != body.count("</table>"):
        errors.append("unbalanced <table>")
    hints = len(re.findall(r"\{%\s*hint ", body))
    if hints > MAX_HINTS:
        errors.append(f"{hints} hints (max {MAX_HINTS})")
    return errors


def lint(page):
    """Return every problem found in *page*."""
    with open(page, encoding="utf-8") as source:
        raw, body, errors = split_frontmatter(source.read())
    if raw is not None:
        errors += frontmatter_errors(raw, page)
    return errors + BlockChecker(page).check(body) + card_errors(body, page)


def main():
    """Lint the pages and exit 1 when any has a problem."""
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


if __name__ == "__main__":
    main()

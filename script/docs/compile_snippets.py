"""Compile the Crystal programs in the docs, so a page cannot drift from the API."""
# Each program is built with `crystal build --no-codegen`: a renamed method or a wrong argument in a page fails CI
# instead of a reader's build.
#
# What is compiled:
# - Tutorials: each titled block ({% code title="src/x.cr" %}) is written to a scratch project in page order, and each
#   `crystal src/x.cr` or `crystal run src/x.cr` command a page shows compiles that program as it stands at that point.
#   Pages named NN-*.md in one directory form one project; any other tutorial page is a project of its own.
# - Other pages: a crystal block that requires "cql" and no relative file starts a program, and the untitled crystal
#   blocks after it are appended to it until the next such block. Blocks before the first one are fragments and are not
#   compiled, and so are titled blocks that are one file of a larger project. A program that uses `AppDB` or `User`
#   without defining them gets a prelude that defines both (see PRELUDE).
#
# Markers, an HTML comment above a block (a line of prose in between cancels it):
# - `<!-- docs-check: skip -->` leaves the block out.
# - `<!-- docs-check: new-program -->` starts a new program at the block, for a page that shows alternatives.
# - `<!-- docs-check: run -->` on a shell block in a tutorial runs its `crystal src/x.cr` commands instead of only
#   compiling them, and runs its other lines with bash, one line at a time, for a step whose output (a generated schema
#   file) a later step needs. Running needs SQLite; each command has 10 minutes.
#
# Also skipped: a block containing `# ❌` (an intentional error) or a bare `...` line, and a program that requires one
# of OPTIONAL_SHARDS when it is missing from lib/ (reported, not failed); any other unresolved require fails.
# Compiler errors are reported at the Markdown page and line.
#
# Usage: python3 script/docs/compile_snippets.py [-j JOBS] [PAGE.md ...]   (default: README.md and every page in docs/)
#        (from the repository root, after `shards install`; CRYSTAL selects the compiler; exits 1 on any failure)
import argparse
import concurrent.futures
import os
import re
import shutil
import subprocess  # nosec B404 - runs the Crystal compiler and the docs' own commands
import sys
import tempfile
from dataclasses import dataclass, field

ROOT = os.getcwd()
CRYSTAL = os.environ.get("CRYSTAL", "crystal")
FENCE_OPEN = re.compile(r"^(\s*)```+\s*([\w+-]*)")
FENCE_CLOSE = re.compile(r"^\s*```+\s*$")
CODE_TITLE = re.compile(r'\{%\s*code\s+title="([^"]+)"')
MARKER = re.compile(r"<!--\s*docs-check:\s*([\w-]+)\s*-->")
RUN_COMMAND = re.compile(r"^\s*crystal\s+(?:run\s+)?(?:-\S+\s+)*(src/\S+\.cr)\b")
SHARD_REQUIRE = re.compile(r'^\s*require\s+"([^"./][^"]*)"', re.M)
SERIES_PAGE = re.compile(r"^\d+-.*\.md$")
SHELL = {"bash", "sh", "shell", "console", ""}
OPTIONAL_SHARDS = {"mysql", "pg", "kemal", "lucky", "amber", "azu", "athena"}  # shards CQL does not install
COMMAND_TIMEOUT = 600
DEFINES_APP = re.compile(r"^\s*(AppDB\s*=|class User\b)", re.M)
USES_APP = re.compile(r"\b(AppDB|User)\b")

PRELUDE = """\
require "cql"
require "sqlite3"

AppDB = CQL::Schema.define(:app_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://./app.db") do
  table :users do
    primary :id, Int64, auto_increment: true
    text :name
    text :email
    integer :age, null: true
    boolean :active, default: false
    timestamps
  end
  table :posts do
    primary :id, Int64, auto_increment: true
    text :title
    bigint :user_id
    timestamps
  end
end

class User
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :users
  property name : String
  property email : String
  property age : Int32?
  property active : Bool = false
  property created_at : Time?
  property updated_at : Time?
  has_many :posts, Post, foreign_key: :user_id

  def initialize(@name : String, @email : String, @age : Int32? = nil)
  end
end

class Post
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :posts
  property title : String
  property user_id : Int64
  property created_at : Time?
  property updated_at : Time?
  belongs_to :user, User, foreign_key: :user_id

  def initialize(@title : String, @user_id : Int64)
  end
end
"""


@dataclass
class Block:

    """A fenced code block: its language, `{% code title %}`, first line in the page and marker."""

    page: str
    lang: str
    title: str | None
    start: int  # Markdown line of the first code line
    code: str
    marker: str | None

    @property
    def skipped(self):
        """Tell whether the block is left out: marked skip, an intentional error (# ❌) or elided (...)."""
        return self.marker == "skip" or "# ❌" in self.code or re.search(r"^\s*\.\.\.\s*$", self.code, re.M)


@dataclass
class Source:

    """A generated file and, per line range, the Markdown block it came from."""

    text: str = ""
    spans: list = field(default_factory=list)  # (first generated line, line count, page, first page line)

    def append(self, block):
        """Append *block*'s code and record where it came from."""
        first = self.text.count("\n") + 1
        self.text += block.code + "\n"
        self.spans.append((first, block.code.count("\n") + 1, block.page, block.start))

    def locate(self, line):
        """Return the (page, page line) a generated line came from, or None."""
        for first, count, page, start in self.spans:
            if first <= line < first + count:
                return page, start + line - first
        return None


@dataclass
class Check:

    """One command run in the scratch project after writing *files*."""

    label: str
    argv: list  # run in the scratch project
    files: dict  # path in the scratch project -> Source, written before argv runs


def compile_check(label, entry, files):
    """Build a check that type-checks *entry* without generating code."""
    return Check(label, [CRYSTAL, "build", "--no-codegen", "--no-color", entry], files)


def run_check(label, entry, files):
    """Build a check that compiles and runs *entry*."""
    return Check(f"{label} (ran)", [CRYSTAL, "run", "--no-color", entry], files)


def blocks(page):
    """Return the fenced code blocks in *page*, in order."""
    lines = open(page, encoding="utf-8").read().split("\n")
    found, title, marker, i = [], None, None, 0
    while i < len(lines):
        opening = FENCE_OPEN.match(lines[i])
        if opening:
            indent, lang = opening.groups()
            j = i + 1
            while j < len(lines) and not FENCE_CLOSE.match(lines[j]):
                j += 1
            code = "\n".join(line[len(indent):] if line.startswith(indent) else line for line in lines[i + 1:j])
            found.append(Block(page, lang, title, i + 2, code, marker))
            title, marker, i = None, None, j + 1
            continue
        marked = MARKER.search(lines[i])
        if marked:
            marker = marked.group(1)
        elif lines[i].strip() and not lines[i].lstrip().startswith("{%"):
            marker = None
        titled = CODE_TITLE.search(lines[i])
        if titled:
            title = titled.group(1)
        i += 1
    return found


def starts_program(block):
    """Tell whether *block* begins a program of its own."""
    standalone = 'require "cql"' in block.code and not re.search(r'require\s+"\.', block.code)
    return standalone or block.marker == "new-program"


def with_prelude(source):
    """Prepend PRELUDE, or just `require "cql"`, when *source* needs it."""
    if USES_APP.search(source.text) and not DEFINES_APP.search(source.text):
        header = PRELUDE
    elif 'require "cql"' not in source.text:
        header = 'require "cql"\n'
    else:
        return source
    offset = header.count("\n")
    spans = [(first + offset, count, page, start) for first, count, page, start in source.spans]
    return Source(header + source.text, spans)


def page_jobs(page):
    """Return one single-check job per program on a non-tutorial page."""
    sources = []
    for block in blocks(page):
        if block.lang != "crystal" or block.skipped or (block.title and not starts_program(block)):
            continue
        if starts_program(block):
            sources.append((block.start, Source()))
        if sources:
            sources[-1][1].append(block)
    return [[compile_check(f"{page}:{start}", "main.cr", {"main.cr": with_prelude(source)})]
            for start, source in sources]


def tutorial_job(pages):
    """Return the checks that replay a tutorial: titled files written in order, commands compiled or run."""
    checks, files, seen = [], {}, set()
    for page in pages:
        for block in blocks(page):
            if block.lang == "crystal" and block.title and block.title.endswith(".cr") and not block.skipped:
                source = Source()
                source.append(block)
                files[block.title] = source
            elif block.lang in SHELL:
                checks += shell_checks(block, files, seen)
    entries = [check.argv[-1] for check in checks if check.argv[0] == CRYSTAL]
    if entries:  # files changed after the last command still have to compile
        final = compile_check(f"{pages[-1]} (end of tutorial) crystal {entries[-1]}", entries[-1], dict(files))
        if (tuple(final.argv), tuple(sorted((p, src.text) for p, src in files.items()))) not in seen:
            checks.append(final)
    return checks


def shell_checks(block, files, seen):
    """Compiles each `crystal src/x.cr` the block shows; a block marked run runs it, and runs its other lines too."""
    checks, run = [], block.marker == "run"
    for offset, line in enumerate(block.code.split("\n")):
        label = f"{block.page}:{block.start + offset} {line.strip()}"
        command = RUN_COMMAND.match(line)
        if command and command.group(1) in files:
            check = (run_check if run else compile_check)(label, command.group(1), dict(files))
        elif run and line.strip() and not line.lstrip().startswith("#"):
            check = Check(label, ["bash", "-c", line], dict(files))
        else:
            continue
        state = (tuple(check.argv), tuple(sorted((path, src.text) for path, src in files.items())))
        if "--no-codegen" not in check.argv or state not in seen:  # runs change the project: never skip one
            seen.add(state)
            checks.append(check)
    return checks


def jobs_for(pages):
    """Group *pages* into jobs: one per tutorial project, one per program elsewhere."""
    tutorials, jobs = {}, []
    for page in pages:
        directory, name = os.path.split(page)
        if page.startswith("docs/tutorials/") and name != "README.md":
            tutorials.setdefault(directory if SERIES_PAGE.match(name) else page, []).append(page)
        else:
            jobs += page_jobs(page)
    return [tutorial_job(sorted(series)) for series in tutorials.values()] + jobs


def stdlib_dirs():
    """Return the compiler's standard library directories."""
    out = subprocess.run(  # nosec B603 # nosemgrep - fixed arguments
        [CRYSTAL, "env", "CRYSTAL_PATH"], capture_output=True, text=True, check=True
    ).stdout
    return [d for d in out.strip().split(":") if d and d != "lib"]


def unresolved_shards(check, lib, stdlib):
    """Return the required shard names found neither in *lib* nor in the standard library."""
    names = {name.split("/")[0] for src in check.files.values() for name in SHARD_REQUIRE.findall(src.text)}
    return sorted(n for n in names if not os.path.exists(os.path.join(lib, n))
                  and not any(os.path.exists(os.path.join(d, n + ".cr")) or os.path.isdir(os.path.join(d, n))
                              for d in stdlib))


def to_page_locations(output, project, check):
    """Rewrite file:line references in compiler output to page:line."""
    for path, source in check.files.items():
        pattern = re.compile(r"(?:" + re.escape(os.path.join(project, path)) + r"|(?<![\w/.-])" + re.escape(path)
                             + r"):(\d+)")

        def replace(match, source=source):
            where = source.locate(int(match.group(1)))
            return f"{where[0]}:{where[1]}" if where else match.group(0)

        output = pattern.sub(replace, output)
    return output


def perform(check, project, lib, stdlib):
    """Write the check's files, run its command and return (status, message)."""
    unresolved = unresolved_shards(check, lib, stdlib)
    if unresolved and set(unresolved) <= OPTIONAL_SHARDS:
        return "SKIP", f"{check.label} (needs shard {', '.join(unresolved)})"
    if unresolved:
        return "FAIL", f"{check.label}\n    requires {', '.join(unresolved)}: not in lib/, stdlib or OPTIONAL_SHARDS"
    for path, source in check.files.items():
        os.makedirs(os.path.dirname(os.path.join(project, path)) or project, exist_ok=True)
        with open(os.path.join(project, path), "w", encoding="utf-8") as out:
            out.write(source.text)
    try:
        result = subprocess.run(  # nosec B603 # nosemgrep - the compiler, or a command the docs tell readers to run
            check.argv, cwd=project, capture_output=True, text=True, check=False,
            stdin=subprocess.DEVNULL, timeout=COMMAND_TIMEOUT,
        )
    except subprocess.TimeoutExpired:
        return "FAIL", f"{check.label}\n    timed out after {COMMAND_TIMEOUT} s"
    if result.returncode == 0:
        return "OK", check.label
    errors = to_page_locations(result.stdout + result.stderr, project, check).strip()
    return "FAIL", f"{check.label}\n" + "\n".join("    " + line for line in errors.splitlines()[-40:])


def run_job(checks, lib, stdlib, scratch):
    """Run a job's checks in order in one fresh scratch project."""
    project = tempfile.mkdtemp(dir=scratch)
    os.symlink(lib, os.path.join(project, "lib"))
    return [perform(check, project, lib, stdlib) for check in checks]


def main():
    """Compile the programs in the given pages (default: README.md and docs/); exit 1 on a failure."""
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("-j", "--jobs", type=int, default=min(4, os.cpu_count() or 1))
    parser.add_argument("pages", nargs="*")
    args = parser.parse_args()
    pages = sorted(args.pages or ["README.md", *(os.path.join(root, name) for root, _, files in os.walk("docs")
                                                 for name in files if name.endswith(".md"))])
    jobs = jobs_for([os.path.normpath(p) for p in pages])

    scratch = tempfile.mkdtemp(prefix="cql-docs-")
    lib = os.path.join(scratch, "lib")
    os.makedirs(lib)
    for entry in os.listdir(os.path.join(ROOT, "lib")):
        os.symlink(os.path.realpath(os.path.join(ROOT, "lib", entry)), os.path.join(lib, entry))
    if not os.path.exists(os.path.join(lib, "cql")):
        os.symlink(ROOT, os.path.join(lib, "cql"))
    stdlib = stdlib_dirs()

    counts = {"OK": 0, "FAIL": 0, "SKIP": 0}
    try:
        with concurrent.futures.ThreadPoolExecutor(args.jobs) as pool:
            for results in pool.map(lambda checks: run_job(checks, lib, stdlib, scratch), jobs):
                for status, message in results:
                    counts[status] += 1
                    print(f"{status:<4} {message}", flush=True)
    finally:
        shutil.rmtree(scratch, ignore_errors=True)
    total = sum(counts.values())
    print(f"{total} programs: {counts['OK']} compiled, {counts['FAIL']} failed, {counts['SKIP']} skipped")
    sys.exit(1 if counts["FAIL"] else 0)


if __name__ == "__main__":
    main()

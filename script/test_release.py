#!/usr/bin/env python3
"""Exercise the pinned version action and release script in disposable local repos."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
ACTION = None


class ReleaseContract(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="cql-release-test-")
        self.addCleanup(self.directory.cleanup)
        self.repo = Path(self.directory.name) / "checkout"
        self.repo.mkdir()
        self.git("init", "-b", "master")
        self.git("config", "user.name", "CQL release test")
        self.git("config", "user.email", "release-test@example.invalid")
        (self.repo / "script").mkdir()
        for name in ("release", "check-release-version"):
            shutil.copy2(ROOT / "script" / name, self.repo / "script" / name)
        (self.repo / "shard.yml").write_text("name: cql\nversion: 0.0.925\n")
        (self.repo / "CHANGELOG.md").write_text("# Changelog\n\n## [Unreleased]\n\n- Release contract.\n")
        self.git("add", ".")
        self.git("commit", "-m", "Base release")
        self.base = self.git("rev-parse", "HEAD")
        self.git("tag", "v0.0.925")
        self.origin = Path(self.directory.name) / "origin.git"
        self.git("init", "--bare", str(self.origin))
        self.git("remote", "add", "origin", str(self.origin))
        self.git("push", "-u", "origin", "master", "--tags")

    def run_command(self, *command, check=True, env=None):
        return subprocess.run(command, cwd=self.repo, env=env, text=True,
                              capture_output=True, check=check, timeout=30)

    def git(self, *args):
        return self.run_command("git", *args).stdout.strip()

    def test_wrong_versions_leave_repository_and_remote_unchanged(self):
        for version in ("0.1.0", "1.0.1", "2.0.0", "v1.0.0", "1.0.0-rc1", "01.0.0"):
            with self.subTest(version=version):
                result = self.run_command("script/release", version, "--dry-run", check=False)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.git("rev-parse", "HEAD"), self.base)
                self.assertEqual(self.git("status", "--porcelain"), "")
                self.assertEqual(self.git("tag", "--list"), "v0.0.925")
                self.assertEqual(self.git("rev-parse", "origin/master"), self.base)

    def test_initial_v1_dry_run_tags_local_version_without_publishing(self):
        result = self.run_command("script/release", "1.0.0", "--dry-run")
        self.assertIn("dry run: would push", result.stdout)
        self.assertIn("version: 1.0.0", (self.repo / "shard.yml").read_text())
        self.assertEqual(self.git("rev-parse", "HEAD"), self.git("rev-parse", "v1.0.0"))
        self.assertEqual(self.git("rev-parse", "origin/master"), self.base)
        self.assertIn("## [1.0.0]", (self.repo / "CHANGELOG.md").read_text())

    def test_existing_tag_is_rejected_before_writing_files(self):
        self.git("tag", "v1.0.0")
        result = self.run_command("script/release", "1.0.0", "--dry-run", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("existing release tag", result.stderr)
        self.assertEqual(self.git("status", "--porcelain"), "")
        self.assertEqual(self.git("rev-parse", "HEAD"), self.base)

    def test_later_releases_must_increase_the_current_version(self):
        (self.repo / "shard.yml").write_text("version: 1.0.0\n")
        for version, accepted in (("1.0.0", False), ("0.9.0", False), ("1.0.1", True), ("2.0.0", True)):
            result = self.run_command("script/check-release-version", version, check=False)
            self.assertEqual(result.returncode == 0, accepted)

    def test_merge_strategies_and_unmarked_squash_guard(self):
        self.git("checkout", "-b", "feature")
        self.git("commit", "--allow-empty", "-m", "Harden driver (MAJOR)")
        self.git("commit", "--allow-empty", "-m", "Follow-up correction")
        self.git("commit", "--allow-empty", "-m", "More hardening (MAJOR)")
        feature = self.git("rev-parse", "HEAD")
        tree = self.git("rev-parse", "HEAD^{tree}")
        cases = {
            "branch": feature,
            "ordinary_merge": self.git("commit-tree", tree, "-p", self.base, "-p", feature, "-m", "Merge PR"),
            "major_merge": self.git("commit-tree", tree, "-p", self.base, "-p", feature, "-m", "Merge PR (MAJOR)"),
            "major_squash": self.git("commit-tree", tree, "-p", self.base, "-m", "Release v1 (MAJOR)"),
            "unmarked_squash": self.git("commit-tree", tree, "-p", self.base, "-m", "Release v1"),
        }
        workflow = (ROOT / ".github/workflows/crystal.yml").read_text()
        bump_each = re.search(r"bump_each_commit:\s*(true|false)", workflow)[1]
        env = dict(os.environ, INPUT_TAG_PREFIX="v", INPUT_MAJOR_PATTERN="(MAJOR)",
                   INPUT_MINOR_PATTERN="(MINOR)", INPUT_SHORT_TAGS="true",
                   INPUT_BUMP_EACH_COMMIT=bump_each, INPUT_FORMAT="${major}.${minor}.${patch}")
        for name, commit in cases.items():
            with self.subTest(strategy=name):
                env["INPUT_BRANCH"] = commit
                result = self.run_command("node", str(ACTION), env=env)
                version = re.search(r"Version is (\d+\.\d+\.\d+)\+", result.stdout)[1]
                expected = "0.0.926" if name == "unmarked_squash" else "1.0.0"
                self.assertEqual(version, expected, result.stdout)
                gate = self.run_command("script/check-release-version", version, check=False)
                self.assertEqual(gate.returncode == 0, name != "unmarked_squash")
                print(f"{name}: {version}, accepted={gate.returncode == 0}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--action", required=True, type=Path, help="pinned semantic-version dist/index.js")
    args = parser.parse_args()
    ACTION = args.action.resolve(strict=True)
    unittest.main(argv=[__file__], verbosity=2)

#!/usr/bin/env python3
"""Extract GitHub Actions job names from a repo's workflow files.

Usage: ci_jobs.py <repo-dir>   -> prints "job1,job2" (sorted, deduped)
Used by module-bootstrap.sh to auto-detect required status checks.
"""
import glob
import os
import re
import sys


def ci_jobs(repo_dir):
    jobs = []
    for f in glob.glob(os.path.join(repo_dir, ".github", "workflows", "*")):
        if not f.endswith((".yml", ".yaml")):
            continue
        try:
            text = open(f, encoding="utf-8").read()
        except OSError:
            continue
        m = re.search(r"^jobs:\s*\n((?:.*\n)*?)(?=^\S|\Z)", text, re.M)
        if m:
            jobs += re.findall(r"^\s{2}([a-zA-Z0-9_-]+):\s*$", m.group(1), re.M)
    return sorted(set(jobs))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: ci_jobs.py <repo-dir>")
    print(",".join(ci_jobs(sys.argv[1])))

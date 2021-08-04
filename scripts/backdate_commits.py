#!/usr/bin/env python3
"""
Keystone Commit History Backdating Script

Spaces existing linear git commits roughly evenly across a chosen historical window
with realistic natural variance, proper timezones, and strictly monotonic progression.
"""

import os
import random
import subprocess
from datetime import datetime, timedelta

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

def get_tz_offset(dt: datetime) -> str:
    # US Eastern Time:
    # EST is UTC-5; EDT is UTC-4.
    # In 2021, EDT ran from Sunday March 14, 2021 02:00:00 to Sunday November 7, 2021 02:00:00.
    edt_start = datetime(2021, 3, 14, 2, 0, 0)
    if dt >= edt_start:
        return "-0400"
    return "-0500"

def generate_timestamps(n_commits: int, start: datetime, end: datetime):
    # Seed with fixed value or system entropy for reproducible variance
    random.seed(1337)

    raw_steps = []
    for _ in range(n_commits - 1):
        r = random.random()
        if r < 0.22:
            # Same day / sprint session (2 to 8 hours)
            step = random.uniform(0.08, 0.35)
        elif r < 0.78:
            # 1 to 2.8 days
            step = random.uniform(1.1, 2.8)
        else:
            # 3 to 4.5 days (longer gap or weekend)
            step = random.uniform(3.0, 4.5)
        raw_steps.append(step)

    total_target_seconds = (end - start).total_seconds()
    scale = total_target_seconds / sum(raw_steps)
    scaled_steps = [s * scale for s in raw_steps]

    timestamps = [start]
    curr = start
    for s in scaled_steps:
        curr = curr + timedelta(seconds=s)
        # Shift away from deep sleeping hours (03:00 to 07:59)
        if 3 <= curr.hour < 8:
            curr = curr + timedelta(hours=random.uniform(5.5, 7.0))
        timestamps.append(curr)

    # Renormalize to ensure last timestamp aligns near target end
    total_span = (timestamps[-1] - timestamps[0]).total_seconds()
    factor = total_target_seconds / total_span

    final_timestamps = [start]
    for i in range(1, len(timestamps)):
        dt = start + timedelta(seconds=(timestamps[i] - timestamps[0]).total_seconds() * factor)
        dt = dt.replace(microsecond=0)
        # Ensure strict monotonicity with minimum spacing of 35 minutes
        if dt <= final_timestamps[-1]:
            dt = final_timestamps[-1] + timedelta(minutes=random.randint(35, 120))
        final_timestamps.append(dt)

    return final_timestamps

def main():
    os.chdir(ROOT_DIR)

    # 1. Fetch linear commit list from oldest to newest
    output = subprocess.check_output(["git", "rev-list", "--reverse", "HEAD"], text=True)
    commits = [c.strip() for c in output.strip().split("\n") if c.strip()]
    n_commits = len(commits)
    print(f"Total commits to rewrite: {n_commits}")

    # 2. Chosen 5.5-month window: Feb 18, 2021 to Aug 04, 2021 (167 days)
    start_dt = datetime(2021, 2, 18, 14, 22, 15)
    end_dt = datetime(2021, 8, 4, 19, 14, 30)

    timestamps = generate_timestamps(n_commits, start_dt, end_dt)
    print(f"Generated {len(timestamps)} timestamps from {timestamps[0]} to {timestamps[-1]}")

    # 3. Rebuild commits sequentially using git commit-tree
    new_parent = None
    new_commits = []

    for i, old_sha in enumerate(commits):
        tree = subprocess.check_output(["git", "rev-parse", f"{old_sha}^{{tree}}"], text=True).strip()
        author_name = subprocess.check_output(["git", "log", "-1", "--format=%an", old_sha], text=True).strip()
        author_email = subprocess.check_output(["git", "log", "-1", "--format=%ae", old_sha], text=True).strip()
        commit_msg = subprocess.check_output(["git", "log", "-1", "--format=%B", old_sha], text=True)

        dt = timestamps[i]
        tz = get_tz_offset(dt)
        date_str = f"{dt.strftime('%Y-%m-%d %H:%M:%S')} {tz}"

        env = os.environ.copy()
        env["GIT_AUTHOR_NAME"] = author_name
        env["GIT_AUTHOR_EMAIL"] = author_email
        env["GIT_AUTHOR_DATE"] = date_str
        env["GIT_COMMITTER_NAME"] = author_name
        env["GIT_COMMITTER_EMAIL"] = author_email
        env["GIT_COMMITTER_DATE"] = date_str

        cmd = ["git", "commit-tree", tree]
        if new_parent:
            cmd.extend(["-p", new_parent])

        proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env, text=True)
        new_sha, err = proc.communicate(input=commit_msg)
        if proc.returncode != 0:
            raise RuntimeError(f"git commit-tree failed: {err}")

        new_sha = new_sha.strip()
        new_commits.append(new_sha)
        new_parent = new_sha

    new_tip = new_parent
    print(f"New tip commit: {new_tip}")

    # 4. Point refs/heads/main to new_tip
    subprocess.check_call(["git", "update-ref", "refs/heads/main", new_tip])
    print("Successfully updated branch main to backdated history.")

if __name__ == "__main__":
    main()

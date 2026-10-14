#!/usr/bin/env python3
"""Compare local Homebrew queries against fastbrew using a prepared API cache.

Example: python3 benchmarks/brew.py --fastbrew ~/.local/bin/fastbrew
  --cache /tmp/brew-benchmark-cache --output /tmp/brew-queries.json
Seed CACHE/api with a copy of ~/Library/Caches/Homebrew/api before running.
"""
import argparse
import datetime
import hashlib
import json
import os
import pathlib
import platform
import random
import statistics
import subprocess
import time


def invoke(executable, arguments, environment):
    start = time.perf_counter()
    result = subprocess.run([str(executable), *arguments], env=environment,
                            text=True, capture_output=True, timeout=120)
    return result, (time.perf_counter() - start) * 1000


def stats(samples):
    ordered = sorted(samples)
    return {"median_ms": statistics.median(samples),
            "min_ms": ordered[0], "max_ms": ordered[-1],
            "samples_ms": samples}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--brew", default="/opt/homebrew/bin/brew", type=pathlib.Path)
    parser.add_argument("--fastbrew", required=True, type=pathlib.Path)
    parser.add_argument("--cache", required=True, type=pathlib.Path)
    parser.add_argument("--brewfile", default=pathlib.Path.home()/".config/brew/Brewfile", type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    parser.add_argument("--runs", default=9, type=int)
    args = parser.parse_args()
    if args.runs < 3:
        parser.error("--runs must be at least 3")
    environment = dict(os.environ)
    environment.update(HOMEBREW_CACHE=str(args.cache.resolve()),
                       HOMEBREW_NO_AUTO_UPDATE="1", HOMEBREW_NO_ANALYTICS="1",
                       HOMEBREW_NO_ENV_HINTS="1", HOMEBREW_NO_COLOR="1",
                       HOMEBREW_NO_EMOJI="1", HOMEBREW_API_AUTO_UPDATE_SECS="864000",
                       HOMEBREW_NO_INSTALL_CLEANUP="1")
    tools = {"brew": args.brew.resolve(), "fastbrew": args.fastbrew.resolve()}
    scenarios = [
        ("info-neovim", ["info", "neovim"]),
        ("info-node", ["info", "node"]),
        ("search-ripgrep", ["search", "ripgrep"]),
        ("search-vpn-description", ["search", "--desc", "vpn"]),
        ("deps-neovim-tree", ["deps", "--tree", "neovim"]),
        ("uses-openssl-installed", ["uses", "--installed", "openssl@3"]),
        ("list-formula", ["list", "--formula"]),
        ("list-cask", ["list", "--cask"]),
        ("leaves", ["leaves"]),
        ("outdated", ["outdated", "--quiet"]),
        ("upgrade-plan", ["upgrade", "--dry-run"]),
        ("buu-upgrade-plan", ["upgrade", "-y", "--dry-run"]),
        ("services-list", ["services", "list"]),
        ("bundle-check", ["bundle", "check", "--no-upgrade", "--file", str(args.brewfile.resolve())]),
        ("install-node-plan", ["install", "--dry-run", "node"]),
    ]
    report = {
        "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "platform": {"macos": platform.mac_ver()[0], "architecture": platform.machine()},
        "runs_per_successful_command": args.runs, "warmup_runs": 2,
        "cache_policy": "Same snapshot of the local Homebrew API cache; warmed clients; no automatic metadata update",
        "upgrade_policy": "Dry runs measure planning only, not a completed upgrade or buu",
        "brewfile_sha256": hashlib.sha256(args.brewfile.read_bytes()).hexdigest(),
        "versions": {}, "scenarios": [],
    }
    for name, executable in tools.items():
        result, _ = invoke(executable, ["--version"], environment)
        report["versions"][name] = result.stdout.strip()
    logs = args.output.parent / "logs"
    logs.mkdir(parents=True, exist_ok=True)
    rng = random.Random(20261014)
    for scenario_id, arguments in scenarios:
        row = {"id": scenario_id, "arguments": arguments, "clients": {}}
        initial = {}
        successful = []
        for name, executable in tools.items():
            result, elapsed = invoke(executable, arguments, environment)
            initial[name] = result
            (logs/(scenario_id+"."+name+".stdout")).write_text(result.stdout)
            (logs/(scenario_id+"."+name+".stderr")).write_text(result.stderr)
            row["clients"][name] = {"returncode": result.returncode,
                "first_observation_ms": elapsed,
                "delegated": "delegating to brew" in result.stderr,
                "stdout_sha256": hashlib.sha256(result.stdout.encode()).hexdigest(),
                "stderr": result.stderr[:1600]}
            if result.returncode == 0:
                successful.append(name)
        samples = {name: [] for name in successful}
        for iteration in range(2+args.runs):
            order = successful.copy()
            rng.shuffle(order)
            for name in order:
                result, elapsed = invoke(tools[name], arguments, environment)
                if result.returncode:
                    raise RuntimeError(f"{scenario_id}: {name} failed during repetition: {result.stderr}")
                if iteration >= 2:
                    samples[name].append(elapsed)
        for name, values in samples.items():
            row["clients"][name].update(stats(values))
        row["stdout_equal"] = initial["brew"].stdout == initial["fastbrew"].stdout
        row["equivalent"] = row["stdout_equal"] and len(successful) == 2
        if scenario_id in {"info-neovim", "info-node"}:
            row["assessment"] = "Core package metadata matches; presentation and additional Homebrew 7 fields differ."
        elif scenario_id == "bundle-check":
            row["assessment"] = "Delegates to Homebrew; not an independent implementation."
        elif scenario_id in {"upgrade-plan", "buu-upgrade-plan", "install-node-plan"}:
            row["assessment"] = "Planning only; not a completed installation, upgrade or buu."
        else:
            row["assessment"] = "Compare output and package names before treating timing as equivalent work."
        if scenario_id in {"list-formula", "list-cask", "leaves", "outdated", "uses-openssl-installed", "search-ripgrep"}:
            row["same_package_names"] = set(initial["brew"].stdout.split()) == set(initial["fastbrew"].stdout.split())
        if len(successful) == 2:
            samples_ratio = statistics.median(samples["brew"])/statistics.median(samples["fastbrew"])
            ratio_key = "timing_ratio" if row["equivalent"] else "non_equivalent_timing_ratio"
            row[ratio_key] = samples_ratio
            print(f"{scenario_id}: brew {statistics.median(samples['brew']):.1f} ms, fastbrew {statistics.median(samples['fastbrew']):.1f} ms, {samples_ratio:.2f}x; stdout_equal={row['stdout_equal']}", flush=True)
        else:
            print(f"{scenario_id}: incompatible; exit codes {[row['clients'][n]['returncode'] for n in tools]}", flush=True)
        report["scenarios"].append(row)
        args.output.write_text(json.dumps(report, indent=2)+"\n")


if __name__ == "__main__":
    main()

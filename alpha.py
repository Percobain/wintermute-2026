#!/usr/bin/env python3

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
CHALLENGES = os.path.join(ROOT, "challenges")


def die(message):
    print("error: " + message)
    sys.exit(2)


def challenge_ids():
    if not os.path.isdir(CHALLENGES):
        return []
    found = []
    for name in sorted(os.listdir(CHALLENGES)):
        if os.path.isfile(os.path.join(CHALLENGES, name, "challenge.json")):
            found.append(name)
    return found


def resolve(prefix):
    matches = [c for c in challenge_ids() if c == prefix or c.startswith(prefix + "-")]
    if not matches:
        die("no such challenge: " + prefix)
    if len(matches) > 1:
        die("ambiguous challenge: " + prefix + " (" + ", ".join(matches) + ")")
    return matches[0]


def load(cid):
    with open(os.path.join(CHALLENGES, cid, "challenge.json"), encoding="utf-8") as f:
        return json.load(f)


def normalize(value, fmt):
    text = " ".join(value.split()).lower()
    if fmt in ("address", "tx_hash"):
        text = text.replace(" ", "")
        if not text.startswith("0x"):
            text = "0x" + text
    elif fmt == "set":
        items = [" ".join(p.split()) for p in text.split(",")]
        text = ", ".join(sorted(p for p in items if p))
    return text


def malformed(value, fmt):
    if fmt == "address":
        return re.fullmatch(r"0x[0-9a-f]{40}", value) is None
    if fmt == "tx_hash":
        return re.fullmatch(r"0x[0-9a-f]{64}", value) is None
    return value == ""


def digest(value):
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def read_answers(cid):
    path = os.path.join(CHALLENGES, cid, "answer.txt")
    answers = {}
    if not os.path.isfile(path):
        return answers
    with open(path, encoding="utf-8-sig") as f:
        for line in f:
            line = line.split("#", 1)[0].strip()
            if "=" not in line:
                continue
            key, _, value = line.partition("=")
            answers[key.strip()] = value.strip()
    return answers


def env_value(key):
    path = os.path.join(ROOT, ".env")
    if os.path.isfile(path):
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line.startswith(key + "="):
                    return line.split("=", 1)[1].strip().strip('"').strip("'")
    return os.environ.get(key, "")


def check_analysis(cid, meta):
    answers = read_answers(cid)
    scored = 0
    total = 0
    for part in meta["parts"]:
        key = part["key"]
        fmt = part["format"]
        total += part["points"]
        raw = answers.get(key, "")
        if raw == "":
            print("  %-18s blank" % key)
            continue
        value = normalize(raw, fmt)
        if malformed(value, fmt):
            print("  %-18s not a valid %s: %s" % (key, fmt, value))
            continue
        if digest(value) == part["hash"]:
            print("  %-18s correct" % key)
            scored += part["points"]
        else:
            print("  %-18s wrong (read as: %s)" % (key, value))
    return scored, total


def check_code(cid, meta):
    forge = shutil.which("forge")
    if forge is None:
        print("  forge not found on PATH, see GETTING-STARTED.md")
        return 0, meta["points"]
    for var in ["ETH_RPC_URL"] + meta.get("env", []):
        if env_value(var) == "":
            print("  %s is not set, copy .env.example to .env and fill it in" % var)
            return 0, meta["points"]
    test = "challenges/" + cid + "/Solution.t.sol"
    result = subprocess.run(
        [forge, "test", "--match-path", test, "--match-test", "test_Solution", "-vv"],
        cwd=ROOT,
    )
    if result.returncode == 0:
        return meta["points"], meta["points"]
    return 0, meta["points"]


def check_one(cid):
    meta = load(cid)
    print("%s  [%s, tier %d]" % (cid, meta["type"], meta["tier"]))
    if meta["type"] == "analysis":
        scored, total = check_analysis(cid, meta)
    else:
        scored, total = check_code(cid, meta)
    print("  %d/%d points" % (scored, total))
    print("")
    return scored, total


def cmd_list():
    print("%-26s %-9s %-5s %s" % ("id", "type", "tier", "points"))
    for cid in challenge_ids():
        meta = load(cid)
        if meta["type"] == "analysis":
            points = sum(p["points"] for p in meta["parts"])
        else:
            points = meta["points"]
        print("%-26s %-9s %-5d %d" % (cid, meta["type"], meta["tier"], points))
    print("")
    print("solve them in order; run 'python alpha.py check' to score yourself")


def cmd_check(args):
    targets = [resolve(a) for a in args] if args else challenge_ids()
    scored = 0
    total = 0
    for cid in targets:
        got, out_of = check_one(cid)
        scored += got
        total += out_of
    print("total: %d/%d points" % (scored, total))
    return 0 if scored == total else 1


USAGE = """usage: python alpha.py <command>

  list                     show every challenge
  check [challenge ...]    score your answers, or everything if given no arguments
"""


def main(argv):
    if not argv:
        print(USAGE)
        return 0
    command, args = argv[0], argv[1:]
    if command == "list":
        return cmd_list()
    if command == "check":
        return cmd_check(args)
    print(USAGE)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]) or 0)

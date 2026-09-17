#!/usr/bin/env python3
"""
Minimal agent-oriented Swift obfuscator: renames type and function declarations
(and their references) deterministically. Variables/properties are left untouched.

It does NOT edit control flow, expressions, strings, or comments' meaning.
It masks string literals so identifiers inside them are never rewritten.

The compiler is the safety net: this script only APPLIES a plan. The SKILL.md
drives build/test/revert. Run --dry-run first, inspect the plan, then apply.

Usage:
  python obfuscate.py <src_dir> --salt <project-salt> --dry-run
  python obfuscate.py <src_dir> --salt <project-salt> --apply
"""
import argparse
import hashlib
import json
import os
import re
import sys

# --- Names we never rename: framework protocol methods / lifecycle / entry points.
# Renaming these compiles-but-misbehaves (e.g. Codable auto-synthesis) or breaks
# framework wiring, so the build loop would NOT always catch them. Exclude up front.
DENY_FUNC = {
    "encode", "hash", "description", "debugDescription", "callAsFunction",
    "viewDidLoad", "viewWillAppear", "viewDidAppear", "viewWillDisappear",
    "viewDidDisappear", "viewDidLayoutSubviews", "prepare", "draw",
    "application", "scene", "sceneDidBecomeActive", "sceneWillResignActive",
    "makeUIView", "updateUIView", "makeUIViewController", "updateUIViewController",
    "makeCoordinator", "body", "main",
}
# --- Project narrowing (billing-demo). Unique methods invoked via dotted member
# access (instance.method(...)). The regex applier rewrites a func *declaration*
# and its implicit-self calls, but its (?<![\w.]) lookbehind deliberately skips
# dotted call sites, so renaming these breaks the build. The build oracle flagged
# them; narrowed per SKILL.md "add it to DENY_FUNC ... then re-run".
DENY_FUNC_PROJECT = {
    "renewalPrice", "renew", "selectorName",
}
SKIP_MODIFIER = re.compile(
    r"(?:^|\s)(?:override|dynamic|@objc|@IBAction|@IBOutlet|@IBDesignable"
    r"|@IBInspectable|@_dynamicReplacement|@objcMembers)\b"
)
PUBLIC_MOD = re.compile(r"(?:^|\s)(?:public|open)\s")
TYPE_DECL = re.compile(
    r"\b(?:final\s+|public\s+|open\s+|internal\s+|private\s+|fileprivate\s+|@\w+\s+)*"
    r"(class|struct|enum|actor|protocol)\s+([A-Z]\w*)"
)
FUNC_DECL = re.compile(r"\bfunc\s+([a-zA-Z_]\w*)\s*[(<]")
STRING_LIT = re.compile(r'"""(?:.|\n)*?"""|"(?:\\.|[^"\\])*"')


def swift_files(root):
    for dp, _, fns in os.walk(root):
        if "/.build" in dp or "/DerivedData" in dp or "/.git" in dp:
            continue
        for fn in fns:
            if fn.endswith(".swift"):
                yield os.path.join(dp, fn)


def det_name(salt, kind, fqn, taken):
    h = hashlib.sha256(f"{salt}|{kind}|{fqn}".encode()).hexdigest()
    prefix = "T" if kind == "type" else "f"
    for n in range(5, 20):
        cand = prefix + h[:n]
        if cand not in taken:
            taken.add(cand)
            return cand
    raise RuntimeError("could not allocate unique name")


def is_test_file(path):
    return "Tests" in path.split(os.sep) or path.endswith("Tests.swift")


def build_inventory(files):
    """Return (type_names, func_counts, func_skip) with reasons for skips."""
    type_decls = {}          # name -> [paths]
    func_decls = {}          # name -> count of declarations
    func_skip = {}           # name -> reason (if any decl must be skipped)

    for path in files:
        text = open(path, encoding="utf-8", errors="replace").read()
        for line in text.splitlines():
            for m in TYPE_DECL.finditer(line):
                name = m.group(2)
                type_decls.setdefault(name, []).append(path)
                if PUBLIC_MOD.search(line):
                    func_skip.setdefault("__type__" + name, "public/open")
                if "@main" in line:
                    func_skip.setdefault("__type__" + name, "@main")
            for m in FUNC_DECL.finditer(line):
                name = m.group(1)
                func_decls[name] = func_decls.get(name, 0) + 1
                if name in DENY_FUNC:
                    func_skip[name] = "framework/protocol method"
                elif name in DENY_FUNC_PROJECT:
                    func_skip[name] = "dotted call site (regex applier limitation)"
                elif SKIP_MODIFIER.search(line):
                    func_skip[name] = "override/@objc/IB/dynamic"
                elif PUBLIC_MOD.search(line):
                    func_skip[name] = "public/open"
                elif name.startswith("test") and is_test_file(path):
                    func_skip[name] = "XCTest method"
    return type_decls, func_decls, func_skip


def plan(files, salt):
    type_decls, func_decls, func_skip = build_inventory(files)
    taken = set()
    rename = {}   # old -> new
    kinds = {}    # old -> "type"|"func"
    skipped = []

    for name in sorted(type_decls):
        reason = func_skip.get("__type__" + name)
        if reason:
            skipped.append((name, "type", reason))
            continue
        if len(type_decls[name]) > 1:
            skipped.append((name, "type", "declared in multiple files"))
            continue
        rename[name] = det_name(salt, "type", name, taken)
        kinds[name] = "type"

    for name, count in sorted(func_decls.items()):
        reason = func_skip.get(name)
        if reason:
            skipped.append((name, "func", reason))
            continue
        if count > 1:
            skipped.append((name, "func", "overloaded / non-unique name"))
            continue
        if name in rename:            # collides with a type name space
            skipped.append((name, "func", "name shared with a type"))
            continue
        rename[name] = det_name(salt, "func", name, taken)
        kinds[name] = "func"

    return rename, kinds, skipped


def apply_to_text(text, rename):
    """Replace identifiers by word boundary, but never inside string literals."""
    masks = []

    def mask(m):
        masks.append(m.group(0))
        return f"\x00{len(masks) - 1}\x00"

    masked = STRING_LIT.sub(mask, text)
    # Longest names first for extra safety against substring overlap.
    for old in sorted(rename, key=len, reverse=True):
        masked = re.sub(rf"(?<![\w.]){re.escape(old)}\b", rename[old], masked)
    return re.sub(r"\x00(\d+)\x00", lambda m: masks[int(m.group(1))], masked)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("--salt", required=True)
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    if not args.apply and not args.dry_run:
        ap.error("pass --dry-run or --apply")

    files = list(swift_files(args.src))
    if not files:
        print(f"no .swift files under {args.src}", file=sys.stderr)
        sys.exit(1)

    rename, kinds, skipped = plan(files, args.salt)
    n_types = sum(1 for k in kinds.values() if k == "type")
    n_funcs = sum(1 for k in kinds.values() if k == "func")

    print(f"files scanned         : {len(files)}")
    print(f"types to rename       : {n_types}")
    print(f"functions to rename   : {n_funcs}")
    print(f"skipped (kept as-is)  : {len(skipped)}")
    if args.dry_run:
        print("\n-- rename plan --")
        for old in sorted(rename):
            print(f"  {kinds[old]:4} {old}  ->  {rename[old]}")
        print("\n-- skipped --")
        for name, kind, reason in sorted(skipped):
            print(f"  {kind:4} {name}  ({reason})")
        return

    for path in files:
        text = open(path, encoding="utf-8", errors="replace").read()
        new = apply_to_text(text, rename)
        if new != text:
            open(path, "w", encoding="utf-8").write(new)

    os.makedirs(os.path.join(args.src, ".agent"), exist_ok=True)
    mp = os.path.join(args.src, ".agent", "map.json")
    payload = {
        "version": 1,
        "salt": args.salt,
        "note": "Trusted-agent recovery map. Do NOT ship in production artifacts.",
        "symbols": {new: {"original": old, "kind": kinds[old]}
                    for old, new in rename.items()},
        "skipped": [{"name": n, "kind": k, "reason": r} for n, k, r in skipped],
    }
    json.dump(payload, open(mp, "w"), indent=2, ensure_ascii=False)
    print(f"\napplied. map written to {mp}")


if __name__ == "__main__":
    main()

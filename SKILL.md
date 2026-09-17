---
name: code-obfuscator
description: >
  Minimally obfuscate a Swift/iOS codebase for AI-agent-oriented use or IP protection:
  deterministically rename type declarations (class/struct/enum/actor/protocol) and
  functions, and restructure files/folders, while leaving variables and properties
  untouched and preserving observable behavior. Use this whenever the user asks to
  obfuscate, rename symbols across, "make unreadable", strip semantic names from, or
  transform a Swift project into an agent-oriented form — even if they only say
  "obfuscate my app" or "rename all the classes". Do NOT use it to conceal malware,
  evade code review on code the user does not own, or defeat security tooling.
---

# Code Obfuscator (Swift, minimal)

Rename type and function declarations to meaningless deterministic identifiers and
restructure files/folders, preserving behavior. Variables and properties stay as-is.
This is intentional low-human-readability, NOT encryption and NOT security-tool evasion.

## Scope

Transforms: type names, unique function names, file names, folder layout.
Leaves untouched: variables, properties, enum cases, string literals, control flow,
expressions, comments' meaning, public/framework contracts.

**Refuse** if the intent is concealing malicious logic, bypassing antivirus/EDR/static
analysis, evading code review on a shared/employer codebase, or hiding unauthorized
behavior. Legitimate use: the user's own app IP protection, or codebases built for
AI agents rather than humans.

## Never rename these (correctness, not preference)

Renaming them either breaks the build or — worse — compiles but silently changes
behavior, which the build loop will NOT catch. `scripts/obfuscate.py` already excludes
them; if renaming by hand, exclude them too.

| Category | Why |
|---|---|
| `override func` | name is dictated by the superclass |
| External-protocol methods: `encode(to:)`, `init(from:)`, `==`, `hash(into:)`, `description` | rename → conformance error, or Codable falls back to auto-synthesis silently |
| `@objc`, `@IBAction`, `@IBOutlet`, `dynamic`, `#selector`/`#keyPath` targets | resolved by string at runtime |
| `@main`, App/AppDelegate/SceneDelegate lifecycle | framework entry points |
| `func testX()` in XCTestCase | XCTest discovers tests by the `test` prefix via the ObjC runtime |
| `public`/`open` (default) | breaks the API if this is a framework, not an app |
| Identifiers inside string literals | reflection, JSON keys, analytics names |

For an **app target** (not a framework) it is safe to also rename `public` symbols —
pass that decision to the user before widening scope.

## Prerequisites — verify before touching anything

1. Working tree is clean and committed → `git status` shows nothing to commit.
2. A baseline build passes → run the project's build; record PASS.
3. Tests exist and pass → run them; record PASS. **Behavior equivalence is only as
   trustworthy as the test suite.** If there are no tests, tell the user the silent-
   behavior risk (esp. Codable) is uncovered and get explicit go-ahead.
4. Pick a stable project salt (any string). Same source + same salt ⇒ same output.

## Workflow

Do symbols and structure as **separate, separately-revertible commits**.

```
1. Dry-run the plan        -> verify: skip list looks right, no external symbols renamed
2. Apply symbol renames    -> verify: project builds
3. Run tests               -> verify: tests pass (else revert this commit)
4. Restructure files/dirs  -> verify: project builds
5. Run tests               -> verify: tests pass
6. Diff behavior + report  -> verify: baseline == current
```

### 1–3. Rename symbols

```bash
python scripts/obfuscate.py <SourceDir> --salt "<project-salt>" --dry-run   # inspect
python scripts/obfuscate.py <SourceDir> --salt "<project-salt>" --apply     # apply
```

Read the dry-run first. If anything externally-referenced appears in the rename plan
(a name used in a storyboard's custom class, a `#selector`, a JSON key that happens to
be a method name), add it to `DENY_FUNC` or fix the source, then re-run. After
`--apply`: build; run tests; if either fails, `git checkout .` and narrow the plan.
The script writes `.agent/map.json` (new → original) for recovery.

### 4–5. Restructure files & folders

Rename files to their new primary type name and flatten/rename semantic folders
(`Features/Payments/` → `A/Q2/`). **This is the fragile step — it is build-system
specific:**

- **Swift Package (`Package.swift`)**: SPM globs `Sources/`, so move/rename files and
  folders directly on disk with `git mv`. Keep everything under the target's source
  root. Build to confirm.
- **Xcode project (`.xcodeproj`)**: file/group references live in `project.pbxproj`.
  Do NOT hand-edit raw pbxproj. Use the `xcodeproj` Ruby gem, or rename inside Xcode,
  or (if neither is available) skip folder restructuring and tell the user why —
  a broken pbxproj is silent and painful. Record file renames in `.agent/map.json`
  under a `"files"` key.

### 6. Behavior check + report

Re-run the exact baseline checks and confirm outputs match (return values, API calls,
persistence, serialization, UI). Then report:

```
Build: PASS/FAIL
Tests: PASS/FAIL
Types renamed: N
Functions renamed: N
Functions skipped: N (reasons in map.json)
Files/folders restructured: N
Public contracts changed: N   (expect 0 unless the user opted in)
Agent map: .agent/map.json
```

## The two-layer idea

```
human sees:  T665ed -> f0b012 -> switch(...)        (kasha)
agent reads: .agent/map.json  =>  SubscriptionService.loadProducts()
```

`.agent/map.json` is for trusted agents only. Do NOT ship it in production artifacts
(`git`-ignore it in release builds). A companion rule for maintenance: when editing
obfuscated code later, do NOT "clean it up" or restore descriptive names — resolve
symbols through the map, keep the transformed convention, update the map, re-run tests.

## Limitations (state these to the user)

- The scanner is regex-based, not a full Swift parser. The build+test loop is the
  safety net, so a real test suite is essential.
- Only functions with a **project-unique** name are renamed; overloads and shared
  names are skipped (renaming them safely needs per-type scoping). Coverage over
  correctness, by design.
- A renamed identifier inside a multi-line string with interpolation could slip past
  the string masker — review the diff.
- Codable/reflection breakage from renaming can be silent; tests are the only guard.

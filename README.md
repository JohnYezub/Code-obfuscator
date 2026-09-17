# Code Obfuscator Skill

> Minimally obfuscate a Swift/iOS codebase for **AI-agent-oriented use or IP protection** —
> deterministically rename type and function declarations and restructure files/folders,
> while preserving observable behavior.

A [Claude](https://claude.com/claude-code) skill. It renames **types** (`class` / `struct`
/ `enum` / `actor` / `protocol`) and **project-unique functions** to meaningless,
deterministic identifiers, then flattens your folder layout — leaving variables, properties,
string literals, control flow, and public contracts untouched.

This is intentional **low-human-readability**, not encryption and not security-tool evasion.

```
human sees:   struct Tdc9c0 { func fd087e(for plan: Tbecb8, months: Int) -> Double }
agent reads:  .agent/map.json  ⇒  PricingEngine.renewalPrice(for:months:)
```

---

## Why?

- **Ship codebases meant for agents, not humans.** Descriptive names are for people; a
  trusted agent resolves symbols through `.agent/map.json` instead.
- **Light IP protection** for your own app's source.
- **Deterministic:** same source + same salt ⇒ same output, every run.

**Not for:** concealing malware, bypassing antivirus/EDR/static analysis, evading code review
on a shared/employer codebase, or hiding unauthorized behavior. The skill refuses these.

---

## Install

Drop the skill where Claude Code discovers skills (e.g. `~/.claude/skills/code-obfuscator/`):

```
code-obfuscator/
├── SKILL.md
└── scripts/
    └── obfuscate.py
```

Then just ask Claude:

> "obfuscate my app" · "rename all the classes" · "strip semantic names from this package"

Or run the applier directly (Python 3, no dependencies):

```bash
python3 scripts/obfuscate.py <SourceDir> --salt "<project-salt>" --dry-run   # inspect
python3 scripts/obfuscate.py <SourceDir> --salt "<project-salt>" --apply     # apply
```

`--apply` writes `.agent/map.json` (new → original) for recovery. The **compiler is the safety
net**: the script only applies a plan — you drive build / test / revert around it.

---

## What gets transformed

| Transformed | Left untouched |
|---|---|
| Type names | Variables, properties, enum cases |
| Project-unique function names | String literals (JSON keys, reflection, analytics) |
| File names | Comments, control flow, expressions |
| Folder layout | Public / framework contracts (by default) |

### Never renamed — correctness, not preference

Renaming these breaks the build or, worse, **compiles but silently changes behavior** (which
a build alone won't catch). The applier excludes them up front:

| Category | Why |
|---|---|
| `override func` | name is dictated by the superclass |
| `encode(to:)`, `init(from:)`, `==`, `hash(into:)`, `description` | Codable/protocol conformance — rename → error or silent auto-synthesis |
| `@objc`, `@IBAction`, `@IBOutlet`, `dynamic`, `#selector` / `#keyPath` targets | resolved by string at runtime |
| `@main`, App/AppDelegate/SceneDelegate | framework entry points |
| `func testX()` in XCTestCase | XCTest discovers tests by the `test` prefix |
| `public` / `open` (default) | breaks the API if this is a framework |
| identifiers inside string literals | reflection, JSON keys, analytics names |
| overloaded / non-unique names | safe scoping needs a full parser (coverage over correctness) |

---

## Workflow

Symbols and structure land as **separate, separately-revertible commits**:

```
1. Dry-run the plan        → verify: skip list looks right, no external symbols renamed
2. Apply symbol renames    → verify: project builds
3. Run tests               → verify: tests pass (else `git checkout .`)
4. Restructure files/dirs  → verify: project builds
5. Run tests               → verify: tests pass
6. Diff behavior + report  → verify: baseline == current
```

**Behavior equivalence is only as trustworthy as your test suite.** No tests → the silent
Codable/reflection risk is uncovered.

---

## Example — see it end to end

The [`examples/`](examples/) folder contains the **same package before and after** the skill,
both building and passing the identical 9-test suite:

- [`examples/billing-before/`](examples/billing-before) — pristine, human-readable
- [`examples/billing-after/`](examples/billing-after) — renamed **and** restructured
- [`examples/README.md`](examples/README.md) — the full walkthrough

```bash
cd examples/billing-before && swift build && swift test   # 9 tests pass
cd ../billing-after        && swift build && swift test   # same 9 tests pass
```

### Before → after

A unique type and its private helper are renamed; the `"SubscriptionService"` **string
literal survives** even though the class *identifier* is gone:

```swift
// before — Sources/Billing/Core/SubscriptionService.swift
final class SubscriptionService {
    func renew(_ plan: Plan, months: Int) -> Double {
        let price = engine.renewalPrice(for: plan, months: months)
        lastAudit = auditLine()
        return applyFloor(price)
    }
    private func auditLine() -> String { "SubscriptionService" }   // ← literal
    private func applyFloor(_ value: Double) -> Double { max(value, 0) }
}
```

```swift
// after — Sources/Billing/Q1/Tb9f5b.swift
final class Tb9f5b {
    func renew(_ plan: Tbecb8, months: Int) -> Double {
        let price = engine.renewalPrice(for: plan, months: months)
        lastAudit = fcba7b()
        return f0b262(price)
    }
    private func fcba7b() -> String { "SubscriptionService" }      // ← unchanged
    private func f0b262(_ value: Double) -> Double { max(value, 0) }
}
```

`Codable` keeps working because the JSON contract lives in **string raw values** (masked) and
`encode(to:)` is never renamed — even when the `CodingKeys` *type* identifier changes:

```swift
// after — Sources/Billing/Q3/Tbecb8.swift
struct Tbecb8: Codable, Equatable {          // was: Plan
    enum Tcce12: String, CodingKey {         // was: CodingKeys
        case id = "plan_id"                  // raw values untouched → JSON identical
        case monthlyPrice = "monthly_price"
        case discountRate = "discount_rate"
    }
    func encode(to encoder: Encoder) throws { … }   // never renamed
}
```

### The recovery map ([`.agent/map.json`](examples/billing-after/.agent/map.json))

```json
{
  "salt": "billing-demo",
  "symbols": {
    "Tb9f5b": { "original": "SubscriptionService", "kind": "type" },
    "Tdc9c0": { "original": "PricingEngine",       "kind": "type" },
    "Tbecb8": { "original": "Plan",                "kind": "type" },
    "f0b262": { "original": "applyFloor",          "kind": "func" }
  }
}
```

> ⚠️ `.agent/map.json` is for **trusted agents only** — `git`-ignore it in release builds.

### The build oracle in action

In this example, the first apply renamed `renewalPrice` and the **build failed**: the
regex applier rewrites a function *declaration* but its `(?<![\w.])` lookbehind skips
**dotted** call sites like `engine.renewalPrice(...)`. Following the skill, the plan was
narrowed (`git checkout .`, add to the deny list, re-run) — nothing was hand-edited past the
compiler and no test was weakened. That's the skill's "coverage over correctness" rule doing
its job. Full story in [`examples/README.md`](examples/README.md).

---

## Report format

After a run the skill reports:

```
Build: PASS/FAIL
Tests: PASS/FAIL
Types renamed: N
Functions renamed: N
Functions skipped: N (reasons in map.json)
Files/folders restructured: N
Public contracts changed: N   (expect 0 unless you opted in)
Agent map: .agent/map.json
```

---

## Limitations (know these)

- The scanner is **regex-based, not a full Swift parser** — the build + test loop is the
  safety net, so a real test suite is essential.
- Only **project-unique** function names are renamed; overloads and shared names are skipped.
- A unique method called via **dotted access** (`x.method(...)`) is not rewritten at the call
  site and must be denied (see the example) — coverage over correctness, by design.
- Renamed identifiers inside multi-line interpolated strings could slip past the masker —
  review the diff.
- **Codable / reflection breakage can be silent** — tests are the only guard.

---

## Repo layout

```
.
├── SKILL.md                 # the skill definition (what Claude reads)
├── scripts/obfuscate.py     # the deterministic applier
├── examples/                # before/after Swift package + walkthrough
└── README.md
```

## License

See [LICENSE.md](LICENSE.md).

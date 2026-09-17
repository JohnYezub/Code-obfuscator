# `code-obfuscator` end-to-end example (Swift Package)

Two copies of the same Swift package that demonstrate the `code-obfuscator`
skill and **prove it preserves behavior** while renaming only the safe symbols.

| Project | State |
|---|---|
| [`billing-before/`](billing-before/) | Pristine, human-readable. Baseline build + tests pass. |
| [`billing-after/`](billing-after/) | Same package after symbol renaming **and** file/folder restructuring. Identical build + test results. |

Both are standalone SPM packages — `cd` into either and run `swift build && swift test`.

## The `Billing` domain (a subscription-pricing library)

One of every construct the skill must reason about is included on purpose, so the
exclusions are *testable*:

| Construct | Expected | Why |
|---|---|---|
| `class SubscriptionService` + private helpers `auditLine`/`applyFloor` | **renamed** | unique type + unique implicit-`self` helpers |
| `struct PricingEngine`, private `round2` | **renamed** | unique type + unique implicit-`self` helper |
| `func renewalPrice(...)`, `func renew(...)`, `func selectorName()` | **kept** (narrowed) | unique, but invoked via dotted member access — see note below |
| `struct Plan: Codable` + `enum CodingKeys` + custom `encode(to:)`/`init(from:)` | **behavior kept** | `encode` is in the deny list; JSON keys live in string raw values (masked) |
| `class Base { func tick() }` / `class Sub: Base { override func tick() }` | `tick` **kept** | `override` name is dictated by the superclass (also non-unique) |
| `final class Ticker: NSObject { @objc func fire() }` via `#selector(Ticker.fire)` | `fire` **kept** | resolved by string at runtime |
| two overloaded `func total(...)` | **kept** | non-unique name |
| `public func publicAPI(...)` | **kept** | framework/public contract |
| log string literal `"SubscriptionService"` | **kept** | identifiers inside string literals are masked |

Type identifiers *are* renamed (`SubscriptionService` → `Tb9f5b`, `Plan` → `Tbecb8`,
`CodingKeys` → `Tcce12`, …); the recovery map is in
[`billing-after/.agent/map.json`](billing-after/.agent/map.json).

## How `billing-after` was produced

From a clean copy of `billing-before`, following `SKILL.md` (each step a separate,
revertible commit; the build+test loop is the oracle):

```bash
# 1–3. Rename symbols (scan the whole package so Tests stay consistent with Sources)
python3 scripts/obfuscate.py . --salt "billing-demo" --dry-run   # inspect the plan
python3 scripts/obfuscate.py . --salt "billing-demo" --apply
swift build && swift test

# 4–5. Restructure (SPM globs Sources/, so move on disk with git mv)
git mv Sources/Billing/Core/SubscriptionService.swift Sources/Billing/Q1/Tb9f5b.swift
# …one per type… then flatten Core/Pricing/Model/Lifecycle/API into Q1…Q5
swift build && swift test
```

### Note: the narrowing (the build oracle earned its keep)

The **first** apply renamed `renewalPrice`/`renew`/`selectorName` and the build
**failed**: the regex applier rewrites a func *declaration* and its implicit-`self`
calls, but its `(?<![\w.])` lookbehind deliberately skips **dotted** call sites
(`engine.renewalPrice(...)`), so those declarations no longer matched their callers.

Per `SKILL.md` ("if either fails, `git checkout .` … add it to `DENY_FUNC` … re-run"),
the plan was narrowed: those three unique-but-dotted methods were moved to a
`DENY_FUNC_PROJECT` set in [`scripts/obfuscate.py`](billing-after/scripts/obfuscate.py).
This is the skill's documented "coverage over correctness" limitation in action —
nothing was hand-edited past the compiler, and no test was weakened.

## Behavior equivalence (before ≡ after)

Obfuscation never touches string/number literals, so the test suite's baseline
constants are byte-identical in both projects and both pass the same 9 tests:

- JSON key set: `{plan_id, monthly_price, discount_rate}`
- `renewalPrice` / `renew` / `publicAPI` = `107.89`; `total([1,2,3])` = `6.0`, `total(2,3)` = `5.0`
- override dispatch `Sub().tick()` = `2`; selector name = `"fire"`; audit log = `"SubscriptionService"`

## Skill report

```
Build: PASS
Tests: PASS (9 tests, unchanged, in both projects)
Types renamed: 8
Functions renamed: 3
Functions skipped: 17 (5 required exclusions + 3 project-narrowed + 9 XCTest methods; reasons in .agent/map.json)
Files/folders restructured: 6 files, 5 semantic folders flattened to Q1…Q5
Public contracts changed: 0
Agent map: billing-after/.agent/map.json
```

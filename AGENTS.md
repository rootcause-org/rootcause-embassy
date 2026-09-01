# AGENTS.md — maintainers-only orchestration playbook

This repo is the **hub**. Its whole point is that a contract change happens **once here** and then
fans out to every implementation, provably.

There is **no code** here. No generators, no IDL, no schemas-as-code. ≤6 languages ever and each
Embassy is ~2k LOC, so plain prose + byte-exact goldens beats codegen on both cost and durability.

## Rule 1 — every wire/behavior change starts HERE

Before touching any implementation:

1. Edit [`CONTRACT.md`](CONTRACT.md) and/or the relevant [`planes/`](planes/) file.
2. Add or update the [`fixtures/`](fixtures/) golden **and its signing vector** (see
   [`fixtures/README.md`](fixtures/README.md) — vectors are regenerated, never hand-edited).
3. Record the reasoning as a numbered entry in [`decisions.md`](decisions.md). If you resolved an
   ambiguity, it is a decision — write it down or the next agent will resolve it differently.
4. Commit. That commit SHA is what the language repos vendor.

A change that lands in a language repo first is a bug. Bring it back here before it spreads.

## Rule 2 — fan out, one subagent per repo

Spawn **one subagent per entry in [`languages.md`](languages.md)**, in parallel. The rootcause host
is one of those entries — it is not special.

Each subagent's prompt is:

> Contract change: `<the hub diff>`, hub commit `<SHA>`.
> Repo: `<path>`.
> Make the implementation conform. Re-vendor `fixtures/` from the hub at that SHA (update the recorded
> hub SHA). Run the conformance suite. Report what changed and anything the contract left ambiguous.

A new-port brief names, per plane, the reference file to read (see the repo map in each language's
`AGENTS.md`) and the deviations the hub sanctions (runtime token, tenant exposure mechanism, timeout
capability — e.g. Python cannot kill a runner thread, so its deadline is cooperative). Vendoring is a
wholesale copy of `fixtures/` at one SHA, no-newline files preserved, `HUB_SHA` written, byte parity
checked with `diff -r`.

For a **new** language repo, publication is part of done unless the task explicitly opts out:

1. Create the public GitHub repo under `rootcause-org`, matching the sibling Embassy repos.
2. Add the SSH `origin`, push the full local `main` history and set its upstream.
3. Verify local `HEAD` equals `origin/main`, the worktree is clean, and the GitHub default branch is
   `main`.

An explicit local-only / no-push instruction wins, but the subagent must report GitHub publication as
pending and [`languages.md`](languages.md) must say so. Never let a local commit read as a fully
landed implementation.

If a subagent reports an ambiguity, **resolve it here** (new decision + fixture) and re-fan; do not
let it be settled locally.

## Rule 3 — conformance = replaying the fixtures byte-for-byte

Every language repo carries a test suite that:

- **verifies** every signing vector in `fixtures/signing_vectors.json` against the exact file bytes,
- **produces** a signature over its own serialization and round-trips it through its own verifier,
- **decodes** every envelope fixture into its own types and asserts the field mapping,
- **replays** the chat JWT vector to the exact token string,
- asserts the **error table** (status ↔ `class`) and the **refusal-is-signed** rule.

A repo that cannot replay a fixture **fails CI**. That is the only enforcement mechanism this design
has, so it is not optional.

The case list is [`conformance.md`](conformance.md) — port from it, not from another language's
test file. Precedence when sources disagree: fixtures > hub prose > any reference implementation.

## Rule 4 — vendored fixtures carry the hub SHA

Each language repo's vendored copy records the hub commit it came from (a `HUB_SHA` file or an
equivalent constant next to the fixtures). The conformance test **prints** it, so drift is visible in
CI output rather than discovered in production.

Checking for drift: compare the recorded SHA against this repo's `HEAD`. A repo behind by a
fixtures-touching commit is out of conformance even if its tests pass.

## Rule 5 — the doc is the source of truth, the code is not

Do not "document what the code does" here. Decide what the wire is, write it here, then make the code
match. When you find code and contract disagreeing, the contract wins unless the code is protecting
against something the contract missed — in which case, fix the contract first.

## Style

Plain language, terse, high-signal — read by agents and humans. Lead with the delta. No changelog
prose (git holds that). No spec-section cross-references (`§4`, "see spec") — specs are throwaway,
this is not.

## Taxonomy (from the host repo — the aliases are banned)

**project** (not tenant/customer/account) · **run** (not job) · **session** (not conversation_id) ·
**thread** / **message** · **principal** (not sender/user) · **claim** · **workspace** (not sandbox) ·
**brain** · **mirror** (not repo) · **tool** (bash/reply only) · **draft** · **note** · **journal** ·
**action** (not effect; **not** an alias for tool) · **Embassy** (not gem/action-runner).

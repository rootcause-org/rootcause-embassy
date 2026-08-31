# Implementations

Every repo that speaks this contract. The fan-out in [`AGENTS.md`](AGENTS.md) spawns one subagent per
row. Local paths are under `~/code/rootcause-org/`.

| Repo | Role | Status | Runtime token | Vendored fixtures |
|---|---|---|---|---|
| `rootcause` | **host** — the other side of every plane | live | — | `internal/action/testdata/contract/` |
| `rootcause-embassy-ruby` | Ruby Embassy (Rails/Rack), gem `rootcause-embassy` | live, 0.5.x | `ruby` (in-process eval) | `spec/fixtures/contract/` |
| `rootcause-embassy-go` | Go Embassy, module `github.com/rootcause-org/rootcause-embassy-go` | live, 0.1.0 | `go` (yaegi) | `internal/contract/testdata/` |
| PHP | Laravel/Symfony Embassy | planned | `php` | — |
| `rootcause-embassy-python` | Python Embassy (Litestar/FastAPI/Django), package `rootcause_embassy`, `github.com/rootcause-org/rootcause-embassy-python` | live, 0.1.0 | `python` (via registered runner, decision 12) | `tests/contract/testdata/` |
| Node | Express/Nest Embassy | planned | `node` | — |

## Per-plane coverage

| | actions | dry_run | analysis trigger | result callback | sent-message | answers | chat mint | api plane | health |
|---|---|---|---|---|---|---|---|---|---|
| host | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | verify only | ✅ | — |
| ruby | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ |
| go | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| python | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

## Open conformance debt

**rootcause-embassy-ruby** (decisions 1–7 shipped; decision 1 reference implementation:
idempotent ack + nonce release on failed dispatch)
- `capture_sent_message` cannot send `answers[]` (host accepts them; Go sends them)
- decision 6b — verify async-analysis doc says `notes[].key` (host emits `key`, `kind` is legacy)
- decision 10 — no health endpoint (optional)
- fixtures not yet vendored from the hub

**rootcause-embassy-go** (0.1.0, hub SHA printed by conformance suite)
- reserved tenant names: matches the six exact names only (`schema.go`); the contract refuses **any**
  `rc_tenant_*` spelling (`rc_tenant_region` passes in Go, is refused in Python) — Go is out of conformance
- API plane has no conformance cases (see [`conformance.md`](conformance.md))
- yaegi caveats, documented in its README/AGENTS: script stdout only via `a.Out()` (`fmt.Println`
  escapes — no process-global redirect); deadline cancels the main frame only, scripts must not
  spawn goroutines; interpreters pooled per (digest, tenant) because pooled programs keep
  package-level state
- no CI workflow or tagged release

**rootcause-embassy-python** (0.1.0, published; hub SHA printed by conformance suite; first consumer DentAI —
chat plane live in its dashboard via the standalone `rootcause_embassy.chat` functions)
- no built-in runner (decision 12): a real invocation needs `Config.runner`; the deadline is cooperative
  (Python cannot kill a thread) — enforced at fetch and around the run, `ActionContext.deadline` for scripts
- `Config`/`Embassy` require the action plane at boot (same as Go); chat-only consumers use the module
  functions — an independent per-plane constructor is a possible DX follow-up
- Litestar/FastAPI adapter snippets in README are illustrative, not tested; no CI workflow, no tag/release

**rootcause (host)** (doc/golden cleanup shipped: `WIRE-CONTRACT.md` is a pointer here, goldens
re-vendored from hub `4f02c9f`, contract test prints the vendored SHA)
- analysis/ and chat/ fixture planes not vendored host-side (test covers `actions/` only)
- no host-side consumer of the health endpoint yet — `/rc-action-doctor` still uses the 405 probe

## Adding a language

1. Add the row above and its runtime token to [`decisions.md`](decisions.md) §8.
2. Vendor `fixtures/` + the hub SHA.
3. Implement, in this order: signing → replay → schema → resolve → execute → result envelope →
   analysis planes → chat mint → api plane → health.
4. Conformance suite per [`AGENTS.md`](AGENTS.md) rule 3, wired into CI.
5. Create the public `rootcause-org/<repo>` GitHub repo, add its SSH `origin`, push full `main`, and
   verify local `HEAD == origin/main` plus a clean worktree. If the task explicitly forbids this,
   record publication as pending in the implementation row and handoff.

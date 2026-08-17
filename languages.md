# Implementations

Every repo that speaks this contract. The fan-out in [`AGENTS.md`](AGENTS.md) spawns one subagent per
row. Local paths are under `~/code/rootcause-org/`.

| Repo | Role | Status | Runtime token | Vendored fixtures |
|---|---|---|---|---|
| `rootcause` | **host** — the other side of every plane | live | — | `internal/action/testdata/contract/` |
| `rootcause-embassy-ruby` | Ruby Embassy (Rails/Rack), gem `rootcause-embassy` | live, 0.5.x | `ruby` (in-process eval) | `spec/fixtures/contract/` |
| `rootcause-embassy-go` | Go Embassy, module `github.com/rootcause-org/rootcause-embassy-go` | planned | `go` (yaegi) | — |
| PHP | Laravel/Symfony Embassy | planned | `php` | — |
| Python | Django/FastAPI Embassy | planned | `python` (hosted mode only today) | — |
| Node | Express/Nest Embassy | planned | `node` | — |

## Per-plane coverage

| | actions | dry_run | analysis trigger | result callback | sent-message | answers | chat mint | api plane | health |
|---|---|---|---|---|---|---|---|---|---|
| host | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | verify only | ✅ | — |
| ruby | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ |
| go | — | — | — | — | — | — | — | — | — |

## Open conformance debt

**rootcause-embassy-ruby**
- decision 1 — shipped (idempotent ack + nonce release on failed dispatch); it is the reference
  implementation of that rule
- decision 2 — `Result#reasoning_steps` still exists
- decision 3 — no `executed_actions` / `questions` / `delete` accessors
- decision 4 — `start_analysis` has no `principal:` kwarg
- decision 5 — docs describe sent-message `metadata` as free-form
- decision 7 — no total (fetch + execute) deadline
- `capture_sent_message` cannot send `answers[]`
- decision 6b — async-analysis doc says `notes[].kind`, host emits `notes[].key`
- decision 10 — no health endpoint (optional)
- fixtures not yet vendored from the hub
- stale skill doc `.agents/skills/embassy-action-runner/SKILL.md` points at pre-rename paths

**rootcause (host)**
- `WIRE-CONTRACT.md` should shrink to a pointer here + a host-specific file map
- dead file refs in `WIRE-CONTRACT.md` and `.agents/commands/rc-action-doctor.md`
  (`internal/actionhttp`, `internal/action/service.go`) — real:
  `internal/web/customer/action.go`, `internal/actionexec/service.go`
- `.agents/skills/actions/execution-modes.md` — digest drift WARNs and executes, it does not refuse
- golden `result_refusal.json` still carries `Rootcause::SchemaViolation` (decision 6)
- contract test should print the vendored hub SHA

## Adding a language

1. Add the row above and its runtime token to [`decisions.md`](decisions.md) §8.
2. Vendor `fixtures/` + the hub SHA.
3. Implement, in this order: signing → replay → schema → resolve → execute → result envelope →
   analysis planes → chat mint → api plane → health.
4. Conformance suite per [`AGENTS.md`](AGENTS.md) rule 3, wired into CI.

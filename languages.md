# Implementations

Every repo that speaks this contract. The fan-out in [`AGENTS.md`](AGENTS.md) spawns one subagent per
row.

| Repo | Role | Status | Runtime token | Vendored fixtures |
|---|---|---|---|---|
| `rootcause` | **host** — the other side of every plane | live | — | private conformance fixtures |
| `rootcause-embassy-ruby` | Ruby Embassy (Rails/Rack), gem `rootcause-embassy` | v0.12.0 (hub 6d2c818, consumed from git main); action/analysis/chat/API parity + typed diagnostics; `credentials` claim pending | `ruby` (in-process eval) | `spec/fixtures/contract/` |
| `rootcause-embassy-go` | Go Embassy, module `github.com/rootcause-org/rootcause-embassy-go` | live, 0.5.0 (hub 6d2c818) | `go` (yaegi) | `internal/contract/testdata/` |
| PHP | Laravel/Symfony Embassy | planned | `php` | — |
| `rootcause-embassy-python` | Python Embassy (Litestar/FastAPI/Django), package `rootcause_embassy`, `github.com/rootcause-org/rootcause-embassy-python` | live, 0.3.0 (hub 6d2c818); `credentials` claim pending | `python` (via registered runner, decision 12) | `tests/contract/testdata/` |
| Node | Express/Nest Embassy | planned | `node` | — |

## Per-plane coverage

| | actions | dry_run | analysis trigger | result callback | sent-message | answers | chat mint | chat `credentials` | api plane | health |
|---|---|---|---|---|---|---|---|---|---|---|
| host | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | verify only | verify + inject | ✅ | — |
| ruby | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | pending | ✅ | ✅ |
| go | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ ¹ | ✅ |
| python | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | pending | ✅ | ✅ |

¹ Go implements the API plane; its API-plane conformance cases are not ported yet.

## Adding a language

1. Add the row above and its runtime token to [decision 8](decisions.md#8-runtime-tokens).
2. Vendor `fixtures/` + the hub SHA.
3. Implement, in this order: signing → replay → schema → resolve → execute → result envelope →
   analysis planes → chat mint → api plane → health.
4. Conformance suite per [`AGENTS.md`](AGENTS.md) rule 3, wired into CI.
5. Create the public `rootcause-org/<repo>` GitHub repo, add its SSH `origin`, push full `main`, and
   verify local `HEAD == origin/main` plus a clean worktree. If the task explicitly forbids this,
   record publication as pending in the implementation row and handoff.

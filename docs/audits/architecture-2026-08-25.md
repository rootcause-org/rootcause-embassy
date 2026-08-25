# Architecture audit — rootcause-embassy (hub) + embassy-ruby + embassy-go — 2026-08-25

Intent sources: hub `AGENTS.md` (rules 1–5), `CONTRACT.md`, `planes/*.md`, `decisions.md`, `languages.md`,
`fixtures/README.md` · ruby `AGENTS.md`, `SPEC.md`, `.agents/skills/embassy-action-runner/SKILL.md` ·
go `AGENTS.md`, `README.md`.
Scope: hub `2b61567` · ruby `9dda6f4` · go `5f6c1f2` — all three clean, fetched, already at upstream.
Not audited: `rootcause` host row of `languages.md` (out of scope). Nothing left untimed: both suites run
without infra (Ruby under WebMock, Go pure stdlib+yaegi).

Method: `loc/deps/excess/test_stats/hotspots/lint_rules.py` on both impls; suites timed; one Opus
sub-agent per repo + one cross-impl agent; every claim below re-opened in source by the orchestrator.
Script false positives dropped: Ruby's 40 "no-assert" tests are all `expect { }.to raise_error` (0 real);
Go's `ActionAPI` "wide 1-impl interface" is the script-facing API exported into yaegi (`executor.go:246`),
not a substitution port.

## Headline

Both Embassies implement the same pipeline with a near 1:1 file mapping and stay on the "~2k LOC,
no codegen" thesis (ruby lib 1526 LOC, go 2216). **Go is in conformance** (fixtures byte-identical to
hub, `HUB_SHA` = hub HEAD, suite covers rule 3 except the `500 internal_error` row).
**Ruby is not**: no hub fixtures, no `HUB_SHA`, its "contract" spec replays four pre-hub goldens that
contradict pinned decisions. The hub itself has one live 401/409 contradiction and both impls made the
*same* local resolution against decision 6b — a signal the decision, not the code, is wrong.

## Findings (ranked)

### 1. Ruby has no conformance suite in the hub's sense (rule 3/4 unmet)
Evidence: `rootcause-embassy-ruby/spec/fixtures/contract/` holds only `invocation.json`,
`invocation_dry_run.json`, `invocation_schema_violation.json`, `fetch_response.json`; `grep -r HUB_SHA` = 0;
`spec/contract/wire_spec.rb:5` "see WIRE-CONTRACT.md in rootcause-light"; no signing-vector replay, no
analysis/chat envelope decode, no error-table assertion. The vendored goldens contradict the hub:
`invocation.json` carries `"dry_run":false` (hub `planes/actions.md:52`: emitted iff true) and the nil-UUID
`project_id` (`decisions.md:200` rejects it). `languages.md:9` says fixtures live at `spec/fixtures/contract/`
while `languages.md:30` says "not yet vendored" — both half-true.
Why it hurts: the hub's *only* enforcement mechanism is absent for the reference implementation.
Proposed seam: delete `spec/fixtures/contract/`, vendor hub `fixtures/` + `HUB_SHA`, rewrite `wire_spec.rb`
as a vector replayer mirroring `rootcause-embassy-go/internal/contract/contract_test.go` (verify vectors
`:111`, own-sign round-trip `:872`, decode `:628`, JWT `:878`, error table `:419-541`, refusal-signed
`:544/:555`, 405 unsigned `:587`). Blocker: Ruby cannot replay the chat JWT vector today — `chat.rb:78`
hard-codes `"jti" => SecureRandom.uuid`; add a `jti:` kwarg next to the existing `now:` (`chat.rb:61`).
Blast radius: spec-only + 1 kwarg.

### 2. Hub: stale `issued_at` is 401 in the analysis plane, 409 in CONTRACT
`CONTRACT.md:62` (409 `replay`, "both routes") vs `planes/analysis.md:65` ("`401` bad signature or stale
`issued_at`"). Commit `2b61567` touched CONTRACT/decisions/languages only. Both impls already do 409
(`replay.rb:27-30`, `replay.go:62-69`). Fix the plane doc; add a stale-`issued_at` refusal fixture (today
`result_refusal_replay.json` pins only the nonce branch).

### 3. Both impls accept legacy `notes[].kind`; decision 6b says "fall back to nothing"
`decisions.md:100-102` · ruby `result.rb:126` `(node[:key] || node[:kind])` · go `result.go:120`
`Kind string \`json:"kind"\`` (used `:147`). Two-for-two identical local resolution → amend 6b to permit
the fallback (and pin a fixture) **or** file conformance debt against both. Rule 1: decide here first.
Ruby's own test data still uses the legacy spelling as the primary path (`spec/support/wire.rb:151-152`);
`docs/async-analysis-spec.md:168,172,245` still documents `kind` — the exact item `languages.md:28` flags.

### 4. Ruby: the Rack shell is cloned verbatim, and the signed-endpoint core twice more
`rack.rb:14-56` vs `result_rack.rb:160-202`: body-read, 405 literal (`rack.rb:55` == `result_rack.rb:201`),
`content-type`+signature header assembly identical except `runner`/`receiver` identifiers. Core clone:
`authenticate` `runner.rb:90-96` == `result_rack.rb:46-52`; `reply` `runner.rb:216-219` ==
`result_rack.rb:127-130` (ResultReceiver already reaches into `Runner::Reply`); 500 backstop
`runner.rb:66` == `result_rack.rb:40`. Go already has this seam (`writeSigned` `action.go:251-261` reused
`resultroute.go:41`; one `writeMethodNotAllowed` `action.go:242-247`).
Why it hurts: contract surface (405 floor `decisions.md:107`, signed refusals) maintained in two places.
Seam: `Embassy::RackShell` (handler accessor param) + `Embassy::SignedEndpoint` owning
authenticate/parse(required:)/reply/rescue; `Reply` moves out of `Runner`. ~80 LOC out, 3 files.

### 5. Ruby cannot send `answers[]`; no aggregate attachment cap
`client.rb:95` hard-raises on blank `sent_body`, no `answers:` kwarg → the answers-only golden
(`fixtures/analysis/answers.json`, `planes/analysis.md:155-157`) is unreachable; `result.rb:26` tells the
reader to POST answers anyway. Go: `client.go:120`, `:207-209` ("SentBody or Answers"). Ruby also lacks the
6 MiB total cap (`planes/analysis.md:54`; go `client.go:16`; ruby only per-attachment `client.rb:153`).
Also: `client.rb:108` passes `metadata` verbatim while `client_spec.rb:249,343` send `resource_id: 42` as
Integer — the host strict-decodes strings (`decisions.md:73`), so the spec pins a body the host rejects.

### 6. `project_id` not required in either impl, contract says "always present"
`planes/actions.md:51` · ruby `runner.rb:18` `REQUIRED_FIELDS` · go `action.go:222-226`. Missing field
surfaces as `502 resolve_failed` (host answers 404) instead of `400 invalid_request` (`CONTRACT.md:60`).
Two-for-two again → hub decision: either add `project_id` to required or say tolerant-inbound permits it.

### 7. Go: freshness refusal message swaps skew and drift
`replay.go:69` `"issued_at outside ±%ds window (skew=%ds)"` with `(skew, drift)` → a 1h-off clock prints
`skew=3600s`. Message-only, ungoldened. Fix labels; a `printf`-style vet directive on the `errors.go:32-53`
constructors would catch this class.

### 8. Go: process-global token cache
`apiauth.go:42-45` `tokenCache` map + mutex, written `:55,:63`, never evicted, per-process not per-Embassy;
tests need `invalidateToken` for isolation (`api_test.go:51,:96`). Only package-level mutable state in the
repo (interpreter pool is per-executor `executor.go:99-103`, nonce store per-Config `config.go:152`). Move
onto `*API` (`api.go:51` `newAPI`) — `APIFor` already gives per-project instances. ~20 LOC out.

### 9. Ruby: one process-wide execution mutex, taken unconditionally
`executor.rb:27` `PROCESS_EXECUTION_MUTEX`, held at `:42` around compile+timeout+run, even for flat
invocations (no `RC_TENANT_*` env swap, `executor.rb:26`) and when stdout capture is off (`:133`).
`decisions.md:149` sanctions the mutex for the ENV dance only. Second concurrent invocation queues and then
trips `total_deadline` (`runner.rb:40`) with a misleading "exceeded 22s" message. Needs a deliberate call.

### 10. Ruby: local rules the hub never decided
`runner.rb:20-21` `TENANT_SLUG_PATTERN`, `NIL_UUID` enforced `:187-192`; `planes/actions.md:57-66` pins
all-or-nothing/reserved names/NUL but not slug charset or nil-UUID. Go has the NUL guard (`tenant.go:59-65`),
Ruby does not. Rule 1: promote to a numbered decision + fixture, or drop.

### 11. Hub prose gaps (each an implementer decides locally today)
- Error table has fixtures for 4 of 7 classes (`fixtures/README.md:77` "four refusal fixtures");
  `invalid_request`, `handler_error`, `internal_error`, `method_not_allowed` unpinned; Go's suite therefore
  never asserts `500 internal_error` (only unasserted row).
- Decision 1 (idempotent ack + nonce release) has no golden pinning the state machine; `result_ack.json`
  pins bytes only.
- `analysis/trigger_response.json` is the one signed-body golden without a signing vector.
- `CONTRACT.md:16-22` "three keys" omits `api_key` (`planes/api.md:10`, `CONTRACT.md:14`).
- Decision 8 closes `runtime` to `ruby|go|python` (`decisions.md:132`); `languages.md:11,13` list `php`,`node`.
- Health golden `fixtures/actions/health_response.json` says `"embassy":"ruby"` — Ruby has no health
  endpoint; Go string-substitutes it (`contract_test.go:620`).
- Stdout cap "is the convention" (`actions.md:107`), no truncation marker; both impls silently slice
  (`executor.rb:145-151`, `executor.go:299`). Client-side attachment cap unstated; both chose 256 KiB
  (`config.rb:137`, `config.go:149-150`) vs host 4 MiB. Sent-message `type` never enumerated.
- Rule 4 drift check is "fixtures-touching commit" (`AGENTS.md:56-57`) — `2b61567` was prose-only and
  changed wire semantics; extend to contract-touching.
- Style violations of its own rule (`AGENTS.md:66-69`): §-refs at `planes/actions.md:17`,
  `planes/analysis.md:44,114`, `decisions.md:79,171,197`, `languages.md:46`; changelog prose
  `decisions.md:190-202` (reconciliation table), `:95-98`, `:37-38`, `languages.md:39-40`.

### 12. Minor / hygiene
- Ruby `errors.rb:15` `def code = "error"` — invents a class outside the closed vocabulary
  (`CONTRACT.md:56`); unreachable today, make abstract.
- Ruby `schema.rb:73,80-87` accepts JSON-Schema `properties` shape the contract forbids
  (`planes/actions.md:47` "never an array… only type and required"). Dead branch + `schema_spec.rb:81-90`.
- Ruby helpers duplicated: `blank?` ×5 (`config.rb:222`, `api.rb:231`, `chat.rb:167`, `client.rb:256`,
  `result.rb:129` — two different definitions), `present?` ×3, `Process.clock_gettime` ×4.
- Go `newUUID` duplicated `internal.go:57-63` / `chat/chat.go:269-275` (import direction forces it →
  `internal/uuid`). Go outbound HTTP written 3× (`api.go:145-176`, `client.go:253-275`, `resolver.go:150-183`)
  where Ruby has `http.rb:15-22` — port it.
- Go `ActionAPI.DryRun()` `executor.go:47` returns constant `false` (dry-run returns before the executor,
  `action.go:147-155`). Go `Config.Timeout` governs both script exec (`action.go:163`) and result-handler
  dispatch (`resultroute.go:133`) though documented as "ONE script execution" (`config.go:72-74`).
- Go exports with no documented consumer: `Embassy.Config()` (returns `Secret`, `embassy.go:41`),
  `NewMemoryNonceStore` (`replay.go:31`), `API.Put/Delete` (`api.go:67,71`). Health routed by path suffix
  (`action.go:54`). `schema.go:186-188` unreachable `default` arm. `contains` (`schema.go:192`) =
  `slices.Contains`.
- Ruby stale pointers `runner.rb:135`, `wire_spec.rb:5,19`. `config.rb:169,186` `api_configured?`/
  `chat_configured?` only called from specs.
- Go `make check` skips lint when `golangci-lint` is absent (`Makefile:16-21`) and there is no
  `.golangci.yml`; `languages.md:37` already lists no CI/no tag/no remote.

Checked and cleared (conform in all three): header `X-Webhook-Signature`/`sha256=`, fetch query order,
±300s skew, nonce TTL `2*skew+1`, 20s/22s deadlines, 64 KiB stdout, 405 unsigned, refusal classes
400/401/409/422/502/500, result-route idempotent ack + nonce release (`result_rack.rb:66-100`,
`resultroute.go:74-91`), `api.rb:108` `rescue ArgumentError; raise` is load-bearing.

## Simplification proposals

### Ruby — one RackShell + one SignedEndpoint (finding 4)
Intent "core framework-agnostic, Rails glue a thin shell" (`rootcause-embassy-ruby/AGENTS.md` conventions;
`SKILL.md:18-19`) · Exists `rack.rb` 57 LOC, `result_rack.rb` 205 LOC, `runner.rb` 90-96/216-219 ·
Simpler: shell class parameterised on handler; endpoint mixin owns verify/parse/reply/rescue · ~80 LOC ·
Risk: both mounts break together instead of separately — `rack_spec.rb:18,32,38` + `result_rack_spec.rb:72,93`
cover it.

### Ruby — drop the JSON-Schema branch (finding 12)
Intent `planes/actions.md:47` · Exists `schema.rb:73-87` + `schema_spec.rb:81-90` · ~24 LOC · Risk: a host
emitting JSON-Schema — impossible without a hub change first (rule 1).

### Ruby — one `Util` for `blank?`/`present?`/monotonic clock (finding 12)
~14 LOC · Risk: pick `.to_s.empty?` semantics (4 of 5 sites).

### Go — per-`API` token cache, `internal/uuid`, shared `doHTTP` (findings 8, 12)
Intent `planes/api.md:44` "credentials are project-pinned"; AGENTS.md "stdlib + yaegi" · ~20 + ~8 + ~40 LOC ·
Risk: `APIFor` instances stop sharing a token (one exchange per instance — acceptable).

### Go — drop `ActionAPI.DryRun()`, unexport `Config()`/`NewMemoryNonceStore`/`Put`/`Delete`
~18 LOC · Risk: a customer script calling `a.DryRun()` stops compiling — v0.1.0, no tag, no remote.

Go is otherwise **not over-engineered**: every `config.go` knob has a live read site and a test.

## Test economy

Ruby: 218 examples, 19 near-dup clusters (test_stats jaccard ≥ .8). Go: 40 tests, 0 clusters, 0 mock-only.

| cut | reason | covered by (survivor) |
|---|---|---|
| `spec/config_spec.rb:4,10,16,61,69` → 1 table | five "expect ArgumentError /field/" bodies | merged table test |
| `spec/config_spec.rb:38` | asserts `/secret/` not the placeholder (own comment admits) | `config_spec.rb:4` |
| `spec/config_spec.rb:24` | narrower copy of `:31` | `config_spec.rb:31` |
| `spec/config_spec.rb:45` | "accepts real fetch_url" — every spec builds a valid config | `runner_spec.rb:17` |
| `spec/signature_spec.rb:13,17,22` → 1 | three `valid? == false` literals | merged |
| `spec/signature_spec.rb:32,37` | internal helper, exercised by public path | `signature_spec.rb:7` |
| `spec/replay_spec.rb:13` · `:22,26` → 1 · `:45` | subsumed by edge-of-window; past/future same rule; `add?` asserted via `guard!` | `replay_spec.rb:17` · merged · `replay_spec.rb:34` |
| `spec/resolver_spec.rb:11` | strict subset of the cache test | `resolver_spec.rb:26` |
| `spec/schema_spec.rb:11,16,21,26,31,36` → 1 | six type rows, identical body | merged table |
| `spec/result_rack_spec.rb:49,57` → 1 · `:137,148` → 1 | forged vs missing sig; both `handler_error` | merged |
| `spec/result_rack_spec.rb:202,208,214` | byte-identical to invocation-shell tests — **only after finding 4 lands** | `rack_spec.rb:32,38,44` |
| `spec/result_rack_spec.rb:109` | third session_id round-trip | `client_spec.rb:130` + `result_rack_spec.rb:104` |
| `spec/result_spec.rb:50,68` · `:33` | subsumed by order-independence / big mapping test | `result_spec.rb:78` · `result_spec.rb:4` |
| `spec/client_spec.rb:46` · `:85` → fold into `:69` | step 2 of the round-trip; one extra assertion | `client_spec.rb:130` · `client_spec.rb:69` |
| `spec/executor_spec.rb:114,119,125` → 1 | capture/truncate/disabled same shape | merged |
| go `contract_test.go:364 TestSuccessEnvelopeShape` | second full yaegi compile to assert key order | fold `assertKeyOrder` into `TestActionRoundTrip` `:287` |
| go `executor_test.go:167 TestExecutorParamsAreData` | same config/script shape as `:35` | table row in `TestExecutorRunsAndCaptures` (keep the `"; os.Exit(1); "` literal) |

Net Ruby 218 → ~190. Keep-list (sole test of a critical path, do not cut): `runner_spec.rb:56,101,125,197,214`,
`result_rack_spec.rb:72,93`, `resolver_spec.rb:44,53`, `chat_spec.rb:36`, `client_spec.rb:94`,
`api_spec.rb:80`; go `TestExecutorDoesNotReuseATimedOutProgram`, `TestExecutorConcurrentTenantIsolation`,
`TestResultRedeliverySemantics/a failed dispatch releases the nonce`.
Gap to add (1 test each): Ruby full vector replay (finding 1); Go `500 internal_error` + `writeSigned`
marshal-fallback (`action.go:253-256`) via a handler panicking with a non-error value.

## Test suite speed
Ruby: **2.32s** wall (`bundle exec rspec`, 218 examples) — `executor_spec.rb:88` "kills a hanging body" =
2.0s (88%): `let(:config) { Wire.config(timeout: 2) }` (`:4`) + `sleep 5` (`:89`). Timeout consumed at
`executor.rb:46` `Timeout.timeout(@config.timeout.to_f)` — floats already work and `Wire.config` skips
`validate!`. Sub-agent measured `timeout: 0.05` + `sleep 1` → 0.064s, same assertions. Second sink
`runner_spec.rb:287-289` (`total_deadline: 0.2`, `sleep 2`) → 0.05. Suite ≈ **2.3s → ~0.4s**.
Go: **5.7s** wall cold (3 packages compile), ~2.1s warm; sinks are deliberate deadline tests
(`executor_test.go:121` 200ms, `:150` 100ms). Nothing to win.
Proposed: 2 literal edits, ~2.1s saved (Ruby); ~28 merges/cuts (Ruby), 2 (Go).

## Proposed custom lint rules (run via `lint_rules.py`; every listed hit a true violation)

| rule | repo / vehicle | hits today | all true? |
|---|---|---|---|
| `def (self\.)?(blank\|present)\?` in `lib/**` | ruby rubocop cop | 8 (`config.rb:222`, `api.rb:231`, `chat.rb:167`, `client.rb:256-257`, `result.rb:129`, `runner.rb:261`, `result_rack.rb:152`) | yes |
| `\bsleep [1-9]` in `spec/**` | ruby rubocop (RSpec) | 2 (`executor_spec.rb:89`, `runner_spec.rb:289`) | yes |
| `require: HUB_SHA` in `spec/contract/*.rb` | ruby | 1 (`wire_spec.rb` missing) | yes |
| `HTTP_X_WEBHOOK_SIGNATURE` in `lib/**` except `rack.rb` | ruby | 1 (`result_rack.rb:160`) | yes |
| `class"?:\s*"(invalid_request\|…\|method_not_allowed)"` in `lib/**` except `errors.rb` | ruby | 4 (`rack.rb:55`, `result_rack.rb:40,201`, `runner.rb:66`) | yes |
| `node\[:kind\]` in `lib/**` | ruby | 1 (`result.rb:126`) — pending finding 3 decision | yes |
| `WIRE-CONTRACT\|rootcause-light\|§\d` (comments too → plain `grep`, not lint_rules) | ruby grep | 2 (`runner.rb:135`, `wire_spec.rb:5`) | yes |
| `\b(fmt\.Print\|log\.Print\|os\.Stdout\|os\.Stderr)` non-test | go forbidigo | 0 | — (pin before first) |
| `w\.Write(\|\.WriteHeader(\|http\.Error(\|http\.NotFound(` outside `action.go` | go forbidigo/grep | 0 | — |
| non-stdlib import other than yaegi | go depguard `allow: [$gostd, github.com/traefik/yaegi]` | 0 | — |
| `func newUUID\(` outside `internal.go` | go grep | 1 (`chat/chat.go:269`) | yes |
| `` `json:"kind"` `` in `result.go` | go grep | 1 (`result.go:120`) — pending finding 3 | yes |
| `§\d` in `**/*.md` except `AGENTS.md` | hub grep (lint_rules glob missed top-level md; verified by grep) | 7 (listed in finding 11) | yes |
| json fixture ends with newline | hub grep | 0 | — |

Dropped (false positives): a broad `"(error_class)"` regex (hit `require_relative "embassy/replay"`);
`"kind"` repo-wide (chat claim `chat.rb:67`, attachment `client.go:27` are legitimate);
package-level-map regex (matched a local assignment `client.go:162`; native vehicle would be
`gochecknoglobals`, not validated here).

Prototype files used: `/tmp/arch/rules-{ruby,go,hub}.yaml` (regexes above are verbatim).
Native ports: Ruby → custom cops under `lib/rubocop/cop/embassy/` + `.rubocop.yml` `require:`
(repo already runs `standard`); Go → new `.golangci.yml` with `depguard` + `forbidigo` and make `make check`
fail when the binary is missing (`Makefile:16-21`); hub → a 3-line `scripts/check.sh` grep gate is enough for
a prose repo.

## Proposed dependency contract (NOT wired into CI)
Both impls are single-package (Ruby `lib/rootcause`, Go root → `chat`); no cycles, no hubs, no
skip-layer imports. Only contract worth stating, Go depguard:
```yaml
linters-settings:
  depguard:
    rules:
      main:
        files: ["$all"]
        allow: ["$gostd", "github.com/traefik/yaegi", "github.com/rootcause-org/rootcause-embassy-go"]
```
Would have caught: nothing today (0 hits) — it pins AGENTS.md "stdlib + yaegi only". Packwerk for Ruby is
overkill at 20 files; the cops above are the contract.

## Deliberately not done
- No product/test edits (audit only). Ruby fixture vendoring (finding 1) is the first fan-out task.
- Hub decisions required before code moves: finding 3 (`kind` fallback), 6 (`project_id` required?),
  10 (slug/nil-UUID rules), 11 bullets (stdout marker, client attachment cap, `type` enum, `php`/`node`
  in decision 8, `api_key` in key table, extend rule 4 to contract-touching commits).
- Ruby mutex scope (finding 9) is a concurrency semantics call, not a drive-by.
- Go `gochecknoglobals` not validated; `Config.Timeout` split (finding 12) needs a doc-or-field decision.
- Ruby `execution-failure` classes are Ruby class names (`runner.rb:76`) vs Go tokens — sanctioned by
  decision 6e, left alone.

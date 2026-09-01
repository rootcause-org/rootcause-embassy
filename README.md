# rootcause-embassy — the contract hub

Integrating ReplyPen into your app? Start at [`docs/integrator/start-here.md`](docs/integrator/start-here.md).

Porting or maintaining an Embassy? Start at [`CONTRACT.md`](CONTRACT.md).

An **Embassy** is rootcause's trusted in-app presence inside a customer's own runtime. It is a small
library (~2k LOC) the customer mounts in their app. It:

- receives signed **action** invocations from the rootcause host, resolves the script by digest, runs
  it on the project's **own production**, returns a signed structured result;
- **triggers analyses** on the host and **receives the result** asynchronously into a customer handler;
- **captures the human's actually-sent reply** (and answers to clarifying questions) back to the host;
- **mints embedded-chat tokens** for signed-in users;
- calls the host's ordinary HTTP **API** with a bearer.

It never decides what may run, never auto-executes a proposed action, and never invents identity.

## This repo

The **single authoritative wire contract** for every Embassy, in every language, plus the **canonical
golden fixtures** that prove conformance. No generators, no IDL — ≤6 languages ever, so plain prose
plus byte-exact goldens is cheaper and more durable than codegen.

```
README.md          you are here
AGENTS.md          orchestration playbook — how a contract change flows out to every repo
CONTRACT.md        the wire contract, all planes (start here)
planes/            one file per plane: actions, analysis, chat, api
fixtures/          CANONICAL goldens + signing vectors; every repo vendors these
languages.md       registry + status matrix of the implementations
decisions.md       the 11 pinned decisions + versioning policy
```

Read [`CONTRACT.md`](CONTRACT.md) first; the `planes/` files are the detail.

## How a contract change flows

1. Change lands **here** first: `CONTRACT.md` / `planes/*` / `fixtures/*`, with the reasoning recorded
   in `decisions.md`.
2. Fan out to every repo in [`languages.md`](languages.md) — the rootcause host is one of them.
3. Each repo re-vendors `fixtures/` (carrying the hub commit SHA) and replays them byte-for-byte in
   its conformance suite. A repo that cannot replay a fixture fails its CI.

Full instructions: [`AGENTS.md`](AGENTS.md).

## Taxonomy

**project** (never tenant/customer/account), **run**, **session**, **principal**, **claim**,
**workspace**, **brain**, **mirror**, **tool**, **draft**, **note**, **action** (never "effect", and
never an alias for tool), **Embassy** (never "gem"/"action-runner"). Same vocabulary as the host repo.

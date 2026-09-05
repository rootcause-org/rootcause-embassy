---
name: embassy-actions
description: Use when mounting, verifying, or troubleshooting the customer-side Embassy action endpoint for ReplyPen actions (signed health, dry run, confirmed action, `[ReplyPen] CODE` errors).
---

# Embassy actions

Read [`../../docs/integrator/start-here.md`](../../docs/integrator/start-here.md), then
[`../../docs/integrator/actions.md`](../../docs/integrator/actions.md). Walk the action rungs in
[`../../docs/integrator/verify.md`](../../docs/integrator/verify.md) in order: 405 floor, signed
health, dry run, host workflow smoke, then one harmless confirmed action.

Hard rule (security boundary): `ROOTCAUSE_ACTION_SECRET` stays in the backend and is never the chat
secret — the two planes must fail independently. Framework mounting and runtime rules: the sibling
language Embassy README.

On any `[ReplyPen] CODE` line, open `../../docs/integrator/errors.md#<code-lowercased>` and follow
**Self-fix**. If **Who fixes** is `operator`, capture a bundle with
`rc dev action doctor <action-id> --bundle` and follow
[`../../docs/integrator/escalate.md`](../../docs/integrator/escalate.md).

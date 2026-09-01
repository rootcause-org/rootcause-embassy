---
name: embassy-actions
description: Mount, verify, and troubleshoot the customer side of ReplyPen Embassy actions.
---

# Embassy actions

Read [`../../docs/integrator/start-here.md`](../../docs/integrator/start-here.md), then
[`../../docs/integrator/actions.md`](../../docs/integrator/actions.md). Use the action rungs in
[`../../docs/integrator/verify.md`](../../docs/integrator/verify.md) in order: 405 floor, signed
health, dry run, host workflow smoke, then one harmless confirmed action.

Keep `ROOTCAUSE_ACTION_SECRET` in the backend and separate from the chat secret. Use the sibling
language Embassy README for framework mounting and runtime rules.

On any `[ReplyPen] CODE` line, open `../../docs/integrator/errors.md#<code-lowercased>` and follow **Self-fix**. If
**Who fixes** is `operator`, run `rc dev action doctor <action-id> --bundle` and follow
[`../../docs/integrator/escalate.md`](../../docs/integrator/escalate.md).

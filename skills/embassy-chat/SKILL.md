---
name: embassy-chat
description: Use when integrating, verifying, or troubleshooting ReplyPen embedded chat in a customer app (token minting, widget, CSP, `[ReplyPen] CODE` errors) from the public Embassy contract hub.
---

# Embassy chat

Read [`../../docs/integrator/start-here.md`](../../docs/integrator/start-here.md), then
[`../../docs/integrator/chat.md`](../../docs/integrator/chat.md) — it owns the Chat Studio /
`rc project chat brief` handoff: treat the brief's fenced `replypen_brief: v1` block as the source of
truth for mode, target, principal kind, tenant, and exact origins; regenerate it after any change
instead of asking the human again or editing it by hand. Then walk the chat rungs in
[`../../docs/integrator/verify.md`](../../docs/integrator/verify.md) in order; never skip the replay
or denied-origin checks.

Hard rules (security boundary): `ROOTCAUSE_CHAT_SECRET` stays in the backend; mint per render; only
the short-lived token reaches the browser; `rc project chat secret reveal` runs only in an approved
backend terminal. Code-level minting and framework mounting: the sibling language Embassy README.

On any `[ReplyPen] CODE` line, open `../../docs/integrator/errors.md#<code-lowercased>` and follow
**Self-fix**. If **Who fixes** is `operator`, capture a bundle with `rc project chat doctor --bundle`
(`rc >= 1.22.0`) and follow [`../../docs/integrator/escalate.md`](../../docs/integrator/escalate.md).

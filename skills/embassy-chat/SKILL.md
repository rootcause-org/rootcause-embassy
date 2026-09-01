---
name: embassy-chat
description: Integrate, verify, and troubleshoot ReplyPen embedded chat from the public Embassy contract hub.
---

# Embassy chat

Read [`../../docs/integrator/start-here.md`](../../docs/integrator/start-here.md), then
[`../../docs/integrator/chat.md`](../../docs/integrator/chat.md). Use the chat rungs in
[`../../docs/integrator/verify.md`](../../docs/integrator/verify.md) in order; do not skip the replay
or denied-origin checks.

Keep `ROOTCAUSE_CHAT_SECRET` in the backend. Mint per render; send only the short-lived token to the
browser. Use the sibling language Embassy README for code-level token minting.

Start in the ReplyPen **Chat Studio** when available: select the real tenant and principal identity,
exercise the real loader widget, then copy the implementation brief. Treat its fenced
`replypen_brief: v1` block as the source of truth for mode, target, principal kind, tenant, and exact
origins; do not ask the human to choose them again. The brief is deliberately secret-free;
run its `rc project chat secret reveal` command only in an approved backend terminal.

The human changes those choices at
`https://app.replypen.com/projects/<project>[/tenants/<tenant>]/chat/studio`; regenerate the brief after
any change rather than editing its machine block by hand.

Without web access, generate the identical handoff with:

```sh
rc project chat brief [--tenant <slug>] [--target bubble|page]
```

On any `[ReplyPen] CODE` line, open `../../docs/integrator/errors.md#<code-lowercased>` and follow
**Self-fix**. If **Who fixes** is `operator`, use `rc >= 1.22.0`, run
`rc project chat doctor [--origin URL] [--principal-kind KIND] --bundle`, and follow
[`../../docs/integrator/escalate.md`](../../docs/integrator/escalate.md).

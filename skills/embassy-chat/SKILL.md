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

On any `[ReplyPen] CODE` line, open `../../docs/integrator/errors.md#<code-lowercased>` and follow
**Self-fix**. If **Who fixes** is `operator`, use `rc >= 1.22.0`, run
`rc project chat doctor [--origin URL] [--principal-kind KIND] --bundle`, and follow
[`../../docs/integrator/escalate.md`](../../docs/integrator/escalate.md).

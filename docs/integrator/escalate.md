# Escalate an integration failure

Escalate when the error catalogue says **Who fixes: operator**, when all self-fix steps still produce
the same code, or when an action outcome is uncertain. Never retry an uncertain state-changing action.

## Capture a redacted bundle

These commands are **not in `rc` yet** (check `rc help`). Use the manual bundle below until they ship.

Chat:

```sh
rc project chat doctor --bundle
```

Actions:

```sh
rc dev action doctor --bundle
```

The bundle contains project slug, CLI and Embassy versions when known, configuration booleans and
origins, redacted recent rejects, probe results, and timestamps. It must not contain secrets, token
bytes, provider names, stack traces, personal data, or private host details. Review it before sending.

## Manual bundle (until the doctor commands ship)

Assemble the same fields by hand — no secrets, no token bytes:

```sh
rc --version
rc auth access
rc self doctor
rc run debug <run-id>        # only when a run id is involved; redact before sending
```

Add by hand: project slug, Embassy library + version, the configured origins, principal kind and
tenant, whether chat/actions are enabled, the Embassy mount URL, the mount's non-POST probe status
(`curl -i -X GET <mount>` → expect `405` with `Allow: POST`), and the UTC timestamps of the last few
failures with their codes.

## Message template

```text
To: support@replypen.com
Subject: ReplyPen integration failure: <CODE> for <project-slug>

Error line:
[ReplyPen] <CODE>: <hint> — <docs URL>

Redacted doctor bundle:
<paste JSON>

What I tried:
- <self-fix step>
- <result>

First observed: <UTC timestamp>
Environment: <staging or production; no credentials>
```

Attach no screenshots containing tokens and no raw `Authorization`, cookie, HMAC, or environment
values. If the bundle command itself fails, include `rc --version`, `rc auth access`, the command's
error line, and no credentials.

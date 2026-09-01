# Start here

This guide is for the developer who owns the app where ReplyPen chat or actions will run.

## Mental model

1. The ReplyPen host knows the project, runs the support workflow, and stores chat sessions.
2. Your app knows the signed-in person and, when applicable, the tenant.
3. Your backend mints one short-lived chat token for that person.
4. Your browser receives only that token and loads the ReplyPen widget.
5. The browser talks directly to `https://app.replypen.com/chat/v1/*`.
6. The token binds project, origin, principal, tenant, and expiry.
7. A new browser render gets a new token; a token is single-use for opening a session.
8. Actions travel the other way: ReplyPen calls an Embassy mounted in your app.
9. The Embassy accepts only signed, approved, digest-pinned action scripts.
10. Chat and actions use different secrets. Never substitute one for the other.

## Split of responsibilities

The ReplyPen operator:

- creates the project and enables chat and/or actions;
- registers exact browser origins and accepted principal kinds;
- supplies the two secrets out of band and caps the action autonomy level;
- registers your Embassy mount URL and helps with host-side failures.

You:

- keep secrets in your backend environment, never browser code, HTML, logs, or source control;
- mint a token from the authenticated app session on every render;
- add the widget and CSP directives to the host page;
- mount and protect the Embassy action endpoint when enabling actions;
- run the verification ladder and send a redacted bundle when escalation is needed.

## Two secrets

| Secret | Typical app environment | Purpose | Never lives in |
| --- | --- | --- | --- |
| chat signing secret | `ROOTCAUSE_CHAT_SECRET` | HS256 chat token minting | browser, widget tag, logs |
| action reverse secret | `ROOTCAUSE_ACTION_SECRET` | HMAC for host ↔ Embassy actions and analysis | browser, chat token, logs |

The operator may call the chat secret `webhook_secret` and the action secret
`action_reverse_secret`. The Embassy libraries use the `ROOTCAUSE_*` names above. Also set
`ROOTCAUSE_CHAT_PROJECT=<project-slug>` and
`ROOTCAUSE_CHAT_BASE_URL=https://app.replypen.com`. Set the base URL explicitly in every language;
standalone token minting does not need it, but widget rendering does.

## Send this request to the operator

Copy, fill, and send:

```text
Please prepare ReplyPen integration for:
- project slug: acme
- browser origins: https://app.acme.example, https://staging.acme.example
- principal kind: acme_user
- tenant claim: required / not used
- Embassy action mount URL: https://api.acme.example/rootcause/action (or: actions not yet enabled)

Please return the chat signing secret and action reverse secret through the agreed secret channel,
and confirm the registered origins, principal manifest, and operator-capped action autonomy.
```

An origin is the exact `scheme://host[:port]`. Paths, wildcards, trailing slashes, and sibling
subdomains do not match.

## Install and authenticate `rc`

macOS:

```sh
brew install rootcause-org/tap/rc
```

Linux or WSL:

```sh
curl -fsSL https://raw.githubusercontent.com/rootcause-org/rootcause-cli/main/scripts/install.sh | sh
```

Then:

```sh
rc auth login
rc auth access
```

`rc auth access` must show the project and the configuration/diagnostic access needed by the steps
below. Ask the operator if the project or a required permission is absent.

## Integration checklist

- [ ] Operator request sent and both secrets received separately.
- [ ] Secrets installed only in the backend environment.
- [ ] Chat-only app uses its language's standalone chat API; action configuration is not required.
- [ ] [`chat.md`](chat.md): token minting, rotation, CSP, widget, and API wired.
- [ ] [`verify.md`](verify.md): chat ladder passes, including replay and denied-origin checks.
- [ ] [`actions.md`](actions.md): Embassy mounted and zero-side-effect probes pass, if enabling actions.
- [ ] [`verify.md`](verify.md): propose → confirm → executed passes before raising autonomy.
- [ ] [`errors.md`](errors.md): every surfaced code has been followed to its self-fix steps.
- [ ] [`escalate.md`](escalate.md): redacted bundle captured if the operator must help.

## Upcoming self-service commands

These command shapes require `rc >= X` (version TBD). Until that release lands, the operator performs
the equivalent configuration:

```sh
rc project chat get
rc project chat set
rc project chat secret rotate
rc project chat secret reveal
rc project chat doctor
rc project principals get
rc project principals set
```

Do not design scripts around the placeholder version. Confirm availability with `rc help` and
`rc --version`.

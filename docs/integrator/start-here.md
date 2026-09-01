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

- [ ] Open **Chat Studio** from the ReplyPen project navigation, select a real tenant/principal, and send one preview message.
- [ ] Set the greeting, starter prompts, locale, color scheme, depth, branding, and exact origins while watching the real widget update.
- [ ] Copy or download the Studio implementation brief and hand it to the app developer; it contains no token or secret.
- [ ] Operator request sent and both secrets received separately.
- [ ] Secrets installed only in the backend environment.
- [ ] Chat-only app uses its language's standalone chat API; action configuration is not required.
- [ ] [`chat.md`](chat.md): token minting, rotation, CSP, widget, and API wired.
- [ ] [`verify.md`](verify.md): chat ladder passes, including replay and denied-origin checks.
- [ ] [`actions.md`](actions.md): Embassy mounted and zero-side-effect probes pass, if enabling actions.
- [ ] [`verify.md`](verify.md): propose → confirm → executed passes before raising autonomy.
- [ ] [`errors.md`](errors.md): every surfaced code has been followed to its self-fix steps.
- [ ] [`escalate.md`](escalate.md): redacted bundle captured if the operator must help.

## Self-service commands (`rc >= 1.22.0`)

Use an authenticated, project-scoped `rc` profile (or add `--project <slug>` to each command):

```sh
rc project chat get
rc project chat set chat_enabled=true chat_origins=https://app.acme.example
rc project chat secret rotate
rc project chat secret reveal
rc project chat token --origin https://app.acme.example \
  --principal-kind acme_user --principal-id <external-id> [--tenant <tenant-slug>]
rc project chat send <message> [--token <token>] [--origin https://app.acme.example]
rc project chat doctor [--origin https://app.acme.example] \
  [--principal-kind acme_user] [--bundle]
rc project chat brief [--tenant <tenant-slug>] [--target bubble|page] \
  [--locale en|nl|fr] [--color-scheme light|dark]
rc project principals get
rc project principals set <json-or-yaml-file>
```

`chat secret rotate` and `chat secret reveal` print plaintext once; redirect them only to an approved
secret channel. `chat send` reads `RC_CHAT_TOKEN` when `--token` is omitted. `chat brief` prints the
same secret-free Markdown generated by Chat Studio, including exact CSP origins and a fenced
`replypen_brief: v1` YAML block.

## When a project owner sends an implementation brief

A project owner can settle every product choice in Chat Studio and send you one secret-free Markdown
brief. Treat its `replypen_brief: v1` block as the source of truth for tenant, presentation, mode,
principal kind, and exact origins; do not ask them to choose those values again. The prose above it
separates what is already live in ReplyPen from the backend and browser work you still own.

The machine block has this shape (values vary by project):

```yaml
replypen_brief: v1
generated_at: "2026-01-02T03:04:05Z"
studio_url: "https://app.replypen.com/projects/example/chat/studio"
project: "example"
tenant: ""
widget_origin: "https://app.replypen.com"
target: "bubble"
locale: "en"
color_scheme: "light"
chat_mode: "consumer"
chat_enabled: true
actions_enabled: false
allowed_origins:
  - "https://app.example.com"
principal_kinds:
  - "app_user"
greeting: "How can we help?"
suggested_prompts:
  - "Where is my order?"
```

Choices change at
`https://app.replypen.com/projects/<project>[/tenants/<tenant>]/chat/studio`. Ask the owner to change
them there and regenerate the brief; never edit the machine block into a competing configuration.

# Error catalogue

Every customer-facing error has a stable SCREAMING_SNAKE code, one plain-language hint, and a docs
link of this form:

```text
https://github.com/rootcause-org/rootcause-embassy/blob/main/docs/integrator/errors.md#<code-lowercased>
```

The widget writes `console.error("[ReplyPen] <CODE>: <hint> — <docs>")`. Never include tokens,
secrets, personal data, private host details, provider names, costs, or stack traces in an error or
bundle.

## ACTION_CONFLICT

- **Meaning:** The chat action proposal could not be settled safely; its state may have changed.
- **Who fixes:** operator.
- **Self-fix:** Re-read the action card/session. Do not repeat a confirmation while the outcome is unknown.
- **Escalate with:** The error line and `rc dev action doctor --bundle`.

## ACTION_EXECUTOR_UNAVAILABLE

- **Meaning:** ReplyPen cannot start action execution because the action executor is not available.
- **Who fixes:** operator.
- **Self-fix:** Stop before confirmation and ask the operator to verify the project's action execution service.
- **Escalate with:** The error line and `rc dev action doctor ACTION_ID --bundle`.

## ACTION_FAILED

- **Meaning:** The action ran or attempted to run but finished with a failed outcome.
- **Who fixes:** you.
- **Self-fix:** Inspect the action's customer-safe result, fix the script or app dependency, and do not retry while the outcome is uncertain.
- **Escalate with:** The error line and `rc dev action doctor ACTION_ID --bundle`.

## ACTION_RESOLVE_FAILED

- **Meaning:** ReplyPen could not resolve the approved action definition and pinned script digest.
- **Who fixes:** operator.
- **Self-fix:** Confirm the action id is approved and live in the project brain; do not substitute an unapproved script.
- **Escalate with:** The error line and `rc dev action doctor ACTION_ID --bundle`.

## ACTIONS_DISABLED

- **Meaning:** The project action plane is disabled.
- **Who fixes:** operator.
- **Self-fix:** Keep proposals non-actionable and ask the operator to enable actions with the intended autonomy cap.
- **Escalate with:** The error line and `rc dev action doctor ACTION_ID --bundle`.

## ACTIONS_UNAVAILABLE

- **Meaning:** Chat action decisions are not enabled or wired for this project.
- **Who fixes:** operator.
- **Self-fix:** Keep the card non-actionable and ask the operator to verify action enablement and the Embassy mount.
- **Escalate with:** The error line and `rc dev action doctor --bundle`.

## ATTACHMENT_ALREADY_SENT

- **Meaning:** This upload is already bound to another message and cannot be reused.
- **Who fixes:** you.
- **Self-fix:** Upload the file again and use the new `attachment_id` in exactly one message.
- **Escalate with:** The error line and `rc project chat doctor --bundle` if a new upload also fails.

## ATTACHMENTS_UNAVAILABLE

- **Meaning:** The attachment service is not enabled for this chat surface.
- **Who fixes:** operator.
- **Self-fix:** Send the message without file parts, then ask the operator to verify attachment wiring.
- **Escalate with:** The error line and `rc project chat doctor --bundle`.

## BAD_ATTACHMENT

- **Meaning:** An attachment id is malformed or duplicated in the message.
- **Who fixes:** you.
- **Self-fix:** Send each valid upload id once and copy it unchanged from the upload response.
- **Escalate with:** The error line and the redacted message part shapes plus `rc project chat doctor --bundle`.

## BAD_BODY

- **Meaning:** The request body, id, multipart form, score, or required field is invalid.
- **Who fixes:** you.
- **Self-fix:** Compare the request with `chat.md`, set `Content-Type`, and send only documented fields and types.
- **Escalate with:** The error line, redacted request shape, and `rc project chat doctor --bundle`.

## BAD_ID

- **Meaning:** A session or attachment path id is not a UUID.
- **Who fixes:** you.
- **Self-fix:** Use the id returned by the preceding ReplyPen response without truncation or decoration.
- **Escalate with:** The error line and `rc project chat doctor --bundle` if the returned id itself is rejected.

## BAD_OUTCOME

- **Meaning:** An action decision is not `confirm`, `decline`, or `cancel`.
- **Who fixes:** you.
- **Self-fix:** Send one allowed lowercase outcome in `{"outcome":"..."}`.
- **Escalate with:** The error line and a redacted request shape plus `rc project chat doctor --bundle`.

## BAD_SIGNATURE

- **Meaning:** An Embassy HMAC signature is absent, malformed, uses the wrong secret, or does not match the exact bytes.
- **Who fixes:** you.
- **Self-fix:** Verify `ROOTCAUSE_ACTION_SECRET`, sign the raw transmitted bytes once, and replay the signing fixtures.
- **Escalate with:** The error line, Embassy version, hub SHA, and `rc dev action doctor --bundle`; never send the signature key.

## BAD_TOKEN

- **Meaning:** The chat JWT signature, algorithm, audience, issuer, time window, or required claim is invalid.
- **Who fixes:** you.
- **Self-fix:** Replay `fixtures/chat/jwt_vector.json`, check the backend clock, and compare `aud`, `iss`, `origin`, and expiry.
- **Escalate with:** The error line and `rc project chat doctor --bundle`; never paste the token.

## CHAT_DISABLED

- **Meaning:** Embedded chat is disabled for the project.
- **Who fixes:** operator.
- **Self-fix:** Confirm the intended project slug, then ask the operator to enable chat for it.
- **Escalate with:** The error line and `rc project chat doctor --bundle`.

## EMBASSY_HEALTH_INVALID

- **Meaning:** The Embassy health response is missing required fields, malformed, unsigned, or signed incorrectly.
- **Who fixes:** you.
- **Self-fix:** Upgrade the Embassy, verify its signed `/health` route and protocol fields, and replay the health fixture.
- **Escalate with:** The error line and `rc dev action doctor ACTION_ID --bundle`.

## EMBASSY_MODE_REQUIRED

- **Meaning:** Action execution needs an Embassy mode, but the project has no usable mode configured.
- **Who fixes:** operator.
- **Self-fix:** Ask the operator to select the intended Embassy execution mode before testing a real action.
- **Escalate with:** The error line and `rc dev action doctor ACTION_ID --bundle`.

## EMBASSY_NOT_MOUNTED

- **Meaning:** The configured app URL responds, but no Embassy action route is mounted there.
- **Who fixes:** you.
- **Self-fix:** Mount the language Embassy at the registered path and verify the unsigned 405 liveness floor.
- **Escalate with:** The error line and `rc dev action doctor ACTION_ID --bundle`.

## EMBASSY_PROTOCOL_MISMATCH

- **Meaning:** The mounted Embassy reports a protocol version incompatible with the host.
- **Who fixes:** you.
- **Self-fix:** Upgrade the Embassy to a compatible release; never bypass protocol or signature checks.
- **Escalate with:** The error line and `rc dev action doctor ACTION_ID --bundle`.

## EMBASSY_REJECTED

- **Meaning:** The Embassy returned a signed refusal that does not map to a more specific public code.
- **Who fixes:** you.
- **Self-fix:** Read the verified refusal class and hint, then follow its catalogue entry without weakening the gate.
- **Escalate with:** The error line and `rc dev action doctor ACTION_ID --bundle`.

## EMBASSY_REPLAYED

- **Meaning:** The Embassy rejected the invocation as stale or replayed.
- **Who fixes:** you.
- **Self-fix:** Synchronize the app clock, use a fresh nonce per invocation, and do not retry a possibly executed action blindly.
- **Escalate with:** The error line and `rc dev action doctor ACTION_ID --bundle`.

## EMBASSY_RESOLVE_FAILED

- **Meaning:** The Embassy could not fetch or digest-verify the approved action script.
- **Who fixes:** operator.
- **Self-fix:** Verify signed script-fetch reachability and approval state; never run bytes whose digest does not match.
- **Escalate with:** The error line and `rc dev action doctor ACTION_ID --bundle`.

## EMBASSY_RESULT_INVALID

- **Meaning:** The Embassy response is malformed, oversized, unsigned, or fails signature verification.
- **Who fixes:** you.
- **Self-fix:** Upgrade the Embassy and replay the signed result fixtures over the exact transmitted bytes.
- **Escalate with:** The error line and `rc dev action doctor ACTION_ID --bundle`.

## EMBASSY_SCHEMA_REJECTED

- **Meaning:** The Embassy refused action params because they do not satisfy the approved schema.
- **Who fixes:** you.
- **Self-fix:** Match param keys and types to the approved manifest and remove reserved tenant selectors.
- **Escalate with:** The error line and `rc dev action doctor ACTION_ID --bundle`.

## EMBASSY_SIGNATURE_REJECTED

- **Meaning:** The Embassy could not verify the host invocation signature with its configured action secret.
- **Who fixes:** operator.
- **Self-fix:** Verify the app and host hold the same per-project action reverse secret; never paste either secret into diagnostics.
- **Escalate with:** The error line and `rc dev action doctor ACTION_ID --bundle`.

## EMBASSY_TLS

- **Meaning:** ReplyPen could not establish a trusted TLS connection to the Embassy URL.
- **Who fixes:** you.
- **Self-fix:** Install a publicly trusted, hostname-matching certificate with a complete chain and current validity.
- **Escalate with:** The error line and `rc dev action doctor ACTION_ID --bundle`.

## EMBASSY_UNREACHABLE

- **Meaning:** ReplyPen could not connect to the Embassy or the request timed out before a response.
- **Who fixes:** you.
- **Self-fix:** Check public DNS, firewall/allowlist, route availability, and the Embassy's total request deadline.
- **Escalate with:** The error line and `rc dev action doctor ACTION_ID --bundle`.

## EMBASSY_URL_MISSING

- **Meaning:** The project has no Embassy action URL configured.
- **Who fixes:** operator.
- **Self-fix:** Provide the operator with the public HTTPS mount URL and confirm it contains no credentials or query string.
- **Escalate with:** The error line and `rc dev action doctor ACTION_ID --bundle`.

## EMBASSY_URL_REFUSED

- **Meaning:** The configured Embassy URL violates the host's outbound URL safety rules.
- **Who fixes:** operator.
- **Self-fix:** Use a public HTTPS hostname that resolves to the intended app; loopback, private, credentialed, or unsafe redirect targets are refused.
- **Escalate with:** The error line and `rc dev action doctor ACTION_ID --bundle`.

## EMPTY_FILE

- **Meaning:** The uploaded file has zero bytes.
- **Who fixes:** you.
- **Self-fix:** Reject empty files in the composer or upload the intended non-empty file.
- **Escalate with:** The error line and file metadata without contents plus `rc project chat doctor --bundle`.

## FEEDBACK_UNAVAILABLE

- **Meaning:** Turn feedback is not enabled on this chat surface.
- **Who fixes:** operator.
- **Self-fix:** Hide or disable the feedback control until the operator confirms availability.
- **Escalate with:** The error line and `rc project chat doctor --bundle`.

## FORBIDDEN

- **Meaning:** The authenticated `rc` identity lacks the project role, tenant reach, or scope required for this action operation.
- **Who fixes:** you.
- **Self-fix:** Run `rc auth access`, select the intended project/tenant, and ask a project admin for the missing action permission.
- **Escalate with:** The error line and `rc dev action doctor ACTION_ID --bundle`.

## HANDLER_ERROR

- **Meaning:** The Embassy accepted an analysis result but could not dispatch it to the configured app handler.
- **Who fixes:** you.
- **Self-fix:** Verify the result handler is registered, loadable, and succeeds for the redacted conformance fixture.
- **Escalate with:** The error line, Embassy version, hub SHA, and `rc dev action doctor --bundle`.

## INTERNAL

- **Meaning:** The chat host could not complete a request for a reason the integrator cannot repair from the request.
- **Who fixes:** operator.
- **Self-fix:** Retry one read-only request once. Do not repeat a state-changing request with an unknown outcome.
- **Escalate with:** The error line, UTC timestamp, and `rc project chat doctor --bundle`.

## INTERNAL_ERROR

- **Meaning:** The Embassy hit an unforeseen failure after its public validation gates.
- **Who fixes:** operator.
- **Self-fix:** Upgrade to the current Embassy release and rerun the conformance suite; do not expose exception text.
- **Escalate with:** The error line, Embassy version, hub SHA, and `rc dev action doctor --bundle`.

## INVALID_PARAMS

- **Meaning:** The requested action params are malformed, missing, extra, or incompatible with the approved manifest.
- **Who fixes:** you.
- **Self-fix:** Compare the submitted names and JSON types with the action's public schema; never add tenant selectors as params.
- **Escalate with:** The error line and `rc dev action doctor ACTION_ID --bundle`.

## INVALID_REQUEST

- **Meaning:** An Embassy action/result body is malformed, missing a required field, or names an unsupported runtime.
- **Who fixes:** you.
- **Self-fix:** Validate against `CONTRACT.md`, send the language's runtime token, and replay the invocation fixtures.
- **Escalate with:** The error line, redacted field names, Embassy version, hub SHA, and `rc dev action doctor --bundle`.

## METHOD_NOT_ALLOWED

- **Meaning:** A non-POST request reached an Embassy action mount; this is expected only for the 405 liveness probe.
- **Who fixes:** you.
- **Self-fix:** Use POST for invocations. If running the probe, verify status `405` and `Allow: POST` and treat it as success.
- **Escalate with:** The error line and `rc dev action doctor --bundle` if the mount does not return the 405 floor.

## MISSING_FILE

- **Meaning:** A multipart upload omitted the `file` form field.
- **Who fixes:** you.
- **Self-fix:** Send exactly one file part named `file` plus the `session_id` field.
- **Escalate with:** The error line and a redacted multipart field-name list plus `rc project chat doctor --bundle`.

## NO_TOKEN

- **Meaning:** The chat request has no usable `Authorization: Bearer <token>` header.
- **Who fixes:** you.
- **Self-fix:** Fetch a fresh token from your backend and attach it as a Bearer token; do not place it in the URL.
- **Escalate with:** The error line and `rc project chat doctor --bundle`; never paste the token.

## ORIGIN_MISMATCH

- **Meaning:** The request origin differs from the exact origin signed into the token.
- **Who fixes:** you.
- **Self-fix:** Mint on the backend with the browser's exact `scheme://host[:port]` and do not reuse a token across origins.
- **Escalate with:** The error line, the two non-secret origins, and `rc project chat doctor --bundle`.

## ORIGIN_NOT_ALLOWED

- **Meaning:** The embedding origin is missing or absent from the project's exact origin allowlist.
- **Who fixes:** operator.
- **Self-fix:** Verify the page origin has no path/trailing slash, then request that exact origin be registered.
- **Escalate with:** The error line, exact origin, and `rc project chat doctor --bundle`.

## PRINCIPAL_REQUIRED

- **Meaning:** The project declares principal kinds but the token has no complete valid principal.
- **Who fixes:** you.
- **Self-fix:** Mint `principal.kind`, `external_id`, `asserted_by`, and `assurance` from the authenticated backend.
- **Escalate with:** The error line, redacted claim names, and `rc project chat doctor --bundle`.

## RATE_LIMITED

- **Meaning:** The caller or origin exceeded the chat request budget.
- **Who fixes:** you.
- **Self-fix:** Honor `Retry-After`, debounce duplicate calls, and stop mint/reload loops.
- **Escalate with:** The error line, request cadence without payloads, and `rc project chat doctor --bundle` if normal human use is limited.

## REPLAY

- **Meaning:** An Embassy nonce was already used or `issued_at` is outside the accepted clock window.
- **Who fixes:** you.
- **Self-fix:** Generate a fresh nonce per invocation, synchronize clocks, and never automatically retry a possibly executed action.
- **Escalate with:** The error line, redacted timestamps/nonces, and `rc dev action doctor --bundle`.

## RESOLVE_FAILED

- **Meaning:** The Embassy could not fetch or verify the approved script bytes for the pinned digest.
- **Who fixes:** operator.
- **Self-fix:** Check Embassy network reachability and configured fetch URL, then run a dry run; never bypass digest verification.
- **Escalate with:** The error line, action id, digest, Embassy version, hub SHA, and `rc dev action doctor --bundle`.

## RUN_IN_FLIGHT

- **Meaning:** Another message turn is already processing for this session.
- **Who fixes:** you.
- **Self-fix:** Disable duplicate sends and wait for the current SSE turn to finish before posting another message.
- **Escalate with:** The error line, session id, timestamps, and `rc project chat doctor --bundle` if the state never clears.

## SCHEMA_VIOLATION

- **Meaning:** Action params fail the approved invocation schema or try to override reserved tenant fields.
- **Who fixes:** you.
- **Self-fix:** Compare param keys/types with the action manifest and pass tenant identity only through the trusted tuple.
- **Escalate with:** The error line, redacted param keys/schema, and `rc dev action doctor --bundle`.

## SESSION_CLOSED

- **Meaning:** The session is readable but no longer accepts new turns or decisions.
- **Who fixes:** you.
- **Self-fix:** Open a new session with a freshly minted token and keep the closed transcript read-only.
- **Escalate with:** The error line and `rc project chat doctor --bundle` if a newly opened session is closed.

## SESSION_DRIFT

- **Meaning:** The token's origin, principal, or tenant differs from the values bound when the session opened.
- **Who fixes:** you.
- **Self-fix:** Resume only with tokens minted for the same authenticated identity, tenant, and origin; otherwise open a new session.
- **Escalate with:** The error line, redacted claim shapes, and `rc project chat doctor --bundle`.

## TENANT_NOT_SUPPORTED

- **Meaning:** The token carries a tenant for a project that has no tenants.
- **Who fixes:** you.
- **Self-fix:** Omit the `tenant` claim for this project and mint a fresh token.
- **Escalate with:** The error line and `rc project chat doctor --bundle` if the operator says the project is tenant-enabled.

## TENANT_REQUIRED

- **Meaning:** A tenant-enabled chat token or action request omits the required tenant slug.
- **Who fixes:** you.
- **Self-fix:** Resolve the authenticated app context to the registered tenant slug; mint a fresh chat token or pass the action's trusted tenant selector outside params.
- **Escalate with:** For actions, the error line and `rc dev action doctor ACTION_ID --bundle`; for chat, the error line, redacted tenant slug, and `rc project chat doctor --bundle`.

## TENANT_UNAVAILABLE

- **Meaning:** The named tenant exists but is not active.
- **Who fixes:** operator.
- **Self-fix:** Confirm the intended tenant slug and ask the operator to inspect its status; do not fall back to unscoped access.
- **Escalate with:** The error line, tenant slug, and `rc project chat doctor --bundle`.

## TOKEN_REPLAYED

- **Meaning:** The token's single-use `jti` already opened a session.
- **Who fixes:** you.
- **Self-fix:** Mint a fresh token with a new UUID `jti` for every new session/render; keep the original page token for its existing session calls.
- **Escalate with:** The error line, mint/open timestamps, and `rc project chat doctor --bundle`; never paste either token.

## TOO_LARGE

- **Meaning:** An upload or multipart request exceeds the accepted size.
- **Who fixes:** you.
- **Self-fix:** Reject or compress the file before upload and do not retry the same oversized body.
- **Escalate with:** The error line and file name/type/size only plus `rc project chat doctor --bundle`.

## TOO_MANY_ATTACHMENTS

- **Meaning:** One message references more attachments than a turn accepts.
- **Who fixes:** you.
- **Self-fix:** Split the files across turns and keep every upload id single-use.
- **Escalate with:** The error line, attachment count, and `rc project chat doctor --bundle`.

## TOO_MANY_PENDING

- **Meaning:** The session holds too many uploaded files that have not been sent in a message.
- **Who fixes:** you.
- **Self-fix:** Send the intended message, stop abandoned pre-uploads, or wait for pending uploads to expire.
- **Escalate with:** The error line, pending-file count/total size, and `rc project chat doctor --bundle`.

## TURN_TOO_LARGE

- **Meaning:** The combined attachments referenced by one message exceed the turn limit.
- **Who fixes:** you.
- **Self-fix:** Split the attachments across messages or reduce their sizes.
- **Escalate with:** The error line, aggregate size without contents, and `rc project chat doctor --bundle`.

## UNKNOWN_ACTION

- **Meaning:** The action id is absent from the project's approved live registry.
- **Who fixes:** you.
- **Self-fix:** Use the exact approved action id or complete the draft → review → approve lifecycle before invoking it.
- **Escalate with:** The error line and `rc dev action doctor ACTION_ID --bundle`.

## UNKNOWN_ATTACHMENT

- **Meaning:** The attachment does not exist in this session or is not reachable by this principal.
- **Who fixes:** you.
- **Self-fix:** Use the upload response id in the same session and do not reuse ids across sessions.
- **Escalate with:** The error line, session/attachment ids, and `rc project chat doctor --bundle`.

## UNKNOWN_PROJECT

- **Meaning:** The project query parameter is missing or does not name a visible ReplyPen project.
- **Who fixes:** you.
- **Self-fix:** Copy the public project slug supplied by the operator into both token and widget configuration.
- **Escalate with:** The error line, project slug, and `rc project chat doctor --bundle`.

## UNKNOWN_RUN

- **Meaning:** The feedback run id is absent from this session or not reachable by this principal.
- **Who fixes:** you.
- **Self-fix:** Use the `run_id` from that session's assistant message and do not accept arbitrary browser ids.
- **Escalate with:** The error line, session/run ids, and `rc project chat doctor --bundle`.

## UNKNOWN_SESSION

- **Meaning:** The session is missing, expired, belongs to another surface, or is not reachable by this token.
- **Who fixes:** you.
- **Self-fix:** Rehydrate only ids stored for this project/principal/tenant; open a new session when the old one expired.
- **Escalate with:** The error line, session id, and `rc project chat doctor --bundle`.

## UNKNOWN_TENANT

- **Meaning:** The token names a tenant slug not registered under the project.
- **Who fixes:** you.
- **Self-fix:** Map authenticated app context to the operator-provided slug; do not derive it from free-form browser input.
- **Escalate with:** The error line, tenant slug, and `rc project chat doctor --bundle`.

## UNSUPPORTED_TYPE

- **Meaning:** Uploaded bytes do not match an allowed file type or the declared type is misleading.
- **Who fixes:** you.
- **Self-fix:** Validate actual file bytes and upload a supported image, PDF, CSV, text, JSON, or spreadsheet type.
- **Escalate with:** The error line and file name/declared/detected type without contents plus `rc project chat doctor --bundle`.

## WIDGET_LOADER_NOT_FOUND

- **Meaning:** The browser received `404` for `/chat/widget/v1/loader.js`.
- **Who fixes:** you.
- **Self-fix:** Use `https://app.replypen.com/chat/widget/v1/loader.js?v=2` exactly and remove proxy path rewriting.
- **Escalate with:** The console error, requested URL without token/query data, and `rc project chat doctor --bundle`.

## WIDGET_PANEL_NOT_FOUND

- **Meaning:** The loader ran but the ReplyPen panel or launcher iframe returned `404`.
- **Who fixes:** operator.
- **Self-fix:** Confirm the project, origin, and CSP, then reproduce once without browser extensions or a rewriting proxy.
- **Escalate with:** The console error, non-secret origin, browser/network status, and `rc project chat doctor --bundle`.

## WIDGET_SCRIPT_BLOCKED

- **Meaning:** The host page's Content Security Policy or a browser blocker refused the loader script.
- **Who fixes:** you.
- **Self-fix:** Add `https://app.replypen.com` to `script-src`, `frame-src`, and `connect-src`; do not add unsafe directives.
- **Escalate with:** The console CSP line, redacted CSP directives, and `rc project chat doctor --bundle`.

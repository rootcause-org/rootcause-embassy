# Error catalogue

Every customer-facing error has a stable SCREAMING_SNAKE code, one plain-language hint, and a docs
link of this form:

```text
https://github.com/rootcause-org/rootcause-embassy/blob/main/docs/integrator/errors.md#<code-lowercased>
```

The widget writes `console.error("[ReplyPen] <CODE>: <hint> — <docs>")`. Never include tokens,
secrets, personal data, private host details, provider names, costs, or stack traces in an error or
bundle.

## ACTION_CLOCK_SKEW_INVALID

- **Meaning:** The configured action clock-skew allowance is outside the safe range.
- **Who fixes:** you.
- **Self-fix:** Set a non-negative allowance no greater than the documented maximum, then restart the app.
- **Escalate with:** The error line, Embassy version, and redacted action configuration.

## ACTION_CONFLICT

- **Meaning:** The chat action proposal could not be settled safely; its state may have changed.
- **Who fixes:** operator.
- **Self-fix:** Re-read the action card/session. Do not repeat a confirmation while the outcome is unknown.
- **Escalate with:** The error line and `rc dev action doctor --bundle`.

## ACTION_DEADLINE_INVALID

- **Meaning:** The configured action deadline is outside the safe range.
- **Who fixes:** you.
- **Self-fix:** Set a positive deadline within the documented maximum, then restart the app.
- **Escalate with:** The error line, Embassy version, and redacted action configuration.

## ACTION_EXECUTION_FAILED

- **Meaning:** The approved action script could not complete successfully.
- **Who fixes:** you.
- **Self-fix:** Inspect the safe execution result, fix the app dependency or handler, and do not retry while the outcome is uncertain.
- **Escalate with:** The error line and `rc dev action doctor ACTION_ID --bundle`.

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

## ACTION_FETCH_URL_REQUIRED

- **Meaning:** Actions are enabled, but no signed script-fetch URL is configured.
- **Who fixes:** you.
- **Self-fix:** Set `ROOTCAUSE_FETCH_URL` to the host-provided HTTPS endpoint and restart the app.
- **Escalate with:** The error line, Embassy version, and redacted action configuration.

## ACTION_PLANE_DISABLED

- **Meaning:** An action or result route was called while the Embassy action plane is disabled.
- **Who fixes:** you.
- **Self-fix:** Configure the complete action plane, or treat this 503 as expected in chat-only mode.
- **Escalate with:** The error line and redacted Embassy configuration; never send secrets.

## ACTION_PROJECT_UNKNOWN

- **Meaning:** The action request names a project that has no configured verification secret.
- **Who fixes:** operator.
- **Self-fix:** Confirm the project slug and configure that project's action secret without exposing it.
- **Escalate with:** The error line, project slug, Embassy version, and `rc dev action doctor --bundle`.

## ACTION_RESOLVE_FAILED

- **Meaning:** ReplyPen could not resolve the approved action definition and pinned script digest.
- **Who fixes:** operator.
- **Self-fix:** Confirm the action id is approved and live in the project brain; do not substitute an unapproved script.
- **Escalate with:** The error line and `rc dev action doctor ACTION_ID --bundle`.

## ACTION_SECRETS_INVALID

- **Meaning:** The per-project action-secret map contains a blank project or secret.
- **Who fixes:** you.
- **Self-fix:** Remove blank entries and provide one non-empty secret for every configured project.
- **Escalate with:** The error line and only redacted map keys; never send secret values.

## ACTION_SECRET_REQUIRED

- **Meaning:** Actions are partially configured without a usable verification secret.
- **Who fixes:** you.
- **Self-fix:** Set `ROOTCAUSE_ACTION_SECRET` or a complete per-project secret map, then restart the app.
- **Escalate with:** The error line and redacted Embassy configuration; never send secrets.

## ACTION_TIMEOUT_INVALID

- **Meaning:** The configured action execution timeout is outside the safe range.
- **Who fixes:** you.
- **Self-fix:** Set a positive timeout no greater than the action deadline, then restart the app.
- **Escalate with:** The error line, Embassy version, and redacted duration settings.

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

## ANALYSIS_BODY_REQUIRED

- **Meaning:** An analysis trigger was requested without content to analyze.
- **Who fixes:** you.
- **Self-fix:** Supply a non-empty body before calling the trigger helper.
- **Escalate with:** The error line and a redacted request shape.

## ANALYSIS_REQUEST_INVALID

- **Meaning:** The Embassy could not construct a valid analysis-trigger request.
- **Who fixes:** you.
- **Self-fix:** Check the trigger URL and request fields, then retry with documented values.
- **Escalate with:** The error line, Embassy version, and a redacted request shape.

## ANALYSIS_RESPONSE_INVALID

- **Meaning:** The analysis-trigger endpoint returned an invalid or unsuccessful response.
- **Who fixes:** operator.
- **Self-fix:** Verify the configured endpoint and host health; do not parse the response as success.
- **Escalate with:** The error line, HTTP status, and a redacted response shape.

## ANALYSIS_TRIGGER_URL_REQUIRED

- **Meaning:** Analysis triggering was requested without a configured endpoint.
- **Who fixes:** you.
- **Self-fix:** Set `ROOTCAUSE_TRIGGER_URL` to the host-provided HTTPS endpoint and restart the app.
- **Escalate with:** The error line and redacted Embassy configuration.

## API_BASE_URL_INVALID

- **Meaning:** The configured ReplyPen API base URL is malformed or unsafe.
- **Who fixes:** you.
- **Self-fix:** Use the exact host-provided HTTP or HTTPS origin without credentials, query, or fragment.
- **Escalate with:** The error line and the redacted base URL.

## API_BASE_URL_REQUIRED

- **Meaning:** An API call was requested without a configured ReplyPen API base URL.
- **Who fixes:** you.
- **Self-fix:** Set `ROOTCAUSE_API_BASE_URL` and restart the app.
- **Escalate with:** The error line and redacted Embassy configuration.

## API_KEY_REQUIRED

- **Meaning:** An API call was requested without a ReplyPen API key.
- **Who fixes:** you.
- **Self-fix:** Set `ROOTCAUSE_API_KEY` in the app environment and restart; never log the value.
- **Escalate with:** The error line and only whether the variable is present; never send the key.

## API_METHOD_INVALID

- **Meaning:** The API helper received an empty or malformed HTTP method.
- **Who fixes:** you.
- **Self-fix:** Pass a standard uppercase HTTP method supported by the target route.
- **Escalate with:** The error line and redacted call shape.

## API_ORIGIN_MISMATCH

- **Meaning:** An API path resolved outside the configured ReplyPen API origin.
- **Who fixes:** you.
- **Self-fix:** Pass a relative API path on the configured origin; never construct a cross-origin target.
- **Escalate with:** The error line, base origin, and redacted path.

## API_PATH_INVALID

- **Meaning:** The API helper received a malformed request path.
- **Who fixes:** you.
- **Self-fix:** Pass a valid relative path without credentials or an alternate origin.
- **Escalate with:** The error line and redacted path.

## API_PATH_REQUIRED

- **Meaning:** The API helper was called without a request path.
- **Who fixes:** you.
- **Self-fix:** Supply the documented route path.
- **Escalate with:** The error line and caller location.

## API_REQUEST_INVALID

- **Meaning:** The API helper could not encode or create the outbound request.
- **Who fixes:** you.
- **Self-fix:** Validate the request value and route path before retrying.
- **Escalate with:** The error line, Embassy version, and redacted request shape.

## API_RESPONSE_INVALID

- **Meaning:** The ReplyPen API response was malformed or could not be decoded safely.
- **Who fixes:** operator.
- **Self-fix:** Confirm host compatibility and retry only if the operation is safe to repeat.
- **Escalate with:** The error line, HTTP status, and a redacted response shape.

## API_TRANSPORT_ERROR

- **Meaning:** The app could not complete the network request to the ReplyPen API.
- **Who fixes:** operator.
- **Self-fix:** Check DNS, TLS, egress, and host availability before a safe retry.
- **Escalate with:** The error line, target hostname, and request timing; never send credentials.

## ATTACHMENT_ALREADY_SENT

- **Meaning:** This upload is already bound to another message and cannot be reused.
- **Who fixes:** you.
- **Self-fix:** Upload the file again and use the new `attachment_id` in exactly one message.
- **Escalate with:** The error line and `rc project chat doctor --bundle` if a new upload also fails.

## ATTACHMENT_INVALID

- **Meaning:** A Go Embassy attachment is missing a valid name, MIME type, reader, or size.
- **Who fixes:** you.
- **Self-fix:** Populate every required attachment field with the actual non-negative file size.
- **Escalate with:** The error line and file metadata without contents.

## ATTACHMENT_TOO_LARGE

- **Meaning:** One Go Embassy attachment exceeds the per-file upload limit.
- **Who fixes:** you.
- **Self-fix:** Reject or shrink the file before calling the Embassy helper.
- **Escalate with:** The error line and file name, MIME type, and size without contents.

## ATTACHMENTS_TOO_LARGE

- **Meaning:** The combined Go Embassy attachment payload exceeds the request limit.
- **Who fixes:** you.
- **Self-fix:** Send fewer or smaller files while keeping every file within its individual limit.
- **Escalate with:** The error line and redacted file metadata without contents.

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

## CHAT_BASE_URL_INVALID

- **Meaning:** The configured chat base URL is malformed or unsafe.
- **Who fixes:** you.
- **Self-fix:** Use the default or an exact HTTP or HTTPS ReplyPen origin without credentials, query, or fragment.
- **Escalate with:** The error line and redacted base URL.

## CHAT_DISABLED

- **Meaning:** Embedded chat is disabled for the project.
- **Who fixes:** operator.
- **Self-fix:** Confirm the intended project slug, then ask the operator to enable chat for it.
- **Escalate with:** The error line and `rc project chat doctor --bundle`.

## CHAT_EXTERNAL_ID_REQUIRED

- **Meaning:** Chat token minting was attempted without the app's authenticated external user id.
- **Who fixes:** you.
- **Self-fix:** Resolve the external id from the server-side app session; never accept it from browser input.
- **Escalate with:** The error line and the redacted server-side identity mapping.

## CHAT_PROJECT_REQUIRED

- **Meaning:** Chat token minting was attempted without a project slug.
- **Who fixes:** you.
- **Self-fix:** Set `ROOTCAUSE_CHAT_PROJECT` to the operator-provided slug and restart the app.
- **Escalate with:** The error line and redacted chat configuration.

## CHAT_SECRET_REQUIRED

- **Meaning:** Chat token minting was attempted without a signing secret.
- **Who fixes:** you.
- **Self-fix:** Set `ROOTCAUSE_CHAT_SECRET` in the server environment and restart; never expose it to the browser.
- **Escalate with:** The error line and only whether the variable is present; never send the secret.

## CHAT_SECRET_REUSED

- **Meaning:** The same secret was configured for chat JWTs and action HMAC verification.
- **Who fixes:** you.
- **Self-fix:** Provision distinct random secrets for the chat and action planes, then restart the app.
- **Escalate with:** The error line and only secret fingerprints from an approved doctor command.

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

## HOST_REFUSED

- **Meaning:** The ReplyPen host refused an API request without a more specific stable code.
- **Who fixes:** operator.
- **Self-fix:** Read the safe host hint, verify the request contract, and do not infer success.
- **Escalate with:** The error line, HTTP status, request path, and redacted response shape.

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

## ORIGIN_INVALID

- **Meaning:** The origin supplied for chat token minting is not a canonical HTTP or HTTPS origin.
- **Who fixes:** you.
- **Self-fix:** Derive the exact public app origin server-side and omit paths, credentials, query, and fragment.
- **Escalate with:** The error line and redacted origin.

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

## SENT_MESSAGE_CONTENT_REQUIRED

- **Meaning:** Sent-message reporting was attempted without message content.
- **Who fixes:** you.
- **Self-fix:** Supply a non-empty subject or body according to the sent-message contract.
- **Escalate with:** The error line and redacted request shape.

## SENT_MESSAGE_INVALID

- **Meaning:** The Embassy could not construct a valid sent-message report.
- **Who fixes:** you.
- **Self-fix:** Validate the session id, recipients, and content fields before retrying.
- **Escalate with:** The error line, Embassy version, and redacted request shape.

## SENT_MESSAGE_RESPONSE_INVALID

- **Meaning:** The sent-message endpoint returned an invalid or unsuccessful response.
- **Who fixes:** operator.
- **Self-fix:** Verify endpoint compatibility and do not report the message twice while acceptance is uncertain.
- **Escalate with:** The error line, HTTP status, and redacted response shape.

## SENT_MESSAGE_URL_REQUIRED

- **Meaning:** Sent-message reporting was requested without a configured endpoint.
- **Who fixes:** you.
- **Self-fix:** Set `ROOTCAUSE_SENT_MESSAGE_URL` to the host-provided HTTPS endpoint and restart the app.
- **Escalate with:** The error line and redacted Embassy configuration.

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

## SESSION_ID_REQUIRED

- **Meaning:** An Embassy helper requiring chat continuity was called without a session id.
- **Who fixes:** you.
- **Self-fix:** Preserve and pass the ReplyPen session id without accepting a browser-forged replacement.
- **Escalate with:** The error line and redacted request flow.

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

## TOKEN_EXCHANGE_FAILED

- **Meaning:** The host refused or could not complete a chat token exchange.
- **Who fixes:** operator.
- **Self-fix:** Mint a fresh backend token and verify project, principal, origin, and clock configuration.
- **Escalate with:** The error line and `rc project chat doctor --bundle`; never paste the token.

## TOKEN_MINT_FAILED

- **Meaning:** The Go Embassy could not sign a valid chat JWT.
- **Who fixes:** you.
- **Self-fix:** Validate chat configuration, origin, claims, and server clock, then mint a fresh token.
- **Escalate with:** The error line, Embassy version, and redacted claims; never send a token or secret.

## TOKEN_REPLAYED

- **Meaning:** The token's single-use `jti` already opened a session.
- **Who fixes:** you.
- **Self-fix:** Mint a fresh token with a new UUID `jti` for every new session/render; keep the original page token for its existing session calls.
- **Escalate with:** The error line, mint/open timestamps, and `rc project chat doctor --bundle`; never paste either token.

## TOKEN_TTL_INVALID

- **Meaning:** The requested chat-token lifetime is outside the allowed range.
- **Who fixes:** you.
- **Self-fix:** Use the two-hour default or a positive duration no greater than 24 hours.
- **Escalate with:** The error line and requested duration.

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

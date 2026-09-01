# Verification ladder

Run the doctor first when stuck:

```sh
rc project chat doctor [--origin https://app.acme.example] [--principal-kind acme_user]
rc dev action doctor <action-id>
```

Chat doctor requires `rc >= 1.22.0`. Use `--bundle` only for escalation, because its output is shaped
for sharing. Rungs 1–2 are fully local. Rungs 3–6 require the operator to have supplied the secret and
confirmed project, origins, principal kinds, and tenants. Complete each rung in order; a higher rung
does not replace a lower one.

## Chat

1. Unit vector

   Command: run your language package's chat/conformance test against
   `fixtures/chat/jwt_vector.json`.

   Expect: byte-exact `signing_input` and `token` match.

   On failure: [`BAD_TOKEN`](errors.md#bad_token).

2. Widget tag

   Command: for a server-rendered integration, render the widget tag in a unit test and compare it
   with `fixtures/chat/widget_tag.html` after substituting only documented inputs. For an SPA that
   constructs the tag in browser code, assert the loader path, `?v=2`, all required attributes, and
   that each optional attribute appears only when configured.

   Expect: loader `?v=2`, project, token, and optional attributes are escaped correctly.

   On failure: this is a local assertion, not a host code — fix the tag against the golden. A wrong
   loader URL surfaces later as [`WIDGET_LOADER_NOT_FOUND`](errors.md#widget_loader_not_found), a
   bad mode/target as [`WIDGET_MODE_INVALID`](errors.md#widget_mode_invalid) /
   [`WIDGET_TARGET_INVALID`](errors.md#widget_target_invalid).

3. Open a session

   Command:

   ```sh
   curl -i -X POST 'https://app.replypen.com/chat/v1/session?project=acme' \
     -H 'Authorization: Bearer <fresh-token>' \
     -H 'Origin: https://app.acme.example'
   ```

   Expect: `200` and `{"session_id":"<uuid>","greeting":"<text>"}`.

   On failure: use the returned code; common codes are [`ORIGIN_NOT_ALLOWED`](errors.md#origin_not_allowed)
   and [`BAD_TOKEN`](errors.md#bad_token).

4. Prove replay protection

   Command: repeat rung 3 with the exact same token.

   Expect: `401 TOKEN_REPLAYED`.

   Any second `200` is a security failure. Escalate with a chat bundle.

5. Stream one turn

   Command:

   ```sh
   curl -N -X POST 'https://app.replypen.com/chat/v1/message?project=acme' \
     -H 'Authorization: Bearer <page-token>' \
     -H 'Origin: https://app.acme.example' \
     -H 'Content-Type: application/json' \
     --data '{"session_id":"<uuid>","message":{"id":"client-message-1","parts":[{"type":"text","text":"Hello"}]}}'
   ```

   Expect: SSE frames through `finish`, then `data: [DONE]`.

   On failure: [`SESSION_DRIFT`](errors.md#session_drift),
   [`RUN_IN_FLIGHT`](errors.md#run_in_flight), or the returned code.

6. Browser origins

   Command: open the real widget once on an allowed origin and once on a host absent from
   `chat_origins`.

   Expect: allowed origin loads; denied origin fails closed with `ORIGIN_NOT_ALLOWED`.

   If both load, stop: the origin boundary is misconfigured. If neither loads, check
   [`WIDGET_SCRIPT_BLOCKED`](errors.md#widget_script_blocked) and the CSP in `chat.md`.

## Actions

7. Probes and dry run

   Command:

   ```sh
   rc dev action doctor <action-id>
   rc dev action doctor <action-id> --params '{"...":"..."}'   # adds the dry-run preflight
   ```

   Expect: resolution ok, mount present, signed protocol `1` health with the Embassy version and
   capability tokens, and a preflight that reports `would_execute` with no data change.

   You can also probe the mount directly from your own network:

   ```sh
   curl -i -X GET <mount>                                     # expect 405 + Allow: POST
   sig=$(printf 'project_id=<uuid>' | openssl dgst -sha256 -hmac "$ROOTCAUSE_ACTION_SECRET" -r | cut -d' ' -f1)
   curl -i "<mount>/health?project_id=<uuid>" -H "X-Webhook-Signature: $sig"
   ```

   An unsigned health request returns an opaque `404` by design.

   On failure: use the returned refusal, commonly [`BAD_SIGNATURE`](errors.md#bad_signature),
   [`RESOLVE_FAILED`](errors.md#resolve_failed), or [`SCHEMA_VIOLATION`](errors.md#schema_violation).

8. Host workflow smoke

   Command:

   ```sh
   rc ask 'Exercise the new integration without changing data'
   rc run debug <run-id>
   ```

   Expect: the run completes and the debug artifact shows the intended grounded path without secrets.

   On failure: capture the run id; never paste an unredacted debug artifact into a public issue.

9. Real gated action

   Command: trigger one harmless proposal, inspect its params and digest, confirm it, then inspect the
   resulting run.

   Expect: `proposed → executing → succeeded`, one intended change, and a signed Embassy result.

   On failure or uncertain outcome: do not retry blindly. Run `rc dev action doctor <action-id> --bundle` and
   escalate.

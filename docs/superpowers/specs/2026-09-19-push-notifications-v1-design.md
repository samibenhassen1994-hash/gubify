# Gubify Push Notifications V1 Design

## Purpose and scope

Gubify Push Notifications V1 adds a global, per-user notification inbox and FCM delivery without replacing or changing the existing Private Gub notification system under `gubs/{gubId}/notifications`.

Only these six events are supported:

1. `task_assigned`: the task assignee only, provided the assignee is non-empty and different from the creator.
2. `proposal_created`: every current Gub member except the proposal creator.
3. `community_answer_created`: the Ask author only, excluding the Answer author, while the Ask is active.
4. `community_best_answer_selected`: the selected Answer author only, once per resolved Ask.
5. `community_join_request_created`: the Community owner and active Platform Admins currently authorized to manage the request, excluding the requester.
6. `community_join_request_resolved`: the requester only, with distinct approved/rejected copy.

Chat messages, task completion, proposal outcomes, XP, levels, leaderboards, generic activity, and new-member events remain out of scope.

## Repository boundaries

- Flutter app worktree: `C:\Users\samib\Projects\gubify-push-notifications-v1`, branch `feature/push-notifications-v1`, based on `1fc87dd6e8d95060eccbcef39321d671655cb2b6`.
- Worker worktree: `C:\Users\samib\Projects\gubify-website-push-notifications-v1`, branch `feature/push-notifications-worker-v1`, based on `c26d6caef61ffcdd3bcd6b73ebb1ed0d31f27c75`.
- The original checkouts and their `master`, `main`, and `home-interactive-world-redesign` branches remain untouched.
- No production deployment or real secret configuration is part of this implementation.

## Architecture overview

The domain write remains client-owned and Rules-protected. After a Task, Proposal, Answer, Ask resolution, or Join Request mutation completes successfully, the Flutter client sends a best-effort event request to the Worker containing only the event type and authoritative entity identifiers. Push failure never rolls back or corrupts the already-completed domain operation.

The Worker authenticates the caller with a fully verified Firebase ID token, reloads all authoritative Firestore documents, validates that the event exists and that the caller was allowed to cause it, derives recipients and message copy server-side, and uses a deterministic event key. It persists a deterministic delivery plan and enqueues bounded recipient chunks in Cloudflare Queue. Queue consumers create one deterministic inbox document per recipient, load that recipient's registered devices, send FCM HTTP v1 messages, and remove device records for permanently invalid tokens.

The Flutter app reads only its own global inbox and devices. It never supplies recipient IDs, notification titles, or notification bodies.

## Firestore schema

### Device registrations

Path:

`users/{uid}/devices/{deviceId}`

Fields:

- `deviceId`: stable per-install UUID and equal to the document ID.
- `token`: current FCM registration token.
- `platform`: one of `android`, `ios`.
- `updatedAt`: server timestamp.

The install UUID is stored locally with `shared_preferences`. Token refresh updates the same document. Every logout, account switch, and authenticated-session teardown first invokes a dedicated unregister operation while the old Firebase session is still valid: it deletes `users/{oldUid}/devices/{deviceId}`, then calls `FirebaseMessaging.deleteToken()`, and only then invokes Firebase Auth logout. If the Firestore delete fails, token deletion is still attempted so any stale server document points to an invalid registration token that the Worker can later remove. A subsequent login obtains a fresh token and registers the installation under the new UID. Anonymous-to-linked account conversion preserves the UID and therefore updates the existing registration rather than unregistering it. Full tokens are never logged.

### Global notification inbox

Path:

`users/{uid}/pushNotifications/{notificationId}`

The document ID is deterministic from `eventKey` and recipient UID. Fields:

- `id`: equal to `notificationId`.
- `eventKey`: deterministic event identity.
- `type`: one of the six supported event types.
- `title`: Worker-generated title.
- `body`: Worker-generated body.
- `createdAt`: Worker/server timestamp.
- `read`: boolean, initially `false`.
- `actorId`: optional authoritative actor UID.
- `data`: bounded routing map containing only required IDs such as `gubId`, `taskId`, `proposalId`, `communityId`, `askId`, and resolution outcome.

No `readBy` array is used because each document belongs to exactly one recipient.

### Worker idempotency

Path:

`pushDeliveryEvents/{eventKey}`

The Worker creates or observes a deterministic event guard recording the canonical event type, authoritative recipient set, and deterministic chunk plan. Recipient inbox document IDs are deterministic, and inbox creation is an idempotent create-or-read operation: retries cannot create duplicate inbox entries or reset an already-read document to unread.

FCM delivery is deliberately best-effort rather than exactly-once. Queue retries may resend an FCM message after an ambiguous timeout. Every FCM payload therefore uses the deterministic notification ID/event key as Android `notification.tag`, Android collapse key where supported, and APNs `apns-collapse-id`, reducing duplicate visible notifications while acknowledging that FCM cannot guarantee exactly-once device delivery. No design claim relies on a per-device exactly-once delivery ledger.

`eventKey` formats are canonical and entity-based, for example:

- `task_assigned__{gubId}__{taskId}`
- `proposal_created__{gubId}__{proposalId}`
- `community_answer_created__{communityId}__{askId}__{answerId}`
- `community_best_answer_selected__{communityId}__{askId}__{answerId}`
- `community_join_request_created__{communityId}__{requesterUid}__{requestedAt}`
- `community_join_request_resolved__{communityId}__{requesterUid}__{requestedAt}__{status}`

Join Request documents gain an immutable-per-cycle `requestedAt` server timestamp. A newly created request stores `createdAt == requestedAt`. When an already approved/rejected request is reset to `pending`, the existing document keeps its historical `createdAt` but receives a new server-side `requestedAt`; approval/rejection preserves that value. Thus every pending→resolved lifecycle has one authoritative cycle identifier even though the document ID is reused. The Worker rejects Join Request events without a valid `requestedAt`, and all event keys derive it from the authoritative request document rather than client input.

## Firestore Rules

Rules changes are limited to the two new user subcollections:

### `users/{uid}/devices/{deviceId}`

- Only authenticated `uid == request.auth.uid` can get/list/create/update/delete.
- Create/update require exact keys, `deviceId` equal to the path ID, non-empty bounded token, supported platform, and `updatedAt == request.time`.
- A user in irreversible account-deletion state cannot create or update device registrations, but may delete their own registration as cleanup.
- No user can access another user's devices.

### `users/{uid}/pushNotifications/{notificationId}`

- Only authenticated `uid == request.auth.uid` can get/list.
- Client create/delete are denied.
- Client update may change only `read` from `false` to `true`; all other fields must remain unchanged.
- No user can access another user's inbox.

The Worker uses service-account authorization and is not granted through client Rules. Existing Rules for `gubs/{gubId}/notifications` remain byte-for-byte unchanged unless a failing regression demonstrates otherwise; in that case implementation stops for review.

## Worker endpoint and authentication

Endpoint:

`POST /api/push/events`

Request headers:

- `Authorization: Bearer <Firebase ID token>`
- `Content-Type: application/json`

Request body is a discriminated union containing only `type` and required entity IDs. Unknown keys, recipient fields, title, or body are rejected.

Worker modules remain separate from `worker/index.ts`:

- Firebase ID-token verification using Google's Secure Token JWKS/certificates and Web Crypto.
- Service-account OAuth access-token creation for Firestore and FCM HTTP v1.
- Firestore REST helpers and strict document decoding.
- Event validation/recipient resolution.
- Inbox/idempotency persistence.
- Queue producer, deterministic delivery chunks, Queue consumer, FCM delivery, and invalid-token cleanup.
- HTTP route handler.

`worker/index.ts` only recognizes the push route and delegates to the module; existing website, image, Community catalog, and sitemap routing remain unchanged.

Required Worker configuration:

- Existing non-secret: `FIREBASE_PROJECT_ID`.
- Secret: `FIREBASE_CLIENT_EMAIL`.
- Secret: `FIREBASE_PRIVATE_KEY`.
- Queue binding: `PUSH_DELIVERY_QUEUE`.
- Rate Limiting binding: `PUSH_EVENTS_RATE_LIMITER`.

No credentials or example private-key values are committed.

Firebase ID-token verification is complete rather than decode-only. The verifier requires `alg == RS256`, resolves `kid` against Google's Secure Token public keys, verifies the signature with Web Crypto, and validates `iss == https://securetoken.google.com/{FIREBASE_PROJECT_ID}`, `aud == FIREBASE_PROJECT_ID`, non-empty bounded `sub`, `exp`, `iat`, and `auth_time` with a small documented clock-skew allowance. Public keys are cached with the Cloudflare Cache API according to Google's cache headers and refreshed on an unknown `kid`; failed verification never reaches event validation.

The endpoint applies Cloudflare's Rate Limiting binding before expensive Firestore/FCM work. It limits by a privacy-preserving hash of source IP before authentication and by verified Firebase UID after authentication. Rate-limit responses use HTTP 429 and do not create event guards or inbox documents. Exact limits remain configuration constants covered by tests and are conservative enough for legitimate retries.

The HTTP handler performs authentication and authoritative validation only, persists the deterministic event/delivery plan, and sends recipient chunk references to `PUSH_DELIVERY_QUEUE`. Chunks contain no credentials or message text supplied by the client and are bounded (maximum 25 recipient UIDs per message). The Queue consumer re-reads the persisted authoritative plan, processes bounded recipient/device batches, and uses `ctx.waitUntil` only for short cleanup work. This keeps CPU time, subrequest count, message size, and retry behavior compatible with Workers Free limits. Chunk IDs and inbox IDs are deterministic, so Queue redelivery is safe.

## Server-side event validation

### Task assigned

The Worker loads `gubs/{gubId}/tasks/{taskId}`, verifies canonical IDs, active task/Gub state, caller equals `creatorId`, and caller has current Gub creation authority. Recipient is authoritative `assignedUserId`; empty/self-assigned tasks produce no delivery.

### Proposal created

The Worker loads the proposal and Gub, verifies caller equals `creatorId` and the proposal exists in its creation state, then reads current `gubs/{gubId}/members`. Recipients are current member UIDs except the creator.

### Community Answer created

The Worker loads the Community, Ask, and `answers/{answerId}`, verifies Answer ID/author/caller consistency, Ask ownership linkage, and Ask status remains `active`. Recipient is the Ask `authorId`, except when equal to Answer author.

### Best Answer selected

The Worker loads the resolved Ask and selected Answer, verifies the authoritative `bestAnswerId`, `bestAnswerAuthorId`, resolved status, and caller equals the Ask author. Recipient is the selected Answer author. Deterministic idempotency produces one notification.

### Join Request received

The Worker loads the Community and pending request, verifies requester/caller consistency, approval access mode, and a valid authoritative `requestedAt` for the current pending cycle. Recipients are the Community owner plus every active Platform Admin whose user profile still exists and who is not in account-deletion state. No local Community admin role is introduced.

### Join Request resolved

The Worker loads the request and Community, verifies status is `approved` or `rejected`, `resolvedBy` equals the caller, the request retains the same authoritative `requestedAt` from its pending cycle, and caller is either the Community owner or an active Platform Admin under current architecture. Recipient is the authoritative request `userId`.

## Flutter event delivery

A small authenticated HTTP client obtains `FirebaseAuth.currentUser.getIdToken()`, sends the event IDs after the domain mutation succeeds, and treats delivery as best-effort. It does not expose push failures as domain-write failures. Logging contains event type and coarse error class only, never ID tokens or device tokens.

Hooks are additive and do not change repository transaction semantics:

- `TaskService.createTask` after task creation.
- `ProposalService.createProposal` after proposal creation, alongside but separate from the existing internal Gub notification.
- `CommunityAskAnswerService` after successful Answer creation.
- Ask resolution service after successful resolution.
- `CommunityService.requestToJoin` after successful pending request creation.
- Community approve/reject methods after successful transition.

Test seams allow event delivery to be asserted without network requests.

## Flutter FCM lifecycle

`PushNotificationService` starts only after Firebase initialization and authenticated navigation readiness. It:

- registers the top-level `@pragma('vm:entry-point')` background handler before `runApp`;
- requests notification permission after the authenticated application is ready, not during splash/auth entry;
- creates the Android high-importance notification channel with notification dots enabled;
- obtains and stores the token for the current Firebase UID;
- observes `onTokenRefresh`;
- observes Firebase Auth user changes to detach the installation from the previous UID and attach it to the current UID;
- handles `onMessage` by relying on the Worker-written inbox stream for UI updates and avoiding an extra foreground system notification;
- handles `onMessageOpenedApp` and `getInitialMessage` through a coordinator that waits for navigation readiness;
- when a system push is opened, extracts the authoritative `notificationId`, marks that inbox document read before routing, and then opens the destination. Failure to mark read does not bypass destination validation, but is surfaced to the coordinator for bounded retry while the inbox stream remains authoritative.

Account linking preserves the UID and therefore updates the same device record without breaking Anonymous-to-Google linking.

All background/terminated deliveries use an FCM payload containing both `notification` and `data`. The `notification` block allows Android/iOS to display a system notification while the app is not foregrounded. The `data` block contains `notificationId`, `eventKey`, `type`, and only the bounded routing IDs needed by the app. Foreground handling does not synthesize a second local/system notification, preventing duplicate visible alerts.

On Android, the high-importance notification channel enables `showBadge`/notification dots. This does not mirror Firestore unread state and does not create a numeric app badge: launcher dots represent active system notifications and disappear according to Android/launcher behavior when those notifications are opened, dismissed, or cleared. The in-app red bell dot remains independently driven by the Firestore unread existence query.

## Inbox and navbar badge

`GlobalNotificationsScreen` becomes a bounded recent inbox:

- query: `users/{uid}/pushNotifications`, ordered by `createdAt` descending, limited to 50;
- loading, empty, error, and notification-card states;
- tap marks only that document `read: true`, then invokes the global notification router;
- no interaction with Private Gub `NotificationModel`, `NotificationRepository`, `NotificationService`, `NotificationsScreen`, or `NotificationRouter`.

The navbar uses one stream for:

`where('read', isEqualTo: false).limit(1)`

It maps the snapshot to a boolean `hasUnreadNotifications`. The Notifications icon shows a small red circle with no text. No aggregate count and no full-collection read are used.

## Global routing

A separate `GlobalPushNotificationRouter` resolves each notification destination authoritatively before navigation:

- task → existing `TaskDetailsScreen`.
- proposal → existing `ProposalDetailsScreen`.
- Answer / Best Answer → `CommunityAskDetailsScreen` for the exact Ask.
- pending Join Request → `CommunityJoinRequestsScreen` for the exact Community, after confirming current management access.
- resolved Join Request → active Community home if membership now exists; otherwise public Community details.

The coordinator uses the root navigator already owned by `GubifyApp`, queues one pending notification until startup navigation is ready, and avoids duplicate opens across initial-message and resumed-message paths.

Opening a notification from either the inbox or a system push uses the same coordinator operation: mark the deterministic inbox document read, deduplicate the open by `notificationId`, then route. This ensures the navbar dot clears from the authoritative inbox state after a system-notification tap as well as an inbox tap.

## Error handling and consistency

- Domain operations complete independently of push delivery.
- Invalid or stale events return a non-success Worker response without creating inbox documents.
- Missing/deleted destination content displays a simple unavailable message rather than crashing.
- An FCM error never deletes inbox history.
- Only permanent token errors (`UNREGISTERED` and equivalent invalid-registration responses) delete the matching device record; transient errors remain retryable.
- Inbox creation is strongly idempotent and never duplicated or reset by retries.
- FCM delivery remains best-effort/at-least-once under Queue retry. Deterministic collapse identifiers/tags reduce duplicate visible notifications but do not claim exactly-once delivery.

## Tests

### Flutter

- model/repository schema and recent-50 query;
- mark-read behavior and ownership path;
- unread existence query uses `read == false` and `limit(1)`;
- navbar badge absent/present, red dot only, no number;
- inbox loading/empty/error/read states;
- routing for all six event types and unavailable destinations;
- device registration, token refresh, user switching, linking with unchanged UID, and no full-token logging;
- device unregister and FCM token deletion complete before Firebase Auth logout/account switch;
- background/initial/opened-message coordinator and navigation-readiness queue;
- system-push open marks the inbox document read before routing;
- six service hooks fire only after successful writes and do not change domain success on delivery failure;
- existing Private Gub notification tests remain unchanged and green.

### Firestore emulator

- exact device schema and own-user CRUD;
- other-user access denied;
- device writes blocked during account deletion except cleanup delete;
- inbox owner read/list allowed;
- arbitrary client create/delete denied;
- only `read: false -> true` accepted;
- all other inbox mutations denied;
- existing Private Gub notification Rules regressions remain green.

### Worker

- Firebase token verification success/failure;
- strict request schema rejects recipient/title/body injection;
- authoritative validation and recipients for all six events;
- Answer-after-resolution rejection;
- owner/active Platform Admin join-request recipients;
- distinct Join Request cycles on the same document produce distinct `requestedAt` event keys;
- resolved-request authorization and copy;
- full Firebase ID-token signature/issuer/audience/time validation, key caching/refresh, and rate limiting;
- deterministic event/chunk/inbox IDs and Queue redelivery behavior;
- multi-device delivery;
- `notification + data` FCM payloads with deterministic Android/APNs collapse identifiers;
- permanent invalid-token cleanup and transient-error retention;
- existing Worker tests/lint/build remain green.

## Known V1 trade-offs

Cloudflare Workers do not provide native Firestore document triggers. Therefore event dispatch is initiated by the successful Flutter operation. If the app is terminated after the Firestore write but before the Worker request begins, that event may not produce a push. Deterministic event keys make explicit retries safe, but V1 does not add a polling scheduler or Cloud Function. Closing that rare delivery gap would require a server-triggered outbox processor and is intentionally outside this V1. Once the Worker accepts an event, Cloudflare Queue provides bounded asynchronous fan-out and retry.

FCM delivery can duplicate under ambiguous network/Queue retry even though inbox creation cannot. Deterministic Android tags/collapse keys and APNs collapse IDs mitigate duplicate visible notifications; they do not create an exactly-once guarantee.

FCM launcher-dot appearance remains controlled by Android launchers and reflects active system notifications, not the Firestore unread collection. Gubify configures a channel that allows dots but does not implement numeric or OEM-specific badges.

## Acceptance criteria

- Exactly the six approved events can create global inbox documents and FCM deliveries.
- Recipient, title, body, and routing data are derived by the Worker from authoritative data.
- Reused Join Request documents identify each request cycle with authoritative `requestedAt`.
- Retries do not duplicate inbox entries; FCM remains explicitly best-effort with deterministic collapse identifiers.
- The global inbox is limited, read state is per recipient, and the navbar performs only an existence query.
- FCM tokens are per UID and per installation, refresh safely, and are unregistered/deleted before logout or user change.
- System-push taps mark the matching inbox notification read before routing.
- Worker fan-out uses bounded Cloudflare Queue chunks compatible with Workers Free constraints.
- Firebase ID tokens are fully verified with cached keys, and the endpoint is rate-limited.
- Existing Private Gub internal notifications and their Rules are unchanged.
- Flutter analyze/tests, complete Firestore Rules tests, and Worker tests/lint/build pass.
- No deployment, merge, or credential commit occurs.

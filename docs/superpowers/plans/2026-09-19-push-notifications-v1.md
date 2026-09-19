# Gubify Push Notifications V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the approved six-event global notification inbox and FCM delivery pipeline without changing the existing Private Gub notification system.

**Architecture:** Flutter completes each authoritative domain write, then submits only event type and entity IDs to an authenticated Worker endpoint. The Worker validates the Firebase ID token and authoritative Firestore state, persists a deterministic event plan, uses a paginated FANOUT Queue to discover recipients, emits one deterministic DELIVERY Queue job per recipient, pages devices, writes one idempotent inbox document, and sends best-effort FCM. Firestore Rules protect the new per-user device/inbox collections and add only the required `requestedAt` lifecycle validation to Community Join Requests.

**Tech Stack:** Flutter/Dart, Firebase Auth, Cloud Firestore, Firebase Messaging, Android notification channels, Node.js Firestore Rules emulator tests, TypeScript Cloudflare Worker, Cloudflare Queues, Web Crypto, Firestore REST, FCM HTTP v1.

**Spec:** `docs/superpowers/specs/2026-09-19-push-notifications-v1-design.md`

## Global Constraints

- Work only in `C:\Users\samib\Projects\gubify-push-notifications-v1` on `feature/push-notifications-v1` and `C:\Users\samib\Projects\gubify-website-push-notifications-v1` on `feature/push-notifications-worker-v1`.
- Do not modify the original checkouts, `master`, `main`, or `home-interactive-world-redesign`.
- Support exactly: `task_assigned`, `proposal_created`, `community_answer_created`, `community_best_answer_selected`, `community_join_request_created`, and `community_join_request_resolved`.
- Keep `gubs/{gubId}/notifications`, `NotificationModel`, `NotificationRepository`, `NotificationService`, `NotificationsScreen`, and their Firestore Rules byte-for-byte unchanged.
- Do not deploy, merge, configure production, execute the legacy migration against production, or commit secrets/credentials.
- Workers Free permits 50 external subrequests per invocation; every FANOUT and DELIVERY invocation enforces a maximum budget of 40.
- Cloudflare Queues Free has a finite daily operations quota. The design bounds messages and retries; it must never be described or tested as unlimited capacity.
- Inbox writes are strongly idempotent. FCM is best-effort/at-least-once with deterministic collapse identifiers.
- Domain success never depends on push delivery success.
- Migration rollout order is fixed: prepare migration → operator runs migration → verify zero legacy gaps → deploy Rules/Worker → release Flutter. This plan stops before every external execution/deploy step.

## Review Focus

- A Queue acceptance followed by a failed Firestore status write must retry without duplicate recipient or inbox documents; Task 7 pins both FANOUT and DELIVERY ambiguity.
- A proposal with more recipients than one page must finish through deterministic continuations while every invocation stays at or below 40 external subrequests; Task 7 owns this test.
- A legacy Join Request without `requestedAt` must be migrated idempotently and remain approvable/rejectable, with no retroactive push artifacts; Task 2 owns this test.
- Logout/account switch must delete the old UID's current installation record before Firebase Auth loses permission, even when token deletion fails transiently; Task 13 owns ordering and retry tests.
- Initial-message and resumed-message callbacks may deliver the same notification; Task 14 verifies one route open, read-before-route, and bounded retry.

---

## Phase 0 — Documentation checkpoint

### Task 1: Lock the approved contract and execution baseline

**Repository/worktree:** Flutter app — `C:\Users\samib\Projects\gubify-push-notifications-v1`

**Files:**
- Modify: `docs/superpowers/specs/2026-09-19-push-notifications-v1-design.md`
- Create: `docs/superpowers/plans/2026-09-19-push-notifications-v1.md`

**Interfaces:**
- Consumes: approved architecture and repository SHAs in the spec.
- Produces: the canonical payload/event names, rollout order, and task sequence used by both repositories.

- [ ] **Step 1: Verify isolated branches before implementation**

Run:

```powershell
git -C C:\Users\samib\Projects\gubify-push-notifications-v1 branch --show-current
git -C C:\Users\samib\Projects\gubify-push-notifications-v1 status --short
git -C C:\Users\samib\Projects\gubify-website-push-notifications-v1 branch --show-current
git -C C:\Users\samib\Projects\gubify-website-push-notifications-v1 status --short
```

Expected: the two approved feature branches and clean worktrees.

- [ ] **Step 2: Verify the documentation diff**

Run:

```powershell
git -C C:\Users\samib\Projects\gubify-push-notifications-v1 diff --check
git -C C:\Users\samib\Projects\gubify-push-notifications-v1 diff --stat
```

Expected: only the spec correction and this plan; no production files.

- [ ] **Step 3: Commit the docs checkpoint**

```powershell
git add docs/superpowers/specs/2026-09-19-push-notifications-v1-design.md docs/superpowers/plans/2026-09-19-push-notifications-v1.md
git commit -m "docs: plan push notifications v1 implementation"
```

**Checkpoint:** Human approval of this plan and explicit selection of an execution method. Do not begin Task 2 before that approval.

---

## Phase 1 — Firestore contract and safe legacy preparation

### Task 2: Add `requestedAt`, migration tooling, and lifecycle Rules

**Repository/worktree:** Flutter app — `C:\Users\samib\Projects\gubify-push-notifications-v1`

**Files:**
- Modify: `lib/modules/community/models/community_access_request_model.dart`
- Modify: `lib/modules/community/repositories/community_repository.dart`
- Modify: `firestore.rules`
- Modify: `tests/firestore-rules/phase2a.test.mjs`
- Modify: `tests/firestore-rules/phase4a2.test.mjs`
- Create: `tools/backfill-community-join-request-requested-at.mjs`
- Create: `tests/tools/backfill-community-join-request-requested-at.test.mjs`
- Modify: `package.json`

**Interfaces:**
- Consumes: existing reusable `joinRequests/{uid}` document and `createdAt` timestamp.
- Produces: `CommunityAccessRequestModel.requestedAt`, repository writes that set/rotate/preserve it, and an idempotent Admin migration command with dry-run verification.

- [ ] **Step 1: Write RED model/repository tests**

Add tests proving `fromFirestore` reads `requestedAt`, initial create writes both timestamps with `FieldValue.serverTimestamp()`, reset-to-pending rotates only `requestedAt`, and approve/reject preserve it. The expected model surface is:

```dart
final Timestamp? requestedAt;
```

Run the focused Community repository/model tests and confirm failure because the field/write is absent.

- [ ] **Step 2: Write RED Rules tests**

In the existing Join Request fixtures, test:

```javascript
requestedAt: serverTimestamp()
```

on create/reset; assert arbitrary removal/backdating/change is `PERMISSION_DENIED`, and approve/reject/finalization preserve the exact prior timestamp. Add a migrated legacy fixture where `requestedAt === createdAt` and prove approve/reject remain allowed. Confirm RED against current Rules.

- [ ] **Step 3: Write RED migration tests**

Export pure planning/execution functions from the tool so tests can provide fake documents. Pin these outcomes:

```javascript
{ missing: 2, updated: 2, alreadyCurrent: 1, invalidCreatedAt: 0 }
```

Verify dry-run performs no writes, apply copies `createdAt` exactly, a second apply is a no-op, invalid/missing `createdAt` fails verification, and no `pushDeliveryEvents`/`pushNotifications`/Queue API is touched.

Add exact package scripts:

```json
"backfill:community-join-request-requested-at": "node tools/backfill-community-join-request-requested-at.mjs",
"test:backfill:community-join-request-requested-at": "node --test tests/tools/backfill-community-join-request-requested-at.test.mjs"
```

- [ ] **Step 4: Implement the minimum lifecycle change**

Add `requestedAt` to the model and repository payloads. Update only the Join Request Rules helpers/matches needed to require `request.time` for new cycles and equality preservation for resolution/finalization. Do not edit the `gubs/{gubId}/notifications` Rules block.

- [ ] **Step 5: Implement the Admin migration tool**

Follow the existing Admin-tool conventions. Require explicit `--dry-run` or `--apply`, default to dry-run, use paginated `collectionGroup('joinRequests')` reads and batches below Firestore limits, update only documents lacking `requestedAt` and having a valid `createdAt`, and print verification totals. Never call a push endpoint.

- [ ] **Step 6: Run focused and full Rules checks**

```powershell
npm.cmd run test:backfill:community-join-request-requested-at
npx.cmd firebase emulators:exec --only firestore "npm.cmd run test:rules:phase2a"
npx.cmd firebase emulators:exec --only firestore "npm.cmd run test:rules:phase4a2"
npx.cmd firebase emulators:exec --only firestore "npm.cmd run test:rules:all"
git diff --check
```

Expected: all green; a direct diff confirms the Private Gub notification Rules block is identical to its pre-task blob.

- [ ] **Step 7: Commit**

```powershell
git add lib/modules/community/models/community_access_request_model.dart lib/modules/community/repositories/community_repository.dart firestore.rules tests/firestore-rules/phase2a.test.mjs tests/firestore-rules/phase4a2.test.mjs tools/backfill-community-join-request-requested-at.mjs tests/tools/backfill-community-join-request-requested-at.test.mjs package.json
git commit -m "feat: version Community join request cycles"
```

**External configuration:** None. The migration is prepared and tested only; do not supply real Admin credentials and do not run `--apply` against production.

**Checkpoint:** Rules lifecycle is green, migration dry-run/apply behavior is unit-tested, and Private Gub notification Rules are byte-for-byte unchanged.

### Task 3: Add new device and global inbox Rules

**Repository/worktree:** Flutter app.

**Files:**
- Modify: `firestore.rules`
- Create: `tests/firestore-rules/push-notifications.test.mjs`
- Modify: `package.json`

**Interfaces:**
- Produces client access for `users/{uid}/devices/{deviceId}` and read-only inbox access for `users/{uid}/pushNotifications/{notificationId}`.
- Worker writes bypass client Rules through service-account authorization.

- [ ] **Step 1: Write the RED emulator matrix**

Cover exact device keys (`deviceId`, `token`, `platform`, `updatedAt`), own-user CRUD, other-user denial, deletion-state create/update denial with own delete allowed, inbox own get/list, denied client create/delete, and exact `read: false -> true` update with every other field immutable.

- [ ] **Step 2: Run focused RED**

```powershell
npx.cmd firebase emulators:exec --only firestore "node --test tests/firestore-rules/push-notifications.test.mjs"
```

Expected: access failures because the new matches do not exist.

- [ ] **Step 3: Add minimum Rules helpers/matches**

Keep schemas exact and bounded. Do not share helpers with or edit the Private Gub notification match.

- [ ] **Step 4: Run focused and full GREEN**

Run the new file, `private-notification-history-boundary.test.mjs`, and `npm.cmd run test:rules:all` through the emulator.

- [ ] **Step 5: Commit**

```powershell
git add firestore.rules tests/firestore-rules/push-notifications.test.mjs package.json
git commit -m "feat: secure global push notification data"
```

**Checkpoint:** New collections are isolated per UID and every historical Private Gub notification test remains green.

---

## Phase 2 — Worker security and persistence foundation

### Task 4: Add Worker contracts and authenticated endpoint shell

**Repository/worktree:** Worker — `C:\Users\samib\Projects\gubify-website-push-notifications-v1`

**Files:**
- Create: `worker/push/contracts.ts`
- Create: `worker/push/firebase-id-token.ts`
- Create: `worker/push/rate-limit.ts`
- Create: `worker/push/handler.ts`
- Modify: `worker/index.ts`
- Modify: `cloudflare-env.d.ts`
- Create: `tests/push-contracts.test.mjs`
- Create: `tests/push-auth.test.mjs`
- Modify: `package.json`

**Interfaces:**
- Produces `PushEventRequest`, `PushEventType`, `VerifiedFirebaseUser`, and `handlePushEventRequest(request, env, ctx): Promise<Response>`.
- `Env` gains `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`, `PUSH_FANOUT_QUEUE`, `PUSH_DELIVERY_QUEUE`, and `PUSH_EVENTS_RATE_LIMITER` types only; no values.

- [ ] **Step 1: Write strict schema RED tests**

Test all six valid discriminated request bodies and reject unknown event types, missing IDs, empty IDs, extra `recipientIds`, `title`, or `body` keys, non-POST methods, and oversized JSON.

Add the exact Worker script once so later push test files are included automatically:

```json
"test:push": "node --experimental-strip-types --import ./tests/cloudflare-test-loader.mjs --test tests/push-*.test.mjs"
```

- [ ] **Step 2: Write Firebase token verification RED tests**

Use generated test RSA keys. Verify RS256 signature, `kid`, issuer, audience, non-empty bounded subject, `exp`, `iat`, `auth_time`, clock skew, unknown-key refresh, and Cache API reuse according to the X.509 endpoint's `Cache-Control: max-age`.

- [ ] **Step 3: Implement verification and rate-limit ordering**

Use the canonical certificate endpoint:

```text
https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com
```

Apply source-IP hash limiting before certificate/Firestore work and verified-UID limiting immediately after authentication. A 429 must not persist an event plan.

- [ ] **Step 4: Wire only `/api/push/events` into the existing entrypoint**

Preserve image, Community catalog, sitemap, and vinext routing. Add no other push endpoints.

- [ ] **Step 5: Run Worker checks**

```powershell
npm.cmd run test:push
npm.cmd run lint
npm.cmd run build
```

- [ ] **Step 6: Commit**

```powershell
git add worker/push/contracts.ts worker/push/firebase-id-token.ts worker/push/rate-limit.ts worker/push/handler.ts worker/index.ts cloudflare-env.d.ts tests/push-contracts.test.mjs tests/push-auth.test.mjs package.json
git commit -m "feat: authenticate push event requests"
```

**External configuration:** Later Cloudflare configuration must provide both secrets, two Queue bindings, and a Rate Limiting binding. This task uses test doubles only.

**Checkpoint:** Invalid/unverified/rate-limited requests cannot reach event persistence; existing Worker tests/build remain green.

### Task 5: Add service-account OAuth and Firestore REST primitives

**Repository/worktree:** Worker.

**Files:**
- Create: `worker/push/service-account-auth.ts`
- Create: `worker/push/firestore-rest.ts`
- Create: `tests/push-service-account-auth.test.mjs`
- Create: `tests/push-firestore-rest.test.mjs`

**Interfaces:**
- Produces `getGoogleAccessToken(env, cache, now): Promise<string>`.
- Produces typed helpers `getDocument`, `listDocuments`, `runQuery`, `createDocument`, `patchDocument`, and `deleteDocument` with strict Firestore value decoding and test-injected `fetch`.

- [ ] **Step 1: Write RED OAuth/cache tests**

Verify JWT assertion claims/scope, PEM newline normalization, Web Crypto signing, access-token cache expiry, non-2xx sanitization, and absence of secret/token logging.

- [ ] **Step 2: Write RED Firestore helper tests**

Pin URL escaping, masks/preconditions, pagination tokens, structured queries, server timestamp transforms, missing document handling, and typed string/timestamp/map/array decoding.

- [ ] **Step 3: Implement the minimum modules**

Use `https://www.googleapis.com/auth/datastore` plus `https://www.googleapis.com/auth/firebase.messaging` scopes in the service-account assertion and keep access tokens only in memory/cache.

- [ ] **Step 4: Run focused tests and lint**

```powershell
npm.cmd run test:push -- --test-name-pattern="service account|Firestore REST"
npm.cmd run lint
```

- [ ] **Step 5: Commit**

```powershell
git add worker/push/service-account-auth.ts worker/push/firestore-rest.ts tests/push-service-account-auth.test.mjs tests/push-firestore-rest.test.mjs
git commit -m "feat: add Worker Firebase access primitives"
```

**Checkpoint:** Authentication and Firestore REST behavior are deterministic under mocks and expose no credentials.

---

## Phase 3 — Authoritative event validation

### Task 6: Validate exactly six events and persist deterministic event plans

**Repository/worktree:** Worker.

**Files:**
- Create: `worker/push/event-validator.ts`
- Create: `worker/push/event-plan-store.ts`
- Create: `tests/push-event-validator.test.mjs`
- Create: `tests/push-event-plan-store.test.mjs`
- Modify: `worker/push/handler.ts`

**Interfaces:**
- Produces `validatePushEvent(request, callerUid, firestore): Promise<ValidatedPushEvent>`.
- `ValidatedPushEvent` contains canonical `eventKey`, approved type, authoritative copy/routing IDs, and a recipient source descriptor; it never contains client-provided copy or recipients.
- Produces `ensureEventPlan(validated): Promise<EventPlan>` using create-or-read semantics.

- [ ] **Step 1: Write RED tests for each event**

Pin authoritative caller checks, active/deletion state, exact destination IDs, recipient exclusion, active Ask requirement, resolved Best Answer linkage, Join Request `requestedAt`, owner/active Platform Admin authority, and stale/forged entity rejection.

- [ ] **Step 2: Write deterministic key/plan RED tests**

Verify two submissions of the same event return the same plan, reused Join Request documents produce distinct cycle keys, mismatched existing plans fail closed, and no inbox/FCM work occurs during validation.

- [ ] **Step 3: Implement validators and plan persistence**

Encode the six key formats from the spec. Store only authoritative title/body/routing and recipient-source information. Do not enumerate proposal members in the HTTP invocation.

- [ ] **Step 4: Run focused tests plus Worker suite**

```powershell
npm.cmd run test:push -- --test-name-pattern="event validator|event plan"
npm.cmd run test:app
npm.cmd run lint
```

- [ ] **Step 5: Commit**

```powershell
git add worker/push/event-validator.ts worker/push/event-plan-store.ts worker/push/handler.ts tests/push-event-validator.test.mjs tests/push-event-plan-store.test.mjs
git commit -m "feat: validate push events authoritatively"
```

**Dependency:** Task 2's `requestedAt` contract defines Join Request event keys; no Flutter event hook is enabled yet.

**Checkpoint:** Exactly six event types persist canonical plans, and `proposal_created` performs no unbounded member query.

---

## Phase 4 — Bounded FANOUT, DELIVERY, and FCM

### Task 7: Implement paginated FANOUT with idempotent recovery

**Repository/worktree:** Worker.

**Files:**
- Create: `worker/push/fanout-consumer.ts`
- Create: `worker/push/queue-messages.ts`
- Create: `tests/push-fanout-consumer.test.mjs`
- Modify: `worker/push/handler.ts`
- Modify: `worker/index.ts`
- Modify: `cloudflare-env.d.ts`

**Interfaces:**
- Produces `FanoutMessage { kind: 'fanout'; eventKey: string; cursor?: string }`.
- Produces deterministic recipient documents at `pushDeliveryEvents/{eventKey}/recipients/{uid}`.
- Emits `DeliveryMessage { kind: 'delivery'; eventKey: string; recipientUid: string; deviceCursor?: string }`.

- [ ] **Step 1: Write FANOUT RED tests**

Cover single-recipient events, proposal member pagination beyond one page, creator exclusion, owner plus active Platform Admin discovery, deterministic cursor continuation, duplicate message redelivery, and finite Queue operations.

- [ ] **Step 2: Pin the Free-plan budget**

Use a counting fetch/Queue fake. Assert every consumer invocation stops at `MAX_EXTERNAL_SUBREQUESTS = 40`, below Cloudflare Workers Free's 50 limit, persists the cursor, and emits a continuation. Assert tests never model Cloudflare Queues as unlimited and expose operation counts for quota review.

- [ ] **Step 3: Test non-atomic recovery**

Cover: plan write then FANOUT enqueue failure; Queue acceptance then status-write failure; recipient record creation then DELIVERY enqueue failure; cursor-write ambiguity; stale FANOUT continuation. Retries must create one recipient record per UID and no inbox documents at fan-out time.

- [ ] **Step 4: Implement FANOUT and queue dispatch**

The HTTP handler only ensures the plan and requests FANOUT. The Queue handler discriminates `kind`, re-reads authoritative state, processes a bounded page, reconciles pending recipients before cursor advance, and returns retryable failures for transient errors.

- [ ] **Step 5: Run tests, lint, and build**

```powershell
npm.cmd run test:push -- --test-name-pattern="FANOUT"
npm.cmd run lint
npm.cmd run build
```

- [ ] **Step 6: Commit**

```powershell
git add worker/push/fanout-consumer.ts worker/push/queue-messages.ts worker/push/handler.ts worker/index.ts cloudflare-env.d.ts tests/push-fanout-consumer.test.mjs
git commit -m "feat: add bounded push recipient fanout"
```

**External configuration:** `PUSH_FANOUT_QUEUE` must later have a consumer route. Queue retention, retries, and daily Free quota must be reviewed in Cloudflare before deployment; no configuration is applied now.

**Checkpoint:** Large recipient sets require multiple bounded invocations, every invocation uses ≤40 external subrequests, and retries do not duplicate recipients.

### Task 8: Implement DELIVERY, inbox idempotency, and FCM HTTP v1

**Repository/worktree:** Worker.

**Files:**
- Create: `worker/push/delivery-consumer.ts`
- Create: `worker/push/fcm-client.ts`
- Create: `tests/push-delivery-consumer.test.mjs`
- Create: `tests/push-fcm-client.test.mjs`
- Modify: `worker/index.ts`

**Interfaces:**
- Consumes `DeliveryMessage` from Task 7.
- Creates deterministic `users/{uid}/pushNotifications/{notificationId}` and pages `users/{uid}/devices` at maximum 20 devices per invocation.
- Produces FCM `notification + data`, Android tag/collapse key/channel, and APNs collapse ID from the event key.

- [ ] **Step 1: Write DELIVERY RED tests**

Verify deterministic create-or-read inbox behavior, preservation of existing `read: true`, device pagination/continuation, ≤20 devices, ≤40 external subrequests, duplicate delivery messages, and completion only after all pages finish.

- [ ] **Step 2: Write FCM RED tests**

Assert Worker-generated title/body, bounded string-only routing data, notification ID/event key, Android channel/tag/collapse key, APNs collapse ID, permanent invalid-token deletion, transient error retention/retry, and sanitized logs.

- [ ] **Step 3: Implement DELIVERY and FCM**

Create/read inbox before sends, preserve read state, page devices, remove only permanently invalid device documents, persist cursor, enqueue deterministic continuation, and mark recipient completed at the terminal page.

- [ ] **Step 4: Run full Worker verification**

```powershell
npm.cmd run test:push
npm.cmd run test:app
npm.cmd run lint
npm.cmd run build
```

- [ ] **Step 5: Commit**

```powershell
git add worker/push/delivery-consumer.ts worker/push/fcm-client.ts worker/index.ts tests/push-delivery-consumer.test.mjs tests/push-fcm-client.test.mjs
git commit -m "feat: deliver idempotent global push notifications"
```

**External configuration:** `PUSH_DELIVERY_QUEUE` later needs its consumer and retry policy. FCM HTTP v1 access uses the already named service-account secrets; no secret values enter Git.

**Checkpoint:** Inbox is exactly-once per recipient/event, FCM is explicitly best-effort, invalid tokens are cleaned safely, and Worker full checks pass.

---

## Phase 5 — Flutter event producer hooks

### Task 9: Add the authenticated best-effort Worker client

**Repository/worktree:** Flutter app.

**Files:**
- Create: `lib/modules/push_notifications/models/push_event.dart`
- Create: `lib/modules/push_notifications/services/push_event_client.dart`
- Create: `test/modules/push_notifications/push_event_client_test.dart`

**Interfaces:**
- Produces six typed constructors and `Future<void> submit(PushEvent event)`.
- Gets a fresh Firebase ID token, sends only `type` plus authoritative IDs to `const String.fromEnvironment('GUBIFY_PUSH_EVENTS_URL')`, and swallows/logs coarse delivery failures without exposing tokens.

- [ ] **Step 1: Write RED contract tests**

Assert exact JSON for all six events, bearer header, no recipient/title/body fields, non-2xx/timeout best-effort behavior, missing URL no-op in local/test builds, and no token in logs.

- [ ] **Step 2: Implement model/client with injectable auth and HTTP seams**

Use sealed/typed event factories rather than arbitrary maps. Keep endpoint configuration outside source secrets.

- [ ] **Step 3: Run focused tests and analyze**

```powershell
flutter test --no-pub test/modules/push_notifications/push_event_client_test.dart
flutter analyze
```

- [ ] **Step 4: Commit**

```powershell
git add lib/modules/push_notifications/models/push_event.dart lib/modules/push_notifications/services/push_event_client.dart test/modules/push_notifications/push_event_client_test.dart
git commit -m "feat: add authenticated push event client"
```

**Dependency:** The request contract must match Tasks 4 and 6. No live endpoint is configured.

**Checkpoint:** Client can only express the six approved payloads and cannot make a domain operation fail.

### Task 10: Attach the six post-success domain hooks

**Repository/worktree:** Flutter app.

**Files:**
- Modify: `lib/modules/tasks/services/task_service.dart`
- Modify: `lib/modules/proposals/services/proposal_service.dart`
- Modify: `lib/modules/community/services/community_ask_answer_service.dart`
- Modify: `lib/modules/community/services/community_service.dart`
- Create: `test/modules/tasks/task_service_test.dart`
- Create: `test/modules/proposals/proposal_service_test.dart`
- Modify: `test/modules/community/community_ask_answer_service_test.dart`
- Create: `test/modules/community/community_push_event_hooks_test.dart`

**Interfaces:**
- Consumes `PushEventClient.submit` after authoritative repository success.
- No repository transaction or existing Private Gub notification call changes.

- [ ] **Step 1: Write RED service-hook tests**

For each event, assert zero calls when the domain write fails and exactly one typed call after success. Assert Answer emits only for active Ask and Best Answer only after successful resolution. Join Request client payloads contain only `communityId` and requester UID; the Worker, not Flutter, reads authoritative `requestedAt` and derives the cycle event key.

- [ ] **Step 2: Add narrow dependency injection**

Add optional submit callbacks/factories to service test constructors while production defaults to `PushEventClient.instance.submit`. Do not make repositories depend on HTTP.

- [ ] **Step 3: Implement post-success hooks**

Task assignment skips empty/self assignees. Proposal push remains separate from the existing `NotificationService.instance.send` call, which stays unchanged. Every push submission is unawaited or guarded so its failure cannot alter domain success, while tests can await the injected seam deterministically.

- [ ] **Step 4: Run focused regressions**

```powershell
flutter test --no-pub test/modules/tasks test/modules/proposals test/modules/community/community_ask_answer_service_test.dart test/modules/community/community_push_event_hooks_test.dart
flutter analyze
```

- [ ] **Step 5: Commit**

```powershell
git add lib/modules/tasks/services/task_service.dart lib/modules/proposals/services/proposal_service.dart lib/modules/community/services/community_ask_answer_service.dart lib/modules/community/services/community_service.dart test/modules/tasks test/modules/proposals test/modules/community/community_ask_answer_service_test.dart test/modules/community/community_push_event_hooks_test.dart
git commit -m "feat: emit approved push notification events"
```

**Checkpoint:** Six and only six hooks fire after successful writes; existing Private Gub notifications and all domain outcomes remain unchanged.

---

## Phase 6 — Flutter inbox and unread navbar state

### Task 11: Add global inbox model/repository/service and UI

**Repository/worktree:** Flutter app.

**Files:**
- Create: `lib/modules/push_notifications/models/global_push_notification.dart`
- Create: `lib/modules/push_notifications/repositories/global_push_notification_repository.dart`
- Create: `lib/modules/push_notifications/services/global_push_notification_service.dart`
- Create: `lib/modules/push_notifications/widgets/global_push_notification_card.dart`
- Modify: `lib/modules/notifications/screens/global_notifications_screen.dart`
- Create: `test/modules/push_notifications/global_push_notification_repository_test.dart`
- Create: `test/modules/push_notifications/global_push_notification_card_test.dart`
- Modify: `test/modules/notifications/global_notifications_screen_test.dart`

**Interfaces:**
- `watchRecent(uid)` queries `users/{uid}/pushNotifications`, `orderBy('createdAt', descending: true)`, `limit(50)`.
- `watchHasUnread(uid)` uses only `where('read', isEqualTo: false).limit(1)`.
- `markRead(uid, notificationId)` updates only `{read: true}`.

- [ ] **Step 1: Write repository/service RED tests**

Use Firestore query recording seams to assert exact paths, order, limits, existence-only unread behavior, decoding, and exact mark-read update.

- [ ] **Step 2: Write screen/card RED tests**

Cover loading, empty, error, newest-first data, unread styling, read tap callback, and absence of the Private Gub `NotificationsScreen`/models.

- [ ] **Step 3: Implement bounded inbox UI**

Replace only the global placeholder. Preserve the Private Gub screen untouched.

- [ ] **Step 4: Run focused tests**

```powershell
flutter test --no-pub test/modules/push_notifications test/modules/notifications/global_notifications_screen_test.dart
flutter analyze
```

- [ ] **Step 5: Commit**

```powershell
git add lib/modules/push_notifications lib/modules/notifications/screens/global_notifications_screen.dart test/modules/push_notifications test/modules/notifications/global_notifications_screen_test.dart
git commit -m "feat: add global notification inbox"
```

**Checkpoint:** Global inbox is bounded, per-user, and entirely separate from Private Gub notifications.

### Task 12: Add the red unread dot without a count

**Repository/worktree:** Flutter app.

**Files:**
- Modify: `lib/widgets/gubify_bottom_navigation_bar.dart`
- Modify: `lib/screens/main_navigation_shell.dart`
- Modify: `test/screens/main_navigation_shell_test.dart`
- Create: `test/widgets/gubify_bottom_navigation_bar_notification_test.dart`

**Interfaces:**
- Adds `bool hasUnreadNotifications` to the bar.
- The shell subscribes once to the service's boolean stream for the authenticated UID and passes only the boolean.

- [ ] **Step 1: Write RED widget tests**

Assert no dot for false, one red dot with no text for true, exactly four destinations, unchanged avatar/semantics, no count/count query, and no overflow at 320×426.

- [ ] **Step 2: Implement the minimum bar/shell change**

Overlay a keyed dot on the bell icon. Do not recreate the inbox stream on tab taps or add listeners to the empty/non-notification tabs.

- [ ] **Step 3: Run navigation regressions**

```powershell
flutter test --no-pub test/widgets/gubify_bottom_navigation_bar_notification_test.dart test/screens/main_navigation_shell_test.dart
flutter analyze
```

- [ ] **Step 4: Commit**

```powershell
git add lib/widgets/gubify_bottom_navigation_bar.dart lib/screens/main_navigation_shell.dart test/widgets/gubify_bottom_navigation_bar_notification_test.dart test/screens/main_navigation_shell_test.dart
git commit -m "feat: show unread notification dot"
```

**Checkpoint:** One existence stream controls a dot without a number; root tab state preservation remains green.

---

## Phase 7 — FCM device lifecycle and routing

### Task 13: Register devices, refresh tokens, and detach before sign-out

**Repository/worktree:** Flutter app.

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Create: `lib/modules/push_notifications/repositories/push_device_repository.dart`
- Create: `lib/modules/push_notifications/services/push_device_service.dart`
- Modify: `lib/services/auth_service.dart`
- Modify: `lib/pages/startup_screen.dart`
- Create: `test/modules/push_notifications/push_device_service_test.dart`
- Modify: `test/services/auth_service_google_link_test.dart`
- Modify: `test/modules/profile/account_session_section_test.dart`
- Modify: `test/modules/profile/account_deletion_service_test.dart`

**Interfaces:**
- Adds `firebase_messaging` and `flutter_local_notifications`; `pubspec.lock` records the compatible versions resolved by the current Flutter SDK.
- `PushDeviceService.attach(uid)`, `refreshToken(uid, token)`, and `detachBeforeSignOut(uid)` operate on one stable installation UUID stored in `SharedPreferences`.
- `AuthService` receives an optional `Future<void> Function(String uid) beforeSignOut` seam whose production default calls device detach.

- [ ] **Step 1: Write RED lifecycle tests**

Cover permission timing after authenticated navigation, stable installation ID, token create/update, refresh, same-UID Anonymous linking, UID switch ordering, delete-before-Firebase-sign-out, transient delete failure, logout failure behavior, and no token logging. Detach always attempts both the Firestore device-document delete and `FirebaseMessaging.deleteToken()`: if the Firestore delete fails but token invalidation succeeds, sign-out may proceed and the Worker later removes the stale invalid record; if token invalidation fails, normal logout/account switch remains authenticated and returns a retryable failure.

- [ ] **Step 2: Add dependencies and repository/service**

Run `flutter pub add firebase_messaging flutter_local_notifications`. Request permission only when the authenticated app is ready. Observe auth/token changes without adding a Firestore listener. Store exact device schema with server timestamp.

- [ ] **Step 3: Integrate every actual sign-out path**

Call detach before `_authVerificationGateway.signOut()` in normal logout, auth switch, and incomplete-profile exits. Preserve Google sign-out behavior. Account deletion uses the existing deletion workflow to remove device documents before the Auth user is deleted; add a focused cleanup assertion rather than a second deletion system.

- [ ] **Step 4: Run focused auth/device tests**

```powershell
flutter test --no-pub test/modules/push_notifications/push_device_service_test.dart test/services/auth_service_google_link_test.dart test/modules/profile/account_session_section_test.dart test/modules/profile/account_deletion_service_test.dart
flutter analyze
```

- [ ] **Step 5: Commit**

```powershell
git add pubspec.yaml pubspec.lock lib/modules/push_notifications/repositories/push_device_repository.dart lib/modules/push_notifications/services/push_device_service.dart lib/services/auth_service.dart lib/pages/startup_screen.dart test/modules/push_notifications/push_device_service_test.dart test/services/auth_service_google_link_test.dart test/modules/profile/account_session_section_test.dart test/modules/profile/account_deletion_service_test.dart
git commit -m "feat: manage FCM device registrations"
```

**External configuration:** Firebase Console later enables/configures Cloud Messaging and platform credentials. No real configuration is performed in this phase.

**Checkpoint:** The old UID loses its device record before auth permission is lost; linking with unchanged UID keeps the same installation.

### Task 14: Add Android channel and system-push coordinator

**Repository/worktree:** Flutter app.

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Create: `lib/modules/push_notifications/services/push_notification_coordinator.dart`
- Create: `lib/modules/push_notifications/navigation/global_push_notification_router.dart`
- Modify: `lib/main.dart`
- Modify: `lib/modules/notifications/screens/global_notifications_screen.dart`
- Create: `test/modules/push_notifications/push_notification_coordinator_test.dart`
- Create: `test/modules/push_notifications/global_push_notification_router_test.dart`
- Modify: `test/modules/notifications/global_notifications_screen_test.dart`
- Modify: `test/pages/startup_screen_test.dart`

**Interfaces:**
- Top-level `@pragma('vm:entry-point') firebaseMessagingBackgroundHandler(RemoteMessage message)` is registered before `runApp`.
- `PushNotificationCoordinator.open(notificationId, data)` deduplicates, marks read, waits for root navigation readiness, then delegates to `GlobalPushNotificationRouter`.
- Router supports only the six approved destinations and performs authoritative availability/access reads before navigation.

- [ ] **Step 1: Write RED coordinator tests**

Cover `getInitialMessage`, `onMessageOpenedApp`, duplicate initial/resumed delivery, one queued open before navigation readiness, mark-read before route, bounded mark-read retry, foreground no-local-notification behavior, and malformed data rejection.

- [ ] **Step 2: Write RED router tests**

Cover task, proposal, Answer/Best Answer Ask details, pending Join Request management screen, approved Community home, rejected/public fallback, deleted/unavailable destinations, and denied access without unsafe navigation.

- [ ] **Step 3: Implement channel and manifest metadata**

Create one high-importance Android channel with `showBadge: true`, add `POST_NOTIFICATIONS`, and set the FCM default channel metadata. Do not implement numeric badges or a foreground duplicate notification.

- [ ] **Step 4: Integrate root navigator readiness**

Reuse `GubifyApp`'s existing navigator key. Coordinate invite-link readiness and push readiness without introducing a second navigator. Inbox taps call the same `open` operation.

- [ ] **Step 5: Run focused routing/startup tests**

```powershell
flutter test --no-pub test/modules/push_notifications/push_notification_coordinator_test.dart test/modules/push_notifications/global_push_notification_router_test.dart test/modules/notifications/global_notifications_screen_test.dart test/pages/startup_screen_test.dart
flutter analyze
```

- [ ] **Step 6: Commit**

```powershell
git add android/app/src/main/AndroidManifest.xml lib/main.dart lib/modules/push_notifications/services/push_notification_coordinator.dart lib/modules/push_notifications/navigation/global_push_notification_router.dart lib/modules/notifications/screens/global_notifications_screen.dart test/modules/push_notifications test/modules/notifications/global_notifications_screen_test.dart test/pages/startup_screen_test.dart
git commit -m "feat: route opened push notifications"
```

**Checkpoint:** System and inbox opens share one read-before-route coordinator, and foreground delivery creates no duplicate system notification.

---

## Phase 8 — Integration verification and operational handoff

### Task 15: Cross-repository contract and regression verification

**Repositories/worktrees:** Both dedicated worktrees.

**Files:**
- Create: `test/modules/push_notifications/push_event_contract_test.dart`
- Create: `tests/push-contract-fixtures.test.mjs` in the Worker repository

**Interfaces:**
- Both sides consume a checked-in, non-secret fixture set containing the six request JSON shapes and routing data shapes. Do not introduce a shared runtime package.

- [ ] **Step 1: Add matching contract fixtures/tests**

Assert Flutter serialization is accepted by the Worker parser and that Worker routing data decodes in Flutter. Include rejection fixtures for recipient/title/body injection and unknown seventh event.

- [ ] **Step 2: Run complete Flutter/Rules verification**

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --no-pub
npx.cmd firebase emulators:exec --only firestore "npm.cmd run test:rules:all"
npm.cmd run test:backfill:community-join-request-requested-at
git diff --check
```

- [ ] **Step 3: Run complete Worker verification**

```powershell
npm.cmd test
npm.cmd run test:push
npm.cmd run lint
npm.cmd run build
git diff --check
```

- [ ] **Step 4: Audit protected scope**

Compare both feature branches to their bases. Confirm no diff in Private Gub notification files/Rules, only six event hooks, no credentials, no production URL/secret values, no deployment artifacts, and no changes in original checkouts.

- [ ] **Step 5: Commit final test-only integration changes**

Flutter:

```powershell
git add test/modules/push_notifications/push_event_contract_test.dart
git commit -m "test: verify Flutter push notification contracts"
```

Worker:

```powershell
git add tests/push-contract-fixtures.test.mjs package.json
git commit -m "test: verify Worker push notification contracts"
```

**Checkpoint:** Every full suite is green with observed exit code 0, both worktrees are clean, original checkouts are untouched, and no deploy/merge has occurred.

### Task 16: Prepare but do not execute external rollout instructions

**Repositories/worktrees:** Both, documentation only.

**Files:**
- Create: `docs/push-notifications-v1-rollout.md` in the Flutter repository.
- Create: `PUSH_NOTIFICATIONS_SETUP.md` in the Worker repository.

**Interfaces:**
- Produces operator checklists; performs no external mutation.

- [ ] **Step 1: Document Firebase operator actions**

List: enable/verify the Firebase Cloud Messaging API, verify the existing Android Firebase app registration, configure an APNs authentication key for the existing iOS Firebase app, run the legacy migration dry-run, run Admin apply manually, verify zero missing/invalid `requestedAt`, verify zero push artifacts, then deploy Rules only after approval. Never include credentials.

- [ ] **Step 2: Document Cloudflare operator actions**

List exact secret names `FIREBASE_CLIENT_EMAIL` and `FIREBASE_PRIVATE_KEY`; non-secret `FIREBASE_PROJECT_ID`; bindings `PUSH_FANOUT_QUEUE`, `PUSH_DELIVERY_QUEUE`, `PUSH_EVENTS_RATE_LIMITER`; queue consumers/retries; Worker route; 40-of-50 subrequest budget; finite Queues Free daily quota monitoring; and required pre-deploy test commands.

- [ ] **Step 3: Document release ordering and rollback**

Order: migration → verification → Rules → Worker queues/bindings/secrets → Worker → Flutter. Rollback disables Flutter event URL/Worker route first, preserves inbox data, and never rolls back `requestedAt` or re-enables legacy documents.

- [ ] **Step 4: Commit documentation separately**

Flutter:

```powershell
git add docs/push-notifications-v1-rollout.md
git commit -m "docs: add push notification rollout checklist"
```

Worker:

```powershell
git add PUSH_NOTIFICATIONS_SETUP.md
git commit -m "docs: add push notification Worker setup"
```

**Final stop:** Report files, commits, full verification results, final schema, endpoint, exact secret/binding names, manual Firebase/Cloudflare actions, trade-offs, and confirmation that Private Gub notifications are unchanged. Do not configure, deploy, merge, or execute the production migration.

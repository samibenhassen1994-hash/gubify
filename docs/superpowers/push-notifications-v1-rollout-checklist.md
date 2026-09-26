# Push notifications V1 rollout checklist

No production operation has been performed by this branch.

Before rollout, perform in order:

1. Run the server-side legacy Join Request migration (`requestedAt = createdAt`) and verify it. It must not emit pushes.
2. Deploy the reviewed Firestore Rules.
3. Configure Cloudflare Queue and Rate Limiter bindings and the bounded processing budget.
4. Add Cloudflare secrets through the dashboard/CLI only; never commit them.
5. Deploy the Worker and validate its authenticated endpoint with non-production fixtures.
6. Configure Firebase Cloud Messaging credentials and platform settings.
7. Build and release Flutter with the compile-time `GUBIFY_PUSH_EVENTS_URL`.

Rollback is Worker-side: stop/disable Worker processing. `GUBIFY_PUSH_EVENTS_URL` is compile-time; changing or removing it for installed clients requires a new app build and release.

Private Gub notifications at `gubs/{gubId}/notifications` and their Rules remain outside this rollout.

# Community Android App Links Design

## Objective

Allow an Android user who selects **Entra nella community** on a public
`https://gubify.com/community/{slug}` page to open that Community in Gubify.
The existing Private Gub invite flow at `https://gubify.com/join/{code}` must
remain behaviorally unchanged.

The destination must survive cold start, sign-in, email verification, and
profile completion. Opening a Community link must never join a user directly
or bypass existing Community approval, restriction, moderation, or membership
checks.

## Scope

This work spans two repositories and two isolated branches:

- Flutter app: `feature/community-app-links`, based on `origin/master` at
  `b00b14e675e9b36641159b0e95521aa89ae0ba3a`.
- Website: `feature/community-app-links`, based on `origin/main` at
  `0f28c1ce7ca7021fdc53872e556aea669cc535a4`.

No Firestore Rules, database data, Worker push processing, iOS integration,
Cloudflare deployment, merge, or Android release is in scope.

## Canonical Links

- Private Gub invite: `https://gubify.com/join/{code}`.
- Public Community: `https://gubify.com/community/{slug}`.
- Android package: `com.gubify.app`.
- Google Play fallback:
  `https://play.google.com/store/apps/details?id=com.gubify.app`.

Community slugs use the existing canonical format:
`[a-z0-9]+(?:-[a-z0-9]+)*`, with the existing maximum length of 60.
Scheme, host, port, user-info, path length, and slug must all be validated.
Query strings and fragments do not change the destination.

## Flutter Architecture

### Typed destination parser

The existing App Links infrastructure will parse both link families into a
sealed/typed destination rather than interpreting every URI as a Private Gub
invite. The Private Gub parser and visible invite-code normalization remain
unchanged.

The Community parser accepts only canonical HTTPS links on `gubify.com` with
exactly two path segments, where the first is `community` and the second is a
valid canonical slug. Lookalike hosts, HTTP, credentials, ports, extra path
segments, encoded separators, uppercase slugs, and malformed slugs are ignored.

### One coordinator for all app-link lifecycle states

The coordinator continues to subscribe once to `AppLinks.uriLinkStream`. In
`app_links` 7.x this stream supplies the initial link as well as links received
while the process is alive, so one subscription covers cold start, background,
and foreground delivery without introducing a second initial-link read.

The coordinator stores one pending typed destination until
`markNavigationReady()` is called. Startup calls that method only after the
authenticated shell exists, so the destination naturally survives:

- unauthenticated sign-in;
- anonymous continuation;
- required email verification;
- first-profile/name completion;
- normal authenticated startup.

While a destination is opening, an identical URI does not stack another
route. A distinct later destination is retained and drained after the current
navigation completes. Coordinator disposal cancels the stream and pending
work.

### Community slug resolution

A focused repository/service method reads the single public projection
`communityPublic/{slug}`. It returns a `communityId` only when:

- the document exists;
- its `slug` equals the requested slug;
- `communityId` is a non-empty string.

The existing Rules already allow public single-document `get` on this
collection. No query, index, or Rules change is required.

When resolution succeeds, the root navigator pushes
`CommunityPublicDetailsScreen(communityId: communityId)`. The existing screen
and services remain authoritative for membership and access:

- member or owner: open Community;
- non-member, open access: offer join;
- approval access: offer/request approval;
- joining restriction: do not offer access;
- deleting or missing Community: show the existing unavailable state.

Resolution failure shows a user-safe message and does not navigate to an
arbitrary Community. No membership document or join request is written by the
link handler.

## Android Configuration

The existing verified HTTPS intent filter for `gubify.com/join/` remains
unchanged. A sibling verified filter (or additional data entry with equivalent
matching semantics) handles `gubify.com/community/` without broadening the app
to unrelated website paths.

Flutter framework deep linking remains disabled because the app intentionally
uses the `app_links` plugin and its coordinator.

The website will publish `public/.well-known/assetlinks.json` containing only
the Android relation needed to open links:

- namespace: `android_app`;
- package: `com.gubify.app`;
- relation: `delegate_permission/common.handle_all_urls`;
- Google Play App Signing SHA-256:
  `13:CA:6C:DB:A5:14:F5:E5:C5:B4:D9:9D:95:C2:16:68:83:F0:BF:C8:F2:14:73:22:CF:21:52:8A:55:A3:59:47`.

The file must be served without redirects at
`https://gubify.com/.well-known/assetlinks.json`, with HTTP 200 and a JSON
content type. Local tests verify the artifact and route. The public HTTP 200
check is necessarily a post-deploy publishing step and will not be claimed
during this no-deploy implementation phase.

## Website CTA

The Community page remains the canonical SEO page and performs no redirect on
load. The user must explicitly select **Entra nella community**.

The canonical Community HTTPS URL is the source destination. On Android, the
click handler builds an Android intent for the same HTTPS host/path and package,
with the Google Play listing as `browser_fallback_url`. This gives deterministic
Play fallback when the package is absent while preserving the verified HTTPS
App Link destination when it is installed.

Desktop and non-Android browsers retain the public page and its SEO content;
no iOS URL or iOS behavior is added. The CTA must not enroll a user from the
website.

URL construction and Android intent construction live in a small pure module
so encoding and fallback behavior can be tested without browser timing.

## Error and Security Behavior

- Invalid links are ignored and never converted into partial destinations.
- A missing or malformed public projection produces an unavailable message.
- A projection cannot choose a different slug than the requested document.
- Community membership and access remain enforced by the existing app service
  and Firestore Rules.
- Duplicate app-link events do not push duplicate Community routes.
- Technical errors are handled as best-effort link failures and do not break
  startup or authentication.
- No keystore, signing password, service-account data, or other credential is
  added to either repository.

## Test Strategy

### Flutter

- Parser tests for valid Community URLs, query/fragment tolerance, invalid
  schemes/hosts/ports/user-info/slugs/extra segments, and existing invites.
- Coordinator tests for initial link before navigation readiness, foreground
  and background-style events, pending destination through delayed readiness,
  duplicate Community suppression, distinct queued destinations, and disposal.
- Repository/service tests for successful slug resolution and missing,
  malformed, or mismatched public projections.
- Widget/navigation tests proving the resolved ID opens
  `CommunityPublicDetailsScreen`, while existing `/join/{code}` still opens
  `JoinGubScreen`.
- Existing Community public-details tests continue to prove member, open,
  approval, restriction, and unavailable behavior.
- Full `flutter test` and `flutter analyze`.

### Website

- Pure URL tests for canonical Community links, Android intents, package, and
  encoded Play fallback.
- CTA tests for explicit-click-only behavior, Android launch, non-Android
  no-redirect behavior, and no automatic redirect during page render.
- Rendered-page tests confirming the CTA is enabled while metadata, canonical
  URL, Community content, and SEO remain intact.
- Asset Links tests validating JSON syntax, exact package, exact relation, and
  exact Play fingerprint.
- Full relevant website tests, lint, and production build.

## Delivery

Each repository receives focused commits and a normal push of its dedicated
feature branch. There is no merge or deployment. The handoff lists the manual
production sequence:

1. review and merge both branches;
2. deploy the website containing `assetlinks.json` and CTA changes;
3. verify public HTTP 200, no redirect, JSON content type, package, and
   fingerprint;
4. build/sign an Android release containing the manifest change;
5. upload that release to Google Play;
6. verify Android domain association and test installed/not-installed flows on
   a physical Android device.

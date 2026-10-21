# Initial 100 Communities Design

## Goal

Create a reviewed catalog of exactly 100 useful English-language Communities and add a secure, resumable administrative import path without changing the one-Community ownership limit for ordinary users.

## Verified administrative identity

- Firebase project: `gubify-a3e2c`
- UID: `9dTaHzIR3FcEjK5KDAkCnImYbV93`
- Authentication email: `gubifyapp@gmail.com`
- Auth account: enabled
- Firestore profile: present
- `platformAdmins/{uid}.active`: `true`

The importer must re-verify all of these conditions at runtime. It must stop if any condition changes.

## Catalog

The repository will contain a JSON catalog with exactly 100 records:

- 20 broad global subjects;
- 20 focused niches with active international audiences;
- 60 additional popular, evergreen, or emerging subjects.

Every record contains `name`, `slug`, `type`, `language`, `description`, `accessMode`, `topic`, `popularityEvidence`, and `sourceUrls`. Names and descriptions are original, descriptions are at most 280 characters, and every `type` and `language` is accepted by the current model and Rules. Evidence is qualitative and explicitly distinguishes established popularity, relative trend growth, and documented emerging potential. Brand, game, team, artist, and celebrity communities are described as independent fan discussion spaces without implying official affiliation.

## Ownership architecture

`communityOwnership/{uid}` remains the single ownership marker for ordinary accounts and continues to enforce one owned Community.

Platform Admin ownership is recorded separately at:

`platformAdminCommunityOwnership/{uid}/communities/{communityId}`

Each document contains only `ownerId`, `communityId`, and `createdAt`. Creation is allowed only when the authenticated user is the matching active Platform Admin and the same atomic operation creates the canonical Community root, owner membership, user copy, public/name/slug registries, restrictions, and progress projection.

The repository selects the normal or Platform Admin ownership path from the verified role. An active Platform Admin can create and list multiple owned Communities. Revocation immediately blocks further multi-Community creation. Previously owned Communities remain manageable by their canonical `ownerId`; ownership does not silently transfer or disappear when the admin registry is revoked. Deletion removes only the matching administrative ownership record.

## Compatibility

Existing ordinary ownership records and Community documents are unchanged. Membership, XP, `communityUserProgress.communityIds`, public projections, join behavior, account deletion, and existing Community deletion retain their current schemas and behavior. Platform Admin ownership documents are additive and cannot grant moderation, membership, or access to unrelated Communities.

Screens and services that currently infer a single owned Community must instead derive owned Community lists from canonical membership copies/root queries for Platform Admins while preserving the existing ordinary-user experience.

## Importer

The administrative Node script uses Firebase Admin SDK and explicit project `gubify-a3e2c`. Credentials are accepted only through local Application Default Credentials and are never stored or logged.

Default execution is dry-run. Applying requires both `--apply` and `--project=gubify-a3e2c`. The script:

1. validates the catalog and the verified administrator;
2. checks every canonical name key and slug;
3. refuses to overwrite any Community or registry owned by another UID;
4. treats an already complete matching Community as skipped;
5. repairs no partial state automatically in dry-run and reports it as an error;
6. uses one Firestore transaction per Community so no partial Community is committed;
7. writes root, name registry, slug registry, public projection, initial restrictions, owner member, owner user copy, progress projection, and Platform Admin ownership record;
8. uses server timestamps and `memberCount: 1` without fabricated activity;
9. reports created, skipped, conflicts, and failures.

The production import is explicitly out of scope until separate human approval.

## Security and Rules

Rules must prove:

- ordinary users still cannot own a second Community;
- active Platform Admins can create a second and subsequent Community only for themselves;
- anonymous, inactive, deleted-profile, or revoked admins cannot use the admin path;
- clients cannot forge administrative ownership records for another UID or Community;
- the admin create batch cannot omit or forge canonical projections;
- deletion removes the matching ownership record and cannot delete another admin's record;
- revocation blocks new creation but does not prevent the canonical owner from managing or deleting already-owned Communities.

No moderation, Child Safety, Private Gub notification, or unrelated permission is broadened.

## Validation

- Catalog validation and simulated 100-record import tests.
- Firestore Emulator RED/GREEN coverage for normal and Platform Admin ownership.
- Flutter unit/widget tests for creation limits, owned-Community listing, management, and deletion.
- Complete Firestore Rules suite.
- Complete Flutter test suite and `flutter analyze`.
- Importer dry-run against production in read-only mode only.
- Verification that `communityPublic` records expose the fields consumed by Explorer and the existing website/sitemap contract.

## Non-goals

- No production seed.
- No Firebase deploy.
- No website or Cloudflare change.
- No moderation redesign or `hiddenFromDiscovery` synchronization.
- No merge to `master` and no Google Play release.

# Community Images Phase 1 Design

## Scope

Add one owner-managed square image to each Community. The client selects only
from the gallery, rejects original files larger than 20 MiB, normalizes the
image to an oriented 512 x 512 JPEG at quality 82, obtains a signed upload from
the existing Worker, uploads directly to Cloudinary, then atomically publishes
the resulting metadata to the Community root and public projection.

No image removal, deletion cleanup, Cloudinary SDK, secret in the client,
Cloud Function, index change, commit, push, or merge belongs to this phase.

## Data contract

`communities/{communityId}` gains optional legacy-compatible fields:

- `imageUrl`: Cloudinary HTTPS delivery URL.
- `imagePublicId`: exactly `community_<communityId>`.
- `imageVersion`: positive integer returned by Cloudinary.
- `imageUpdatedAt`: server timestamp.

`communityPublic/{slug}` gains:

- `imageUrl`: identical to the root value.
- `imageVersion`: identical to the root value.
- `updatedAt`: server timestamp for the paired update.

The Community model treats all image fields as optional so existing documents
continue to render with the current icon fallback.

## Upload pipeline

1. The owner chooses one image with `image_picker` using the gallery source.
2. `XFile.length()` is checked before reading bytes. Files above 20 MiB fail
   immediately with `Choose an image smaller than 20 MiB.`
3. Image processing runs outside the UI isolate with `compute`: decode, bake
   EXIF orientation, centered square crop, resize to 512 x 512, JPEG quality 82.
4. The service obtains a fresh Firebase ID token and calls
   `POST https://gubify-media-api.samibenhassen1994.workers.dev/sign-upload`
   with `Authorization: Bearer <token>` and JSON `{ "communityId": "..." }`.
5. The repository validates the signing response, including Cloudinary cloud
   `s3yauoza`, HTTPS upload endpoint, and exact public ID
   `community_<communityId>`.
6. Flutter posts the processed bytes directly to Cloudinary using the exact
   signed fields returned by the Worker.
7. The Cloudinary response is accepted only when `public_id` is exact,
   `version` is a positive integer, and `secure_url` matches the expected
   account and deterministic asset.
8. A Firestore transaction reads the authoritative Community root (including
   slug), then updates root and `communityPublic/{slug}` atomically.

Cancellation is a normal no-op. Expected validation errors are returned outside
Firestore transaction callbacks; Firebase exceptions may propagate through the
existing friendly service error mapping. Upload secrets and signed parameters
are never logged.

## Firestore Rules

Only the current active Community owner may update image metadata. A valid root
image update changes only the four root image fields, requires
`imagePublicId == "community_" + communityId`, a positive integer version,
`imageUpdatedAt == request.time`, and a strict URL of the form:

`https://res.cloudinary.com/s3yauoza/image/upload/v<positive-version>/community_<communityId>.<extension>`

The rule constrains image-enabled Community IDs to the alphanumeric Firestore
auto-ID shape before interpolating the ID into a regex. This prevents regex
injection while preserving all normally-created Communities.

The public projection update is allowed only in the same atomic operation. It
changes only `imageUrl`, `imageVersion`, and `updatedAt`; requires exact equality
with the post-write root via `getAfter`; and requires `updatedAt == request.time`.
Conversely, the root image update requires the matching post-write public
projection.

Firestore Rules can reliably verify the URL account, resource type, upload
path, positive Cloudinary version segment, deterministic asset name, extension,
root/public equality, and integer positivity. Rules do not provide a safe
integer-to-string conversion or numeric parsing facility, so they cannot
reliably prove that integer `imageVersion` equals the decimal version embedded
in `imageUrl`. The client validates both values from the same Cloudinary
response, persists them atomically, and Rules ensure root/public consistency;
the URL still must contain a valid positive version segment.

## UI

Community Settings shows an owner-only image card before destructive actions.
It displays the current image or existing Community fallback, an `Add image` or
`Change image` action, progress state, double-tap protection, and friendly
feedback. A successful response updates local screen state immediately.

A reusable presentation widget renders the image with a safe icon fallback on
missing URL or network failure. It is used in Community Settings, Explorer
cards, public details, and the Community Home header without changing existing
navigation or surrounding content.

## Testing

- Model tests cover legacy documents and image metadata parsing/copying.
- Processor tests prove JPEG output is 512 x 512 and oversized input is rejected
  before processing through the service seam.
- HTTP repository tests cover exact public ID, signing response validation,
  upload response validation, and friendly failures.
- Widget tests cover owner-only Add/Change/loading and fallback/image rendering.
- Focused Rules tests cover owner success, member/outsider denial, wrong account,
  wrong deterministic ID in both field and URL, invalid version/timestamp,
  non-atomic updates, and valid paired updates.


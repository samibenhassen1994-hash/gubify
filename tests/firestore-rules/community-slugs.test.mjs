import { after, before, beforeEach, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-gubify';
const ids = { owner: 'owner', outsider: 'outsider' };
let env;
const db = (uid) => env.authenticatedContext(uid).firestore();
const anonymousDb = () => env.unauthenticatedContext().firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});
after(async () => env.cleanup());
beforeEach(async () => env.clearFirestore());

function createCommunity({
  actor = ids.owner,
  communityId = 'c1',
  name = 'Football Italia',
  nameKey = 'footballitalia',
  slug = 'football-italia',
  ownerId = actor,
  registryOverrides = {},
  nameRegistryOverrides = {},
  publicOverrides = {},
  includeRegistry = true,
  includePublic = true,
} = {}) {
  const firestore = db(actor);
  const batch = writeBatch(firestore);
  batch.set(doc(firestore, 'communities', communityId), {
    communityId,
    name,
    ownerId,
    memberCount: 1,
    visibility: 'public',
    createdAt: serverTimestamp(),
    type: 'Sport',
    language: 'Italian',
    description: 'Italian football fans.',
    accessMode: 'open',
    nameKey,
    slug,
    slugAssignedAt: serverTimestamp(),
  });
  if (includeRegistry) {
    batch.set(doc(firestore, 'communitySlugs', slug), {
      slug,
      communityId,
      ownerId,
      createdAt: serverTimestamp(),
      ...registryOverrides,
    });
  }
  batch.set(doc(firestore, 'communityNames', nameKey), {
    nameKey,
    communityId,
    ownerId,
    createdAt: serverTimestamp(),
    ...nameRegistryOverrides,
  });
  if (includePublic) {
    batch.set(doc(firestore, 'communityPublic', slug), {
      communityId,
      slug,
      name,
      description: 'Italian football fans.',
      type: 'Sport',
      language: 'Italian',
      accessMode: 'open',
      memberCount: 1,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      ...publicOverrides,
    });
  }
  batch.set(doc(firestore, 'communities', communityId, 'members', actor), {
    uid: actor,
    displayName: actor,
    photoUrl: null,
    role: 'owner',
    joinedAt: serverTimestamp(),
  });
  batch.set(doc(firestore, 'users', actor, 'communities', communityId), {
    communityId,
    name,
    ownerId,
    memberCount: 1,
    visibility: 'public',
    role: 'owner',
    joinedAt: serverTimestamp(),
  });
  batch.set(
    doc(firestore, 'communityUserProgress', actor),
    {
      xp: 0,
      communityIds: [communityId],
      membershipProjectionCommunityId: communityId,
      membershipProjectionAction: 'join',
      membershipProjectionUpdatedAt: serverTimestamp(),
    },
    { merge: true },
  );
  batch.set(doc(firestore, 'communityOwnership', actor), {
    ownerId: actor,
    communityId,
    createdAt: serverTimestamp(),
  });
  return batch.commit();
}

async function seedPublicCommunities() {
  await env.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    await Promise.all([
      setDoc(doc(firestore, 'communityPublic', 'alpha'), {
        communityId: 'c-alpha',
        slug: 'alpha',
        name: 'Alpha',
        description: '',
        language: 'English',
        accessMode: 'open',
        createdAt: new Date(),
        updatedAt: new Date(),
      }),
      setDoc(doc(firestore, 'communityPublic', 'beta'), {
        communityId: 'c-beta',
        slug: 'beta',
        name: 'Beta',
        description: '',
        language: 'English',
        accessMode: 'approval',
        createdAt: new Date(),
        updatedAt: new Date(),
      }),
    ]);
  });
}

describe('Community slugs and safe public projections', () => {
  test('owner creates the matching Community, slug registry and projection', () =>
    assertSucceeds(createCommunity()));

  test('a public projection keeps the root type and memberCount', async () => {
    await assertSucceeds(createCommunity());
    await env.withSecurityRulesDisabled(async (context) => {
      const firestore = context.firestore();
      const [root, projection] = await Promise.all([
        getDoc(doc(firestore, 'communities', 'c1')),
        getDoc(doc(firestore, 'communityPublic', 'football-italia')),
      ]);
      assert.equal(projection.data().type, root.data().type);
      assert.equal(projection.data().memberCount, root.data().memberCount);
      assert.equal(projection.data().ownerId, undefined);
    });
  });

  test('a public projection rejects a type or memberCount that differs from the root', async () => {
    await assertFails(createCommunity({ publicOverrides: { type: 'Music' } }));
    await assertFails(createCommunity({ publicOverrides: { memberCount: 2 } }));
  });

  test('memberCount changes require the matching root transaction', async () => {
    await assertSucceeds(createCommunity());
    const firestore = db(ids.owner);

    await assertFails(updateDoc(
      doc(firestore, 'communityPublic', 'football-italia'),
      { memberCount: 2, updatedAt: serverTimestamp() },
    ));

    const batch = writeBatch(firestore);
    batch.update(doc(firestore, 'communities', 'c1'), { memberCount: 2 });
    batch.update(doc(firestore, 'communityPublic', 'football-italia'), {
      memberCount: 3,
      updatedAt: serverTimestamp(),
    });
    await assertFails(batch.commit());
  });

  test('a public projection rejects an updatedAt-only memberCount mutation', async () => {
    await assertSucceeds(createCommunity());

    await assertFails(updateDoc(
      doc(db(ids.owner), 'communityPublic', 'football-italia'),
      { updatedAt: serverTimestamp() },
    ));
  });

  test('a public projection rejects an unchanged memberCount mutation without a root update', async () => {
    await assertSucceeds(createCommunity());

    await assertFails(updateDoc(
      doc(db(ids.owner), 'communityPublic', 'football-italia'),
      { memberCount: 1, updatedAt: serverTimestamp() },
    ));
  });

  test('a duplicate slug registry cannot be overwritten', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'communitySlugs', 'football-italia'), {
        slug: 'football-italia', communityId: 'existing', ownerId: ids.outsider, createdAt: new Date(),
      });
    });
    await assertFails(createCommunity());
  });

  test('the same normalized name cannot be reserved twice', async () => {
    await assertSucceeds(createCommunity());
    await assertFails(
      createCommunity({
        actor: ids.outsider,
        ownerId: ids.outsider,
        communityId: 'c2',
        slug: 'football-italia-fans',
        name: '  FOOTBALL   ITALIA ',
        nameKey: 'footballitalia',
      }),
    );
  });

  test('similar but different names remain valid', async () => {
    await assertSucceeds(createCommunity());
    await assertSucceeds(
      createCommunity({
        actor: ids.outsider,
        ownerId: ids.outsider,
        communityId: 'c2',
        slug: 'football-italia-fans',
        name: 'Football Italia Fans',
        nameKey: 'footballitaliafans',
      }),
    );
  });

  test('a forged Community name registry is rejected', () =>
    assertFails(
      createCommunity({
        nameRegistryOverrides: { communityId: 'other-community' },
      }),
    ));

  test('the Rules accept the Dart V2 canonical key for accents and tab whitespace', () =>
    assertSucceeds(createCommunity({
      name: 'Cà\tffè',
      nameKey: 'caffe',
      slug: 'caffe',
    })));

  test('line breaks are rejected rather than allowing unverified normalization', () =>
    assertFails(createCommunity({
      name: 'Cà\tff\nè',
      nameKey: 'caffe',
      slug: 'caffe',
    })));

  test('the Rules accept the Dart V2 escaped-slash key', () =>
    assertSucceeds(createCommunity({
      name: 'Caffè/Roma',
      nameKey: 'caffe∕roma',
      slug: 'caffe-roma',
    })));

  test('an arbitrary Community name key cannot be selected by a modified client', () =>
    assertFails(createCommunity({ nameKey: 'attacker-selected-key' })));

  test('case, whitespace, and accent variants use the same canonical key', async () => {
    await assertSucceeds(createCommunity({ name: 'Caffè Test', nameKey: 'caffetest' }));
    await assertFails(createCommunity({
      actor: ids.outsider,
      ownerId: ids.outsider,
      communityId: 'c2',
      name: ' C A F F E\tT E S T ',
      nameKey: 'caffetest',
      slug: 'caffe-test-2',
    }));
  });

  test('concurrent attempts for the same canonical name allow only one owner', async () => {
    const attempts = await Promise.allSettled([
      createCommunity({
        communityId: 'c1',
        name: 'Race Name',
        nameKey: 'racename',
        slug: 'race-name',
      }),
      createCommunity({
        actor: ids.outsider,
        ownerId: ids.outsider,
        communityId: 'c2',
        name: ' R A C E  N A M E ',
        nameKey: 'racename',
        slug: 'race-name-2',
      }),
    ]);

    assert.equal(attempts.filter((attempt) => attempt.status === 'fulfilled').length, 1);
    assert.equal(attempts.filter((attempt) => attempt.status === 'rejected').length, 1);
  });

  test('punctuation remains distinct in canonical keys', async () => {
    await assertSucceeds(createCommunity());
    await assertSucceeds(createCommunity({
      actor: ids.outsider,
      ownerId: ids.outsider,
      communityId: 'c2',
      name: 'Football-Italia',
      nameKey: 'football-italia',
      slug: 'football-italia-2',
    }));
  });

  test('a non-owner cannot reserve a slug for another Community owner', () =>
    assertFails(createCommunity({ actor: ids.outsider, ownerId: ids.owner })));

  test('a projection rejects sensitive fields', () =>
    assertFails(createCommunity({ publicOverrides: { ownerId: ids.owner } })));

  test('a Community root requires both the registry and public projection', async () => {
    await assertFails(createCommunity({ includeRegistry: false }));
    await assertFails(createCommunity({ includePublic: false }));
  });

  test('the public projection is readable anonymously but the root is not', async () => {
    await assertSucceeds(createCommunity());
    await assertSucceeds(getDoc(doc(anonymousDb(), 'communityPublic', 'football-italia')));
    await assertFails(getDoc(doc(anonymousDb(), 'communities', 'c1')));
  });

  test('Community SEO listing keeps anonymous single-document get allowed', async () => {
    await seedPublicCommunities();

    await assertSucceeds(
      getDoc(doc(anonymousDb(), 'communityPublic', 'alpha')),
    );
  });

  test('Community SEO listing requires an anonymous query limit of at most 100', async () => {
    await seedPublicCommunities();
    const publicCommunities = collection(anonymousDb(), 'communityPublic');

    await assertSucceeds(getDocs(query(publicCommunities, limit(50))));
    await assertSucceeds(getDocs(query(publicCommunities, limit(100))));
    await assertFails(getDocs(query(publicCommunities, limit(101))));
    await assertFails(getDocs(publicCommunities));
  });

  test('Community SEO listing applies the same query limits when authenticated', async () => {
    await seedPublicCommunities();
    const publicCommunities = collection(db(ids.outsider), 'communityPublic');

    await assertSucceeds(getDocs(query(publicCommunities, limit(100))));
    await assertFails(getDocs(query(publicCommunities, limit(101))));
    await assertFails(getDocs(publicCommunities));
  });

  test('Community SEO listing does not broaden public write permissions', async () => {
    await seedPublicCommunities();
    const anonymous = anonymousDb();

    await assertFails(setDoc(doc(anonymous, 'communityPublic', 'gamma'), {
      slug: 'gamma',
    }));
    await assertFails(updateDoc(doc(anonymous, 'communityPublic', 'alpha'), {
      name: 'Changed',
    }));
    await assertFails(deleteDoc(doc(anonymous, 'communityPublic', 'alpha')));
  });

  test('a Community slug cannot be changed after creation', async () => {
    await assertSucceeds(createCommunity());
    await assertFails(updateDoc(doc(db(ids.owner), 'communities', 'c1'), { slug: 'stolen-slug' }));
  });
});

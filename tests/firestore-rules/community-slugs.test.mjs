import { after, before, beforeEach, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
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
  slug = 'football-italia',
  ownerId = actor,
  registryOverrides = {},
  publicOverrides = {},
  includeRegistry = true,
  includePublic = true,
} = {}) {
  const firestore = db(actor);
  const batch = writeBatch(firestore);
  batch.set(doc(firestore, 'communities', communityId), {
    communityId,
    name: 'Football Italia',
    ownerId,
    memberCount: 1,
    visibility: 'public',
    createdAt: serverTimestamp(),
    type: 'Sport',
    language: 'Italian',
    description: 'Italian football fans.',
    accessMode: 'open',
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
  if (includePublic) {
    batch.set(doc(firestore, 'communityPublic', slug), {
      communityId,
      slug,
      name: 'Football Italia',
      description: 'Italian football fans.',
      language: 'Italian',
      accessMode: 'open',
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
    name: 'Football Italia',
    ownerId,
    memberCount: 1,
    visibility: 'public',
    role: 'owner',
    joinedAt: serverTimestamp(),
  });
  batch.set(doc(firestore, 'communityOwnership', actor), {
    ownerId: actor,
    communityId,
    createdAt: serverTimestamp(),
  });
  return batch.commit();
}

describe('Community slugs and safe public projections', () => {
  test('owner creates the matching Community, slug registry and projection', () =>
    assertSucceeds(createCommunity()));

  test('a duplicate slug registry cannot be overwritten', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'communitySlugs', 'football-italia'), {
        slug: 'football-italia', communityId: 'existing', ownerId: ids.outsider, createdAt: new Date(),
      });
    });
    await assertFails(createCommunity());
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

  test('a Community slug cannot be changed after creation', async () => {
    await assertSucceeds(createCommunity());
    await assertFails(updateDoc(doc(db(ids.owner), 'communities', 'c1'), { slug: 'stolen-slug' }));
  });
});

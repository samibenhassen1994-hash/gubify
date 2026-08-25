import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, serverTimestamp, setDoc, writeBatch } from 'firebase/firestore';

const projectId = 'demo-gubify';
const communityId = 'abc123';
const slug = 'photos';
const validUrl = 'https://res.cloudinary.com/s3yauoza/image/upload/v42/community_abc123.jpg';
let env;
const db = (uid) => env.authenticatedContext(uid).firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});
after(async () => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    await setDoc(doc(firestore, 'communities', communityId), {
      communityId, name: 'Photos', ownerId: 'owner', memberCount: 2,
      visibility: 'public', createdAt: new Date(1), type: 'Art & Creativity',
      language: 'English', description: '', accessMode: 'open', nameKey: 'photos',
      slug, slugAssignedAt: new Date(1),
    });
    await setDoc(doc(firestore, 'communityPublic', slug), {
      communityId, slug, name: 'Photos', description: '', language: 'English',
      accessMode: 'open', createdAt: new Date(1), updatedAt: new Date(1),
    });
    for (const uid of ['owner', 'member']) {
      await setDoc(doc(firestore, 'communities', communityId, 'members', uid), {
        uid, displayName: uid, photoUrl: null,
        role: uid === 'owner' ? 'owner' : 'member', joinedAt: new Date(1),
      });
    }
  });
});

function pairedUpdate(actor, {
  imageUrl = validUrl,
  imagePublicId = 'community_abc123',
  imageVersion = 42,
  publicUrl = imageUrl,
  publicVersion = imageVersion,
} = {}) {
  const firestore = db(actor);
  const batch = writeBatch(firestore);
  batch.update(doc(firestore, 'communities', communityId), {
    imageUrl, imagePublicId, imageVersion, imageUpdatedAt: serverTimestamp(),
  });
  batch.update(doc(firestore, 'communityPublic', slug), {
    imageUrl: publicUrl, imageVersion: publicVersion, updatedAt: serverTimestamp(),
  });
  return batch.commit();
}

describe('Community image metadata', () => {
  test('owner can atomically publish the deterministic Community asset', () =>
    assertSucceeds(pairedUpdate('owner')));

  test('normal member and outsider cannot update image metadata', async () => {
    await assertFails(pairedUpdate('member'));
    await assertFails(pairedUpdate('outsider'));
  });

  test('external account URL and wrong deterministic asset are denied', async () => {
    await assertFails(pairedUpdate('owner', {
      imageUrl: 'https://res.cloudinary.com/other/image/upload/v42/community_abc123.jpg',
    }));
    await assertFails(pairedUpdate('owner', {
      imageUrl: 'https://res.cloudinary.com/s3yauoza/image/upload/v42/community_other.jpg',
    }));
    await assertFails(pairedUpdate('owner', {
      imageUrl: 'https://res.cloudinary.com/s3yauoza/image/upload/v0/community_abc123.jpg',
    }));
  });

  test('wrong public id and invalid version are denied', async () => {
    await assertFails(pairedUpdate('owner', { imagePublicId: 'community_other' }));
    await assertFails(pairedUpdate('owner', { imageVersion: 0, publicVersion: 0 }));
  });

  test('root and public projection must match', () =>
    assertFails(pairedUpdate('owner', { publicVersion: 43 })));

  test('root-only and public-only writes are denied', async () => {
    await assertFails(setDoc(doc(db('owner'), 'communities', communityId), {
      imageUrl: validUrl, imagePublicId: 'community_abc123', imageVersion: 42,
      imageUpdatedAt: serverTimestamp(),
    }, { merge: true }));
    await assertFails(setDoc(doc(db('owner'), 'communityPublic', slug), {
      imageUrl: validUrl, imageVersion: 42, updatedAt: serverTimestamp(),
    }, { merge: true }));
  });
});

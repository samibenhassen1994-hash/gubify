import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-gubify-community-guidelines';
let env;
const db = (uid, provider = 'google.com') =>
  env.authenticatedContext(uid, {
    firebase: { sign_in_provider: provider },
  }).firestore();
const upgradedDb = (uid, identityProvider) =>
  env.authenticatedContext(uid, {
    firebase: {
      sign_in_provider: 'anonymous',
      identities: { [identityProvider]: ['linked-identity'] },
    },
  }).firestore();
const unauthenticatedDb = () => env.unauthenticatedContext().firestore();
const ref = (database, uid = 'member') =>
  doc(database, 'communityGuidelinesAcceptances', uid);
const acceptance = (overrides = {}) => ({
  accepted: true,
  acceptedAt: serverTimestamp(),
  version: 1,
  ...overrides,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});
after(async () => env.cleanup());
beforeEach(async () => env.clearFirestore());

describe('global Community Guidelines acceptance', () => {
  for (const [name, database] of [
    ['direct Google', () => db('member', 'google.com')],
    ['direct email/password', () => db('member', 'password')],
    ['anonymous-upgraded Google', () => upgradedDb('member', 'google.com')],
    ['anonymous-upgraded email', () => upgradedDb('member', 'email')],
  ]) {
    test(`${name} writes and reads own current acceptance`, async () => {
      const client = database();
      await assertSucceeds(setDoc(ref(client), acceptance()));
      await assertSucceeds(getDoc(ref(client)));
    });
  }

  test('owner can update and delete own acceptance', async () => {
    const client = db('member');
    await assertSucceeds(setDoc(ref(client), acceptance()));
    await assertSucceeds(setDoc(ref(client), acceptance()));
    await assertSucceeds(deleteDoc(ref(client)));
  });

  test('anonymous and unauthenticated users are denied', async () => {
    await assertFails(setDoc(ref(db('member', 'anonymous')), acceptance()));
    await assertFails(setDoc(ref(unauthenticatedDb()), acceptance()));
  });

  test('users cannot write or read another user acceptance', async () => {
    const client = db('other');
    await assertFails(setDoc(ref(client, 'member'), acceptance()));
    await env.withSecurityRulesDisabled((context) =>
      setDoc(ref(context.firestore(), 'member'), {
        accepted: true,
        acceptedAt: new Date(),
        version: 1,
      }),
    );
    await assertFails(getDoc(ref(client, 'member')));
  });

  test('false acceptance and wrong version are denied', async () => {
    const client = db('member');
    await assertFails(setDoc(ref(client), acceptance({ accepted: false })));
    await assertFails(setDoc(ref(client), acceptance({ version: 0 })));
    await assertFails(setDoc(ref(client), acceptance({ version: 2 })));
  });

  test('forged timestamp, missing fields and extra fields are denied', async () => {
    const client = db('member');
    await assertFails(setDoc(ref(client), acceptance({ acceptedAt: new Date(0) })));
    await assertFails(setDoc(ref(client), { accepted: true, version: 1 }));
    await assertFails(setDoc(ref(client), acceptance({ extra: true })));
  });

  test('old Community member fields are no longer an acceptance path', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const batch = writeBatch(context.firestore());
      batch.set(doc(context.firestore(), 'communities', 'community-1'), {
        communityId: 'community-1',
        ownerId: 'owner',
        memberCount: 1,
        deletionStatus: 'active',
      });
      batch.set(
        doc(context.firestore(), 'communities', 'community-1', 'members', 'member'),
        { uid: 'member', displayName: 'Member', role: 'member', joinedAt: new Date() },
      );
      await batch.commit();
    });
    await assertFails(
      updateDoc(
        doc(db('member'), 'communities', 'community-1', 'members', 'member'),
        {
          antiSpamRulesAccepted: true,
          antiSpamRulesAcceptedAt: serverTimestamp(),
          antiSpamRulesVersion: 1,
        },
      ),
    );
  });
});

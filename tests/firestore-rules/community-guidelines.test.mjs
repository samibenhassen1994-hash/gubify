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
  serverTimestamp,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-gubify-community-guidelines';
const ids = {
  owner: 'owner',
  member: 'member',
  outsider: 'outsider',
  anonymous: 'anonymous',
};
const joinedAt = new Date('2026-09-09T00:00:00Z');
let env;

const db = (uid, provider = 'google.com') =>
  env.authenticatedContext(uid, {
    firebase: { sign_in_provider: provider },
  }).firestore();
const unauthenticatedDb = () => env.unauthenticatedContext().firestore();
const memberRef = (database, uid) =>
  doc(database, 'communities', 'community-1', 'members', uid);
const acceptance = (overrides = {}) => ({
  antiSpamRulesAccepted: true,
  antiSpamRulesAcceptedAt: serverTimestamp(),
  antiSpamRulesVersion: 1,
  ...overrides,
});

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
    const database = context.firestore();
    const batch = writeBatch(database);
    batch.set(doc(database, 'communities', 'community-1'), {
      communityId: 'community-1',
      name: 'Community',
      ownerId: ids.owner,
      memberCount: 3,
      visibility: 'public',
      deletionStatus: 'active',
      createdAt: joinedAt,
    });
    for (const [uid, role] of [
      [ids.owner, 'owner'],
      [ids.member, 'member'],
      [ids.anonymous, 'member'],
    ]) {
      batch.set(memberRef(database, uid), {
        uid,
        displayName: uid,
        photoUrl: null,
        role,
        joinedAt,
      });
    }
    await batch.commit();
  });
});

describe('Community Guidelines acceptance', () => {
  test('linked current member can accept the supported version', async () => {
    const database = db(ids.member);
    await assertSucceeds(
      updateDoc(memberRef(database, ids.member), acceptance()),
    );
  });

  test('linked owner can accept the supported version', async () => {
    const database = db(ids.owner);
    await assertSucceeds(
      updateDoc(memberRef(database, ids.owner), acceptance()),
    );
  });

  test('anonymous and unauthenticated users cannot accept', async () => {
    const anonymous = db(ids.anonymous, 'anonymous');
    await assertFails(
      updateDoc(memberRef(anonymous, ids.anonymous), acceptance()),
    );
    await assertFails(
      updateDoc(
        memberRef(unauthenticatedDb(), ids.member),
        acceptance(),
      ),
    );
  });

  test('outsiders, removed members and other users cannot accept', async () => {
    await assertFails(
      updateDoc(memberRef(db(ids.outsider), ids.outsider), acceptance()),
    );

    await env.withSecurityRulesDisabled(async (context) => {
      await deleteDoc(memberRef(context.firestore(), ids.member));
    });
    await assertFails(
      updateDoc(memberRef(db(ids.member), ids.member), acceptance()),
    );
    await assertFails(
      updateDoc(memberRef(db(ids.owner), ids.anonymous), acceptance()),
    );
  });

  test('false, unsupported version and forged timestamp are denied', async () => {
    const database = db(ids.member);
    await assertFails(
      updateDoc(
        memberRef(database, ids.member),
        acceptance({ antiSpamRulesAccepted: false }),
      ),
    );
    await assertFails(
      updateDoc(
        memberRef(database, ids.member),
        acceptance({ antiSpamRulesVersion: 2 }),
      ),
    );
    await assertFails(
      updateDoc(
        memberRef(database, ids.member),
        acceptance({
          antiSpamRulesAcceptedAt: new Date('2026-09-09T00:00:00Z'),
        }),
      ),
    );
  });

  test('acceptance cannot modify identity or role fields', async () => {
    const database = db(ids.member);
    for (const extra of [
      { displayName: 'Forged' },
      { role: 'owner' },
      { photoUrl: 'https://example.com/forged.png' },
      { joinedAt: serverTimestamp() },
    ]) {
      await assertFails(
        updateDoc(
          memberRef(database, ids.member),
          acceptance(extra),
        ),
      );
    }
  });

  test('acceptance cannot modify progress, reward or cooldown fields', async () => {
    const database = db(ids.member);
    for (const extra of [
      { xp: 100 },
      { bestAnswerCount: 1 },
      { lastAskCreatedAt: serverTimestamp() },
      { arbitraryField: true },
    ]) {
      await assertFails(
        updateDoc(
          memberRef(database, ids.member),
          acceptance(extra),
        ),
      );
    }
  });

  test('acceptance is denied while the Community is deleting', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'communities', 'community-1'), {
        deletionStatus: 'deleting',
      });
    });
    const database = db(ids.member);
    await assertFails(
      updateDoc(memberRef(database, ids.member), acceptance()),
    );
  });
});

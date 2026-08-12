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
  orderBy,
  query,
  where,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-gubify-private-notification-history';
const t0 = new Date('2026-01-01T00:00:00Z');
const t1 = new Date('2026-01-02T00:00:00Z');
const t2 = new Date('2026-01-03T00:00:00Z');
const t3 = new Date('2026-01-04T00:00:00Z');
const t4 = new Date('2026-01-05T00:00:00Z');
const t5 = new Date('2026-01-06T00:00:00Z');
const t6 = new Date('2026-01-07T00:00:00Z');
const ids = {
  owner: 'owner',
  member: 'member',
  outsider: 'outsider',
  legacy: 'legacy',
};

let env;
const db = (uid) => env.authenticatedContext(uid).firestore();
const notifications = (uid) =>
  collection(db(uid), 'gubs', 'g1', 'notifications');
const notificationDocument = (uid, notificationId) =>
  doc(db(uid), 'gubs', 'g1', 'notifications', notificationId);

const membership = (uid, role, joinedAt) => ({
  uid,
  displayName: uid,
  photoUrl: null,
  role,
  ...(joinedAt ? { joinedAt } : {}),
});

const notification = (notificationId, createdAt) => ({
  notificationId,
  title: notificationId,
  body: notificationId,
  type: 'task_created',
  senderId: ids.owner,
  senderName: ids.owner,
  createdAt,
  readBy: [],
  data: { module: 'tasks', gubId: 'g1', taskId: 'task1' },
});

const notificationsSince = async (uid, boundary) => {
  const snapshot = await assertSucceeds(
    getDocs(
      query(
        notifications(uid),
        where('createdAt', '>=', boundary),
        orderBy('createdAt', 'desc'),
      ),
    ),
  );
  return snapshot.docs.map((document) => document.id);
};

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
    batch.set(doc(database, 'gubs', 'g1'), {
      gubId: 'g1',
      name: 'Private',
      ownerId: ids.owner,
      memberCount: 2,
      inviteTokenId: 'ABCDEFGH',
      createdAt: t0,
    });
    batch.set(
      doc(database, 'gubs', 'g1', 'members', ids.owner),
      membership(ids.owner, 'owner', t0),
    );
    batch.set(
      doc(database, 'gubs', 'g1', 'members', ids.member),
      membership(ids.member, 'member', t2),
    );
    batch.set(
      doc(database, 'gubs', 'g1', 'members', ids.legacy),
      membership(ids.legacy, 'member', null),
    );
    for (const [id, createdAt] of [
      ['pre-join', t1],
      ['post-join', t3],
      ['while-away', t4],
      ['post-rejoin', t6],
    ]) {
      batch.set(
        doc(database, 'gubs', 'g1', 'notifications', id),
        notification(id, createdAt),
      );
    }
    await batch.commit();
  });
});

describe('Private notification membership history boundary', () => {
  test('owner sees notifications created after the original membership', async () => {
    assert.deepEqual(await notificationsSince(ids.owner, t0), [
      'post-rejoin',
      'while-away',
      'post-join',
      'pre-join',
    ]);
  });

  test('a new member does not receive notifications from before joining', async () => {
    assert(!((await notificationsSince(ids.member, t2)).includes('pre-join')));
  });

  test('a new member receives notifications from after joining', async () => {
    assert((await notificationsSince(ids.member, t2)).includes('post-join'));
  });

  test('an unbounded notification query is denied', async () => {
    await assertFails(getDocs(notifications(ids.member)));
  });

  test('a notification query below joinedAt is denied', async () => {
    await assertFails(
      getDocs(query(notifications(ids.member), where('createdAt', '>=', t1))),
    );
  });

  test('a direct get of a pre-join notification is denied', async () => {
    await assertFails(getDoc(notificationDocument(ids.member, 'pre-join')));
  });

  test('a direct get of a post-join notification is allowed', async () => {
    await assertSucceeds(getDoc(notificationDocument(ids.member, 'post-join')));
  });

  test('an outsider is denied', async () => {
    await assertFails(
      getDocs(query(notifications(ids.outsider), where('createdAt', '>=', t0))),
    );
  });

  test('a removed member is denied', async () => {
    await env.withSecurityRulesDisabled((context) =>
      deleteDoc(doc(context.firestore(), 'gubs', 'g1', 'members', ids.member)),
    );
    await assertFails(
      getDocs(query(notifications(ids.member), where('createdAt', '>=', t2))),
    );
  });

  test('a rejoin requires the new joinedAt boundary', async () => {
    await replaceWithRejoinedMember();
    await assertFails(
      getDocs(query(notifications(ids.member), where('createdAt', '>=', t2))),
    );
  });

  test('a rejoined member cannot directly get notifications sent while away', async () => {
    await replaceWithRejoinedMember();
    await assertFails(getDoc(notificationDocument(ids.member, 'while-away')));
  });

  test('a rejoined member receives notifications created after rejoin', async () => {
    await replaceWithRejoinedMember();
    assert.deepEqual(await notificationsSince(ids.member, t5), ['post-rejoin']);
  });

  test('a membership without joinedAt fails closed', async () => {
    await assertFails(
      getDocs(query(notifications(ids.legacy), where('createdAt', '>=', t0))),
    );
  });
});

async function replaceWithRejoinedMember() {
  await env.withSecurityRulesDisabled(async (context) => {
    const database = context.firestore();
    await deleteDoc(doc(database, 'gubs', 'g1', 'members', ids.member));
    await writeBatch(database)
        .set(
          doc(database, 'gubs', 'g1', 'members', ids.member),
          membership(ids.member, 'member', t5),
        )
        .commit();
  });
}

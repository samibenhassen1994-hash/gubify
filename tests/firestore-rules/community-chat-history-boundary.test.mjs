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
  orderBy,
  query,
  where,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-gubify-community-chat-history';
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
const messages = (uid) => collection(db(uid), 'communities', 'c1', 'messages');
const messageDocument = (uid, messageId) =>
  doc(db(uid), 'communities', 'c1', 'messages', messageId);

const membership = (uid, role, joinedAt) => ({
  uid,
  displayName: uid,
  photoUrl: null,
  role,
  ...(joinedAt ? { joinedAt } : {}),
});

const message = (messageId, createdAt) => ({
  messageId,
  communityId: 'c1',
  senderId: ids.owner,
  senderName: ids.owner,
  text: messageId,
  createdAt,
});

const messagesSince = async (uid, boundary) => {
  const snapshot = await assertSucceeds(
    getDocs(
      query(
        messages(uid),
        where('createdAt', '>=', boundary),
        orderBy('createdAt', 'desc'),
        limit(50),
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
    batch.set(doc(database, 'communities', 'c1'), {
      communityId: 'c1',
      name: 'Community',
      ownerId: ids.owner,
      memberCount: 2,
      visibility: 'public',
      createdAt: t0,
    });
    batch.set(
      doc(database, 'communities', 'c1', 'members', ids.owner),
      membership(ids.owner, 'owner', t0),
    );
    batch.set(
      doc(database, 'communities', 'c1', 'members', ids.member),
      membership(ids.member, 'member', t2),
    );
    batch.set(
      doc(database, 'communities', 'c1', 'members', ids.legacy),
      membership(ids.legacy, 'member', null),
    );
    batch.set(
      doc(database, 'communities', 'c1', 'messages', 'pre-join'),
      message('pre-join', t1),
    );
    batch.set(
      doc(database, 'communities', 'c1', 'messages', 'post-join'),
      message('post-join', t3),
    );
    batch.set(
      doc(database, 'communities', 'c1', 'messages', 'while-away'),
      message('while-away', t4),
    );
    batch.set(
      doc(database, 'communities', 'c1', 'messages', 'post-rejoin'),
      message('post-rejoin', t6),
    );
    await batch.commit();
  });
});

describe('Community Chat membership history boundary', () => {
  test('owner reads messages created after the original membership', async () => {
    assert.deepEqual(await messagesSince(ids.owner, t0), [
      'post-rejoin',
      'while-away',
      'post-join',
      'pre-join',
    ]);
  });

  test('a new member does not receive pre-join messages', async () => {
    assert(!((await messagesSince(ids.member, t2)).includes('pre-join')));
  });

  test('a new member receives post-join messages', async () => {
    assert((await messagesSince(ids.member, t2)).includes('post-join'));
  });

  test('an unbounded Community Chat query is denied', async () => {
    await assertFails(getDocs(messages(ids.member)));
  });

  test('a Community Chat query below joinedAt is denied', async () => {
    await assertFails(
      getDocs(query(messages(ids.member), where('createdAt', '>=', t1))),
    );
  });

  test('a direct get of a pre-join message is denied', async () => {
    await assertFails(getDoc(messageDocument(ids.member, 'pre-join')));
  });

  test('a direct get of a post-join message is allowed', async () => {
    await assertSucceeds(getDoc(messageDocument(ids.member, 'post-join')));
  });

  test('an outsider is denied', async () => {
    await assertFails(
      getDocs(query(messages(ids.outsider), where('createdAt', '>=', t0))),
    );
  });

  test('a removed member is denied', async () => {
    await env.withSecurityRulesDisabled((context) =>
      deleteDoc(
        doc(context.firestore(), 'communities', 'c1', 'members', ids.member),
      ),
    );
    await assertFails(
      getDocs(query(messages(ids.member), where('createdAt', '>=', t2))),
    );
  });

  test('a rejoin requires the new joinedAt boundary', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const database = context.firestore();
      await deleteDoc(doc(database, 'communities', 'c1', 'members', ids.member));
      await writeBatch(database)
          .set(
            doc(database, 'communities', 'c1', 'members', ids.member),
            membership(ids.member, 'member', t5),
          )
          .commit();
    });
    await assertFails(
      getDocs(query(messages(ids.member), where('createdAt', '>=', t2))),
    );
  });

  test('a rejoined member cannot directly get messages sent while away', async () => {
    await replaceWithRejoinedMember();
    await assertFails(getDoc(messageDocument(ids.member, 'while-away')));
  });

  test('a rejoined member receives messages created after rejoin', async () => {
    await replaceWithRejoinedMember();
    assert.deepEqual(await messagesSince(ids.member, t5), ['post-rejoin']);
  });

  test('a membership without joinedAt fails closed', async () => {
    await assertFails(
      getDocs(query(messages(ids.legacy), where('createdAt', '>=', t0))),
    );
  });
});

async function replaceWithRejoinedMember() {
  await env.withSecurityRulesDisabled(async (context) => {
    const database = context.firestore();
    await deleteDoc(doc(database, 'communities', 'c1', 'members', ids.member));
    await writeBatch(database)
        .set(
          doc(database, 'communities', 'c1', 'members', ids.member),
          membership(ids.member, 'member', t5),
        )
        .commit();
  });
}

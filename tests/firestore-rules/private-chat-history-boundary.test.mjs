import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, getDoc, getDocs, query, where, writeBatch } from 'firebase/firestore';

const projectId = 'demo-gubify-private-chat-history';
const t0 = new Date('2026-01-01T00:00:00Z');
const t1 = new Date('2026-01-02T00:00:00Z');
const t2 = new Date('2026-01-03T00:00:00Z');
const t3 = new Date('2026-01-04T00:00:00Z');
const t4 = new Date('2026-01-05T00:00:00Z');
const ids = { owner: 'owner', member: 'member', outsider: 'outsider', legacy: 'legacy' };

let env;
const db = (uid) => env.authenticatedContext(uid).firestore();
const messages = (uid) => collection(db(uid), 'gubs', 'g1', 'messages');

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
      gubId: 'g1', name: 'Private', ownerId: ids.owner, memberCount: 2,
      inviteTokenId: 'ABCDEFGH', createdAt: t0,
    });
    for (const [uid, joinedAt, role] of [[ids.owner, t0, 'owner'], [ids.member, t2, 'member'], [ids.legacy, null, 'member']]) {
      batch.set(doc(database, 'gubs', 'g1', 'members', uid), {
        uid, displayName: uid, photoUrl: null, role, ...(joinedAt ? { joinedAt } : {}),
      });
    }
    for (const [id, createdAt] of [['owner-visible', t1], ['member-old', t1], ['member-new', t3], ['while-away', t3], ['rejoin-new', t4]]) {
      batch.set(doc(database, 'gubs', 'g1', 'messages', id), {
        messageId: id, gubId: 'g1', senderId: ids.owner, senderName: ids.owner,
        text: id, createdAt,
      });
    }
    await batch.commit();
  });
});

describe('Private Chat membership history boundary', () => {
  test('owner and new member only read the post-boundary window', async () => {
    await assertSucceeds(getDocs(query(messages(ids.owner), where('createdAt', '>=', t0))));
    await assertFails(getDocs(messages(ids.member)));
    await assertFails(getDocs(query(messages(ids.member), where('createdAt', '>=', t1))));
    await assertSucceeds(getDocs(query(messages(ids.member), where('createdAt', '>=', t2))));
    await assertFails(getDoc(doc(db(ids.member), 'gubs', 'g1', 'messages', 'member-old')));
    await assertSucceeds(getDoc(doc(db(ids.member), 'gubs', 'g1', 'messages', 'member-new')));
  });

  test('outsiders, removed members, and legacy memberships fail closed', async () => {
    await assertFails(getDocs(query(messages(ids.outsider), where('createdAt', '>=', t0))));
    await assertFails(getDocs(query(messages(ids.legacy), where('createdAt', '>=', t0))));
    await env.withSecurityRulesDisabled(async (context) => {
      await deleteDoc(doc(context.firestore(), 'gubs', 'g1', 'members', ids.member));
    });
    await assertFails(getDocs(query(messages(ids.member), where('createdAt', '>=', t2))));
  });

  test('rejoin uses only the latest joinedAt window', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await deleteDoc(doc(context.firestore(), 'gubs', 'g1', 'members', ids.member));
      await writeBatch(context.firestore())
        .set(doc(context.firestore(), 'gubs', 'g1', 'members', ids.member), {
          uid: ids.member, displayName: ids.member, photoUrl: null, role: 'member', joinedAt: t4,
        })
        .commit();
    });
    await assertFails(getDocs(query(messages(ids.member), where('createdAt', '>=', t2))));
    await assertFails(getDoc(doc(db(ids.member), 'gubs', 'g1', 'messages', 'while-away')));
    await assertSucceeds(getDocs(query(messages(ids.member), where('createdAt', '>=', t4))));
    await assertSucceeds(getDoc(doc(db(ids.member), 'gubs', 'g1', 'messages', 'rejoin-new')));
  });
});

import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-gubify-history-boundaries';
const ids = {
  privateMember: 'privateMember',
  communityMember: 'communityMember',
  outsider: 'outsider',
};
const beforeJoin = new Date('2026-01-01T00:00:00Z');
const joinedAt = new Date('2026-01-02T00:00:00Z');
const afterJoin = new Date('2026-01-03T00:00:00Z');
const rejoinedAt = new Date('2026-01-04T00:00:00Z');

let env;
const db = (uid) => env.authenticatedContext(uid).firestore();
const privateMessages = (uid) => collection(db(uid), 'gubs', 'g1', 'messages');
const communityMessages = (uid) => collection(db(uid), 'communities', 'c1', 'messages');
const posts = (uid) => collection(db(uid), 'gubs', 'g1', 'posts');
const tasks = (uid) => collection(db(uid), 'gubs', 'g1', 'tasks');
const proposals = (uid) => collection(db(uid), 'gubs', 'g1', 'proposals');
const goals = (uid) => collection(db(uid), 'gubs', 'g1', 'goals');
const events = (uid) => collection(db(uid), 'gubs', 'g1', 'events');

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
    for (const uid of Object.values(ids)) {
      batch.set(doc(database, 'users', uid), {
        displayName: uid,
        createdAt: beforeJoin,
        updatedAt: beforeJoin,
        activeHub: null,
        avatar: null,
      });
    }
    batch.set(doc(database, 'gubs', 'g1'), {
      gubId: 'g1', name: 'Private', ownerId: ids.privateMember,
      inviteTokenId: 'K7M4P9Q2', memberCount: 1, createdAt: beforeJoin,
    });
    batch.set(doc(database, 'gubs', 'g1', 'members', ids.privateMember), {
      uid: ids.privateMember, displayName: ids.privateMember, photoUrl: null,
      role: 'owner', joinedAt,
    });
    batch.set(doc(database, 'communities', 'c1'), {
      communityId: 'c1', name: 'Community', ownerId: ids.communityMember,
      memberCount: 1, visibility: 'public', createdAt: beforeJoin,
      type: 'General', language: 'English', description: '', accessMode: 'open',
    });
    batch.set(doc(database, 'communities', 'c1', 'members', ids.communityMember), {
      uid: ids.communityMember, displayName: ids.communityMember, photoUrl: null,
      role: 'owner', joinedAt,
    });
    for (const [path, data] of [
      [['gubs', 'g1', 'messages', 'old'], { messageId: 'old', gubId: 'g1', senderId: ids.privateMember, senderName: ids.privateMember, text: 'old', createdAt: beforeJoin }],
      [['gubs', 'g1', 'messages', 'new'], { messageId: 'new', gubId: 'g1', senderId: ids.privateMember, senderName: ids.privateMember, text: 'new', createdAt: afterJoin }],
      [['communities', 'c1', 'messages', 'old'], { messageId: 'old', communityId: 'c1', senderId: ids.communityMember, senderName: ids.communityMember, text: 'old', createdAt: beforeJoin }],
      [['communities', 'c1', 'messages', 'new'], { messageId: 'new', communityId: 'c1', senderId: ids.communityMember, senderName: ids.communityMember, text: 'new', createdAt: afterJoin }],
      [['gubs', 'g1', 'posts', 'old'], { gubId: 'g1', authorId: ids.privateMember, authorName: ids.privateMember, authorPhoto: null, message: 'old', likes: 0, comments: 0, createdAt: beforeJoin, updatedAt: beforeJoin }],
      [['gubs', 'g1', 'posts', 'new'], { gubId: 'g1', authorId: ids.privateMember, authorName: ids.privateMember, authorPhoto: null, message: 'new', likes: 0, comments: 0, createdAt: afterJoin, updatedAt: afterJoin }],
      [['gubs', 'g1', 'tasks', 'active'], { status: 'active', completedAt: null }],
      [['gubs', 'g1', 'tasks', 'old'], { status: 'completed', completedAt: beforeJoin }],
      [['gubs', 'g1', 'tasks', 'new'], { status: 'completed', completedAt: afterJoin }],
      [['gubs', 'g1', 'proposals', 'active'], { status: 'voting', resolvedAt: null }],
      [['gubs', 'g1', 'proposals', 'old'], { status: 'approved', resolvedAt: beforeJoin }],
      [['gubs', 'g1', 'proposals', 'new'], { status: 'rejected', resolvedAt: afterJoin }],
      [['gubs', 'g1', 'goals', 'active'], { status: 'active', archived: false, completedAt: null }],
      [['gubs', 'g1', 'goals', 'old'], { status: 'completed', archived: false, completedAt: beforeJoin }],
      [['gubs', 'g1', 'goals', 'new'], { status: 'completed', archived: false, completedAt: afterJoin }],
      [['gubs', 'g1', 'events', 'past'], { eventDate: beforeJoin }],
      [['gubs', 'g1', 'events', 'future'], { eventDate: new Date('2030-01-01T00:00:00Z') }],
    ]) {
      batch.set(doc(database, ...path), data);
    }
    await batch.commit();
  });
});

describe('production membership history boundaries', () => {
  test('Private Chat and Board deny old history, including direct document access', async () => {
    await assertSucceeds(getDocs(query(privateMessages(ids.privateMember), where('createdAt', '>=', joinedAt))));
    await assertFails(getDocs(privateMessages(ids.privateMember)));
    await assertFails(getDocs(query(privateMessages(ids.privateMember), where('createdAt', '>=', beforeJoin))));
    await assertFails(getDoc(doc(db(ids.privateMember), 'gubs', 'g1', 'messages', 'old')));
    await assertSucceeds(getDoc(doc(db(ids.privateMember), 'gubs', 'g1', 'messages', 'new')));
    await assertSucceeds(getDocs(query(posts(ids.privateMember), where('createdAt', '>=', joinedAt))));
    await assertFails(getDocs(posts(ids.privateMember)));
    await assertFails(getDoc(doc(db(ids.privateMember), 'gubs', 'g1', 'posts', 'old')));
    await assertSucceeds(getDoc(doc(db(ids.privateMember), 'gubs', 'g1', 'posts', 'new')));
  });

  test('Community Chat enforces the same boundary and denies outsiders', async () => {
    await assertSucceeds(getDocs(query(communityMessages(ids.communityMember), where('createdAt', '>=', joinedAt))));
    await assertFails(getDocs(communityMessages(ids.communityMember)));
    await assertFails(getDoc(doc(db(ids.communityMember), 'communities', 'c1', 'messages', 'old')));
    await assertSucceeds(getDoc(doc(db(ids.communityMember), 'communities', 'c1', 'messages', 'new')));
    await assertFails(getDocs(query(communityMessages(ids.outsider), where('createdAt', '>=', joinedAt))));
  });

  test('a later rejoin boundary hides the previous membership period', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'gubs', 'g1', 'members', ids.privateMember), {
        uid: ids.privateMember, displayName: ids.privateMember, photoUrl: null,
        role: 'owner', joinedAt: rejoinedAt,
      });
    });
    await assertFails(getDocs(query(privateMessages(ids.privateMember), where('createdAt', '>=', joinedAt))));
    await assertSucceeds(getDocs(query(privateMessages(ids.privateMember), where('createdAt', '>=', rejoinedAt))));
  });

  test('a valid current member can still write one canonical message', async () => {
    await assertSucceeds(setDoc(doc(db(ids.privateMember), 'gubs', 'g1', 'messages', 'sent'), {
      messageId: 'sent', gubId: 'g1', senderId: ids.privateMember,
      senderName: ids.privateMember, text: 'sent', createdAt: serverTimestamp(),
    }));
    await assertSucceeds(setDoc(doc(db(ids.communityMember), 'communities', 'c1', 'messages', 'sent'), {
      messageId: 'sent', communityId: 'c1', senderId: ids.communityMember,
      senderName: ids.communityMember, text: 'sent', createdAt: serverTimestamp(),
    }));
  });

  test('collaborative state exposes current items and only bounded history', async () => {
    await assertSucceeds(getDocs(query(tasks(ids.privateMember), where('status', '==', 'active'))));
    await assertSucceeds(getDocs(query(tasks(ids.privateMember), where('status', '==', 'completed'), where('completedAt', '>=', joinedAt))));
    await assertFails(getDoc(doc(db(ids.privateMember), 'gubs', 'g1', 'tasks', 'old')));
    await assertSucceeds(getDoc(doc(db(ids.privateMember), 'gubs', 'g1', 'tasks', 'new')));

    await assertSucceeds(getDocs(query(proposals(ids.privateMember), where('status', '==', 'voting'))));
    await assertSucceeds(getDocs(query(proposals(ids.privateMember), where('status', '==', 'approved'), where('resolvedAt', '>=', joinedAt))));
    await assertFails(getDoc(doc(db(ids.privateMember), 'gubs', 'g1', 'proposals', 'old')));

    await assertSucceeds(getDocs(query(goals(ids.privateMember), where('status', '==', 'active'), where('archived', '==', false))));
    await assertSucceeds(getDocs(query(goals(ids.privateMember), where('status', '==', 'completed'), where('completedAt', '>=', joinedAt))));
    await assertFails(getDoc(doc(db(ids.privateMember), 'gubs', 'g1', 'goals', 'old')));

    await assertFails(getDoc(doc(db(ids.privateMember), 'gubs', 'g1', 'events', 'past')));
    await assertSucceeds(getDoc(doc(db(ids.privateMember), 'gubs', 'g1', 'events', 'future')));
    await assertFails(getDocs(query(events(ids.outsider), where('eventDate', '>=', joinedAt))));
  });
});

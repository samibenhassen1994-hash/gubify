import { after, before, beforeEach, test } from 'node:test';
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
  increment,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-gubify-board';
const ids = { owner: 'owner', member: 'member', outsider: 'outsider' };
const now = () => new Date('2026-01-01T00:00:00Z');
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
    const seed = context.firestore();
    await setDoc(doc(seed, 'gubs', 'g1'), {
      gubId: 'g1', name: 'Board', ownerId: ids.owner,
      inviteTokenId: 'CODE', memberCount: 2, createdAt: now(),
    });
    for (const [uid, role] of [[ids.owner, 'owner'], [ids.member, 'member']]) {
      await setDoc(doc(seed, 'users', uid), {
        displayName: uid, createdAt: now(), updatedAt: now(), activeHub: null, avatar: null,
      });
      await setDoc(doc(seed, 'gubs', 'g1', 'members', uid), {
        uid, displayName: uid, photoUrl: null, role, joinedAt: now(),
      });
    }
    for (const postId of ['p1', 'p2']) {
      await setDoc(doc(seed, 'gubs', 'g1', 'posts', postId), {
        gubId: 'g1', authorId: ids.owner, authorName: ids.owner,
        authorPhoto: null, message: postId, likes: 0, comments: 0,
        createdAt: now(), updatedAt: now(),
      });
    }
  });
});

test('only owner can pin, replace and unpin a Board post', async () => {
  const root = doc(db(ids.owner), 'gubs', 'g1');
  await assertSucceeds(updateDoc(root, { pinnedBoardPostId: 'p1' }));
  await assertSucceeds(updateDoc(root, { pinnedBoardPostId: 'p2' }));
  await assertSucceeds(updateDoc(root, { pinnedBoardPostId: null }));
  await assertFails(updateDoc(doc(db(ids.member), 'gubs', 'g1'), { pinnedBoardPostId: 'p1' }));
});

test('member can comment and outsider cannot', async () => {
  const memberDb = db(ids.member);
  const comment = doc(memberDb, 'gubs', 'g1', 'posts', 'p1', 'comments', 'c1');
  const post = doc(memberDb, 'gubs', 'g1', 'posts', 'p1');
  const batch = writeBatch(memberDb);
  batch.set(comment, {
    commentId: 'c1', authorId: ids.member, authorName: ids.member,
    text: 'Hello', createdAt: serverTimestamp(),
  });
  batch.update(post, {
    comments: increment(1), updatedAt: serverTimestamp(),
    lastCommentAuthorId: ids.member, lastCommentId: 'c1',
  });
  await assertSucceeds(batch.commit());

  await assertFails(setDoc(
    doc(db(ids.outsider), 'gubs', 'g1', 'posts', 'p1', 'comments', 'outside'),
    { commentId: 'outside', authorId: ids.outsider, authorName: ids.outsider, text: 'No', createdAt: serverTimestamp() },
  ));
});

test('comment history is bounded by membership joinedAt', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'gubs', 'g1', 'posts', 'p1', 'comments', 'old'), {
      commentId: 'old', authorId: ids.owner, authorName: ids.owner,
      text: 'Old', createdAt: new Date('2025-12-01T00:00:00Z'),
    });
  });
  await assertFails(getDoc(doc(db(ids.member), 'gubs', 'g1', 'posts', 'p1', 'comments', 'old')));
});

test('member can like once and unlike while outsider cannot like', async () => {
  const memberDb = db(ids.member);
  const like = doc(memberDb, 'gubs', 'g1', 'posts', 'p1', 'likes', ids.member);
  const post = doc(memberDb, 'gubs', 'g1', 'posts', 'p1');
  let batch = writeBatch(memberDb);
  batch.set(like, { userId: ids.member, createdAt: serverTimestamp() });
  batch.update(post, { likes: increment(1) });
  await assertSucceeds(batch.commit());

  batch = writeBatch(memberDb);
  batch.set(like, { userId: ids.member, createdAt: serverTimestamp() });
  batch.update(post, { likes: increment(1) });
  await assertFails(batch.commit());

  batch = writeBatch(memberDb);
  batch.delete(like);
  batch.update(post, { likes: increment(-1) });
  await assertSucceeds(batch.commit());
  await assertFails(setDoc(
    doc(db(ids.outsider), 'gubs', 'g1', 'posts', 'p1', 'likes', ids.outsider),
    { userId: ids.outsider, createdAt: serverTimestamp() },
  ));
});

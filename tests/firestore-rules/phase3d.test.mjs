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
  collectionGroup,
  deleteDoc,
  doc,
  documentId,
  getCountFromServer,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-gubify';
const uid = {
  owner: 'owner', member: 'member', second: 'second', outsider: 'outsider',
  otherOwner: 'otherOwner', communityOwner: 'communityOwner', communityMember: 'communityMember',
};
const now = () => new Date('2026-01-01T00:00:00Z');
let env;
const db = (userId) => env.authenticatedContext(userId).firestore();
const tokenId = (id) => id === 'g1' ? 'QUE3D2Q7' : id === 'g2' ? 'QUE3D2Q8' : 'QUE3D2Q9';

const profile = (userId) => ({ displayName: userId, createdAt: now(), updatedAt: now(), activeHub: null, avatar: null });
const member = (userId, role = 'member') => ({ uid: userId, displayName: userId, photoUrl: null, role, joinedAt: now() });
const root = (id, ownerId, count = 1, overrides = {}) => ({ gubId: id, name: id, ownerId, inviteTokenId: tokenId(id), memberCount: count, createdAt: now(), ...overrides });
const task = (gubId, id = 'task1', overrides = {}) => ({
  gubId, taskId: id, title: 'Task', description: '', creatorId: uid.member, creatorName: uid.member,
  assignedUserId: null, assignedUserName: null, sourceType: 'manual', sourceId: null,
  sourcePreview: null, originUserId: null, sourceAuthorName: null, additionalDetails: null,
  status: 'active', priority: 'normal', createdAt: now(), dueDate: null, completedAt: null,
  completedBy: null, notificationsEnabled: true, archived: false, ...overrides,
});
const proposal = (gubId, id = 'proposal1', overrides = {}) => ({
  gubId, proposalId: id, title: 'Proposal', description: 'Description', creatorId: uid.member,
  creatorName: uid.member, status: 'voting', createdAt: now(), expiresAt: new Date('2026-02-01T00:00:00Z'),
  eventDate: new Date('2026-03-01T00:00:00Z'), type: 'custom', yesVotes: 0, noVotes: 0,
  memberCount: 3, resultProcessed: false, eventCreated: false, tasksCreated: false,
  sourceType: 'manual', sourceId: null, sourcePreview: null, originUserId: null, sourceAuthorName: null,
  ...overrides,
});
const goal = (id = 'goal1') => ({ goalId: id, title: id, description: '', targetAmount: 100, currentAmount: 0,
  ownerId: uid.owner, completedMembers: 0, totalMembers: 3, status: 'active', archived: false,
  createdAt: now(), deadline: null, completedAt: null, sourceType: 'manual', sourceId: null,
  sourcePreview: null, originUserId: null, sourceAuthorName: null });

before(async () => {
  env = await initializeTestEnvironment({ projectId, firestore: { rules: readFileSync('firestore.rules', 'utf8') } });
});
after(async () => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const d = context.firestore();
    const batch = writeBatch(d);
    for (const userId of Object.values(uid)) batch.set(doc(d, 'users', userId), profile(userId));
    batch.set(doc(d, 'gubs', 'g1'), root('g1', uid.owner, 3));
    batch.set(doc(d, 'inviteTokens', tokenId('g1')), { gubId: 'g1', ownerId: uid.owner, gubName: 'g1', active: true, createdAt: now() });
    for (const userId of [uid.owner, uid.member, uid.second]) {
      const role = userId === uid.owner ? 'owner' : 'member';
      batch.set(doc(d, 'gubs', 'g1', 'members', userId), member(userId, role));
      batch.set(doc(d, 'users', userId, 'gubs', 'g1'), { gubId: 'g1', name: 'g1', ownerId: uid.owner, role, joinedAt: now() });
    }
    batch.set(doc(d, 'gubs', 'g2'), root('g2', uid.otherOwner, 2));
    batch.set(doc(d, 'inviteTokens', tokenId('g2')), { gubId: 'g2', ownerId: uid.otherOwner, gubName: 'g2', active: true, createdAt: now() });
    for (const userId of [uid.otherOwner, uid.member]) batch.set(doc(d, 'gubs', 'g2', 'members', userId), member(userId, userId === uid.otherOwner ? 'owner' : 'member'));
    batch.set(doc(d, 'users', uid.member, 'gubs', 'g2'), { gubId: 'g2', name: 'g2', ownerId: uid.otherOwner, role: 'member', joinedAt: now() });
    batch.set(doc(d, 'gubs', 'g3'), root('g3', uid.outsider));
    batch.set(doc(d, 'inviteTokens', tokenId('g3')), { gubId: 'g3', ownerId: uid.outsider, gubName: 'g3', active: true, createdAt: now() });
    batch.set(doc(d, 'gubs', 'g3', 'members', uid.outsider), member(uid.outsider, 'owner'));

    batch.set(doc(d, 'communities', 'c1'), { communityId: 'c1', name: 'Public', ownerId: uid.communityOwner, memberCount: 2, visibility: 'public', createdAt: now(), type: 'General', language: 'English', description: '' });
    batch.set(doc(d, 'communities', 'c1', 'members', uid.communityOwner), member(uid.communityOwner, 'owner'));
    batch.set(doc(d, 'communities', 'c1', 'members', uid.communityMember), member(uid.communityMember));
    batch.set(doc(d, 'communities', 'c2'), { communityId: 'c2', name: 'Legacy private', ownerId: uid.communityOwner, memberCount: 1, visibility: 'private', createdAt: now() });
    batch.set(doc(d, 'communities', 'c2', 'members', uid.communityOwner), member(uid.communityOwner, 'owner'));
    batch.set(doc(d, 'communityOwnership', uid.communityOwner), { ownerId: uid.communityOwner, communityId: 'c1', createdAt: now() });

    batch.set(doc(d, 'gubs', 'g1', 'messages', 'm1'), { messageId: 'm1', gubId: 'g1', senderId: uid.member, senderName: uid.member, text: 'G1 message', createdAt: now() });
    batch.set(doc(d, 'gubs', 'g2', 'messages', 'm2'), { messageId: 'm2', gubId: 'g2', senderId: uid.member, senderName: uid.member, text: 'G2 message', createdAt: now() });
    batch.set(doc(d, 'gubs', 'g1', 'posts', 'post1'), { gubId: 'g1', authorId: uid.member, authorName: uid.member, authorPhoto: null, message: 'Post', likes: 0, comments: 0, createdAt: now(), updatedAt: now() });
    batch.set(doc(d, 'gubs', 'g1', 'posts', 'post1', 'comments', 'comment1'), { commentId: 'comment1', authorId: uid.member, authorName: uid.member, text: 'Comment', createdAt: now() });
    batch.set(doc(d, 'gubs', 'g1', 'posts', 'post1', 'likes', uid.member), { userId: uid.member, createdAt: now() });
    batch.set(doc(d, 'gubs', 'g1', 'tasks', 'task1'), task('g1'));
    batch.set(doc(d, 'gubs', 'g2', 'tasks', 'foreignTask'), task('g2', 'foreignTask'));
    batch.set(doc(d, 'gubs', 'g1', 'events', 'event1'), { gubId: 'g1', eventId: 'event1', proposalId: 'proposal1', title: 'Proposal', description: 'Description', type: 'custom', creatorId: uid.member, creatorName: uid.member, eventDate: new Date('2026-03-01T00:00:00Z'), createdAt: now(), status: 'scheduled' });
    batch.set(doc(d, 'gubs', 'g1', 'organizedEvents', 'organized1'), { eventId: 'organized1', gubId: 'g1', title: 'Organized', description: null, location: null, scheduledAt: null, createdBy: uid.member, createdByName: uid.member, createdAt: now(), status: 'active', completedAt: null, sourceType: 'manual', sourceId: null, sourcePreview: null, originUserId: null, sourceAuthorName: null, assignments: [{ userId: uid.second, userName: uid.second, taskText: 'Work', isCompleted: false, completedAt: null }], assignmentUserIds: [uid.second] });
    batch.set(doc(d, 'gubs', 'g1', 'proposals', 'proposal1'), proposal('g1', 'proposal1', { status: 'approved', yesVotes: 3, resultProcessed: true }));
    batch.set(doc(d, 'gubs', 'g1', 'proposals', 'proposal1', 'votes', uid.member), { uid: uid.member, vote: 'yes', votedAt: now() });
    batch.set(doc(d, 'gubs', 'g1', 'goals', 'goal1'), goal());
    batch.set(doc(d, 'gubs', 'g1', 'goals', 'goal1', 'members', uid.member), { uid: uid.member, displayName: uid.member, photoUrl: null, amount: 10, confirmed: true, updatedAt: now(), confirmedAt: now() });
    batch.set(doc(d, 'gubs', 'g1', 'notifications', 'notification1'), { notificationId: 'notification1', title: 'Task', body: 'Created', type: 'task_created', senderId: uid.member, senderName: uid.member, createdAt: now(), readBy: [uid.member], data: { module: 'tasks', gubId: 'g1', taskId: 'task1' } });
    batch.set(doc(d, 'gubs', 'g1', 'creationCooldowns', `${uid.member}_task`), { creatorId: uid.member, moduleType: 'task', deletedItemId: 'old', deletedBy: uid.member, deletedAt: now(), availableAt: now() });
    batch.set(doc(d, 'communities', 'c1', 'messages', 'cm1'), { messageId: 'cm1', communityId: 'c1', senderId: uid.communityMember, senderName: uid.communityMember, text: 'Community', createdAt: now() });
    batch.set(doc(d, 'communities', 'c1', 'asks', 'ask1'), { askId: 'ask1', communityId: 'c1', authorId: uid.communityOwner, authorDisplayName: uid.communityOwner, type: 'help', text: 'Ask', createdAt: now(), status: 'resolved', bestAnswerId: uid.communityMember, bestAnswerAuthorId: uid.communityMember, resolvedAt: now(), xpAwarded: true });
    batch.set(doc(d, 'communities', 'c1', 'asks', 'ask1', 'answers', uid.communityMember), { answerId: uid.communityMember, authorId: uid.communityMember, authorDisplayName: uid.communityMember, text: 'Answer', createdAt: now() });
    await batch.commit();
  });
});

describe('real query compatibility', () => {
  test('owner count query works only for the matching owner', async () => {
    await assertSucceeds(getCountFromServer(query(collection(db(uid.owner), 'gubs'), where('ownerId', '==', uid.owner))));
    await assertFails(getCountFromServer(query(collection(db(uid.outsider), 'gubs'), where('ownerId', '==', uid.owner))));
  });
  test('My Gubs whereIn enrichment allows only a fully authorized result set', async () => {
    await assertSucceeds(getDocs(query(collection(db(uid.member), 'gubs'), where(documentId(), 'in', ['g1', 'g2']))));
    await assertFails(getDocs(query(collection(db(uid.member), 'gubs'), where(documentId(), 'in', ['g1', 'g3']))));
  });
  test('private inviteTokenId discovery remains denied to a non-member', async () => {
    await assertFails(getDocs(query(collection(db(uid.outsider), 'gubs'), where('inviteTokenId', '==', tokenId('g1')), limit(1))));
  });
  test('Community public discovery and owner queries work, while an unconstrained mixed query fails', async () => {
    await assertSucceeds(getDocs(query(collection(db(uid.outsider), 'communities'), where('visibility', '==', 'public'))));
    await assertSucceeds(getDocs(query(collection(db(uid.communityOwner), 'communities'), where('ownerId', '==', uid.communityOwner), limit(1))));
    await assertFails(getDocs(collection(db(uid.outsider), 'communities')));
  });
  test('real ordered module lists work for members and fail for outsiders', async () => {
    const memberDb = db(uid.member); const outsiderDb = db(uid.outsider);
    for (const [name, constraints] of [
      ['messages', [where('createdAt', '>=', now()), orderBy('createdAt', 'desc'), limit(50)]], ['posts', [orderBy('createdAt', 'desc'), limit(25)]],
      ['tasks', [orderBy('createdAt', 'desc')]], ['events', [orderBy('eventDate')]],
      ['organizedEvents', [orderBy('createdAt', 'desc')]], ['proposals', [orderBy('createdAt', 'desc')]],
    ]) {
      await assertSucceeds(getDocs(query(collection(memberDb, 'gubs', 'g1', name), ...constraints)));
      await assertFails(getDocs(query(collection(outsiderDb, 'gubs', 'g1', name), ...constraints)));
    }
  });
  test('filtered cooldown checks and active-creator queries match the client', async () => {
    await assertSucceeds(getDocs(query(collection(db(uid.member), 'gubs', 'g1', 'tasks'), where('creatorId', '==', uid.member), where('status', '==', 'active'), limit(1))));
    await assertSucceeds(getDocs(query(collection(db(uid.member), 'gubs', 'g1', 'organizedEvents'), where('createdBy', '==', uid.member), where('status', '==', 'active'), limit(1))));
    await assertSucceeds(getDocs(query(collection(db(uid.member), 'gubs', 'g1', 'creationCooldowns'), where('creatorId', '==', uid.member))));
  });
  test('member, vote, budget-member, notification, and Community-chat list queries work', async () => {
    await assertSucceeds(getDocs(query(collection(db(uid.member), 'gubs', 'g1', 'members'), orderBy('joinedAt'))));
    await assertSucceeds(getDocs(collection(db(uid.member), 'gubs', 'g1', 'proposals', 'proposal1', 'votes')));
    await assertSucceeds(getDocs(collection(db(uid.member), 'gubs', 'g1', 'goals', 'goal1', 'members')));
    await assertSucceeds(getDocs(query(collection(db(uid.member), 'gubs', 'g1', 'notifications'), where('createdAt', '>=', now()), orderBy('createdAt', 'desc'))));
    await assertSucceeds(getDocs(query(collection(db(uid.communityMember), 'communities', 'c1', 'messages'), where('createdAt', '>=', now()), orderBy('createdAt', 'desc'), limit(50))));
  });
});

describe('cross-module and cross-resource isolation', () => {
  test('Gub and Community memberships never grant each other access', async () => {
    await assertFails(getDocs(collection(db(uid.communityMember), 'gubs', 'g1', 'tasks')));
    await assertFails(getDocs(collection(db(uid.member), 'communities', 'c1', 'messages')));
  });
  test('personal copies and forged role fields are not authorization evidence', async () => {
    await env.withSecurityRulesDisabled((context) => setDoc(doc(context.firestore(), 'users', uid.outsider, 'gubs', 'g1'), { gubId: 'g1', ownerId: uid.outsider, role: 'owner' }));
    await assertFails(getDocs(collection(db(uid.outsider), 'gubs', 'g1', 'tasks')));
    await assertFails(deleteDoc(doc(db(uid.outsider), 'gubs', 'g1')));
  });
  test('chat source IDs cannot cross Gub boundaries', async () => {
    await assertFails(setDoc(doc(db(uid.member), 'gubs', 'g1', 'tasks', 'cross-source'), task('g1', 'cross-source', { sourceType: 'chat', sourceId: 'm2', sourcePreview: 'G2 message', originUserId: uid.member, sourceAuthorName: uid.member, additionalDetails: null })));
  });
  test('a Task cannot authorize another notification type or a foreign-Gub resource', async () => {
    const base = { notificationId: 'bad', title: 'Bad', body: 'Bad', senderId: uid.member, senderName: uid.member, createdAt: now(), readBy: [uid.member] };
    await assertFails(setDoc(doc(db(uid.member), 'gubs', 'g1', 'notifications', 'bad'), { ...base, type: 'task_completed', data: { module: 'tasks', gubId: 'g1', taskId: 'task1' } }));
    await assertFails(setDoc(doc(db(uid.member), 'gubs', 'g1', 'notifications', 'foreign'), { ...base, notificationId: 'foreign', type: 'task_created', data: { module: 'tasks', gubId: 'g2', taskId: 'foreignTask' } }));
  });
  test('Proposal-derived Calendar data cannot be substituted', async () => {
    await assertFails(setDoc(doc(db(uid.member), 'gubs', 'g1', 'events', 'forged'), { gubId: 'g1', eventId: 'forged', proposalId: 'proposal1', title: 'Different', description: 'Description', type: 'custom', creatorId: uid.member, creatorName: uid.member, eventDate: new Date('2026-03-01T00:00:00Z'), createdAt: now(), status: 'scheduled' }));
  });
  test('vote aggregate updates cannot carry unrelated Proposal changes', async () => {
    await assertFails(updateDoc(doc(db(uid.member), 'gubs', 'g1', 'proposals', 'proposal1'), { yesVotes: 4, noVotes: 0, title: 'Hijacked' }));
  });
  test('Goal contribution identity and path cannot be borrowed from another resource', async () => {
    await assertFails(updateDoc(doc(db(uid.second), 'gubs', 'g1', 'goals', 'goal1', 'members', uid.member), { amount: 50, updatedAt: now() }));
    await assertFails(updateDoc(doc(db(uid.member), 'gubs', 'g1', 'goals', 'missing', 'members', uid.member), { amount: 50, updatedAt: now() }));
  });
  test('deletion and ownership markers are isolated to their exact root', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'gubs', 'g1'), { deletionStatus: 'deleting', deletionRequestedBy: uid.owner, deletionStartedAt: now(), deletionUpdatedAt: now(), deletionPhase: 'preparing' });
      await setDoc(doc(context.firestore(), 'communityOwnership', uid.outsider), { ownerId: uid.outsider, communityId: 'c1', createdAt: now() });
    });
    await assertFails(deleteDoc(doc(db(uid.owner), 'gubs', 'g2', 'tasks', 'foreignTask')));
    await assertFails(deleteDoc(doc(db(uid.outsider), 'communities', 'c1')));
  });
});

describe('account deletion personal-data cleanup', () => {
  const deletionState = (userId) => ({ userId, status: 'deleting', startedAt: serverTimestamp() });

  test('deletion state can list only its own Community join requests', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const d = context.firestore();
      await setDoc(doc(d, 'communities', 'c1', 'joinRequests', uid.member), {
        userId: uid.member, displayName: uid.member, status: 'rejected', createdAt: now(),
      });
      await setDoc(doc(d, 'communities', 'c2', 'joinRequests', uid.member), {
        userId: uid.member, displayName: uid.member, status: 'approved', createdAt: now(),
      });
      await setDoc(doc(d, 'communities', 'c1', 'joinRequests', uid.second), {
        userId: uid.second, displayName: uid.second, status: 'pending', createdAt: now(),
      });
    });

    const ownDb = db(uid.member);
    const ownRequests = query(
      collectionGroup(ownDb, 'joinRequests'),
      where('userId', '==', uid.member),
    );
    await assertFails(getDocs(ownRequests));
    await assertSucceeds(setDoc(
      doc(ownDb, 'accountDeletionStates', uid.member),
      deletionState(uid.member),
    ));
    const snapshot = await assertSucceeds(getDocs(ownRequests));
    assert.equal(snapshot.size, 2);
    assert.ok(snapshot.docs.every((request) => request.data().userId === uid.member));

    const outsiderTargetQuery = query(
      collectionGroup(db(uid.outsider), 'joinRequests'),
      where('userId', '==', uid.member),
    );
    await assertFails(getDocs(outsiderTargetQuery));
    await assertFails(getDocs(collectionGroup(ownDb, 'joinRequests')));
  });

  test('normal accounts cannot self-anonymize identity fields', async () => {
    const memberDb = db(uid.member);
    await assertFails(updateDoc(doc(memberDb, 'gubs', 'g1', 'messages', 'm1'), {
      senderId: '__deleted_user__', senderName: 'Deleted user',
    }));
    await assertFails(updateDoc(doc(memberDb, 'gubs', 'g1', 'posts', 'post1', 'comments', 'comment1'), {
      authorId: '__deleted_user__', authorName: 'Deleted user',
    }));
    const communityDb = db(uid.communityMember);
    await assertFails(updateDoc(doc(communityDb, 'communities', 'c1', 'messages', 'cm1'), {
      senderId: '__deleted_user__', senderName: 'Deleted user',
    }));
  });

  test('anonymizes authored Gub comments and Community Ask history', async () => {
    const memberDb = db(uid.member);
    await assertSucceeds(setDoc(doc(memberDb, 'accountDeletionStates', uid.member), deletionState(uid.member)));
    await assertSucceeds(getDocs(query(collectionGroup(memberDb, 'comments'), where('authorId', '==', uid.member))));
    await assertSucceeds(updateDoc(doc(memberDb, 'gubs', 'g1', 'posts', 'post1', 'comments', 'comment1'), {
      authorId: '__deleted_user__', authorName: 'Deleted user',
    }));

    const ownerDb = db(uid.communityOwner);
    await assertSucceeds(setDoc(doc(ownerDb, 'accountDeletionStates', uid.communityOwner), deletionState(uid.communityOwner)));
    await assertSucceeds(getDocs(query(collectionGroup(ownerDb, 'asks'), where('authorId', '==', uid.communityOwner))));
    await assertSucceeds(updateDoc(doc(ownerDb, 'communities', 'c1', 'asks', 'ask1'), {
      authorId: '__deleted_user__', authorDisplayName: 'Deleted user',
    }));

    const communityDb = db(uid.communityMember);
    await assertSucceeds(getDocs(query(collectionGroup(communityDb, 'answers'), where('authorId', '==', uid.communityMember))));
    await assertSucceeds(setDoc(doc(communityDb, 'accountDeletionStates', uid.communityMember), deletionState(uid.communityMember)));
    const replacementId = 'anonymous-answer';
    await assertSucceeds(updateDoc(doc(communityDb, 'communities', 'c1', 'asks', 'ask1', 'answers', uid.communityMember), {
      deletionReplacementAnswerId: replacementId,
    }));
    const migration = writeBatch(communityDb);
    migration.set(doc(communityDb, 'communities', 'c1', 'asks', 'ask1', 'answers', replacementId), {
      answerId: replacementId, authorId: '__deleted_user__', authorDisplayName: 'Deleted user', text: 'Answer', createdAt: now(),
    });
    migration.update(doc(communityDb, 'communities', 'c1', 'asks', 'ask1'), {
      bestAnswerId: replacementId, bestAnswerAuthorId: '__deleted_user__',
    });
    migration.delete(doc(communityDb, 'communities', 'c1', 'asks', 'ask1', 'answers', uid.communityMember));
    await assertSucceeds(migration.commit());
    const askAfter = (await getDoc(doc(communityDb, 'communities', 'c1', 'asks', 'ask1'))).data();
    assert.equal(askAfter.bestAnswerId, replacementId);
    assert.equal(askAfter.bestAnswerAuthorId, '__deleted_user__');
    assert.equal((await getDoc(doc(communityDb, 'communities', 'c1', 'asks', 'ask1', 'answers', uid.communityMember))).exists(), false);
  });

  test('profile absence alone never unlocks detached identity cleanup', async () => {
    const memberDb = db(uid.member);
    const like = doc(memberDb, 'gubs', 'g1', 'posts', 'post1', 'likes', uid.member);
    const vote = doc(memberDb, 'gubs', 'g1', 'proposals', 'proposal1', 'votes', uid.member);
    const contribution = doc(memberDb, 'gubs', 'g1', 'goals', 'goal1', 'members', uid.member);

    await assertFails(deleteDoc(like));
    await assertFails(deleteDoc(vote));
    await assertFails(deleteDoc(contribution));
    await assertSucceeds(deleteDoc(doc(memberDb, 'users', uid.member)));
    await assertFails(deleteDoc(like));
    await assertFails(deleteDoc(vote));
    await assertFails(deleteDoc(contribution));
  });

  test('irreversible deletion state unlocks cleanup only after profile deletion', async () => {
    const memberDb = db(uid.member);
    const state = doc(memberDb, 'accountDeletionStates', uid.member);
    await assertSucceeds(setDoc(state, deletionState(uid.member)));
    await assertFails(deleteDoc(state));
    await assertSucceeds(deleteDoc(doc(memberDb, 'users', uid.member)));
    await assertFails(setDoc(doc(memberDb, 'users', uid.member), profile(uid.member)));
    await assertSucceeds(deleteDoc(doc(memberDb, 'gubs', 'g1', 'posts', 'post1', 'likes', uid.member)));
    await assertSucceeds(deleteDoc(doc(memberDb, 'gubs', 'g1', 'proposals', 'proposal1', 'votes', uid.member)));
    await assertSucceeds(deleteDoc(doc(memberDb, 'gubs', 'g1', 'goals', 'goal1', 'members', uid.member)));
  });

  test('deletion repository detached identity queries remain identity scoped', async () => {
    const memberDb = db(uid.member);
    await assertSucceeds(setDoc(
      doc(memberDb, 'accountDeletionStates', uid.member),
      deletionState(uid.member),
    ));
    await assertSucceeds(deleteDoc(doc(memberDb, 'users', uid.member)));

    for (const [group, field] of [
      ['likes', 'userId'],
      ['votes', 'uid'],
      ['members', 'uid'],
    ]) {
      const ownDocuments = query(
        collectionGroup(memberDb, group),
        where(field, '==', uid.member),
        orderBy(documentId()),
        limit(300),
      );
      const snapshot = await assertSucceeds(getDocs(ownDocuments));
      assert.ok(snapshot.docs.every((document) => document.data()[field] === uid.member));
      await assertFails(getDocs(collectionGroup(memberDb, group)));

      const outsiderTargetQuery = query(
        collectionGroup(db(uid.outsider), group),
        where(field, '==', uid.member),
        orderBy(documentId()),
        limit(300),
      );
      await assertFails(getDocs(outsiderTargetQuery));
    }
  });

  test('deletion state blocks new likes and votes', async () => {
    const memberDb = db(uid.second);
    await assertSucceeds(setDoc(doc(memberDb, 'accountDeletionStates', uid.second), deletionState(uid.second)));
    const likeBatch = writeBatch(memberDb);
    likeBatch.update(doc(memberDb, 'gubs', 'g1', 'posts', 'post1'), { likes: 1 });
    likeBatch.set(doc(memberDb, 'gubs', 'g1', 'posts', 'post1', 'likes', uid.second), { userId: uid.second, createdAt: now() });
    await assertFails(likeBatch.commit());
    const voteBatch = writeBatch(memberDb);
    voteBatch.update(doc(memberDb, 'gubs', 'g1', 'proposals', 'proposal1'), { yesVotes: 4 });
    voteBatch.set(doc(memberDb, 'gubs', 'g1', 'proposals', 'proposal1', 'votes', uid.second), { uid: uid.second, vote: 'yes', votedAt: now() });
    await assertFails(voteBatch.commit());
    await assertFails(setDoc(doc(memberDb, 'gubs', 'g1', 'messages', 'late-message'), {
      messageId: 'late-message', gubId: 'g1', senderId: uid.second, senderName: uid.second, text: 'Too late', createdAt: now(),
    }));

    assert.equal((await getDoc(doc(memberDb, 'gubs', 'g1', 'posts', 'post1'))).data().likes, 0);
    assert.equal((await getDoc(doc(memberDb, 'gubs', 'g1', 'proposals', 'proposal1'))).data().yesVotes, 3);
    assert.equal((await getDoc(doc(memberDb, 'gubs', 'g1', 'goals', 'goal1'))).data().currentAmount, 0);
  });

  test('deletion state disables Platform Admin authority', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'platformAdmins', uid.member), { active: true });
    });
    const memberDb = db(uid.member);
    await assertSucceeds(setDoc(doc(memberDb, 'accountDeletionStates', uid.member), deletionState(uid.member)));
    await assertFails(updateDoc(doc(memberDb, 'communities', 'c1', 'asks', 'ask1'), {
      moderationHidden: true, moderatedBy: uid.member, moderatedAt: now(),
    }));
  });

  test('stale copies permit only exact authored-content anonymization', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const d = context.firestore();
      await deleteDoc(doc(d, 'gubs', 'g1', 'members', uid.member));
      await deleteDoc(doc(d, 'communities', 'c1', 'members', uid.communityMember));
    });
    const gubDb = db(uid.member);
    await assertSucceeds(setDoc(doc(gubDb, 'accountDeletionStates', uid.member), deletionState(uid.member)));
    await assertSucceeds(getDocs(query(collection(gubDb, 'gubs', 'g1', 'messages'), where('senderId', '==', uid.member))));
    await assertSucceeds(updateDoc(doc(gubDb, 'gubs', 'g1', 'messages', 'm1'), {
      senderId: '__deleted_user__', senderName: 'Deleted user',
    }));

    const communityDb = db(uid.communityMember);
    await assertSucceeds(setDoc(doc(communityDb, 'accountDeletionStates', uid.communityMember), deletionState(uid.communityMember)));
    await assertSucceeds(getDocs(query(collection(communityDb, 'communities', 'c1', 'messages'), where('senderId', '==', uid.communityMember))));
    await assertSucceeds(updateDoc(doc(communityDb, 'communities', 'c1', 'messages', 'cm1'), {
      senderId: '__deleted_user__', senderName: 'Deleted user',
    }));
    await assertFails(getDocs(collection(communityDb, 'communities', 'c1', 'messages')));
  });

  test('deletion state blocks task completion and notification reads', async () => {
    const memberDb = db(uid.member);
    await assertSucceeds(setDoc(doc(memberDb, 'accountDeletionStates', uid.member), deletionState(uid.member)));
    await assertFails(updateDoc(doc(memberDb, 'gubs', 'g1', 'tasks', 'task1'), {
      status: 'completed', completedAt: now(), completedBy: uid.member,
    }));
    await assertFails(updateDoc(doc(memberDb, 'gubs', 'g1', 'notifications', 'notification1'), {
      readBy: [uid.member, uid.second],
    }));
  });

  test('deletion state can remove an active Community Ask slot', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const d = context.firestore();
      await setDoc(doc(d, 'communities', 'c1', 'activeAskSlots', uid.communityMember), {
        askId: 'active-ask', authorId: uid.communityMember, createdAt: now(),
      });
      await setDoc(doc(d, 'communities', 'c1', 'asks', 'active-ask'), {
        askId: 'active-ask', communityId: 'c1', authorId: uid.communityMember,
        authorDisplayName: uid.communityMember, type: 'help', text: 'Active',
        createdAt: now(), status: 'active',
      });
    });
    const memberDb = db(uid.communityMember);
    await assertSucceeds(setDoc(doc(memberDb, 'accountDeletionStates', uid.communityMember), deletionState(uid.communityMember)));
    await assertSucceeds(deleteDoc(doc(memberDb, 'communities', 'c1', 'activeAskSlots', uid.communityMember)));
  });

  test('deletion state discovers only its orphan Community Ask slots', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const d = context.firestore();
      await deleteDoc(doc(d, 'communities', 'c1', 'members', uid.communityMember));
      await deleteDoc(doc(d, 'users', uid.communityMember, 'communities', 'c1'));
      await setDoc(doc(d, 'communities', 'c1', 'activeAskSlots', uid.communityMember), {
        askId: 'orphan-active', authorId: uid.communityMember, createdAt: now(),
      });
      await setDoc(doc(d, 'communities', 'c1', 'activeAskSlots', uid.second), {
        askId: 'other-active', authorId: uid.second, createdAt: now(),
      });
    });
    const memberDb = db(uid.communityMember);
    await assertSucceeds(setDoc(doc(memberDb, 'accountDeletionStates', uid.communityMember), deletionState(uid.communityMember)));
    const ownSlots = query(collectionGroup(memberDb, 'activeAskSlots'), where('authorId', '==', uid.communityMember));
    const snapshot = await assertSucceeds(getDocs(ownSlots));
    assert.equal(snapshot.size, 1);
    await assertFails(getDocs(collectionGroup(memberDb, 'activeAskSlots')));
    await assertSucceeds(deleteDoc(snapshot.docs[0].ref));
    assert.equal((await getDocs(ownSlots)).empty, true);
  });

  test('stale assignee-only organized events remain identity scoped and retryable', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const d = context.firestore();
      await deleteDoc(doc(d, 'gubs', 'g1', 'members', uid.member));
      await setDoc(doc(d, 'gubs', 'g1', 'organizedEvents', 'assigned-only'), {
        eventId: 'assigned-only', gubId: 'g1', title: 'Assigned', createdBy: uid.second,
        createdByName: uid.second, originUserId: null, sourceAuthorName: null,
        assignments: [{ userId: uid.member, userName: uid.member, taskText: 'Keep', isCompleted: false, completedAt: null }],
        assignmentUserIds: [uid.member], status: 'active', createdAt: now(),
      });
    });
    const memberDb = db(uid.member);
    await assertSucceeds(setDoc(doc(memberDb, 'accountDeletionStates', uid.member), deletionState(uid.member)));
    const ownAssignments = query(collection(memberDb, 'gubs', 'g1', 'organizedEvents'), where('assignmentUserIds', 'array-contains', uid.member));
    const snapshot = await assertSucceeds(getDocs(ownAssignments));
    assert.equal(snapshot.size, 1);
    await assertFails(getDocs(collection(memberDb, 'gubs', 'g1', 'organizedEvents')));
    await assertSucceeds(updateDoc(snapshot.docs[0].ref, {
      assignments: [{ userId: '__deleted_user__', userName: 'Deleted user', taskText: 'Keep', isCompleted: false, completedAt: null }],
      assignmentUserIds: ['__deleted_user__'],
    }));
    assert.equal((await getDocs(ownAssignments)).empty, true);
  });

  test('current member can migrate a legacy assignee-only Organized Event', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'gubs', 'g1', 'organizedEvents', 'legacy-assignment'), {
        eventId: 'legacy-assignment', gubId: 'g1', title: 'Legacy assignment',
        createdBy: uid.second, createdByName: uid.second, originUserId: null,
        sourceAuthorName: null,
        assignments: [{ userId: uid.member, userName: uid.member, taskText: 'Keep', isCompleted: false, completedAt: null }],
        status: 'active', createdAt: now(),
      });
    });
    const memberDb = db(uid.member);
    await assertSucceeds(setDoc(doc(memberDb, 'accountDeletionStates', uid.member), deletionState(uid.member)));
    const events = await assertSucceeds(getDocs(collection(memberDb, 'gubs', 'g1', 'organizedEvents')));
    const legacy = events.docs.find((event) => event.id === 'legacy-assignment');
    assert.ok(legacy);
    await assertSucceeds(updateDoc(legacy.ref, {
      assignments: [{ userId: '__deleted_user__', userName: 'Deleted user', taskText: 'Keep', isCompleted: false, completedAt: null }],
      assignmentUserIds: ['__deleted_user__'],
    }));
    const migrated = await getDoc(legacy.ref);
    assert.deepEqual(migrated.data().assignmentUserIds, ['__deleted_user__']);
    assert.equal(migrated.data().assignments[0].userId, '__deleted_user__');
  });

  test('stale Community Answer migration can read only its Best Answer Ask', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const d = context.firestore();
      await deleteDoc(doc(d, 'communities', 'c1', 'members', uid.communityMember));
      await deleteDoc(doc(d, 'users', uid.communityMember, 'communities', 'c1'));
      await setDoc(doc(d, 'communities', 'c1', 'asks', 'unrelated'), {
        askId: 'unrelated', communityId: 'c1', authorId: uid.second,
        authorDisplayName: uid.second, type: 'help', text: 'Unrelated',
        createdAt: now(), status: 'active',
      });
    });
    const memberDb = db(uid.communityMember);
    await assertSucceeds(setDoc(doc(memberDb, 'accountDeletionStates', uid.communityMember), deletionState(uid.communityMember)));
    const ownAnswers = query(collectionGroup(memberDb, 'answers'), where('authorId', '==', uid.communityMember));
    assert.equal((await getDocs(ownAnswers)).size, 1);
    const bestAsks = query(collectionGroup(memberDb, 'asks'), where('bestAnswerAuthorId', '==', uid.communityMember));
    assert.equal((await getDocs(bestAsks)).size, 1);
    await assertFails(getDoc(doc(memberDb, 'communities', 'c1', 'asks', 'unrelated')));

    const oldAnswer = doc(memberDb, 'communities', 'c1', 'asks', 'ask1', 'answers', uid.communityMember);
    const replacementId = 'stale-anonymous-answer';
    await assertSucceeds(updateDoc(oldAnswer, { deletionReplacementAnswerId: replacementId }));
    const migration = writeBatch(memberDb);
    migration.set(doc(memberDb, 'communities', 'c1', 'asks', 'ask1', 'answers', replacementId), {
      answerId: replacementId, authorId: '__deleted_user__', authorDisplayName: 'Deleted user', text: 'Answer', createdAt: now(),
    });
    migration.update(doc(memberDb, 'communities', 'c1', 'asks', 'ask1'), {
      bestAnswerId: replacementId, bestAnswerAuthorId: '__deleted_user__',
    });
    migration.delete(oldAnswer);
    await assertSucceeds(migration.commit());
    assert.equal((await getDocs(ownAnswers)).empty, true);
  });

  test('secondary UID references are anonymized without changing history', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const d = context.firestore();
      await updateDoc(doc(d, 'gubs', 'g1', 'posts', 'post1'), {
        lastCommentAuthorId: uid.member, lastCommentId: 'comment1',
      });
      await updateDoc(doc(d, 'gubs', 'g1', 'proposals', 'proposal1'), {
        deletedBy: uid.member, deletedAt: now(), status: 'deleted',
      });
      await setDoc(doc(d, 'gubs', 'g1', 'notifications', 'goal-member'), {
        notificationId: 'goal-member', title: 'Goal', body: 'Submitted',
        type: 'goal_submitted', senderId: uid.second, senderName: uid.second,
        createdAt: now(), readBy: [],
        data: { goalId: 'goal1', memberId: uid.member, amount: 10 },
      });
    });
    const memberDb = db(uid.member);
    await assertSucceeds(setDoc(doc(memberDb, 'accountDeletionStates', uid.member), deletionState(uid.member)));
    await assertSucceeds(updateDoc(doc(memberDb, 'gubs', 'g1', 'posts', 'post1'), {
      lastCommentAuthorId: '__deleted_user__',
    }));
    await assertSucceeds(updateDoc(doc(memberDb, 'gubs', 'g1', 'proposals', 'proposal1'), {
      deletedBy: '__deleted_user__',
    }));
    await assertSucceeds(updateDoc(doc(memberDb, 'gubs', 'g1', 'creationCooldowns', `${uid.member}_task`), {
      creatorId: '__deleted_user__', deletedBy: '__deleted_user__',
    }));
    await assertSucceeds(updateDoc(doc(memberDb, 'gubs', 'g1', 'notifications', 'goal-member'), {
      data: { goalId: 'goal1', memberId: '__deleted_user__', amount: 10 },
    }));
    const postAfter = (await getDoc(doc(memberDb, 'gubs', 'g1', 'posts', 'post1'))).data();
    assert.equal(postAfter.comments, 0);
    assert.equal(postAfter.message, 'Post');
    const proposalAfter = (await getDoc(doc(memberDb, 'gubs', 'g1', 'proposals', 'proposal1'))).data();
    assert.equal(proposalAfter.resultProcessed, true);
    assert.equal(proposalAfter.title, 'Proposal');
  });

  test('moderated Answer migration preserves moderation fields exactly', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'communities', 'c1', 'asks', 'ask1', 'answers', uid.communityMember), {
        moderationHidden: true, moderatedBy: uid.communityOwner, moderatedAt: now(),
      });
    });
    const memberDb = db(uid.communityMember);
    await assertSucceeds(setDoc(doc(memberDb, 'accountDeletionStates', uid.communityMember), deletionState(uid.communityMember)));
    const replacementId = 'moderated-anonymous-answer';
    await assertSucceeds(updateDoc(doc(memberDb, 'communities', 'c1', 'asks', 'ask1', 'answers', uid.communityMember), {
      deletionReplacementAnswerId: replacementId,
    }));
    const migration = writeBatch(memberDb);
    migration.set(doc(memberDb, 'communities', 'c1', 'asks', 'ask1', 'answers', replacementId), {
      answerId: replacementId, authorId: '__deleted_user__', authorDisplayName: 'Deleted user',
      text: 'Answer', createdAt: now(), moderationHidden: true,
      moderatedBy: uid.communityOwner, moderatedAt: now(),
    });
    migration.update(doc(memberDb, 'communities', 'c1', 'asks', 'ask1'), {
      bestAnswerId: replacementId, bestAnswerAuthorId: '__deleted_user__',
    });
    migration.delete(doc(memberDb, 'communities', 'c1', 'asks', 'ask1', 'answers', uid.communityMember));
    await assertSucceeds(migration.commit());

    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'communities', 'c1', 'asks', 'forged', 'answers', uid.second), {
        answerId: uid.second, authorId: uid.second, authorDisplayName: uid.second,
        text: 'Answer', createdAt: now(), moderationHidden: true,
        moderatedBy: uid.owner, moderatedAt: now(), deletionReplacementAnswerId: 'forged-replacement',
      });
    });
    const secondDb = db(uid.second);
    await assertSucceeds(setDoc(doc(secondDb, 'accountDeletionStates', uid.second), deletionState(uid.second)));
    const forged = writeBatch(secondDb);
    forged.set(doc(secondDb, 'communities', 'c1', 'asks', 'forged', 'answers', 'forged-replacement'), {
      answerId: 'forged-replacement', authorId: '__deleted_user__', authorDisplayName: 'Deleted user',
      text: 'Answer', createdAt: now(), moderationHidden: false,
      moderatedBy: uid.second, moderatedAt: now(),
    });
    forged.delete(doc(secondDb, 'communities', 'c1', 'asks', 'forged', 'answers', uid.second));
    await assertFails(forged.commit());
  });
});

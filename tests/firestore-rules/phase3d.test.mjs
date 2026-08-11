import { after, before, beforeEach, describe, test } from 'node:test';
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
  documentId,
  getCountFromServer,
  getDocs,
  limit,
  orderBy,
  query,
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
    batch.set(doc(d, 'gubs', 'g1', 'tasks', 'task1'), task('g1'));
    batch.set(doc(d, 'gubs', 'g2', 'tasks', 'foreignTask'), task('g2', 'foreignTask'));
    batch.set(doc(d, 'gubs', 'g1', 'events', 'event1'), { gubId: 'g1', eventId: 'event1', proposalId: 'proposal1', title: 'Proposal', description: 'Description', type: 'custom', creatorId: uid.member, creatorName: uid.member, eventDate: new Date('2030-03-01T00:00:00Z'), createdAt: now(), status: 'scheduled' });
    batch.set(doc(d, 'gubs', 'g1', 'organizedEvents', 'organized1'), { eventId: 'organized1', gubId: 'g1', title: 'Organized', description: null, location: null, scheduledAt: null, createdBy: uid.member, createdByName: uid.member, createdAt: now(), status: 'active', completedAt: null, sourceType: 'manual', sourceId: null, sourcePreview: null, originUserId: null, sourceAuthorName: null, assignments: [{ userId: uid.second, userName: uid.second, taskText: 'Work', isCompleted: false, completedAt: null }] });
    batch.set(doc(d, 'gubs', 'g1', 'proposals', 'proposal1'), proposal('g1', 'proposal1', { status: 'approved', yesVotes: 3, resultProcessed: true }));
    batch.set(doc(d, 'gubs', 'g1', 'proposals', 'proposal1', 'votes', uid.member), { uid: uid.member, vote: 'yes', votedAt: now() });
    batch.set(doc(d, 'gubs', 'g1', 'goals', 'goal1'), goal());
    batch.set(doc(d, 'gubs', 'g1', 'goals', 'goal1', 'members', uid.member), { uid: uid.member, displayName: uid.member, photoUrl: null, amount: 10, confirmed: false, updatedAt: now(), confirmedAt: null });
    batch.set(doc(d, 'gubs', 'g1', 'notifications', 'notification1'), { notificationId: 'notification1', title: 'Task', body: 'Created', type: 'task_created', senderId: uid.member, senderName: uid.member, createdAt: now(), readBy: [uid.member], data: { module: 'tasks', gubId: 'g1', taskId: 'task1' } });
    batch.set(doc(d, 'gubs', 'g1', 'creationCooldowns', `${uid.member}_task`), { creatorId: uid.member, moduleType: 'task', deletedItemId: 'old', deletedBy: uid.member, deletedAt: now(), availableAt: now() });
    batch.set(doc(d, 'communities', 'c1', 'messages', 'cm1'), { messageId: 'cm1', communityId: 'c1', senderId: uid.communityMember, senderName: uid.communityMember, text: 'Community', createdAt: now() });
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
      ['messages', [where('createdAt', '>=', now()), orderBy('createdAt', 'desc'), limit(50)]], ['posts', [where('createdAt', '>=', now()), orderBy('createdAt', 'desc'), limit(25)]],
      ['tasks', [where('status', '==', 'active')]], ['events', [where('eventDate', '>=', now()), orderBy('eventDate')]],
      ['organizedEvents', [orderBy('createdAt', 'desc')]], ['proposals', [where('status', '==', 'voting')]],
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
    await assertSucceeds(getDocs(query(collection(db(uid.member), 'gubs', 'g1', 'notifications'), where('createdAt', '>=', now()))));
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

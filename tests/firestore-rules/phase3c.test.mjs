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
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-gubify';
const uid = {
  ownerGub: 'ownerGub',
  memberGub: 'memberGub',
  secondMember: 'secondMember',
  outsider: 'outsider',
  ownerOtherGub: 'ownerOtherGub',
  ownerCommunity: 'ownerCommunity',
  memberCommunity: 'memberCommunity',
  communityOutsider: 'communityOutsider',
  falseOwner: 'falseOwner',
};
const ts = () => new Date('2026-01-01T00:00:00Z');
const gubMembers = [uid.ownerGub, uid.memberGub, uid.secondMember];
const tokenId = (id) => id === 'g2' ? 'DEL3C2Q8' : 'DEL3C2Q7';
const communityMembers = [uid.ownerCommunity, uid.memberCommunity];
let env;

const db = (userId) => env.authenticatedContext(userId).firestore();
const anonymousDb = () => env.unauthenticatedContext().firestore();
const profile = (userId) => ({ displayName: userId, createdAt: ts(), updatedAt: ts(), activeHub: null, avatar: null });
const member = (userId, role = 'member') => ({ uid: userId, displayName: userId, photoUrl: null, role, joinedAt: ts() });
const gubRoot = (id = 'g1', ownerId = uid.ownerGub, overrides = {}) => ({
  gubId: id, name: `${id} Gub`, ownerId, inviteTokenId: tokenId(id), memberCount: gubMembers.length, createdAt: ts(), ...overrides,
});
const gubCopy = (id, userId, role = 'member', overrides = {}) => ({
  gubId: id, name: `${id} Gub`,
  ownerId: id === 'g2' ? uid.ownerOtherGub : uid.ownerGub, role, joinedAt: ts(), ...overrides,
});
const communityRoot = (id = 'c1', ownerId = uid.ownerCommunity, overrides = {}) => ({
  communityId: id, name: `${id} Community`, ownerId, memberCount: communityMembers.length,
  visibility: 'public', createdAt: ts(), type: 'General', language: 'English', description: '', ...overrides,
});
const communityCopy = (id, userId, role = 'member', overrides = {}) => ({
  communityId: id, name: `${id} Community`, ownerId: uid.ownerCommunity,
  memberCount: communityMembers.length, visibility: 'public', role, joinedAt: ts(), ...overrides,
});
const task = (id = 'task1', overrides = {}) => ({
  gubId: 'g1', taskId: id, title: 'Task', description: '', creatorId: uid.memberGub,
  creatorName: uid.memberGub, assignedUserId: uid.secondMember, assignedUserName: uid.secondMember,
  sourceType: 'manual', sourceId: null, sourcePreview: null, originUserId: null,
  sourceAuthorName: null, additionalDetails: null, status: 'active', priority: 'normal',
  createdAt: ts(), dueDate: null, completedAt: null, completedBy: null,
  notificationsEnabled: true, archived: false, ...overrides,
});
const assignment = (userId, overrides = {}) => ({ userId, userName: userId, taskText: 'Do work', isCompleted: false, completedAt: null, ...overrides });
const organizedEvent = (id = 'organized1') => ({
  eventId: id, gubId: 'g1', title: 'Event', description: null, location: null,
  scheduledAt: null, createdBy: uid.memberGub, createdByName: uid.memberGub,
  createdAt: ts(), status: 'active', completedAt: null, sourceType: 'manual',
  sourceId: null, sourcePreview: null, originUserId: null, sourceAuthorName: null,
  assignments: [assignment(uid.secondMember)],
});
const proposal = (id = 'proposal1') => ({
  gubId: 'g1', proposalId: id, title: 'Proposal', description: 'Details', creatorId: uid.memberGub,
  creatorName: uid.memberGub, status: 'voting', createdAt: ts(), expiresAt: new Date('2026-02-01T00:00:00Z'),
  eventDate: null, type: 'custom', yesVotes: 0, noVotes: 0, memberCount: gubMembers.length,
  resultProcessed: false, eventCreated: false, tasksCreated: false, sourceType: 'manual',
  sourceId: null, sourcePreview: null, originUserId: null, sourceAuthorName: null,
});
const goal = (id = 'goal1') => ({
  goalId: id, title: 'Budget', description: '', targetAmount: 100, currentAmount: 0,
  ownerId: uid.ownerGub, completedMembers: 0, totalMembers: gubMembers.length,
  status: 'active', archived: false, createdAt: ts(), deadline: null, completedAt: null,
  sourceType: 'manual', sourceId: null, sourcePreview: null, originUserId: null, sourceAuthorName: null,
});

before(async () => {
  env = await initializeTestEnvironment({ projectId, firestore: { rules: readFileSync('firestore.rules', 'utf8') } });
});
after(async () => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const seedDb = context.firestore();
    const batch = writeBatch(seedDb);
    for (const userId of Object.values(uid)) batch.set(doc(seedDb, 'users', userId), profile(userId));
    batch.set(doc(seedDb, 'gubs', 'g1'), gubRoot());
    batch.set(doc(seedDb, 'inviteTokens', tokenId('g1')), { gubId: 'g1', ownerId: uid.ownerGub, gubName: 'g1 Gub', active: true, createdAt: ts() });
    for (const userId of gubMembers) {
      const role = userId === uid.ownerGub ? 'owner' : 'member';
      batch.set(doc(seedDb, 'gubs', 'g1', 'members', userId), member(userId, role));
      batch.set(doc(seedDb, 'users', userId, 'gubs', 'g1'), gubCopy('g1', userId, role));
    }
    batch.set(doc(seedDb, 'gubs', 'g2'), gubRoot('g2', uid.ownerOtherGub, { memberCount: 1 }));
    batch.set(doc(seedDb, 'inviteTokens', tokenId('g2')), { gubId: 'g2', ownerId: uid.ownerOtherGub, gubName: 'g2 Gub', active: true, createdAt: ts() });
    batch.set(doc(seedDb, 'gubs', 'g2', 'members', uid.ownerOtherGub), member(uid.ownerOtherGub, 'owner'));
    batch.set(doc(seedDb, 'users', uid.ownerOtherGub, 'gubs', 'g2'), gubCopy('g2', uid.ownerOtherGub, 'owner', { memberCount: 1 }));
    batch.set(doc(seedDb, 'communities', 'c1'), communityRoot());
    for (const userId of communityMembers) {
      const role = userId === uid.ownerCommunity ? 'owner' : 'member';
      batch.set(doc(seedDb, 'communities', 'c1', 'members', userId), member(userId, role));
      batch.set(doc(seedDb, 'users', userId, 'communities', 'c1'), communityCopy('c1', userId, role));
    }
    batch.set(doc(seedDb, 'communityOwnership', uid.ownerCommunity), { ownerId: uid.ownerCommunity, communityId: 'c1', createdAt: ts() });
    await batch.commit();
  });
});

async function seed(path, data) {
  await env.withSecurityRulesDisabled((context) => setDoc(doc(context.firestore(), ...path), data));
}
async function seedPopulatedGub(id = 'g1') {
  const base = ['gubs', id];
  await env.withSecurityRulesDisabled(async (context) => {
    const d = context.firestore();
    const writes = [
      [['messages', 'message1'], { messageId: 'message1', gubId: id, senderId: uid.memberGub, senderName: uid.memberGub, text: 'Message', createdAt: ts() }],
      [['chatReads', uid.memberGub], { userId: uid.memberGub, gubId: id, lastReadAt: ts() }],
      [['boardReads', uid.memberGub], { lastReadAt: ts() }],
      [['posts', 'post1'], { gubId: id, authorId: uid.memberGub, authorName: uid.memberGub, authorPhoto: null, message: 'Post', likes: 0, comments: 0, createdAt: ts(), updatedAt: ts() }],
      [['tasks', 'task1'], task()],
      [['events', 'event1'], { gubId: id, eventId: 'event1', proposalId: 'proposal1', title: 'Calendar', description: '', type: 'custom', creatorId: uid.memberGub, creatorName: uid.memberGub, eventDate: ts(), createdAt: ts(), status: 'scheduled' }],
      [['organizedEvents', 'organized1'], organizedEvent()],
      [['proposals', 'proposal1'], proposal()],
      [['proposals', 'proposal1', 'votes', uid.memberGub], { uid: uid.memberGub, vote: 'yes', votedAt: ts() }],
      [['goals', 'goal1'], goal()],
      [['goals', 'goal1', 'members', uid.memberGub], { uid: uid.memberGub, displayName: uid.memberGub, photoUrl: null, amount: 10, confirmed: false, updatedAt: ts(), confirmedAt: null }],
      [['notifications', 'notification1'], { notificationId: 'notification1', title: 'Notice', body: 'Body', type: 'task_created', senderId: uid.memberGub, senderName: uid.memberGub, createdAt: ts(), readBy: [uid.memberGub], data: { module: 'tasks', gubId: id, taskId: 'task1' } }],
      [['creationCooldowns', `${uid.memberGub}_task`], { creatorId: uid.memberGub, moduleType: 'task', deletedItemId: 'old', deletedBy: uid.memberGub, deletedAt: ts(), availableAt: ts() }],
    ];
    for (const [suffix, data] of writes) await setDoc(doc(d, ...base, ...suffix), data);
  });
}
async function startGubDeletion(actor = uid.ownerGub, overrides = {}) {
  const clientDb = db(actor);
  const batch = writeBatch(clientDb);
  batch.update(doc(clientDb, 'gubs', 'g1'), {
    deletionStatus: 'deleting', deletionRequestedBy: actor,
    deletionStartedAt: serverTimestamp(), deletionUpdatedAt: serverTimestamp(), deletionPhase: 'preparing', ...overrides,
  });
  batch.update(doc(clientDb, 'inviteTokens', tokenId('g1')), { active: false });
  return batch.commit();
}
async function markGubDeleting(id = 'g1', ownerId = uid.ownerGub, overrides = {}) {
  await env.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    await updateDoc(doc(adminDb, 'gubs', id), {
      deletionStatus: 'deleting', deletionRequestedBy: ownerId, deletionStartedAt: ts(),
      deletionUpdatedAt: ts(), deletionPhase: 'preparing', ...overrides,
    });
    await updateDoc(doc(adminDb, 'inviteTokens', tokenId(id)), { active: false });
  });
}
async function deleteCollection(clientDb, path) {
  while (true) {
    const snapshot = await getDocs(collection(clientDb, ...path));
    if (snapshot.empty) return;
    const batch = writeBatch(clientDb);
    for (const item of snapshot.docs) batch.delete(item.ref);
    await batch.commit();
  }
}
async function cleanupGub(clientDb, id = 'g1') {
  const rootRef = doc(clientDb, 'gubs', id);
  const memberSnapshot = await getDocs(collection(clientDb, 'gubs', id, 'members'));
  const memberIds = [...new Set([uid.ownerGub, ...memberSnapshot.docs.map((item) => item.id)])].sort();
  await updateDoc(rootRef, { deletionMemberIds: memberIds });
  await updateDoc(rootRef, { deletionPhase: 'preparing', deletionUpdatedAt: serverTimestamp() });
  for (const [parents, children] of [['proposals', 'votes'], ['goals', 'members']]) {
    const parentSnapshot = await getDocs(collection(clientDb, 'gubs', id, parents));
    for (const parent of parentSnapshot.docs) await deleteCollection(clientDb, ['gubs', id, parents, parent.id, children]);
    const batch = writeBatch(clientDb); for (const parent of parentSnapshot.docs) batch.delete(parent.ref); await batch.commit();
  }
  await updateDoc(rootRef, { deletionPhase: 'nestedCollections', deletionUpdatedAt: serverTimestamp() });
  for (const name of ['messages', 'chatReads', 'boardReads', 'posts', 'tasks', 'events', 'organizedEvents', 'notifications', 'creationCooldowns', 'members']) {
    await deleteCollection(clientDb, ['gubs', id, name]);
  }
  await updateDoc(rootRef, { deletionPhase: 'directCollections', deletionUpdatedAt: serverTimestamp() });
  const copyBatch = writeBatch(clientDb);
  for (const memberId of memberIds) copyBatch.delete(doc(clientDb, 'users', memberId, 'gubs', id));
  await copyBatch.commit();
  await updateDoc(rootRef, { deletionPhase: 'userCopies', deletionUpdatedAt: serverTimestamp() });
  const tokenRef = doc(clientDb, 'inviteTokens', tokenId(id));
  if ((await getDoc(tokenRef)).exists()) await deleteDoc(tokenRef);
  await updateDoc(rootRef, { deletionPhase: 'finalizing', deletionUpdatedAt: serverTimestamp() });
  await deleteDoc(rootRef);
}

async function startCommunityDeletion(actor = uid.ownerCommunity, overrides = {}) {
  return updateDoc(doc(db(actor), 'communities', 'c1'), {
    deletionStatus: 'deleting', deletionStartedAt: serverTimestamp(),
    deletionStartedBy: actor, deletionRequestedBy: actor, ...overrides,
  });
}
async function markCommunityDeleting(overrides = {}) {
  await env.withSecurityRulesDisabled((context) => updateDoc(doc(context.firestore(), 'communities', 'c1'), {
    deletionStatus: 'deleting', deletionStartedAt: ts(), deletionStartedBy: uid.ownerCommunity,
    deletionRequestedBy: uid.ownerCommunity, ...overrides,
  }));
}
async function cleanupCommunity(clientDb, id = 'c1', ownerId = uid.ownerCommunity) {
  const rootRef = doc(clientDb, 'communities', id);
  const memberSnapshot = await getDocs(collection(clientDb, 'communities', id, 'members'));
  const memberIds = [...new Set([ownerId, ...memberSnapshot.docs.map((item) => item.id)])];
  for (const memberId of memberIds) await setDoc(doc(clientDb, 'communities', id, 'deletionMembers', memberId), { uid: memberId });
  await updateDoc(rootRef, { deletionMembersCapturedAt: serverTimestamp() });
  const asks = await getDocs(collection(clientDb, 'communities', id, 'asks'));
  for (const ask of asks.docs) {
    await deleteCollection(clientDb, ['communities', id, 'asks', ask.id, 'answers']);
  }
  await deleteCollection(clientDb, ['communities', id, 'asks']);
  await deleteCollection(clientDb, ['communities', id, 'messages']);
  await deleteCollection(clientDb, ['communities', id, 'members']);
  while (true) {
    const markers = await getDocs(collection(clientDb, 'communities', id, 'deletionMembers'));
    if (markers.empty) break;
    const batch = writeBatch(clientDb);
    for (const marker of markers.docs) {
      batch.delete(doc(clientDb, 'users', marker.id, 'communities', id));
      batch.delete(marker.ref);
    }
    await batch.commit();
  }
  await runTransaction(clientDb, async (transaction) => {
    const rootSnapshot = await transaction.get(rootRef);
    assert.equal(rootSnapshot.exists(), true);
    const ownershipRef = doc(clientDb, 'communityOwnership', ownerId);
    const ownership = await transaction.get(ownershipRef);
    if (ownership.data()?.communityId === id) transaction.delete(ownershipRef);
    transaction.delete(rootRef);
  });
}

describe('Gub deletion transition and checkpoints', () => {
  test('real owner starts deletion with the exact server-timestamp payload', () => assertSucceeds(startGubDeletion()));
  for (const [name, actor] of [['member', uid.memberGub], ['outsider', uid.outsider], ['other Gub owner', uid.ownerOtherGub]]) {
    test(`${name} cannot start Gub deletion`, () => assertFails(startGubDeletion(actor)));
  }
  test('anonymous user cannot start deletion', () => assertFails(updateDoc(doc(anonymousDb(), 'gubs', 'g1'), { deletionStatus: 'deleting', deletionRequestedBy: uid.ownerGub, deletionStartedAt: serverTimestamp(), deletionUpdatedAt: serverTimestamp(), deletionPhase: 'preparing' })));
  test('owner cannot forge starter, timestamp, root fields, or arbitrary fields', async () => {
    await assertFails(startGubDeletion(uid.ownerGub, { deletionRequestedBy: uid.falseOwner }));
    await assertFails(startGubDeletion(uid.ownerGub, { deletionStartedAt: 'now' }));
    await assertFails(startGubDeletion(uid.ownerGub, { ownerId: uid.falseOwner }));
    await assertFails(startGubDeletion(uid.ownerGub, { name: 'Changed', inviteTokenId: 'BAD3C2Q7', memberCount: 99 }));
    await assertFails(startGubDeletion(uid.ownerGub, { arbitrary: true }));
  });
  test('deletion cannot start from an unexpected state or missing root', async () => {
    await seed(['gubs', 'g1'], gubRoot('g1', uid.ownerGub, { deletionStatus: 'deleted' }));
    await assertFails(startGubDeletion());
    await assertFails(updateDoc(doc(db(uid.ownerGub), 'gubs', 'missing'), { deletionStatus: 'deleting' }));
  });
  test('retry preserves starter and start time and cannot return active', async () => {
    await assertSucceeds(startGubDeletion());
    await assertSucceeds(updateDoc(doc(db(uid.ownerGub), 'gubs', 'g1'), { deletionUpdatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(db(uid.ownerGub), 'gubs', 'g1'), { deletionRequestedBy: uid.falseOwner }));
    await assertFails(updateDoc(doc(db(uid.ownerGub), 'gubs', 'g1'), { deletionStartedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(db(uid.ownerGub), 'gubs', 'g1'), { deletionStatus: 'active' }));
  });
  test('only real deletion phases and monotonic retry checkpoints are accepted', async () => {
    await assertSucceeds(startGubDeletion());
    const ref = doc(db(uid.ownerGub), 'gubs', 'g1');
    await assertSucceeds(updateDoc(ref, { deletionMemberIds: [...gubMembers].sort() }));
    await assertSucceeds(updateDoc(ref, { deletionPhase: 'nestedCollections', deletionUpdatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { deletionPhase: 'preparing', deletionUpdatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { deletionPhase: 'anything', deletionUpdatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { deletionUpdatedAt: 'now' }));
  });
});

describe('normal Gub writes are blocked while deleting', () => {
  beforeEach(() => markGubDeleting());
  test('join, membership, user copy, messages, reads, and Board posts are blocked', async () => {
    const memberDb = db(uid.memberGub);
    await assertFails(updateDoc(doc(memberDb, 'gubs', 'g1'), { memberCount: 4 }));
    await assertFails(setDoc(doc(db(uid.outsider), 'gubs', 'g1', 'members', uid.outsider), member(uid.outsider)));
    await assertFails(setDoc(doc(db(uid.outsider), 'users', uid.outsider, 'gubs', 'g1'), gubCopy('g1', uid.outsider)));
    await assertFails(setDoc(doc(memberDb, 'gubs', 'g1', 'messages', 'new'), { messageId: 'new', gubId: 'g1', senderId: uid.memberGub, senderName: uid.memberGub, text: 'Blocked', createdAt: serverTimestamp() }));
    await assertFails(setDoc(doc(memberDb, 'gubs', 'g1', 'chatReads', uid.memberGub), { userId: uid.memberGub, gubId: 'g1', lastReadAt: serverTimestamp() }));
    await assertFails(setDoc(doc(memberDb, 'gubs', 'g1', 'boardReads', uid.memberGub), { lastReadAt: serverTimestamp() }));
    await assertFails(setDoc(doc(memberDb, 'gubs', 'g1', 'posts', 'new'), { gubId: 'g1', authorId: uid.memberGub, authorName: uid.memberGub, authorPhoto: null, message: 'Blocked', likes: 0, comments: 0, createdAt: serverTimestamp(), updatedAt: serverTimestamp() }));
  });
  test('Task, Calendar, Organized Event, Proposal, vote, Goal, notification, and cooldown writes are blocked', async () => {
    await seedPopulatedGub();
    const memberDb = db(uid.memberGub);
    await assertFails(setDoc(doc(memberDb, 'gubs', 'g1', 'tasks', 'new'), task('new')));
    await assertFails(updateDoc(doc(db(uid.secondMember), 'gubs', 'g1', 'tasks', 'task1'), { status: 'completed', completedAt: serverTimestamp(), completedBy: uid.secondMember }));
    await assertFails(setDoc(doc(memberDb, 'gubs', 'g1', 'events', 'new'), { arbitrary: true }));
    await assertFails(setDoc(doc(memberDb, 'gubs', 'g1', 'organizedEvents', 'new'), organizedEvent('new')));
    await assertFails(updateDoc(doc(db(uid.secondMember), 'gubs', 'g1', 'organizedEvents', 'organized1'), { assignments: [assignment(uid.secondMember, { isCompleted: true, completedAt: ts() })], status: 'completed', completedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(memberDb, 'gubs', 'g1', 'proposals', 'new'), proposal('new')));
    await assertFails(setDoc(doc(memberDb, 'gubs', 'g1', 'proposals', 'proposal1', 'votes', uid.memberGub), { uid: uid.memberGub, vote: 'yes', votedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(db(uid.ownerGub), 'gubs', 'g1', 'goals', 'new'), goal('new')));
    await assertFails(updateDoc(doc(db(uid.ownerGub), 'gubs', 'g1', 'goals', 'goal1', 'members', uid.memberGub), { confirmed: true, confirmedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(memberDb, 'gubs', 'g1', 'notifications', 'new'), { arbitrary: true }));
    await assertFails(setDoc(doc(memberDb, 'gubs', 'g1', 'creationCooldowns', 'new'), { arbitrary: true }));
  });
});

const gubCleanupPaths = [
  ['messages', 'message1'], ['chatReads', uid.memberGub], ['boardReads', uid.memberGub], ['posts', 'post1'],
  ['tasks', 'task1'], ['events', 'event1'], ['organizedEvents', 'organized1'],
  ['proposals', 'proposal1', 'votes', uid.memberGub], ['proposals', 'proposal1'],
  ['goals', 'goal1', 'members', uid.memberGub], ['goals', 'goal1'],
  ['notifications', 'notification1'], ['creationCooldowns', `${uid.memberGub}_task`], ['members', uid.memberGub],
];

describe('Gub cleanup authorization and isolation', () => {
  beforeEach(async () => { await seedPopulatedGub(); await markGubDeleting(); });
  for (const path of gubCleanupPaths) {
    const label = path.join('/');
    test(`deletion owner cleans ${label}; member, outsider, and anonymous cannot`, async () => {
      const full = ['gubs', 'g1', ...path];
      await assertFails(deleteDoc(doc(db(uid.memberGub), ...full)));
      await assertFails(deleteDoc(doc(db(uid.outsider), ...full)));
      await assertFails(deleteDoc(doc(anonymousDb(), ...full)));
      await assertSucceeds(deleteDoc(doc(db(uid.ownerGub), ...full)));
      await assertSucceeds(deleteDoc(doc(db(uid.ownerGub), ...full)));
    });
  }
  test('owner deletes all captured user copies but members cannot delete another user copy', async () => {
    await assertFails(deleteDoc(doc(db(uid.memberGub), 'users', uid.secondMember, 'gubs', 'g1')));
    for (const memberId of gubMembers) await assertSucceeds(deleteDoc(doc(db(uid.ownerGub), 'users', memberId, 'gubs', 'g1')));
  });
  test('incoherent copy and ownership of another Gub do not grant cleanup rights', async () => {
    await seed(['users', uid.memberGub, 'gubs', 'g1'], gubCopy('other', uid.memberGub));
    await assertFails(deleteDoc(doc(db(uid.ownerOtherGub), 'users', uid.memberGub, 'gubs', 'g1')));
    await seed(['gubs', 'g2', 'messages', 'preserved'], { value: true });
    await assertFails(deleteDoc(doc(db(uid.ownerGub), 'gubs', 'g2', 'messages', 'preserved')));
  });
  test('active root cannot be deleted, deleting root only by starter owner after token cleanup', async () => {
    await seed(['gubs', 'g1'], gubRoot());
    await assertFails(deleteDoc(doc(db(uid.ownerGub), 'gubs', 'g1')));
    await markGubDeleting('g1', uid.ownerGub, { deletionRequestedBy: uid.falseOwner });
    await assertFails(deleteDoc(doc(db(uid.ownerGub), 'gubs', 'g1')));
    await assertFails(deleteDoc(doc(db(uid.falseOwner), 'gubs', 'g1')));
    await markGubDeleting();
    await assertFails(deleteDoc(doc(db(uid.memberGub), 'gubs', 'g1')));
    await assertFails(deleteDoc(doc(db(uid.outsider), 'gubs', 'g1')));
    await assertFails(deleteDoc(doc(anonymousDb(), 'gubs', 'g1')));
    await assertSucceeds(deleteDoc(doc(db(uid.ownerGub), 'inviteTokens', tokenId('g1'))));
    await assertSucceeds(deleteDoc(doc(db(uid.ownerGub), 'gubs', 'g1')));
  });
});

describe('complete and resumed Gub pipeline', () => {
  test('populated Gub is deleted in client order while another Gub remains intact', async () => {
    await seedPopulatedGub();
    await assertSucceeds(startGubDeletion());
    await cleanupGub(db(uid.ownerGub));
    await env.withSecurityRulesDisabled(async (context) => {
      assert.equal((await getDoc(doc(context.firestore(), 'gubs', 'g1'))).exists(), false);
      assert.equal((await getDoc(doc(context.firestore(), 'gubs', 'g2'))).exists(), true);
      for (const memberId of gubMembers) assert.equal((await getDoc(doc(context.firestore(), 'users', memberId, 'gubs', 'g1'))).exists(), false);
    });
  });
  test('partial nested cleanup can be retried and already absent documents remain harmless', async () => {
    await seedPopulatedGub(); await assertSucceeds(startGubDeletion());
    await deleteCollection(db(uid.ownerGub), ['gubs', 'g1', 'proposals', 'proposal1', 'votes']);
    await assertSucceeds(deleteDoc(doc(db(uid.ownerGub), 'gubs', 'g1', 'proposals', 'proposal1')));
    await cleanupGub(db(uid.ownerGub));
    await env.withSecurityRulesDisabled(async (context) => assert.equal((await getDoc(doc(context.firestore(), 'gubs', 'g1'))).exists(), false));
  });
});

describe('Community transition, cleanup, legacy, and retry', () => {
  test('owner starts deletion; member, outsider, anonymous, forged starter and invalid timestamp fail', async () => {
    await assertFails(startCommunityDeletion(uid.memberCommunity));
    await assertFails(startCommunityDeletion(uid.communityOutsider));
    await assertFails(updateDoc(doc(anonymousDb(), 'communities', 'c1'), { deletionStatus: 'deleting' }));
    await assertFails(startCommunityDeletion(uid.ownerCommunity, { deletionStartedBy: uid.falseOwner }));
    await assertFails(startCommunityDeletion(uid.ownerCommunity, { deletionRequestedBy: uid.falseOwner }));
    await assertFails(startCommunityDeletion(uid.ownerCommunity, { deletionStartedAt: 'now' }));
    await assertSucceeds(startCommunityDeletion());
  });
  test('unexpected state, functional changes, and owner promotion during start are denied', async () => {
    await seed(['communities', 'c1'], communityRoot('c1', uid.ownerCommunity, { deletionStatus: 'deleted' }));
    await assertFails(startCommunityDeletion());
    await seed(['communities', 'c1'], communityRoot());
    await assertFails(startCommunityDeletion(uid.ownerCommunity, { name: 'Changed', ownerId: uid.falseOwner, arbitrary: true }));
  });
  test('normal Community joins, membership, messages, and copies stop while deleting', async () => {
    await markCommunityDeleting();
    await assertFails(updateDoc(doc(db(uid.memberCommunity), 'communities', 'c1'), { memberCount: 3 }));
    await assertFails(setDoc(doc(db(uid.communityOutsider), 'communities', 'c1', 'members', uid.communityOutsider), member(uid.communityOutsider)));
    await assertFails(setDoc(doc(db(uid.communityOutsider), 'users', uid.communityOutsider, 'communities', 'c1'), communityCopy('c1', uid.communityOutsider)));
    await assertFails(setDoc(doc(db(uid.memberCommunity), 'communities', 'c1', 'messages', 'new'), { messageId: 'new', communityId: 'c1', senderId: uid.memberCommunity, senderName: uid.memberCommunity, text: 'Blocked', createdAt: serverTimestamp() }));
  });
  test('deletion markers are owner-only checkpoints with exact UID and support read/delete retry', async () => {
    await markCommunityDeleting();
    const ownerDb = db(uid.ownerCommunity);
    const marker = doc(ownerDb, 'communities', 'c1', 'deletionMembers', uid.memberCommunity);
    await assertFails(setDoc(doc(db(uid.memberCommunity), 'communities', 'c1', 'deletionMembers', uid.memberCommunity), { uid: uid.memberCommunity }));
    await assertFails(setDoc(marker, { uid: uid.falseOwner }));
    await assertSucceeds(setDoc(marker, { uid: uid.memberCommunity }));
    await assertSucceeds(setDoc(marker, { uid: uid.memberCommunity }));
    await assertFails(setDoc(marker, { uid: uid.falseOwner }));
    await assertSucceeds(getDocs(collection(ownerDb, 'communities', 'c1', 'deletionMembers')));
    await assertSucceeds(deleteDoc(marker));
    await assertSucceeds(deleteDoc(marker));
  });
  test('owner cleanup permissions cover messages, members, user copies, markers, and atomic finalization', async () => {
    await seed(['communities', 'c1', 'messages', 'message1'], { messageId: 'message1', communityId: 'c1', senderId: uid.memberCommunity, senderName: uid.memberCommunity, text: 'Message', createdAt: ts() });
    await markCommunityDeleting();
    await assertFails(deleteDoc(doc(db(uid.memberCommunity), 'communities', 'c1', 'messages', 'message1')));
    await assertSucceeds(deleteDoc(doc(db(uid.ownerCommunity), 'communities', 'c1', 'messages', 'message1')));
    await assertSucceeds(deleteDoc(doc(db(uid.ownerCommunity), 'communities', 'c1', 'members', uid.memberCommunity)));
    await assertSucceeds(deleteDoc(doc(db(uid.ownerCommunity), 'users', uid.memberCommunity, 'communities', 'c1')));
    await assertFails(deleteDoc(doc(db(uid.memberCommunity), 'users', uid.ownerCommunity, 'communities', 'c1')));
    await assertFails(deleteDoc(doc(db(uid.ownerCommunity), 'communityOwnership', uid.ownerCommunity)));
    await assertFails(deleteDoc(doc(db(uid.ownerCommunity), 'communities', 'c1')));
    await assertSucceeds(cleanupCommunity(db(uid.ownerCommunity)));
  });
  test('full current Community pipeline deletes all data and preserves unrelated Community', async () => {
    await seed(['communities', 'c1', 'messages', 'message1'], { messageId: 'message1', communityId: 'c1', senderId: uid.memberCommunity, senderName: uid.memberCommunity, text: 'Message', createdAt: ts() });
    await seed(['communities', 'c1', 'asks', 'ask1'], { askId: 'ask1', communityId: 'c1', authorId: uid.ownerCommunity, authorDisplayName: uid.ownerCommunity, type: 'help', text: 'Help', createdAt: ts(), status: 'active' });
    await seed(['communities', 'c1', 'asks', 'ask1', 'answers', 'answer1'], { answerId: 'answer1', authorId: uid.memberCommunity, authorDisplayName: uid.memberCommunity, text: 'Answer', createdAt: ts() });
    await seed(['communities', 'c2'], communityRoot('c2', uid.falseOwner, { memberCount: 0 }));
    await assertSucceeds(startCommunityDeletion());
    await cleanupCommunity(db(uid.ownerCommunity));
    await env.withSecurityRulesDisabled(async (context) => {
      const firestore = context.firestore();
      assert.equal((await getDoc(doc(firestore, 'communities', 'c1'))).exists(), false);
      assert.equal((await getDoc(doc(firestore, 'communities', 'c1', 'messages', 'message1'))).exists(), false);
      assert.equal((await getDoc(doc(firestore, 'communities', 'c1', 'asks', 'ask1'))).exists(), false);
      assert.equal((await getDoc(doc(firestore, 'communities', 'c1', 'asks', 'ask1', 'answers', 'answer1'))).exists(), false);
      assert.equal((await getDoc(doc(firestore, 'communities', 'c1', 'members', uid.ownerCommunity))).exists(), false);
      assert.equal((await getDoc(doc(firestore, 'communities', 'c1', 'members', uid.memberCommunity))).exists(), false);
      assert.equal((await getDoc(doc(firestore, 'communityOwnership', uid.ownerCommunity))).exists(), false);
      assert.equal((await getDoc(doc(firestore, 'communities', 'c2'))).exists(), true);
      for (const memberId of communityMembers) assert.equal((await getDoc(doc(firestore, 'users', memberId, 'communities', 'c1'))).exists(), false);
    });
  });
  test('partial Community pipeline resumes after messages and one copy are already absent', async () => {
    await seed(['communities', 'c1', 'messages', 'message1'], { value: true });
    await seed(['communities', 'c1', 'asks', 'ask1'], { askId: 'ask1', communityId: 'c1', authorId: uid.ownerCommunity, authorDisplayName: uid.ownerCommunity, type: 'help', text: 'Help', createdAt: ts(), status: 'active' });
    await seed(['communities', 'c1', 'asks', 'ask1', 'answers', 'answer1'], { answerId: 'answer1', authorId: uid.memberCommunity, authorDisplayName: uid.memberCommunity, text: 'Answer', createdAt: ts() });
    await assertSucceeds(startCommunityDeletion());
    await assertSucceeds(deleteDoc(doc(db(uid.ownerCommunity), 'communities', 'c1', 'messages', 'message1')));
    await assertSucceeds(deleteDoc(doc(db(uid.ownerCommunity), 'communities', 'c1', 'asks', 'ask1', 'answers', 'answer1')));
    await assertSucceeds(deleteDoc(doc(db(uid.ownerCommunity), 'users', uid.memberCommunity, 'communities', 'c1')));
    await cleanupCommunity(db(uid.ownerCommunity));
  });
  test('owner discovers and resumes a deleting Community after its copy is gone', async () => {
    await seed(['communities', 'c1', 'messages', 'message1'], { value: true });
    await seed(['communities', 'c1', 'asks', 'ask1'], { askId: 'ask1', communityId: 'c1', authorId: uid.ownerCommunity, authorDisplayName: uid.ownerCommunity, type: 'help', text: 'Help', createdAt: ts(), status: 'active' });
    await seed(['communities', 'c1', 'asks', 'ask1', 'answers', 'answer1'], { answerId: 'answer1', authorId: uid.memberCommunity, authorDisplayName: uid.memberCommunity, text: 'Answer', createdAt: ts() });
    await seed(['communities', 'c2'], communityRoot('c2', uid.ownerCommunity, { memberCount: 0 }));
    await assertSucceeds(startCommunityDeletion());
    await assertSucceeds(deleteDoc(doc(db(uid.ownerCommunity), 'users', uid.ownerCommunity, 'communities', 'c1')));
    await assertSucceeds(deleteDoc(doc(db(uid.ownerCommunity), 'communities', 'c1', 'asks', 'ask1', 'answers', 'answer1')));

    const ownerDb = db(uid.ownerCommunity);
    const ownedCommunities = await assertSucceeds(getDocs(query(
      collection(ownerDb, 'communities'),
      where('ownerId', '==', uid.ownerCommunity),
    )));
    const incompleteIds = ownedCommunities.docs
      .filter((item) => item.data().deletionStatus === 'deleting'
        && (item.data().deletionRequestedBy === uid.ownerCommunity
          || item.data().deletionStartedBy === uid.ownerCommunity))
      .map((item) => item.id);

    assert.deepEqual(incompleteIds, ['c1']);
    await cleanupCommunity(ownerDb);
    await env.withSecurityRulesDisabled(async (context) => {
      const firestore = context.firestore();
      assert.equal((await getDoc(doc(firestore, 'communities', 'c1'))).exists(), false);
      assert.equal((await getDoc(doc(firestore, 'communities', 'c1', 'asks', 'ask1'))).exists(), false);
      assert.equal((await getDoc(doc(firestore, 'communities', 'c2'))).exists(), true);
    });
  });
  test('legacy deleting Community with deletionStartedBy only remains recoverable', async () => {
    await seed(['communities', 'c1'], { name: 'Legacy', ownerId: uid.ownerCommunity, memberCount: 2, visibility: 'public', createdAt: ts(), deletionStatus: 'deleting', deletionStartedAt: ts(), deletionStartedBy: uid.ownerCommunity });
    await env.withSecurityRulesDisabled((context) => deleteDoc(doc(context.firestore(), 'communityOwnership', uid.ownerCommunity)));
    await cleanupCommunity(db(uid.ownerCommunity));
  });
  test('legacy copies and memberships without role are cleanup data, but ambiguous legacy owner is denied', async () => {
    await seed(['users', uid.memberCommunity, 'communities', 'c1'], { communityId: 'c1', name: 'Legacy', ownerId: uid.ownerCommunity, joinedAt: ts() });
    await seed(['communities', 'c1', 'members', uid.memberCommunity], { uid: uid.memberCommunity, displayName: uid.memberCommunity, joinedAt: ts() });
    await markCommunityDeleting();
    await assertSucceeds(deleteDoc(doc(db(uid.ownerCommunity), 'users', uid.memberCommunity, 'communities', 'c1')));
    await assertSucceeds(deleteDoc(doc(db(uid.ownerCommunity), 'communities', 'c1', 'members', uid.memberCommunity)));
    await seed(['communities', 'c1'], { name: 'Ambiguous', visibility: 'public', deletionStatus: 'deleting' });
    await assertFails(deleteDoc(doc(db(uid.falseOwner), 'communities', 'c1')));
  });
  test('false ownership marker grants no Community deletion authority', async () => {
    await seed(['communityOwnership', uid.falseOwner], { ownerId: uid.falseOwner, communityId: 'c1', createdAt: ts() });
    await markCommunityDeleting();
    await assertFails(deleteDoc(doc(db(uid.falseOwner), 'communities', 'c1')));
    await assertFails(deleteDoc(doc(db(uid.falseOwner), 'communities', 'c1', 'members', uid.memberCommunity)));
  });
});

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
  getDoc,
  getDocs,
  runTransaction,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
  where,
} from 'firebase/firestore';

const projectId = 'demo-gubify';
const uid = {
  ownerGub: 'ownerGub',
  creatorTask: 'creatorTask',
  assigneeTask: 'assigneeTask',
  uninvolvedMember: 'uninvolvedMember',
  secondMember: 'secondMember',
  outsider: 'outsider',
};
const members = [
  uid.ownerGub,
  uid.creatorTask,
  uid.assigneeTask,
  uid.uninvolvedMember,
  uid.secondMember,
];

let env;
const db = (userId) => env.authenticatedContext(userId).firestore();
const anonymousDb = () => env.unauthenticatedContext().firestore();
const timestamp = () => new Date('2026-01-01T00:00:00Z');
const inviteTokenId = 'PHA3B2Q7';

const profile = (userId) => ({
  displayName: userId,
  createdAt: timestamp(),
  updatedAt: timestamp(),
  activeHub: null,
  avatar: null,
});
const member = (userId, role = 'member') => ({
  uid: userId,
  displayName: userId,
  photoUrl: null,
  role,
  joinedAt: timestamp(),
});
const root = (overrides = {}) => ({
  gubId: 'g1',
  name: 'Phase 3B Gub',
  ownerId: uid.ownerGub,
  inviteTokenId,
  memberCount: members.length,
  createdAt: timestamp(),
  ...overrides,
});
const copy = (userId, role) => ({
  gubId: 'g1',
  name: 'Phase 3B Gub',
  ownerId: uid.ownerGub,
  role,
  joinedAt: timestamp(),
});

const taskData = (taskId = 'task1', creatorId = uid.creatorTask, overrides = {}) => ({
  gubId: 'g1',
  taskId,
  title: 'Prepare the report',
  description: '',
  creatorId,
  creatorName: creatorId,
  assignedUserId: uid.assigneeTask,
  assignedUserName: uid.assigneeTask,
  sourceType: 'manual',
  sourceId: null,
  sourcePreview: null,
  originUserId: null,
  sourceAuthorName: null,
  additionalDetails: null,
  status: 'active',
  priority: 'normal',
  createdAt: timestamp(),
  dueDate: null,
  completedAt: null,
  completedBy: null,
  notificationsEnabled: true,
  archived: false,
  ...overrides,
});
const calendarEventData = (eventId = 'event1', overrides = {}) => ({
  gubId: 'g1',
  eventId,
  proposalId: 'proposal1',
  title: 'Meet next month',
  description: 'Proposal description',
  type: 'custom',
  creatorId: uid.creatorTask,
  creatorName: uid.creatorTask,
  eventDate: new Date('2026-02-01T12:00:00Z'),
  createdAt: timestamp(),
  status: 'scheduled',
  ...overrides,
});
const assignment = (userId, overrides = {}) => ({
  userId,
  userName: userId,
  taskText: `Assignment for ${userId}`,
  isCompleted: false,
  completedAt: null,
  ...overrides,
});
const organizedEventData = (eventId = 'organized1', creatorId = uid.creatorTask, overrides = {}) => ({
  eventId,
  gubId: 'g1',
  title: 'Organize launch',
  description: null,
  location: null,
  scheduledAt: null,
  createdBy: creatorId,
  createdByName: creatorId,
  createdAt: timestamp(),
  status: 'active',
  completedAt: null,
  sourceType: 'manual',
  sourceId: null,
  sourcePreview: null,
  originUserId: null,
  sourceAuthorName: null,
  assignments: [assignment(uid.assigneeTask), assignment(uid.secondMember)],
  ...overrides,
});
const proposalData = (proposalId = 'proposal1', creatorId = uid.creatorTask, overrides = {}) => ({
  gubId: 'g1',
  proposalId,
  title: 'Meet next month',
  description: 'Proposal description',
  creatorId,
  creatorName: creatorId,
  status: 'voting',
  createdAt: timestamp(),
  expiresAt: new Date('2026-01-08T00:00:00Z'),
  eventDate: new Date('2026-02-01T12:00:00Z'),
  type: 'custom',
  yesVotes: 0,
  noVotes: 0,
  memberCount: members.length,
  resultProcessed: false,
  eventCreated: false,
  tasksCreated: false,
  sourceType: 'manual',
  sourceId: null,
  sourcePreview: null,
  originUserId: null,
  sourceAuthorName: null,
  ...overrides,
});
const voteData = (userId, vote = 'yes', overrides = {}) => ({
  uid: userId,
  vote,
  votedAt: timestamp(),
  ...overrides,
});
const goalData = (goalId = 'goal1', ownerId = uid.ownerGub, overrides = {}) => ({
  goalId,
  title: 'Shared trip budget',
  description: 'Save together',
  targetAmount: 100,
  currentAmount: 0,
  ownerId,
  completedMembers: 0,
  totalMembers: members.length,
  status: 'active',
  archived: false,
  createdAt: timestamp(),
  deadline: null,
  completedAt: null,
  sourceType: 'manual',
  sourceId: null,
  sourcePreview: null,
  originUserId: null,
  sourceAuthorName: null,
  ...overrides,
});
const goalMemberData = (userId, overrides = {}) => ({
  uid: userId,
  displayName: userId,
  photoUrl: null,
  amount: 0,
  confirmed: false,
  updatedAt: timestamp(),
  confirmedAt: null,
  ...overrides,
});
const notificationData = (notificationId, senderId, type = 'task_created', overrides = {}) => ({
  notificationId,
  title: 'New task',
  body: 'A task was created.',
  type,
  senderId,
  senderName: senderId,
  createdAt: timestamp(),
  readBy: [senderId],
  data: { module: 'tasks', gubId: 'g1', taskId: 'task1' },
  ...overrides,
});
const cooldownData = (creatorId, moduleType, itemId, deletedBy, overrides = {}) => ({
  creatorId,
  moduleType,
  deletedItemId: itemId,
  deletedBy,
  deletedAt: serverTimestamp(),
  availableAt: new Date('2026-01-02T12:00:00Z'),
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
    const seedDb = context.firestore();
    const batch = writeBatch(seedDb);
    for (const userId of [...members, uid.outsider]) {
      batch.set(doc(seedDb, 'users', userId), profile(userId));
    }
    batch.set(doc(seedDb, 'gubs', 'g1'), root());
    batch.set(doc(seedDb, 'inviteTokens', inviteTokenId), {
      gubId: 'g1', ownerId: uid.ownerGub, gubName: 'Phase 3B Gub',
      active: true, createdAt: timestamp(),
    });
    for (const userId of members) {
      const role = userId === uid.ownerGub ? 'owner' : 'member';
      batch.set(doc(seedDb, 'gubs', 'g1', 'members', userId), member(userId, role));
      batch.set(doc(seedDb, 'users', userId, 'gubs', 'g1'), copy(userId, role));
    }
    await batch.commit();
  });
});

async function seed(pathSegments, data) {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), ...pathSegments), data);
  });
}
async function markDeleting() {
  await env.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'gubs', 'g1'), {
      deletionStatus: 'deleting',
      deletionRequestedBy: uid.ownerGub,
      deletionStartedAt: timestamp(),
      deletionUpdatedAt: timestamp(),
      deletionPhase: 'preparing',
    });
    await updateDoc(doc(context.firestore(), 'inviteTokens', inviteTokenId), {
      active: false,
    });
  });
}

describe('Tasks and supported origins', () => {
  test('member creates exact manual Task and members can read it', async () => {
    const ref = doc(db(uid.creatorTask), 'gubs', 'g1', 'tasks', 'task1');
    await assertSucceeds(setDoc(ref, taskData()));
    await assertSucceeds(getDoc(doc(db(uid.assigneeTask), 'gubs', 'g1', 'tasks', 'task1')));
  });
  test('outsider and unauthenticated user cannot read Tasks', async () => {
    await seed(['gubs', 'g1', 'tasks', 'task1'], taskData());
    await assertFails(getDocs(collection(db(uid.outsider), 'gubs', 'g1', 'tasks')));
    await assertFails(getDoc(doc(anonymousDb(), 'gubs', 'g1', 'tasks', 'task1')));
  });
  for (const [name, overrides] of [
    ['forged creatorId', { creatorId: uid.ownerGub }],
    ['incoherent gubId', { gubId: 'other' }],
    ['incoherent taskId', { taskId: 'other' }],
    ['unknown sourceType', { sourceType: 'calendar' }],
    ['arbitrary field', { isAdmin: true }],
    ['invalid status', { status: 'completed' }],
  ]) {
    test(`rejects Task create with ${name}`, () => assertFails(setDoc(doc(db(uid.creatorTask), 'gubs', 'g1', 'tasks', `bad-${name}`), taskData(`bad-${name}`, uid.creatorTask, overrides))));
  }
  test('rejects assignment to a non-member and forged assignee name', async () => {
    await assertFails(setDoc(doc(db(uid.creatorTask), 'gubs', 'g1', 'tasks', 'bad-assignee'), taskData('bad-assignee', uid.creatorTask, { assignedUserId: uid.outsider, assignedUserName: uid.outsider })));
    await assertFails(setDoc(doc(db(uid.creatorTask), 'gubs', 'g1', 'tasks', 'bad-name'), taskData('bad-name', uid.creatorTask, { assignedUserName: 'Forged' })));
  });
  test('creates a chat Task only with immutable source message metadata', async () => {
    await seed(['gubs', 'g1', 'messages', 'message1'], {
      messageId: 'message1', gubId: 'g1', senderId: uid.assigneeTask,
      senderName: uid.assigneeTask, text: 'Original full message', createdAt: timestamp(),
    });
    const chatTask = taskData('chat-task', uid.creatorTask, {
      sourceType: 'chat', sourceId: 'message1', sourcePreview: 'Original full message',
      originUserId: uid.assigneeTask, sourceAuthorName: uid.assigneeTask,
      additionalDetails: 'Optional details',
    });
    await assertSucceeds(setDoc(doc(db(uid.creatorTask), 'gubs', 'g1', 'tasks', 'chat-task'), chatTask));
    await assertFails(setDoc(doc(db(uid.creatorTask), 'gubs', 'g1', 'tasks', 'forged-chat'), { ...chatTask, taskId: 'forged-chat', sourcePreview: 'Changed origin' }));
  });
  test('assignee completes assigned Task with client payload', async () => {
    await seed(['gubs', 'g1', 'tasks', 'task1'], taskData());
    await assertSucceeds(updateDoc(doc(db(uid.assigneeTask), 'gubs', 'g1', 'tasks', 'task1'), {
      ...taskData(), status: 'completed', completedAt: timestamp(), completedBy: uid.assigneeTask,
    }));
  });
  test('any member may complete an unassigned Task, matching UI policy', async () => {
    await seed(['gubs', 'g1', 'tasks', 'open-task'], taskData('open-task', uid.creatorTask, { assignedUserId: null, assignedUserName: null }));
    await assertSucceeds(updateDoc(doc(db(uid.uninvolvedMember), 'gubs', 'g1', 'tasks', 'open-task'), {
      ...taskData('open-task', uid.creatorTask, { assignedUserId: null, assignedUserName: null }),
      status: 'completed', completedAt: timestamp(), completedBy: uid.uninvolvedMember,
    }));
  });
  test('rejects completion by uninvolved member and inconsistent completion fields', async () => {
    await seed(['gubs', 'g1', 'tasks', 'task1'], taskData());
    const ref = doc(db(uid.uninvolvedMember), 'gubs', 'g1', 'tasks', 'task1');
    await assertFails(updateDoc(ref, { ...taskData(), status: 'completed', completedAt: timestamp(), completedBy: uid.uninvolvedMember }));
    await assertFails(updateDoc(doc(db(uid.assigneeTask), 'gubs', 'g1', 'tasks', 'task1'), { ...taskData(), status: 'completed', completedAt: null, completedBy: uid.assigneeTask }));
    await assertFails(updateDoc(doc(db(uid.assigneeTask), 'gubs', 'g1', 'tasks', 'task1'), { ...taskData(), completedAt: timestamp(), completedBy: uid.assigneeTask }));
  });
  test('rejects edits, reassignment, origin replacement, creator changes, and reopening', async () => {
    await seed(['gubs', 'g1', 'tasks', 'task1'], taskData());
    const ref = doc(db(uid.creatorTask), 'gubs', 'g1', 'tasks', 'task1');
    await assertFails(updateDoc(ref, { ...taskData(), title: 'Edited' }));
    await assertFails(updateDoc(ref, { ...taskData(), assignedUserId: uid.secondMember, assignedUserName: uid.secondMember }));
    await assertFails(updateDoc(ref, { ...taskData(), sourceType: 'chat', sourceId: 'x' }));
    await assertFails(updateDoc(ref, { ...taskData(), creatorId: uid.ownerGub }));
    await seed(['gubs', 'g1', 'tasks', 'completed'], taskData('completed', uid.creatorTask, { status: 'completed', completedAt: timestamp(), completedBy: uid.assigneeTask }));
    await assertFails(updateDoc(doc(db(uid.assigneeTask), 'gubs', 'g1', 'tasks', 'completed'), taskData('completed')));
  });
  test('creator and Gub owner delete Task only with matching cooldown transaction', async () => {
    for (const [actor, taskId] of [[uid.creatorTask, 'delete-creator'], [uid.ownerGub, 'delete-owner']]) {
      await seed(['gubs', 'g1', 'tasks', taskId], taskData(taskId));
      const clientDb = db(actor);
      await assertSucceeds(runTransaction(clientDb, async (tx) => {
        tx.delete(doc(clientDb, 'gubs', 'g1', 'tasks', taskId));
        tx.set(doc(clientDb, 'gubs', 'g1', 'creationCooldowns', `${uid.creatorTask}_task`), cooldownData(uid.creatorTask, 'task', taskId, actor));
      }));
    }
  });
  test('rejects unauthorized Task deletion, missing cooldown, and writes while deleting', async () => {
    await seed(['gubs', 'g1', 'tasks', 'task1'], taskData());
    await assertFails(deleteDoc(doc(db(uid.uninvolvedMember), 'gubs', 'g1', 'tasks', 'task1')));
    await assertFails(deleteDoc(doc(db(uid.creatorTask), 'gubs', 'g1', 'tasks', 'task1')));
    await markDeleting();
    await assertFails(setDoc(doc(db(uid.creatorTask), 'gubs', 'g1', 'tasks', 'blocked'), taskData('blocked')));
  });
});

describe('Calendar Events created from Proposals', () => {
  beforeEach(async () => {
    await seed(['gubs', 'g1', 'proposals', 'proposal1'], proposalData('proposal1', uid.creatorTask, { status: 'approved', yesVotes: 3, resultProcessed: true }));
  });
  test('member processing an approved Proposal creates exact Calendar event', async () => {
    await assertSucceeds(setDoc(doc(db(uid.assigneeTask), 'gubs', 'g1', 'events', 'event1'), calendarEventData()));
  });
  test('member reads Calendar; outsider cannot read or create', async () => {
    await seed(['gubs', 'g1', 'events', 'event1'], calendarEventData());
    await assertSucceeds(getDocs(query(collection(db(uid.secondMember), 'gubs', 'g1', 'events'), where('eventDate', '>=', timestamp()))));
    await assertFails(getDocs(collection(db(uid.outsider), 'gubs', 'g1', 'events')));
    await assertFails(setDoc(doc(db(uid.outsider), 'gubs', 'g1', 'events', 'out'), calendarEventData('out', { creatorId: uid.outsider, creatorName: uid.outsider })));
  });
  for (const [name, overrides] of [
    ['forged creator', { creatorId: uid.ownerGub }],
    ['incoherent gubId', { gubId: 'other' }],
    ['incoherent eventId', { eventId: 'other' }],
    ['unknown proposal', { proposalId: 'missing' }],
    ['wrong timestamp', { createdAt: 'today' }],
    ['arbitrary field', { isAdmin: true }],
  ]) {
    test(`rejects Calendar create with ${name}`, () => assertFails(setDoc(doc(db(uid.assigneeTask), 'gubs', 'g1', 'events', `bad-${name}`), calendarEventData(`bad-${name}`, overrides))));
  }
  test('Calendar detail updates are denied because no Flutter call site invokes them', async () => {
    await seed(['gubs', 'g1', 'events', 'event1'], calendarEventData());
    await assertFails(updateDoc(doc(db(uid.creatorTask), 'gubs', 'g1', 'events', 'event1'), { ...calendarEventData(), status: 'completed' }));
  });
  test('creator and owner may delete Calendar event; unrelated member may not', async () => {
    await seed(['gubs', 'g1', 'events', 'creator-delete'], calendarEventData('creator-delete'));
    await assertSucceeds(deleteDoc(doc(db(uid.creatorTask), 'gubs', 'g1', 'events', 'creator-delete')));
    await seed(['gubs', 'g1', 'events', 'owner-delete'], calendarEventData('owner-delete'));
    await assertSucceeds(deleteDoc(doc(db(uid.ownerGub), 'gubs', 'g1', 'events', 'owner-delete')));
    await seed(['gubs', 'g1', 'events', 'denied-delete'], calendarEventData('denied-delete'));
    await assertFails(deleteDoc(doc(db(uid.uninvolvedMember), 'gubs', 'g1', 'events', 'denied-delete')));
  });
  test('Calendar writes are denied while Gub is deleting', async () => {
    await markDeleting();
    await assertFails(setDoc(doc(db(uid.assigneeTask), 'gubs', 'g1', 'events', 'blocked'), calendarEventData('blocked')));
  });
});

describe('Organized Events', () => {
  test('member creates exact manual and chat-origin Organized Events', async () => {
    await assertSucceeds(setDoc(doc(db(uid.creatorTask), 'gubs', 'g1', 'organizedEvents', 'organized1'), organizedEventData()));
    await seed(['gubs', 'g1', 'messages', 'message1'], { messageId: 'message1', gubId: 'g1', senderId: uid.assigneeTask, senderName: uid.assigneeTask, text: 'Organize this', createdAt: timestamp() });
    await assertSucceeds(setDoc(doc(db(uid.creatorTask), 'gubs', 'g1', 'organizedEvents', 'organized-chat'), organizedEventData('organized-chat', uid.creatorTask, { sourceType: 'chat', sourceId: 'message1', sourcePreview: 'Organize this', originUserId: uid.assigneeTask, sourceAuthorName: uid.assigneeTask })));
  });
  test('members read Organized Events; outsiders cannot read or create', async () => {
    await seed(['gubs', 'g1', 'organizedEvents', 'organized1'], organizedEventData());
    await assertSucceeds(getDoc(doc(db(uid.assigneeTask), 'gubs', 'g1', 'organizedEvents', 'organized1')));
    await assertFails(getDoc(doc(db(uid.outsider), 'gubs', 'g1', 'organizedEvents', 'organized1')));
    await assertFails(setDoc(doc(db(uid.outsider), 'gubs', 'g1', 'organizedEvents', 'out'), organizedEventData('out', uid.outsider)));
  });
  for (const [name, overrides] of [
    ['forged creator', { createdBy: uid.ownerGub }],
    ['incoherent gubId', { gubId: 'other' }],
    ['incoherent eventId', { eventId: 'other' }],
    ['unknown source', { sourceType: 'proposal' }],
    ['completed initial status', { status: 'completed' }],
    ['arbitrary field', { isAdmin: true }],
  ]) {
    test(`rejects Organized Event create with ${name}`, () => assertFails(setDoc(doc(db(uid.creatorTask), 'gubs', 'g1', 'organizedEvents', `bad-${name}`), organizedEventData(`bad-${name}`, uid.creatorTask, overrides))));
  }
  test('assigned member completes and undoes only own inline assignment', async () => {
    await seed(['gubs', 'g1', 'organizedEvents', 'organized1'], organizedEventData());
    const completedAssignments = [assignment(uid.assigneeTask, { isCompleted: true, completedAt: timestamp() }), assignment(uid.secondMember)];
    const ref = doc(db(uid.assigneeTask), 'gubs', 'g1', 'organizedEvents', 'organized1');
    await assertSucceeds(updateDoc(ref, { assignments: completedAssignments, status: 'active', completedAt: null }));
    await assertSucceeds(updateDoc(ref, { assignments: organizedEventData().assignments, status: 'active', completedAt: null }));
  });
  test('uninvolved member cannot alter assignments or privilege-bearing fields', async () => {
    await seed(['gubs', 'g1', 'organizedEvents', 'organized1'], organizedEventData());
    await assertFails(updateDoc(doc(db(uid.uninvolvedMember), 'gubs', 'g1', 'organizedEvents', 'organized1'), {
      assignments: [assignment(uid.assigneeTask, { isCompleted: true, completedAt: timestamp() }), assignment(uid.secondMember)],
      status: 'active', completedAt: null,
    }));
    await assertFails(updateDoc(doc(db(uid.assigneeTask), 'gubs', 'g1', 'organizedEvents', 'organized1'), { createdBy: uid.assigneeTask }));
  });
  test('assigned member cannot alter another assignment or inject assignment fields', async () => {
    await seed(['gubs', 'g1', 'organizedEvents', 'organized1'], organizedEventData());
    const ref = doc(db(uid.assigneeTask), 'gubs', 'g1', 'organizedEvents', 'organized1');
    await assertFails(updateDoc(ref, {
      assignments: [assignment(uid.assigneeTask), assignment(uid.secondMember, { taskText: 'Forged task' })],
      status: 'active', completedAt: null,
    }));
    await assertFails(updateDoc(ref, {
      assignments: [assignment(uid.assigneeTask, { isCompleted: true, completedAt: timestamp(), isAdmin: true }), assignment(uid.secondMember)],
      status: 'active', completedAt: null,
    }));
  });
  test('creator and owner delete with cooldown; unrelated member cannot', async () => {
    for (const [actor, eventId] of [[uid.creatorTask, 'org-creator-delete'], [uid.ownerGub, 'org-owner-delete']]) {
      await seed(['gubs', 'g1', 'organizedEvents', eventId], organizedEventData(eventId));
      const clientDb = db(actor);
      await assertSucceeds(runTransaction(clientDb, async (tx) => {
        tx.delete(doc(clientDb, 'gubs', 'g1', 'organizedEvents', eventId));
        tx.set(doc(clientDb, 'gubs', 'g1', 'creationCooldowns', `${uid.creatorTask}_organizedEvent`), cooldownData(uid.creatorTask, 'organizedEvent', eventId, actor));
      }));
    }
    await seed(['gubs', 'g1', 'organizedEvents', 'org-denied'], organizedEventData('org-denied'));
    await assertFails(deleteDoc(doc(db(uid.uninvolvedMember), 'gubs', 'g1', 'organizedEvents', 'org-denied')));
  });
  test('Organized Event writes are denied while deleting', async () => {
    await markDeleting();
    await assertFails(setDoc(doc(db(uid.creatorTask), 'gubs', 'g1', 'organizedEvents', 'blocked'), organizedEventData('blocked')));
  });
});

describe('Proposals, votes, and client aggregates', () => {
  test('member creates exact manual and chat Proposal', async () => {
    await assertSucceeds(setDoc(doc(db(uid.creatorTask), 'gubs', 'g1', 'proposals', 'proposal1'), proposalData()));
    await seed(['gubs', 'g1', 'messages', 'message1'], { messageId: 'message1', gubId: 'g1', senderId: uid.assigneeTask, senderName: uid.assigneeTask, text: 'Propose this', createdAt: timestamp() });
    await assertSucceeds(setDoc(doc(db(uid.creatorTask), 'gubs', 'g1', 'proposals', 'proposal-chat'), proposalData('proposal-chat', uid.creatorTask, { sourceType: 'chat', sourceId: 'message1', sourcePreview: 'Propose this', originUserId: uid.assigneeTask, sourceAuthorName: uid.assigneeTask })));
  });
  test('members read Proposals; outsiders cannot read or create', async () => {
    await seed(['gubs', 'g1', 'proposals', 'proposal1'], proposalData());
    await assertSucceeds(getDoc(doc(db(uid.secondMember), 'gubs', 'g1', 'proposals', 'proposal1')));
    await assertFails(getDoc(doc(db(uid.outsider), 'gubs', 'g1', 'proposals', 'proposal1')));
    await assertFails(setDoc(doc(db(uid.outsider), 'gubs', 'g1', 'proposals', 'out'), proposalData('out', uid.outsider)));
  });
  for (const [name, overrides] of [
    ['forged creator', { creatorId: uid.ownerGub }],
    ['incoherent gubId', { gubId: 'other' }],
    ['incoherent proposalId', { proposalId: 'other' }],
    ['nonzero initial aggregates', { yesVotes: 1 }],
    ['unknown source', { sourceType: 'event' }],
    ['arbitrary field', { isAdmin: true }],
  ]) {
    test(`rejects Proposal create with ${name}`, () => assertFails(setDoc(doc(db(uid.creatorTask), 'gubs', 'g1', 'proposals', `bad-${name}`), proposalData(`bad-${name}`, uid.creatorTask, overrides))));
  }
  test('member creates own yes/no vote; outsider, anonymous, forged UID and value fail', async () => {
    await seed(['gubs', 'g1', 'proposals', 'proposal1'], proposalData());
    await assertSucceeds(setDoc(doc(db(uid.assigneeTask), 'gubs', 'g1', 'proposals', 'proposal1', 'votes', uid.assigneeTask), voteData(uid.assigneeTask, 'yes')));
    await assertSucceeds(setDoc(doc(db(uid.secondMember), 'gubs', 'g1', 'proposals', 'proposal1', 'votes', uid.secondMember), voteData(uid.secondMember, 'no')));
    await assertFails(setDoc(doc(db(uid.outsider), 'gubs', 'g1', 'proposals', 'proposal1', 'votes', uid.outsider), voteData(uid.outsider)));
    await assertFails(setDoc(doc(anonymousDb(), 'gubs', 'g1', 'proposals', 'proposal1', 'votes', 'anonymous'), voteData('anonymous')));
    await assertFails(setDoc(doc(db(uid.assigneeTask), 'gubs', 'g1', 'proposals', 'proposal1', 'votes', uid.secondMember), voteData(uid.secondMember)));
    await assertFails(setDoc(doc(db(uid.uninvolvedMember), 'gubs', 'g1', 'proposals', 'proposal1', 'votes', uid.uninvolvedMember), voteData(uid.uninvolvedMember, 'maybe')));
  });
  test('double vote, vote change, and vote delete are denied', async () => {
    await seed(['gubs', 'g1', 'proposals', 'proposal1'], proposalData());
    await seed(['gubs', 'g1', 'proposals', 'proposal1', 'votes', uid.assigneeTask], voteData(uid.assigneeTask));
    const ref = doc(db(uid.assigneeTask), 'gubs', 'g1', 'proposals', 'proposal1', 'votes', uid.assigneeTask);
    await assertFails(setDoc(ref, voteData(uid.assigneeTask, 'yes')));
    await assertFails(setDoc(ref, voteData(uid.assigneeTask, 'no')));
    await assertFails(deleteDoc(ref));
  });
  test('voter performs separate one-vote aggregate update used by client', async () => {
    await seed(['gubs', 'g1', 'proposals', 'proposal1'], proposalData());
    await seed(['gubs', 'g1', 'proposals', 'proposal1', 'votes', uid.assigneeTask], voteData(uid.assigneeTask, 'yes'));
    await assertSucceeds(updateDoc(doc(db(uid.assigneeTask), 'gubs', 'g1', 'proposals', 'proposal1'), { ...proposalData(), yesVotes: 1 }));
  });
  test('aggregate update without own vote, wrong delta, negative counts, and unrelated edits fail', async () => {
    await seed(['gubs', 'g1', 'proposals', 'proposal1'], proposalData());
    const ref = doc(db(uid.assigneeTask), 'gubs', 'g1', 'proposals', 'proposal1');
    await assertFails(updateDoc(ref, { ...proposalData(), yesVotes: 1 }));
    await seed(['gubs', 'g1', 'proposals', 'proposal1', 'votes', uid.assigneeTask], voteData(uid.assigneeTask, 'yes'));
    await assertFails(updateDoc(ref, { ...proposalData(), yesVotes: 2 }));
    await assertFails(updateDoc(ref, { ...proposalData(), yesVotes: -1 }));
    await assertFails(updateDoc(ref, { ...proposalData(), yesVotes: 1, title: 'Forged' }));
  });
  test('mathematically valid result transition and eventCreated flag are allowed only on approved Proposal', async () => {
    await seed(['gubs', 'g1', 'proposals', 'proposal1'], proposalData('proposal1', uid.creatorTask, { yesVotes: 3, noVotes: 0 }));
    await assertSucceeds(updateDoc(doc(db(uid.assigneeTask), 'gubs', 'g1', 'proposals', 'proposal1'), { ...proposalData('proposal1', uid.creatorTask, { yesVotes: 3, noVotes: 0 }), status: 'approved', resultProcessed: true, resolvedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(db(uid.assigneeTask), 'gubs', 'g1', 'proposals', 'proposal1'), { eventCreated: true }));
  });
  test('creator and owner soft-delete Proposal with cooldown; unauthorized member fails', async () => {
    for (const [actor, proposalId] of [[uid.creatorTask, 'proposal-delete-creator'], [uid.ownerGub, 'proposal-delete-owner']]) {
      await seed(['gubs', 'g1', 'proposals', proposalId], proposalData(proposalId));
      const clientDb = db(actor);
      await assertSucceeds(runTransaction(clientDb, async (tx) => {
        tx.update(doc(clientDb, 'gubs', 'g1', 'proposals', proposalId), { status: 'deleted', deletedAt: serverTimestamp(), deletedBy: actor });
        tx.set(doc(clientDb, 'gubs', 'g1', 'creationCooldowns', `${uid.creatorTask}_proposal`), cooldownData(uid.creatorTask, 'proposal', proposalId, actor));
      }));
    }
    await seed(['gubs', 'g1', 'proposals', 'proposal-denied'], proposalData('proposal-denied'));
    await assertFails(updateDoc(doc(db(uid.uninvolvedMember), 'gubs', 'g1', 'proposals', 'proposal-denied'), { status: 'deleted', deletedAt: serverTimestamp(), deletedBy: uid.uninvolvedMember }));
  });
  test('Proposal and vote writes are denied during deletion', async () => {
    await seed(['gubs', 'g1', 'proposals', 'proposal1'], proposalData());
    await markDeleting();
    await assertFails(setDoc(doc(db(uid.creatorTask), 'gubs', 'g1', 'proposals', 'blocked'), proposalData('blocked')));
    await assertFails(setDoc(doc(db(uid.assigneeTask), 'gubs', 'g1', 'proposals', 'proposal1', 'votes', uid.assigneeTask), voteData(uid.assigneeTask)));
  });
});

describe('Shared Budget goals, members, and contributions', () => {
  test('Gub owner creates exact manual and chat Shared Budget roots', async () => {
    await assertSucceeds(setDoc(doc(db(uid.ownerGub), 'gubs', 'g1', 'goals', 'goal1'), goalData()));
    await seed(['gubs', 'g1', 'messages', 'message1'], { messageId: 'message1', gubId: 'g1', senderId: uid.assigneeTask, senderName: uid.assigneeTask, text: 'Budget this', createdAt: timestamp() });
    await assertSucceeds(setDoc(doc(db(uid.ownerGub), 'gubs', 'g1', 'goals', 'goal-chat'), goalData('goal-chat', uid.ownerGub, { sourceType: 'chat', sourceId: 'message1', sourcePreview: 'Budget this', originUserId: uid.assigneeTask, sourceAuthorName: uid.assigneeTask })));
  });
  test('members read goals; non-owner and outsider cannot create', async () => {
    await seed(['gubs', 'g1', 'goals', 'goal1'], goalData());
    await assertSucceeds(getDoc(doc(db(uid.assigneeTask), 'gubs', 'g1', 'goals', 'goal1')));
    await assertFails(setDoc(doc(db(uid.creatorTask), 'gubs', 'g1', 'goals', 'member-goal'), goalData('member-goal', uid.creatorTask)));
    await assertFails(setDoc(doc(db(uid.outsider), 'gubs', 'g1', 'goals', 'out'), goalData('out', uid.outsider)));
  });
  for (const [name, overrides] of [
    ['forged owner', { ownerId: uid.creatorTask }],
    ['incoherent goalId', { goalId: 'other' }],
    ['invalid amount', { targetAmount: -1 }],
    ['nonzero initial progress', { currentAmount: 10 }],
    ['unknown source', { sourceType: 'proposal' }],
    ['wrong type', { targetAmount: '100' }],
    ['arbitrary field', { isAdmin: true }],
  ]) {
    test(`rejects Shared Budget create with ${name}`, () => assertFails(setDoc(doc(db(uid.ownerGub), 'gubs', 'g1', 'goals', `bad-${name}`), goalData(`bad-${name}`, uid.ownerGub, overrides))));
  }
  test('budget owner creates member documents only for real Gub members', async () => {
    await seed(['gubs', 'g1', 'goals', 'goal1'], goalData());
    await assertSucceeds(setDoc(doc(db(uid.ownerGub), 'gubs', 'g1', 'goals', 'goal1', 'members', uid.assigneeTask), goalMemberData(uid.assigneeTask)));
    await assertFails(setDoc(doc(db(uid.ownerGub), 'gubs', 'g1', 'goals', 'goal1', 'members', uid.outsider), goalMemberData(uid.outsider)));
    await assertFails(setDoc(doc(db(uid.ownerGub), 'gubs', 'g1', 'goals', 'goal1', 'members', uid.assigneeTask), goalMemberData(uid.ownerGub)));
  });
  test('member updates only own positive unconfirmed contribution', async () => {
    await seed(['gubs', 'g1', 'goals', 'goal1'], goalData());
    await seed(['gubs', 'g1', 'goals', 'goal1', 'members', uid.assigneeTask], goalMemberData(uid.assigneeTask));
    await assertSucceeds(updateDoc(doc(db(uid.assigneeTask), 'gubs', 'g1', 'goals', 'goal1', 'members', uid.assigneeTask), { amount: 25.5, confirmed: false, updatedAt: serverTimestamp(), confirmedAt: null }));
  });
  test('member cannot update another contribution, confirm self, forge identity, or use invalid amount', async () => {
    await seed(['gubs', 'g1', 'goals', 'goal1'], goalData());
    await seed(['gubs', 'g1', 'goals', 'goal1', 'members', uid.assigneeTask], goalMemberData(uid.assigneeTask));
    await seed(['gubs', 'g1', 'goals', 'goal1', 'members', uid.secondMember], goalMemberData(uid.secondMember));
    await assertFails(updateDoc(doc(db(uid.assigneeTask), 'gubs', 'g1', 'goals', 'goal1', 'members', uid.secondMember), { amount: 20, updatedAt: serverTimestamp() }));
    const ownRef = doc(db(uid.assigneeTask), 'gubs', 'g1', 'goals', 'goal1', 'members', uid.assigneeTask);
    await assertFails(updateDoc(ownRef, { confirmed: true, confirmedAt: serverTimestamp() }));
    await assertFails(updateDoc(ownRef, { uid: uid.ownerGub }));
    await assertFails(updateDoc(ownRef, { amount: -1, updatedAt: serverTimestamp() }));
  });
  test('Gub owner atomically confirms contribution and advances parent aggregate', async () => {
    await seed(['gubs', 'g1', 'goals', 'goal1'], goalData());
    await seed(['gubs', 'g1', 'goals', 'goal1', 'members', uid.assigneeTask], goalMemberData(uid.assigneeTask, { amount: 25 }));
    const clientDb = db(uid.ownerGub);
    await assertSucceeds(runTransaction(clientDb, async (tx) => {
      tx.update(doc(clientDb, 'gubs', 'g1', 'goals', 'goal1', 'members', uid.assigneeTask), { confirmed: true, confirmedAt: serverTimestamp() });
      tx.update(doc(clientDb, 'gubs', 'g1', 'goals', 'goal1'), { currentAmount: 25, completedMembers: 1 });
    }));
  });
  test('non-owner confirmation and inconsistent aggregate updates fail', async () => {
    await seed(['gubs', 'g1', 'goals', 'goal1'], goalData());
    await seed(['gubs', 'g1', 'goals', 'goal1', 'members', uid.assigneeTask], goalMemberData(uid.assigneeTask, { amount: 25 }));
    await assertFails(updateDoc(doc(db(uid.assigneeTask), 'gubs', 'g1', 'goals', 'goal1'), { currentAmount: 25, completedMembers: 1 }));
    await assertFails(updateDoc(doc(db(uid.ownerGub), 'gubs', 'g1', 'goals', 'goal1'), { currentAmount: 90, completedMembers: 4 }));
  });
  test('creator and Gub owner soft-delete Shared Budget with cooldown; unrelated member fails', async () => {
    await seed(['gubs', 'g1', 'goals', 'goal1'], goalData());
    const clientDb = db(uid.ownerGub);
    await assertSucceeds(runTransaction(clientDb, async (tx) => {
      tx.update(doc(clientDb, 'gubs', 'g1', 'goals', 'goal1'), { status: 'deleted', archived: true, deletedAt: serverTimestamp(), deletedBy: uid.ownerGub });
    }));
    await seed(['gubs', 'g1', 'goals', 'goal-denied'], goalData('goal-denied'));
    await assertFails(updateDoc(doc(db(uid.uninvolvedMember), 'gubs', 'g1', 'goals', 'goal-denied'), { status: 'deleted', archived: true, deletedAt: serverTimestamp(), deletedBy: uid.uninvolvedMember }));
  });
  test('Shared Budget writes are denied during deletion', async () => {
    await seed(['gubs', 'g1', 'goals', 'goal1'], goalData());
    await seed(['gubs', 'g1', 'goals', 'goal1', 'members', uid.assigneeTask], goalMemberData(uid.assigneeTask));
    await markDeleting();
    await assertFails(setDoc(doc(db(uid.ownerGub), 'gubs', 'g1', 'goals', 'blocked'), goalData('blocked')));
    await assertFails(updateDoc(doc(db(uid.assigneeTask), 'gubs', 'g1', 'goals', 'goal1', 'members', uid.assigneeTask), { amount: 10, updatedAt: serverTimestamp() }));
  });
});

describe('Notifications', () => {
  beforeEach(async () => seed(['gubs', 'g1', 'tasks', 'task1'], taskData()));
  test('valid task notification can be created by authoritative sender', async () => {
    await assertSucceeds(setDoc(doc(db(uid.creatorTask), 'gubs', 'g1', 'notifications', 'notification1'), notificationData('notification1', uid.creatorTask)));
  });
  test('all Gub members read Gub-level notifications; outsider cannot', async () => {
    await seed(['gubs', 'g1', 'notifications', 'notification1'], notificationData('notification1', uid.creatorTask));
    await assertSucceeds(getDoc(doc(db(uid.assigneeTask), 'gubs', 'g1', 'notifications', 'notification1')));
    await assertSucceeds(getDoc(doc(db(uid.uninvolvedMember), 'gubs', 'g1', 'notifications', 'notification1')));
    await assertFails(getDoc(doc(db(uid.outsider), 'gubs', 'g1', 'notifications', 'notification1')));
  });
  test('member marks only self read without changing content or another user state', async () => {
    await seed(['gubs', 'g1', 'notifications', 'notification1'], notificationData('notification1', uid.creatorTask));
    const ref = doc(db(uid.assigneeTask), 'gubs', 'g1', 'notifications', 'notification1');
    await assertSucceeds(updateDoc(ref, { readBy: [uid.creatorTask, uid.assigneeTask] }));
    await assertFails(updateDoc(ref, { readBy: [uid.creatorTask, uid.secondMember] }));
    await assertFails(updateDoc(ref, { title: 'Forged', readBy: [uid.creatorTask, uid.assigneeTask] }));
  });
  for (const [name, actor, overrides] of [
    ['forged sender', uid.assigneeTask, { senderId: uid.creatorTask }],
    ['unknown type', uid.creatorTask, { type: 'admin_granted' }],
    ['wrong notificationId', uid.creatorTask, { notificationId: 'other' }],
    ['arbitrary field', uid.creatorTask, { isAdmin: true }],
  ]) {
    test(`rejects notification with ${name}`, () => assertFails(setDoc(doc(db(actor), 'gubs', 'g1', 'notifications', `bad-${name}`), notificationData(`bad-${name}`, actor, 'task_created', overrides))));
  }
  test('outsider cannot create and normal delete is unsupported', async () => {
    await assertFails(setDoc(doc(db(uid.outsider), 'gubs', 'g1', 'notifications', 'out'), notificationData('out', uid.outsider)));
    await seed(['gubs', 'g1', 'notifications', 'notification1'], notificationData('notification1', uid.creatorTask));
    await assertFails(deleteDoc(doc(db(uid.creatorTask), 'gubs', 'g1', 'notifications', 'notification1')));
  });
  test('notification writes are denied during deletion', async () => {
    await markDeleting();
    await assertFails(setDoc(doc(db(uid.creatorTask), 'gubs', 'g1', 'notifications', 'blocked'), notificationData('blocked', uid.creatorTask)));
  });
});

describe('Creation cooldowns', () => {
  test('creator reads own cooldown; members may read cooldowns for availability UI', async () => {
    await seed(['gubs', 'g1', 'creationCooldowns', `${uid.creatorTask}_task`], cooldownData(uid.creatorTask, 'task', 'old-task', uid.ownerGub));
    await assertSucceeds(getDoc(doc(db(uid.creatorTask), 'gubs', 'g1', 'creationCooldowns', `${uid.creatorTask}_task`)));
    await assertSucceeds(getDoc(doc(db(uid.ownerGub), 'gubs', 'g1', 'creationCooldowns', `${uid.creatorTask}_task`)));
  });
  test('arbitrary direct cooldown create/update/delete is denied', async () => {
    const ref = doc(db(uid.creatorTask), 'gubs', 'g1', 'creationCooldowns', `${uid.creatorTask}_task`);
    await assertFails(setDoc(ref, cooldownData(uid.creatorTask, 'task', 'missing', uid.creatorTask)));
    await seed(['gubs', 'g1', 'creationCooldowns', `${uid.creatorTask}_task`], cooldownData(uid.creatorTask, 'task', 'old-task', uid.ownerGub));
    await assertFails(updateDoc(ref, { availableAt: timestamp() }));
    await assertFails(deleteDoc(ref));
  });
  test('rejects cooldown under wrong ID, forged creator, bad module, timestamp, and extra field', async () => {
    await seed(['gubs', 'g1', 'tasks', 'delete-me'], taskData('delete-me'));
    for (const [docId, data] of [
      ['wrong', cooldownData(uid.creatorTask, 'task', 'delete-me', uid.ownerGub)],
      [`${uid.creatorTask}_task`, cooldownData(uid.secondMember, 'task', 'delete-me', uid.ownerGub)],
      [`${uid.creatorTask}_bad`, cooldownData(uid.creatorTask, 'bad', 'delete-me', uid.ownerGub)],
      [`${uid.creatorTask}_task`, cooldownData(uid.creatorTask, 'task', 'delete-me', uid.ownerGub, { availableAt: 'later' })],
      [`${uid.creatorTask}_task`, cooldownData(uid.creatorTask, 'task', 'delete-me', uid.ownerGub, { extra: true })],
    ]) {
      await assertFails(setDoc(doc(db(uid.ownerGub), 'gubs', 'g1', 'creationCooldowns', docId), data));
    }
  });
  test('outsider cannot use cooldown collection and active writes stop during deletion', async () => {
    await assertFails(getDocs(collection(db(uid.outsider), 'gubs', 'g1', 'creationCooldowns')));
    await markDeleting();
    await assertFails(setDoc(doc(db(uid.creatorTask), 'gubs', 'g1', 'creationCooldowns', `${uid.creatorTask}_task`), cooldownData(uid.creatorTask, 'task', 'x', uid.creatorTask)));
  });
});

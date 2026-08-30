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
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-gubify-community-asks';
const t0 = new Date('2026-01-01T00:00:00Z');
const t1 = new Date('2026-01-02T00:00:00Z');
const t2 = new Date('2026-01-03T00:00:00Z');
const ids = { owner: 'owner', member: 'member', outsider: 'outsider' };
let env;

const db = (uid, provider = 'google.com') => env.authenticatedContext(uid, {
  firebase: { sign_in_provider: provider },
}).firestore();
const askRef = (uid, messageId = 'message-1', provider = 'google.com') =>
  doc(db(uid, provider), 'communities', 'c1', 'asks', messageId);
const activeAsks = (uid, provider = 'google.com') => query(
  collection(db(uid, provider), 'communities', 'c1', 'asks'),
  where('authorId', '==', ids.owner),
  where('status', '==', 'active'),
  orderBy('createdAt', 'desc'),
);
const askData = (overrides = {}) => ({
  askId: 'message-1',
  communityId: 'c1',
  authorId: ids.owner,
  authorDisplayName: 'Owner',
  type: 'help',
  sourceMessageId: 'message-1',
  text: 'Please help',
  createdAt: serverTimestamp(),
  status: 'active',
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
    batch.set(doc(database, 'communities', 'c1'), {
      communityId: 'c1',
      name: 'Community',
      ownerId: ids.owner,
      memberCount: 2,
      visibility: 'public',
      createdAt: t0,
      deletionStatus: 'active',
    });
    batch.set(doc(database, 'communities', 'c1', 'members', ids.owner), {
      uid: ids.owner,
      displayName: 'Owner',
      photoUrl: null,
      role: 'owner',
      joinedAt: t0,
    });
    batch.set(doc(database, 'communities', 'c1', 'members', ids.member), {
      uid: ids.member,
      displayName: 'Member',
      photoUrl: null,
      role: 'member',
      joinedAt: t2,
    });
    batch.set(doc(database, 'users', ids.owner), {
      displayName: 'Owner',
    });
    batch.set(doc(database, 'users', ids.member), {
      displayName: 'Member',
    });
    batch.set(doc(database, 'communities', 'c1', 'messages', 'message-1'), {
      messageId: 'message-1',
      communityId: 'c1',
      senderId: ids.owner,
      senderName: 'Owner',
      text: 'Please help',
      createdAt: t0,
    });
    batch.set(doc(database, 'communities', 'c1', 'asks', 'message-1'), {
      ...askData({ createdAt: t1 }),
    });
    await batch.commit();
  });
});

describe('Community active asks', () => {
  test('current linked member reads active asks created before joinedAt', async () => {
    await assertSucceeds(getDocs(activeAsks(ids.member)));
    await assertSucceeds(getDoc(askRef(ids.member)));
  });

  test('Firebase Anonymous member cannot read active asks', async () => {
    await assertFails(getDocs(activeAsks(ids.member, 'anonymous')));
    await assertFails(getDoc(askRef(ids.member, 'message-1', 'anonymous')));
  });

  test('outsider and removed member cannot read active asks', async () => {
    await assertFails(getDocs(activeAsks(ids.outsider)));
    await env.withSecurityRulesDisabled((context) => deleteDoc(
      doc(context.firestore(), 'communities', 'c1', 'members', ids.member),
    ));
    await assertFails(getDocs(activeAsks(ids.member)));
  });

  test('closed asks are not readable in Phase 1', async () => {
    await env.withSecurityRulesDisabled((context) => updateDoc(
      doc(context.firestore(), 'communities', 'c1', 'asks', 'message-1'),
      { status: 'closed' },
    ));
    await assertFails(getDoc(askRef(ids.member)));
  });

  test('linked author creates an ask from their own source message', async () => {
    await env.withSecurityRulesDisabled((context) => deleteDoc(
      doc(context.firestore(), 'communities', 'c1', 'asks', 'message-1'),
    ));
    await assertSucceeds(setDoc(askRef(ids.owner), askData()));
  });

  test('production transaction can read an absent deterministic ask before creating it', async () => {
    await env.withSecurityRulesDisabled((context) => deleteDoc(
      doc(context.firestore(), 'communities', 'c1', 'asks', 'message-1'),
    ));
    const ownerDb = db(ids.owner);
    await assertSucceeds(runTransaction(ownerDb, async (transaction) => {
      const target = doc(ownerDb, 'communities', 'c1', 'asks', 'message-1');
      const source = doc(ownerDb, 'communities', 'c1', 'messages', 'message-1');
      const existing = await transaction.get(target);
      if (existing.exists()) return false;
      await transaction.get(source);
      transaction.set(target, askData());
      return true;
    }));
  });

  test('another member cannot create an ask from the owner message', async () => {
    await env.withSecurityRulesDisabled((context) => deleteDoc(
      doc(context.firestore(), 'communities', 'c1', 'asks', 'message-1'),
    ));
    await assertFails(setDoc(askRef(ids.member), askData({ authorId: ids.member })));
  });

  test('Firebase Anonymous cannot create an ask', async () => {
    await env.withSecurityRulesDisabled((context) => deleteDoc(
      doc(context.firestore(), 'communities', 'c1', 'asks', 'message-1'),
    ));
    await assertFails(setDoc(askRef(ids.owner, 'message-1', 'anonymous'), askData()));
  });

  test('deterministic id, valid type and source snapshot are enforced', async () => {
    await assertFails(setDoc(askRef(ids.owner, 'other-id'), askData()));
    await env.withSecurityRulesDisabled((context) => deleteDoc(
      doc(context.firestore(), 'communities', 'c1', 'asks', 'message-1'),
    ));
    await assertFails(setDoc(askRef(ids.owner), askData({ type: 'reward' })));
    await assertFails(setDoc(askRef(ids.owner), askData({ text: 'Forged' })));
  });

  test('linked member creates a Direct Ask with an independent generated id', async () => {
    const directId = 'direct-generated-id';
    await assertSucceeds(setDoc(askRef(ids.member, directId), {
      askId: directId,
      communityId: 'c1',
      authorId: ids.member,
      authorDisplayName: 'Member',
      type: 'information',
      text: 'A direct ask',
      createdAt: serverTimestamp(),
      status: 'active',
    }));
  });

  test('anonymous, outsider, and removed members cannot create Direct Asks', async () => {
    const data = {
      askId: 'direct-denied',
      communityId: 'c1',
      authorId: ids.member,
      authorDisplayName: 'Member',
      type: 'advice',
      text: 'A direct ask',
      createdAt: serverTimestamp(),
      status: 'active',
    };
    await assertFails(setDoc(askRef(ids.member, 'direct-denied', 'anonymous'), data));
    await assertFails(setDoc(askRef(ids.outsider, 'direct-denied'), {
      ...data,
      authorId: ids.outsider,
    }));
    await env.withSecurityRulesDisabled((context) => deleteDoc(
      doc(context.firestore(), 'communities', 'c1', 'members', ids.member),
    ));
    await assertFails(setDoc(askRef(ids.member, 'direct-denied'), data));
  });

  test('Direct Ask identity, type, status, and text are validated', async () => {
    const base = {
      askId: 'direct-validation',
      communityId: 'c1',
      authorId: ids.member,
      authorDisplayName: 'Member',
      type: 'help',
      text: 'A direct ask',
      createdAt: serverTimestamp(),
      status: 'active',
    };
    await assertFails(setDoc(askRef(ids.member, 'different-id'), base));
    await assertFails(setDoc(askRef(ids.member, 'direct-validation'), {
      ...base,
      authorDisplayName: 'Forged',
    }));
    await assertFails(setDoc(askRef(ids.member, 'direct-validation'), {
      ...base,
      type: 'reward',
    }));
    await assertFails(setDoc(askRef(ids.member, 'direct-validation'), {
      ...base,
      status: 'closed',
    }));
    await assertFails(setDoc(askRef(ids.member, 'direct-validation'), {
      ...base,
      text: '   ',
    }));
  });

  test('existing ask cannot be overwritten or updated', async () => {
    await assertFails(setDoc(askRef(ids.owner), askData({ type: 'advice' })));
    await assertFails(updateDoc(askRef(ids.owner), { status: 'closed' }));
  });

  test('deleting owner can clean ask documents', async () => {
    await env.withSecurityRulesDisabled((context) => updateDoc(
      doc(context.firestore(), 'communities', 'c1'),
      {
        deletionStatus: 'deleting',
        deletionStartedAt: t2,
        deletionStartedBy: ids.owner,
        deletionAskedBy: ids.owner,
      },
    ));
    await assertSucceeds(deleteDoc(askRef(ids.owner)));
  });
});

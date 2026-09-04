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
  documentId,
  doc,
  getDoc,
  getDocs,
  limit,
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
const answerRef = (uid, answerId = 'answer-1', provider = 'google.com') =>
  doc(db(uid, provider), 'communities', 'c1', 'asks', 'message-1', 'answers', answerId);
const activeAsks = (uid, provider = 'google.com') => query(
  collection(db(uid, provider), 'communities', 'c1', 'asks'),
  where('authorId', '==', ids.owner),
  where('status', '==', 'active'),
  orderBy('createdAt', 'desc'),
);
const resolvedAsks = (uid, provider = 'google.com') => query(
  collection(db(uid, provider), 'communities', 'c1', 'asks'),
  where('status', '==', 'resolved'),
  orderBy('resolvedAt', 'desc'),
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
const activeAskSlotData = (askId, authorId) => ({
  askId,
  authorId,
  createdAt: serverTimestamp(),
});
const addAskCooldownUpdate = (batch, database, uid) => batch.update(
  doc(database, 'communities', 'c1', 'members', uid),
  { lastAskCreatedAt: serverTimestamp() },
);

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
    batch.set(doc(database, 'users', ids.owner, 'communities', 'c1'), {
      communityId: 'c1', name: 'Community', ownerId: ids.owner,
      memberCount: 2, visibility: 'public', role: 'owner', joinedAt: t0,
    });
    batch.set(doc(database, 'users', ids.member, 'communities', 'c1'), {
      communityId: 'c1', name: 'Community', ownerId: ids.owner,
      memberCount: 2, visibility: 'public', role: 'member', joinedAt: t2,
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
    batch.set(doc(database, 'communities', 'c1', 'activeAskSlots', ids.owner), {
      askId: 'message-1', authorId: ids.owner, createdAt: t1,
    });
    batch.set(doc(database, 'communities', 'c1', 'asks', 'message-1', 'answers', 'answer-1'), {
      answerId: 'answer-1', authorId: ids.member, authorDisplayName: 'Member',
      text: 'A useful answer', createdAt: t2,
    });
    await batch.commit();
  });
});

describe('Community active asks', () => {
  test('a linked member can query bounded global XP for projected members', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const database = context.firestore();
      await setDoc(doc(database, 'communityUserProgress', ids.owner), {
        xp: 120,
        communityIds: ['c1'],
      });
      await setDoc(doc(database, 'communityUserProgress', ids.member), {
        xp: 40,
        communityIds: ['c1'],
      });
    });
    const snapshot = await assertSucceeds(getDocs(query(
      collection(db(ids.member), 'communityUserProgress'),
      where('communityIds', 'array-contains', 'c1'),
      orderBy('xp', 'desc'),
      limit(5),
    )));
    assert.deepEqual(snapshot.docs.map((document) => document.id), [ids.owner, ids.member]);
  });

  test('global XP is linked-readable but cannot be written arbitrarily', async () => {
    await env.withSecurityRulesDisabled((context) => setDoc(
      doc(context.firestore(), 'communityUserProgress', ids.member),
      { xp: 40, updatedAt: t2 },
    ));
    await assertSucceeds(getDoc(doc(db(ids.owner), 'communityUserProgress', ids.member)));
    await assertFails(getDoc(doc(db(ids.owner, 'anonymous'), 'communityUserProgress', ids.member)));
    await assertFails(setDoc(doc(db(ids.member), 'communityUserProgress', ids.member), {
      xp: 1000, updatedAt: serverTimestamp(), lastRewardCommunityId: 'c1',
      lastRewardAskId: 'message-1', lastRewardRole: 'bestAnswer',
    }));
  });

  test('global XP deletion requires the atomic account profile cleanup', async () => {
    await env.withSecurityRulesDisabled((context) => setDoc(
      doc(context.firestore(), 'communityUserProgress', ids.member),
      { xp: 40, updatedAt: t2 },
    ));
    await assertFails(deleteDoc(
      doc(db(ids.member), 'communityUserProgress', ids.member),
    ));
    const memberDb = db(ids.member);
    const batch = writeBatch(memberDb);
    batch.delete(doc(memberDb, 'communityUserProgress', ids.member));
    batch.delete(doc(memberDb, 'users', ids.member));
    await assertSucceeds(batch.commit());
  });

  test('target Community copies expose only current mutual membership', async () => {
    await assertSucceeds(getDoc(
      doc(db(ids.member), 'users', ids.owner, 'communities', 'c1'),
    ));
    await assertSucceeds(getDocs(query(
      collection(db(ids.member), 'users', ids.owner, 'communities'),
      where(documentId(), 'in', ['c1']),
    )));
    await assertFails(getDoc(
      doc(db(ids.outsider), 'users', ids.owner, 'communities', 'c1'),
    ));
    await env.withSecurityRulesDisabled((context) => deleteDoc(
      doc(context.firestore(), 'communities', 'c1', 'members', ids.owner),
    ));
    await assertFails(getDoc(
      doc(db(ids.member), 'users', ids.owner, 'communities', 'c1'),
    ));
  });

  test('current linked member reads active asks created before joinedAt', async () => {
    await assertSucceeds(getDocs(activeAsks(ids.member)));
    await assertSucceeds(getDoc(askRef(ids.member)));
  });

  test('profile history collection-group query is limited to current mutual Communities', async () => {
    const history = (uid) => query(
      collectionGroup(db(uid), 'asks'),
      where('authorId', '==', ids.owner),
      where('status', '==', 'active'),
      where('communityId', 'in', ['c1']),
      orderBy('createdAt', 'desc'),
      limit(5),
    );
    await assertSucceeds(getDocs(history(ids.member)));
    await assertFails(getDocs(history(ids.outsider)));
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

  test('resolved ask remains readable by a current linked member', async () => {
    await env.withSecurityRulesDisabled((context) => updateDoc(
      doc(context.firestore(), 'communities', 'c1', 'asks', 'message-1'),
      { status: 'resolved', bestAnswerId: 'answer-1', bestAnswerAuthorId: ids.member, resolvedAt: t2, xpAwarded: true },
    ));
    await assertSucceeds(getDoc(askRef(ids.member)));
    await assertSucceeds(getDocs(resolvedAsks(ids.member)));
  });

  test('linked author creates an ask from their own source message', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const database = context.firestore();
      await deleteDoc(doc(database, 'communities', 'c1', 'asks', 'message-1'));
      await deleteDoc(doc(database, 'communities', 'c1', 'activeAskSlots', ids.owner));
    });
    const ownerDb = db(ids.owner);
    const batch = writeBatch(ownerDb);
    batch.set(doc(ownerDb, 'communities', 'c1', 'asks', 'message-1'), askData());
    batch.set(
      doc(ownerDb, 'communities', 'c1', 'activeAskSlots', ids.owner),
      activeAskSlotData('message-1', ids.owner),
    );
    addAskCooldownUpdate(batch, ownerDb, ids.owner);
    await assertSucceeds(batch.commit());
  });

  test('production transaction can read an absent deterministic ask before creating it', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const database = context.firestore();
      await deleteDoc(doc(database, 'communities', 'c1', 'asks', 'message-1'));
      await deleteDoc(doc(database, 'communities', 'c1', 'activeAskSlots', ids.owner));
    });
    const ownerDb = db(ids.owner);
    await assertSucceeds(runTransaction(ownerDb, async (transaction) => {
      const target = doc(ownerDb, 'communities', 'c1', 'asks', 'message-1');
      const source = doc(ownerDb, 'communities', 'c1', 'messages', 'message-1');
      const slot = doc(ownerDb, 'communities', 'c1', 'activeAskSlots', ids.owner);
      const existing = await transaction.get(target);
      if (existing.exists()) return false;
      await transaction.get(source);
      await transaction.get(slot);
      transaction.set(target, askData());
      transaction.set(slot, activeAskSlotData('message-1', ids.owner));
      transaction.update(doc(ownerDb, 'communities', 'c1', 'members', ids.owner), {
        lastAskCreatedAt: serverTimestamp(),
      });
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
    const memberDb = db(ids.member);
    const batch = writeBatch(memberDb);
    batch.set(doc(memberDb, 'communities', 'c1', 'asks', directId), {
      askId: directId,
      communityId: 'c1',
      authorId: ids.member,
      authorDisplayName: 'Member',
      type: 'information',
      text: 'A direct ask',
      createdAt: serverTimestamp(),
      status: 'active',
    });
    batch.set(
      doc(memberDb, 'communities', 'c1', 'activeAskSlots', ids.member),
      activeAskSlotData(directId, ids.member),
    );
    addAskCooldownUpdate(batch, memberDb, ids.member);
    await assertSucceeds(batch.commit());
  });

  test('active Ask creation requires a matching atomic author slot', async () => {
    const directId = 'direct-slot-required';
    await assertFails(setDoc(askRef(ids.member, directId), {
      askId: directId,
      communityId: 'c1',
      authorId: ids.member,
      authorDisplayName: 'Member',
      type: 'information',
      text: 'A direct ask',
      createdAt: serverTimestamp(),
      status: 'active',
    }));

    const memberDb = db(ids.member);
    const batch = writeBatch(memberDb);
    batch.set(doc(memberDb, 'communities', 'c1', 'asks', directId), {
      askId: directId,
      communityId: 'c1',
      authorId: ids.member,
      authorDisplayName: 'Member',
      type: 'information',
      text: 'A direct ask',
      createdAt: serverTimestamp(),
      status: 'active',
    });
    batch.set(doc(memberDb, 'communities', 'c1', 'activeAskSlots', ids.member), {
      askId: directId,
      authorId: ids.member,
      createdAt: serverTimestamp(),
    });
    addAskCooldownUpdate(batch, memberDb, ids.member);
    await assertSucceeds(batch.commit());

    const second = writeBatch(memberDb);
    second.set(doc(memberDb, 'communities', 'c1', 'asks', 'direct-second'), {
      askId: 'direct-second',
      communityId: 'c1',
      authorId: ids.member,
      authorDisplayName: 'Member',
      type: 'help',
      text: 'A second direct ask',
      createdAt: serverTimestamp(),
      status: 'active',
    });
    second.set(doc(memberDb, 'communities', 'c1', 'activeAskSlots', ids.member), {
      askId: 'direct-second',
      authorId: ids.member,
      createdAt: serverTimestamp(),
    });
    await assertFails(second.commit());
  });

  test('Ask creation requires the targeted atomic membership cooldown update', async () => {
    const directId = 'cooldown-update-required';
    const memberDb = db(ids.member);
    const batch = writeBatch(memberDb);
    batch.set(doc(memberDb, 'communities', 'c1', 'asks', directId), {
      askId: directId,
      communityId: 'c1',
      authorId: ids.member,
      authorDisplayName: 'Member',
      type: 'help',
      text: 'A direct ask',
      createdAt: serverTimestamp(),
      status: 'active',
    });
    batch.set(
      doc(memberDb, 'communities', 'c1', 'activeAskSlots', ids.member),
      activeAskSlotData(directId, ids.member),
    );
    await assertFails(batch.commit());
  });

  test('Ask cooldown is enforced and an expired timestamp permits a new Ask', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const database = context.firestore();
      await deleteDoc(doc(database, 'communities', 'c1', 'asks', 'message-1'));
      await deleteDoc(doc(database, 'communities', 'c1', 'activeAskSlots', ids.owner));
      await updateDoc(doc(database, 'communities', 'c1', 'members', ids.owner), {
        lastAskCreatedAt: new Date('2000-01-01T00:00:00Z'),
      });
    });
    const ownerDb = db(ids.owner);
    const batch = writeBatch(ownerDb);
    batch.set(doc(ownerDb, 'communities', 'c1', 'asks', 'message-1'), askData());
    batch.set(
      doc(ownerDb, 'communities', 'c1', 'activeAskSlots', ids.owner),
      activeAskSlotData('message-1', ids.owner),
    );
    addAskCooldownUpdate(batch, ownerDb, ids.owner);
    await assertSucceeds(batch.commit());

    await env.withSecurityRulesDisabled(async (context) => {
      const database = context.firestore();
      await deleteDoc(doc(database, 'communities', 'c1', 'asks', 'message-1'));
      await deleteDoc(doc(database, 'communities', 'c1', 'activeAskSlots', ids.owner));
    });
    const tooSoon = writeBatch(ownerDb);
    tooSoon.set(doc(ownerDb, 'communities', 'c1', 'asks', 'message-1'), askData());
    tooSoon.set(
      doc(ownerDb, 'communities', 'c1', 'activeAskSlots', ids.owner),
      activeAskSlotData('message-1', ids.owner),
    );
    addAskCooldownUpdate(tooSoon, ownerDb, ids.owner);
    await assertFails(tooSoon.commit());
  });

  test('standalone membership cooldown updates are denied', async () => {
    await assertFails(updateDoc(
      doc(db(ids.member), 'communities', 'c1', 'members', ids.member),
      { lastAskCreatedAt: serverTimestamp() },
    ));
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
      status: 'resolved',
    }));
    await assertFails(setDoc(askRef(ids.member, 'direct-validation'), {
      ...base,
      text: '   ',
    }));
  });

  test('Ask author edits only active Ask text and receives a server edit timestamp', async () => {
    await assertSucceeds(updateDoc(askRef(ids.owner), {
      text: 'Updated ask text',
      updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(askRef(ids.owner), {
      text: 'Updated Ask text again',
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(askRef(ids.member), {
      text: 'Forged update',
      updatedAt: serverTimestamp(),
    }));
    await env.withSecurityRulesDisabled((context) => updateDoc(
      doc(context.firestore(), 'communities', 'c1', 'asks', 'message-1'),
      { status: 'resolved' },
    ));
    await assertFails(updateDoc(askRef(ids.owner), {
      text: 'Resolved update',
      updatedAt: serverTimestamp(),
    }));
  });

  test('existing ask cannot be overwritten or have immutable fields changed', async () => {
    await assertFails(setDoc(askRef(ids.owner), askData({ type: 'advice' })));
    await assertFails(updateDoc(askRef(ids.owner), { authorId: ids.member }));
    await assertFails(updateDoc(askRef(ids.owner), { status: 'closed' }));
  });

  test('linked member creates and reads an Answer on an active Ask', async () => {
    await env.withSecurityRulesDisabled((context) => deleteDoc(
      doc(context.firestore(), 'communities', 'c1', 'asks', 'message-1', 'answers', ids.member),
    ));
    await assertSucceeds(setDoc(answerRef(ids.member, ids.member), {
      answerId: ids.member, authorId: ids.member, authorDisplayName: 'Member',
      text: 'Another answer', createdAt: serverTimestamp(),
    }));
    await assertSucceeds(getDoc(answerRef(ids.owner, ids.member)));
  });

  test('Ask author cannot create an Answer on their own Ask', async () => {
    await assertFails(setDoc(answerRef(ids.owner, ids.owner), {
      answerId: ids.owner, authorId: ids.owner, authorDisplayName: 'Owner',
      text: 'My own answer', createdAt: serverTimestamp(),
    }));
  });

  test('Answer document id must equal its author and blocks a second Answer', async () => {
    const memberDb = db(ids.member);
    const canonical = doc(
      memberDb,
      'communities',
      'c1',
      'asks',
      'message-1',
      'answers',
      ids.member,
    );
    await assertSucceeds(setDoc(canonical, {
      answerId: ids.member,
      authorId: ids.member,
      authorDisplayName: 'Member',
      text: 'My canonical Answer',
      createdAt: serverTimestamp(),
    }));
    await assertFails(setDoc(answerRef(ids.member, 'second-answer'), {
      answerId: 'second-answer',
      authorId: ids.member,
      authorDisplayName: 'Member',
      text: 'A second Answer',
      createdAt: serverTimestamp(),
    }));
  });

  test('Answer author can edit only once and only canonical fields', async () => {
    const memberAnswer = answerRef(ids.member, ids.member);
    await assertSucceeds(setDoc(memberAnswer, {
      answerId: ids.member,
      authorId: ids.member,
      authorDisplayName: 'Member',
      text: 'Original',
      createdAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(memberAnswer, { answerId: 'other' }));
    await assertFails(updateDoc(memberAnswer, { authorId: ids.owner }));
    await assertFails(updateDoc(memberAnswer, { authorDisplayName: 'Other' }));
    await assertFails(updateDoc(memberAnswer, { createdAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(memberAnswer, {
      text: 'Edited',
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(memberAnswer, {
      text: 'Edited twice',
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(answerRef(ids.owner, ids.member), {
      text: 'Forged edit',
      updatedAt: serverTimestamp(),
    }));
  });

  test('Answer author or Ask author can delete, except a selected Best Answer', async () => {
    const memberAnswer = answerRef(ids.member, ids.member);
    await assertSucceeds(setDoc(memberAnswer, {
      answerId: ids.member,
      authorId: ids.member,
      authorDisplayName: 'Member',
      text: 'Removable',
      createdAt: serverTimestamp(),
    }));
    await assertSucceeds(deleteDoc(memberAnswer));
    await assertSucceeds(setDoc(memberAnswer, {
      answerId: ids.member,
      authorId: ids.member,
      authorDisplayName: 'Member',
      text: 'Ask author can remove this',
      createdAt: serverTimestamp(),
    }));
    await assertSucceeds(deleteDoc(answerRef(ids.owner, ids.member)));
    await env.withSecurityRulesDisabled((context) => updateDoc(
      doc(context.firestore(), 'communities', 'c1', 'asks', 'message-1'),
      {
        status: 'resolved', bestAnswerId: 'answer-1', bestAnswerAuthorId: ids.member,
        resolvedAt: t2, xpAwarded: true,
      },
    ));
    await assertFails(deleteDoc(answerRef(ids.owner, 'answer-1')));
  });

  test('anonymous, outsider, removed member, spoofing, and Answer updates are denied', async () => {
    const payload = {
      answerId: 'denied', authorId: ids.member, authorDisplayName: 'Member',
      text: 'Answer', createdAt: serverTimestamp(),
    };
    await assertFails(setDoc(answerRef(ids.member, 'denied', 'anonymous'), payload));
    await assertFails(setDoc(answerRef(ids.outsider, 'denied'), { ...payload, authorId: ids.outsider }));
    await assertFails(setDoc(answerRef(ids.member, 'denied'), { ...payload, authorId: ids.owner }));
    await assertFails(setDoc(answerRef(ids.member, 'wrong-id'), { ...payload, answerId: 'different-id' }));
    await assertFails(updateDoc(answerRef(ids.member), { text: 'Edited' }));
    await env.withSecurityRulesDisabled((context) => deleteDoc(
      doc(context.firestore(), 'communities', 'c1', 'members', ids.member),
    ));
    await assertFails(setDoc(answerRef(ids.member, 'denied'), payload));
  });

  test('Answer creation is denied after resolution', async () => {
    await env.withSecurityRulesDisabled((context) => updateDoc(
      doc(context.firestore(), 'communities', 'c1', 'asks', 'message-1'),
      { status: 'resolved' },
    ));
    await assertFails(setDoc(answerRef(ids.member, 'late'), {
      answerId: 'late', authorId: ids.member, authorDisplayName: 'Member',
      text: 'Too late', createdAt: serverTimestamp(),
    }));
  });

  test('Ask author atomically resolves with exact winner and asker rewards', async () => {
    const ownerDb = db(ids.owner);
    const batch = writeBatch(ownerDb);
    batch.update(doc(ownerDb, 'communities', 'c1', 'asks', 'message-1'), {
      status: 'resolved', bestAnswerId: 'answer-1', bestAnswerAuthorId: ids.member,
      resolvedAt: serverTimestamp(), xpAwarded: true,
    });
    batch.delete(doc(ownerDb, 'communities', 'c1', 'activeAskSlots', ids.owner));
    batch.update(doc(ownerDb, 'communities', 'c1', 'members', ids.member), {
      bestAnswerCount: 1,
    });
    batch.set(doc(ownerDb, 'communityUserProgress', ids.member), {
      xp: 20, communityIds: ['c1'], updatedAt: serverTimestamp(), lastRewardCommunityId: 'c1',
      lastRewardAskId: 'message-1', lastRewardRole: 'bestAnswer',
    });
    batch.set(doc(ownerDb, 'communityUserProgress', ids.owner), {
      xp: 2, communityIds: ['c1'], updatedAt: serverTimestamp(), lastRewardCommunityId: 'c1',
      lastRewardAskId: 'message-1', lastRewardRole: 'askAuthor',
    });
    await assertSucceeds(batch.commit());
  });

  test('non-author, own Answer, missing reward, and arbitrary XP resolution are denied', async () => {
    const memberDb = db(ids.member);
    let batch = writeBatch(memberDb);
    batch.update(doc(memberDb, 'communities', 'c1', 'asks', 'message-1'), {
      status: 'resolved', bestAnswerId: 'answer-1', bestAnswerAuthorId: ids.member,
      resolvedAt: serverTimestamp(), xpAwarded: true,
    });
    await assertFails(batch.commit());

    const ownerDb = db(ids.owner);
    batch = writeBatch(ownerDb);
    batch.update(doc(ownerDb, 'communities', 'c1', 'asks', 'message-1'), {
      status: 'resolved', bestAnswerId: 'answer-1', bestAnswerAuthorId: ids.member,
      resolvedAt: serverTimestamp(), xpAwarded: true,
    });
    batch.update(doc(ownerDb, 'communities', 'c1', 'members', ids.member), {
      bestAnswerCount: 50,
    });
    batch.set(doc(ownerDb, 'communityUserProgress', ids.member), {
      xp: 10000, updatedAt: serverTimestamp(), lastRewardCommunityId: 'c1',
      lastRewardAskId: 'message-1', lastRewardRole: 'bestAnswer',
    });
    batch.set(doc(ownerDb, 'communityUserProgress', ids.owner), {
      xp: 2, updatedAt: serverTimestamp(), lastRewardCommunityId: 'c1',
      lastRewardAskId: 'message-1', lastRewardRole: 'askAuthor',
    });
    await assertFails(batch.commit());
  });

  test('Ask author cannot select their own Answer', async () => {
    await env.withSecurityRulesDisabled((context) => setDoc(
      doc(context.firestore(), 'communities', 'c1', 'asks', 'message-1', 'answers', 'owner-answer'),
      {
        answerId: 'owner-answer', authorId: ids.owner, authorDisplayName: 'Owner',
        text: 'My own answer', createdAt: t2,
      },
    ));

    const ownerDb = db(ids.owner);
    const batch = writeBatch(ownerDb);
    batch.update(doc(ownerDb, 'communities', 'c1', 'asks', 'message-1'), {
      status: 'resolved', bestAnswerId: 'owner-answer', bestAnswerAuthorId: ids.owner,
      resolvedAt: serverTimestamp(), xpAwarded: true,
    });
    batch.update(doc(ownerDb, 'communities', 'c1', 'members', ids.owner), {
      bestAnswerCount: 1,
    });
    batch.set(doc(ownerDb, 'communityUserProgress', ids.owner), {
      xp: 20, updatedAt: serverTimestamp(), lastRewardCommunityId: 'c1',
      lastRewardAskId: 'message-1', lastRewardRole: 'bestAnswer',
    });
    await assertFails(batch.commit());
  });

  test('removed Answer author cannot receive a Best Answer reward', async () => {
    await env.withSecurityRulesDisabled((context) => deleteDoc(
      doc(context.firestore(), 'communities', 'c1', 'members', ids.member),
    ));

    const ownerDb = db(ids.owner);
    const batch = writeBatch(ownerDb);
    batch.update(doc(ownerDb, 'communities', 'c1', 'asks', 'message-1'), {
      status: 'resolved', bestAnswerId: 'answer-1', bestAnswerAuthorId: ids.member,
      resolvedAt: serverTimestamp(), xpAwarded: true,
    });
    batch.set(doc(ownerDb, 'communities', 'c1', 'members', ids.member), {
      uid: ids.member, displayName: 'Member', role: 'member', joinedAt: t0,
      bestAnswerCount: 1,
    });
    batch.set(doc(ownerDb, 'communityUserProgress', ids.member), {
      xp: 20, updatedAt: serverTimestamp(), lastRewardCommunityId: 'c1',
      lastRewardAskId: 'message-1', lastRewardRole: 'bestAnswer',
    });
    batch.set(doc(ownerDb, 'communityUserProgress', ids.owner), {
      xp: 2, updatedAt: serverTimestamp(), lastRewardCommunityId: 'c1',
      lastRewardAskId: 'message-1', lastRewardRole: 'askAuthor',
    });
    await assertFails(batch.commit());
  });

  test('resolved Ask cannot be rewarded twice or returned to active', async () => {
    await env.withSecurityRulesDisabled((context) => updateDoc(
      doc(context.firestore(), 'communities', 'c1', 'asks', 'message-1'),
      { status: 'resolved', bestAnswerId: 'answer-1', bestAnswerAuthorId: ids.member, resolvedAt: t2, xpAwarded: true },
    ));
    await assertFails(updateDoc(askRef(ids.owner), { status: 'active' }));
    await assertFails(updateDoc(askRef(ids.owner), { bestAnswerId: 'other' }));
  });

  test('Ask author deletes active Ask only with its matching slot and can delete resolved Ask', async () => {
    await assertFails(deleteDoc(askRef(ids.owner)));
    const ownerDb = db(ids.owner);
    const batch = writeBatch(ownerDb);
    batch.delete(doc(ownerDb, 'communities', 'c1', 'asks', 'message-1'));
    batch.delete(doc(ownerDb, 'communities', 'c1', 'activeAskSlots', ids.owner));
    await assertSucceeds(batch.commit());

    await env.withSecurityRulesDisabled((context) => setDoc(
      doc(context.firestore(), 'communities', 'c1', 'asks', 'resolved-ask'),
      askData({
        askId: 'resolved-ask',
        sourceMessageId: 'message-1',
        status: 'resolved',
        bestAnswerId: 'answer-1',
        bestAnswerAuthorId: ids.member,
        resolvedAt: t2,
        xpAwarded: true,
      }),
    ));
    await assertSucceeds(deleteDoc(askRef(ids.owner, 'resolved-ask')));
  });

  test('deleting owner can clean Answer documents before Asks', async () => {
    await env.withSecurityRulesDisabled((context) => updateDoc(
      doc(context.firestore(), 'communities', 'c1'),
      { deletionStatus: 'deleting', deletionStartedAt: t2, deletionStartedBy: ids.owner, deletionRequestedBy: ids.owner },
    ));
    await assertFails(getDocs(
      collection(db(ids.member), 'communities', 'c1', 'asks'),
    ));
    await assertFails(getDocs(
      collection(db(ids.outsider), 'communities', 'c1', 'asks', 'message-1', 'answers'),
    ));
    await assertSucceeds(getDocs(
      collection(db(ids.owner), 'communities', 'c1', 'asks'),
    ));
    await assertSucceeds(getDocs(
      collection(db(ids.owner), 'communities', 'c1', 'asks', 'message-1', 'answers'),
    ));
    await assertSucceeds(deleteDoc(answerRef(ids.owner)));
    await assertSucceeds(deleteDoc(askRef(ids.owner)));
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

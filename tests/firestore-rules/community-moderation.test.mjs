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
  increment,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-gubify';
const ids = {
  owner: 'owner',
  member: 'member',
  target: 'target',
  outsider: 'outsider',
  other: 'other',
};
const joinedAt = new Date('2026-08-10T00:00:00Z');
const visibleMessageAt = new Date('2026-08-11T00:00:00Z');
const hiddenMessageAt = new Date('2026-08-09T00:00:00Z');
let env;

const db = (uid) => env.authenticatedContext(uid).firestore();
const reportRef = (uid, reportId) =>
  doc(db(uid), 'moderationReports', reportId);
const targetRef = (uid, targetKey) =>
  doc(db(uid), 'moderationTargets', targetKey);

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
    const firestore = context.firestore();
    await setDoc(doc(firestore, 'communities', 'c1'), {
      communityId: 'c1',
      name: 'Safe Community',
      ownerId: ids.owner,
      memberCount: 3,
      visibility: 'public',
      deletionStatus: 'active',
    });
    for (const [uid, name, role] of [
      [ids.owner, 'Owner', 'owner'],
      [ids.member, 'Member', 'member'],
      [ids.target, 'Target User', 'member'],
    ]) {
      await setDoc(doc(firestore, 'communities', 'c1', 'members', uid), {
        uid,
        displayName: name,
        photoUrl: null,
        role,
        joinedAt,
      });
    }
    await setDoc(doc(firestore, 'communities', 'c1', 'asks', 'ask-1'), {
      askId: 'ask-1', communityId: 'c1', authorId: ids.target,
      authorDisplayName: 'Target User', type: 'help', text: 'Ask text',
      createdAt: joinedAt, status: 'active',
    });
    await setDoc(doc(firestore, 'communities', 'c1', 'asks', 'ask-1', 'answers', 'target'), {
      answerId: 'target', authorId: ids.target,
      authorDisplayName: 'Target User', text: 'Answer text', createdAt: joinedAt,
    });
    await setDoc(doc(firestore, 'communities', 'c1', 'messages', 'community-message-1'), {
      messageId: 'community-message-1', communityId: 'c1', senderId: ids.target,
      senderName: 'Target User', text: 'Community message', createdAt: visibleMessageAt,
    });
    await setDoc(doc(firestore, 'communities', 'c1', 'messages', 'community-message-2'), {
      messageId: 'community-message-2', communityId: 'c1', senderId: ids.target,
      senderName: 'Target User', text: 'Second Community message', createdAt: visibleMessageAt,
    });
    await setDoc(doc(firestore, 'communities', 'c1', 'messages', 'community-message-hidden'), {
      messageId: 'community-message-hidden', communityId: 'c1', senderId: ids.target,
      senderName: 'Target User', text: 'Hidden Community message', createdAt: hiddenMessageAt,
    });
    await setDoc(doc(firestore, 'gubs', 'g1'), {
      name: 'Private Gub',
      ownerId: ids.owner,
      deletionStatus: 'active',
    });
    for (const [uid, displayName] of [
      [ids.owner, 'Gub Owner'],
      [ids.member, 'Gub Member'],
      [ids.target, 'Gub Target'],
    ]) {
      await setDoc(doc(firestore, 'gubs', 'g1', 'members', uid), {
        uid,
        displayName,
        role: uid === ids.owner ? 'owner' : 'member',
        joinedAt,
      });
    }
    await setDoc(doc(firestore, 'gubs', 'g1', 'messages', 'gub-message-1'), {
      messageId: 'gub-message-1', gubId: 'g1', senderId: ids.target,
      senderName: 'Gub Target', text: 'Private Gub message', createdAt: visibleMessageAt,
    });
    await setDoc(doc(firestore, 'gubs', 'g1', 'messages', 'gub-message-2'), {
      messageId: 'gub-message-2', gubId: 'g1', senderId: ids.target,
      senderName: 'Gub Target', text: 'Second private Gub message', createdAt: visibleMessageAt,
    });
    await setDoc(doc(firestore, 'gubs', 'g1', 'messages', 'gub-message-hidden'), {
      messageId: 'gub-message-hidden', gubId: 'g1', senderId: ids.target,
      senderName: 'Gub Target', text: 'Hidden private Gub message', createdAt: hiddenMessageAt,
    });
  });
});

const communityReport = (reporterId = ids.outsider, overrides = {}) => ({
  reportId: `community__c1__${reporterId}`,
  reporterId,
  communityId: 'c1',
  targetType: 'community',
  targetId: 'c1',
  reason: 'spam',
  details: '',
  createdAt: serverTimestamp(),
  status: 'open',
  communityNameSnapshot: 'Safe Community',
  ...overrides,
});

const userReport = (reporterId = ids.member, overrides = {}) => ({
  reportId: `user__c1__${ids.target}__${reporterId}`,
  reporterId,
  communityId: 'c1',
  targetType: 'user',
  targetId: ids.target,
  targetUserId: ids.target,
  reason: 'harassment_or_bullying',
  details: 'Repeated unwanted contact.',
  createdAt: serverTimestamp(),
  status: 'open',
  communityNameSnapshot: 'Safe Community',
  targetNameSnapshot: 'Target User',
  ...overrides,
});

const gubUserReport = (reporterId = ids.member, overrides = {}) => ({
  reportId: `user__gub__g1__${ids.target}__${reporterId}`,
  reporterId,
  gubId: 'g1',
  targetType: 'user',
  targetId: ids.target,
  targetUserId: ids.target,
  reason: 'harassment_or_bullying',
  details: 'Repeated unwanted contact.',
  createdAt: serverTimestamp(),
  status: 'open',
  gubNameSnapshot: 'Private Gub',
  targetNameSnapshot: 'Gub Target',
  ...overrides,
});

const gubMessageReport = (reporterId = ids.member, overrides = {}) => ({
  reportId: `message__gub__g1__gub-message-1__${reporterId}`,
  reporterId,
  gubId: 'g1',
  targetType: 'user',
  targetId: ids.target,
  targetUserId: ids.target,
  messageId: 'gub-message-1',
  reason: 'spam',
  details: '',
  createdAt: serverTimestamp(),
  status: 'open',
  gubNameSnapshot: 'Private Gub',
  targetNameSnapshot: 'Gub Target',
  contentSnapshot: 'Private Gub message',
  ...overrides,
});

const communityMessageReport = (reporterId = ids.member, overrides = {}) => ({
  reportId: `message__community__c1__community-message-1__${reporterId}`,
  reporterId,
  communityId: 'c1',
  targetType: 'user',
  targetId: ids.target,
  targetUserId: ids.target,
  messageId: 'community-message-1',
  reason: 'spam',
  details: '',
  createdAt: serverTimestamp(),
  status: 'open',
  communityNameSnapshot: 'Safe Community',
  targetNameSnapshot: 'Target User',
  contentSnapshot: 'Community message',
  ...overrides,
});

const submitReport = (uid, report) => {
  const clientDb = db(uid);
  const reportReference = doc(clientDb, 'moderationReports', report.reportId);
  const targetKey = report.targetType === 'ask'
    ? `ask__${report.communityId}__${report.targetId}`
    : report.targetType === 'answer'
      ? `answer__${report.communityId}__${report.askId}__${report.targetId}`
      : `${report.targetType}__${report.targetId}`;
  const targetReference = doc(clientDb, 'moderationTargets', targetKey);
  const targetNameSnapshot =
    report.targetType === 'community'
      ? report.communityNameSnapshot
      : report.targetNameSnapshot;

  return runTransaction(clientDb, async (transaction) => {
    const existingReport = await transaction.get(reportReference);
    if (existingReport.exists()) return false;

    transaction.set(reportReference, report);
    transaction.set(targetReference, {
      targetType: report.targetType,
      targetId: report.targetId,
      targetNameSnapshot,
      reportCount: increment(1),
      lastReportedAt: serverTimestamp(),
      lastReportId: report.reportId,
    }, { merge: true });
    return true;
  });
};

const moderationTargetKey = (report) => report.targetType === 'ask'
  ? `ask__${report.communityId}__${report.targetId}`
  : report.targetType === 'answer'
    ? `answer__${report.communityId}__${report.askId}__${report.targetId}`
    : `${report.targetType}__${report.targetId}`;

const submitInvalidReportBatch = (uid, report) => {
  const clientDb = db(uid);
  const batch = writeBatch(clientDb);
  const targetKey = moderationTargetKey(report);
  batch.set(doc(clientDb, 'moderationReports', report.reportId), report);
  batch.set(doc(clientDb, 'moderationTargets', targetKey), {
    targetType: report.targetType,
    targetId: report.targetId,
    targetNameSnapshot:
      report.targetType === 'community'
        ? report.communityNameSnapshot
        : report.targetNameSnapshot,
    reportCount: 1,
    lastReportedAt: serverTimestamp(),
    lastReportId: report.reportId,
  });
  return batch.commit();
};

const assertInvalidReportFailsAtomically = async (uid, report) => {
  const targetKey = moderationTargetKey(report);
  await assertFails(submitInvalidReportBatch(uid, report));
  await env.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    const [savedReport, savedTarget] = await Promise.all([
      getDoc(doc(firestore, 'moderationReports', report.reportId)),
      getDoc(doc(firestore, 'moderationTargets', targetKey)),
    ]);
    assert.equal(savedReport.exists(), false);
    assert.equal(savedTarget.exists(), false);
  });
};

const readTargetSummary = async (targetKey) => {
  let snapshot;
  await env.withSecurityRulesDisabled(async (context) => {
    snapshot = await getDoc(doc(context.firestore(), 'moderationTargets', targetKey));
  });
  return snapshot;
};

describe('central Community moderation reports', () => {
  test('first Community report creates its summary counter', async () => {
    const report = communityReport();
    await assertSucceeds(submitReport(ids.outsider, report));

    const summary = await readTargetSummary('community__c1');
    assert(summary.exists());
    assert.strictEqual(summary.data().reportCount, 1);
    assert.strictEqual(summary.data().targetNameSnapshot, 'Safe Community');
    assert.strictEqual(summary.data().lastReportId, report.reportId);
    assert.deepEqual(Object.keys(summary.data()).sort(), [
      'lastReportId',
      'lastReportedAt',
      'reportCount',
      'targetId',
      'targetNameSnapshot',
      'targetType',
    ]);
  });

  test('a second reporter increments the same Community summary', async () => {
    await assertSucceeds(submitReport(ids.outsider, communityReport()));
    const report = communityReport(ids.other);
    await assertSucceeds(submitReport(ids.other, report));

    const summary = await readTargetSummary('community__c1');
    assert.strictEqual(summary.data().reportCount, 2);
    assert.strictEqual(summary.data().lastReportId, report.reportId);
  });

  test('user reports share one global summary across Communities', async () => {
    const first = userReport();
    const second = userReport(ids.member, {
      reportId: `user__c2__${ids.target}__${ids.member}`,
      communityId: 'c2',
      communityNameSnapshot: 'Other Community',
    });
    await env.withSecurityRulesDisabled(async (context) => {
      const firestore = context.firestore();
      await setDoc(doc(firestore, 'communities', 'c2'), {
        communityId: 'c2',
        name: 'Other Community',
        ownerId: ids.owner,
        memberCount: 2,
        visibility: 'public',
        deletionStatus: 'active',
      });
      for (const [uid, displayName] of [
        [ids.member, 'Member'],
        [ids.target, 'Target User'],
      ]) {
        await setDoc(doc(firestore, 'communities', 'c2', 'members', uid), {
          uid,
          displayName,
          photoUrl: null,
          role: 'member',
          joinedAt,
        });
      }
    });

    await assertSucceeds(submitReport(ids.member, first));
    await assertSucceeds(submitReport(ids.member, second));

    const summary = await readTargetSummary(`user__${ids.target}`);
    assert.strictEqual(summary.data().reportCount, 2);
    assert.strictEqual(summary.data().targetId, ids.target);
    assert.strictEqual(summary.data().lastReportId, second.reportId);
  });

  test('owner cannot report their own Community', () =>
    assertFails(setDoc(reportRef(ids.owner, 'community__c1__owner'), communityReport(ids.owner))));

  test('spoofed reporterId is denied', () =>
    assertFails(setDoc(reportRef(ids.outsider, 'community__c1__outsider'), communityReport(ids.member))));

  test('unknown reason and extra fields are denied', async () => {
    await assertFails(setDoc(reportRef(ids.outsider, 'community__c1__outsider'), communityReport(ids.outsider, { reason: 'unknown' })));
    await assertFails(setDoc(reportRef(ids.outsider, 'community__c1__outsider'), communityReport(ids.outsider, { email: 'private@example.com' })));
  });

  test('reports cannot be updated, deleted or listed', async () => {
    const id = 'community__c1__outsider';
    await assertSucceeds(submitReport(ids.outsider, communityReport()));
    await assertFails(updateDoc(reportRef(ids.outsider, id), { status: 'closed' }));
    await assertFails(deleteDoc(reportRef(ids.outsider, id)));
    await assertFails(deleteDoc(targetRef(ids.outsider, 'community__c1')));
    await assertFails(getDoc(targetRef(ids.outsider, 'community__c1')));
    await assertFails(getDocs(collection(db(ids.outsider), 'moderationReports')));
    await assertFails(getDocs(collection(db(ids.outsider), 'moderationTargets')));
  });

  test('a report and its summary cannot be written independently', async () => {
    const report = communityReport();
    await assertFails(setDoc(reportRef(ids.outsider, report.reportId), report));
    await env.withSecurityRulesDisabled(async (context) => {
      const firestore = context.firestore();
      const savedReport = await getDoc(
        doc(firestore, 'moderationReports', report.reportId),
      );
      const savedSummary = await getDoc(
        doc(firestore, 'moderationTargets', 'community__c1'),
      );
      assert.equal(savedReport.exists(), false);
      assert.equal(savedSummary.exists(), false);
    });
  });

  test("another user cannot read a reporter's report", async () => {
    const id = 'community__c1__outsider';
    await assertSucceeds(submitReport(ids.outsider, communityReport()));
    await assertSucceeds(getDoc(reportRef(ids.outsider, id)));
    await assertFails(getDoc(reportRef(ids.other, id)));
  });

  test('duplicate deterministic report cannot overwrite the first', async () => {
    const id = 'community__c1__outsider';
    await assertSucceeds(submitReport(ids.outsider, communityReport()));
    await assertSucceeds(submitReport(ids.outsider, communityReport(ids.outsider, { details: 'Again' })));
    const summary = await readTargetSummary('community__c1');
    assert.strictEqual(summary.data().reportCount, 1);
    await assertFails(setDoc(reportRef(ids.outsider, id), communityReport(ids.outsider, { details: 'Again' })));
  });

  test('duplicate deterministic user report cannot overwrite the first', async () => {
    const id = 'user__c1__target__member';
    await assertSucceeds(submitReport(ids.member, userReport()));
    await assertFails(setDoc(reportRef(ids.member, id), userReport(ids.member, { details: 'Again' })));
  });

  test('arbitrary counter changes and standalone summary writes are denied', async () => {
    await assertSucceeds(submitReport(ids.outsider, communityReport()));
    const summary = targetRef(ids.outsider, 'community__c1');
    await assertFails(updateDoc(summary, { reportCount: 2 }));
    await assertFails(updateDoc(summary, { reportCount: 0 }));
    await assertFails(
      setDoc(targetRef(ids.member, 'community__c1'), {
        targetType: 'community',
        targetId: 'c1',
        targetNameSnapshot: 'Safe Community',
        reportCount: 1,
        lastReportedAt: serverTimestamp(),
        lastReportId: 'community__c1__member',
      }),
    );
  });

  test('forged lastReportId and mismatched target summary are denied', async () => {
    const report = communityReport();
    const clientDb = db(ids.outsider);
    const reportReference = doc(clientDb, 'moderationReports', report.reportId);
    const targetReference = doc(clientDb, 'moderationTargets', 'community__c1');
    await assertFails(
      runTransaction(clientDb, async (transaction) => {
        await transaction.get(reportReference);
        transaction.set(reportReference, report);
        transaction.set(targetReference, {
          targetType: 'community',
          targetId: 'c1',
          targetNameSnapshot: 'Safe Community',
          reportCount: 1,
          lastReportedAt: serverTimestamp(),
          lastReportId: 'community__c1__forged',
        });
      }),
    );
    await assertFails(
      runTransaction(clientDb, async (transaction) => {
        await transaction.get(reportReference);
        transaction.set(reportReference, report);
        transaction.set(targetReference, {
          targetType: 'community',
          targetId: 'other',
          targetNameSnapshot: 'Safe Community',
          reportCount: 1,
          lastReportedAt: serverTimestamp(),
          lastReportId: report.reportId,
        });
      }),
    );
  });

  test('unsupported report target types remain denied', () =>
    assertFails(
      submitReport(
        ids.outsider,
        communityReport(ids.outsider, {
          reportId: 'unsupported__c1__m1__outsider',
          targetType: 'unsupported',
          targetId: 'm1',
          targetNameSnapshot: 'Message',
        }),
      ),
    ));

  test('member can report another Community member', () =>
    assertSucceeds(submitReport(ids.member, userReport())));

  test('private Gub members and owners can report another Gub member', async () => {
    await assertSucceeds(submitReport(ids.member, gubUserReport()));
    await assertSucceeds(submitReport(ids.owner, gubUserReport(ids.owner)));
    const summary = await readTargetSummary(`user__${ids.target}`);
    assert.strictEqual(summary.data().reportCount, 2);
    assert.strictEqual(summary.data().lastReportId, `user__gub__g1__${ids.target}__${ids.owner}`);
  });

  test('Community and private Gub user reports aggregate on one global target', async () => {
    await assertSucceeds(submitReport(ids.member, userReport()));
    await assertSucceeds(submitReport(ids.member, gubUserReport()));
    const summary = await readTargetSummary(`user__${ids.target}`);
    assert.strictEqual(summary.data().reportCount, 2);
    assert.strictEqual(summary.data().lastReportId, `user__gub__g1__${ids.target}__${ids.member}`);
  });

  test('invalid private Gub user reports are denied', async () => {
    await assertFails(submitReport(ids.outsider, gubUserReport(ids.outsider)));
    await assertFails(submitReport(ids.member, gubUserReport(ids.member, {
      reporterId: ids.other,
    })));
    await assertFails(submitReport(ids.member, gubUserReport(ids.member, {
      targetId: ids.other,
      targetUserId: ids.other,
      reportId: `user__gub__g1__${ids.other}__${ids.member}`,
    })));
    await assertFails(submitReport(ids.target, gubUserReport(ids.target, {
      targetId: ids.target,
      targetUserId: ids.target,
      reportId: `user__gub__g1__${ids.target}__${ids.target}`,
    })));
    await assertFails(submitReport(ids.member, gubUserReport(ids.member, {
      reportId: `user__gub__g1__${ids.target}__wrong`,
    })));
    await assertFails(submitReport(ids.member, gubUserReport(ids.member, {
      gubNameSnapshot: 'Forged Gub',
    })));
    await assertFails(submitReport(ids.member, gubUserReport(ids.member, {
      targetNameSnapshot: 'Forged Target',
    })));
    await assertFails(submitReport(ids.member, gubUserReport(ids.member, {
      reason: 'unsupported',
    })));
    await assertFails(submitReport(ids.member, gubUserReport(ids.member, {
      details: 'x'.repeat(501),
    })));
    await assertFails(submitReport(ids.member, gubUserReport(ids.member, {
      extra: 'field',
    })));
  });

  test('private Gub reports retain atomic duplicate and privacy protections', async () => {
    const report = gubUserReport();
    await assertFails(setDoc(reportRef(ids.member, report.reportId), report));
    await assertSucceeds(submitReport(ids.member, report));
    await assertFails(setDoc(reportRef(ids.member, report.reportId), report));
    const summary = await readTargetSummary(`user__${ids.target}`);
    assert.strictEqual(summary.data().reportCount, 1);
    await assertSucceeds(getDoc(reportRef(ids.member, report.reportId)));
    await assertFails(getDoc(reportRef(ids.other, report.reportId)));
  });

  test('private Gub and Community message reports aggregate on the author target', async () => {
    await assertSucceeds(submitReport(ids.member, gubMessageReport()));
    await assertSucceeds(submitReport(ids.member, communityMessageReport()));

    const summary = await readTargetSummary(`user__${ids.target}`);
    assert.strictEqual(summary.data().reportCount, 2);
    assert.strictEqual(summary.data().targetType, 'user');
    assert.strictEqual(summary.data().targetId, ids.target);
  });

  test('Report User and distinct message reports share the global user target', async () => {
    await assertSucceeds(submitReport(ids.member, gubUserReport()));
    await assertSucceeds(submitReport(ids.member, communityMessageReport()));
    await assertSucceeds(submitReport(ids.member, gubMessageReport(ids.member, {
      reportId: `message__gub__g1__gub-message-2__${ids.member}`,
      messageId: 'gub-message-2',
      contentSnapshot: 'Second private Gub message',
    })));

    const summary = await readTargetSummary(`user__${ids.target}`);
    assert.strictEqual(summary.data().reportCount, 3);
  });

  test('invalid private Gub message reports are denied', async () => {
    await assertInvalidReportFailsAtomically(ids.target, gubMessageReport(ids.target, {
      reportId: `message__gub__g1__gub-message-1__${ids.target}`,
      reporterId: ids.target,
    }));
    await assertInvalidReportFailsAtomically(ids.member, gubMessageReport(ids.member, { targetId: ids.other }));
    await assertInvalidReportFailsAtomically(ids.member, gubMessageReport(ids.member, { targetUserId: ids.other }));
    await assertInvalidReportFailsAtomically(ids.member, gubMessageReport(ids.member, { contentSnapshot: 'Forged' }));
    await assertInvalidReportFailsAtomically(ids.member, gubMessageReport(ids.member, { targetNameSnapshot: 'Forged' }));
    await assertInvalidReportFailsAtomically(ids.member, gubMessageReport(ids.member, { gubNameSnapshot: 'Forged' }));
    await assertInvalidReportFailsAtomically(ids.member, gubMessageReport(ids.member, {
      reportId: `message__gub__g1__missing__${ids.member}`,
      messageId: 'missing',
    }));
    await assertInvalidReportFailsAtomically(ids.member, gubMessageReport(ids.member, {
      reportId: `message__gub__g1__other-gub-message__${ids.member}`,
      messageId: 'other-gub-message',
    }));
    await assertInvalidReportFailsAtomically(ids.outsider, gubMessageReport(ids.outsider));
    await assertInvalidReportFailsAtomically(ids.member, gubMessageReport(ids.member, {
      reportId: `message__gub__g1__gub-message-hidden__${ids.member}`,
      messageId: 'gub-message-hidden',
      contentSnapshot: 'Hidden private Gub message',
    }));
    await assertInvalidReportFailsAtomically(ids.member, gubMessageReport(ids.member, { reason: 'invalid' }));
    await assertInvalidReportFailsAtomically(ids.member, gubMessageReport(ids.member, { details: 'x'.repeat(501) }));
    await assertInvalidReportFailsAtomically(ids.member, gubMessageReport(ids.member, { status: 'closed' }));
    await assertInvalidReportFailsAtomically(ids.member, gubMessageReport(ids.member, { createdAt: visibleMessageAt }));
    await assertInvalidReportFailsAtomically(ids.member, gubMessageReport(ids.member, { reportId: 'wrong' }));
  });

  test('forged Community message sender, target, content, and names are denied', async () => {
    await assertInvalidReportFailsAtomically(ids.target, communityMessageReport(ids.target, {
      reportId: `message__community__c1__community-message-1__${ids.target}`,
      reporterId: ids.target,
    }));
    await assertInvalidReportFailsAtomically(ids.member, communityMessageReport(ids.member, { targetId: ids.other }));
    await assertInvalidReportFailsAtomically(ids.member, communityMessageReport(ids.member, { targetUserId: ids.other }));
    await assertInvalidReportFailsAtomically(ids.member, communityMessageReport(ids.member, { contentSnapshot: 'Forged' }));
    await assertInvalidReportFailsAtomically(ids.member, communityMessageReport(ids.member, { targetNameSnapshot: 'Forged' }));
    await assertInvalidReportFailsAtomically(ids.member, communityMessageReport(ids.member, { communityNameSnapshot: 'Forged' }));
  });

  test('invalid Community membership, message IDs, and history access are denied', async () => {
    await assertInvalidReportFailsAtomically(ids.member, communityMessageReport(ids.member, {
      reportId: `message__community__c1__missing__${ids.member}`,
      messageId: 'missing',
    }));
    await assertInvalidReportFailsAtomically(ids.member, communityMessageReport(ids.member, {
      reportId: `message__community__c1__other-community-message__${ids.member}`,
      messageId: 'other-community-message',
    }));
    await assertInvalidReportFailsAtomically(ids.outsider, communityMessageReport(ids.outsider));
    await assertInvalidReportFailsAtomically(ids.member, communityMessageReport(ids.member, {
      reportId: `message__community__c1__community-message-hidden__${ids.member}`,
      messageId: 'community-message-hidden',
      contentSnapshot: 'Hidden Community message',
    }));
  });

  test('invalid Community message report reason, details, and status are denied', async () => {
    await assertInvalidReportFailsAtomically(ids.member, communityMessageReport(ids.member, { reason: 'invalid' }));
    await assertInvalidReportFailsAtomically(ids.member, communityMessageReport(ids.member, { details: 'x'.repeat(501) }));
    await assertInvalidReportFailsAtomically(ids.member, communityMessageReport(ids.member, { status: 'closed' }));
  });

  test('client-controlled Community message report timestamp is denied', async () => {
    await assertInvalidReportFailsAtomically(ids.member, communityMessageReport(ids.member, { createdAt: visibleMessageAt }));
  });

  test('non-deterministic Community message report ID is denied', async () => {
    await assertInvalidReportFailsAtomically(ids.member, communityMessageReport(ids.member, { reportId: 'wrong' }));
  });

  test('a duplicate message report cannot overwrite or increment its target twice', async () => {
    const report = gubMessageReport();
    await assertSucceeds(submitReport(ids.member, report));
    await assertFails(setDoc(reportRef(ids.member, report.reportId), {
      ...report,
      details: 'Overwrite',
    }));
    const summary = await readTargetSummary(`user__${ids.target}`);
    assert.strictEqual(summary.data().reportCount, 1);
  });

  test('member can report an Ask with an authoritative content snapshot', () =>
    assertSucceeds(submitReport(ids.member, {
      reportId: 'ask__c1__ask-1__member', reporterId: ids.member,
      communityId: 'c1', targetType: 'ask', targetId: 'ask-1',
      targetUserId: ids.target, reason: 'spam', details: '',
      createdAt: serverTimestamp(), status: 'open',
      communityNameSnapshot: 'Safe Community', targetNameSnapshot: 'Target User',
      contentSnapshot: 'Ask text',
    })));

  test('member can report an Answer using the full Community and Ask key', async () => {
    const report = {
      reportId: 'answer__c1__ask-1__target__member', reporterId: ids.member,
      communityId: 'c1', askId: 'ask-1', targetType: 'answer', targetId: ids.target,
      targetUserId: ids.target, reason: 'spam', details: '',
      createdAt: serverTimestamp(), status: 'open',
      communityNameSnapshot: 'Safe Community', targetNameSnapshot: 'Target User',
      contentSnapshot: 'Answer text',
    };
    await assertSucceeds(submitReport(ids.member, report));
    const summary = await readTargetSummary('answer__c1__ask-1__target');
    assert.strictEqual(summary.data().reportCount, 1);
  });

  test('forged Ask/Answer report content and self reports are denied', async () => {
    const base = {
      reportId: 'ask__c1__ask-1__member', reporterId: ids.member,
      communityId: 'c1', targetType: 'ask', targetId: 'ask-1',
      targetUserId: ids.target, reason: 'spam', details: '',
      createdAt: serverTimestamp(), status: 'open',
      communityNameSnapshot: 'Safe Community', targetNameSnapshot: 'Target User',
      contentSnapshot: 'Ask text',
    };
    await assertFails(submitReport(ids.member, { ...base, contentSnapshot: 'forged' }));
    await assertFails(submitReport(ids.target, {
      ...base, reportId: 'ask__c1__ask-1__target', reporterId: ids.target,
      targetUserId: ids.target,
    }));
  });

  test('user cannot report self', () =>
    assertFails(setDoc(reportRef(ids.member, 'user__c1__member__member'), userReport(ids.member, { reportId: 'user__c1__member__member', targetId: ids.member, targetUserId: ids.member, targetNameSnapshot: 'Member' }))));

  test('outsider cannot report an arbitrary Community user', () =>
    assertFails(setDoc(reportRef(ids.outsider, 'user__c1__target__outsider'), userReport(ids.outsider))));

  test('forged target name and uid are denied', async () => {
    await assertFails(setDoc(reportRef(ids.member, 'user__c1__target__member'), userReport(ids.member, { targetNameSnapshot: 'Forged' })));
    await assertFails(setDoc(reportRef(ids.member, 'user__c1__other__member'), userReport(ids.member, { reportId: 'user__c1__other__member', targetId: ids.other, targetUserId: ids.other })));
  });

});

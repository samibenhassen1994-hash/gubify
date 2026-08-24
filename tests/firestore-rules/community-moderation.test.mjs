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

const submitReport = (uid, report) => {
  const clientDb = db(uid);
  const reportReference = doc(clientDb, 'moderationReports', report.reportId);
  const targetKey = `${report.targetType}__${report.targetId}`;
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

  test('user cannot report self', () =>
    assertFails(setDoc(reportRef(ids.member, 'user__c1__member__member'), userReport(ids.member, { reportId: 'user__c1__member__member', targetId: ids.member, targetUserId: ids.member, targetNameSnapshot: 'Member' }))));

  test('outsider cannot report an arbitrary Community user', () =>
    assertFails(setDoc(reportRef(ids.outsider, 'user__c1__target__outsider'), userReport(ids.outsider))));

  test('forged target name and uid are denied', async () => {
    await assertFails(setDoc(reportRef(ids.member, 'user__c1__target__member'), userReport(ids.member, { targetNameSnapshot: 'Forged' })));
    await assertFails(setDoc(reportRef(ids.member, 'user__c1__other__member'), userReport(ids.member, { reportId: 'user__c1__other__member', targetId: ids.other, targetUserId: ids.other })));
  });

});

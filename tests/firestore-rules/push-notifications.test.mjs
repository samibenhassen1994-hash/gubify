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
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const projectId = 'demo-gubify-push-notifications';
const ids = {
  owner: 'owner',
  other: 'other',
};
const createdAt = new Date('2026-09-19T12:00:00Z');

let env;
const db = (uid) => env.authenticatedContext(uid).firestore();
const deviceDocument = (actor, owner = actor, deviceId = 'device-1') =>
  doc(db(actor), 'users', owner, 'devices', deviceId);
const inboxDocument = (actor, owner = actor, notificationId = 'notification-1') =>
  doc(db(actor), 'users', owner, 'pushNotifications', notificationId);

const deviceData = (overrides = {}) => ({
  deviceId: 'device-1',
  token: 'fcm-registration-token',
  platform: 'android',
  updatedAt: serverTimestamp(),
  ...overrides,
});

const inboxData = (overrides = {}) => ({
  id: 'notification-1',
  eventKey: 'task_assigned__gub-1__task-1',
  type: 'task_assigned',
  title: 'Task assigned',
  body: 'A task was assigned to you.',
  createdAt,
  read: false,
  actorId: 'actor-1',
  data: { gubId: 'gub-1', taskId: 'task-1' },
  ...overrides,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});

after(async () => env.cleanup());
beforeEach(async () => env.clearFirestore());

async function seed(path, data) {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), path), data);
  });
}

describe('device registrations', () => {
  test('an owner can create, get, list, update, and delete a registration', async () => {
    const reference = deviceDocument(ids.owner);
    await assertSucceeds(setDoc(reference, deviceData()));
    await assertSucceeds(getDoc(reference));
    await assertSucceeds(
      getDocs(collection(db(ids.owner), 'users', ids.owner, 'devices')),
    );
    await assertSucceeds(
      updateDoc(reference, {
        token: 'refreshed-fcm-registration-token',
        platform: 'ios',
        updatedAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(deleteDoc(reference));
  });

  test('create requires the exact schema, path identity, bounded token, platform, and server time', async () => {
    const reference = deviceDocument(ids.owner);
    const { updatedAt: _, ...missingUpdatedAt } = deviceData();
    const invalidRegistrations = [
      missingUpdatedAt,
      deviceData({ forged: true }),
      deviceData({ deviceId: 'another-device' }),
      deviceData({ token: '' }),
      deviceData({ token: '   ' }),
      deviceData({ token: 'x'.repeat(4097) }),
      deviceData({ platform: 'web' }),
      deviceData({ updatedAt: createdAt }),
    ];

    for (const registration of invalidRegistrations) {
      await assertFails(setDoc(reference, registration));
    }
  });

  test('update preserves the exact valid device schema', async () => {
    await seed('users/owner/devices/device-1', {
      ...deviceData(),
      updatedAt: createdAt,
    });
    const reference = deviceDocument(ids.owner);

    await assertFails(updateDoc(reference, { forged: true, updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(reference, { deviceId: 'another-device', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(reference, { token: '', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(reference, { platform: 'web', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(reference, { updatedAt: createdAt }));
  });

  test('other and unauthenticated users cannot access a registration', async () => {
    await seed('users/owner/devices/device-1', {
      ...deviceData(),
      updatedAt: createdAt,
    });
    const otherReference = deviceDocument(ids.other, ids.owner);

    await assertFails(getDoc(otherReference));
    await assertFails(
      getDocs(collection(db(ids.other), 'users', ids.owner, 'devices')),
    );
    await assertFails(setDoc(deviceDocument(ids.other, ids.owner, 'device-2'), {
      ...deviceData({ deviceId: 'device-2' }),
    }));
    await assertFails(updateDoc(otherReference, {
      token: 'stolen-token',
      updatedAt: serverTimestamp(),
    }));
    await assertFails(deleteDoc(otherReference));
    await assertFails(
      getDoc(doc(env.unauthenticatedContext().firestore(), 'users', ids.owner, 'devices', 'device-1')),
    );
  });

  test('account deletion blocks create and update but permits owner cleanup', async () => {
    await seed('users/owner/devices/device-1', {
      ...deviceData(),
      updatedAt: createdAt,
    });
    await seed('accountDeletionStates/owner', {
      userId: ids.owner,
      status: 'deleting',
      startedAt: createdAt,
    });

    await assertFails(setDoc(deviceDocument(ids.owner, ids.owner, 'device-2'), {
      ...deviceData({ deviceId: 'device-2' }),
    }));
    await assertFails(updateDoc(deviceDocument(ids.owner), {
      token: 'refreshed-token',
      updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(getDoc(deviceDocument(ids.owner)));
    await assertSucceeds(deleteDoc(deviceDocument(ids.owner)));
  });
});

describe('global notification inbox', () => {
  test('an owner can get and list their inbox', async () => {
    await seed('users/owner/pushNotifications/notification-1', inboxData());
    await seed('users/owner/pushNotifications/notification-2', inboxData({
      id: 'notification-2',
      eventKey: 'proposal_created__gub-1__proposal-1',
    }));

    await assertSucceeds(getDoc(inboxDocument(ids.owner)));
    const snapshot = await assertSucceeds(
      getDocs(collection(db(ids.owner), 'users', ids.owner, 'pushNotifications')),
    );
    assert.equal(snapshot.size, 2);
  });

  test('other and unauthenticated users cannot read an inbox', async () => {
    await seed('users/owner/pushNotifications/notification-1', inboxData());

    await assertFails(getDoc(inboxDocument(ids.other, ids.owner)));
    await assertFails(
      getDocs(collection(db(ids.other), 'users', ids.owner, 'pushNotifications')),
    );
    await assertFails(
      getDoc(doc(env.unauthenticatedContext().firestore(), 'users', ids.owner, 'pushNotifications', 'notification-1')),
    );
  });

  test('clients cannot create or delete inbox documents', async () => {
    await assertFails(setDoc(inboxDocument(ids.owner), inboxData()));
    await seed('users/owner/pushNotifications/notification-1', inboxData());
    await assertFails(deleteDoc(inboxDocument(ids.owner)));
  });

  test('an owner can change read exactly from false to true', async () => {
    await seed('users/owner/pushNotifications/notification-1', inboxData());
    const reference = inboxDocument(ids.owner);

    await assertSucceeds(updateDoc(reference, { read: true }));
    assert.equal((await getDoc(reference)).data().read, true);
  });

  test('read cannot move in any direction except false to true', async () => {
    await seed('users/owner/pushNotifications/notification-1', inboxData());
    const reference = inboxDocument(ids.owner);

    await assertFails(updateDoc(reference, { read: false }));
    await env.withSecurityRulesDisabled((context) =>
      updateDoc(doc(context.firestore(), 'users/owner/pushNotifications/notification-1'), { read: true }),
    );
    await assertFails(updateDoc(reference, { read: false }));
    await assertFails(updateDoc(reference, { read: true }));
  });

  test('every field other than read is immutable', async () => {
    await seed('users/owner/pushNotifications/notification-1', inboxData());
    const reference = inboxDocument(ids.owner);
    const mutations = [
      { id: 'forged-notification', read: true },
      { eventKey: 'forged-event', read: true },
      { type: 'forged-type', read: true },
      { title: 'Forged title', read: true },
      { body: 'Forged body', read: true },
      { createdAt: new Date('2026-09-20T12:00:00Z'), read: true },
      { actorId: 'forged-actor', read: true },
      { data: { gubId: 'forged-gub' }, read: true },
      { forged: true, read: true },
    ];

    for (const mutation of mutations) {
      await assertFails(updateDoc(reference, mutation));
    }
  });

  test('another user cannot mark an inbox document as read', async () => {
    await seed('users/owner/pushNotifications/notification-1', inboxData());
    await assertFails(updateDoc(inboxDocument(ids.other, ids.owner), { read: true }));
  });
});

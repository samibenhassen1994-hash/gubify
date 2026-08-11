import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { collection, doc, getDocs, query, where, writeBatch } from 'firebase/firestore';

// This intentionally mirrors the dynamic membership boundary proposed for
// production. It proves the Firestore emulator can authorize a collection
// query when its lower timestamp bound is at least the member's joinedAt.
const rules = `
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /spaces/{spaceId}/items/{itemId} {
      allow read: if request.auth != null
        && (resource.data.status == 'active'
          || (resource.data.status == 'completed'
            && resource.data.completedAt >= get(/databases/$(database)/documents/spaces/$(spaceId)/members/$(request.auth.uid)).data.joinedAt));
    }
  }
}`;

let env;

const db = (uid) => env.authenticatedContext(uid).firestore();
const at = (seconds) => new Date(seconds * 1000);

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-gubify-history-dynamic-poc',
    firestore: { rules },
  });
});

after(async () => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const database = context.firestore();
    const batch = writeBatch(database);
    batch.set(doc(database, 'spaces', 'dynamic', 'members', 'member'), {
      joinedAt: at(100),
    });
    batch.set(doc(database, 'spaces', 'dynamic', 'items', 'active-before'), {
      status: 'active',
      completedAt: null,
    });
    batch.set(doc(database, 'spaces', 'dynamic', 'items', 'completed-before'), {
      status: 'completed',
      completedAt: at(99),
    });
    batch.set(doc(database, 'spaces', 'dynamic', 'items', 'completed-after'), {
      status: 'completed',
      completedAt: at(101),
    });
    await batch.commit();
  });
});

describe('membership history architecture gate', () => {
  test('proves separate current and bounded-history queries', async () => {
    const items = collection(db('member'), 'spaces', 'dynamic', 'items');

    await assertSucceeds(getDocs(query(items, where('status', '==', 'active'))));
    await assertSucceeds(getDocs(query(
      items,
      where('status', '==', 'completed'),
      where('completedAt', '>=', at(100)),
    )));
    await assertFails(getDocs(query(items, where('status', '==', 'completed'))));
    await assertFails(getDocs(items));
  });
});

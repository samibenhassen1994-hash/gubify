import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, getDoc, getDocs, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';

const projectId = 'demo-gubify';
let env;
const db = (uid) => env.authenticatedContext(uid).firestore();
const block = (uid, target) => doc(db(uid), 'users', uid, 'blockedUsers', target);
const data = (target) => ({ blockedUserId: target, blockedAt: serverTimestamp() });

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});
after(async () => env.cleanup());
beforeEach(async () => env.clearFirestore());

test('owner can create, read, list, and delete their own block', async () => {
  await assertSucceeds(setDoc(block('a', 'b'), data('b')));
  await assertSucceeds(getDoc(block('a', 'b')));
  await assertSucceeds(getDocs(collection(db('a'), 'users', 'a', 'blockedUsers')));
  await assertSucceeds(deleteDoc(block('a', 'b')));
});

test('other users and anonymous users cannot read another block list', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users', 'a', 'blockedUsers', 'b'), {
      blockedUserId: 'b', blockedAt: new Date(),
    });
  });
  await assertFails(getDoc(doc(db('b'), 'users', 'a', 'blockedUsers', 'b')));
  await assertFails(getDocs(collection(db('c'), 'users', 'a', 'blockedUsers')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users', 'a', 'blockedUsers', 'b')));
});

test('only the owner can create a block in their own list', async () => {
  await assertFails(setDoc(doc(db('a'), 'users', 'b', 'blockedUsers', 'c'), data('c')));
});

test('self blocks, mismatched IDs, extra fields, fake timestamps, and updates are denied', async () => {
  await assertFails(setDoc(block('a', 'a'), data('a')));
  await assertFails(setDoc(block('a', 'b'), { ...data('c') }));
  await assertFails(setDoc(block('a', 'b'), { ...data('b'), extra: true }));
  await assertFails(setDoc(block('a', 'b'), { blockedUserId: 'b', blockedAt: new Date() }));
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users', 'a', 'blockedUsers', 'b'), {
      blockedUserId: 'b', blockedAt: new Date(),
    });
  });
  await assertFails(updateDoc(block('a', 'b'), { blockedUserId: 'c' }));
});

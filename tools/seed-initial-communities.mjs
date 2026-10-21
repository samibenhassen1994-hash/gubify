import {pathToFileURL} from 'node:url';
import process from 'node:process';

import {applicationDefault, getApps, initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';

import {
  initialCommunityCatalog,
  validateInitialCommunityCatalog,
} from './initial-community-catalog.mjs';

export const expectedProjectId = 'gubify-a3e2c';
export const expectedOwnerUid = '9dTaHzIR3FcEjK5KDAkCnImYbV93';
export const expectedOwnerEmail = 'gubifyapp@gmail.com';

export function communityNameKey(name) {
  return name.trim().toLowerCase().normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, '')
    .replaceAll('/', '∕');
}

export function buildCommunityDocumentPlan({
  community,
  communityId,
  owner,
  progressExists = false,
}) {
  const createdAt = FieldValue.serverTimestamp();
  const root = {
    communityId,
    name: community.name,
    ownerId: owner.uid,
    memberCount: 1,
    visibility: 'public',
    createdAt,
    type: community.type,
    language: community.language,
    description: community.description,
    accessMode: community.accessMode,
    nameKey: communityNameKey(community.name),
    slug: community.slug,
    slugAssignedAt: createdAt,
  };
  return [
    {path: `communities/${communityId}`, data: root},
    {path: `communityNames/${root.nameKey}`, data: {nameKey: root.nameKey, communityId, ownerId: owner.uid, createdAt}},
    {path: `communitySlugs/${community.slug}`, data: {slug: community.slug, communityId, ownerId: owner.uid, createdAt}},
    {path: `communityPublic/${community.slug}`, data: {communityId, slug: community.slug, name: community.name, description: community.description, type: community.type, language: community.language, accessMode: community.accessMode, memberCount: 1, createdAt, updatedAt: createdAt}},
    {path: `communityRestrictions/${communityId}`, data: {hiddenFromDiscovery: false, joiningRestricted: false, updatedAt: createdAt}},
    {path: `communities/${communityId}/members/${owner.uid}`, data: {uid: owner.uid, displayName: owner.displayName, photoUrl: owner.photoUrl, role: 'owner', joinedAt: createdAt}},
    {path: `users/${owner.uid}/communities/${communityId}`, data: {communityId, name: community.name, ownerId: owner.uid, memberCount: 1, visibility: 'public', role: 'owner', joinedAt: createdAt}},
    {path: `platformAdminCommunityOwnership/${owner.uid}/communities/${communityId}`, data: {ownerId: owner.uid, communityId, createdAt}},
    {path: `communityUserProgress/${owner.uid}`, merge: true, data: {
      ...(progressExists ? {} : {xp: 0}),
      communityIds: FieldValue.arrayUnion(communityId),
      membershipProjectionCommunityId: communityId,
      membershipProjectionAction: 'join',
      membershipProjectionUpdatedAt: createdAt,
    }},
  ];
}

export function classifyExistingCommunity({nameRegistry, slugRegistry, root, expectedName, ownerId}) {
  if (!nameRegistry && !slugRegistry && !root) return 'new';
  const id = nameRegistry?.communityId;
  if (id && id === slugRegistry?.communityId && root?.communityId === id
      && root.ownerId === ownerId && root.name === expectedName
      && nameRegistry.ownerId === ownerId && slugRegistry.ownerId === ownerId) {
    return 'existing';
  }
  return 'conflict';
}

export function validateExistingDocumentSet({documents, communityId, ownerId, community}) {
  const requiredPaths = buildCommunityDocumentPlan({
    community,
    communityId,
    owner: {uid: ownerId, displayName: 'ignored', photoUrl: null},
  }).map((entry) => entry.path);
  if (requiredPaths.some((path) => !documents.get(path))) return false;
  const root = documents.get(`communities/${communityId}`);
  const member = documents.get(`communities/${communityId}/members/${ownerId}`);
  const copy = documents.get(`users/${ownerId}/communities/${communityId}`);
  const adminOwnership = documents.get(
    `platformAdminCommunityOwnership/${ownerId}/communities/${communityId}`,
  );
  const progress = documents.get(`communityUserProgress/${ownerId}`);
  return root.communityId === communityId && root.ownerId === ownerId
    && root.name === community.name && root.slug === community.slug
    && member.uid === ownerId && member.role === 'owner'
    && copy.communityId === communityId && copy.role === 'owner'
    && adminOwnership.ownerId === ownerId
    && adminOwnership.communityId === communityId
    && Array.isArray(progress.communityIds)
    && progress.communityIds.includes(communityId);
}

function parseArgs(argv) {
  const flags = new Set(argv);
  return {
    apply: flags.has('--apply'),
    projectId: argv[argv.indexOf('--project') + 1],
    ownerUid: argv[argv.indexOf('--owner-uid') + 1],
    confirmCount: Number(argv[argv.indexOf('--confirm-count') + 1]),
  };
}

async function verifyIdentity({projectId, ownerUid}) {
  const app = getApps()[0] ?? initializeApp({credential: applicationDefault(), projectId});
  const [user, admin, profile] = await Promise.all([
    getAuth(app).getUser(ownerUid),
    getFirestore(app).doc(`platformAdmins/${ownerUid}`).get(),
    getFirestore(app).doc(`users/${ownerUid}`).get(),
  ]);
  if (user.email?.toLowerCase() !== expectedOwnerEmail) throw new Error('Owner email does not match the approved account.');
  if (user.disabled) throw new Error('Approved owner account is disabled.');
  if (!admin.exists || admin.data()?.active !== true) throw new Error('Approved Platform Admin role is not active.');
  if (!profile.exists) throw new Error('Approved owner profile is missing.');
  const displayName = profile.data()?.displayName;
  return {
    app,
    owner: {
      uid: ownerUid,
      displayName: typeof displayName === 'string' && displayName.trim() ? displayName.trim() : 'Gubify',
      photoUrl: profile.data()?.photoUrl ?? profile.data()?.photoURL ?? user.photoURL ?? null,
    },
  };
}

async function inspectOne(db, community, ownerId) {
  const nameKey = communityNameKey(community.name);
  const [nameDoc, slugDoc] = await Promise.all([
    db.doc(`communityNames/${nameKey}`).get(),
    db.doc(`communitySlugs/${community.slug}`).get(),
  ]);
  const candidateId = nameDoc.data()?.communityId ?? slugDoc.data()?.communityId;
  const rootDoc = candidateId ? await db.doc(`communities/${candidateId}`).get() : null;
  const state = classifyExistingCommunity({
    nameRegistry: nameDoc.data() ?? null,
    slugRegistry: slugDoc.data() ?? null,
    root: rootDoc?.data() ?? null,
    expectedName: community.name,
    ownerId,
  });
  if (state !== 'existing') return state;
  const plan = buildCommunityDocumentPlan({
    community,
    communityId: candidateId,
    owner: {uid: ownerId, displayName: 'ignored', photoUrl: null},
  });
  const snapshots = await db.getAll(...plan.map((entry) => db.doc(entry.path)));
  const documents = new Map(
    snapshots.map((snapshot) => [snapshot.ref.path, snapshot.data() ?? null]),
  );
  return validateExistingDocumentSet({
    documents,
    communityId: candidateId,
    ownerId,
    community,
  }) ? 'existing' : 'conflict';
}

async function createOne(db, community, owner) {
  const communityRef = db.collection('communities').doc();
  return db.runTransaction(async (transaction) => {
    const nameRef = db.doc(`communityNames/${communityNameKey(community.name)}`);
    const slugRef = db.doc(`communitySlugs/${community.slug}`);
    const [nameDoc, slugDoc, progressDoc] = await Promise.all([
      transaction.get(nameRef),
      transaction.get(slugRef),
      transaction.get(db.doc(`communityUserProgress/${owner.uid}`)),
    ]);
    if (nameDoc.exists || slugDoc.exists) throw new Error(`Concurrent catalog collision: ${community.slug}`);
    for (const entry of buildCommunityDocumentPlan({
      community,
      communityId: communityRef.id,
      owner,
      progressExists: progressDoc.exists,
    })) {
      const ref = db.doc(entry.path);
      if (entry.merge) transaction.set(ref, entry.data, {merge: true});
      else transaction.create(ref, entry.data);
    }
    return communityRef.id;
  });
}

export async function executePreflightedSeed({catalog, apply, inspect, create}) {
  const report = {
    scanned: catalog.length,
    wouldCreate: 0,
    existing: 0,
    conflicts: 0,
    created: 0,
  };
  const pending = [];
  for (const community of catalog) {
    const state = await inspect(community);
    if (state === 'existing') {
      report.existing += 1;
    } else if (state === 'conflict') {
      report.conflicts += 1;
    } else {
      report.wouldCreate += 1;
      pending.push(community);
    }
  }
  if (report.conflicts) {
    throw Object.assign(new Error('Catalog conflicts require review.'), {report});
  }
  if (apply) {
    for (const community of pending) {
      await create(community);
      report.created += 1;
    }
  }
  return report;
}

export async function runSeed({apply = false, projectId, ownerUid, confirmCount = 0} = {}) {
  if (projectId !== expectedProjectId) throw new Error(`Explicit --project ${expectedProjectId} is required.`);
  if (ownerUid !== expectedOwnerUid) throw new Error('Explicit approved --owner-uid is required.');
  const validation = validateInitialCommunityCatalog(initialCommunityCatalog);
  if (validation.errors.length) throw new Error(validation.errors.join('\n'));
  if (apply && confirmCount !== 100) throw new Error('Apply requires --confirm-count 100.');
  const {app, owner} = await verifyIdentity({projectId, ownerUid});
  const db = getFirestore(app);
  return executePreflightedSeed({
    catalog: initialCommunityCatalog,
    apply,
    inspect: (community) => inspectOne(db, community, ownerUid),
    create: (community) => createOne(db, community, owner),
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = parseArgs(process.argv.slice(2));
  runSeed(args).then((report) => {
    console.log(JSON.stringify({mode: args.apply ? 'apply' : 'dry-run', ...report}, null, 2));
  }).catch((error) => {
    if (error.report) console.error(JSON.stringify(error.report));
    console.error(error.message);
    process.exitCode = 1;
  });
}

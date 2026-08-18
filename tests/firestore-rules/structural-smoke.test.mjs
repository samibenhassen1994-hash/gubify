import { before, after, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, writeBatch, setDoc, updateDoc, serverTimestamp } from 'firebase/firestore';

const projectId = 'demo-gubify';
let env;
const db = uid => env.authenticatedContext(uid).firestore();
const tokenId = 'STRUC2Q7';
const root = (id, owner='owner') => ({gubId:id,name:'Test',ownerId:owner,inviteTokenId:tokenId,memberCount:1,createdAt:new Date()});
const member = (uid,role,proof) => ({uid,displayName:uid,photoUrl:null,role,joinedAt:new Date(),...(proof ? {joinedViaInviteToken:proof} : {})});
const copy = (id,uid,role) => ({gubId:id,name:'Test',ownerId:'owner',role,joinedAt:new Date()});
const token = (ownerId='owner', active=true) => ({gubId:'g1',ownerId,gubName:'Test',active,createdAt:serverTimestamp()});

before(async()=>{ env=await initializeTestEnvironment({projectId,firestore:{rules:readFileSync('firestore.rules','utf8')}}); });
after(async()=>env.cleanup());
beforeEach(async()=>env.clearFirestore());

async function createGub(uid='owner', ownerId='owner') {
 const d=db(uid), b=writeBatch(d), id='g1';
 b.set(doc(d,'inviteTokens',tokenId),token(ownerId));
 b.set(doc(d,'gubs',id),root(id,ownerId));
 b.set(doc(d,'gubs',id,'members',uid),member(uid,'owner'));
 b.set(doc(d,'users',uid,'gubs',id),copy(id,uid,'owner'));
 return b.commit();
}
async function seedGub(){ await env.withSecurityRulesDisabled(async c=>{const d=c.firestore(); await setDoc(doc(d,'inviteTokens',tokenId),token()); await setDoc(doc(d,'gubs','g1'),root('g1')); await setDoc(doc(d,'gubs','g1','members','owner'),member('owner','owner')); await setDoc(doc(d,'users','owner','gubs','g1'),copy('g1','owner','owner'));}); }

test('create Gub batch succeeds',()=>assertSucceeds(createGub()));
test('create Gub false owner fails',()=>assertFails(createGub('owner','other')));
test('join Gub coherent batch succeeds',async()=>{await seedGub();const d=db('member'),b=writeBatch(d);b.update(doc(d,'gubs','g1'),{memberCount:2});b.set(doc(d,'gubs','g1','members','member'),member('member','member',tokenId));b.set(doc(d,'users','member','gubs','g1'),copy('g1','member','member'));await assertSucceeds(b.commit());});
test('incomplete join fails',async()=>{await seedGub();const d=db('member'),b=writeBatch(d);b.update(doc(d,'gubs','g1'),{memberCount:2});b.set(doc(d,'gubs','g1','members','member'),member('member','member',tokenId));await assertFails(b.commit());});

async function createCommunity(uid='cowner',ownerId='cowner',marker=true){const d=db(uid),b=writeBatch(d),id='c1',slug='community',nameKey='community',r={communityId:id,name:'Community',ownerId,memberCount:1,visibility:'public',createdAt:serverTimestamp(),type:'General',language:'English',description:'',accessMode:'open',nameKey,slug,slugAssignedAt:serverTimestamp()};b.set(doc(d,'communities',id),r);b.set(doc(d,'communityNames',nameKey),{nameKey,communityId:id,ownerId,createdAt:serverTimestamp()});b.set(doc(d,'communitySlugs',slug),{slug,communityId:id,ownerId,createdAt:serverTimestamp()});b.set(doc(d,'communityPublic',slug),{communityId:id,slug,name:'Community',description:'',language:'English',accessMode:'open',createdAt:serverTimestamp(),updatedAt:serverTimestamp()});b.set(doc(d,'communities',id,'members',uid),{...member(uid,'owner'),joinedAt:serverTimestamp()});b.set(doc(d,'users',uid,'communities',id),{communityId:id,name:'Community',ownerId,memberCount:1,visibility:'public',role:'owner',joinedAt:serverTimestamp()});if(marker)b.set(doc(d,'communityOwnership',uid),{ownerId:uid,communityId:id,createdAt:serverTimestamp()});return b.commit();}
test('create Community batch succeeds',()=>assertSucceeds(createCommunity()));
test('create Community false owner fails',()=>assertFails(createCommunity('cowner','other')));
test('arbitrary communityOwnership fails',async()=>{const d=db('x');await assertFails(setDoc(doc(d,'communityOwnership','x'),{ownerId:'x',communityId:'missing',createdAt:new Date()}));});
test('owner starts deletion',async()=>{await seedGub();const d=db('owner'),b=writeBatch(d);b.update(doc(d,'gubs','g1'),{deletionStatus:'deleting',deletionRequestedBy:'owner',deletionStartedAt:serverTimestamp(),deletionUpdatedAt:serverTimestamp(),deletionPhase:'preparing'});b.update(doc(d,'inviteTokens',tokenId),{active:false});await assertSucceeds(b.commit());});
test('member cannot start deletion',async()=>{await seedGub();await env.withSecurityRulesDisabled(async c=>setDoc(doc(c.firestore(),'gubs','g1','members','member'),member('member','member')));const d=db('member');await assertFails(updateDoc(doc(d,'gubs','g1'),{deletionStatus:'deleting',deletionRequestedBy:'member',deletionStartedAt:new Date(),deletionUpdatedAt:new Date(),deletionPhase:'preparing'}));});
test('deletion plus functional change fails',async()=>{await seedGub();const d=db('owner');await assertFails(updateDoc(doc(d,'gubs','g1'),{name:'Changed',deletionStatus:'deleting',deletionRequestedBy:'owner',deletionStartedAt:new Date(),deletionUpdatedAt:new Date(),deletionPhase:'preparing'}));});
test('deleting cannot return active',async()=>{await env.withSecurityRulesDisabled(async c=>{await setDoc(doc(c.firestore(),'inviteTokens',tokenId),token('owner',false));await setDoc(doc(c.firestore(),'gubs','g1'),{...root('g1'),deletionStatus:'deleting',deletionRequestedBy:'owner',deletionStartedAt:new Date(),deletionPhase:'preparing'});});await assertFails(updateDoc(doc(db('owner'),'gubs','g1'),{deletionStatus:'active'}));});
test('unknown subcollection is denied',async()=>{await seedGub();await assertFails(setDoc(doc(db('owner'),'gubs','g1','unknown','x'),{ok:true}));});

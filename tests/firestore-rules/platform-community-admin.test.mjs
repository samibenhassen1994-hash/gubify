import { before, after, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, collection, getDoc, getDocs, setDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp } from 'firebase/firestore';
let env;
const db = (uid = 'admin', anonymous = false) => env.authenticatedContext(uid, { firebase: { sign_in_provider: anonymous ? 'anonymous' : 'password' } }).firestore();
const at = new Date('2026-08-01');
const moderation = (hidden = true) => ({ moderationHidden: hidden, moderatedBy: 'admin', moderatedAt: serverTimestamp() });
before(async () => { env = await initializeTestEnvironment({projectId:'demo-gubify',firestore:{rules:readFileSync('firestore.rules','utf8')}}); });
after(async () => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async c => {
    const f = c.firestore();
    const data = {
      'platformAdmins/admin': {active:true},
      'platformAdmins/guest': {active:true},
      'communities/c': {communityId:'c',ownerId:'owner',name:'Hidden',visibility:'hidden',accessMode:'approval',memberCount:2,deletionStatus:'active'},
      'communities/c/members/owner': {uid:'owner',displayName:'Owner',role:'owner',joinedAt:at},
      'communities/c/members/member': {uid:'member',displayName:'Member',role:'member',joinedAt:at},
      'users/member/communities/c': {communityId:'c',role:'member'},
      'communityUserProgress/member': {xp:42,communityIds:['c','other']},
      'communities/c/joinRequests/applicant': {userId:'applicant',displayName:'Applicant',status:'pending',createdAt:at},
      'communities/c/messages/m': {messageId:'m',communityId:'c',senderId:'member',senderName:'Member',text:'Original message',createdAt:at},
      'communities/c/asks/a': {askId:'a',communityId:'c',authorId:'owner',authorDisplayName:'Owner',text:'Original ask',type:'help',status:'resolved',bestAnswerId:'member',bestAnswerAuthorId:'member',xpAwarded:true,createdAt:at},
      'communities/c/asks/a/answers/member': {answerId:'member',authorId:'member',authorDisplayName:'Member',text:'Original best answer',createdAt:at},
      'gubs/private': {ownerId:'owner',name:'Private',memberCount:1},
      'gubs/private/messages/m': {text:'Private message',createdAt:at},
    };
    for (const [path,value] of Object.entries(data)) await setDoc(doc(f,path),value);
  });
});
test('active nonmember admin can discover hidden communities and read moderation resources without joining',async()=>{
  const f=db();
  await assertSucceeds(getDoc(doc(f,'platformAdmins/admin')));
  await assertSucceeds(getDocs(collection(f,'communities')));
  for(const path of ['communities/c/members','communities/c/bans','communities/c/joinRequests','communities/c/messages','communities/c/asks','communities/c/asks/a/answers']) await assertSucceeds(getDocs(collection(f,path)));
  assert.equal((await getDoc(doc(f,'communities/c'))).data().memberCount,2);
  assert.equal((await getDoc(doc(f,'communities/c/members/admin'))).exists(),false);
});
test('registry is self-readable only, client immutable, strict boolean and nonanonymous',async()=>{
  const f=db();
  await assertFails(getDocs(collection(f,'platformAdmins')));
  await assertFails(getDoc(doc(f,'platformAdmins/guest')));
  await assertFails(setDoc(doc(db('member'),'platformAdmins/member'),{active:true}));
  await assertFails(updateDoc(doc(f,'platformAdmins/admin'),{active:false}));
  await assertFails(deleteDoc(doc(f,'platformAdmins/admin')));
  await assertFails(getDocs(collection(db('guest',true),'communities/c/messages')));
  await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'platformAdmins/admin'),{active:'true'}));
  await assertFails(getDocs(collection(f,'communities/c/messages')));
});
test('role fields in profiles and membership never grant moderation',async()=>{
  await env.withSecurityRulesDisabled(async c=>{
    await setDoc(doc(c.firestore(),'users/member'),{role:'admin'});
    await updateDoc(doc(c.firestore(),'communities/c/members/member'),{role:'admin'});
  });
  await assertFails(updateDoc(doc(db('member'),'communities/c/messages/m'),moderation()));
});
test('admin hide and unhide preserve original content and best answer rewards',async()=>{
  const f=db();
  for(const path of ['communities/c/messages/m','communities/c/asks/a','communities/c/asks/a/answers/member']){
    const ref=doc(f,path); const before=(await assertSucceeds(getDoc(ref))).data();
    await assertSucceeds(updateDoc(ref,moderation()));
    const hidden=(await getDoc(ref)).data(); assert.equal(hidden.text,before.text); assert.equal(hidden.moderationHidden,true);
    await assertSucceeds(updateDoc(ref,moderation(false)));
    assert.equal((await getDoc(ref)).data().moderationHidden,false);
    await assertFails(updateDoc(ref,{...moderation(),text:'Forged'}));
    await assertFails(updateDoc(ref,{...moderation(),moderatedBy:'owner'}));
    await assertFails(updateDoc(ref,{moderationHidden:true}));
    await assertFails(deleteDoc(ref));
  }
  assert.equal((await getDoc(doc(f,'communities/c/asks/a'))).data().xpAwarded,true);
  assert.equal((await getDoc(doc(f,'communityUserProgress/member'))).data().xp,42);
});
test('revocation and deletion immediately deny reads and writes',async()=>{
  for(const revoke of [f=>updateDoc(doc(f,'platformAdmins/admin'),{active:false}),f=>deleteDoc(doc(f,'platformAdmins/admin'))]){
    await env.withSecurityRulesDisabled(c=>revoke(c.firestore()));
    await assertFails(getDocs(collection(db(),'communities/c/messages')));
    await assertFails(updateDoc(doc(db(),'communities/c/asks/a'),moderation()));
  }
});
test('admin has no private Gub, user account, ownership, XP or posting privilege',async()=>{
  const f=db();
  for(const path of ['gubs/private','gubs/private/messages/m','users/member/communities/c','communityOwnership/owner']) await assertFails(getDoc(doc(f,path)));
  await assertFails(setDoc(doc(f,'users/member'),{displayName:'Forged'}));
  await assertFails(updateDoc(doc(f,'communities/c'),{ownerId:'admin'}));
  await assertFails(updateDoc(doc(f,'communities/c'),{memberCount:1}));
  await assertFails(updateDoc(doc(f,'communityUserProgress/member'),{xp:999}));
  await assertFails(setDoc(doc(f,'communities/c/messages/new'),{messageId:'new',communityId:'c',senderId:'admin',senderName:'Admin',text:'hello',createdAt:serverTimestamp()}));
  await assertFails(deleteDoc(doc(f,'communities/c')));
});
function removal(f,uid='member',{ban=false,omitCopy=false,omitProgress=false,publicProjection=false}={}){
 const batch=writeBatch(f);
 batch.delete(doc(f,`communities/c/members/${uid}`));
 if(!omitCopy)batch.delete(doc(f,`users/${uid}/communities/c`));
 if(!omitProgress&&uid==='member')batch.update(doc(f,'communityUserProgress/member'),{communityIds:['other'],membershipProjectionCommunityId:'c',membershipProjectionAction:ban?'ban':'leave',membershipProjectionUpdatedAt:serverTimestamp()});
 batch.update(doc(f,'communities/c'),{memberCount:1});
 if(publicProjection)batch.update(doc(f,'communityPublic/hidden'),{memberCount:1,updatedAt:serverTimestamp()});
 batch.set(doc(f,'communities/c/membershipMutations/admin'),{action:'remove',userId:uid,actorId:'admin',createdAt:serverTimestamp()});
 if(ban)batch.set(doc(f,`communities/c/bans/${uid}`),{userId:uid,displayName:'Member',photoUrl:null,bannedBy:'admin',bannedAt:serverTimestamp()});
 return batch.commit();
}
test('nonmember admin removal maintains copies and XP projection atomically',async()=>{
 await assertFails(removal(db(),'member',{omitCopy:true}));
 await assertFails(removal(db(),'member',{omitProgress:true}));
 await assertSucceeds(removal(db()));
 const progress=(await getDoc(doc(db(),'communityUserProgress/member'))).data();
 assert.deepEqual(progress.communityIds,['other']);assert.equal(progress.xp,42);
});
test('ban/unban work while owner and actor remain protected',async()=>{
 await assertFails(removal(db(),'owner',{ban:true}));
 await assertFails(removal(db(),'admin',{ban:true}));
 await assertSucceeds(removal(db(),'member',{ban:true}));
 await assertSucceeds(deleteDoc(doc(db(),'communities/c/bans/member')));
});
test('admin can approve or reject requests without assigning membership',async()=>{
 const ref=doc(db(),'communities/c/joinRequests/applicant');
 await assertSucceeds(updateDoc(ref,{status:'approved',resolvedBy:'admin',resolvedAt:serverTimestamp()}));
 assert.equal((await getDoc(doc(db(),'communities/c/members/applicant'))).exists(),false);
 assert.equal((await getDoc(doc(db(),'communities/c'))).data().memberCount,2);
 await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'communities/c/joinRequests/applicant'),{status:'pending'}));
 await assertSucceeds(updateDoc(ref,{status:'rejected',resolvedBy:'admin',resolvedAt:serverTimestamp()}));
});

test('admin removal keeps public member count in the same transaction',async()=>{
 await env.withSecurityRulesDisabled(async c=>{
  await updateDoc(doc(c.firestore(),'communities/c'),{slug:'hidden'});
  await setDoc(doc(c.firestore(),'communityPublic/hidden'),{communityId:'c',slug:'hidden',memberCount:2,updatedAt:at});
 });
 await assertFails(removal(db()));
 await assertSucceeds(removal(db(),'member',{publicProjection:true}));
 assert.equal((await getDoc(doc(db(),'communityPublic/hidden'))).data().memberCount,1);
 assert.equal((await getDoc(doc(db(),'communities/c'))).data().ownerId,'owner');
});

import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { readFileSync } from 'fs';
import { doc, setDoc, updateDoc, deleteDoc, getDoc } from 'firebase/firestore';
const env = await initializeTestEnvironment({ projectId: 'demo-t', firestore: { rules: readFileSync('../../firestore.rules','utf8'), host:'127.0.0.1', port:8085 } });
const a = env.authenticatedContext('ua').firestore();
const b = env.authenticatedContext('ub').firestore();
const anon = env.unauthenticatedContext().firestore();
let ok=0, bad=0;
async function t(name, p){ try{ await p; ok++; console.log('ok  ', name);}catch(e){ bad++; console.log('FAIL', name, e.message.split('\n')[0]); } }
// projects
await t('A가 자기 프로젝트 만들기', assertSucceeds(setDoc(doc(a,'my_projects/p1'),{name:'x',ownerUid:'ua'})));
await t('B가 A 프로젝트 고치기 막힘', assertFails(updateDoc(doc(b,'my_projects/p1'),{name:'y'})));
await t('B가 A 프로젝트 지우기 막힘', assertFails(deleteDoc(doc(b,'my_projects/p1'))));
await t('B가 A 것으로 만들기 막힘', assertFails(setDoc(doc(b,'my_projects/p2'),{name:'x',ownerUid:'ua'})));
await t('A가 공용으로 돌리기', assertSucceeds(updateDoc(doc(a,'my_projects/p1'),{ownerUid:''})));
await t('B가 공용 고치기', assertSucceeds(updateDoc(doc(b,'my_projects/p1'),{name:'z'})));
await t('B가 공용을 자기 것으로', assertSucceeds(updateDoc(doc(b,'my_projects/p1'),{ownerUid:'ub'})));
await t('B 것 읽기(앱이 가림, 규칙은 허용)', assertSucceeds(getDoc(doc(a,'my_projects/p1'))));
await t('예전 주인 없는 프로젝트 누구나', assertSucceeds(setDoc(doc(b,'cutting_projects/c1'),{name:'x'})));
await t('로그인 안 하면 막힘', assertFails(getDoc(doc(anon,'my_projects/p1'))));
// subcollections
await t('하위 모음(기록) 쓰기', assertSucceeds(setDoc(doc(a,'cutting_projects/c1/cut_records/r1'),{x:1})));
// leftovers
await t('내 잔재 문서', assertSucceeds(setDoc(doc(a,'cutting_leftovers/current__ua'),{items:[]})));
await t('공용 잔재 문서', assertSucceeds(setDoc(doc(a,'cutting_leftovers/current'),{items:[]})));
await t('남의 잔재 문서 막힘', assertFails(setDoc(doc(b,'cutting_leftovers/current__ua'),{items:[]})));
// settings
await t('내 설정', assertSucceeds(setDoc(doc(a,'my_project_settings/report_style__ua'),{c:1})));
await t('예전 공용 설정', assertSucceeds(setDoc(doc(a,'my_project_settings/report_style'),{c:1})));
await t('남의 설정 막힘', assertFails(setDoc(doc(b,'my_project_settings/report_style__ua'),{c:1})));
// others unchanged
await t('다른 모음(알림 등) 쓰기', assertSucceeds(setDoc(doc(a,'notices/n1'),{t:1})));
await t('재고 남의 것 고치기 막힘', (async()=>{ await setDoc(doc(a,'inventory/i1'),{ownerUid:'ua'}); await assertFails(updateDoc(doc(b,'inventory/i1'),{qty:1})); })());
await t('users 규칙 유지', assertSucceeds(setDoc(doc(a,'users/홍'),{uid:'ua'})));
// 현장 자료(KEC): 누구나 읽고, 앱에서는 못 쓴다(서버 함수만)
await t('KEC 요약 읽기(로그인 안 해도)', assertSucceeds(getDoc(doc(anon,'reference_content/kec'))));
await t('KEC 요약 쓰기 막힘', assertFails(setDoc(doc(a,'reference_content/kec'),{x:1})));
await env.cleanup();
console.log(`통과 ${ok} 실패 ${bad}`);
process.exit(bad?1:0);

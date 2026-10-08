const assert = require('node:assert/strict');
const path = require('node:path');
const root = path.join(__dirname, 'miniprogram');
const util = require(path.join(root, 'utils/data.js'));
let passed = 0;
function check(label, fn) { fn(); passed++; console.log('PASS', label); }
check('all national ids present', () => assert.deepEqual(util.getIndex().map(x=>x.id), Array.from({length:1025},(_,i)=>i+1)));
for (const q of ['皮卡丘','PIKACHU','25','025','#025']) check('search '+q,()=>assert.deepEqual(util.filterList(q,null,null).map(x=>x.id),[25]));
check('generation and type intersection',()=>assert.deepEqual(util.filterList('',1,'electric').map(x=>x.id),[25,26,81,82,100,101,125,135,145]));
check('search respects generation',()=>assert.equal(util.filterList('皮卡丘',2,null).length,0));
check('empty search state',()=>assert.equal(util.filterList('不存在的宝可梦',null,null).length,0));
check('complete type mapping',()=>assert.equal(Object.keys(util.TYPE_ZH).length,18));
check('no fabricated detail',()=>assert.equal(util.getDetail(2),null));
check('source stats',()=>assert.equal(Object.values(util.getDetail(25).baseStats).reduce((a,b)=>a+b,0),320));
let navigated = '';
global.wx = {nextTick:fn=>fn(),navigateTo:o=>{navigated=o.url},setNavigationBarTitle:()=>{},showToast:()=>{}};
function loadPage(file) {
 let captured;
 global.Page = p=>{captured=p};
 delete require.cache[require.resolve(path.join(root,file))];
 require(path.join(root,file));
 const p = Object.assign({},captured,{data:structuredClone(captured.data)});
 p.setData = patch=>{
  for (const [key,value] of Object.entries(patch)) {
   const parts = key.replace(/\[(\d+)\]/g,'.$1').split('.');
   let dst=p.data; for (let i=0;i<parts.length-1;i++) dst=dst[parts[i]];
   dst[parts[parts.length-1]]=value;
  }
 };
 return p;
}
const list = loadPage('pages/list/list.js');
list.onLoad();
check('first list page has 40 real cards',()=>{assert.equal(list.data.shown.length,40);assert.equal(list.data.total,1025);assert.equal(list.data.shown[0].no,'0001');assert.equal(list.data.shown[0].types[0].zh,'草');});
list.onReachBottom();
check('pagination advances to 80',()=>assert.equal(list.data.shown.length,80));
list.onSearchInput({detail:{value:'#025'}});
check('native list search and new pagination',()=>{assert.equal(list.data.total,1);assert.equal(list.data.shown[0].id,25);assert.equal(list.data.hasMore,false);});
list.onTapCard({currentTarget:{dataset:{id:25}}});
check('native detail navigation',()=>assert.equal(navigated,'/pages/detail/detail?id=25'));
list.onShow();
check('return preserves query and result',()=>{assert.equal(list.data.searchText,'#025');assert.equal(list.data.shown[0].id,25);});
list.onResetFilter(); list.onPickGen({currentTarget:{dataset:{gen:'1'}}}); list.onPickType({currentTarget:{dataset:{type:'electric'}}});
check('list intersection count',()=>assert.equal(list.data.total,9));
list.onImageError({currentTarget:{dataset:{index:0}}});
check('image failure state',()=>assert.equal(list.data.shown[0].imgFailed,true));
list.onResetFilter();
check('reset restores full list',()=>{assert.equal(list.data.total,1025);assert.equal(list.data.activeType,'');assert.equal(list.data.activeGen,0);});
check('Pichu friendship condition',()=>assert.match(util.triggerToZh({trigger:'level-up',minHappiness:220}),/220/));
check('accurate Pinwheel Forest label',()=>assert.match(util.triggerToZh({trigger:'level-up',location:'pinwheel-forest'}),/矢车森林/));
check('accurate affection label',()=>assert.match(util.triggerToZh({trigger:'level-up',minAffection:2,knownMoveType:'fairy'}),/友好度/));
const reference = require('./fixtures/pokemon-details.json');
for (const [id, expected] of Object.entries(reference)) {
 const page = loadPage('pages/detail/detail.js');
 page.onLoad({id});
 check('detail source units and stats '+id,()=>{
  assert.equal(page.data.hasDetail,true);
  assert.equal(page.data.heightM,(expected.heightDm/10).toFixed(1));
  assert.equal(page.data.extra.weightKg,(expected.weightHg/10).toFixed(1));
  assert.equal(page.data.statTotal,Object.values(expected.baseStats).reduce((a,b)=>a+b,0));
  assert.equal(page.data.abilities.length,expected.abilities.length);
 });
}
const basic = loadPage('pages/detail/detail.js'); basic.onLoad({id:'2'});
check('basic detail has no fabricated extensions',()=>{assert.equal(basic.data.hasDetail,false);assert.equal(basic.data.stats.length,0);assert.equal(basic.data.extra,null);});
const missing = loadPage('pages/detail/detail.js'); missing.onLoad({id:'1026'});
check('invalid id state',()=>assert.equal(missing.data.notFound,true));
console.log('Verified contracts:',passed);

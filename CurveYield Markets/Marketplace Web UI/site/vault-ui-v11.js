'use strict';
/* CurveYield Vault UI v11: presentation-only enhancement; original vaults.js owns all transactions. */
(()=>{
const root=document.getElementById('page'),frame=document.getElementById('appFrame');
if(!root||!frame)return;
const create=location.pathname==='/vaults/create',manage=/^\/vaults\/0x[a-f0-9]{40}$/i.test(location.pathname),marketCreate=location.pathname==='/create';
if((!create&&!manage&&!marketCreate)||new URLSearchParams(location.search).get('chain')==='ethereum')return;
let stage=1,tab='overview';try{stage=sessionStorage.getItem('cy-vault-stage')==='2'?2:1}catch{}
for(const a of frame.querySelectorAll('a[href^="#/"]')){const h=a.getAttribute('href'),map={'#/overview':'/','#/markets':'/markets','#/vaults':'/vaults','#/portfolio/positions':'/portfolio','#/markets/create':'/create','#/vaults/create':'/vaults/create'};if(map[h])a.href=map[h];else if(h==='#/oracles'||h==='#/liquidations'){a.hidden=true;a.style.display='none'}}
for(const section of frame.querySelectorAll('.side-section'))if(/Favorites|My Vaults/.test(section.querySelector('.section-label')?.textContent||''))section.hidden=true;
for(const a of frame.querySelectorAll('.wordmark,.collapsed-create,.side-head .gold-btn'))a.href=a.matches('.wordmark')?'/':'/vaults/create';
const toggle=document.getElementById('sidebarToggle');
const sync=()=>{toggle?.setAttribute('aria-expanded',String(!frame.classList.contains('sidebar-collapsed')));toggle?.setAttribute('aria-label',frame.classList.contains('sidebar-collapsed')?'Expand sidebar':'Collapse sidebar')};
try{if(localStorage.getItem('cy-sidebar-collapsed')==='1')frame.classList.add('sidebar-collapsed')}catch{}
toggle?.addEventListener('click',()=>{frame.classList.toggle('sidebar-collapsed');try{localStorage.setItem('cy-sidebar-collapsed',frame.classList.contains('sidebar-collapsed')?'1':'0')}catch{}sync()});sync();
document.getElementById('menuToggle')?.addEventListener('click',()=>frame.classList.toggle('menu-open'));
frame.addEventListener('click',e=>{if(e.target===frame)frame.classList.remove('menu-open')});
const el=(tag,cls,content)=>{const e=document.createElement(tag);e.className=cls;e.innerHTML=content;return e};
function wizard(page){page.classList.add('cy-create');
const h=page.querySelector('.v-heading'),g=page.querySelector('.create-grid'),f=page.querySelector('.create-form'),summary=page.querySelector('.create-summary');
if(!h||!g||!f||!summary)return;
h.querySelector('h1').textContent='Create a vault';
h.querySelector('p').textContent='Set vault identity first, then review compatible adapters and protected deployment on Fraxtal.';
const steps=el('nav','cy-stepper','<div data-step="1"><b>1</b> Vault identity</div><div data-step="2"><b>2</b> Adapter & review</div>');
steps.setAttribute('aria-label','Creation stages');h.after(steps);
const description=el('p','cy-stage-description','');steps.after(description);
const controls=el('div','cy-stage-controls','<button type="button" data-back>← Back to identity</button><button type="button" data-next>Continue to adapter & review →</button>');
g.after(controls);
const cards=[...f.children].filter(x=>x.matches('.create-card:not(.lm-panel)')),lm=f.querySelector('.lm-panel');
function show(n){stage=n;try{sessionStorage.setItem('cy-vault-stage',String(n))}catch{}
page.dataset.stage=String(n);for(const c of cards)c.hidden=n===2;if(lm)lm.hidden=n===1;summary.hidden=n===1;g.classList.toggle('cy-full',n===1);
controls.querySelector('[data-back]').hidden=n===1;controls.querySelector('[data-next]').hidden=n===2;
for(const a of steps.children){a.classList.toggle('active',a.dataset.step===String(n));a.classList.toggle('done',n===2&&a.dataset.step==='1')}
description.textContent=n===1?'Choose the asset, vault name, share symbol, and operator fee. No transaction is submitted on this page.':'Discover eligible lending markets and review the controller and vault deployment. Adapter onboarding, caps, and allocations occur after deployment in the permanent dashboard.'}
controls.querySelector('[data-back]').onclick=()=>{show(1);scrollTo(0,0)};
controls.querySelector('[data-next]').onclick=()=>{show(2);scrollTo(0,0)};show(stage)}
function dashboard(page){page.classList.add('cy-manage');
const h=page.querySelector('.v-heading'),g=page.querySelector('.create-grid'),f=page.querySelector('.create-form'),summary=page.querySelector('.create-summary');
if(!h||!g||!f)return;
const name=h.querySelector('h1')?.textContent||'Vault';h.prepend(el('p','cy-vault-name','✦ '+name+' · Fraxtal Vault V2'));const sub=h.querySelector('p:not(.cy-vault-name)');if(sub)sub.textContent='Review on-chain vault configuration and manage supported adapter, operator and fee operations.';const review=summary?.querySelector('.create-eyebrow');if(review)review.textContent='VAULT READINESS';
const sections=['overview','allocation','caps','timelocks','sentinel'];
const nav=el('nav','cy-dashboard-tabs',sections.map(x=>'<button type="button" data-section="'+x+'">'+x[0].toUpperCase()+x.slice(1)+'</button>').join(''));
nav.setAttribute('aria-label','Vault management pages');h.after(nav);
const cards=[...f.children].filter(x=>x.matches('.create-card:not(.lm-panel)')),lm=f.querySelector('.lm-panel');
const deferred=el('section','cy-not-yet','');
f.appendChild(deferred);
const note=el('div','cy-risk-note','Select a supported lending market below to view its actual on-chain allocation and cap operations.');lm?.before(note);
function show(v){tab=v;page.dataset.tab=v;h.querySelector('h1').textContent=v[0].toUpperCase()+v.slice(1);
for(const b of nav.children){b.classList.toggle('active',b.dataset.section===v);b.setAttribute('aria-current',b.dataset.section===v?'page':'false')}
for(const card of cards)card.hidden=v!=='overview';if(lm)lm.hidden=v!=='allocation'&&v!=='caps';
deferred.hidden=v!=='timelocks'&&v!=='sentinel';note.hidden=v!=='caps';
deferred.innerHTML=v==='timelocks'
 ?'<div class="cy-config-block"><h2>Vault Pending Actions</h2><p>The on-chain pending-action index is not yet connected. This is not a claim that no transactions are pending.</p></div><div class="cy-config-block"><h2>Vault Timelocks</h2>'+[['Add Adapter','Changes the vault adapter set'],['Increase Absolute Cap','Allows additional exposure'],['Increase Relative Cap','Changes proportional exposure'],['Allocator','Grants or revokes allocation privileges'],['Performance Fee','Changes yield-based fees'],['Management Fee','Changes annual fee rate']].map(r=>'<div class="cy-config-row"><div><strong>'+r[0]+'</strong><small>'+r[1]+'</small></div><span>Not loaded</span></div>').join('')+'</div><div class="cy-config-block"><h2>Market Adapter Timelocks</h2><p>Adapter-specific delays are shown after a verified adapter registry read is integrated.</p></div>'
 :'<div class="cy-config-block"><h2>Sentinel Addresses</h2><p>Active sentinel roles are not yet read from this vault. Do not assume any sample address is authorized.</p></div><div class="cy-config-block"><h2>Emergency Actions</h2>'+[['Decrease Absolute Cap','Reduce permitted exposure'],['Decrease Relative Cap','Reduce proportional exposure'],['Revoke Pending Action','Stop an eligible queued change']].map(r=>'<div class="cy-config-row"><div><strong>'+r[0]+'</strong><small>'+r[1]+'</small></div><span>Read-only</span></div>').join('')+'<p>No transaction controls are presented without verified authority and exact deployed ABI.</p></div><div class="cy-config-block"><h2>Recent Activity</h2><p>Sentinel action history is not indexed yet.</p></div>';
if(summary)summary.hidden=v!=='overview';g.classList.toggle('cy-full',v!=='overview')}
nav.querySelectorAll('button').forEach(b=>b.onclick=()=>{show(b.dataset.section);scrollTo(0,0)});show(tab)}
function decorate(){const page=root.querySelector('.v-page');if(!page||page.dataset.cyDecorated==='11')return;page.dataset.cyDecorated='11';if(create)wizard(page);else dashboard(page)}
new MutationObserver(()=>{if(root.querySelector('.v-page:not([data-cy-decorated="11"])'))decorate()}).observe(root,{childList:true});
decorate();
})();
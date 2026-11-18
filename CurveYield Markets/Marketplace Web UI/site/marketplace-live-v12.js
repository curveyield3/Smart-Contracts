'use strict';
/* CurveYield Marketplace live layer v12 — only verified API and browser-saved data.
   Does not handle signatures, contract writes or pretend to be a complete vault registry. */
(()=>{
if(!document.body.hasAttribute('data-cy-live'))return;
const Q=s=>document.querySelector(s), root=Q('#content'), esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const number=n=>n==null||n===''||!Number.isFinite(Number(n))?null:Number(n);
const f=(n,d=2)=>number(n)==null?'—':Number(n).toLocaleString(undefined,{maximumFractionDigits:d});
const usd=n=>number(n)==null?'—':'$'+f(n,0),pct=n=>number(n)==null?'—':f(n)+'%';
const trunc=s=>String(s||'').length>24?String(s).slice(0,9)+'…'+String(s).slice(-6):String(s||'—');
const okAddress=s=>/^0x[0-9a-f]{40}$/i.test(String(s||'')),okId=s=>/^0x[0-9a-f]{64}$/i.test(String(s||''));
const badge=s=>'<span class="x-token">'+esc(String(s||'✦')[0])+'</span>';
const warn=s=>'<div class="x-disclaimer"><span class="x-dot"></span>'+esc(s)+'</div>';
const blank=(title,msg)=>'<div class="x-empty-panel"><strong>'+esc(title)+'</strong><p>'+esc(msg)+'</p></div>';
const header=(title,msg)=>'<header class="x-pagehead"><h1>'+esc(title)+'</h1><p>'+esc(msg)+'</p></header>';
const marketName=m=>String(m.token||m.loanSymbol||m.assetSymbol||'Token');
const collateral=m=>String(m.collateralSymbol||'cysdFXS');
const mkHref=(id,m)=>m?.factory&&okId(m.id)?'/market/'+m.id:['wfrax','frxusd','sfrxusd'].includes(id)?'/'+id:null;
const link=id=>'/markets/'+encodeURIComponent(id);
let cached=null,until=0,account=null,pending=0;
async function markets(){if(cached&&Date.now()<until)return cached;const r=await fetch('/api/markets',{cache:'no-store'});if(!r.ok)throw Error('Market API HTTP '+r.status);const d=await r.json();if(d.chainId!==252||!d.markets||d.networkOk===false)throw Error('Fraxtal market data could not be verified');cached=d;until=Date.now()+8000;return d;}
const marketRows=d=>Object.entries(d.markets).filter(([k,m])=>m&&!m.error).sort((a,b)=>(number(b[1].borrowUsd)||0)-(number(a[1].borrowUsd)||0));
const marketConvert=([key,m])=>({id:key,loan:marketName(m),collateral:collateral(m),lltv:pct(m.lltv),supplied:number(m.supply)!=null?f(m.supply):'—',liquidity:number(m.liquidity)!=null?f(m.liquidity):'—',borrow:pct(m.borrowApr),lend:pct(m.lendApr),protocol:'CurveYield',symbol:marketName(m).slice(0,1)});
const vaultRecords=()=>{try{const list=JSON.parse(localStorage.getItem('cy-vaults-fraxtal-v1')||'[]');return Array.isArray(list)?list.filter(x=>okAddress(x.address)).slice(0,70):[]}catch{return[]}};
function side(){
 for(const g of document.querySelectorAll('.side-section'))if(/^(Favorites|My Vaults)/.test(g.querySelector('.section-label')?.textContent?.trim()||''))g.hidden=true;
 const mapping={'#/overview':'/','#/markets':'/markets','#/vaults':'/vaults','#/portfolio/positions':'/portfolio','#/markets/create':'/create','#/vaults/create':'/vaults/create'};
 for(const a of document.querySelectorAll('.side-link')){const h=a.getAttribute('href')||'';if(mapping[h])a.setAttribute('href',mapping[h]);if(h==='#/oracles'||h==='#/liquidations'){a.hidden=true;a.style.display='none';}}
 Q('.wordmark')?.setAttribute('href','/');
 for(const a of document.querySelectorAll('.collapsed-create,.side-head .gold-btn'))a.setAttribute('href','/vaults/create');
 const w=Q('.wallet-pill');if(w){w.onclick=connect;const n=w.querySelector('.wallet-name'),s=w.querySelector('.connected');if(n)n.textContent=account?trunc(account):'Connect wallet';if(s)s.textContent=account?'Connected':'Wallet';}
}
function paint(html){root.innerHTML=html;root.classList.add('explorer-layout');root.classList.remove('dash-layout');}
function unavailable(title,e){paint('<div class="x-explorer">'+header(title,'Live Fraxtal information')+'<div class="x-content">'+blank('Data temporarily unavailable',String(e?.message||e))+'<button type="button" class="secondary-btn" data-retry>Retry</button></div></div>');Q('[data-retry]')?.addEventListener('click',refresh);}
function loading(title){paint('<div class="x-explorer">'+header(title,'Live Fraxtal information')+'<div class="x-content">'+blank('Reading verified data','Loading the existing CurveYield on-chain API.')+'</div></div>');}
function filterLive(){
 const body=Q('.x-table tbody'),search=Q('[data-xsearch]'),asset=Q('[data-xfilter="asset"]'),coll=Q('[data-xfilter="collateral"]'),sort=Q('[data-xsort]');if(!body)return;
 const rows=[...body.children];const update=()=>{let count=0;const s=(search?.value||'').toLowerCase().trim();for(const row of rows){const show=(!s||row.dataset.search.includes(s))&&(!asset?.value||row.dataset.asset===asset.value)&&(!coll?.value||row.dataset.collateral===coll.value);row.hidden=!show;if(show)count++;}
 const mode=sort?.value||'size';rows.sort((a,b)=>mode==='name'?a.dataset.name.localeCompare(b.dataset.name):mode==='apy'?Number(b.dataset.apy)-Number(a.dataset.apy):Number(a.dataset.rank)-Number(b.dataset.rank));rows.forEach(x=>body.appendChild(x));if(Q('.x-count'))Q('.x-count').textContent=count+' of '+rows.length+' verified items';if(Q('.x-empty-filter'))Q('.x-empty-filter').hidden=count>0;};
 [search,asset,coll,sort].forEach(n=>n?.addEventListener(n===search?'input':'change',update));update();
}
async function marketDirectory(){loading('Variable Rate Markets');try{const d=await markets(),list=marketRows(d);sampleMarkets.splice(0,sampleMarkets.length,...list.map(marketConvert));let html=xIndex('markets');
 html=html.replace(/<div class="x-disclaimer">[\s\S]*?<\/div>/,warn('Fraxtal rates and balances are returned by the on-chain market API; changes can occur each block.'))
 .replace('Live aggregate not connected',esc('Block '+(d.block??'—'))).replace('>—</strong><small>Block', '>'+(list.some(([k,m])=>Number(m.borrow)>0&&number(m.borrowUsd)===null)?'—':usd(list.reduce((sum,[k,m])=>sum+(number(m.borrowUsd)||0),0)))+'</strong><small>Block')
 .replace(/Preview examples are not contract-verified listings\./,'Market parameters and rates are read live from CurveYield’s Fraxtal API.')
 .replace(/>Open live discovery ↗</,'>Ethereum opportunities ↗</');
 paint(html);for(const td of root.querySelectorAll('.x-table td small'))if(td.textContent==='Illustrative')td.remove();
 filterLive();for(const a of root.querySelectorAll('a[href^="#/markets/"]'))a.href=a.getAttribute('href').replace('#','');
 }catch(e){unavailable('Variable Rate Markets',e)}}
function kv(a,b){return '<div class="x-info-row"><span>'+esc(a)+'</span><strong>'+esc(b)+'</strong></div>'}
function stats(a,b){return '<div class="x-stat"><span>'+esc(a)+'</span><strong>'+esc(b)+'</strong></div>'}
async function marketDetail(id,tab){
 loading('Market details');try{const d=await markets(),m=d.markets[id];if(!m||m.error)throw Error('The requested market is not available in the live API.');
 const active=['positions','risk','activity'].includes(tab)?tab:'overview',name=marketName(m),col=collateral(m),trade=mkHref(id,m),url=link(id);
 let content='';
 if(active==='overview')content='<section class="x-card"><h2>Market overview</h2><div class="x-mini-grid">'+stats('Outstanding loans',number(m.borrow)!=null?f(m.borrow)+' '+name:'—')+stats('Liquidity',number(m.liquidity)!=null?f(m.liquidity)+' '+name:'—')+stats('Utilization',pct(m.utilization))+'</div></section><section class="x-card"><h2>Market parameters</h2>'+kv('Loan asset',name)+kv('Collateral asset',col)+kv('LLTV',pct(m.lltv))+kv('Borrow APR',pct(m.borrowApr))+kv('Lend APR',pct(m.lendApr))+kv('Oracle',trunc(m.oracle))+'</section>';
 else if(active==='risk')content='<section class="x-card"><h2>Market risk</h2><p>Borrow positions can be liquidated according to their collateral thresholds and oracle prices.</p>'+kv('LLTV',pct(m.lltv))+kv('Utilization',pct(m.utilization))+kv('Oracle price',number(m.oraclePrice)==null?'Unavailable':f(m.oraclePrice,6))+'</section>';
 else if(active==='positions')content='<section class="x-card"><h2>My position</h2><div data-live-pos>'+blank('Connect a wallet','Read your supply, borrowing and collateral balances on Fraxtal.')+'</div><button type="button" class="secondary-btn" data-connect>Connect wallet</button></section>';
 else content='<section class="x-card"><h2>Market activity</h2><div data-live-events>Loading on-chain events…</div></section>';
 const tabs=['overview','positions','risk','activity'].map(t=>'<a href="'+url+'/'+t+'" class="'+(t===active?'active':'')+'">'+t[0].toUpperCase()+t.slice(1)+'</a>').join('');
 paint('<div class="x-detail"><div class="x-detail-head"><div class="x-entity-identity">'+badge(name)+'<div><div class="x-detail-eyebrow"><a href="/markets">Variable Rate Markets</a> › ✦ Fraxtal</div><h1>'+esc(name)+' / '+esc(col)+'</h1><p>On-chain CurveYield market · '+esc(id)+'</p></div></div></div><nav class="x-subtabs">'+tabs+'</nav>'+warn('On-chain data only. Historical charts are omitted until an authoritative history source is connected.')+'<div class="x-detail-grid"><div class="x-detail-main">'+content+'</div><aside class="x-action-card"><h2>Market actions</h2><p>The existing trading interface handles Lend, Borrow, Repay and Withdraw transactions.</p>'+(trade?'<a class="gold-btn" href="'+esc(trade)+'">Open live trading →</a>':'<p>Direct trading is not yet enabled for this discovered market.</p>')+'</aside></div></div>');
 if(active==='positions'){Q('[data-connect]')?.addEventListener('click',connect);if(account)await marketPosition(id,m);}
 if(active==='activity'){const e=Q('[data-live-events]');try{const r=await fetch('/api/activity/'+encodeURIComponent(id));if(!r.ok)throw Error('Events HTTP '+r.status);const doc=await r.json(),items=Array.isArray(doc.activity)?doc.activity:[];e.innerHTML=items.length?'<div class="x-table-scroll"><table class="x-table"><thead><tr><th>Action</th><th>Amount</th><th>Block</th><th>Transaction</th></tr></thead><tbody>'+items.slice(0,30).map(x=>'<tr><td>'+esc(x.kind)+'</td><td>'+f(x.amount)+' '+esc(x.asset)+'</td><td>'+esc(x.block)+'</td><td><a href="https://fraxscan.com/tx/'+esc(x.txHash)+'" target="_blank" rel="noopener">'+esc(trunc(x.txHash))+' ↗</a></td></tr>').join('')+'</tbody></table></div>':blank('No events in the available index window','Market history is bounded to the available Fraxtal event window.');}catch(err){e.innerHTML=blank('Market activity unavailable',err.message)}}
 }catch(e){unavailable('Market details',e)}}
async function marketPosition(id,m){if(!account||!Q('[data-live-pos]'))return;try{const query='/api/positions?wallet='+encodeURIComponent(account)+(okId(id)?'&market='+encodeURIComponent(id):'');const r=await fetch(query,{cache:'no-store'});if(!r.ok)throw Error('Position API HTTP '+r.status);const d=await r.json();if(d.chainId!==252)throw Error('Position response chain mismatch');const p=d.positions?.[id.toLowerCase()]??d.positions?.[id];if(!p||p.error)throw Error(p?.error||'Position not returned');Q('[data-live-pos]').innerHTML=kv('Supplied',f(p.supplyAssets)+' '+marketName(m))+kv('Borrowed',f(p.debtAssets)+' '+marketName(m))+kv('Collateral',f(p.collateral)+' '+collateral(m))+kv('LTV',pct(p.ltv));}catch(err){Q('[data-live-pos]').innerHTML=blank('Position unavailable',err.message)}}
async function vaultDirectory(){
 loading('Vaults');
 const saved=vaultRecords(),indexed=[],known=new Set();let cursor=null,available=false,error='';
 async function loadPage(next){
  const url='/api/vault-directory'+(next?'?cursor='+encodeURIComponent(next):'');
  const r=await fetch(url,{cache:'no-store'}),d=await r.json();
  if(!r.ok||!d.available||d.chainId!==252||!Array.isArray(d.vaults))throw Error(d.error||'Index provider unavailable');
  for(const v of d.vaults)if(okAddress(v.address)&&!known.has(v.address.toLowerCase())){known.add(v.address.toLowerCase());indexed.push(v)}
  cursor=d.cursor||null;available=true;
 }
 try{await loadPage(null)}catch(e){error=String(e.message||e)}
 function show(){
  const rows=indexed.map(v=>({address:v.address,name:v.name||v.symbol||'Vault V2',asset:v.asset,source:'Factory events'}));
  for(const v of saved)if(!known.has(v.address.toLowerCase()))rows.push({address:v.address,name:v.name||'Vault V2',source:'Browser-saved'});
  paint('<div class="x-explorer">'+header('Vaults','Browse indexed Fraxtal Vault V2 contracts and saved addresses.')+'<div class="x-content">'+
   '<div class="x-summary"><div><span>Factory event vaults loaded</span><strong>'+indexed.length+'</strong><small>'+(cursor?'Additional pages available':available?'Index page set complete':'Index unavailable')+'</small></div><a class="x-summary-link" href="/vaults/create">Create Vault ↗</a></div>'+
   warn(available?'Entries come from official Fraxtal factory CreateVaultV2 event logs. If coverage is partial, load earlier pages. Each contract is verified when opened.':'Index unavailable: '+error+'. Browser-saved vaults appear below.')+
   '<label>Search <input type="search" data-cy-vsearch placeholder="Vault name or address"></label>'+
   '<div class="x-table-scroll"><table class="x-table"><thead><tr><th>Vault</th><th>Asset contract</th><th>Source</th><th>Open</th></tr></thead><tbody>'+
   rows.map(v=>'<tr data-cy-vrow data-name="'+esc((v.name+' '+v.address).toLowerCase())+'"><td>'+esc(v.name)+'<small>'+esc(trunc(v.address))+'</small></td><td>'+esc(trunc(v.asset))+'</td><td>'+esc(v.source)+'</td><td><a href="/vaults/'+esc(v.address)+'">Verify & open →</a></td></tr>').join('')+
   '</tbody></table></div>'+(rows.length?'':blank('No vaults available','No indexed or browser-saved vaults in this view.'))+
   (cursor?'<button type="button" class="secondary-btn" data-cy-load>Load more vaults</button>':'')+
   '<section class="x-card" style="margin-top:20px"><h2>Open a deployed vault</h2><div class="v-import"><input id="cy-vaddr" placeholder="0x vault address" style="flex:1;min-width:0"><button type="button" class="gold-btn" data-open-vault>Open vault</button></div><p data-vault-error></p></section></div></div>');
  Q('[data-cy-vsearch]')?.addEventListener('input',e=>{const q=e.target.value.toLowerCase();for(const row of root.querySelectorAll('[data-cy-vrow]'))row.hidden=!row.dataset.name.includes(q)});
  Q('[data-open-vault]')?.addEventListener('click',()=>{const addr=Q('#cy-vaddr').value.trim();if(okAddress(addr))location.assign('/vaults/'+addr);else Q('[data-vault-error]').textContent='Enter a valid 0x vault address.'});
  Q('[data-cy-load]')?.addEventListener('click',async e=>{e.currentTarget.disabled=true;try{await loadPage(cursor)}catch(ex){error=String(ex.message||ex);cursor=null}show()});
 }
 show();
}
async function portfolio(tab){paint('<div class="portfolio-page"><header class="portfolio-heading"><h1>Portfolio</h1><p>Read-only account positions on Fraxtal.</p></header><nav class="portfolio-tabs">'+[['positions','My positions'],['vaults','My vaults'],['activity','My activity']].map(([k,v])=>'<a class="portfolio-tab '+(tab===k?'active':'')+'" href="/portfolio/'+k+'">'+v+'</a>').join('')+'</nav><div class="portfolio-content"><div data-portfolio>'+blank('Connect your wallet','Account positions are only shown when returned by the on-chain API.')+'</div><div class="portfolio-wallet-callout"><div><strong>'+(account?esc(trunc(account)):'No wallet connected')+'</strong><p>Verified Fraxtal market positions are read without signing.</p></div><button class="secondary-btn" data-connect>'+(account?'Refresh':'Connect wallet')+'</button></div></div></div>');
 Q('[data-connect]')?.addEventListener('click',account?()=>portfolioData(tab):connect);if(account)await portfolioData(tab);}
async function portfolioData(tab){const el=Q('[data-portfolio]');if(!el||!account)return;
 if(tab==='vaults'){const list=vaultRecords();el.innerHTML=warn('Saved vaults are not verified as owned or curated by this wallet until opened.')+(list.length?list.map(x=>'<div class="x-info-row"><span>'+esc(x.name||'Vault V2')+'</span><a href="/vaults/'+esc(x.address)+'">Verify and open ↗</a></div>').join(''):blank('No saved vaults','Open a deployed vault to add it to your recent list.'));return}
 if(tab==='activity'){
  el.innerHTML=blank('Reading wallet activity','Scanning indexed Fraxtal market events for this wallet.');
  try{
   const r=await fetch('/api/portfolio-activity?wallet='+encodeURIComponent(account),{cache:'no-store'}),d=await r.json();
   if(!r.ok||d.chainId!==252||!Array.isArray(d.activity))throw Error(d.error||'Activity unavailable');
   el.innerHTML=warn('Coverage: '+d.scope+'. Blocks '+d.fromBlock+'–'+d.toBlock+'. Older events may exist.')+
    (d.activity.length?'<div class="portfolio-table-scroller"><table class="portfolio-table"><thead><tr><th>Action</th><th>Market</th><th>Block</th><th>Transaction</th></tr></thead><tbody>'+
       d.activity.map(x=>'<tr><td>'+esc(x.kind)+'</td><td>'+esc(x.market)+'</td><td>'+esc(x.block)+'</td><td><a href="https://fraxscan.com/tx/'+esc(x.txHash)+'" target="_blank" rel="noopener">'+esc(trunc(x.txHash))+' ↗</a></td></tr>').join('')+'</tbody></table></div>':
       blank('No activity in the scanned window','This does not imply there is no earlier activity.'))+
     '<p><a href="https://fraxscan.com/address/'+encodeURIComponent(account)+'" target="_blank" rel="noopener">Full wallet history on Fraxscan ↗</a></p>';
  }catch(ex){el.innerHTML=blank('Activity unavailable',ex.message)}
  return;
 }
 el.innerHTML=blank('Loading positions','Reading current Fraxtal balances.');
 try{const [r,d]=await Promise.all([fetch('/api/positions?wallet='+encodeURIComponent(account),{cache:'no-store'}),markets()]);if(!r.ok)throw Error('Position API HTTP '+r.status);const p=await r.json();if(p.chainId!==252||!p.positions)throw Error('Unrecognized position response');const items=Object.entries(p.positions).filter(([k,x])=>x&&!x.error&&(Number(x.supplyAssets)>0||Number(x.debtAssets)>0||Number(x.collateral)>0));el.innerHTML='<div class="portfolio-metrics"><div><span>Markets with positions</span><strong>'+items.length+'</strong><small>Verified Fraxtal reads</small></div><div><span>Total supplied</span><strong>'+(items.some(([k,x])=>Number(x.supplyAssets)>0&&number(x.supplyUsd)===null)?'—':usd(items.reduce((n,[k,x])=>n+(number(x.supplyUsd)||0),0)))+'</strong></div><div><span>Total borrowed</span><strong>'+(items.some(([k,x])=>Number(x.debtAssets)>0&&number(x.debtUsd)===null)?'—':usd(items.reduce((n,[k,x])=>n+(number(x.debtUsd)||0),0)))+'</strong></div></div><h2>Your positions</h2>'+(items.length?'<div class="portfolio-table-scroller"><table class="portfolio-table"><thead><tr><th>Market</th><th>Supplied</th><th>Borrowed</th><th>Collateral</th><th>LTV</th></tr></thead><tbody>'+items.map(([k,x])=>'<tr><td><a href="'+link(k)+'">'+esc(marketName(d.markets[k]||{}))+'</a></td><td>'+f(x.supplyAssets)+'</td><td>'+f(x.debtAssets)+'</td><td>'+f(x.collateral)+'</td><td>'+pct(x.ltv)+'</td></tr>').join('')+'</tbody></table></div>':blank('No nonzero market positions','The connected wallet has no positions in the markets covered by this API.'))+warn('Coverage is limited to the Fraxtal markets in the /api/positions endpoint. Vault shares and other protocols are not included.');}catch(err){el.innerHTML=blank('Unable to read positions',err.message)}}
function home(){paint('<div class="x-explorer">'+header('Explore CurveYield','Browse live markets, saved vaults, and your Fraxtal portfolio.')+'<div class="x-content"><div class="x-home-links"><a href="/vaults"><span class="x-home-icon">▦</span><strong>Vaults</strong><small>Open recently saved vaults</small><span>Browse vaults →</span></a><a href="/markets"><span class="x-home-icon">◇</span><strong>Variable Rate Markets</strong><small>Live rates, collateral and liquidity</small><span>Explore markets →</span></a><a href="/portfolio"><span class="x-home-icon">◫</span><strong>Portfolio</strong><small>Read account-linked positions</small><span>Open portfolio →</span></a></div><h2 class="x-home-subtitle">Explore opportunities</h2><div class="x-shortcuts"><a href="/opportunities">Ethereum opportunities ↗</a><a href="/create">Create a market ↗</a></div></div></div>')}
async function connect(){if(!window.ethereum){const el=Q('[data-portfolio]')||Q('[data-live-pos]');if(el)el.innerHTML=blank('No wallet provider','Install MetaMask, Rabby, or another EIP-1193 wallet.');return}try{const list=await window.ethereum.request({method:'eth_requestAccounts'});if(!okAddress(list?.[0]))throw Error('No wallet selected');account=list[0];refresh();}catch(err){const el=Q('[data-portfolio]')||Q('[data-live-pos]');if(el)el.innerHTML=blank('Connection failed',err.message)}}
async function refresh(){side();document.title=location.pathname.startsWith('/markets/')?'Market details · CurveYield':location.pathname.startsWith('/markets')?'Markets · CurveYield':location.pathname.startsWith('/portfolio')?'Portfolio · CurveYield':location.pathname.startsWith('/vaults')?'Vaults · CurveYield':'CurveYield Marketplace';const hash=location.hash.replace(/^#\/?/,'');const page=hash&&/^(markets|vaults|portfolio|overview)(\/|$)/.test(hash)?'/'+hash:location.pathname;const parts=page.split('/').filter(Boolean);
 if(parts[0]==='markets'){if(parts[1])return marketDetail(parts[1],parts[2]);return marketDirectory();}
 if(parts[0]==='vaults')return vaultDirectory();
 if(parts[0]==='portfolio')return portfolio(['positions','vaults','activity'].includes(parts[1])?parts[1]:'positions');
 return home();}
window.addEventListener('hashchange',refresh);
window.ethereum?.on?.('accountsChanged',accounts=>{account=okAddress(accounts?.[0])?accounts[0]:null;refresh()});
window.ethereum?.request?.({method:'eth_accounts'}).then(list=>{if(okAddress(list?.[0])){account=list[0];refresh()}}).catch(()=>{});
refresh();
})();
// CurveYield Markets Worker v188 — R2 durable protocol batches and per-token views; original market logic retained.
const HTML="<!doctype html>\n<html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1,viewport-fit=cover\"><meta name=\"theme-color\" content=\"#fffdfa\"><meta name=\"description\" content=\"CurveYield Markets — lend and borrow WFRAX, frxUSD and sfrxUSD against cysdFXS on Fraxtal, powered by Morpho Blue.\"><title>CurveYield Markets · Fraxtal lending</title><link rel=\"icon\" href=\"/assets/curveyield-logo.webp\" type=\"image/webp\"><link rel=\"stylesheet\" href=\"/assets/app.css\"></head>\n<body>\n<div class=\"app-root\">\n<header class=\"topbar\"><div class=\"navinner\"><a class=\"brand\" href=\"/\" aria-label=\"CurveYield Markets home\"><span class=\"brand-mark\"><img src=\"/assets/curveyield-logo.webp\" width=\"40\" height=\"40\" alt=\"Official CurveYield logo\" decoding=\"async\"></span><span class=\"brand-type\"><strong>CURVEYIELD</strong><small>MARKETS</small></span></a><nav class=\"mainnav\" aria-label=\"Main navigation\"><a href=\"/\" data-nav=\"markets\" class=\"active\">Markets</a><a href=\"/create\" data-nav=\"create\">Create Market</a><a href=\"/vaults\">Vaults</a><a href=\"/opportunities\">Opportunities</a><a href=\"https://docs.curveyield.com/\" target=\"_blank\" rel=\"noopener\">Docs <span class=\"ext-icon\">↗</span></a></nav><div class=\"header-end\"><span class=\"chain-pill\"><span class=\"chain-dot\"></span>Fraxtal</span><button id=\"walletButton\" class=\"connect-btn\" type=\"button\"><svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.7\"><rect x=\"3\" y=\"6\" width=\"18\" height=\"14\" rx=\"3\"/><path d=\"M3 9h18M7 6V4h11\"/></svg><span id=\"walletButtonText\">Connect Wallet</span></button></div></div></header>\n<main id=\"page\" aria-live=\"polite\"></main>\n<footer class=\"sitefooter\"><div class=\"footinner\"><span class=\"footbrand\">✧ CURVEYIELD <span>MARKETS</span></span><div class=\"footnav\"><a href=\"https://fraxscan.com/address/0xcce2862aed7f2248063c3dcf6906582166c2b6ca\" target=\"_blank\" rel=\"noopener\">Morpho Blue ↗</a><a href=\"https://docs.curveyield.com/\" target=\"_blank\" rel=\"noopener\">Docs ↗</a><a href=\"https://boosthub.curveyield.org/\" target=\"_blank\" rel=\"noopener\">BoostHub ↗</a></div><span class=\"footnote\">Non-custodial · Fraxtal chain 252 · © 2026 CurveYield</span></div></footer>\n</div>\n<div id=\"toast\" class=\"toast\" role=\"status\" aria-live=\"polite\"></div>\n<script defer src=\"https://boosthub.curveyield.org/vendor/ethers.umd.min.js\"></script><script defer src=\"/assets/app.js\"></script>\n</body></html>\n";
const CSS = ":root{color-scheme:light;--ink:#15171c;--black:#0c1016;--muted:#7f848b;--muted2:#a1a5aa;--soft:#f8f8f8;--canvas:#fcfcfc;--line:#e9e9e8;--line2:#f0efed;--gold:#c48b02;--gold2:#dd9d00;--gold-fade:#fff7e5;--gold-stroke:#f3dfb1;--ok:#15976c;--danger:#d45a45;--shadow:0 9px 34px rgba(20,20,20,.035);font-family:Inter,-apple-system,BlinkMacSystemFont,\"Segoe UI\",Roboto,Arial,sans-serif;-webkit-font-smoothing:antialiased}\n*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:var(--canvas);color:var(--ink);min-width:320px;font-size:14px}button,input,select{font:inherit}button{cursor:pointer}a{color:inherit;text-decoration:none}a:focus-visible,button:focus-visible,input:focus-visible,select:focus-visible{outline:3px solid rgba(204,150,17,.24);outline-offset:2px}button:disabled{opacity:.5;cursor:not-allowed}.app-root{min-height:100vh;display:flex;flex-direction:column}.topbar{height:73px;background:white;border-bottom:1px solid #edeeed;position:sticky;top:0;z-index:40}.navinner{height:100%;max-width:1600px;padding:0 58px;margin:auto;display:flex;align-items:center;gap:53px}.brand{display:inline-flex;align-items:center;gap:11px;white-space:nowrap;min-width:185px}.brand-mark{color:var(--gold);display:grid;place-items:center}.brand-type{display:flex;flex-direction:column;letter-spacing:.125em;line-height:1.1}.brand-type strong{font-size:15px;font-weight:850}.brand-type small{color:var(--gold);font-weight:800;font-size:9px;letter-spacing:.27em;margin-top:4px}.mainnav{display:flex;align-items:center;gap:9px;height:100%}.mainnav a{padding:12px 18px;color:#73777c;font-weight:560;border-radius:11px;white-space:nowrap}.mainnav a.active,.mainnav a:hover{background:#f6f6f5;color:#15171c}.ext-icon{font-size:12px;color:#93989c}.header-end{display:flex;align-items:center;gap:13px;margin-left:auto}.chain-pill{border:1px solid var(--line);background:#fafafa;border-radius:22px;white-space:nowrap;color:#4f5359;padding:11px 13px;font-weight:600;font-size:12px}.chain-dot{display:inline-block;width:8px;height:8px;background:linear-gradient(135deg,#9f7cff,#f2a6ff);border-radius:50%;margin-right:7px}.connect-btn{background:var(--gold2);border:1px solid #cc8f00;color:#fff;box-shadow:0 4px 13px rgba(195,145,13,.13);padding:12px 18px;font-weight:650;border-radius:12px;white-space:nowrap;display:flex;align-items:center;gap:9px}.connect-btn:hover{background:#bb8100}main{flex:1}.container{max-width:1472px;padding:0 65px;margin:0 auto}.topcrumb{display:flex;gap:9px;align-items:center;color:#9a9ca2;font-size:13px;margin:36px 0 26px}.topcrumb a:hover{color:var(--gold)}.topcrumb span:last-child{color:#30333a}.muted{color:var(--muted)}.small{font-size:12px}.tiny{font-size:11px}.nowrap{white-space:nowrap}.monospace{font-family:ui-monospace,Menlo,Monaco,Consolas,monospace;font-size:12px}.textgold{color:var(--gold)}.right{text-align:right}.positive{color:#13926d}.negative{color:#d15e3d}.inline-icon{color:#a7a8ac;margin-left:3px}.over-head{padding:51px 0 24px}.over-head h1{font-size:39px;letter-spacing:-1.55px;margin:0 0 10px;line-height:1.18;font-weight:720}.over-head .sub{font-size:15px;color:#81848a;margin:0}.overview-summary{display:flex;gap:54px;align-items:flex-end;padding:22px 0 32px;border-bottom:1px solid var(--line)}.summary-number{display:flex;flex-direction:column;gap:8px}.summary-number span{font-size:13px;color:#7f858c}.summary-number strong{font-size:29px;font-weight:680;letter-spacing:-.9px}.syncbadge{margin-left:auto;color:#92969a;font-size:12px;display:flex;align-items:center;gap:7px}.statusdot{display:inline-block;width:7px;height:7px;border-radius:50%;background:#b9bdc1}.statusdot.live{background:var(--ok);box-shadow:0 0 0 3px rgba(28,158,115,.08)}.content-title{display:flex;justify-content:space-between;align-items:center;gap:20px;padding:37px 0 22px}.content-title h2{font-size:22px;letter-spacing:-.55px;font-weight:680;margin:0}.content-title small{font-weight:500;color:#999da1}.sort-select{padding:10px 13px;border:1px solid var(--line);background:#fff;border-radius:9px;font-size:13px;color:#63676b;min-width:190px}.filterbar{display:flex;flex-wrap:wrap;align-items:center;gap:10px;margin-bottom:21px}.filterbtn{min-width:116px;background:white;color:#44494f;border:1px solid var(--line);border-radius:9px;padding:12px 14px;display:flex;justify-content:space-between;gap:18px;font-weight:550;align-items:center}.filterbtn span{color:#999;font-size:10px}.searchwrap{margin-left:auto;position:relative}.searchwrap:before{content:'⌕';position:absolute;left:14px;top:8px;color:#a3a4a7;font-size:24px}.searchwrap input{padding:12px 14px 12px 40px;min-width:280px;border:1px solid var(--line);background:white;border-radius:9px;outline:none}.searchwrap input:focus{border-color:#e0c686}.tablewrap{background:white;border:1px solid var(--line);border-radius:13px;overflow:hidden;box-shadow:var(--shadow)}table{width:100%;border-collapse:collapse;table-layout:auto}thead tr{background:#fafafa}th{text-align:left;text-transform:none;white-space:nowrap;color:#90949a;font-weight:560;font-size:12px;padding:17px 19px}td{padding:25px 19px;border-top:1px solid #f1f0f0;vertical-align:middle;font-size:14px;white-space:nowrap}tbody tr{cursor:pointer;transition:background .15s}tbody tr:hover{background:#fffaf0}td:first-child,th:first-child{padding-left:27px}td:last-child,th:last-child{padding-right:27px}.asset{display:inline-flex;align-items:center;gap:11px;font-weight:660;font-size:14px}.coin{width:30px;height:30px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;color:white;font-size:11px;font-weight:780;box-shadow:0 2px 5px rgba(12,13,16,.08);flex-shrink:0}.coin.wfrax{background:linear-gradient(140deg,#1c1e22 9%,#555c67)}.coin.frxusd{background:linear-gradient(155deg,#2e5ac3,#78b1fc)}.coin.sfrxusd{background:linear-gradient(150deg,#2a9b86,#70cec0)}.coin.cysdfxs{background:linear-gradient(140deg,#aa7b00,#f5c35c);color:#2e2200}.coin.smallcoin{width:22px;height:22px;font-size:8px}.tokenpair{display:inline-flex;align-items:center}.tokenpair .coin+.coin{margin-left:-7px;border:2px solid white;box-sizing:content-box}.strong{font-weight:650}.subvalue{color:#a2a5a8;font-size:12px;margin-top:6px}.numeric{font-variant-numeric:tabular-nums}.pill{display:inline-block;border:1px solid #f1e3c8;background:#fffaf0;color:#9b6900;padding:4px 8px;border-radius:7px;font-size:11px;font-weight:650}.riskpill{font-weight:600;background:#f7f7f8;border-radius:7px;padding:5px 9px;color:#555}.overview-footnote{padding:19px 0 70px;color:#a1a1a1;font-size:12px}.empty-row{text-align:center;padding:55px 15px;color:#92969b}.market-section{padding-top:0;padding-bottom:75px}.market-top{display:grid;grid-template-columns:minmax(0,1fr) 355px;gap:42px}.market-head{padding-top:6px}.pair-heading{display:flex;align-items:center;gap:17px;margin:0 0 12px}.pair-heading .tokenpair .coin{width:40px;height:40px;font-size:13px}.pair-heading h1{margin:0;font-weight:690;letter-spacing:-1.5px;font-size:37px;line-height:1.2}.pair-meta{display:flex;align-items:center;gap:9px;color:#9c9fa5;font-size:12px;margin:0 0 39px}.pair-meta .chain-dot{width:7px;height:7px}.mini-link{color:#9c9fa5}.mini-link:hover{color:var(--gold)}.metricgrid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:22px;margin-bottom:39px}.bigmetric{min-width:0}.bigmetric .metriclabel{display:flex;align-items:center;gap:4px;color:#969ba1;font-size:12px;margin-bottom:12px}.bigmetric .metricvalue{font-size:27px;line-height:1.1;font-weight:660;letter-spacing:-.9px}.bigmetric .metricdesc{color:#a5a6aa;margin-top:9px;font-size:12px}.tabbar{border-bottom:1px solid var(--line);display:flex;gap:27px;white-space:nowrap;overflow-x:auto;margin-bottom:30px}.tabbar a{color:#888c91;padding:0 1px 16px;position:relative;font-weight:580}.tabbar a.active{color:#1a1c21}.tabbar a.active:after{content:\"\";height:2px;background:var(--gold);position:absolute;bottom:0;left:0;right:0}.section-block{margin-bottom:34px}.section-block h2{font-size:19px;font-weight:650;letter-spacing:-.4px;margin:0 0 23px}.section-block h3{font-size:15px;font-weight:640;margin:0 0 16px}.attrs{display:grid;grid-template-columns:1fr 1fr;column-gap:40px;row-gap:0}.attribute{display:flex;gap:16px;justify-content:space-between;align-items:center;padding:16px 0;border-bottom:1px solid var(--line2);min-width:0}.attribute .l{color:#888c93;font-size:13px}.attribute .v{font-weight:580;text-align:right;min-width:0;overflow-wrap:anywhere;font-size:13px}.attribute .v .asset{font-size:13px}.attribute .coin{width:22px;height:22px;font-size:9px}.chartbox{border:1px solid var(--line);border-radius:12px;background:white;overflow:hidden;padding:23px;margin:0 0 28px}.chartheader{display:flex;align-items:center;justify-content:space-between;gap:20px;margin-bottom:15px}.chartheader strong{font-size:14px}.chartlegend{color:#a0a5a8;font-size:12px}.chartbox svg{width:100%;height:auto;display:block}.chart-sub{font-size:12px;color:#92969a;margin-top:10px}.stat-inline{display:flex;justify-content:space-between;padding:18px 0;border-bottom:1px solid var(--line2);color:#838990}.stat-inline strong{color:#272a30;font-weight:620}.rate-compare{display:flex;gap:28px;margin-top:21px}.rate-compare strong{font-size:24px}.rate-compare span{display:block;font-size:12px;color:var(--muted);margin-bottom:8px}.activity-empty{padding:52px 20px;text-align:center;background:#fff;border:1px dashed var(--line);border-radius:12px;color:#969a9d}.action-panel{background:#fff;align-self:start;border:1px solid #ececeb;box-shadow:0 18px 48px rgba(22,18,9,.06);border-radius:16px;overflow:hidden;position:sticky;top:103px}.action-tabs{display:grid;grid-template-columns:1fr 1fr;border-bottom:1px solid var(--line)}.action-tabs button{background:#fff;border:0;padding:20px 8px;font-weight:620;color:#858a8f;position:relative}.action-tabs button.selected{color:var(--gold)}.action-tabs button.selected:after{content:\"\";background:var(--gold);position:absolute;bottom:0;left:26px;right:26px;height:2px}.action-content{padding:24px}.operation-pills{display:flex;background:#f7f7f6;border-radius:11px;padding:4px;gap:3px;margin-bottom:25px;overflow-x:auto}.operation-pills button{flex:1;background:none;border:0;padding:10px 7px;font-size:12px;border-radius:8px;color:#8a8d92;white-space:nowrap}.operation-pills button.chosen{background:#fff;color:#17191d;box-shadow:0 1px 5px rgba(0,0,0,.07)}.inputlabel{display:flex;justify-content:space-between;color:#92979d;font-size:12px;margin-bottom:12px}.amountfield{border:1px solid #e9e9e6;border-radius:11px;padding:14px 13px;display:flex;align-items:center;gap:9px}.amountfield:focus-within{border-color:#dcb755}.amountfield input{min-width:0;width:100%;border:0;outline:0;font-size:26px;font-weight:530;color:#181a20;background:transparent}.amountfield input::placeholder{color:#cacacb}.tokenselect{display:flex;align-items:center;gap:6px;background:#f6f6f5;border-radius:9px;padding:8px 9px;flex-shrink:0;font-size:12px;font-weight:690}.tokenselect .coin{width:20px;height:20px;font-size:8px}.usdline{display:flex;justify-content:space-between;align-items:center;color:#a1a5a7;font-size:12px;margin:10px 0 24px}.maxlink{background:none;border:0;color:var(--gold);font-size:12px;font-weight:730;padding:0}.action-primary{width:100%;background:#d59600;color:white;border:1px solid #c78a00;border-radius:11px;font-weight:700;padding:16px 12px;font-size:14px}.action-primary:hover{background:#b67d00}.panel-details{margin-top:20px;border-top:1px solid #f0f0ef;padding-top:9px}.panel-details .stat-inline{font-size:12px;padding:13px 0}.positionbox{padding:17px 0 1px;border-bottom:1px solid #ededeb}.position-title{font-size:13px;font-weight:700;margin-bottom:7px}.position-grid{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin:13px 0 19px}.position-grid span{color:#969a9e;font-size:11px}.position-grid strong{display:block;color:#282c31;font-size:15px;margin-top:6px}.notice{color:#9b742c;background:#fff8e8;border:1px solid #f9ecd0;padding:12px;border-radius:9px;font-size:11px;line-height:1.5;margin-top:17px}.riskbar{height:8px;background:#f1f1f0;border-radius:50px;overflow:hidden;margin:12px 0 18px}.riskbar>span{display:block;height:100%;background:linear-gradient(90deg,#ddb347,#ce8300);width:0;max-width:100%;border-radius:50px}.loading{animation:blink 1.4s infinite;opacity:.65}@keyframes blink{50%{opacity:1}}.toast{position:fixed;right:23px;bottom:24px;max-width:420px;color:#fff;background:#24282d;padding:14px 18px;box-shadow:0 12px 42px rgba(0,0,0,.2);border-radius:11px;z-index:150;font-size:13px;display:none}.toast.show{display:block}.sitefooter{border-top:1px solid var(--line);background:white}.footinner{margin:auto;max-width:1472px;padding:25px 65px;display:flex;align-items:center;justify-content:space-between;gap:22px;color:#999da2;font-size:11px}.footbrand{color:#b58300;font-weight:850;letter-spacing:.14em}.footbrand span{color:#b8a576;font-size:9px}.footnav{display:flex;gap:18px}.footnav a:hover{color:var(--gold)}.footnote{text-align:right}\n@media(max-width:1230px){.container,.footinner{padding-left:35px;padding-right:35px}.navinner{padding:0 34px}.market-top{grid-template-columns:minmax(0,1fr) 330px;gap:24px}.metricgrid{gap:12px}.bigmetric .metricvalue{font-size:23px}.tablewrap{overflow-x:auto}table{min-width:1050px}}\n@media(max-width:960px){.navinner{gap:17px}.brand{min-width:auto}.mainnav{gap:0}.mainnav a{padding:12px 9px}.market-top{grid-template-columns:minmax(0,1fr)}.action-panel{position:static;max-width:100%}.market-head{min-width:0}.metricgrid{grid-template-columns:repeat(4,1fr)}.topcrumb{margin-top:25px}.over-head{padding-top:38px}}\n@media(max-width:700px){.topbar{height:65px}.container,.footinner{padding-left:17px;padding-right:17px}.navinner{padding:0 16px;gap:10px}.brand-type strong{font-size:13px}.brand-type small{font-size:8px}.brand-mark svg{width:24px;height:24px}.mainnav{margin-left:auto}.mainnav a{padding:8px;font-size:12px}.mainnav a:not(.active){display:none}.header-end{margin-left:0;gap:8px}.chain-pill{display:none}.connect-btn{font-size:12px;padding:10px 11px}.connect-btn svg{display:none}.over-head h1{font-size:32px;letter-spacing:-1.1px}.over-head .sub{font-size:13px;line-height:1.6}.overview-summary{gap:28px;flex-wrap:wrap}.summary-number strong{font-size:23px}.syncbadge{width:100%;margin-left:0}.content-title{padding-top:27px;flex-wrap:wrap}.content-title h2{font-size:20px}.sort-select{min-width:145px}.filterbar{gap:7px}.filterbtn{padding:9px 10px;min-width:105px;font-size:12px}.searchwrap{width:100%;margin-left:0}.searchwrap input{width:100%;min-width:0}.tablewrap{overflow:hidden;background:transparent;border:0;box-shadow:none;border-radius:0}table{min-width:0}thead{display:none}tbody{display:grid;gap:12px}tbody tr{display:grid;grid-template-columns:1fr 1fr;gap:15px;border:1px solid var(--line);border-radius:12px;background:#fff;padding:20px 17px}td{padding:0!important;border:0!important;white-space:normal;font-size:14px}td:before{content:attr(data-label);display:block;font-size:11px;color:#92969a;margin-bottom:7px}td:first-child{grid-column:1/3}td:nth-child(2),td:nth-child(3){grid-column:auto}td:nth-child(4){grid-column:1}td:nth-child(5){grid-column:2}td:last-child{grid-column:2}td .subvalue{font-size:11px}.market-top{gap:22px}.pair-heading h1{font-size:30px}.metricgrid{grid-template-columns:1fr 1fr;row-gap:27px;margin-bottom:30px}.bigmetric .metricvalue{font-size:25px}.pair-meta{margin-bottom:29px;flex-wrap:wrap}.attrs{grid-template-columns:1fr}.tabbar{gap:22px}.chartbox{padding:14px}.rate-compare{gap:22px}.footinner{flex-wrap:wrap}.footnote{text-align:left}.sitefooter{margin-top:15px}}\n@media(max-width:375px){.brand-type small{display:none}.brand-type strong{font-size:11px}.brand-mark svg{width:23px}.connect-btn{padding:10px 8px;font-size:11px}.mainnav a{font-size:11px}.summary-number strong{font-size:21px}.metricgrid{gap:13px}.bigmetric .metricvalue{font-size:22px}}\n\n/* Official CurveYield and Stake DAO sdFXS graphics — v3 */\n.brand-mark img{width:40px;height:40px;display:block;object-fit:contain;border-radius:0}\n.coin.cysdfxs{background:transparent!important;box-shadow:none!important;color:transparent;overflow:hidden}\n.authentic-sdfxs{display:block;width:100%;height:100%;object-fit:contain;border-radius:50%}\n.collateral-spotlight{margin-top:32px;display:flex;align-items:center;gap:30px;background:#fff;border:1px solid #e9e6dc;border-radius:15px;padding:18px;box-shadow:0 2px 10px rgba(29,28,17,.025);max-width:850px}\n.collateral-spotlight img{height:176px;width:176px;object-fit:cover;border-radius:10px;flex:none}\n.collateral-spotlight .spotlight-eyebrow{color:#a77a18;font-size:11px;letter-spacing:.16em;font-weight:800}\n.collateral-spotlight h3{font-size:23px;margin:9px 0 5px;font-weight:700;letter-spacing:-.4px}\n.collateral-spotlight p{font-size:14px;line-height:1.6;color:#72767e;max-width:480px;margin:0 0 13px}\n.collateral-spotlight a{font-size:13px;color:#ac7800;font-weight:700}\n@media(max-width:640px){.brand-mark img{width:32px;height:32px}.collateral-spotlight{gap:14px;padding:12px;margin-top:20px}.collateral-spotlight img{width:116px;height:116px}.collateral-spotlight h3{font-size:19px}.collateral-spotlight p{font-size:12px;line-height:1.35}.collateral-spotlight a{font-size:12px}}\n\n/* v4: real USD valuations, on-chain history and clear missing-value states. */\n.position-usd{display:block;font-size:11px;font-weight:500;color:#85898e;padding-top:3px}.event-list{display:flex;flex-direction:column;border:1px solid #ebebeb;border-radius:11px;overflow:hidden}.event-row{display:grid;grid-template-columns:1.3fr 1fr auto;gap:12px;align-items:center;padding:15px 16px;border-bottom:1px solid #f0f0f0;font-size:13px}.event-row:last-child{border-bottom:0}.event-row:hover{background:#fffaf0}.event-row strong{font-weight:600}.event-row small{color:#929497}.event-row span{font-variant-numeric:tabular-nums}@media(max-width:640px){.event-row{grid-template-columns:1fr auto;gap:5px;padding:12px}.event-row small{grid-column:1/-1}}\n\n.coin img.frax-token-logo{display:block;width:100%;height:100%;object-fit:cover;border-radius:50%}\n\n\n/* CurveYield Creator — v7. Same market grid and typographic hierarchy, new finance-specific form. */\n.create-shell{padding-bottom:64px}.create-head{padding:14px 0 38px}.create-eyebrow{display:block;letter-spacing:.16em;font-size:10px;font-weight:800;color:#a77a19}\n.create-head h1{font-size:38px;letter-spacing:-1.3px;margin:12px 0}.create-head p{font-size:15px;line-height:1.75;color:#878b91;max-width:740px;margin:0}\n.create-grid{display:grid;grid-template-columns:minmax(0,1.42fr) minmax(295px,.85fr);gap:29px;align-items:start}\n.create-form{display:flex;flex-direction:column;gap:18px}.create-card,.create-summary-card{border:1px solid #e9e8e4;border-radius:15px;background:#fff;padding:27px 30px;box-shadow:var(--shadow)}\n.create-card-header{display:flex;justify-content:space-between;align-items:start;gap:20px;margin-bottom:25px}\n.create-card-header span{font-size:10px;letter-spacing:.12em;color:#bc8b26;font-weight:760}.create-card-header h2,.create-summary-card h2{font-size:20px;letter-spacing:-.55px;margin:8px 0 0}\n.create-chain{font-size:11px!important;color:#6e637f!important;letter-spacing:0!important;white-space:nowrap}\n.create-field{display:block;margin:0 0 19px}.create-field:last-child{margin-bottom:0}.create-field>span{display:block;color:#4f5459;font-size:12px;font-weight:650;margin-bottom:8px}\n.create-field input,.create-field select{font-family:inherit;width:100%;padding:13px 13px;font-size:13px;border:1px solid #e7e6e2;border-radius:9px;outline:none;color:#22262c;background:#fff}\n.create-field input:focus,.create-field select:focus{border-color:#cba849;box-shadow:0 0 0 3px rgba(201,160,38,.1)}\n.create-field small{display:block;color:#9ca1a7;line-height:1.5;margin-top:7px;font-size:11px}\n.create-fee-input{display:flex;align-items:center;border:1px solid #e7e6e2;border-radius:9px;overflow:hidden;max-width:230px}.create-fee-input input{border:0;border-radius:0;font-size:24px;font-weight:670;padding:12px 15px}.create-fee-input strong{font-size:21px;color:#a47b17;padding:0 15px}\n.create-summary{position:sticky;top:100px}.create-summary-card h2{margin:10px 0 24px;line-height:1.4}.create-total{display:flex;flex-direction:column;gap:10px}.create-total span{font-size:12px;color:#8d9196}.create-total strong{font-size:44px;font-weight:720;letter-spacing:-1.8px;color:#161a1f}\n.create-split-bar{height:10px;background:#e9e9e8;border-radius:99px;overflow:hidden;margin:22px 0 18px}.create-split-bar span{height:100%;background:linear-gradient(90deg,#bd8800,#f2c45a);display:block;border-radius:99px}\n.create-summary-row{display:flex;justify-content:space-between;padding:12px 0;font-size:14px}.create-summary-row b{font-size:15px}.create-dot{display:inline-block;width:9px;height:9px;border-radius:50%;background:#caa036;margin-right:8px}.create-dot.grey{background:#b6b6b6}\n.create-calculation{border-top:1px solid #efeeea;margin-top:24px;padding-top:21px}.create-calculation strong{font-size:13px}.create-calculation p{font-size:12px;line-height:1.65;color:#84898f;margin:10px 0 0}\n.create-cta{padding:22px 26px;border:1px solid #ece7d8;background:#fffcf4;border-radius:13px}.create-cta button{margin-top:12px}.create-cta .create-review{background:#fff;color:#ac7c18;border-color:#e6d5a9}.create-cta p{font-size:12px;line-height:1.7;color:#887a5b}\n.create-ready{font-size:12px;font-weight:650;color:#15976c}.create-ready.create-pending{color:#a27a32}.create-status{padding:13px 15px;background:white;border:1px solid #efe6d4;border-radius:9px;line-height:1.5;font-size:12px;overflow-wrap:anywhere}\n.create-proof{padding:15px;border:1px solid #e7e0c9;background:#fff;border-radius:9px;font-size:12px;display:grid;gap:9px}.create-proof code{overflow-wrap:anywhere;color:#85631d}.create-proof a,.create-back{color:#a97d15;font-size:12px;font-weight:630}\n.create-back{display:inline-block;margin:25px 3px}\n@media(max-width:980px){.create-grid{grid-template-columns:1fr}.create-summary{position:static}.create-shell{padding-bottom:35px}}\n@media(max-width:700px){.create-head{padding:8px 0 26px}.create-head h1{font-size:30px}.create-card,.create-summary-card{padding:21px 18px}.create-card-header h2{font-size:18px}.create-cta{padding:19px 17px}.create-total strong{font-size:36px}.mainnav a[data-nav=\"create\"]{display:inline-block!important;font-size:11px!important}}\n\n/* v10: generic on-chain token badges */\n.coin.generic{background:linear-gradient(140deg,#4b5362,#8793a6);color:#fff;font-size:10px}\n/* v9: creator IRM catalog */\n.create-irm-group{margin:18px 0 22px;padding:18px;background:#fffcf6;border:1px solid #efe5cf;border-radius:12px}\n.create-irm-group .create-field input,.create-irm-group .create-field select{background:white}\n.create-limit-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:3px 14px}\n.create-irm-hint{font-size:12px;line-height:1.6;color:#7c8189;margin:9px 0}\n.create-not-yet-ready{font-size:12px;line-height:1.5;padding:12px;color:#9b6721;background:#fff4dc;border:1px solid #f0ddad;border-radius:8px}\n@media(max-width:640px){.create-limit-grid{grid-template-columns:1fr}.create-irm-group{padding:14px 12px}}\n";
const APP = "'use strict';\nconst MARKET_INFO={\n wfrax:{slug:'wfrax',token:'WFRAX',loan:'0xFc00000000000000000000000000000000000002',oracle:'0xe49a63067768d6ecf4b607ef54b4eaf5d22ab7db',id:'0xb1960d24b04dd48407c6409c648833dcb3aa11201d49cffaa8e3addec15827d1',lltv:88,min:30,target:50,max:110,utilTarget:90,rebate:0},\n frxusd:{slug:'frxusd',token:'frxUSD',loan:'0xfc00000000000000000000000000000000000001',oracle:'0x6da1203d4b1edc187345b0cf6ee9b5731d407e34',id:'0x807653235a3872ebae280c1f5d4441d9cdc40b2b2148be8fb1d10922a80c261c',lltv:81,min:20,target:40,max:120,utilTarget:88,rebate:0},\n sfrxusd:{slug:'sfrxusd',token:'sfrxUSD',loan:'0xfc00000000000000000000000000000000000008',oracle:'0xb1383718b657418cd4be4c973e9a68dc79d6a3a2',id:'0xa751be8ab5675783a65f0823d3d4e604d03bac5389ae6d7ac26ba2375b893a7e',lltv:81,min:20,target:40,max:120,utilTarget:88,rebate:4}\n};\nconst CONFIG={morpho:'0xcce2862aed7f2248063c3dcf6906582166c2b6ca',vault:'0x876a56e39e51b4b9734d9798c33bfb186d15d766',irm:'0x1161c47629f30c904547d259fb4bb92e10169651',explorer:'https://fraxscan.com',chain:252};\nconst PATH_PARTS=location.pathname.split('/').filter(Boolean);const PAGE=(PATH_PARTS[0]||'').toLowerCase();const CURRENT_SLUG=PAGE==='market'&&/^0x[0-9a-f]{64}$/i.test(PATH_PARTS[1]||'')?PATH_PARTS[1].toLowerCase():PAGE;\nconst IS_CREATE=PAGE==='create';\n// All new rate models must be independently deployed and enabled on Morpho\n// before they may be selected in a signed market-creation transaction.\nconst IRM_CATALOG={\n legacy:{name:'CurveYield yield-based IRM (existing)',address:CONFIG.irm,deployable:false,available:true},\n bounded:{name:'CurveYield bounded-yield IRM (new)',address:null,deployable:true,available:false},\n morpho:{name:'Morpho AdaptiveCurveIRM (standard)',address:null,deployable:true,available:false},\n euler:{name:'Euler configurable linear-kink IRM (adapter)',address:null,deployable:true,available:false},\n custom:{name:'Custom pre-approved IRM address',address:null,deployable:false,available:true}\n};\nconst SPLITTER_ADDRESS='0xc0890482e5b65b5d8fe9947eb362642435a107f9'; // Live and verified atomic market-creation splitter; Morpho ownership and fee routing active.\nlet current=MARKET_INFO[CURRENT_SLUG]||null;\nconst state={create:{preset:'wfrax',loan:MARKET_INFO.wfrax.loan,collateral:CONFIG.vault,oracle:MARKET_INFO.wfrax.oracle,irm:CONFIG.irm,lltv:'81',extra:'5',receiver:'',status:'',marketId:'',txHash:'',reviewed:false,routingActive:false,irmModel:'legacy',borrowCap:'200',dailyChange:'10',collateralCap:'100',fallbackApr:'12',eulerBase:'2',eulerAtKink:'10',eulerAtFull:'100',eulerKink:'90',eulerCap:'200'},markets:{},networkOk:false,loading:true,error:null,wallet:null,positions:{},histories:{},historyLoading:false,panelMode:'lend',operation:'supply',tab:'market',filter:'',loanFilter:'all',sort:'loans',lastSync:null,clock:null};\nconst $=id=>document.getElementById(id);\nconst escapeHtml=x=>String(x??'').replace(/[&<>\"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;',\"'\":'&#39;'}[c]));\nconst compact=(n,d=2)=>n!=null&&n!==''&&Number.isFinite(Number(n))?new Intl.NumberFormat('en-US',{notation:Math.abs(Number(n))>=1e6?'compact':'standard',maximumFractionDigits:d,minimumFractionDigits:Math.abs(Number(n))<.0001?0:Math.min(2,d)}).format(Number(n)):'—';\nconst percent=(v,d=2)=>v!=null&&v!==''&&Number.isFinite(Number(v))?Number(v).toFixed(d)+'%':'—';\nconst big=(v)=>{try{return BigInt(v??0)}catch{return 0n}};\nconst quantity=v=>{try{let x=big(v);return Number(x)/1e18}catch{return 0}};\nconst short=a=>a?a.slice(0,6)+'…'+a.slice(-4):'Connect Wallet';\nconst clone=market=>{\n const observed=state.markets[market.slug];\n const m={...market,...(observed||{})};\n if(!state.networkOk||!observed||observed.supply==null){for(const k of ['supply','borrow','liquidity','supplyUsd','borrowUsd','liquidityUsd','loanUsdPrice','collateralUsdPrice','oraclePrice','borrowApr','lendApr','vaultApr','vaultPps','utilization','min','target','max','utilTarget','rebate','lltv','curveCollateralApr','maximumBorrowApr'])m[k]=null;}\n return m;\n};\nconst marketOrder=['wfrax','frxusd','sfrxusd'];\nconst pairIcons=(slug,small=false)=>`<span class=\"tokenpair\">${coin('cysdfxs',small)}${coin(slug,small)}</span>`;\nfunction coin(slug,small=false){\n const match=MARKET_INFO[slug]||state.markets[slug];\n const key=(match?.token||slug).toLowerCase();\n const family=['cysdfxs','wfrax','frxusd','sfrxusd'].includes(key)?key:'generic';\n const inner=family==='cysdfxs'?'<img class=\"authentic-sdfxs\" alt=\"sdFXS\" src=\"/assets/sdfxs.svg\">':family==='wfrax'?'<img class=\"frax-token-logo\" alt=\"WFRAX\" src=\"https://docs.frax.com/images/protocol/FRAX.png\">':family==='frxusd'?'<img class=\"frax-token-logo\" alt=\"frxUSD\" src=\"https://docs.frax.com/images/protocol/frxUSD.png\">':family==='sfrxusd'?'<img class=\"frax-token-logo\" alt=\"sfrxUSD\" src=\"https://docs.frax.com/images/protocol/sfrxUSD.png\">':escapeHtml((match?.token||'?').slice(0,2).toUpperCase());\n return `<span class=\"coin ${family} ${small?'smallcoin':''}\">${inner}</span>`;\n}const asset=(slug)=>`<span class=\"asset\">${coin(slug)} ${MARKET_INFO[slug].token}</span>`;\nconst marketUrl=s=>'/'+s;\nfunction notice(message){let el=$('toast');el.textContent=message;el.classList.add('show');clearTimeout(state.clock);state.clock=setTimeout(()=>el.classList.remove('show'),6500)}\nfunction usd(n){return n!=null&&typeof n==='number'&&Number.isFinite(n)?'$'+compact(n,2):'—'}\nfunction metrics(m){return [\n ['Total Market Size',usd(m.supplyUsd),m.supply==null?'—':compact(m.supply,4)+' '+m.token+' supplied'],\n ['Total Liquidity',usd(m.liquidityUsd),m.liquidity==null?'—':compact(m.liquidity,4)+' '+m.token+' available'],\n ['Borrow Rate',percent(m.borrowApr), 'Annualized · on-chain IRM'],\n ['Lend Rate',percent(m.lendApr), 'Estimated · before incentives']\n ]}\nfunction heroStats(){const list=marketOrder.map(k=>clone(MARKET_INFO[k]));const ready=list.every(x=>x.borrowUsd!=null);const loans=ready?list.reduce((a,m)=>a+m.borrowUsd,0):null;\nreturn `<div class=\"overview-summary\"><div class=\"summary-number\"><span>Outstanding Loans</span><strong>${usd(loans)}</strong><span class=\"subvalue\">Converted using live Fraxtal price sources</span></div><div class=\"syncbadge\"><span class=\"statusdot ${state.networkOk?'live':''}\"></span>${state.networkOk?'Live Fraxtal data':'Awaiting Fraxtal data'}</div></div>`}\n\nfunction overview(){const list=marketOrder.map(k=>clone(MARKET_INFO[k]));const q=state.filter.trim().toLowerCase();const filtered=list.filter(m=>(state.loanFilter==='all'||m.slug===state.loanFilter)&&(!q||m.token.toLowerCase().includes(q)||'cysdfxs'.includes(q))); if(state.sort==='rates')filtered.sort((a,b)=>(b.borrowApr??-1)-(a.borrowApr??-1));else if(state.sort==='liquidity')filtered.sort((a,b)=>(b.liquidityUsd??-1)-(a.liquidityUsd??-1));else filtered.sort((a,b)=>(b.borrowUsd??-1)-(a.borrowUsd??-1));\nreturn `<div class=\"container\"><section class=\"over-head\"><h1>Variable Rate Markets</h1><p class=\"sub\">Lend and borrow at variable rates in CurveYield markets, powered by Morpho Blue.</p></section>${heroStats()}<div class=\"content-title\"><h2>All variable rate markets <small>(${list.length})</small></h2><select id=\"sortMarket\" class=\"sort-select\" aria-label=\"Sort markets\"><option value=\"loans\" ${state.sort==='loans'?'selected':''}>Sort by Outstanding Loans</option><option value=\"liquidity\" ${state.sort==='liquidity'?'selected':''}>Sort by Total Liquidity</option><option value=\"rates\" ${state.sort==='rates'?'selected':''}>Sort by Borrow Rate</option></select></div><div class=\"filterbar\"><span class=\"filterbtn\" title=\"Only Fraxtal markets are currently deployed\">Network <span>Fraxtal</span></span><select id=\"loanFilter\" class=\"filterbtn\" aria-label=\"Filter by loan token\"><option value=\"all\">Loan: All</option><option value=\"wfrax\" ${state.loanFilter==='wfrax'?'selected':''}>WFRAX</option><option value=\"frxusd\" ${state.loanFilter==='frxusd'?'selected':''}>frxUSD</option><option value=\"sfrxusd\" ${state.loanFilter==='sfrxusd'?'selected':''}>sfrxUSD</option></select><span class=\"filterbtn\" title=\"All three markets use cysdFXS collateral\">Collateral <span>cysdFXS</span></span><div class=\"searchwrap\"><input id=\"marketSearch\" placeholder=\"Filter markets\" value=\"${escapeHtml(state.filter)}\" aria-label=\"Filter markets\" autocomplete=\"off\"/></div></div><div class=\"tablewrap\"><table aria-label=\"Variable rate markets\"><thead><tr><th>Network</th><th>Loan</th><th>Collateral</th><th>LLTV</th><th>Trusted by</th><th>Outstanding Loans</th><th>Total Liquidity</th><th>Borrow Rate</th><th>Lend Rate</th></tr></thead><tbody>${filtered.map(m=>`<tr tabindex=\"0\" role=\"link\" data-open=\"${m.slug}\" aria-label=\"Open ${m.token} market\"><td data-label=\"Network\"><span class=\"chain-dot\"></span>Fraxtal</td><td data-label=\"Loan\">${asset(m.slug)}</td><td data-label=\"Collateral\"><span class=\"asset\">${coin('cysdfxs')} cysdFXS</span></td><td data-label=\"LLTV\"><span class=\"riskpill\">${percent(m.lltv)}</span></td><td data-label=\"Trusted by\"><span class=\"muted\" title=\"No curated-vault endorsement data reported\">—</span></td><td data-label=\"Outstanding Loans\"><div class=\"strong numeric\">${usd(m.borrowUsd)}</div><div class=\"subvalue\">${m.borrow==null?'—':compact(m.borrow,4)+' '+m.token}</div></td><td data-label=\"Total Liquidity\"><div class=\"strong numeric\">${usd(m.liquidityUsd)}</div><div class=\"subvalue\">${m.liquidity==null?'—':compact(m.liquidity,4)+' '+m.token}</div></td><td data-label=\"Borrow Rate\"><span class=\"strong numeric\">${percent(m.borrowApr)}</span></td><td data-label=\"Lend Rate\"><span class=\"strong numeric\">${percent(m.lendApr)}</span></td></tr>`).join('')||`<tr><td class=\"empty-row\" colspan=\"9\">No matching markets</td></tr>`}</tbody></table></div><section class=\"collateral-spotlight\" aria-label=\"cysdFXS collateral branding\"><img src=\"/assets/cysdfxs-poster.webp\" alt=\"cysdFXS poster with the official sdFXS logo and CurveYield crest\" loading=\"lazy\" width=\"176\" height=\"176\"><div><span class=\"spotlight-eyebrow\">CURVEYIELD COLLATERAL</span><h3>cysdFXS</h3><p>The CurveYield sdFXS vault token secures the WFRAX, frxUSD and sfrxUSD lending markets.</p><a href=\"https://boosthub.curveyield.org/#/locker/sdfxs\" target=\"_blank\" rel=\"noopener\">Explore sdFXS vault ↗</a></div></section><div class=\"overview-footnote\">Rates are live model-derived APR estimates, not forward-looking guarantees. Assets and balances are sourced from the Morpho Blue contracts on Fraxtal. No rewards or liquidity are simulated.</div></div>`}\nfunction metricRow(m){return `<div class=\"metricgrid\">${metrics(m).map(([label,val,desc])=>`<div class=\"bigmetric\"><div class=\"metriclabel\">${label} <span class=\"inline-icon\" title=\"Based on live Morpho Blue storage\">ⓘ</span></div><div class=\"metricvalue numeric\">${val}</div><div class=\"metricdesc\">${desc}</div></div>`).join('')}</div>`}\nfunction marketAttributes(m){return `<section class=\"section-block\"><h2>Market Attributes</h2><div class=\"attrs\"><div><div class=\"attribute\"><span class=\"l\">Collateral</span><span class=\"v\"><span class=\"asset\">${coin('cysdfxs',true)} cysdFXS</span></span></div><div class=\"attribute\"><span class=\"l\">Loan</span><span class=\"v\"><span class=\"asset\">${coin(m.slug,true)} ${m.token}</span></span></div><div class=\"attribute\"><span class=\"l\">Liquidation LLTV</span><span class=\"v\">${percent(m.lltv,0)}</span></div><div class=\"attribute\"><span class=\"l\">Utilization</span><span class=\"v\">${percent(m.utilization)}</span></div><div class=\"attribute\"><span class=\"l\">Target utilization</span><span class=\"v\">${percent(m.utilTarget,0)}</span></div></div><div><div class=\"attribute\"><span class=\"l\">Oracle price</span><span class=\"v\">${m.oraclePrice==null?'—':compact(m.oraclePrice,7)+' '+m.token+' / cysdFXS'}</span></div><div class=\"attribute\"><span class=\"l\">Collateral USD price</span><span class=\"v\">${usd(m.collateralUsdPrice)} / cysdFXS</span></div><div class=\"attribute\"><span class=\"l\">Loan token USD price</span><span class=\"v\">${usd(m.loanUsdPrice)}</span></div><div class=\"attribute\"><span class=\"l\">Oracle adapter</span><span class=\"v\"><a class=\"mini-link monospace\" target=\"_blank\" rel=\"noopener\" href=\"${CONFIG.explorer}/address/${m.oracle}\">${short(m.oracle)} ↗</a></span></div><div class=\"attribute\"><span class=\"l\">Interest rate model</span><span class=\"v\"><a class=\"mini-link monospace\" target=\"_blank\" rel=\"noopener\" href=\"${CONFIG.explorer}/address/${CONFIG.irm}\">${short(CONFIG.irm)} ↗</a></span></div><div class=\"attribute\"><span class=\"l\">Market ID</span><span class=\"v\"><a class=\"mini-link monospace\" href=\"${CONFIG.explorer}/address/${CONFIG.morpho}\" target=\"_blank\" rel=\"noopener\">${short(m.id)} ↗</a></span></div></div></div></section>`}\nfunction rateCurve(m){\n const apr=m.curveCollateralApr,cap=m.maximumBorrowApr;\n if([apr,cap,m.min,m.target,m.max,m.utilTarget,m.rebate].some(v=>v==null)||m.utilTarget<=0||m.utilTarget>=100)\n  return `<div class=\"chartbox\"><div class=\"chartheader\"><strong>Interest rate model</strong></div><div class=\"activity-empty\">— · Current IRM curve unavailable from Fraxtal RPC.</div></div>`;\n const values=[],pts=[];let ymax=5;\n const rateAt=u=>{const pct=u<=m.utilTarget?m.min+(m.target-m.min)*u/m.utilTarget:m.target+(m.max-m.target)*(u-m.utilTarget)/(100-m.utilTarget);return Math.max(0,Math.min(cap,apr*pct/100-m.rebate))};\n for(let u=0;u<=100;u+=5){const v=rateAt(u);values.push(v);ymax=Math.max(ymax,v*1.15)}\n for(let n=0;n<values.length;n++)pts.push(`${36+n*5*6.1},${195-values[n]/ymax*158}`);\n const ty=195-rateAt(m.utilTarget)/ymax*158;\n return `<div class=\"chartbox\"><div class=\"chartheader\"><strong>Interest rate model</strong><span class=\"chartlegend\">Borrow APR vs. market utilization</span></div><svg viewBox=\"0 0 700 239\" role=\"img\" aria-label=\"On-chain configured borrowing-rate curve across utilization\"><rect x=\"0\" y=\"0\" width=\"700\" height=\"239\" fill=\"#fff\"/>${[0,1,2,3,4].map(i=>`<line x1=\"36\" y1=\"${36+i*40}\" x2=\"647\" y2=\"${36+i*40}\" stroke=\"#f0eeec\" stroke-width=\"1\"/><text x=\"0\" y=\"${40+i*40}\" font-size=\"11\" fill=\"#9c9ea1\">${(ymax*(1-i/4)).toFixed(1)}%</text>`).join('')}<line x1=\"36\" y1=\"195\" x2=\"647\" y2=\"195\" stroke=\"#e8e9ea\"/><line x1=\"${36+m.utilTarget*6.1}\" y1=\"28\" x2=\"${36+m.utilTarget*6.1}\" y2=\"195\" stroke=\"#dcb35a\" stroke-dasharray=\"5 6\" opacity=\".8\"/><polyline fill=\"none\" stroke=\"#c38a03\" stroke-width=\"3.5\" stroke-linecap=\"round\" stroke-linejoin=\"round\" points=\"${pts.join(' ')}\"/><circle cx=\"${36+m.utilTarget*6.1}\" cy=\"${ty}\" r=\"5.5\" fill=\"#ca9003\" stroke=\"#fff\" stroke-width=\"2.5\"/>${[0,25,50,75,100].map(i=>`<text x=\"${36+i*6.1}\" y=\"222\" text-anchor=\"middle\" font-size=\"12\" fill=\"#9a9ca0\">${i}%</text>`).join('')}</svg><div class=\"chart-sub\">Calculated from the verified IRM's on-chain curve, cached/fallback collateral APR (${percent(apr)}) and borrow APR cap (${percent(cap)}). Not a historical chart.</div></div>`;\n}\nfunction rateSection(m){return `<section class=\"section-block\"><h2>Rates</h2><div class=\"rate-compare\"><div><span>Borrow Rate</span><strong>${percent(m.borrowApr)}</strong></div><div><span>Estimated Lend Rate</span><strong>${percent(m.lendApr)}</strong></div><div><span>Vault Collateral APR</span><strong>${percent(m.vaultApr)}</strong></div></div></section><section class=\"section-block\">${rateCurve(m)}</section><section class=\"section-block\"><h3>IRM Breakdown</h3><div class=\"attrs\"><div><div class=\"stat-inline\"><span>Minimum collateral-yield share</span><strong>${percent(m.min,0)}</strong></div><div class=\"stat-inline\"><span>Target share</span><strong>${percent(m.target,0)}</strong></div><div class=\"stat-inline\"><span>Maximum share</span><strong>${percent(m.max,0)}</strong></div></div><div><div class=\"stat-inline\"><span>Target utilization</span><strong>${percent(m.utilTarget,0)}</strong></div><div class=\"stat-inline\"><span>Borrow APR adjustment</span><strong>${m.rebate==null?'—':m.rebate===0?'None':'-'+compact(m.rebate)+' percentage points'}</strong></div></div></div></section>`}\nfunction eventList(m,category){\n const h=state.histories[m.slug];\n if(h===undefined)return `<div class=\"activity-empty\">Loading on-chain ${category==='liquidations'?'liquidation':'transaction'} history…</div>`;\n if(h===null)return `<div class=\"activity-empty\">— · Unable to read history from Fraxtal RPC.</div>`;\n const arr=h[category]||[];\n if(!arr.length)return `<div class=\"activity-empty\">${h.complete?(category==='liquidations'?'No liquidations yet.':'No activity yet.'):(category==='liquidations'?'No recent liquidations in the scanned block range.':'No recent activity in the scanned block range.')}</div>`;\n return `<div class=\"event-list\">${arr.map(e=>`<a class=\"event-row\" href=\"${CONFIG.explorer}/tx/${escapeHtml(e.txHash)}\" target=\"_blank\" rel=\"noopener\"><strong>${escapeHtml(e.kind)}</strong><span>${e.amount==null?'—':compact(e.amount,5)+' '+escapeHtml(e.asset)}</span><small>Block ${e.block} ↗</small></a>`).join('')}</div>${!h.complete?'<div class=\"chart-sub\">Recent block range only; older events are not included.</div>':''}`;\n}\nfunction riskSection(m){return `<section class=\"section-block\"><h2>Risk</h2><div class=\"attrs\"><div><div class=\"stat-inline\"><span>Liquidation Loan-To-Value (LLTV)</span><strong>${percent(m.lltv,0)}</strong></div><div class=\"stat-inline\"><span>Current utilization</span><strong>${percent(m.utilization)}</strong></div><div class=\"stat-inline\"><span>Oracle price</span><strong>${m.oraclePrice==null?'—':compact(m.oraclePrice,6)+' '+m.token}</strong></div></div><div><div class=\"stat-inline\"><span>Collateral asset</span><strong>cysdFXS</strong></div><div class=\"stat-inline\"><span>Loan asset</span><strong>${m.token}</strong></div><div class=\"stat-inline\"><span>Rate model</span><strong>Collateral yield based</strong></div></div></div></section><section class=\"section-block\"><h3>Oracle attributes</h3><div class=\"chartbox\"><div class=\"stat-inline\"><span>Oracle adapter</span><strong class=\"monospace\">${short(m.oracle)}</strong></div><div class=\"stat-inline\"><span>Underlying collateral</span><strong>sdFXS</strong></div><div class=\"stat-inline\"><span>Valuation</span><strong>Vault share PPS × OmniRouter TWAP</strong></div><div class=\"stat-inline\"><span>Liquidation price</span><strong>Position-specific · connect wallet</strong></div><p class=\"chart-sub\">Collateral prices and your loan-to-value can change. Liquidation may occur when debt exceeds the configured LLTV against the oracle’s valuation.</p></div></section><section class=\"section-block\"><h3>Liquidations</h3>${eventList(m,'liquidations')}</section>`}\nfunction activitySection(m){return `<section class=\"section-block\"><h2>Activity</h2><div class=\"attrs\"><div class=\"stat-inline\"><span>Total supply</span><strong>${m.supply==null?'—':compact(m.supply,4)+' '+m.token}</strong></div><div class=\"stat-inline\"><span>Outstanding loans</span><strong>${m.borrow==null?'—':compact(m.borrow,4)+' '+m.token}</strong></div><div class=\"stat-inline\"><span>Available liquidity</span><strong>${m.liquidity==null?'—':compact(m.liquidity,4)+' '+m.token}</strong></div><div class=\"stat-inline\"><span>Utilization</span><strong>${percent(m.utilization)}</strong></div></div></section><section class=\"section-block\"><h3>All Transactions</h3>${eventList(m,'activity')}</section>`}\nfunction positionsFor(m){return state.positions[m.slug]||null}\nfunction panel(m){let p=positionsFor(m);let isLend=state.panelMode==='lend',opts=isLend?['supply','withdraw']:['collateral','borrow','repay','release'];let op=opts.includes(state.operation)?state.operation:opts[0];state.operation=op;const token=(op==='collateral'||op==='release')?(m.collateralSymbol||'cysdFXS'):m.token;const slug=(op==='collateral'||op==='release')?(m.factory?'generic':'cysdfxs'):m.slug;let actionName={supply:'Supply',withdraw:'Withdraw',collateral:'Supply collateral',borrow:'Borrow',repay:'Repay',release:'Withdraw collateral'}[op];let balance=p?(op==='supply'||op==='repay'?p.walletLoanBalance:op==='collateral'?p.walletCollateralBalance:op==='withdraw'?p.supplyAssets:op==='release'?p.collateral:p.debtAssets):null;let walletCard=state.wallet&&p?`<div class=\"positionbox\"><div class=\"position-title\">Your position</div><div class=\"position-grid\"><div><span>Supplied</span><strong>${compact(p.supplyAssets,4)} ${m.token}<small class='position-usd'>${usd(p.supplyUsd)}</small></strong></div><div><span>Borrowed</span><strong>${compact(p.debtAssets,4)} ${m.token}<small class='position-usd'>${usd(p.debtUsd)}</small></strong></div><div><span>Collateral</span><strong>${compact(p.collateral,4)} ${escapeHtml(m.collateralSymbol||'cysdFXS')}<small class='position-usd'>${usd(p.collateralUsd)}</small></strong></div><div><span>Position LTV</span><strong>${percent(p.ltv)}</strong></div></div>${p.ltv!=null&&m.lltv!=null?`<div class=\"riskbar\"><span style=\"width:${Math.max(0,Math.min(100,p.ltv/m.lltv*100))}%\"></span></div>`:''}</div>`:'';\nreturn `<aside class=\"action-panel\" aria-label=\"Lend and borrow actions\"><div class=\"action-tabs\"><button data-mode=\"lend\" class=\"${isLend?'selected':''}\">Lend</button><button data-mode=\"borrow\" class=\"${!isLend?'selected':''}\">Borrow</button></div><div class=\"action-content\"><div class=\"operation-pills\">${opts.map(x=>`<button data-op=\"${x}\" class=\"${op===x?'chosen':''}\">${{supply:'Supply',withdraw:'Withdraw',collateral:'Collateral',borrow:'Borrow',repay:'Repay',release:'Withdraw'}[x]}</button>`).join('')}</div><div class=\"inputlabel\"><span>${actionName} amount</span><span>${state.wallet?'Available: '+(balance==null?'—':compact(balance,5))+' '+escapeHtml(token):'Connect wallet for balance'}</span></div><div class=\"amountfield\"><input type=\"number\" inputmode=\"decimal\" id=\"amountInput\" min=\"0\" step=\"any\" placeholder=\"0.00\" aria-label=\"${actionName} amount\"/><div class=\"tokenselect\">${coin(slug)}${escapeHtml(token)}</div></div><div class=\"usdline\"><span>1 ${escapeHtml(token)} ≈ ${usd((op==='collateral'||op==='release')?m.collateralUsdPrice:m.loanUsdPrice)}</span><button class=\"maxlink\" data-max=\"1\">MAX</button></div><button class=\"action-primary\" data-submit=\"${op}\" ${m.factory&&(m.loanDecimals==null||m.collateralDecimals==null)?'disabled title=\"Token decimals unavailable\"':''}>${state.wallet?actionName:'Connect Wallet'}</button>${walletCard}<div class=\"panel-details\"><div class=\"stat-inline\"><span>Borrow APR</span><strong>${percent(m.borrowApr)}</strong></div><div class=\"stat-inline\"><span>Estimated lend APR</span><strong>${percent(m.lendApr)}</strong></div><div class=\"stat-inline\"><span>Market liquidity</span><strong>${m.liquidity==null?'—':compact(m.liquidity,3)+' '+m.token}</strong></div><div class=\"stat-inline\"><span>Liquidation LLTV</span><strong>${percent(m.lltv,0)}</strong></div></div><p class=\"notice\">Non-custodial lending on Morpho Blue. Approval may be required. Wallet transactions and liquidation risk are your responsibility. ${(!m.factory||m.collateral.toLowerCase()===CONFIG.vault.toLowerCase())?\"<a href=\\\"https://boosthub.curveyield.org/#/locker/sdfxs\\\" target=\\\"_blank\\\" rel=\\\"noopener\\\"><u>Get cysdFXS ↗</u></a>\":''}</p></div></aside>`}\nfunction detail(slug){const m=clone(MARKET_INFO[slug]);let sections={market:marketAttributes,rates:rateSection,risk:riskSection,activity:activitySection};return `<div class=\"container market-section\"><div class=\"topcrumb\"><a href=\"/\">Variable Rate Markets</a><span>›</span><span>${m.token} / cysdFXS</span></div><div class=\"market-top\"><div class=\"market-head\"><div class=\"pair-heading\">${pairIcons(m.slug)}<h1>cysdFXS / ${m.token}</h1></div><div class=\"pair-meta\"><span class=\"chain-dot\"></span> Fraxtal <span>·</span><a href=\"${CONFIG.explorer}/address/${CONFIG.morpho}#readContract\" target=\"_blank\" rel=\"noopener\" class=\"mini-link monospace\">${short(m.id)} ↗</a><span>·</span><span class=\"pill\">${percent(m.lltv,0)} LLTV</span></div>${metricRow(m)}<nav class=\"tabbar\" aria-label=\"Market detail tabs\">${['market','rates','risk','activity'].map(x=>`<a href=\"#${x}\" data-tab=\"${x}\" class=\"${state.tab===x?'active':''}\">${{market:'Market',rates:'Rates',risk:'Risk',activity:'Activity'}[x]}</a>`).join('')}</nav><div id=\"tabBody\">${sections[state.tab](m)}</div><div class=\"overview-footnote\">Morpho Blue market · Real Fraxtal contracts · APR estimates derived from current rates; no historical data implied. <a class=\"textgold\" target=\"_blank\" rel=\"noopener\" href=\"https://docs.morpho.org/\">Powered by Morpho ↗</a></div></div>${panel(m)}</div></div>`}\nfunction render(){const page=$('page');if(!page)return;page.innerHTML=IS_CREATE?createMarketPage():current?(current.factory?dynamicDetail(clone(current)):detail(current.slug)):PAGE==='market'?'<div class=\"container\"><section class=\"over-head\"><h1>Market unavailable</h1><p class=\"sub\">Loading the market or waiting for its confirmed factory creation event.</p><a href=\"/\">View all markets</a></section></div>':Object.values(state.markets).some(m=>m.factory)?dynamicOverview():overview();if(state.discoveryError&&!IS_CREATE&&!current){const head=page.querySelector('.over-head');head?.insertAdjacentHTML('afterend','<div class=\"container\"><p class=\"notice\">Factory indexing temporarily unavailable: '+escapeHtml(state.discoveryError)+'</p></div>')}wire();if(IS_CREATE)wireCreator();document.title=IS_CREATE?'Create a Market · CurveYield':current?`${current.collateralSymbol||'cysdFXS'} / ${current.token} · CurveYield Markets`:'CurveYield Markets · Fraxtal lending';}\nfunction wire(){document.querySelectorAll('[data-open]').forEach(row=>{row.addEventListener('click',()=>location.assign(marketUrl(row.dataset.open)));row.addEventListener('keydown',e=>{if(e.key==='Enter')location.assign(marketUrl(row.dataset.open))})});$('marketSearch')?.addEventListener('input',e=>{state.filter=e.target.value;render();const el=$('marketSearch');el?.focus();el?.setSelectionRange(el.value.length,el.value.length)});$('sortMarket')?.addEventListener('change',e=>{state.sort=e.target.value;render()});$('loanFilter')?.addEventListener('change',e=>{state.loanFilter=e.target.value;render()});document.querySelectorAll('[data-tab]').forEach(el=>el.addEventListener('click',e=>{e.preventDefault();state.tab=el.dataset.tab;history.replaceState(null,'','#'+state.tab);render();if(['activity','risk'].includes(state.tab))loadHistory()}));document.querySelectorAll('[data-mode]').forEach(el=>el.addEventListener('click',()=>{state.panelMode=el.dataset.mode;state.operation=state.panelMode==='lend'?'supply':'collateral';render()}));document.querySelectorAll('[data-op]').forEach(el=>el.addEventListener('click',()=>{state.operation=el.dataset.op;render()}));document.querySelector('[data-max]')?.addEventListener('click',()=>{const p=current?positionsFor(clone(current)):null;if(!p||!state.networkOk){notice('Live balance information unavailable');return;}const vals={supply:p.walletLoanBalance,withdraw:p.supplyAssets,borrow:Math.max(0,Math.min((clone(current).liquidity??0),p.collateral*(clone(current).oraclePrice??0)*current.lltv/100-p.debtAssets)),collateral:p.walletCollateralBalance,repay:p.debtAssets,release:Math.max(0,p.collateral-(p.debtAssets>0?p.debtAssets/(clone(current).oraclePrice||1)/(current.lltv/100):0))};const v=vals[state.operation];if(v!=null&&Number.isFinite(v))$('amountInput').value=(Math.max(0,v)*(state.operation==='repay'?1.001:0.999999)).toFixed(12).replace(/0+$/,'').replace(/\\.$/,'')});document.querySelector('[data-submit]')?.addEventListener('click',handleOperation);}\nasync function loadMarkets(){try{const r=await fetch('/api/markets',{cache:'no-store'});if(!r.ok)throw Error('RPC response '+r.status);const d=await r.json();if(!d.markets)throw Error('Invalid market response');state.markets=d.markets;if(PAGE==='market')current=d.markets[CURRENT_SLUG]||null;state.networkOk=!!d.networkOk;state.lastSync=d.block??null;state.error=d.error||null;state.discoveryError=d.discoveryError||null;}catch(e){state.networkOk=false;state.markets={};state.positions={};state.error=String(e.message)}state.loading=false;render();if(state.wallet&&state.networkOk)loadPositions();if(current&&['activity','risk'].includes(state.tab))loadHistory()}\nasync function loadPositions(){if(!state.wallet)return;try{const r=await fetch('/api/positions?wallet='+encodeURIComponent(state.wallet)+(current?'&market='+encodeURIComponent(current.slug):''),{cache:'no-store'});if(!r.ok)throw Error('Position RPC unavailable');const v=await r.json();state.positions=v.positions||{};}catch(e){state.positions={};notice('Position refresh: '+e.message)}render()}\nasync function loadHistory(force=false){\n if(!current||!['activity','risk'].includes(state.tab)||state.historyLoading)return;\n const slug=current.slug;\n if(!force&&Object.prototype.hasOwnProperty.call(state.histories,slug))return;\n state.historyLoading=true;\n try{const r=await fetch('/api/activity/'+encodeURIComponent(slug),{cache:'no-store'});if(!r.ok)throw new Error('History RPC '+r.status);const h=await r.json();if(!Array.isArray(h.activity)||!Array.isArray(h.liquidations))throw new Error('Invalid event history');state.histories[slug]=h;}\n catch(e){state.histories[slug]=null;}\n finally{state.historyLoading=false;render()}\n}\nasync function connectWallet(){if(!window.ethereum){notice('Install a wallet with an EIP-1193 provider, such as MetaMask or Rabby.');return}try{const acc=await window.ethereum.request({method:'eth_requestAccounts'});if(!acc?.[0])return;state.wallet=acc[0];const id=await window.ethereum.request({method:'eth_chainId'});if(parseInt(id,16)!==252){try{await window.ethereum.request({method:'wallet_switchEthereumChain',params:[{chainId:'0xfc'}]})}catch(e){if(e.code===4902)await window.ethereum.request({method:'wallet_addEthereumChain',params:[{chainId:'0xfc',chainName:'Fraxtal',rpcUrls:['https://rpc.frax.com'],nativeCurrency:{name:'FRAX',symbol:'FRAX',decimals:18},blockExplorerUrls:['https://fraxscan.com']}]});else throw e}}$('walletButtonText').textContent=short(state.wallet);render();await loadPositions()}catch(e){notice(e.shortMessage||e.message||'Wallet connection failed')}}\nfunction getEthers(){if(!globalThis.ethers)throw Error('Wallet transaction library failed to load; check network and try again.');return globalThis.ethers}\nasync function handleOperation(){if(!state.wallet){await connectWallet();return}if(!current)return;if(!state.networkOk||!state.markets[current.slug]){notice('Market state unavailable; refresh before transacting.');return;}const m=clone(current),op=state.operation,amount=$('amountInput')?.value?.trim();if(m.factory&&(m.loanDecimals==null||m.collateralDecimals==null)){notice('On-chain token decimals are unavailable; transactions are disabled until metadata can be verified.');return;}if(!amount||!(Number(amount)>0)||!/^\\d+(\\.\\d{1,18})?$/.test(amount)){notice('Enter a positive token amount with at most 18 decimal places.');return}try{const E=getEthers();const pr=E.providers?.Web3Provider?new E.providers.Web3Provider(window.ethereum,'any'):new E.BrowserProvider(window.ethereum);const signer=await pr.getSigner();const user=state.wallet;const decimals=(op==='collateral'||op==='release')?(m.collateralDecimals??18):(m.loanDecimals??18);const qty=(E.utils?.parseUnits??E.parseUnits)(amount,decimals);const marketParams=[m.loan,m.collateral||CONFIG.vault,m.oracle,m.irm||CONFIG.irm,m.lltvRaw||String(BigInt(Math.round(m.lltv*100))*10n**14n)];const M=new E.Contract(CONFIG.morpho,['function supply((address,address,address,address,uint256),uint256,uint256,address,bytes)','function withdraw((address,address,address,address,uint256),uint256,uint256,address,address)','function borrow((address,address,address,address,uint256),uint256,uint256,address,address)','function repay((address,address,address,address,uint256),uint256,uint256,address,bytes)','function supplyCollateral((address,address,address,address,uint256),uint256,address,bytes)','function withdrawCollateral((address,address,address,address,uint256),uint256,address,address)'],signer);let token=(op==='collateral'||op==='release')?(m.collateral||CONFIG.vault):m.loan;if(['supply','repay','collateral'].includes(op)){const T=new E.Contract(token,['function allowance(address,address) view returns(uint256)','function approve(address,uint256) returns(bool)'],signer);const allowance=await T.allowance(user,CONFIG.morpho);if(BigInt(allowance.toString())<BigInt(qty.toString())){notice('Confirm token approval in your wallet…');const a=await T.approve(CONFIG.morpho,qty);await a.wait()}}\nconst calls={supply:()=>M.supply(marketParams,qty,0,user,'0x'),withdraw:()=>M.withdraw(marketParams,qty,0,user,user),borrow:()=>M.borrow(marketParams,qty,0,user,user),repay:()=>M.repay(marketParams,qty,0,user,'0x'),collateral:()=>M.supplyCollateral(marketParams,qty,user,'0x'),release:()=>M.withdrawCollateral(marketParams,qty,user,user)};notice('Confirm '+op+' in your wallet…');const tx=await calls[op]();notice('Transaction submitted: '+short(tx.hash));await tx.wait();notice('Transaction confirmed on Fraxtal. Refreshing balances.');await loadMarkets();await loadPositions()}catch(e){notice(e.reason||e.shortMessage||e.data?.message||e.message||'Transaction failed')}}\n$('walletButton')?.addEventListener('click',connectWallet);\nif(window.ethereum?.on){window.ethereum.on('accountsChanged',accounts=>{state.wallet=accounts?.[0]||null;$('walletButtonText').textContent=state.wallet?short(state.wallet):'Connect Wallet';state.positions={};render();if(state.wallet)loadPositions()});window.ethereum.on('chainChanged',()=>{state.positions={};render();if(state.wallet)loadPositions()})}\nif(current&&['market','rates','risk','activity'].includes(location.hash.slice(1)))state.tab=location.hash.slice(1);\nrender();loadMarkets();setInterval(()=>{if(document.visibilityState==='visible'){loadMarkets();if(current&&['activity','risk'].includes(state.tab))loadHistory(true)}},30000);\n\n// MARKET_CREATOR_V7 — unchanged Morpho core, optional external fee splitter.\nconst CREATOR_PRESETS={\n wfrax:{loan:MARKET_INFO.wfrax.loan,oracle:MARKET_INFO.wfrax.oracle,lltv:'81'},\n frxusd:{loan:MARKET_INFO.frxusd.loan,oracle:MARKET_INFO.frxusd.oracle,lltv:'88'},\n sfrxusd:{loan:MARKET_INFO.sfrxusd.loan,oracle:MARKET_INFO.sfrxusd.oracle,lltv:'88'}\n};\nconst creatorAddress=a=>/^0x[0-9a-fA-F]{40}$/.test(a||'');\nfunction creatorFeeSummary(){\n const x=Number(state.create.extra);\n if(!Number.isFinite(x)||x<0||x>22)return null;\n return {creator:x,curveyield:0.8+0.1*x,total:0.8+1.1*x};\n}\nfunction creatorIrmConfig(c,esc,row){\n const option=IRM_CATALOG[c.irmModel]||IRM_CATALOG.legacy;\n const options=Object.entries(IRM_CATALOG).map(([id,item])=>`<option value=\"${id}\" ${c.irmModel===id?'selected':''}>${item.name}${item.available?'':' · needs deployment and approval'}</option>`).join('');\n let config='';\n if(c.irmModel==='bounded')config=`<div class=\"create-limit-grid\">\n ${row('Maximum borrow APR · %',c.borrowCap,'create-borrow-cap','Maximum hard-coded ceiling 500% APR; limit is immutable per IRM deployment.')}\n ${row('Maximum change per 24h · APR percentage points',c.dailyChange,'create-daily-change','Maximum hard-coded ceiling 50 points; rate change is bounded by elapsed time.')}\n ${row('Collateral yield APR cap · %',c.collateralCap,'create-collateral-cap','Maximum hard-coded ceiling 500%.')}\n ${row('Fallback collateral APR · %',c.fallbackApr,'create-fallback-apr','Used when the vault APR feed is unavailable.')}\n </div><p class=\"create-irm-hint\">Settings are constructor parameters for a NEW IRM instance, not mutable settings on the existing IRM. No new IRM is deployed from this page yet.</p>`;\n if(c.irmModel==='euler')config=`<div class=\"create-limit-grid\">\n ${row('Euler base APR · %',c.eulerBase,'create-euler-base','Interest rate at 0% utilization.')}\n ${row('Euler kink APR · %',c.eulerAtKink,'create-euler-kink-rate','Interest rate at target utilization.')}\n ${row('Euler full-utilization APR · %',c.eulerAtFull,'create-euler-full','Interest rate at 100% utilization.')}\n ${row('Euler target utilization · %',c.eulerKink,'create-euler-kink','Kink between 0% and 100% utilization.')}\n ${row('Adapter borrow APR cap · %',c.eulerCap,'create-euler-cap','Immutable at deployment, never above the 500% absolute cap.')}\n </div><p class=\"create-irm-hint\">Euler's EVK IRM uses 27-decimal SPY; the Morpho adapter converts that to 18-decimal per-second rates. Only the stateless linear-kink model is supported.</p>`;\n if(c.irmModel==='morpho')config='<p class=\"create-irm-hint\">Use the original Morpho AdaptiveCurveIRM implementation, deployed for this Morpho Blue instance. Morpho governance must enable the specific IRM address before market creation.</p>';\n if(c.irmModel==='legacy')config='<p class=\"create-irm-hint\">Existing deployed yield-based IRM. It supports only the cysdFXS vault and requires the administrator to configure a curve for each new market ID before market creation. Existing lending markets are unaffected.</p>';\n return `<div class=\"create-irm-group\"><label class=\"create-field\"><span>Interest rate model</span><select id=\"create-irm-model\">${options}</select><small>Contracts must be deployed and enabled on Morpho. Changing models changes the resulting market ID.</small></label>\n ${row('Selected IRM contract address',c.irm,'create-irm','Only use a deployed, Morpho-enabled IRM matching this market.')} ${config}\n ${option.available?'':`<p class=\"create-not-yet-ready\">Not yet deployable via this form. Requires owner approval of the compiled IRM before selecting or creating a market.</p>`}</div>`;\n}\nfunction createMarketPage(){\n const c=state.create,fees=creatorFeeSummary(),working=!!SPLITTER_ADDRESS,ready=working&&c.routingActive&&c.reviewed;\n const esc=v=>escapeHtml(v??'');\n const row=(label,value,id,hint='')=>`<label class=\"create-field\"><span>${label}</span><input id=\"${id}\" value=\"${esc(value)}\" autocomplete=\"off\" spellcheck=\"false\"/><small>${hint}</small></label>`;\n return `<div class=\"container create-shell\"><div class=\"topcrumb\"><a href=\"/\">Markets</a><span>›</span><span>Create a market</span></div>\n <div class=\"create-head\"><span class=\"create-eyebrow\">PERMISSIONLESS MARKETS · FRAXTAL</span><h1>Create a lending market</h1><p>Deploy a new market in the existing, unmodified Morpho Blue lending core. Choose the assets, oracle, interest rate model and your share of borrowing-interest fees.</p></div>\n <div class=\"create-grid\"><section class=\"create-form\">\n <div class=\"create-card\"><div class=\"create-card-header\"><div><span>01 · Market configuration</span><h2>Select your assets</h2></div><span class=\"create-chain\">● Fraxtal</span></div>\n <label class=\"create-field\"><span>Starting configuration</span><select id=\"create-preset\">\n <option value=\"wfrax\" ${c.preset==='wfrax'?'selected':''}>WFRAX loan · cysdFXS collateral</option>\n <option value=\"frxusd\" ${c.preset==='frxusd'?'selected':''}>frxUSD loan · cysdFXS collateral</option>\n <option value=\"sfrxusd\" ${c.preset==='sfrxusd'?'selected':''}>sfrxUSD loan · cysdFXS collateral</option>\n <option value=\"custom\" ${c.preset==='custom'?'selected':''}>Custom ERC-20 pair</option></select><small>Presets are examples; existing identical market parameters cannot be recreated.</small></label>\n ${row('Loan token address',c.loan,'create-loan','ERC-20 supplied by lenders and borrowed by borrowers.')}\n ${row('Collateral token address',c.collateral,'create-collateral','ERC-20 deposited as borrowing collateral.')}\n ${row('Oracle address',c.oracle,'create-oracle','Must return the correctly scaled Morpho price for this exact pair.')}\n ${creatorIrmConfig(c,esc,row)}\n ${row('Liquidation loan-to-value · %',c.lltv,'create-lltv','Requires an already-enabled LLTV on the core.')}\n </div>\n <div class=\"create-card\"><div class=\"create-card-header\"><div><span>02 · Creator earnings</span><h2>Configure your fee</h2></div></div>\n <label class=\"create-field\"><span>Creator fee · 0–22%</span><div class=\"create-fee-input\"><input id=\"create-fee\" inputmode=\"decimal\" type=\"number\" min=\"0\" max=\"22\" step=\"0.01\" value=\"${esc(c.extra)}\"><strong>%</strong></div><small>This percentage is yours, taken from accrued borrowing interest.</small></label>\n ${row('Fee receiving wallet',c.receiver||state.wallet||'','create-receiver','The original creator or current receiver can update this address later.')}\n </div>\n <div class=\"create-cta\"><div class=\"create-ready ${working?'':'create-pending'}\">${working?(c.routingActive?'Splitter deployed · Fee routing verified':'Splitter deployed · routing not active'):'Splitter deployment pending'} · Original Morpho core unchanged</div>\n <button class=\"action-primary create-review\" id=\"create-review\" type=\"button\">Review on-chain compatibility</button>\n <button class=\"action-primary\" id=\"create-submit\" type=\"button\" ${!ready?'disabled':''}>${!working?'Creation unavailable until splitter deployment':!c.routingActive?'Fee routing configuration unavailable':!c.reviewed?'Review compatibility first':state.wallet?'Create market on Fraxtal':'Connect wallet to create'}</button>\n <p>One transaction creates the Morpho market, sets its actual fee, and activates fee sharing automatically. No separate Safe approval or activation is needed for each new market.</p>\n ${c.status?`<div class=\"create-status\">${esc(c.status)}</div>`:''}\n ${c.marketId?`<div class=\"create-proof\"><strong>Market ID</strong><code>${esc(c.marketId)}</code>${c.txHash?`<a href=\"https://fraxscan.com/tx/${esc(c.txHash)}\" target=\"_blank\" rel=\"noopener\">View confirmed transaction ↗</a><a href=\"/market/${esc(c.marketId)}\">Open newly created market ↗</a>`:''}</div>`:''}\n </div></section>\n <aside class=\"create-summary\"><div class=\"create-summary-card\"><span class=\"create-eyebrow\">FEE BREAKDOWN</span><h2>How borrowing fees are shared</h2>\n <div class=\"create-total\"><span>Total Morpho market fee</span><strong id=\"preview-total\">${fees?fees.total.toFixed(2)+'%':'—'}</strong></div>\n <div class=\"create-split-bar\" aria-hidden=\"true\"><span id=\"preview-protocol-width\" style=\"width:${fees?100*fees.curveyield/fees.total:100}%\"></span></div>\n <div class=\"create-summary-row\"><span><i class=\"create-dot gold\"></i> CurveYield</span><b id=\"preview-protocol\">${fees?fees.curveyield.toFixed(2)+'%':'—'}</b></div>\n <div class=\"create-summary-row\"><span><i class=\"create-dot grey\"></i> Market creator</span><b id=\"preview-creator\">${fees?fees.creator.toFixed(2)+'%':'—'}</b></div>\n <div class=\"create-calculation\"><strong>Protocol fee policy</strong><p>CurveYield receives 0.8 percentage points plus 10% of the creator's fee. Total market fee = 0.8% + 1.1 × creator fee; creator maximum = 22%, total maximum = 25%.</p></div>\n <div class=\"create-calculation\"><strong>Unchanged Morpho contract</strong><p>Morpho mints fee supply shares to one global recipient. The independent splitter keeps track of each market's creator and allocates shares to both beneficiaries. Withdrawals from the splitter may wait for available market liquidity.</p></div>\n <div class=\"create-calculation\"><strong>Fee routing active</strong><p>The Safe has transferred Morpho ownership to CurveYield governance and enabled the atomic splitter. Every new market automatically receives the selected on-chain fee and creator revenue allocation in the same transaction.</p></div>\n </div><a class=\"create-back\" href=\"/\">← Return to all markets</a></aside></div></div>`;\n}\nfunction creatorPayload(){\n const c=state.create, E=getEthers();\n if(IRM_CATALOG[c.irmModel]?.deployable && !IRM_CATALOG[c.irmModel].available)\n  throw Error('The selected IRM has not been deployed and enabled on Morpho. Configure the IRM deployment first.');\n const addresses=[c.loan,c.collateral,c.oracle,c.irm,c.receiver||state.wallet];\n if(addresses.some(a=>!creatorAddress(a)))throw Error('Every token, oracle, IRM and fee-recipient address must be a valid Ethereum address.');\n if(c.loan.toLowerCase()===c.collateral.toLowerCase())throw Error('Loan and collateral must be different tokens.');\n if(c.irmModel==='legacy'&&c.collateral.toLowerCase()!==CONFIG.vault.toLowerCase())throw Error('The existing yield IRM accepts only cysdFXS collateral.');\n if(!/^\\d{1,2}(\\.\\d{1,2})?$/.test(c.extra)||Number(c.extra)>22)throw Error('Creator fee must be 0–22%, with at most two decimal places.');\n if(!/^\\d{1,2}(\\.\\d{1,2})?$/.test(c.lltv)||Number(c.lltv)<=0||Number(c.lltv)>=100)throw Error('LLTV must be greater than 0 and less than 100.');\n const parse=(v,dec)=>(E.utils?.parseUnits??E.parseUnits)(String(v),dec).toString();\n const lltv=parse(c.lltv,16), creatorFee=parse(c.extra,16);\n const params=[c.loan,c.collateral,c.oracle,c.irm,lltv];\n const coder=E.utils?.defaultAbiCoder??E.AbiCoder.defaultAbiCoder();\n const encoded=coder.encode(['tuple(address,address,address,address,uint256)'],[params]);\n const id=(E.utils?.keccak256??E.keccak256)(encoded);\n return {params,id,creatorFee,receiver:c.receiver||state.wallet};\n}\nasync function creatorProvider(){\n if(!window.ethereum)throw Error('Connect an Ethereum wallet to inspect permissions on Fraxtal.');\n const E=getEthers(), provider=E.providers?.Web3Provider?new E.providers.Web3Provider(window.ethereum,'any'):new E.BrowserProvider(window.ethereum);\n const chain=await provider.getNetwork();if(Number(chain.chainId)!==252)throw Error('Switch wallet to Fraxtal network (chain 252).');\n return {E,provider};\n}\nasync function reviewCreator(){\n let c=state.create;c.status='Checking live Morpho parameters…';render();\n try{\n const {E,provider}=await creatorProvider(),p=creatorPayload();\n const M=new E.Contract(CONFIG.morpho,[\n 'function isIrmEnabled(address) view returns(bool)',\n 'function isLltvEnabled(uint256) view returns(bool)',\n 'function market(bytes32) view returns(uint128,uint128,uint128,uint128,uint128,uint128)',\n 'function owner() view returns(address)',\n 'function feeRecipient() view returns(address)'\n ],provider);\n const [irmEnabled,lltvEnabled,m,owner,feeRecipient]=await Promise.all([\n M.isIrmEnabled(p.params[3]),M.isLltvEnabled(p.params[4]),M.market(p.id),M.owner(),M.feeRecipient()\n ]);\n const exists=BigInt(m[4].toString())>0n;\n const legacyConfigured=c.irmModel!=='legacy'||(await new E.Contract(CONFIG.irm,['function configured(bytes32) view returns(bool)'],provider).configured(p.id));\n c.routingActive=!!SPLITTER_ADDRESS&&feeRecipient.toLowerCase()===SPLITTER_ADDRESS.toLowerCase();\n c.marketId=p.id;c.reviewed=!exists&&irmEnabled&&lltvEnabled&&legacyConfigured&&c.routingActive;\n let stateText=exists?'That exact market already exists. Change oracle, IRM or LLTV.':\n !irmEnabled?'IRM not enabled by Morpho owner.':\n !lltvEnabled?'LLTV not enabled by Morpho owner.':\n !legacyConfigured?'This new market has no yield IRM curve configured. The IRM owner must configure the market ID first.':\n 'Market parameters are available for creation.';\n c.status=stateText+' Owner: '+short(owner)+'. '+\n (SPLITTER_ADDRESS&&feeRecipient.toLowerCase()===SPLITTER_ADDRESS.toLowerCase()\n ?'Splitter is the active fee recipient.':'Fee routing not yet switched to splitter.');\n }catch(e){c.reviewed=false;c.routingActive=false;c.status=e.shortMessage||e.message||String(e);}\n render();\n}\nasync function submitCreator(){\n if(!SPLITTER_ADDRESS||!state.create.reviewed||!state.create.routingActive){notice('Review and confirm active Morpho fee routing before creation.');return}\n if(!state.wallet){await connectWallet();return}\n try{\n const data=creatorPayload();\n const {E,provider}=await creatorProvider();\n const signer=await provider.getSigner();\n const currentRecipient=await new E.Contract(CONFIG.morpho,['function feeRecipient() view returns(address)'],provider).feeRecipient();\n if(currentRecipient.toLowerCase()!==SPLITTER_ADDRESS.toLowerCase())throw Error('Morpho fee routing changed; Safe must authorize the splitter before creation.');\n const S=new E.Contract(SPLITTER_ADDRESS,[\n 'function createMarket((address,address,address,address,uint256),address,uint256) returns(bytes32)'\n ],signer);\n state.create.status='Confirm market creation in your wallet…';render();\n const transaction=await S.createMarket(data.params,data.receiver,data.creatorFee);\n state.create.txHash=transaction.hash;state.create.status='Transaction submitted. Awaiting receipt…';render();\n await transaction.wait();\n await loadMarkets();\n state.create.marketId=data.id;state.create.status='Market created on Fraxtal. The selected Morpho market fee and creator fee sharing were activated in the same transaction.';\n notice('Market created with its fee and revenue allocation active.');\n render();\n }catch(e){state.create.status=e.reason||e.shortMessage||e.message||'Market creation failed';render();}\n}\nfunction creatorRefreshPreview(){\n const f=creatorFeeSummary();\n if(!f){for(const id of ['preview-total','preview-protocol','preview-creator'])$(id).textContent='—';return}\n $('preview-total').textContent=f.total.toFixed(2)+'%';\n $('preview-protocol').textContent=f.curveyield.toFixed(2)+'%';\n $('preview-creator').textContent=f.creator.toFixed(2)+'%';\n $('preview-protocol-width').style.width=(100*f.curveyield/f.total)+'%';\n}\nfunction wireCreator(){\n const fields={'create-loan':'loan','create-collateral':'collateral','create-oracle':'oracle','create-irm':'irm','create-lltv':'lltv','create-fee':'extra','create-receiver':'receiver','create-borrow-cap':'borrowCap','create-daily-change':'dailyChange','create-collateral-cap':'collateralCap','create-fallback-apr':'fallbackApr','create-euler-base':'eulerBase','create-euler-kink-rate':'eulerAtKink','create-euler-full':'eulerAtFull','create-euler-kink':'eulerKink','create-euler-cap':'eulerCap'};\n for(const [id,key] of Object.entries(fields))$(id)?.addEventListener('input',e=>{\n  state.create[key]=e.target.value;state.create.reviewed=false;\n  if(key==='extra')creatorRefreshPreview();\n });\n $('create-irm-model')?.addEventListener('change',e=>{\n  const key=e.target.value;if(!IRM_CATALOG[key])return;\n  state.create.irmModel=key;\n  state.create.irm=IRM_CATALOG[key].address||'';\n  state.create.status='';state.create.reviewed=false;\n  state.create.marketId='';render();\n });\n $('create-preset')?.addEventListener('change',e=>{\n  state.create.preset=e.target.value;\n  if(CREATOR_PRESETS[e.target.value]){\n   const v=CREATOR_PRESETS[e.target.value];\n   state.create.loan=v.loan;state.create.collateral=CONFIG.vault;state.create.oracle=v.oracle;state.create.lltv=v.lltv;\n  }\n  state.create.status='';state.create.reviewed=false;render();\n });\n $('create-review')?.addEventListener('click',reviewCreator);\n $('create-submit')?.addEventListener('click',submitCreator);\n}\n\n\nfunction dynamicOverview(){\n const listed=[...marketOrder.map(k=>clone(MARKET_INFO[k])),...Object.values(state.markets).filter(m=>m.factory).map(m=>clone(m))];\n const q=state.filter.trim().toLowerCase();\n let filtered=listed.filter(m=>(state.loanFilter==='all'||m.slug===state.loanFilter)&&(!q||[m.token,m.collateralSymbol,m.id].some(x=>String(x||'').toLowerCase().includes(q))));\n const metric=state.sort==='rates'?'borrowApr':state.sort==='liquidity'?'liquidityUsd':'borrowUsd';\n filtered.sort((a,b)=>(b[metric]??-1)-(a[metric]??-1));\n const totals=listed.every(m=>m.borrowUsd!=null)?listed.reduce((n,m)=>n+m.borrowUsd,0):null;\n const rows=filtered.map(m=>{\n  const collateral=m.collateralSymbol||'cysdFXS',ctoken=m.collateral||CONFIG.vault;\n  const icon=ctoken.toLowerCase()===CONFIG.vault.toLowerCase()?coin('cysdfxs'):`<span class=\"coin generic\">${escapeHtml(collateral.slice(0,2).toUpperCase())}</span>`;\n  return `<tr tabindex=\"0\" role=\"link\" data-open=\"${m.factory?'market/'+m.id:m.slug}\"><td data-label=\"Network\"><span class=\"chain-dot\"></span>Fraxtal</td><td data-label=\"Loan\"><span class=\"asset\">${coin(m.slug)} ${escapeHtml(m.token)}</span></td><td data-label=\"Collateral\"><span class=\"asset\">${icon} ${escapeHtml(collateral)}</span></td><td data-label=\"LLTV\"><span class=\"riskpill\">${percent(m.lltv)}</span></td><td data-label=\"Trusted by\">—</td><td data-label=\"Outstanding Loans\">${usd(m.borrowUsd)}<div class=\"subvalue\">${m.borrow==null?'—':compact(m.borrow,4)+' '+escapeHtml(m.token)}</div></td><td data-label=\"Total Liquidity\">${usd(m.liquidityUsd)}<div class=\"subvalue\">${m.liquidity==null?'—':compact(m.liquidity,4)+' '+escapeHtml(m.token)}</div></td><td data-label=\"Borrow Rate\">${percent(m.borrowApr)}</td><td data-label=\"Lend Rate\">${percent(m.lendApr)}</td></tr>`;\n }).join('');\n return `<div class=\"container\"><section class=\"over-head\"><h1>Variable Rate Markets</h1><p class=\"sub\">Lend and borrow on Morpho Blue. Factory-created markets are indexed directly from Fraxtal events.</p></section><div class=\"overview-summary\"><div class=\"summary-number\"><span>Outstanding Loans</span><strong>${usd(totals)}</strong><span class=\"subvalue\">USD total available only when every asset price is known</span></div><div class=\"syncbadge\"><span class=\"statusdot ${state.networkOk?'live':''}\"></span>${state.networkOk?'Live Fraxtal data':'Awaiting Fraxtal data'}</div></div><div class=\"content-title\"><h2>All variable rate markets <small>(${listed.length})</small></h2><select id=\"sortMarket\" class=\"sort-select\"><option value=\"loans\" ${state.sort==='loans'?'selected':''}>Sort by Outstanding Loans</option><option value=\"liquidity\" ${state.sort==='liquidity'?'selected':''}>Sort by Total Liquidity</option><option value=\"rates\" ${state.sort==='rates'?'selected':''}>Sort by Borrow Rate</option></select></div><div class=\"filterbar\"><span class=\"filterbtn\">Network <span>Fraxtal</span></span><select id=\"loanFilter\" class=\"filterbtn\" aria-label=\"Filter by loan token\"><option value=\"all\">Loan: All</option>${marketOrder.map(k=>`<option value=\"${k}\" ${state.loanFilter===k?'selected':''}>${MARKET_INFO[k].token}</option>`).join('')}</select><span class=\"filterbtn\">Factory <span>${listed.length-3} discovered</span></span><div class=\"searchwrap\"><input id=\"marketSearch\" placeholder=\"Search tokens or market IDs\" value=\"${escapeHtml(state.filter)}\" autocomplete=\"off\"></div></div><div class=\"tablewrap\"><table aria-label=\"Variable rate markets\"><thead><tr><th>Network</th><th>Loan</th><th>Collateral</th><th>LLTV</th><th>Trusted by</th><th>Outstanding Loans</th><th>Total Liquidity</th><th>Borrow Rate</th><th>Lend Rate</th></tr></thead><tbody>${rows||'<tr><td colspan=\"9\" class=\"empty-row\">No matching markets</td></tr>'}</tbody></table></div><div class=\"overview-footnote\">Factory listings require a verified creation event and corresponding Morpho market parameters. Unknown USD prices remain unavailable.</div></div>`;\n}\n\nfunction dynamicDetail(m){\n const loan=escapeHtml(m.token),coll=escapeHtml(m.collateralSymbol);\n const link=a=>`<a href=\"${CONFIG.explorer}/address/${escapeHtml(a)}\" target=\"_blank\" rel=\"noopener\" class=\"mini-link monospace\">${short(a)} ↗</a>`;\n const icon=m.collateral.toLowerCase()===CONFIG.vault.toLowerCase()?coin('cysdfxs'):`<span class=\"coin generic\">${escapeHtml(m.collateralSymbol.slice(0,2).toUpperCase())}</span>`;\n const sections={\n market:()=>`<section class=\"section-block\"><h2>Market Attributes</h2><div class=\"attrs\"><div><div class=\"attribute\"><span class=\"l\">Loan</span><span class=\"v\">${coin(m.slug)} ${loan}</span></div><div class=\"attribute\"><span class=\"l\">Collateral</span><span class=\"v\">${icon} ${coll}</span></div><div class=\"attribute\"><span class=\"l\">LLTV</span><span class=\"v\">${percent(m.lltv)}</span></div><div class=\"attribute\"><span class=\"l\">Utilization</span><span class=\"v\">${percent(m.utilization)}</span></div><div class=\"attribute\"><span class=\"l\">Decimals</span><span class=\"v\">${m.loanDecimals} loan / ${m.collateralDecimals} collateral</span></div></div><div><div class=\"attribute\"><span class=\"l\">Loan token</span><span class=\"v\">${link(m.loan)}</span></div><div class=\"attribute\"><span class=\"l\">Collateral token</span><span class=\"v\">${link(m.collateral)}</span></div><div class=\"attribute\"><span class=\"l\">Oracle</span><span class=\"v\">${link(m.oracle)}</span></div><div class=\"attribute\"><span class=\"l\">IRM</span><span class=\"v\">${link(m.irm)}</span></div><div class=\"attribute\"><span class=\"l\">Creator factory</span><span class=\"v\">${link(m.factory)}</span></div><div class=\"attribute\"><span class=\"l\">Market ID</span><span class=\"v monospace\">${m.id}</span></div></div></div></section>`,\n rates:()=>`<section class=\"section-block\"><h2>Rates</h2><div class=\"rate-compare\"><div><span>Borrow APR</span><strong>${percent(m.borrowApr)}</strong></div><div><span>Lend APR</span><strong>${percent(m.lendApr)}</strong></div></div><p class=\"chart-sub\">Read from the configured on-chain interest-rate model. No fixed yield-based rate curve is assumed.</p></section>`,\n risk:()=>`<section class=\"section-block\"><h2>Risk</h2><div class=\"stat-inline\"><span>Liquidation LLTV</span><strong>${percent(m.lltv)}</strong></div><div class=\"stat-inline\"><span>Current utilization</span><strong>${percent(m.utilization)}</strong></div><div class=\"stat-inline\"><span>Oracle price (${loan} / ${coll})</span><strong>${m.oraclePrice==null?'—':compact(m.oraclePrice,8)}</strong></div><p class=\"chart-sub\">This market has its own collateral and oracle risk. No valuation is invented for tokens lacking a verified price feed.</p></section><section class=\"section-block\"><h3>Liquidations</h3>${eventList(m,'liquidations')}</section>`,\n activity:()=>activitySection(m)\n };\n return `<div class=\"container market-section\"><div class=\"topcrumb\"><a href=\"/\">Variable Rate Markets</a><span>›</span><span>${coll} / ${loan}</span></div><div class=\"market-top\"><div class=\"market-head\"><div class=\"pair-heading\">${icon}${coin(m.slug)}<h1>${coll} / ${loan}</h1></div><div class=\"pair-meta\"><span class=\"chain-dot\"></span> Fraxtal <span>·</span><span class=\"pill\">${percent(m.lltv)} LLTV</span><span>·</span> Factory-created</div>${metricRow(m)}<nav class=\"tabbar\" aria-label=\"Market detail tabs\">${['market','rates','risk','activity'].map(k=>`<a href=\"#${k}\" data-tab=\"${k}\" class=\"${state.tab===k?'active':''}\">${{market:'Market',rates:'Rates',risk:'Risk',activity:'Activity'}[k]}</a>`).join('')}</nav><div id=\"tabBody\">${sections[state.tab]?.()||sections.market()}</div><div class=\"overview-footnote\">Market ID: <span class=\"monospace\">${m.id}</span>. Values are read on Fraxtal.</div></div>${panel(m)}</div></div>`;\n}";
const FAVICON = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 64 64\"><rect width=\"64\" height=\"64\" rx=\"16\" fill=\"#fffaf0\"/><path d=\"M32 5 56 18v28L32 59 8 46V18L32 5Z\" fill=\"none\" stroke=\"#c58b00\" stroke-width=\"4\"/><path d=\"M45 23a18 18 0 1 0 0 18\" fill=\"none\" stroke=\"#bd8100\" stroke-width=\"6\" stroke-linecap=\"round\"/><path d=\"M33 32h16l-6 10\" fill=\"none\" stroke=\"#bd8100\" stroke-width=\"5\" stroke-linejoin=\"round\"/></svg>\n";
const CY_LOGO_B64 = "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";
const CYSD_POSTER_B64 = "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";
const SDFXS_AUTHENTIC = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"600\" height=\"600\" viewBox=\"0 0 600 600\" fill=\"none\">\n    <path d=\"M300 600C465.685 600 600 465.685 600 300C600 134.315 465.685 0 300 0C134.315 0 0 134.315 0 300C0 465.685 134.315 600 300 600Z\" fill=\"url(#paint0_radial_440_36)\"/>\n    <g transform=\"matrix(1.67788933755,0,0,1.67788933755,60,62)\">\n        <path d=\"M196.24,174.3c0-12.41-5.16-22.6-15.33-30.31c-7.52-5.7-18.03-10.37-35.08-15.61l0,0   c-30.69-9.43-30.69-14.86-30.69-19.23c0-6.04,8.94-14.41,25.71-14.41c9.93,0,26.59,2.5,26.59,19.26h27.92   c0-7.9-1.77-15.27-5.12-21.7l22.4-22.4l-19.74-19.74L170.07,73c-8.28-4.06-18.19-6.17-29.21-6.17c-10.27,0-19.71,1.98-27.85,5.79   L90.56,50.17L70.82,69.91l21.3,21.3c-3.18,5.56-4.89,11.7-4.89,17.95c0,12.41,5.16,22.6,15.33,30.31c7.52,5.7,18,10.36,35.05,15.6   l0,0c30.69,9.42,30.71,14.87,30.71,19.24c0,6.04-8.94,14.41-25.71,14.41c-9.93,0-26.59-2.5-26.59-19.26H88.1   c0,7.93,1.78,15.32,5.15,21.77l-22.44,22.44l19.74,19.74l22.91-22.91c8.27,4.04,18.15,6.14,29.14,6.14   c10.24,0,19.65-1.97,27.77-5.75l22.53,22.53l19.74-19.74l-21.34-21.34C194.51,186.74,196.24,180.59,196.24,174.3z\" fill=\"white\" />\n    </g>\n    <g transform=\"matrix(0.75,0,0,0.75,40,40)\">\n        <path fill=\"#492fb9\" d=\"m623 462.76q10.84 13.27 26.98 31.52 16.12 18.24 26.92 39.85c43.77 87.68-28.71 185.94-123.16 181.77-41.43-1.83-76.36-21.17-101-54.22q-7.38-9.9-12.45-21.34-1.82-4.1-3.36-7.91-11.74-31.78-6.64-64.39c4.69-29.93 22.11-56.14 41.95-78.37 15.43-17.28 29.37-33.39 42.01-52.07 7.45-11.02 13.67-24.11 20.24-36.33q1.92-3.55 3.41-7.3 13.07-32.74 20.44-66.71a0.66 0.66 0 0 1 1.29 0c5.14 23.1 11.8 45.91 21.62 67.38 3.25 7.11 5.86 14.79 9.45 21.26q13.73 24.74 32.3 46.86z\" />\n        <g transform=\"matrix(1.95918367347,0,0,1.95918367347,495,525)\">\n            <path d=\"M13.3734 34.4709L14.3282 41.1736L9.55243 42.131L5.73146 41.1736L0 31.5987L1.91049 14.3628L8.59676 5.7453L17.1935 4.78789L25.7903 0L37.2541 5.7453L34.3879 8.61751C42.6664 9.89405 48.0796 10.8523 50.6266 11.4906C54.4476 12.448 61.1347 17.2359 62.0895 18.1933C63.0452 19.1507 62.5894 23.552 62.0895 26.8108C61.7557 28.9834 61.1191 30.579 60.179 31.5987L64 53.6216H55.4032L57.3137 51.7068L49.6718 35.4283L28.6564 38.3014L21.0162 53.6216H12.4195L15.2848 48.8337L21.0162 28.7256L17.1952 24.896L8.59676 26.8108L7.64108 34.4709L10.5064 37.344L13.3725 34.4709H13.3734ZM26.8108 45.7799L29.6649 39.8988L33.4703 38.9189L36.3243 53.6216H26.8108L28.7135 52.6417L26.8108 45.7799ZM45.1459 39.1222L48 37.1892L52.7568 45.4054L51.8054 53.6216H43.2432L45.1459 50.7217V39.1222V39.1222Z\" fill=\"#ffffff\" />\n        </g>\n    </g>\n    <defs>\n        <radialGradient id=\"paint0_radial_440_36\" cx=\"0\" cy=\"0\" r=\"1\" gradientUnits=\"userSpaceOnUse\" gradientTransform=\"translate(196 143.5) rotate(54.1675) scale(497.082)\">\n            <stop stop-color=\"#323638\"/>\n            <stop offset=\"1\"/>\n        </radialGradient>\n    </defs>\n</svg>\n";
// CurveYield Markets v4 — real Fraxtal Morpho Blue data and on-chain USD valuations.
// Missing market/price/wallet/history reads return null (rendered as an em dash).
const CHAIN_ID=252;
const MORPHO='0xcce2862aed7f2248063c3dcf6906582166c2b6ca';
const VAULT='0x876a56e39e51b4b9734d9798c33bfb186d15d766';
const IRM='0x1161c47629f30c904547d259fb4bb92e10169651';
const COLLATERAL=VAULT;
const USD_WFRAX_CURVE='0xa0d3911349e701a1f49c1ba2dda34b4ce9636569';
const USD_SFRX_REDEMPTION='0xbfc4d34db83553725ec6c768da71d2d9c1456b55';
const MORPHO_DEPLOY_BLOCK=44013954;
const RPC_ENDPOINTS=['https://rpc.frax.com','https://fraxtal-rpc.publicnode.com'];
const MARKET_INFO={
 wfrax:{slug:'wfrax',token:'WFRAX',loan:'0xFc00000000000000000000000000000000000002',oracle:'0xe49a63067768d6ecf4b607ef54b4eaf5d22ab7db',id:'0xb1960d24b04dd48407c6409c648833dcb3aa11201d49cffaa8e3addec15827d1',lltv:88},
 frxusd:{slug:'frxusd',token:'frxUSD',loan:'0xfc00000000000000000000000000000000000001',oracle:'0x6da1203d4b1edc187345b0cf6ee9b5731d407e34',id:'0x807653235a3872ebae280c1f5d4441d9cdc40b2b2148be8fb1d10922a80c261c',lltv:81},
 sfrxusd:{slug:'sfrxusd',token:'sfrxUSD',loan:'0xfc00000000000000000000000000000000000008',oracle:'0xb1383718b657418cd4be4c973e9a68dc79d6a3a2',id:'0xa751be8ab5675783a65f0823d3d4e604d03bac5389ae6d7ac26ba2375b893a7e',lltv:81}
};
const pad=v=>BigInt(v).toString(16).padStart(64,'0');
const addr=a=>a.toLowerCase().slice(2).padStart(64,'0');
const calldata=(selector,...parts)=>selector+parts.map(x=>typeof x==='string'&&x.startsWith('0x')?x.slice(2).padStart(64,'0'):pad(x)).join('');
function words(hex){if(typeof hex!=='string'||!/^0x[0-9a-fA-F]*$/.test(hex))throw new Error('Malformed RPC response');const d=hex.slice(2);if(d.length%64)throw new Error('Invalid ABI response length');return d.match(/.{64}/g)?.map(w=>BigInt('0x'+w))??[]}
function oneWord(raw){try{const w=words(raw);return w.length?w[0]:null}catch{return null}}
function asFloat(n,dec=18){return n==null?null:Number(n)/10**dec}
function finite(n){return typeof n==='number'&&Number.isFinite(n)?n:null}
async function rpc(calls){let lastError;
 for(const endpoint of RPC_ENDPOINTS){try{
  const payload=calls.map((c,i)=>({jsonrpc:'2.0',id:i+1,method:c.method,params:c.params??[]}));
  const response=await fetch(endpoint,{method:'POST',headers:{'content-type':'application/json','accept':'application/json'},body:JSON.stringify(payload),signal:AbortSignal.timeout(9000)});
  if(!response.ok)throw new Error('RPC HTTP '+response.status);
  const results=await response.json();
  if(!Array.isArray(results)||results.length!==calls.length)throw new Error('RPC batch unsupported');
  const map=new Map(results.map(x=>[x.id,x]));
  if(results.some(x=>x.error)&&endpoint!==RPC_ENDPOINTS.at(-1)){lastError=new Error(results.find(x=>x.error).error.message);continue}
  return calls.map((c,i)=>{const r=map.get(i+1);return !r?{error:'RPC omitted requested result'}:r.error?{error:r.error.message||'RPC error'}:{result:r.result??null}});
 }catch(e){lastError=e}}
 throw new Error('Fraxtal RPC unavailable: '+(lastError?.message??'unknown'));
}
const ethCall=(to,data)=>({method:'eth_call',params:[{to,data},'latest']});
const MKT_SELECTOR='0x5c60e39a',ORACLE_SELECTOR='0xa035b1fe',APR_SELECTOR='0xc89d5b8b',PPS_SELECTOR='0x77c7b8fc';
const RATE_SELECTOR='0x8c00bf6b',POSITION_SELECTOR='0x93c52062',BALANCE_SELECTOR='0x70a08231';
const CURVE_SELECTOR='0x66903e80',INIT_SELECTOR='0xac5555aa',CACHED_SELECTOR='0xdf739d84';
function paramsWords(m){return [addr(m.loan),addr(COLLATERAL),addr(m.oracle),addr(IRM),pad(BigInt(m.lltv)*10n**16n)]}
function numericRate(raw){const value=oneWord(raw);return value===null?null:finite(asFloat(value)*365*24*3600*100)}
function safeAmount(value){return value==null?null:finite(asFloat(value))}
function usdTimes(value,price){return value==null||price==null?null:finite(value*price)}

const SUPPORTED_FACTORIES=[{address:'0x2682d4b95386ffc7f5de064df2be89f16476942a',fromBlock:44025030,topic:'0x7a32ce4ff01835c07f0112eaf5df84f4f059e29bf9b1b58d582e19f6e93e02d5'},{address:'0xc0890482e5b65b5d8fe9947eb362642435a107f9',fromBlock:44029090,topic:'0x7a32ce4ff01835c07f0112eaf5df84f4f059e29bf9b1b58d582e19f6e93e02d5'}];
const FACTORY_INDEX_CACHE='https://markets.curveyield.org/__factory_index_v22';
function safeSymbol(raw){
 try{
  if(typeof raw!=='string'||!/^0x[0-9a-fA-F]+$/.test(raw))return null;
  const h=raw.slice(2);if(h.length<64)return null;
  let data=h;if(h.length>64){const offset=Number(BigInt('0x'+h.slice(0,64)))*2;
   if(offset+64>h.length)return null;const n=Number(BigInt('0x'+h.slice(offset,offset+64)));
   if(n>128||offset+64+n*2>h.length)return null;data=h.slice(offset+64,offset+64+n*2)}
  const b=Uint8Array.from(data.match(/../g)||[],x=>parseInt(x,16));
  return new TextDecoder().decode(b).replace(/[^A-Za-z0-9._-]/g,'').slice(0,24)||null;
 }catch{return null}
}
async function rpcChunks(calls){
 const all=[];for(let i=0;i<calls.length;i+=32)all.push(...await rpc(calls.slice(i,i+32)));return all;
}
async function indexedMarketRequests(head){
 const last=Math.max(0,head-3),cache=globalThis.caches?.default;
 let prev=null;
 if(cache)try{const response=await cache.match(FACTORY_INDEX_CACHE);if(response){const d=await response.json();
  if(d.version===22&&Number.isInteger(d.block)&&d.block<=last&&Array.isArray(d.events)&&d.events.length<10000)prev=d;}}catch{}
 const events=new Map((prev?.events||[]).map(x=>[x.id,x]));
 if(prev&&prev.block>=last-5)return {events:[...events.values()],block:prev.block};
 const jobs=[];
 for(const factory of SUPPORTED_FACTORIES){
  const first=Math.max(factory.fromBlock,prev?prev.block-6:factory.fromBlock);
  for(const [key,event] of events){if(event.factory===factory.address&&event.block>=first)events.delete(key)}
  for(let b=first;b<=last;b+=2500)jobs.push({factory,from:b,to:Math.min(last,b+2499)});
 }
 for(let i=0;i<jobs.length;i+=10){
  const batch=jobs.slice(i,i+10);
  const result=await rpc(batch.map(t=>({method:'eth_getLogs',params:[{address:t.factory.address,topics:[t.factory.topic],fromBlock:'0x'+t.from.toString(16),toBlock:'0x'+t.to.toString(16)}]})));
  for(let k=0;k<result.length;k++){
   if(result[k]?.error||!Array.isArray(result[k]?.result))throw Error('Factory event scan failed');
   for(const log of result[k].result){
    const id=log.topics?.[1]?.toLowerCase();
    if(!/^0x[0-9a-f]{64}$/.test(id||'')||log.address?.toLowerCase()!==batch[k].factory.address)continue;
    const amounts=words(log.data||'0x');
    events.set(id,{id,factory:batch[k].factory.address,block:Number(BigInt(log.blockNumber)),
     creator:'0x'+(log.topics[2]||'').slice(-40),receiver:'0x'+(log.topics[3]||'').slice(-40),
     creatorFee:amounts[0]?.toString(),totalFee:amounts[1]?.toString(),txHash:log.transactionHash});
   }
  }
 }
 const next={version:22,block:last,events:[...events.values()]};
 if(cache)try{await cache.put(FACTORY_INDEX_CACHE,new Response(JSON.stringify(next),{headers:{'cache-control':'public,max-age=2592000','content-type':'application/json'}}))}catch{}
 return {events:next.events,block:last};
}
async function discoveredMarketState(block,standard){
 const index=await indexedMarketRequests(block);
 if(!index.events.length)return {markets:{},scannedTo:index.block};
 const params=await rpcChunks(index.events.map(e=>ethCall(MORPHO,calldata('0x2c3c9157',e.id))));
 const found=[];
 const toAddr=w=>'0x'+w.toString(16).padStart(40,'0');
 for(let i=0;i<index.events.length;i++){
  const p=params[i]?.result?words(params[i].result):null;
  if(!p||p.length<5||p[0]===0n||p[1]===0n)continue;
  found.push({...index.events[i],loan:toAddr(p[0]),collateral:toAddr(p[1]),oracle:toAddr(p[2]),irm:toAddr(p[3]),lltvRaw:p[4].toString(),lltv:Number(p[4])/1e16});
 }
 if(!found.length)return {markets:{},scannedTo:index.block};
 const calls=[];
 for(const m of found)calls.push(ethCall(MORPHO,calldata(MKT_SELECTOR,m.id)),ethCall(m.loan,'0x313ce567'),ethCall(m.collateral,'0x313ce567'),
  ethCall(m.loan,'0x95d89b41'),ethCall(m.collateral,'0x95d89b41'),ethCall(m.oracle,ORACLE_SELECTOR));
 const r=await rpcChunks(calls);const pending=[],rateCalls=[];
 for(let i=0;i<found.length;i++){
  const m=found[i],d=r[i*6]?.result?words(r[i*6].result):null;
  if(!d||d.length<6||d[4]===0n)continue;
  const ld=oneWord(r[i*6+1]?.result),cd=oneWord(r[i*6+2]?.result);
  const loanDecimals=ld!=null&&ld<=36n?Number(ld):null,collateralDecimals=cd!=null&&cd<=36n?Number(cd):null;
  const token=safeSymbol(r[i*6+3]?.result)||(m.loan.slice(0,6)+'…'+m.loan.slice(-4));
  const collateralSymbol=safeSymbol(r[i*6+4]?.result)||(m.collateral.slice(0,6)+'…'+m.collateral.slice(-4));
  const p=oneWord(r[i*6+5]?.result);
  const oraclePrice=p!=null&&ld!=null&&cd!=null?finite(Number(p)/10**(36+loanDecimals-collateralDecimals)):null;
  const match=Object.values(standard).find(x=>x.loan.toLowerCase()===m.loan.toLowerCase());
  const loanUsdPrice=match?.loanUsdPrice??null;
  const supply=loanDecimals==null?null:finite(Number(d[0])/10**loanDecimals);
  const borrow=loanDecimals==null?null:finite(Number(d[2])/10**loanDecimals);
  const liquidity=supply!=null&&borrow!=null?Math.max(0,supply-borrow):null;
  const utilization=supply!=null&&borrow!=null?(supply>0?borrow/supply*100:0):null;
  const value={...m,slug:m.id,token,collateralSymbol,loanDecimals,collateralDecimals,oraclePrice,loanUsdPrice,
   collateralUsdPrice:oraclePrice!=null&&loanUsdPrice!=null?finite(oraclePrice*loanUsdPrice):null,
   supply,borrow,liquidity,utilization,borrowApr:null,lendApr:null,
   supplyUsd:usdTimes(supply,loanUsdPrice),borrowUsd:usdTimes(borrow,loanUsdPrice),liquidityUsd:usdTimes(liquidity,loanUsdPrice),
   lastUpdate:Number(d[4]),feePercent:Number(d[5])/1e16,supplyShares:d[1].toString(),borrowShares:d[3].toString(),
   totalSupplyAssetsRaw:d[0].toString(),totalBorrowAssetsRaw:d[2].toString()};
  pending.push(value);
  rateCalls.push(ethCall(m.irm,RATE_SELECTOR+[addr(m.loan),addr(m.collateral),addr(m.oracle),addr(m.irm),pad(BigInt(m.lltvRaw)),...d.map(pad)].join('')));
 }
 const rates=await rpcChunks(rateCalls),markets={};
 for(let i=0;i<pending.length;i++){
  const m=pending[i];m.borrowApr=numericRate(rates[i]?.result);
  m.lendApr=m.borrowApr!=null&&m.utilization!=null?finite(m.borrowApr*m.utilization/100*(1-m.feePercent/100)):null;
  markets[m.id]=m;
 }
 return {markets,scannedTo:index.block};
}

async function liveMarkets(){
 const names=Object.keys(MARKET_INFO);
 // Stable quote is user-defined $1 for frxUSD. Other prices are LIVE chain readings.
 // Curve frxUSD/FXB/WFRAX: coin[0]=frxUSD, coin[2]=WFRAX, price_oracle(1)=frxUSD/WFRAX.
 // sfrxUSD price is 1-share -> frxUSD assets at the verified mint/redeem contract.
 const base=[{method:'eth_blockNumber',params:[]},ethCall(VAULT,APR_SELECTOR),ethCall(VAULT,PPS_SELECTOR),
  ethCall(USD_WFRAX_CURVE,calldata('0x68727653',1)),
  ethCall(USD_SFRX_REDEMPTION,calldata('0x07a2d13a',10n**18n)),
  ethCall(IRM,'0x5404d933'),ethCall(IRM,'0xbee1d9ea'),ethCall(VAULT,'0xcb3296ec')];
 for(const slug of names){const m=MARKET_INFO[slug];base.push(ethCall(MORPHO,calldata(MKT_SELECTOR,m.id)));base.push(ethCall(m.oracle,ORACLE_SELECTOR))}
 const fetched=await rpc(base);
 const block=typeof fetched[0]?.result==='string'&&/^0x[0-9a-fA-F]+$/.test(fetched[0].result)?Number(BigInt(fetched[0].result)):null;
 const vaultApr=oneWord(fetched[1]?.result)==null?null:finite(asFloat(oneWord(fetched[1].result))*100);
 const vaultPps=asFloat(oneWord(fetched[2]?.result));
 const wfraxUsd=asFloat(oneWord(fetched[3]?.result));
 const sfrxusdUsd=asFloat(oneWord(fetched[4]?.result));
 const fallbackApr=asFloat(oneWord(fetched[5]?.result));
 const maximumBorrowApr=asFloat(oneWord(fetched[6]?.result));
 const aprReady=oneWord(fetched[7]?.result)===null?null:oneWord(fetched[7].result)===1n;
 const loanUsd={wfrax:wfraxUsd>0?wfraxUsd:null,frxusd:1,sfrxusd:sfrxusdUsd>0?sfrxusdUsd:null};
 const sources={wfrax:{kind:'Curve price_oracle(1)',address:USD_WFRAX_CURVE,reference:'frxUSD = $1'},frxusd:{kind:'User-specified reference',address:null,reference:'frxUSD = $1'},sfrxusd:{kind:'Verified mint/redeem convertToAssets(1e18)',address:USD_SFRX_REDEMPTION,reference:'frxUSD = $1'}};
 const marketRaw={},extra=[];
 for(let j=0;j<names.length;j++){
  const slug=names[j],m=MARKET_INFO[slug],x=fetched[8+2*j],oracleResult=fetched[9+2*j];
  const data=x?.result?words(x.result):null;
  if(!data||data.length<6){marketRaw[slug]={error:x?.error||'Market read unavailable'};continue}
  marketRaw[slug]={data,priceRaw:oracleResult?.result??null,priceError:oracleResult?.error??null,error:null};
  extra.push({slug,kind:'rate',call:ethCall(IRM,RATE_SELECTOR.slice(0,10)+[...paramsWords(m),...data.map(pad)].join(''))});
  extra.push({slug,kind:'curve',call:ethCall(IRM,calldata(CURVE_SELECTOR,m.id))});
  extra.push({slug,kind:'init',call:ethCall(IRM,calldata(INIT_SELECTOR,m.id))});
  extra.push({slug,kind:'cached',call:ethCall(IRM,calldata(CACHED_SELECTOR,m.id))});
 }
 const extras=extra.length?await rpc(extra.map(x=>x.call)):[];
 const results={};
 for(const slug of names){const m=MARKET_INFO[slug],x=marketRaw[slug],usdPrice=loanUsd[slug];
  if(!x?.data){results[slug]={...m,supply:null,borrow:null,liquidity:null,utilization:null,borrowApr:null,lendApr:null,oraclePrice:null,loanUsdPrice:usdPrice,usdOracle:sources[slug],supplyUsd:null,borrowUsd:null,liquidityUsd:null,collateralUsdPrice:null,vaultApr,vaultPps,min:null,target:null,max:null,utilTarget:null,rebate:null,curveCollateralApr:null,maximumBorrowApr:null,error:x?.error??'Unavailable'};continue}
  const d=x.data,supply=safeAmount(d[0]),borrow=safeAmount(d[2]);
  const liquid=supply==null||borrow==null?null:Math.max(0,supply-borrow);
  const util=supply==null||borrow==null?null:supply>0?borrow/supply*100:0;
  const get=k=>{const n=extra.findIndex(v=>v.slug===slug&&v.kind===k);return n>=0?extras[n]?.result:null};
  const borrowApr=numericRate(get('rate'));
  const feePercent=asFloat(d[5])===null?null:asFloat(d[5])*100;
  const lendApr=borrowApr===null||util===null||feePercent===null?null:finite(borrowApr*util/100*(1-feePercent/100));
  const oraclePrice=asFloat(oneWord(x.priceRaw),36);
  const curveRaw=get('curve'), curve=curveRaw?words(curveRaw):null;
  const initRaw=oneWord(get('init')),cachedRaw=oneWord(get('cached'));
  const curveCollateralApr=curve?.length===5?(initRaw===1n?asFloat(cachedRaw):initRaw===0n?(aprReady===true?vaultApr==null?null:vaultApr/100:aprReady===false?fallbackApr:null):null):null;
  const min=curve?.length===5?asFloat(curve[0])*100:null;
  const target=curve?.length===5?asFloat(curve[1])*100:null;
  const max=curve?.length===5?asFloat(curve[2])*100:null;
  const utilTarget=curve?.length===5?asFloat(curve[3])*100:null;
  const rebate=curve?.length===5?asFloat(curve[4])*100:null;
  results[slug]={...m,supply,borrow,liquidity:liquid,utilization:util,borrowApr,lendApr,
   loanUsdPrice:usdPrice,usdOracle:sources[slug],usdPriceError:usdPrice===null?(fetched[slug==='wfrax'?3:4]?.error??'Price feed unavailable'):null,
   supplyUsd:usdTimes(supply,usdPrice),borrowUsd:usdTimes(borrow,usdPrice),liquidityUsd:usdTimes(liquid,usdPrice),
   oraclePrice:oraclePrice!=null&&oraclePrice>0?oraclePrice:null,
   collateralUsdPrice:oraclePrice!=null&&oraclePrice>0?usdTimes(oraclePrice,usdPrice):null,
   vaultApr,vaultPps,min,target,max,utilTarget,rebate,
   curveCollateralApr:curveCollateralApr===null?null:finite(curveCollateralApr*100),
   maximumBorrowApr:maximumBorrowApr===null?null:maximumBorrowApr*100,
   lastUpdate:Number(d[4]),supplyShares:d[1].toString(),borrowShares:d[3].toString(),
   totalSupplyAssetsRaw:d[0].toString(),totalBorrowAssetsRaw:d[2].toString(),
   error:x.error,oracleError:x.priceError};
 }
 let discovered={},discoveryError=null,scannedTo=null;
 try{if(block!=null){const d=await discoveredMarketState(block,results);discovered=d.markets;scannedTo=d.scannedTo;}}catch(e){discoveryError=String(e.message||e)}
 return {chainId:CHAIN_ID,networkOk:block!=null,block,updatedAt:new Date().toISOString(),priceSources:{frxUSD:'USD 1.00 user reference',WFRAX:USD_WFRAX_CURVE,sfrxUSD:USD_SFRX_REDEMPTION},markets:{...results,...discovered},discoveryError,scannedTo};
}
async function walletPositions(wallet,requestedMarket){
 if(!/^0x[a-fA-F0-9]{40}$/.test(wallet))throw new Error('Invalid wallet address');
 if(/^0x[a-fA-F0-9]{64}$/.test(requestedMarket||'')){
  const info=await liveMarkets(),m=info.markets[requestedMarket.toLowerCase()];
  if(!m?.factory)throw Error('Unknown factory market');
  const r=await rpc([ethCall(MORPHO,calldata(POSITION_SELECTOR,m.id,wallet)),ethCall(m.loan,calldata(BALANCE_SELECTOR,wallet)),ethCall(m.collateral,calldata(BALANCE_SELECTOR,wallet))]);
  const d=r[0]?.result?words(r[0].result):null;
  if(!d||d.length<3)return {chainId:CHAIN_ID,wallet,positions:{[m.id]:{error:'Position unavailable'}}};
  function shares(s,assets,total){if(BigInt(total)===0n)return 0;return Number(s*BigInt(assets)/BigInt(total))/10**m.loanDecimals}
  const supplyAssets=shares(d[0],m.totalSupplyAssetsRaw,m.supplyShares);
  const debtAssets=shares(d[1],m.totalBorrowAssetsRaw,m.borrowShares);
  const collateral=Number(d[2])/10**m.collateralDecimals;
  const val=m.oraclePrice!=null?collateral*m.oraclePrice:null;
  const position={supplyAssets,debtAssets,collateral,
   ltv:val==null?null:val?debtAssets/val*100:debtAssets===0?0:null,
   walletLoanBalance:asFloat(oneWord(r[1]?.result),m.loanDecimals),walletCollateralBalance:asFloat(oneWord(r[2]?.result),m.collateralDecimals),
   supplyUsd:usdTimes(supplyAssets,m.loanUsdPrice),debtUsd:usdTimes(debtAssets,m.loanUsdPrice),collateralUsd:usdTimes(collateral,m.collateralUsdPrice)};
  return {chainId:CHAIN_ID,wallet,block:info.block,positions:{[m.id]:position}};
 }
 const info=await liveMarkets(),names=Object.keys(MARKET_INFO),calls=[];
 for(const slug of names){const m=MARKET_INFO[slug];calls.push(ethCall(MORPHO,calldata(POSITION_SELECTOR,m.id,wallet)));calls.push(ethCall(m.loan,calldata(BALANCE_SELECTOR,wallet)))}
 calls.push(ethCall(VAULT,calldata(BALANCE_SELECTOR,wallet)));
 const responses=await rpc(calls);const vaultBal=safeAmount(oneWord(responses.at(-1)?.result));
 const positions={};
 for(let j=0;j<names.length;j++){
  const slug=names[j],m=info.markets[slug],d=responses[2*j]?.result?words(responses[2*j].result):null;
  const shareSupply=d?.[0]??null,shareBorrow=d?.[1]??null,col=d?.[2]??null;
  function sharesToAssets(shares,assetRaw,shareRaw){
   if(shares==null||assetRaw==null||shareRaw==null)return null;
   if(BigInt(shareRaw)===0n)return shares===0n?0:null;
   return safeAmount(shares*BigInt(assetRaw)/BigInt(shareRaw));
  }
  const supplyAssets=sharesToAssets(shareSupply,m?.totalSupplyAssetsRaw,m?.supplyShares);
  const debtAssets=sharesToAssets(shareBorrow,m?.totalBorrowAssetsRaw,m?.borrowShares);
  const collateral=safeAmount(col);
  const walletLoanBalance=safeAmount(oneWord(responses[2*j+1]?.result));
  const collateralValue=collateral==null||m?.oraclePrice==null?null:collateral*m.oraclePrice;
  const ltv=collateralValue==null||debtAssets==null?null:collateralValue>0?debtAssets/collateralValue*100:debtAssets===0?0:null;
  positions[slug]={supplyShares:shareSupply?.toString()??null,borrowShares:shareBorrow?.toString()??null,
   supplyAssets,debtAssets,collateral,ltv,walletLoanBalance,walletCollateralBalance:vaultBal,
   supplyUsd:usdTimes(supplyAssets,m?.loanUsdPrice),debtUsd:usdTimes(debtAssets,m?.loanUsdPrice),collateralUsd:usdTimes(collateral,m?.collateralUsdPrice),
   error:d===null?responses[2*j]?.error??'Position RPC unavailable':null};
 }
 return {chainId:CHAIN_ID,wallet:wallet.toLowerCase(),block:info.block,positions};
}
// Verified event signatures from the pinned Morpho Blue EventsLib source.
const MARKET_EVENTS={
 '0xedf8870433c83823eb071d3df1caa8d008f12f6440918c20d75a3602cda30fe0':{kind:'Supply',index:0,asset:'loan'},
 '0xa56fc0ad5702ec05ce63666221f796fb62437c32db1aa1aa075fc6484cf58fbf':{kind:'Withdraw',index:1,asset:'loan'},
 '0x570954540bed6b1304a87dfe815a5eda4a648f7097a16240dcd85c9b5fd42a43':{kind:'Borrow',index:1,asset:'loan'},
 '0x52acb05cebbd3cd39715469f22afbf5a17496295ef3bc9bb5944056c63ccaa09':{kind:'Repay',index:1,asset:'loan'},
 '0xa3b9472a1399e17e123f3c2e6586c23e504184d504de59cdaa2b375e880c6184':{kind:'Supply collateral',index:1,asset:'collateral'},
 '0xe80ebd7cc9223d7382aab2e0d1d6155c65651f83d53c8b9b06901d167e321142':{kind:'Withdraw collateral',index:1,asset:'collateral'},
 '0xa4946ede45d0c6f06a0f5ce92c9ad3b4751452d2fe0e25010783bcab57a67e41':{kind:'Liquidation',index:0,asset:'loan'}
};
async function marketHistory(slug){
 let m=MARKET_INFO[slug];if(!m&&/^0x[a-f0-9]{64}$/.test(slug||'')){m=(await liveMarkets()).markets[slug]}if(!m)throw new Error('Unknown market');
 const numberResult=(await rpc([{method:'eth_blockNumber',params:[]}]))[0]?.result;
 const latest=numberResult?Number(BigInt(numberResult)):null;
 if(latest===null)throw new Error('Cannot determine Fraxtal block');
 const start=Math.max(MORPHO_DEPLOY_BLOCK,latest-23999);
 const segments=[];for(let b=start;b<=latest;b+=2500)segments.push([b,Math.min(latest,b+2499)]);
 const all=[];
 // All ranges must return successfully before an empty history is classified as truly empty.
 for(const [from,to] of segments){
  const filter={address:MORPHO,fromBlock:'0x'+from.toString(16),toBlock:'0x'+to.toString(16),topics:[null,m.id]};
  const result=(await rpc([{method:'eth_getLogs',params:[filter]}]))[0];
  if(result?.error||!Array.isArray(result?.result))throw new Error(result?.error??'Event index unavailable');
  for(const log of result.result){const desc=MARKET_EVENTS[log.topics?.[0]?.toLowerCase()];if(!desc)continue;
   const ws=words(log.data);const tokenDecimals=desc.asset==='collateral'?m.collateralDecimals:m.loanDecimals;
   const amount=ws[desc.index]==null||(m.factory&&tokenDecimals==null)?null:asFloat(ws[desc.index],tokenDecimals??18);
   all.push({kind:desc.kind,amount,asset:desc.asset==='collateral'?(m.collateralSymbol||'cysdFXS'):m.token,block:Number(BigInt(log.blockNumber)),txHash:log.transactionHash,logIndex:Number(BigInt(log.logIndex??'0x0'))});
  }
 }
 all.sort((a,b)=>b.block-a.block||b.logIndex-a.logIndex);
 const liquidations=all.filter(e=>e.kind==='Liquidation');
 return {slug,fromBlock:start,toBlock:latest,complete:start===MORPHO_DEPLOY_BLOCK,
  activity:all.slice(0,50),liquidations:liquidations.slice(0,50),
  activityCount:all.length,liquidationCount:liquidations.length,updatedAt:new Date().toISOString()};
}
function responseJson(data,status=200,ttl=0){return new Response(JSON.stringify(data),{status,headers:{'content-type':'application/json; charset=utf-8','cache-control':ttl?`public, max-age=${ttl}`:'no-store','x-content-type-options':'nosniff','access-control-allow-origin':'*'}})}
const PAGE_HEADERS={'content-type':'text/html; charset=utf-8','x-content-type-options':'nosniff','referrer-policy':'strict-origin-when-cross-origin','cache-control':'public, max-age=60','content-security-policy':"default-src 'self'; script-src 'self' https://boosthub.curveyield.org; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self'; font-src 'self' data:; object-src 'none'; base-uri 'none'; frame-ancestors 'none'"};

const VAULT_CLIENT="\n'use strict';\n(function(){\nconst IS_ETH=new URLSearchParams(location.search).get('chain')==='ethereum',CH_ID=IS_ETH?1:252,NETWORK=IS_ETH?'Ethereum':'Fraxtal',SUFFIX=IS_ETH?'?chain=ethereum':'',EXPLORER=IS_ETH?'https://etherscan.io':'https://fraxscan.com';\nconst F=IS_ETH?'0xA1D94F746dEfa1928926b84fB2596c06926C0405':'0x711bCE12269a3a496eFaABB8B9AD5A4485E08A24',CHAIN=IS_ETH?'0x1':'0xfc',KEY=IS_ETH?'cy-vaults-ethereum-v1':'cy-vaults-fraxtal-v1';\nconst CY_V10_SOURCE_URL='https://github.com/curveyield3/Contract-Automation/blob/main/github-native-sim/curveyield-protected-vault-v10/contracts/CurveYieldProtectedVaultController-v10.sol';\nconst CY_V10_MASTER_POLICY='0xd9a75f28a92d929853872c606097e7050890f35a';\nconst CY_V10_TREASURY='0x47623C62f281807D615eeb4A2CEee9d97F9D3C49';\nconst CY_V10_MAX_CREATION=1000000000000000000n;\nconst CY_V10_INIT='0x60c0806040523461029f57608081613e36803803809161001f8285610302565b83398101031261029f5761003281610325565b9061003f60208201610325565b610050606060408401519301610325565b926601c6bf52634000600b5560c8600c5566071afd498d0000600f5560c860105560fc46036102f3576001600160a01b0316801580156102e2575b80156102d9575b6102ca57600380546001600160a01b03199081169290921790555f805482166001600160a01b039384169081179091556005805490921617905560a0828152600292909255919091166080526040519081016001600160401b038111828210176102b6576040525f8152602081015f8152604082015f815260608301915f835260808401935f8552600460a0600180821b03608051166040519283809263b0b423d760e01b82525afa9081156102ab575f905f905f905f905f9561025a575b50848a52885286528452825215610227578051825166470de4df8200008211801561024f575b8015610248575b610227576706f05b59d3b200009161271061019b6101a29361035a565b0490610339565b1161022757825184516608e1bc9bf040008211801561023d575b8015610236575b6102275766b1a2bc2ec500009161271061019b6101df9361035a565b116102275751600f555160105551600b5551600c5551600155604051613acd90816103698239608051818181611f6b0152612a46015260a051818181610b710152611da10152f35b6358d620b360e01b5f5260045ffd5b505f6101c3565b506103e881116101bc565b505f61017e565b506103e88111610177565b94505050505060a0813d60a0116102a3575b8161027960a09383610302565b8101031261029f578051602082015160408301516060840151608090940151935f610151565b5f80fd5b3d915061026c565b6040513d5f823e3d90fd5b634e487b7160e01b5f52604160045260245ffd5b63e6c4247b60e01b5f5260045ffd5b50833b15610092565b506001600160a01b0382161561008b565b6310dfc03360e01b5f5260045ffd5b601f909101601f19168101906001600160401b038211908210176102b657604052565b51906001600160a01b038216820361029f57565b9190820180921161034657565b634e487b7160e01b5f52601160045260245ffd5b905f9115600117156103465756fe6080806040526004361015610012575f80fd5b5f905f3560e01c908162796bf7146124da57508063054c4797146124b857806307945a601461249a57806311cc66b21461240557806313b55f0d146123e7578063158ef93e146123c45780631613752e146123085780631661f5301461229457806316ccac96146122765780631bf35ce21461217f5780631ccc84881461215657806320146eb51461213457806322edfc3514612116578063249d39e9146120f95780632ce5b098146120a95780633820ce691461207a57806338d17ca2146107b157806338d278c1146120585780634c21afe514612033578063552ccd2e14612010578063570ca73514611fe75780635a7610d414611fc15780635aa6e67514611f9a57806361cecb0614611f555780636488c39b14611f325780636ab7a1bc14611e9f578063715f167b14611ded5780637382fc88146102f25780637459ea1d14611dc457806376b6f58114611d895780637ae6c26914610bdf5780637e0c962e14610b485780638391454014610b295780638616527814610b005780638f9326e214610a4557806393132c9f14610a2a578063941f5d2514610a0157806398878c31146109e6578063a3b88767146109c4578063aa9302a014610998578063ac66cae91461090e578063ac7e534e146108e5578063afff1617146108c3578063b10a6950146108a5578063b542ad18146107f2578063b774682f146107d4578063be8a361f146107b6578063bf8492e6146107b1578063d38bfff41461071f578063d6d54531146106f1578063de093ec6146106b3578063e31aaeed14610695578063e4fc6b6d14610633578063e50f2847146105ff578063e521cb9214610520578063eccb0ef9146104fe578063f068b64a146104e0578063f0be55c7146103bd578063f310c3ac1461039f578063fbfa77cf14610376578063fcad4448146102f7578063fd77d195146102f25763fefc0f0e146102d2575f80fd5b346102ef57806003193601126102ef576020600c54604051908152f35b80fd5b6125fc565b50346102ef57806003193601126102ef576004546001600160a01b03811633036103685760038054336001600160a01b03198083168217909355929091166004556001600160a01b03167ffbe5b6cbafb274f445d7fed869dc77a838d8243a22c460de156560e8857cad038380a380f35b6282b42960e81b8252600482fd5b50346102ef57806003193601126102ef576007546040516001600160a01b039091168152602090f35b50346102ef57806003193601126102ef576020600d54604051908152f35b50346102ef5760203660031901126102ef576004356001600160401b0381116104bf576103ee9036906004016125b4565b6003549091906001600160a01b031633036104d25760ff60125416156104c35760075483906001600160a01b0316803b156104bf57816040518092630b467b9b60e01b82526020600483015281838161044b602482018b8b61264d565b03925af180156104b45761049b575b50507f12a8138ca10c8cec9e024524155814d40ada99473ff8c02d33f76b87a7ce26159161049560405192839260208452602084019161264d565b0390a180f35b816104a591612618565b6104b057825f61045a565b8280fd5b6040513d84823e3d90fd5b5080fd5b6321c4e35760e21b8352600483fd5b6282b42960e81b8352600483fd5b50346102ef57806003193601126102ef576020600e54604051908152f35b50346102ef57806003193601126102ef57602060405166071afd498d00008152f35b50346102ef5760203660031901126102ef5761053a61259e565b81546001600160a01b031633036103685760ff60125416156105f0576013546105e15760016013556001600160a01b031680156105d257610580600e54600a5490612bc5565b6105886132a1565b5050600580546001600160a01b0319811683179091556001600160a01b03167f91e1f7681cd20e140c1b9ca733d5112019e41d298b69cd2fcf1f28db37f16dad8380a38060135580f35b63e6c4247b60e01b8252600482fd5b63558a1e0360e11b8252600482fd5b6321c4e35760e21b8252600482fd5b50346102ef5760203660031901126102ef5760206301e1338061062a600b54600c54906004356136d1565b04604051908152f35b50346102ef57806003193601126102ef5760ff6012541615610686576013546106775760409060016013556106666132a1565b909160135582519182526020820152f35b63558a1e0360e11b8152600490fd5b6321c4e35760e21b8152600490fd5b50346102ef57806003193601126102ef576020600154604051908152f35b50346102ef57806003193601126102ef5760ff6012541615610686576013546106775760016013556106ea600e54600a5490612bc5565b8060135580f35b50346102ef5760203660031901126102ef576020610717600b54600c54906004356136d1565b604051908152f35b50346102ef5760203660031901126102ef5761073961259e565b8154906001600160a01b03821690338290036107a3576001600160a01b0316918215610794576001600160a01b031916821783557f5f56bee8cffbe9a78652a74a60705edede02af10b0bbb888ca44b79a0d42ce808380a380f35b63e6c4247b60e01b8452600484fd5b6282b42960e81b8452600484fd5b6125e1565b50346102ef57806003193601126102ef5760206040516276a7008152f35b50346102ef57806003193601126102ef576020601154604051908152f35b50346102ef5760203660031901126102ef5761080c61259e565b6003546001600160a01b031633036103685760ff60125416156105f0576013546105e15760016013556001600160a01b031680156105d257610853600e54600a5490612bc5565b61085b6132a1565b5050600680546001600160a01b0319811683179091556001600160a01b03167f3d9897364ecf9ac75c7fe8abc08569fcd841be083e27761cf53f54d464e115488380a38060135580f35b50346102ef57806003193601126102ef576020600a54604051908152f35b50346102ef57806003193601126102ef576020604051669969a2857b97458152f35b50346102ef57806003193601126102ef576004546040516001600160a01b039091168152602090f35b50346102ef5760203660031901126102ef576004356001600160401b0381116104bf5761093f9036906004016125b4565b60ff60125416156104c35790816109777faa993ca763733293b31db67143a58f8323001a31d7c3cedba1f73e44bf51f2fd93836127ed565b6109818183613248565b61049560405192839260208452602084019161264d565b50346102ef57806003193601126102ef57602060806109b56129ed565b01516001541415604051908152f35b50346102ef57806003193601126102ef57602060405166b1a2bc2ec500008152f35b50346102ef57806003193601126102ef5760206107176127d5565b50346102ef57806003193601126102ef576005546040516001600160a01b039091168152602090f35b50346102ef57806003193601126102ef5760206107176127b3565b50346102ef5760203660031901126102ef57600354600435906001600160a01b031633036103685760ff60125416156105f0576013546105e1576001601355600e5490610a94600a5482612bc5565b808203610aa4575b828060135580f35b7fbe3f7ffed952f2073a89510b5bef2ff551848acdb598109848941a57e101bba091610af6610ad9600f546010549085612b71565b604051938493846040919493926060820195825260208201520152565b0390a15f80610a9c565b50346102ef57806003193601126102ef576008546040516001600160a01b039091168152602090f35b50346102ef57806003193601126102ef5760206040516301e133808152f35b50346102ef5760203660031901126102ef578054600435906001600160a01b03163303610368577f00000000000000000000000000000000000000000000000000000000000000008111610bd05760407f2b10717465d996a68f98e26f124fe29fea1851b7084c53ca98adebf042fc0b2a91600254908060025582519182526020820152a180f35b6358d620b360e01b8252600482fd5b5060c03660031901126102ef57610bf461259e565b906024356001600160a01b03811691908290036102ef57604435926064356001600160401b0381116104b057610c2e9036906004016125b4565b93906084356001600160401b0381116115f857610c4f9036906004016125b4565b600354919290916001600160a01b03163303611d7b57601354611d6c57600160135560ff60125416611d5e576002543403611d4f576001600160a01b0385169687158015611d47575b611d385780158015611d30575b611d215767060e466a525a2e8b8911611d1257610ce9610cc36129ed565b8051600f5560208101516010556040810151600b556060810151600c5560800151600155565b610cf9600f54601054908b612b71565b946040519863a7a2846960e01b8a523060048b01528060248b015260a43560448b015260208a6064818c73711bce12269a3a496efaabb8b9ad5a4485e08a245af1998a1561177c57899a611cf1575b50604051635edec50d60e01b81526001600160a01b03909a1660048b018190529960208160248173711bce12269a3a496efaabb8b9ad5a4485e08a245afa9081156116e7578a91611cd2575b5015611cc357604051638da5cb5b60e01b81526020816004818e5afa9081156116e7578a91611ca4575b506001600160a01b0316301480159190611c4c575b508015611bf7575b8015611b98575b8015611b41575b8015611aea575b8015611a95575b8015611a40575b80156119d4575b8015611968575b80156118fc575b801561188c575b8015611835575b80156117de575b8015611787575b8015611715575b61170657600780546001600160a01b0319168a1790556040516102f4908181016001600160401b038111828210176116f257906020818d936137a4948686843981520301908bf080156116e75760018060a01b03166001600160601b0360a01b600854161760085560405191808301918383106001600160401b038411176116d35791839160209383398c815203019089f080156116c85760018060a01b03166001600160601b0360a01b600954161760095589600e556001600160601b0360a01b6006541617600655873b156116c45760405163c47f002760e01b81526020600482015291879183918291610f319160248401919061264d565b0381838b5af180156116b9579086916116a4575b5050853b156115f857604051635c26412360e11b81526020600482015291859183918291610f789160248401919061264d565b038183895af180156114da5790849161168f575b5050833b156104b05760405163e90956cf60e01b8152306004820152838160248183895af180156114da5790849161167a575b505060085460405163352f8d5160e11b60208201526001600160a01b039091166024808301919091528152610ff5604482612618565b843b156115df578361101b916040518093819263ef7fa71b60e01b8352600483016126f9565b038183895af180156114da57908491611665575b50506008546001600160a01b0316843b156115df576040519063352f8d5160e11b82526004820152838160248183895af180156114da57908491611650575b50506040516370897b2360e01b602082015260248082018390528152611095604482612618565b843b156115df57836110bb916040518093819263ef7fa71b60e01b8352600483016126f9565b038183895af180156114da5790849161163b575b5050833b156104b0576040516370897b2360e01b815260048101829052838160248183895af180156114da57908491611626575b50506009546040516327eab91960e21b60208201526001600160a01b039091166024808301919091528152611139604482612618565b843b156115df578361115f916040518093819263ef7fa71b60e01b8352600483016126f9565b038183895af180156114da57908491611611575b50506009546001600160a01b0316843b156115df57604051906327eab91960e21b82526004820152838160248183895af180156114da579084916115fc575b50506301e133806111c8600b54600c5490613679565b04604051637f2b711960e11b6020820152816024820152602481526111ee604482612618565b853b156115f85784611214916040518093819263ef7fa71b60e01b8352600483016126f9565b0381838a5af18015611541579085916115e3575b5050843b156115df57604051637f2b711960e11b8152600481018290528481602481838a5af18015611541579085916115ca575b505060405163ed27f7c960e01b8152602081600481895afa9081156115415785916115ab575b506008546001600160a01b039182169116148015929061154c575b82156114e5575b508115611470575b50801561141a575b80156113a9575b61139a57600160ff1960125416176012553461132b575b600354600554604080516001600160a01b039485168152602080820198909852918416939092169185917f4a624520066b62b2ba995797ce3bc64318a16facf2bbb1acd2aa324131ea12159190a4601355604051908152f35b818080803460018060a01b03600554165af1611345612741565b501561138b5760209360018060a01b03600554166040513481527f4266f438ae10cd9b08448ad0b35969fed5dbe9493be0dab7a67c25855866633c873392a393506112d2565b6343070ebd60e11b8252600482fd5b639f0cab4560e01b8252600482fd5b50604051638da5cb5b60e01b8152602081600481875afa90811561140f5783916113e0575b506001600160a01b03163014156112bb565b611402915060203d602011611408575b6113fa8183612618565b8101906126a3565b5f6113ce565b503d6113f0565b6040513d85823e3d90fd5b5060405163e66f53b760e01b8152602081600481875afa90811561140f578391611451575b506001600160a01b03163014156112b4565b61146a915060203d602011611408576113fa8183612618565b5f61143f565b60405163537bfaeb60e11b8152909150602081600481885afa9081156114da57906001600160601b039185916114ab575b501614155f6112ac565b6114cd915060203d6020116114d3575b6114c58183612618565b8101906126da565b5f6114a1565b503d6114bb565b6040513d86823e3d90fd5b6040516343bc43c160e11b815291925090602081600481895afa90811561154157906001600160601b03918691611522575b50161415905f6112a4565b61153b915060203d6020116114d3576114c58183612618565b5f611517565b6040513d87823e3d90fd5b6040516306d9a30160e41b8152909250602081600481895afa90811561154157859161158c575b506009546001600160a01b03918216911614159161129d565b6115a5915060203d602011611408576113fa8183612618565b5f611573565b6115c4915060203d602011611408576113fa8183612618565b5f611282565b816115d491612618565b6115df57835f61125c565b8380fd5b816115ed91612618565b6115df57835f611228565b8480fd5b8161160691612618565b6104b057825f6111b2565b8161161b91612618565b6104b057825f611173565b8161163091612618565b6104b057825f611103565b8161164591612618565b6104b057825f6110cf565b8161165a91612618565b6104b057825f61106e565b8161166f91612618565b6104b057825f61102f565b8161168491612618565b6104b057825f610fbf565b8161169991612618565b6104b057825f610f8c565b816116ae91612618565b6115f857845f610f45565b6040513d88823e3d90fd5b8680fd5b6040513d8a823e3d90fd5b634e487b7160e01b8c52604160045260248cfd5b6040513d8c823e3d90fd5b634e487b7160e01b8b52604160045260248bfd5b639f0cab4560e01b8852600488fd5b5060405163391c2e2f60e21b81526327eab91960e21b60048201526020816024818d5afa90811561177c57899161174d575b50610e36565b61176f915060203d602011611775575b6117678183612618565b8101906126c2565b5f611747565b503d61175d565b6040513d8b823e3d90fd5b5060405163391c2e2f60e21b8152637f2b711960e11b60048201526020816024818d5afa90811561177c5789916117bf575b50610e2f565b6117d8915060203d602011611775576117678183612618565b5f6117b9565b5060405163391c2e2f60e21b815263352f8d5160e11b60048201526020816024818d5afa90811561177c578991611816575b50610e28565b61182f915060203d602011611775576117678183612618565b5f611810565b5060405163391c2e2f60e21b81526370897b2360e01b60048201526020816024818d5afa90811561177c57899161186d575b50610e21565b611886915060203d602011611775576117678183612618565b5f611867565b506040516373c558a760e11b81526327eab91960e21b60048201526020816024818d5afa90811561177c5789916118c6575b501515610e1a565b90506020813d6020116118f4575b816118e160209383612618565b810103126118f057515f6118be565b5f80fd5b3d91506118d4565b506040516373c558a760e11b8152637f2b711960e11b60048201526020816024818d5afa90811561177c578991611936575b501515610e13565b90506020813d602011611960575b8161195160209383612618565b810103126118f057515f61192e565b3d9150611944565b506040516373c558a760e11b815263352f8d5160e11b60048201526020816024818d5afa90811561177c5789916119a2575b501515610e0c565b90506020813d6020116119cc575b816119bd60209383612618565b810103126118f057515f61199a565b3d91506119b0565b506040516373c558a760e11b81526370897b2360e01b60048201526020816024818d5afa90811561177c578991611a0e575b501515610e05565b90506020813d602011611a38575b81611a2960209383612618565b810103126118f057515f611a06565b3d9150611a1c565b506040516306d9a30160e41b81526020816004818d5afa90811561177c578991611a76575b506001600160a01b03161515610dfe565b611a8f915060203d602011611408576113fa8183612618565b5f611a65565b5060405163ed27f7c960e01b81526020816004818d5afa90811561177c578991611acb575b506001600160a01b03161515610df7565b611ae4915060203d602011611408576113fa8183612618565b5f611aba565b5060405163537bfaeb60e11b81526020816004818d5afa90811561177c57906001600160601b03918a91611b22575b50161515610df0565b611b3b915060203d6020116114d3576114c58183612618565b5f611b19565b506040516343bc43c160e11b81526020816004818d5afa90811561177c57906001600160601b03918a91611b79575b50161515610de9565b611b92915060203d6020116114d3576114c58183612618565b5f611b70565b506040516318160ddd60e01b81526020816004818d5afa90811561177c578991611bc5575b501515610de2565b90506020813d602011611bef575b81611be060209383612618565b810103126118f057515f611bbd565b3d9150611bd3565b5060405163e66f53b760e01b81526020816004818d5afa90811561177c578991611c2d575b506001600160a01b03161515610ddb565b611c46915060203d602011611408576113fa8183612618565b5f611c1c565b6040516338d52e0f60e01b81529091506020816004818e5afa9081156116e7578a91611c85575b506001600160a01b031614155f610dd3565b611c9e915060203d602011611408576113fa8183612618565b5f611c73565b611cbd915060203d602011611408576113fa8183612618565b5f610dbe565b633011642560e01b8952600489fd5b611ceb915060203d602011611775576117678183612618565b5f610d94565b611d0b919a5060203d602011611408576113fa8183612618565b985f610d48565b6358d620b360e01b8752600487fd5b631cc6a69960e11b8752600487fd5b508215610ca5565b63e6c4247b60e01b8752600487fd5b508415610c98565b637621a1d360e11b8652600486fd5b62dc149f60e41b8652600486fd5b63558a1e0360e11b8652600486fd5b6282b42960e81b8652600486fd5b50346102ef57806003193601126102ef5760206040517f00000000000000000000000000000000000000000000000000000000000000008152f35b50346102ef57806003193601126102ef576006546040516001600160a01b039091168152602090f35b50346102ef5760203660031901126102ef576004356001600160401b0381116104bf57611e1e9036906004016125b4565b6003549091906001600160a01b031633036104d25760ff60125416156104c35760048210611e7e576001600160e01b0319611e59838361266d565b16638c54519b60e01b8114159081611e8d575b50611e7e5790611e7b91613248565b80f35b631cc6a69960e11b8352600483fd5b630579752760e41b141590505f611e6c565b50346102ef5760203660031901126102ef57600354600435906001600160a01b031633036103685760ff60125416156105f0576013546105e1576001601355600a5490611eee81600e54612bc5565b808203611efd57828060135580f35b7f1e981cc4dbcd8ac3a3f87e97434492a94ecc660fdfa39a5964674031d45d563a91610af6610ad9600b54600c5490856136d1565b50346102ef57806003193601126102ef5760206040516706f05b59d3b200008152f35b50346102ef57806003193601126102ef576040517f00000000000000000000000000000000000000000000000000000000000000006001600160a01b03168152602090f35b50346102ef57806003193601126102ef57546040516001600160a01b039091168152602090f35b50346102ef5760203660031901126102ef576020610717600f5460105490600435612b71565b50346102ef57806003193601126102ef576003546040516001600160a01b039091168152602090f35b50346102ef57806003193601126102ef57602060405167060e466a525a2e8b8152f35b50346102ef57806003193601126102ef576020610717600e54600f5460105491612b71565b50346102ef57806003193601126102ef5760206040516601c6bf526340008152f35b50346102ef57806003193601126102ef57602060405173711bce12269a3a496efaabb8b9ad5a4485e08a248152f35b50346102ef57806003193601126102ef5760a06120c46129ed565b805190602081015190604081015160806060830151920151926040519485526020850152604084015260608301526080820152f35b50346102ef57806003193601126102ef5760206040516127108152f35b50346102ef57806003193601126102ef576020601054604051908152f35b50346102ef57806003193601126102ef5760206040516608e1bc9bf040008152f35b50346102ef57806003193601126102ef576009546040516001600160a01b039091168152602090f35b50346102ef5760203660031901126102ef576004356001600160401b0381116104bf576121b09036906004016125b4565b6003549091906001600160a01b031633036104d25760ff60125416156104c3576121da82826127ed565b60075483906001600160a01b0316803b156104bf5781604051809263ef7fa71b60e01b825260206004830152818381612217602482018b8b61264d565b03925af180156104b457612261575b50507f54590c5d1f311c6cfb849e78418707ccb4e720333d9e13933c64e60dd15ea0bd9161049560405192839260208452602084019161264d565b8161226b91612618565b6104b057825f612226565b50346102ef57806003193601126102ef576020600f54604051908152f35b50346102ef5760203660031901126102ef576122ae61259e565b6003546001600160a01b03163303610368576001600160a01b031680156105d257600480546001600160a01b031916821790557fb5b1e24165f8b300d1e606a379d99c44cf148bd625beec3e5cbecdb2a0e0fb5e8280a280f35b50346102ef5760203660031901126102ef576004356001600160401b0381116104bf576123399036906004016125b4565b600354909291906001600160a01b031633036103685760ff60125416156105f057600754919283926001600160a01b031691823b156123bf5761239d92849283604051809681958294635c26412360e11b845260206004850152602484019161264d565b03925af180156104b4576123ae5750f35b816123b891612618565b6102ef5780f35b505050fd5b50346102ef57806003193601126102ef57602060ff601254166040519015158152f35b50346102ef57806003193601126102ef576020600b54604051908152f35b50346102ef5760203660031901126102ef576004356001600160401b0381116104bf576124369036906004016125b4565b600354909291906001600160a01b031633036103685760ff60125416156105f057600754919283926001600160a01b031691823b156123bf5761239d9284928360405180968195829463c47f002760e01b845260206004850152602484019161264d565b50346102ef57806003193601126102ef576020600254604051908152f35b50346102ef57806003193601126102ef57602060405166470de4df8200008152f35b9050346118f05760403660031901126118f0576124f561259e565b602435908115158092036118f0576003546001600160a01b031633036125905760ff6012541615612581576007546001600160a01b0316803b156118f057835f604492819583956349076b8360e11b855260018060a01b0316600485015260248401525af1801561257657612568575080f35b61257491505f90612618565b005b6040513d5f823e3d90fd5b6321c4e35760e21b5f5260045ffd5b6282b42960e81b5f5260045ffd5b600435906001600160a01b03821682036118f057565b9181601f840112156118f0578235916001600160401b0383116118f057602083818601950101116118f057565b346118f0575f3660031901126118f057602060405160c88152f35b346118f0575f3660031901126118f05760206040516103e88152f35b90601f801991011681019081106001600160401b0382111761263957604052565b634e487b7160e01b5f52604160045260245ffd5b908060209392818452848401375f828201840152601f01601f1916010190565b356001600160e01b0319811692919060048210612688575050565b6001600160e01b031960049290920360031b82901b16169150565b908160209103126118f057516001600160a01b03811681036118f05790565b908160209103126118f0575180151581036118f05790565b908160209103126118f057516001600160601b03811681036118f05790565b602060409281835280519182918282860152018484015e5f828201840152601f01601f1916010190565b811561272d570490565b634e487b7160e01b5f52601260045260245ffd5b3d1561277a573d906001600160401b038211612639576040519161276f601f8201601f191660200184612618565b82523d5f602084013e565b606090565b8181029291811591840414171561279257565b634e487b7160e01b5f52601160045260245ffd5b9190820180921161279257565b6127d2600f546127106127cb600e546010549061277f565b04906127a6565b90565b6127d2600b546127106127cb600a54600c549061277f565b90600481106128e0576001600160e01b0319612809828461266d565b166358c9542560e11b811480156129dd575b80156129cd575b80156129bd575b80156129ad575b801561299d575b801561298d575b61298857634796629160e01b8114908115612977575b5061286857631cc6a69960e11b5f5260045ffd5b806004116118f057604090820182900360031901126118f0576004013563ffffffff60e01b81168091036118f0576370897b2360e01b8114908115612966575b8115612955575b8115612944575b8115612933575b8115612922575b8115612911575b8115612900575b81156128ef575b506128e057565b631cc6a69960e11b5f5260045ffd5b6321c725e760e21b1490505f6128d9565b63026df86760e11b811491506128d2565b6318435a0560e31b811491506128cb565b63059633f360e31b811491506128c4565b63165c650960e31b811491506128bd565b6327eab91960e21b811491506128b6565b637f2b711960e11b811491506128af565b63352f8d5160e11b811491506128a8565b635c1a1a4f60e01b1490505f612854565b505050565b50633e9d2ac760e01b811461283e565b50632438525b60e01b8114612837565b5063f6f98fd560e01b8114612830565b5063585cd34b60e01b8114612829565b506360d54d4160e01b8114612822565b50635b34b82360e01b811461281b565b6040519060a082018281106001600160401b038211176126395760409081525f808452602084018181528483018281526060860183815260808701938452935163b0b423d760e01b81529193929091869160a0826004817f00000000000000000000000000000000000000000000000000000000000000006001600160a01b03165afa918215612576575f915f915f915f915f96612ac4575b50859052875285528652825215612ab557612ab293612aa89151905190612b18565b5051905190613679565b50565b6358d620b360e01b5f5260045ffd5b9450945050505060a0813d60a011612b10575b81612ae460a09383612618565b810103126118f0578051602082015191604081015191608060608301519201519093929190945f612a86565b3d9150612ad7565b66470de4df82000081118015612b66575b8015612b5f575b612ab5575f91156001171561279257612710612b4d9204906127a6565b6706f05b59d3b200008111612ab55790565b505f612b30565b506103e88211612b29565b909166470de4df82000083118015612bba575b8015612ba9575b612ab5576127cb61271091612ba384612b4d966127a6565b9361277f565b506706f05b59d3b200008211612b8b565b506103e88111612b84565b67060e466a525a2e8b81118015613238575b612ab557612be36129ed565b9182515f612bf8602086019283519086612b71565b6040860193845195612c116060890197885190846136d1565b93600e5494612c26600f546010549088612b71565b90600a5495612c3b600b54600c5490896136d1565b9260808d0198895160015414988991829a61322e575b5081613224575b5061321557612c656132a1565b5050818103612fee575b828403612d49575b80612d35575050825b60115581612d1a5750505b600d558751600f5560208801516010556040880151600b556060880151600c556080880151600155600e55600a5515612cc6575b5050505050565b5193519051915192516040805192835260208301939093529181019290925260608201527f20e7b6b49772ff84b6909b3c7404d2d6856b17d0575c387300196aefe47c0c4a90608090a25f80808080612cbf565b612d309250612d2b90600d5461277f565b612723565b612c8b565b612d2b612d449260115461277f565b612c80565b6007546040516373c558a760e11b8152637f2b711960e11b60048201526001600160a01b0390911690602081602481855afa908115612ebd578791612fbc575b5015801590612f65575b8015612f09575b612efa576301e13380840490604051637f2b711960e11b602082015282602482015260248152612dcb604482612618565b813b15612ef657612df58892839260405194858094819363ef7fa71b60e01b8352600483016126f9565b03925af18015612ebd57908791612ee1575b50506007546001600160a01b0316803b156116c457868091602460405180948193637f2b711960e11b83528760048401525af18015612ebd57908791612ec8575b505060075460405163537bfaeb60e11b815290602090829060049082906001600160a01b03165afa908115612ebd57906001600160601b03918891612e9e575b501614612c7757639f0cab4560e01b8552600485fd5b612eb7915060203d6020116114d3576114c58183612618565b5f612e88565b6040513d89823e3d90fd5b81612ed291612618565b612edd57855f612e48565b8580fd5b81612eeb91612618565b612edd57855f612e07565b8780fd5b639f0cab4560e01b8652600486fd5b506040516306d9a30160e41b8152602081600481855afa908115612ebd578791612f46575b506009546001600160a01b0391821691161415612d9a565b612f5f915060203d602011611408576113fa8183612618565b5f612f2e565b5060405163391c2e2f60e21b8152637f2b711960e11b6004820152602081602481855afa908115612ebd578791612f9d575b50612d93565b612fb6915060203d602011611775576117678183612618565b5f612f97565b90506020813d602011612fe6575b81612fd760209383612618565b810103126118f057515f612d89565b3d9150612fca565b6007546040516373c558a760e11b81526370897b2360e01b60048201526001600160a01b0390911690602081602481855afa908115612576575f916131e3575b501580159061318c575b61317d576040516370897b2360e01b60208201526024808201859052815290613062604483612618565b803b156118f05760405163ef7fa71b60e01b8152915f91839182908490829061308e90600483016126f9565b03925af1801561257657613168575b506007546001600160a01b0316803b15612edd578580916024604051809481936370897b2360e01b83528860048401525af180156116b957908691613153575b50506007546040516343bc43c160e11b815290602090829060049082906001600160a01b03165afa9081156116b95783916001600160601b03918891613134575b501614612c6f57639f0cab4560e01b8552600485fd5b61314d915060203d6020116114d3576114c58183612618565b5f61311e565b8161315d91612618565b6115f857845f6130dd565b6131759195505f90612618565b5f935f61309d565b639f0cab4560e01b5f5260045ffd5b5060405163391c2e2f60e21b81526370897b2360e01b6004820152602081602481855afa908115612576575f916131c4575b50613038565b6131dd915060203d602011611775576117678183612618565b5f6131be565b90506020813d60201161320d575b816131fe60209383612618565b810103126118f057515f61302e565b3d91506131f1565b50505050505050505050505050565b905087145f612c58565b881491505f612c51565b50669969a2857b97458211612bd7565b6007546040515f9384936001600160a01b03909316928491839181908337810182815203925af1613277612741565b90156132805750565b60405163ac8040f160e01b815290819061329d90600483016126f9565b0390fd5b6007545f91906001600160a01b0316803b156118f0575f809160046040518094819363a6afed9560e01b83525af1801561257657613664575b506007546008546040516370a0823160e01b81526001600160a01b0391821660048201819052919092169391602081602481885afa801561140f578390613630575b6133459150613333600e54600f5460105491612b71565b61333b6127b3565b9060115492613728565b6011556009546040516370a0823160e01b81526001600160a01b0390911660048201529095602090829060249082905afa80156114da5784906135fc575b6133ac915061339a600a54600b54600c54916136d1565b6133a26127d5565b90600d5492613728565b600d559390928261358d575b5085613516575b8261349f575b8361342c575b506127d29291613426917ff7576d8c2653e9d07af5ef229acf59b339e327d4e0eaddb4a96615534cf148f86040518061341e87868c87859094939260609260808301968352602083015260408201520152565b0390a16127a6565b936127a6565b6009546006546001600160a01b039182169116813b156104b05760405163ed4e9a4160e01b81526001600160a01b03919091166004820152602481018690529082908290604490829084905af180156104b45761348a575b506133cb565b613495828092612618565b6102ef5780613484565b6009546005546001600160a01b039182169116813b156104b05760405163ed4e9a4160e01b81526001600160a01b03919091166004820152602481018590529082908290604490829084905af180156104b457908291613501575b50506133c5565b8161350b91612618565b6102ef57805f6134fa565b6008546006546001600160a01b039182169116813b156104b05760405163ed4e9a4160e01b81526001600160a01b03919091166004820152602481018890529082908290604490829084905af180156104b457908291613578575b50506133bf565b8161358291612618565b6102ef57805f613571565b6005546001600160a01b0316813b156104b05760405163ed4e9a4160e01b81526001600160a01b03919091166004820152602481018490529082908290604490829084905af180156104b4579082916135e7575b506133b8565b816135f191612618565b6102ef57805f6135e1565b506020813d602011613628575b8161361660209383612618565b810103126118f0576133ac9051613383565b3d9150613609565b506020813d60201161365c575b8161364a60209383612618565b810103126118f057613345905161331c565b3d915061363d565b6136719192505f90612618565b5f905f6132da565b6608e1bc9bf04000811180156136c6575b80156136bf575b612ab5575f911560011715612792576127106136ae9204906127a6565b66b1a2bc2ec500008111612ab55790565b505f613691565b506103e8821161368a565b90916608e1bc9bf0400083118015613713575b8015613703575b612ab5576127cb61271091612ba3846136ae966127a6565b5066b1a2bc2ec5000082116136eb565b506103e881116136e4565b811561272d570690565b919392821561379757811561378c579061377861376861375d61377e9461375889613753878a61371e565b61277f565b6127a6565b966137538487612723565b6137728388612723565b906127a6565b9461371e565b908381039081116127925791565b505091505f91905f90565b92935050505f915f919056fe60c03461009957601f6102f438819003918201601f19168301916001600160401b0383118484101761009d5780849260209460405283398101031261009957516001600160a01b0381169081900361009957801561008a576080523360a05260405161024290816100b282396080518181816052015261013f015260a051818181609a015260f10152f35b63e6c4247b60e01b5f5260045ffd5b5f80fd5b634e487b7160e01b5f52604160045260245ffdfe6080806040526004361015610012575f80fd5b5f3560e01c908163ed4e9a41146100c957508063f77c4791146100855763fbfa77cf1461003d575f80fd5b34610081575f366003190112610081576040517f00000000000000000000000000000000000000000000000000000000000000006001600160a01b03168152602090f35b5f80fd5b34610081575f366003190112610081576040517f00000000000000000000000000000000000000000000000000000000000000006001600160a01b03168152602090f35b34610081576040366003190112610081576004356001600160a01b03811690819003610081577f00000000000000000000000000000000000000000000000000000000000000006001600160a01b031633036101fe5763a9059cbb60e01b8252600482015260248035908201526020816044815f7f00000000000000000000000000000000000000000000000000000000000000006001600160a01b03165af19081156101f3575f9161018e575b501561017f57005b6312171d8360e31b5f5260045ffd5b905060203d6020116101ec575b601f8101601f1916820167ffffffffffffffff8111838210176101d857602091839160405281010312610081575180151581036100815781610177565b634e487b7160e01b5f52604160045260245ffd5b503d61019b565b6040513d5f823e3d90fd5b6282b42960e81b5f5260045ffdfea264697066735822122089e2eb76204ad42de61b90ae33fbb0d7e14470b3b1469d9d4ba43db8df66424964736f6c634300081c0033a26469706673582212207cae38c01129f61552ec4370d98b6f7446ec6ec7a737e22231484b77faee79ec64736f6c634300081c0033';\n\nconst tokens=IS_ETH?[['WETH','0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'],['USDC','0xA0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'],['USDT','0xdAC17F958D2ee523a2206206994597C13D831ec7'],['DAI','0x6B175474E89094C44Da98b954EedeAC495271d0F'],['wstETH','0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0']]:[['WFRAX','0xFc00000000000000000000000000000000000002'],['frxUSD','0xfc00000000000000000000000000000000000001'],['sfrxUSD','0xfc00000000000000000000000000000000000008']];\nconst zero='0x0000000000000000000000000000000000000000';\nconst $=id=>document.getElementById(id),ok=a=>/^0x[0-9a-f]{40}$/i.test(a||'')&&a.toLowerCase()!==zero;\nconst esc=v=>String(v??'').replace(/[&<>\"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;',\"'\":'&#39;'}[c]));\nconst short=a=>a?a.slice(0,6)+'…'+a.slice(-4):'Not connected';\nlet wallet='',loading=false,notice='',err='',selected=IS_ETH?1:0,custom='',ownerMode='wallet',owner='',name=IS_ETH?'CurveYield USDC Vault':'CurveYield WFRAX Vault',symbol=IS_ETH?'cyvUSDC':'cyvWFRAX',operatorFeePercent='0',details=null;const LFACT=IS_ETH?zero:'0x3d36d5a098881e34d391b01032126c1ee802b31c';let lm=[],lBusy=false,lErr='',lDone=false,lProtocol='all',lSort='tvl',lChoice='',lAdapter=null,lCap='10000',lPct='25',lAmount='1000',lWorking=false,lPage=0,lCursor='',lHasMore=false,lActiveAsset='';\n\nconst DEAD='0x000000000000000000000000000000000000dEaD';\nlet deadState=null,deadBusy=false,deadTx='';\nconst bign=x=>BigInt(String(x));\nfunction deadShares(decimals){const n=10n**BigInt(6+Math.max(0,18-decimals));return n>1000000000n?n:1000000000n;}\nfunction tokenAmount(x,decimals){const unit=10n**BigInt(decimals),n=bign(x),frac=(n%unit).toString().padStart(decimals,'0').replace(/0+$/,'');return (n/unit).toString()+(frac?'.'+frac:'');}\nfunction deadPanel(){\n const d=deadState;\n let body=!window.ethereum?'<p class=\"v-hint\">Connect a MetaMask or Rabby wallet on Fraxtal to check the exact amount and enable the deposit button.</p>':'<p class=\"v-hint\">Checking vault shares and deposit token amounts…</p>';\n if(d?.status==='done')body='<p class=\"v-good\">✓ Required shares are held by 0x…dEaD.</p><p class=\"v-hint\">Balance: '+esc(String(d.burned))+' shares. This confirms the share balance, not their original mint ordering.</p>';\n if(d?.status==='blocked')body='<p class=\"v-bad\">This vault already issued shares without the required dead deposit. The safe first-deposit window has passed and no mint will be sent.</p>';\n if(d?.status==='error')body='<p class=\"v-bad\">'+esc(d.message)+'</p><button id=\"dead-retry\" class=\"v-secondary\">Check again</button>';\n if(d?.status==='ready'){\n const cost=tokenAmount(d.cost,d.decimals);\n body='<div class=\"v-line\"><span>Tokens locked permanently</span><b>'+esc(cost)+' '+esc(d.symbol)+'</b></div><div class=\"v-line\"><span>Shares sent to 0x…dEaD</span><b>'+esc(String(d.target))+'</b></div><div class=\"v-line\"><span>Your token balance</span><b>'+esc(wallet?tokenAmount(d.balance,d.decimals)+' '+d.symbol:'Connect your wallet')+'</b></div><p class=\"v-hint\">If needed, approve exactly this token amount first. The next wallet confirmation permanently mints the shares.</p><button id=\"dead-action\" class=\"action-primary\" '+(deadBusy||wallet&&d.balance<d.cost?'disabled':'')+'>'+(deadBusy?'Processing…':!wallet?'Connect Wallet':d.balance<d.cost?'Insufficient '+esc(d.symbol):'Make permanent dead deposit')+'</button>';\n }\n return '<section class=\"v-dead\"><span class=\"create-eyebrow\">REQUIRED FIRST FUNDING STEP</span><h3>Protect your vault</h3><p class=\"v-hint\">A permanent first deposit protects depositors from ERC-4626 share inflation attacks.</p>'+body+(deadTx?'<p class=\"v-hint\">Confirmed: <a href=\"https://fraxscan.com/tx/'+esc(deadTx)+'\" target=\"_blank\" rel=\"noopener\">'+esc(deadTx.slice(0,17))+'… ↗</a></p>':'')+'<a href=\"https://docs.morpho.org/curate/tutorials-v2/dead-deposit/\" target=\"_blank\" rel=\"noopener\">Official Morpho dead-deposit guide ↗</a></section>';\n}\nasync function loadDead(){\n if(!vault||!details?.asset||!window.ethereum||deadBusy)return;\n try{\n const chain=await window.ethereum.request({method:'eth_chainId'});\n if(parseInt(chain,16)!==CH_ID)throw Error('Switch to '+NETWORK+' to check vault status.');\n const asset=details.asset,decimals=Number(await call(asset,'decimals() view returns (uint8)'));\n if(!Number.isInteger(decimals)||decimals<0||decimals>36)throw Error('Unsupported token decimals; manual review required.');\n const target=deadShares(decimals);\n const [s,b,c,sy,bal]=await Promise.all([\n call(vault,'totalSupply() view returns (uint256)'),\n call(vault,'balanceOf(address) view returns (uint256)',[DEAD]),\n call(vault,'previewMint(uint256) view returns (uint256)',[target]).catch(()=>null),\n call(asset,'symbol() view returns (string)').catch(()=>tokens.find(t=>t[1].toLowerCase()===asset.toLowerCase())?.[0]||'tokens'),\n wallet?call(asset,'balanceOf(address) view returns (uint256)',[wallet]):Promise.resolve(0n)\n ]);\n const supply=bign(s),burned=bign(b),cost=c==null?0n:bign(c);\n const status=burned>=target?'done':supply!==0n?'blocked':cost<=0n?'error':'ready';\n deadState={status,asset,decimals,target,burned,cost,balance:bign(bal),symbol:String(sy),message:'Mint cost is unavailable or zero.'};\n }catch(e){deadState={status:'error',message:e?.message||String(e)};}\n render();\n}\nasync function makeDead(){\n if(deadBusy)return;\n try{\n await connect();await loadDead();\n const d=deadState;\n if(!d||d.status!=='ready')throw Error('Vault is not eligible for its initial dead deposit.');\n if(d.balance<d.cost)throw Error('Insufficient '+d.symbol+' balance: '+tokenAmount(d.cost,d.decimals)+' required.');\n if(!window.confirm('Permanently lock '+tokenAmount(d.cost,d.decimals)+' '+d.symbol+' in 0x…dEaD?\\n\\nThis cannot be reversed or withdrawn. Your wallet may request token approval and a permanent mint.'))return;\n deadBusy=true;render();\n if(bign(await call(vault,'totalSupply() view returns (uint256)'))!==0n)throw Error('Vault no longer empty. Mint cancelled.');\n if(bign(await call(vault,'balanceOf(address) view returns (uint256)',[DEAD]))!==0n)throw Error('Existing burn shares detected. Refresh before minting.');\n if(bign(await call(vault,'previewMint(uint256) view returns (uint256)',[d.target]))!==d.cost)throw Error('Mint quote changed. Refresh to review the new cost.');\n let allowance=bign(await call(d.asset,'allowance(address,address) view returns (uint256)',[wallet,vault]));\n if(allowance<d.cost){\n  if(allowance>0n)await signed(d.asset,'approve(address,uint256) returns (bool)',[vault,0n],'reset token approval');\n  await signed(d.asset,'approve(address,uint256) returns (bool)',[vault,d.cost],'approve dead deposit');\n  allowance=bign(await call(d.asset,'allowance(address,address) view returns (uint256)',[wallet,vault]));\n  if(allowance<d.cost)throw Error('Token approval not confirmed. Mint was not submitted.');\n }\n if(bign(await call(vault,'totalSupply() view returns (uint256)'))!==0n)throw Error('Vault already has shares: mint cancelled.');\n if(bign(await call(vault,'previewMint(uint256) view returns (uint256)',[d.target]))!==d.cost)throw Error('Price changed after approval. Review again.');\n const hash=await signed(vault,'mint(uint256,address) returns (uint256)',[d.target,DEAD],'permanent initial mint');\n const finalBalance=bign(await call(vault,'balanceOf(address) view returns (uint256)',[DEAD]));\n if(finalBalance<d.target)throw Error('Mint confirmed, but burn address share balance verification failed. Inspect '+hash);\n deadTx=hash;info('Permanent dead deposit verified on-chain. Continue setup.');\n }catch(e){info(e?.message||String(e),true);}\n finally{deadBusy=false;await loadDead();}\n}\n\nconst path=location.pathname.split('/').filter(Boolean),vault=path[1]&&ok(path[1])?path[1]:'',isCreate=path[1]==='create';\nfunction records(){try{return JSON.parse(localStorage.getItem(KEY)||'[]')}catch{return []}}\nfunction store(rec){const a=records().filter(x=>x.address.toLowerCase()!==rec.address.toLowerCase());a.unshift(rec);localStorage.setItem(KEY,JSON.stringify(a.slice(0,70)));}\nfunction abi(sig){const e=window.ethers,I=e?.Interface||e?.utils?.Interface;if(!I)throw Error('Unable to load ethers transaction encoder. Reload the page.');return new I(['function '+sig]);}\nfunction method(sig){return sig.slice(0,sig.indexOf('('));}\nasync function call(to,sig,args=[]){const a=abi(sig);const result=await window.ethereum.request({method:'eth_call',params:[{to,data:a.encodeFunctionData(method(sig),args)},'latest']});return a.decodeFunctionResult(method(sig),result)[0];}\nfunction info(t,e){notice=t;err=e?'error':'';const p=$('vault-alert');if(p){p.textContent=t;p.className='v-alert '+err;}}\nasync function connect(){if(!window.ethereum)throw Error('Install MetaMask or Rabby to connect.');const a=await window.ethereum.request({method:'eth_requestAccounts'});if(!a?.[0])throw Error('No wallet connected.');let ch=await window.ethereum.request({method:'eth_chainId'});if(parseInt(ch,16)!==CH_ID){try{await window.ethereum.request({method:'wallet_switchEthereumChain',params:[{chainId:CHAIN}]});}catch(e){if(e.code===4902)await window.ethereum.request({method:'wallet_addEthereumChain',params:[{chainId:CHAIN,chainName:NETWORK,nativeCurrency:IS_ETH?{name:'Ether',symbol:'ETH',decimals:18}:{name:'FRAX',symbol:'FRAX',decimals:18},rpcUrls:IS_ETH?['https://ethereum-rpc.publicnode.com']:['https://rpc.frax.com'],blockExplorerUrls:[EXPLORER]}]});else throw e;}}wallet=a[0];return wallet;}\nasync function signed(to,sig,args,label){await connect();info('Confirm '+label+' in your wallet…');const data=abi(sig).encodeFunctionData(method(sig),args);const hash=await window.ethereum.request({method:'eth_sendTransaction',params:[{from:wallet,to,data}]});info(label+' submitted. Waiting for the network…');for(let i=0;i<75;i++){const receipt=await window.ethereum.request({method:'eth_getTransactionReceipt',params:[hash]});if(receipt){if(parseInt(receipt.status,16)!==1)throw Error(label+' reverted: '+hash);info(label+' confirmed');return hash;}await new Promise(resolve=>setTimeout(resolve,2400));}throw Error('Transaction still pending: '+hash);}\nfunction input(label,id,value,hint){return '<label class=\"v-field\"><span>'+esc(label)+'</span><input id=\"'+id+'\" value=\"'+esc(value||'')+'\" autocomplete=\"off\" spellcheck=\"false\"/><small>'+esc(hint||'')+'</small></label>';}\nfunction shell(body){return '<div class=\"container v-page\"><div class=\"topcrumb\"><a href=\"/\">Markets</a><span>›</span><a href=\"/vaults'+SUFFIX+'\">Vaults</a><span>›</span><span>'+esc(vault?'Manage':isCreate?'Create':'Overview')+'</span></div>'\n +'<div class=\"lm-chain-tabs\"><a href=\"/vaults/create\" class=\"'+(!IS_ETH?'selected':'')+'\">Fraxtal</a><a href=\"/vaults/create?chain=ethereum\" class=\"'+(IS_ETH?'selected':'')+'\">Ethereum</a></div>'+body+'</div>';}\nfunction listPage(){const items=records().map(x=>'<a class=\"v-item\" href=\"/vaults/'+esc(x.address)+SUFFIX+'\"><b>'+esc(x.name||'Vault V2')+'</b><small>'+esc(short(x.address))+'</small><span>Manage →</span></a>').join('');return shell('<div class=\"v-heading\"><h1>CurveYield Vaults</h1><p>Create and manage Morpho Vault V2 contracts directly on '+NETWORK+'.</p><a class=\"v-primary v-action-link\" href=\"/vaults/create'+SUFFIX+'\">+ Create Vault</a></div><div class=\"create-card\"><h2>My recent vaults</h2>'+(items||'<p class=\"v-hint\">No vaults saved here yet. Create one or import a vault deployed using Morpho’s Fraxtal factory.</p>')+'<div class=\"v-import\"><input id=\"v-import-address\" placeholder=\"Paste an existing vault address\"/><button class=\"v-secondary\" id=\"v-import\">Open vault</button></div><p class=\"v-hint\">This browser list is not a complete on-chain index. You can import any factory-verified vault.</p><p id=\"vault-alert\" class=\"v-alert '+err+'\">'+esc(notice)+'</p></div>');}\nfunction legacyCreatePage(){const buttons=tokens.map((t,i)=>'<button class=\"v-token '+(selected===i?'active':'')+'\" data-token=\"'+i+'\">'+esc(t[0])+'</button>').join('')+'<button class=\"v-token '+(selected===-1?'active':'')+'\" data-token=\"-1\">Other</button>';return shell('<div class=\"v-heading\"><span class=\"create-eyebrow\">MORPHO V2 · '+NETWORK.toUpperCase()+'</span><h1>Create your vault</h1><p>Three simple choices. The important security setup comes afterward.</p></div><div class=\"create-grid\"><div class=\"create-form\"><section class=\"create-card\"><span class=\"create-eyebrow\">1 · ASSET</span><h2>What token will people deposit?</h2><div class=\"v-tokens\">'+buttons+'</div>'+(selected===-1?input('Token contract','v-custom',custom,'ERC-20 address on Fraxtal'):'<p class=\"v-hint\">Only '+esc(tokens[selected][0])+' can be deposited into this vault.</p>')+'</section><section class=\"create-card\"><span class=\"create-eyebrow\">2 · NAME</span><h2>Give your vault a name</h2>'+input('Vault name','v-name',name,'The public name depositors will see.')+input('Share symbol','v-symbol',symbol,'Short token symbol for deposit receipts.')+'</section><section class=\"create-card\"><span class=\"create-eyebrow\">3 · OWNER</span><h2>Who controls this vault?</h2><label class=\"v-option\"><input name=\"v-owner-mode\" type=\"radio\" value=\"wallet\" '+(ownerMode==='wallet'?'checked':'')+'/> My wallet (easiest)</label><label class=\"v-option\"><input name=\"v-owner-mode\" type=\"radio\" value=\"safe\" '+(ownerMode==='safe'?'checked':'')+'/> A different wallet / Safe</label>'+(ownerMode==='safe'?input('Owner address','v-owner',owner,'Must complete setup using that owner.'):'<p class=\"v-hint\">You can transfer ownership to a Safe after setup.</p>')+'</section>'+lmBrowser()+'</div><aside class=\"create-summary\"><div class=\"create-summary-card\"><span class=\"create-eyebrow\">REVIEW</span><h2>Ready to create?</h2><div class=\"v-line\"><span>Chain</span><b>'+esc(NETWORK)+'</b></div><div class=\"v-line\"><span>Deposit token</span><b>'+esc(selected===-1?'Custom':tokens[selected][0])+'</b></div><div class=\"v-line\"><span>Owner</span><b>'+esc(short(ownerMode==='wallet'?wallet:owner))+'</b></div><p class=\"v-hint\">One wallet transaction creates the contract. Setting its name and completing required protections happen in your new dashboard.</p><button id=\"v-deploy\" class=\"action-primary\" '+(loading?'disabled':'')+'>'+(loading?'Creating…':wallet?'Create Vault':'Connect Wallet')+'</button><p id=\"vault-alert\" class=\"v-alert '+err+'\">'+esc(notice)+'</p><p class=\"v-hint\">No CurveYield creation fee. '+NETWORK+' network gas applies.</p></div></aside></div>');}\n\nfunction createPage(){\n if(IS_ETH)return legacyCreatePage();\n const buttons=tokens.map((t,i)=>'<button class=\"v-token '+(selected===i?'active':'')+'\" data-token=\"'+i+'\">'+esc(t[0])+'</button>').join('')+'<button class=\"v-token '+(selected===-1?'active':'')+'\" data-token=\"-1\">Other</button>';\n return shell('<div class=\"v-heading\"><span class=\"create-eyebrow\">CURVEYIELD OMNIVAULT · FRAXTAL</span><h1>Create your protected vault</h1><p>Your wallet deploys its own immutable CurveYield controller, which creates a standard Morpho Vault V2. No shared CurveYield contract can take control of your vault.</p></div><div class=\"create-grid\"><div class=\"create-form\">'\n +'<section class=\"create-card\"><span class=\"create-eyebrow\">1 · DEPOSIT ASSET</span><h2>Choose an asset</h2><div class=\"v-tokens\">'+buttons+'</div>'+(selected===-1?input('Token contract','v-custom',custom,'Fraxtal ERC-20 address'):'<p class=\"v-hint\">Depositors supply '+esc(tokens[selected][0])+' into this vault.</p>')+'</section>'\n +'<section class=\"create-card\"><span class=\"create-eyebrow\">2 · NAME</span><h2>Name your vault</h2>'+input('Vault name','v-name',name,'Public ERC-4626 vault name')+input('Share symbol','v-symbol',symbol,'Depositor receipt symbol')+'</section>'\n +'<section class=\"create-card\"><span class=\"create-eyebrow\">3 · OPERATOR</span><h2>Manage your own strategy risk</h2><p class=\"v-hint\">Your connected wallet becomes the vault operator. Morpho owner and curator are held permanently by your new protected controller. You can propose transferring operator privileges to another wallet or Safe after creation.</p>'+input('Operator performance fee (%)','v-opfee',operatorFeePercent,'0% default; entered as a percent of recognized yield, subject to Morpho fee caps')+'</section>'\n +lmBrowser()+'</div><aside class=\"create-summary\"><div class=\"create-summary-card\"><span class=\"create-eyebrow\">REVIEW</span><h2>Protected creation</h2><div class=\"v-line\"><span>Chain</span><b>Fraxtal (252)</b></div><div class=\"v-line\"><span>Asset</span><b>'+esc(selected===-1?'Custom':tokens[selected][0])+'</b></div><div class=\"v-line\"><span>Vault operator</span><b>'+esc(short(wallet))+'</b></div><div class=\"v-line\"><span>CurveYield creation fee</span><b>1 FRAX (native)</b></div><div class=\"v-line\"><span>CurveYield treasury</span><b>'+esc(short(CY_V10_TREASURY))+'</b></div><p class=\"v-hint\">Two wallet confirmations: deploy your dedicated v10 controller, then pay its native FRAX creation fee to create your Morpho Vault V2. Additional network gas applies. If you decline the second transaction, you can resume using the already deployed controller.</p><button id=\"v-deploy\" class=\"action-primary\" '+(loading?'disabled':'')+'>'+(loading?'Processing…':wallet?'Deploy Controller & Create Vault':'Connect Wallet')+'</button><p id=\"vault-alert\" class=\"v-alert '+err+'\">'+esc(notice)+'</p><p class=\"v-hint\">Fee changes are capped and delayed 90 days. Your strategy selections and liquidity risks remain yours to manage. The initial dead deposit and adapter onboarding must still be completed.</p><a href=\"'+CY_V10_SOURCE_URL+'\" target=\"_blank\" rel=\"noopener\">Compiled CurveYield v10 controller source ↗</a></div></aside></div>');\n}\n\nfunction manager(){\n const d=details,protectedVault=!!d?.controller;\n const managerAddr=protectedVault?d.operator:d?.owner;\n const same=!!d&&!!wallet&&wallet.toLowerCase()===managerAddr?.toLowerCase();\n let rows=d?[['Vault',short(vault)],['Morpho owner',short(d.owner)],['Operator',short(d.operator||d.owner)],['Deposit token',short(d.asset)],['Name',d.name||'Not configured'],['Symbol',d.symbol||'Not configured'],['Curator',short(d.curator)],['Total assets (raw units)',d.total]].map(x=>'<div class=\"v-line\"><span>'+esc(x[0])+'</span><b>'+esc(x[1])+'</b></div>').join(''):'<p class=\"v-hint\">Loading on-chain settings…</p>';\n const edit=same?'<div class=\"v-edit\">'+input('Name','v-edit-name',d.name,'')+input('Symbol','v-edit-symbol',d.symbol,'')+'<button id=\"v-save-name\" class=\"v-secondary\">Save name & symbol</button></div>': '<p class=\"v-hint\">Connect the '+(protectedVault?'operator':'owner')+' wallet to edit configuration.</p>';\n const legacyControls=same&&!protectedVault?'<button id=\"v-finish\" class=\"v-primary\">Finish basic setup</button><div class=\"v-edit\">'+input('Curator address','v-curator',d.curator===zero?wallet:d.curator,'Wallet or Safe for vault risk settings')+'<button id=\"v-save-curator\" class=\"v-secondary\">Assign curator</button></div>':'';\n const fees=same&&protectedVault?'<div class=\"v-edit\"><h3>Operator fees</h3>'+input('Performance fee (%)','v-performance-percent',pctFromWad(d.operatorFeeWad),'% of recognized yield')+input('Annual management fee (%)','v-management-percent',pctFromWad(d.operatorManagementFeeAnnualWad),'% of vault TVL per year')+'<button id=\"v-save-operator-fees\" class=\"v-primary\">Save operator fees</button><p class=\"v-hint\">Changes settle old fee shares first; total fees cannot exceed Morpho native limits.</p></div><div class=\"v-edit\"><h3>Operator transfer</h3>'+input('New operator wallet or Safe','v-next-operator','', 'The new operator must later call acceptOperator() via their wallet or Safe.')+'<button id=\"v-propose-operator\" class=\"v-secondary\">Propose operator transfer</button></div>':'';\n const policy=protectedVault&&ok(d.policyMaster)?\n '<div class=\"v-edit\"><h3>Master fee-policy synchronization</h3>'+\n '<p class=\"v-hint\">Master: <a href=\"'+EXPLORER+'/address/'+esc(d.policyMaster)+'\" target=\"_blank\" rel=\"noopener\">'+esc(short(d.policyMaster))+' ↗</a></p>'+\n '<div class=\"v-line\"><span>Applied version</span><b>'+esc(String(d.appliedPolicyVersion??'—'))+'</b></div>'+\n '<p class=\"v-hint\">'+(d.policyNeedsSync===true?'New master fee rates are available. Anyone can synchronize this vault.':d.policyNeedsSync===false?'This vault has applied the current master fee rates.':'Synchronization status could not be read. Verify before submitting.')+'</p>'+\n '<button id=\"v-sync-policy\" class=\"v-secondary\" '+(d.policyNeedsSync===false?'disabled':'')+'>Synchronize master fees</button></div>':'';\n const note=protectedVault?'<p class=\"v-good\">✓ Protected controller '+(ok(d.policyMaster)?'v10, linked to the on-chain CurveYield master fee policy.':'(legacy version, independently configured).')+'</p><p class=\"v-hint\">Protected controller: <a href=\"'+EXPLORER+'/address/'+esc(d.controller)+'\" target=\"_blank\" rel=\"noopener\">'+esc(d.controller)+'</a></p>'+policy:'';\n return shell('<div class=\"v-heading\"><span class=\"create-eyebrow\">'+NETWORK.toUpperCase()+' · VAULT V2</span><h1>'+esc(d?.name||'Manage vault')+'</h1><p>Complete first-deposit protection and configure supported market adapters before accepting deposits.</p><a href=\"'+EXPLORER+'/address/'+esc(vault)+'\" target=\"_blank\" rel=\"noopener\">View vault on explorer ↗</a></div><div class=\"create-grid\"><div class=\"create-form\"><div class=\"create-card\"><h2>Vault details</h2>'+rows+note+'</div><div class=\"create-card\"><h2>Complete setup</h2>'+deadPanel()+'<div class=\"v-steps\"><div class=\"'+(deadState?.status==='done'?'complete':'')+'\">1. Permanent dead deposit '+(deadState?.status==='done'?'✓':'')+'</div><div class=\"'+(d?.name&&d?.symbol?'complete':'')+'\">2. Name and symbol '+(d?.name&&d?.symbol?'✓':'')+'</div><div class=\"'+(d?.curator&&d.curator!==zero?'complete':'')+'\">3. '+(protectedVault?'Protected curator installed':'Assign curator')+'</div><div>4. Configure eligible adapters and risk limits</div><div>5. Review on-chain roles and restrictions</div></div>'+edit+legacyControls+fees+'</div>'+lmBrowser()+'</div><aside class=\"create-summary\"><div class=\"create-summary-card\"><span class=\"create-eyebrow\">SETUP IN PROGRESS</span><h2>Review before deposits</h2><p class=\"v-hint\">Creating the vault does not make it operational. Complete the permanent dead deposit and verify the adapters and their liquidity risks.</p><a href=\"https://docs.morpho.org/curate/tutorials-v2/checklist/\" target=\"_blank\" rel=\"noopener\">Morpho deployment checklist ↗</a><p id=\"vault-alert\" class=\"v-alert '+err+'\">'+esc(notice)+'</p></div></aside></div>');\n}\n\nfunction lmKey(x){return x.marketId?String(x.marketId).toLowerCase():(x.id||x.protocol+':'+String(x.address||x.poolId||'')+':'+String(x.hubAssetId??x.index??''))}\nfunction lmPick(){return lm.find(x=>lmKey(x)===lChoice&&lmMatch(x)&&(lProtocol==='all'||x.protocol===lProtocol||(lProtocol==='Liquity'&&x.protocol.startsWith('Liquity'))))}\nfunction lmAsset(){const a=vault?details?.asset:selected===-1?custom:tokens[selected]?.[1];return typeof a==='string'&&/^0x[0-9a-fA-F]{40}$/.test(a)&&a.toLowerCase()!==zero.toLowerCase()?a.toLowerCase():null}\nfunction lmMatch(m){const a=lmAsset();return !!a&&(m.asset?.toLowerCase()===a||\n m.lpComposition?.singleCoinCandidates?.some(c=>c.address===a)||\n m.lpComposition?.underlyingCandidates?.some(c=>c.address===a))}\nfunction lmIsConversion(m){const a=lmAsset();return !!a&&m.asset?.toLowerCase()!==a&&lmMatch(m)}\nfunction lmCompose(m){\n const c=m.lpComposition;if(!c)return '';\n const coins=Array.isArray(c.coins)?c.coins:[];\n const body=coins.map(z=>esc(z.symbol||lmShort(z.address))+(z.poolSharePct!=null?' '+lmNum(z.poolSharePct,1)+'%':'')).join(' · ');\n return '<small class=\"v-hint\">LP '+esc(c.lpSymbol||m.assetSymbol||'')+' ('+esc(lmShort(c.lpToken))+') · '+esc(body||c.symbolicComponents?.join(' + ')||'unresolved')+'</small>';\n}\nfunction lmNum(v,d=2){return v==null||!Number.isFinite(Number(v))?'—':Number(v).toLocaleString(undefined,{maximumFractionDigits:d})}\nfunction lmShort(a){return a&&a.length===42?a.slice(0,8)+'…'+a.slice(-5):'—'}\nfunction lmBrowser(){\n const asset=lmAsset(),subset=lm.filter(x=>lmMatch(x)&&(lProtocol==='all'||x.protocol===lProtocol||(lProtocol==='Liquity'&&x.protocol.startsWith('Liquity'))));\n const priority={'CurveLend V2':0,'CurveLend V1':1,'Morpho Blue':2,'Fraxlend':3,'Euler EVK':4,'Aave V3':5,'Aave V4':6,'Compound III':7,'Liquity V2 (legacy BOLD SP)':8};\n subset.sort((a,b)=>lSort==='priority'?(priority[a.protocol]??99)-(priority[b.protocol]??99):lSort==='tvl'?(b.tvlUsdEstimate??-1)-(a.tvlUsdEstimate??-1):lSort==='asset'?String(a.assetSymbol||a.asset).localeCompare(String(b.assetSymbol||b.asset)):(b.lendApr??-1)-(a.lendApr??-1));\n const rows=subset.map(x=>'<div class=\"lm-item\"><div><strong>'+esc(x.protocol)+' · '+esc(x.assetSymbol||lmShort(x.asset))+'</strong><small>'+esc(x.marketName||('Collateral '+(x.collateralSymbol||lmShort(x.collateral))))+'</small>'+(lmIsConversion(x)?'<small>Via LP conversion candidate · adapter quote required</small>':'<small>Direct deposit asset</small>')+lmCompose(x)+'</div><div><small>'+esc(x.rateType||'Lending APR')+'</small><b>'+(x.lendApr==null?'—':lmNum(x.lendApr)+'%')+'</b>'+(x.rateWarning?'<small class=\"negative tiny\">Extreme API yield</small>':'')+'</div><div><small>Supplied TVL'+(x.tvlUsdEstimate!=null?' (USD est.)':' (tokens)')+'</small><b>'+(x.tvlUsdEstimate!=null?'$'+lmNum(x.tvlUsdEstimate,0):lmNum(x.tvlAssets)+' '+esc(x.assetSymbol||''))+'</b></div><button class=\"v-secondary\" data-lm=\"'+esc(lmKey(x))+'\">Select</button></div>').join('');\n const x=lmPick(),tokenName=asset?(tokens.find(t=>t[1].toLowerCase()===asset)?.[0]||lm.find(m=>m.asset?.toLowerCase()===asset)?.assetSymbol||'Custom ERC-20'):null;\n return '<section class=\"create-card lm-panel\"><span class=\"create-eyebrow\">'+NETWORK.toUpperCase()+' LENDING MARKETS</span><h2>Market discovery & allocations</h2>'\n +'<div class=\"lm-deposit-asset\"><span class=\"create-eyebrow\">1 · REQUIRED LENDING ASSET</span><strong>'+(asset?esc(tokenName)+' · '+esc(lmShort(asset)):'Select or load the vault deposit asset first')+'</strong><small>Direct-token markets and LP vaults whose constituent token matches your deposit asset are shown. LP conversion routes require an adapter quote and compatible pool implementation.</small></div>'\n +'<h3>2 · Choose a compatible lending market</h3>'\n +'<p class=\"v-hint\">Discover '+(IS_ETH?'Aave, Morpho, SparkLend, Compound, Fluid, Maple, Yearn, IPOR, Beefy, Convex, Stake DAO, CurveLend and Fraxlend':'CurveLend and Fraxlend')+' markets from live registries and indexed on-chain data. Lending APRs are variable; USD TVL is estimated only when a price reference exists.</p>'\n +'<div class=\"lm-filters\"><select id=\"lm-protocol\"><option value=\"all\">All markets</option>'+(IS_ETH?['Aave V2','Aave V3','Aave V4','Morpho Blue','Morpho Vault V1','Morpho Vault V2','SparkLend','Compound II','Compound III','Fluid Lending','Fluid Smart Lending','Fluid Vaults','Maple Finance','Maple Syrup','Yearn V2','Yearn V3','Yearn Vaults','IPOR Fusion','Beefy Vaults','Convex Finance','Stake DAO','Stake DAO Lockers','CurveLend V1','CurveLend V2','Fraxlend'].map(n=>'<option value=\"'+esc(n)+'\" '+(lProtocol===n?'selected':'')+'>'+esc(n)+'</option>').join(''):'<option value=\"CurveLend\" '+(lProtocol==='CurveLend'?'selected':'')+'>CurveLend</option><option value=\"Fraxlend\" '+(lProtocol==='Fraxlend'?'selected':'')+'>Fraxlend</option>')+'</select>'\n +'<select id=\"lm-sort\">'+(IS_ETH?'<option value=\"asset\" '+(lSort==='asset'?'selected':'')+'>Deposit asset</option>':'')+'<option value=\"rate\" '+(lSort==='rate'?'selected':'')+'>Highest yield</option><option value=\"tvl\" '+(lSort==='tvl'?'selected':'')+'>Highest TVL (default)</option></select>'\n +'<button class=\"v-secondary\" id=\"lm-refresh\">Refresh</button></div>'\n +(!asset?'<p class=\"v-hint\">No markets shown until the vault deposit token is known.</p>':lBusy?'<p class=\"v-hint\">Loading cached public APIs…</p>':lErr?'<p class=\"v-bad\">'+esc(lErr)+'</p>':'<p class=\"v-hint\">'+subset.length+' '+esc(tokenName)+' lending markets match your vault ('+lm.length+' markets scanned).</p>')\n +'<div class=\"lm-results\">'+(rows||(asset?'<p class=\"v-hint\">No matching markets from available sources. Check protocol status above.</p>':'<p class=\"v-hint\">Select the vault deposit asset to discover matching markets.</p>'))+'</div>'\n +(IS_ETH&&lHasMore?'<button class=\"v-secondary\" id=\"lm-more\" type=\"button\">Load additional markets</button>':'')\n +(x?lmDetails(x):'')+'<p class=\"v-hint\">Rates may be APR or APY and can change without notice. TVL may be partial or estimated. Ethereum allocations remain disabled until protocol integrations are reviewed and deployed.</p></section>';\n}\nfunction lmDetails(m){\n let s='<div class=\"lm-detail\"><h3>'+esc(m.protocol)+' '+esc(m.assetSymbol||'market')+'</h3><p><a target=\"_blank\" rel=\"noopener\" href=\"'+EXPLORER+'/address/'+esc(m.address)+'\">Market contract ↗</a></p>'+(m.rateSource?'<p class=\"v-hint\">'+esc(m.rateType||'Rate')+' · '+esc(m.rateSource)+'</p>':'');\n if(m.lpComposition)s+='<p class=\"v-hint\">LP components: '+esc((m.lpComposition.coins||[]).map(c=>c.symbol+(c.poolSharePct!=null?' '+lmNum(c.poolSharePct,1)+'%':'')).join(' · '))+'</p>'+\n (m.lpComposition.poolAddress?'<p><a target=\"_blank\" rel=\"noopener\" href=\"'+EXPLORER+'/address/'+esc(m.lpComposition.poolAddress)+'\">LP pool contract ↗</a></p>':'');\n if(lmIsConversion(m)){\n  const c=m.conversionRoute||{},coind=c.poolCoinIndex;\n  s+='<p class=\"v-hint\">Single-token → LP route candidate: '+esc(lmShort(lmAsset()))+' → '+esc(m.assetSymbol||lmShort(m.asset))+\n   '. Pool coin index: '+esc(coind!=null?coind:'nested/unknown')+\n   '. Pool: '+esc(lmShort(c.poolAddress))+\n   '. '+(c.boosterPid!=null?'Convex Booster PID: '+esc(c.boosterPid)+'. ':'')+\n   'Adapter quote, deposit/withdraw route and slippage must be verified before allocation.</p>';\n }\n if(!vault)return s+'<p class=\"v-hint\">Create your vault before configuring this market. Ethereum deposits to external markets require a verified adapter and conversion route.</p></div>';\n if(!details)return s+'<p class=\"v-hint\">Connect a wallet to load vault settings.</p></div>';\n if(!lmMatch(m))return s+'<p class=\"v-bad\">Incompatible vault deposit token: this direct adapter cannot perform token swaps.</p></div>';\n if(IS_ETH)return s+'<p class=\"v-hint\">Ethereum discovery and LP conversion candidates are available. No swap or LP mint is executed from this page; adapter route and on-chain quote must be verified before allocation.</p></div>';\n if(!lAdapter)return s+'<p class=\"v-hint\">Loading this market’s adapter configuration…</p></div>';\n if(lAdapter.address===zero)return s+'<p class=\"v-hint\">No adapter deployed for this vault and market.</p><button class=\"v-primary\" data-lm-action=\"deploy\">Deploy per-market adapter</button></div>';\n const a=lAdapter,curator=wallet&&(details.controller?details.operator:details.curator)?.toLowerCase()===wallet.toLowerCase();\n s+='<div class=\"v-line\"><span>Adapter</span><b><a href=\"'+EXPLORER+'/address/'+esc(a.address)+'\" target=\"_blank\" rel=\"noopener\">'+esc(lmShort(a.address))+' ↗</a></b></div>'\n +'<div class=\"v-line\"><span>Enabled</span><b>'+(a.enabled?'Yes':'No')+'</b></div>'\n +'<div class=\"v-line\"><span>Absolute cap (raw)</span><b>'+esc(a.abs)+'</b></div>'\n +'<div class=\"v-line\"><span>Relative cap</span><b>'+lmNum(Number(a.rel)/1e16)+'%</b></div>'\n +'<div class=\"v-line\"><span>Connected wallet is allocator</span><b>'+(a.allocator?'Yes':'No')+'</b></div>';\n if(!a.registry) s+='<p class=\"v-bad\">Adapter registry denies this address. Obtain registry authorization first.</p>';\n if(!a.enabled)s+='<p class=\"v-hint\">Curator must schedule and execute addAdapter through the vault’s timelock. '+(a.pendingAdd?'Scheduled.':'Not scheduled.')+'</p><button class=\"v-secondary\" data-lm-action=\"addSchedule\" '+(!curator||!a.registry||a.pendingAdd?'disabled':'')+'>1. Schedule enable</button> <button class=\"v-primary\" data-lm-action=\"addExecute\" '+(!curator||!a.pendingAdd||Date.now()<a.pendingAdd*1000?'disabled':'')+'>2. Execute enable</button>';\n else {\n  s+='<div class=\"lm-controls\"><h4>Risk caps</h4><label>Absolute cap ('+esc(m.assetSymbol||'tokens')+')<input id=\"lm-cap\" value=\"'+esc(lCap)+'\"></label><label>Relative cap (%)<input id=\"lm-pct\" value=\"'+esc(lPct)+'\"></label>'\n  +'<button class=\"v-secondary\" data-lm-action=\"capsSchedule\" '+(!curator?'disabled':'')+'>Schedule cap increases</button> <button class=\"v-secondary\" data-lm-action=\"capsExecute\" '+(!curator?'disabled':'')+'>Execute matured cap increases</button></div>';\n  if(!a.allocator)s+='<div class=\"lm-controls\"><h4>Allocator permission</h4><button class=\"v-secondary\" data-lm-action=\"roleSchedule\" '+(!curator?'disabled':'')+'>Schedule allocator role</button> <button class=\"v-secondary\" data-lm-action=\"roleExecute\" '+(!curator?'disabled':'')+'>Activate role</button></div>';\n  s+='<div class=\"lm-controls\"><h4>Deposits & allocations</h4><label>Amount ('+esc(m.assetSymbol||'tokens')+')<input id=\"lm-amount\" value=\"'+esc(lAmount)+'\"></label>'\n  +'<button class=\"v-secondary\" data-lm-action=\"deposit\" '+(deadState?.status!=='done'?'disabled':'')+'>Deposit into vault</button> '\n  +'<button class=\"v-primary\" data-lm-action=\"allocate\" '+(!a.allocator||!a.ready?'disabled':'')+'>Allocate to market</button> '\n  +'<button class=\"v-secondary\" data-lm-action=\"deallocate\" '+(!a.allocator?'disabled':'')+'>Deallocate</button> '\n  +'<button class=\"v-secondary\" data-lm-action=\"auto\" '+(!a.allocator||!a.ready?'disabled':'')+'>Make automatic liquidity adapter</button>'\n  +'<p class=\"v-hint\">The dead deposit must be complete before normal deposits. The vault must already hold idle assets before allocations. Withdrawals are constrained by market liquidity.</p></div>';\n }\n if(!curator)s+='<p class=\"v-hint\">Risk configuration requires the protected vault operator ('+esc(lmShort(details.operator||details.curator))+'). For Safe-controlled roles, execute via Safe.</p>';\n return s+'</div>';\n}\n\nasync function lmFetch(force=false){\n if(lBusy)return;const asset=lmAsset();\n if(!asset){lm=[];lHasMore=false;lActiveAsset='';lDone=false;render();return;}\n if(asset!==lActiveAsset||force){lm=[];lPage=0;lHasMore=false;lDone=false;lChoice='';lAdapter=null;lActiveAsset=asset;}\n if(lDone&&!force)return;\n lBusy=true;lErr='';render();\n try{\n  if(IS_ETH){\n   const q=new URLSearchParams({asset,protocol:lProtocol,compatible:'1',conversion:'1',sort:lSort==='rate'?'yield':lSort,limit:'250',offset:String(lPage*250)});\n   const r=await fetch('/api/opportunities?'+q),d=await r.json();\n   if(!r.ok||!Array.isArray(d.opportunities))throw Error(d.error||'Cached catalog not available');\n   if(lActiveAsset!==asset)return;\n   const got=d.opportunities.filter(x=>x.chainId===1&&ok(x.asset)&&lmMatch(x));\n   const found=new Set(lm.map(lmKey));lm.push(...got.filter(x=>!found.has(lmKey(x))));\n   lHasMore=Boolean(d.hasMore);lPage++;lDone=!lHasMore;\n   if(d.partial&&d.sourceFailures?.length)lErr='Some sources unavailable: '+d.sourceFailures.map(x=>x.source).join(', ');\n  }else{\n   const r=await fetch('/api/vault-lending-markets'),d=await r.json();\n   if(!r.ok||!Array.isArray(d.opportunities))throw Error(d.error||'Fraxtal discovery unavailable');\n   lm=d.opportunities.filter(x=>x.registryVerified&&x.chainId===252&&ok(x.asset)&&ok(x.address)&&x.asset.toLowerCase()===asset);\n   lHasMore=false;lDone=true;\n  }\n }catch(e){lErr=String(e?.message||e);lHasMore=false;lDone=true}\n finally{lBusy=false;render()}\n}\n\nasync function lmRead(){\n if(!vault||!details||!lmPick()||IS_ETH)return;\n const current=lChoice;lAdapter=null;render();\n try{\n  const a=String(await call(LFACT,'adapter(address,address) view returns(address)',[vault,current]));\n  if(!ok(a)){lAdapter={address:zero};}\n  else{\n   const id=String(await call(a,'adapterId() view returns(bytes32)'));\n   const [enabled,abs,rel,allocator,registry]=await Promise.all([\n    call(vault,'isAdapter(address) view returns(bool)',[a]),\n    call(vault,'absoluteCap(bytes32) view returns(uint256)',[id]),\n    call(vault,'relativeCap(bytes32) view returns(uint256)',[id]),\n    wallet?call(vault,'isAllocator(address) view returns(bool)',[wallet]):Promise.resolve(false),\n    call(vault,'adapterRegistry() view returns(address)')\n   ]);\n   let allow=true;if(ok(String(registry)))allow=Boolean(await call(String(registry),'isInRegistry(address) view returns(bool)',[a]).catch(()=>false));\n   const calldata=abi('addAdapter(address)').encodeFunctionData('addAdapter',[a]);\n   const when=await call(vault,'executableAt(bytes) view returns(uint256)',[calldata]);\n   const A=BigInt(abs.toString()),R=BigInt(rel.toString());\n   lAdapter={address:a,id,enabled:Boolean(enabled),abs:A.toString(),rel:R.toString(),allocator:Boolean(allocator),\n     registry:allow,pendingAdd:Number(when.toString()),ready:Boolean(enabled)&&A>0n&&R>0n};\n  }\n }catch(e){lErr=e.message||String(e);}\n if(current===lChoice)render();\n}\nasync function lmDo(kind){\n const market=lmPick();\n if(lWorking||!vault||!details||!market||!lmMatch(market)||IS_ETH)return;\n lWorking=true;\n try{\n  await connect();const curator=wallet.toLowerCase()===(details.operator||details.curator).toLowerCase();\n  const requireCurator=()=>{if(!curator)throw Error('Curator permission required. Use Safe if curator is a Safe wallet.');};\n  const a=lAdapter?.address;\n  const pack=(sig,args)=>abi(sig).encodeFunctionData(method(sig),args);\n  const stage=async(sig,args,execute)=>{\n   requireCurator();\n   const data=pack(sig,args),at=BigInt((await call(vault,'executableAt(bytes) view returns(uint256)',[data])).toString());\n   if(execute){if(at===0n)throw Error('First schedule this exact curator action.');if(at*1000n>BigInt(Date.now()))throw Error('Timelock is still active.');if(details.controller)await signed(details.controller,'executeCuratorAction(bytes)',[data],'execute protected vault configuration');else await signed(vault,sig,args,'execute Vault V2 configuration');}\n   else{if(at!==0n)throw Error('This action is already scheduled.');if(details.controller)await signed(details.controller,'submitCuratorAction(bytes)',[data],'schedule protected vault configuration');else await signed(vault,'submit(bytes)',[data],'schedule Vault V2 configuration');}\n  };\n  const units=async(text)=>{\n   if(!/^\\d+(?:\\.\\d{1,18})?$/.test(text)||!(Number(text)>0))throw Error('Enter a positive amount.');\n   const d=Number((await call(market.asset,'decimals() view returns(uint8)')).toString()),E=window.ethers;\n   return (E.utils?.parseUnits??E.parseUnits)(text,d).toString();\n  };\n  if(kind==='deploy'){\n   if(ok(String(await call(LFACT,'adapter(address,address) view returns(address)',[vault,market.address]))))throw Error('Adapter already deployed.');\n   await signed(LFACT,'createAdapter(address,address,uint8) returns(address)',[vault,market.address,market.protocolId],'deploy market-specific adapter');\n  }else if(!ok(a))throw Error('Deploy this market adapter first.');\n  else if(kind==='addSchedule'||kind==='addExecute')await stage('addAdapter(address)',[a],kind==='addExecute');\n  else if(kind==='capsSchedule'||kind==='capsExecute'){\n   requireCurator();const cap=BigInt(await units(lCap)),percent=Number(lPct);\n   if(!(percent>0&&percent<=100)||!/^\\d+(?:\\.\\d{1,2})?$/.test(lPct))throw Error('Relative cap must be between 0 and 100%, at most two decimals.');\n   const E=window.ethers,rel=BigInt((E.utils?.parseUnits??E.parseUnits)(lPct,16).toString());\n   const coder=E.utils?.defaultAbiCoder??E.AbiCoder.defaultAbiCoder();\n   const idData=coder.encode(['string','address'],['this',a]);\n   const ops=[['increaseAbsoluteCap(bytes,uint256)',[idData,cap.toString()],cap>BigInt(lAdapter.abs)],\n    ['increaseRelativeCap(bytes,uint256)',[idData,rel.toString()],rel>BigInt(lAdapter.rel)]];\n   let changed=0;for(const [sig,args,need] of ops){\n    if(!need)continue;const at=BigInt((await call(vault,'executableAt(bytes) view returns(uint256)',[pack(sig,args)])).toString());\n    if(kind==='capsSchedule'&&at===0n){await stage(sig,args,false);changed++;}\n    if(kind==='capsExecute'&&at>0n&&at*1000n<=BigInt(Date.now())){await stage(sig,args,true);changed++;}\n   }\n   if(changed===0)throw Error(kind==='capsExecute'?'No matching cap increase is ready; check scheduled inputs.':'No new cap increase needed or already scheduled.');\n  }\n  else if(kind==='roleSchedule'||kind==='roleExecute')await stage('setIsAllocator(address,bool)',[wallet,true],kind==='roleExecute');\n  else if(kind==='deposit'){\n   if(deadState?.status!=='done')throw Error('The vault dead deposit must be complete first.');\n   const amount=BigInt(await units(lAmount));\n   const balance=BigInt((await call(market.asset,'balanceOf(address) view returns(uint256)',[wallet])).toString());if(balance<amount)throw Error('Insufficient asset balance.');\n   let allowance=BigInt((await call(market.asset,'allowance(address,address) view returns(uint256)',[wallet,vault])).toString());\n   if(allowance<amount){if(allowance>0n)await signed(market.asset,'approve(address,uint256) returns(bool)',[vault,0],'reset allowance');\n    await signed(market.asset,'approve(address,uint256) returns(bool)',[vault,amount.toString()],'approve vault deposit');}\n   await signed(vault,'deposit(uint256,address) returns(uint256)',[amount.toString(),wallet],'deposit into Vault V2');\n  }\n  else{\n   if(!Boolean(await call(vault,'isAllocator(address) view returns(bool)',[wallet])))throw Error('Wallet is not a Vault V2 allocator.');\n   if(kind!=='deallocate'&&!lAdapter.ready)throw Error('Adapter requires enabling and nonzero caps.');\n   if(kind==='auto'){\n    if(!window.confirm('Set this market as automatic Vault V2 liquidity adapter? Deposits will route to this market, subject to caps.'))return;\n    await signed(vault,'setLiquidityAdapterAndData(address,bytes)',[a,'0x'],'configure automatic vault allocation');\n   }else await signed(vault,kind==='allocate'?'allocate(address,bytes,uint256)':'deallocate(address,bytes,uint256)',[a,'0x',await units(lAmount)],kind+' vault assets');\n  }\n  info('Transaction confirmed on Fraxtal. Refreshing on-chain state.');\n }catch(e){info(e?.message||String(e),true);}\n finally{lWorking=false;await lmRead();if(vault)await loadDead();render();}\n}\n\nfunction render(){if(!$('page'))return;$('page').innerHTML=vault?manager():isCreate?createPage():listPage();document.title=(vault?'Manage Vault':isCreate?'Create Vault':'Vaults')+' · CurveYield';const wb=$('walletButton');if(wb){wb.onclick=async()=>{try{await connect();render();if(vault)refresh();}catch(e){info(e.message,true)}};if($('walletButtonText'))$('walletButtonText').textContent=wallet?short(wallet):'Connect Wallet';}\ndocument.querySelectorAll('[data-token]').forEach(b=>b.onclick=()=>{selected=Number(b.dataset.token);if(selected>=0){name='CurveYield '+tokens[selected][0]+' Vault';symbol='cyv'+tokens[selected][0];}lDone=false;lm=[];lChoice='';render();lmFetch(true);});\nif($('v-custom'))$('v-custom').oninput=e=>{const pos=e.target.selectionStart;custom=e.target.value.trim();lAdapter=null;lDone=false;lm=[];lChoice='';render();lmFetch(true);const inp=$('v-custom');if(inp){inp.focus();if(pos!=null)inp.setSelectionRange(pos,pos)}};\nif($('v-name'))$('v-name').oninput=e=>name=e.target.value;\nif($('v-symbol'))$('v-symbol').oninput=e=>symbol=e.target.value;\ndocument.querySelectorAll('[name=v-owner-mode]').forEach(b=>b.onchange=e=>{ownerMode=e.target.value;render()});\nif($('v-owner'))$('v-owner').oninput=e=>owner=e.target.value.trim();\nif($('v-deploy'))$('v-deploy').onclick=()=>{if(!wallet)connect().then(render).catch(e=>info(e.message,true));else deploy();};\nif($('v-opfee'))$('v-opfee').oninput=e=>operatorFeePercent=e.target.value;\nif($('v-save-operator-fees'))$('v-save-operator-fees').onclick=saveOperatorFees;\nif($('v-sync-policy'))$('v-sync-policy').onclick=syncMasterPolicy;\nif($('v-propose-operator'))$('v-propose-operator').onclick=proposeOperatorTransfer;\nif($('v-import'))$('v-import').onclick=importVault;\nif($('v-finish'))$('v-finish').onclick=finishBasics;\nif($('dead-action'))$('dead-action').onclick=makeDead;\nif($('dead-retry'))$('dead-retry').onclick=loadDead;\nif($('v-save-name'))$('v-save-name').onclick=saveName;\nif($('v-save-curator'))$('v-save-curator').onclick=saveCurator;\nif($('lm-protocol'))$('lm-protocol').onchange=e=>{lProtocol=e.target.value;if(IS_ETH)lmFetch(true);else render()};\nif($('lm-sort'))$('lm-sort').onchange=e=>{lSort=e.target.value;if(IS_ETH)lmFetch(true);else render()};\nif($('lm-refresh'))$('lm-refresh').onclick=()=>lmFetch(true);if($('lm-more'))$('lm-more').onclick=()=>lmFetch(false);\ndocument.querySelectorAll('[data-lm]').forEach(e=>e.onclick=()=>{lChoice=e.dataset.lm;lAdapter=null;render();if(vault&&!IS_ETH)lmRead()});\ndocument.querySelectorAll('[data-lm-action]').forEach(e=>e.onclick=()=>lmDo(e.dataset.lmAction));\nif($('lm-cap'))$('lm-cap').oninput=e=>lCap=e.target.value;\nif($('lm-pct'))$('lm-pct').oninput=e=>lPct=e.target.value;\nif($('lm-amount'))$('lm-amount').oninput=e=>lAmount=e.target.value;\n}\nasync function legacyDeploy(){if(loading)return;loading=true;try{const who=ownerMode==='wallet'?wallet:owner,asset=selected===-1?custom:tokens[selected][1];if(!ok(who))throw Error('Enter a valid owner wallet.');if(!ok(asset))throw Error('Enter a valid deposit token address.');if(!name.trim()||name.length>80||!symbol.trim()||symbol.length>32)throw Error('Enter a short name and share symbol.');await connect();if(ownerMode==='wallet'&&who.toLowerCase()!==wallet.toLowerCase())throw Error('Wallet changed. Please review the owner and try again.');const fcode=await window.ethereum.request({method:'eth_getCode',params:[F,'latest']});if(fcode==='0x')throw Error('Vault factory contract was not found on Fraxtal.');const code=await window.ethereum.request({method:'eth_getCode',params:[asset,'latest']});if(code==='0x')throw Error('Token contract was not found on Fraxtal.');await call(asset,'decimals() view returns (uint8)');const saltBytes=new Uint8Array(32);crypto.getRandomValues(saltBytes);const salt='0x'+Array.from(saltBytes,x=>x.toString(16).padStart(2,'0')).join('');const hash=await signed(F,'createVaultV2(address,address,bytes32) returns (address)',[who,asset,salt],'vault creation');const address=String(await call(F,'vaultV2(address,address,bytes32) view returns (address)',[who,asset,salt]));if(!ok(address)||!(await call(F,'isVaultV2(address) view returns (bool)',[address])))throw Error('Vault transaction confirmed but factory verification failed. Tx: '+hash);store({address,name:name.trim(),symbol:symbol.trim(),asset,owner:who,hash});location.assign('/vaults/'+address+SUFFIX);}catch(e){info(e.message||String(e),true);loading=false;render();}}\n\nfunction pctToWad(text){\n if(!/^\\d+(?:\\.\\d{1,6})?$/.test(String(text).trim()))throw Error('Fee must be a percent with up to six decimal places.');\n const [whole,part='']=String(text).trim().split('.');\n const pctUnits=BigInt(whole)*1000000n+BigInt(part.padEnd(6,'0'));\n if(pctUnits>100000000n)throw Error('Percent may not exceed 100%.');\n return pctUnits*10000000000n;\n}\nfunction pctFromWad(wad){\n const scaled=BigInt(String(wad||0))*1000000n/10000000000000000n;\n return (Number(scaled)/1000000).toString();\n}\nasync function sendAndConfirm(tx,label){\n await connect();\n info('Confirm '+label+' in your wallet…');\n const hash=await window.ethereum.request({method:'eth_sendTransaction',params:[tx]});\n info(label+' submitted. Waiting for confirmation…');\n for(let i=0;i<75;i++){\n  const receipt=await window.ethereum.request({method:'eth_getTransactionReceipt',params:[hash]});\n  if(receipt){if(parseInt(receipt.status,16)!==1)throw Error(label+' reverted: '+hash);return {hash,receipt};}\n  await new Promise(resolve=>setTimeout(resolve,2400));\n }\n throw Error('Pending '+label+': '+hash+'. Do not submit another deployment until its status is checked.');\n}\nfunction controllerPendingKey(){return 'cy-v10-controller-pending:'+wallet.toLowerCase();}\nasync function deploy(){\n if(IS_ETH)return legacyDeploy();\n if(loading)return;loading=true;\n try{\n  await connect();\n  const who=wallet,asset=selected===-1?custom:tokens[selected][1];\n  if(!ok(who)||!ok(asset))throw Error('Connect an operator wallet and select a valid Fraxtal deposit token.');\n  if(!name.trim()||name.length>80||!symbol.trim()||symbol.length>32)throw Error('Enter a valid vault name and share symbol.');\n  const opWad=pctToWad(operatorFeePercent),full=2000000000000000n+opWad+(opWad*200n/10000n);\n  if(full>500000000000000000n)throw Error('Combined performance fee exceeds Morpho 50% maximum.');\n  const [fc,ac]=await Promise.all([window.ethereum.request({method:'eth_getCode',params:[F,'latest']}),window.ethereum.request({method:'eth_getCode',params:[asset,'latest']})]);\n  if(fc==='0x'||ac==='0x')throw Error('Vault factory or deposit token has no contract code on Fraxtal.');\n  await call(asset,'decimals() view returns (uint8)');\n  const key=controllerPendingKey();\n  let prior=null;try{prior=JSON.parse(localStorage.getItem(key)||'null');}catch{}\n  let controller=prior?.controller;\n  if(controller){\n   if(!ok(controller))throw Error('Invalid saved controller. Inspect browser storage before retrying.');\n   const operator=String(await call(controller,'operator() view returns (address)'));\n   if(operator.toLowerCase()!==who.toLowerCase())throw Error('Saved controller belongs to a different operator.');\n   if(Boolean(await call(controller,'initialized() view returns (bool)'))){\n    const already=String(await call(controller,'vault() view returns (address)'));\n    if(ok(already)&&Boolean(await call(F,'isVaultV2(address) view returns (bool)',[already]))){localStorage.removeItem(key);location.assign('/vaults/'+already);return;}\n    throw Error('Saved controller was already initialized; inspect it on Fraxscan.');\n   }\n  }else{\n   const constructorArgs=[who,CY_V10_TREASURY].map(x=>x.slice(2).toLowerCase().padStart(64,'0')).join('')+CY_V10_MAX_CREATION.toString(16).padStart(64,'0')+CY_V10_MASTER_POLICY.slice(2).toLowerCase().padStart(64,'0');\n   const deployment=await sendAndConfirm({from:who,data:CY_V10_INIT+constructorArgs},'your immutable CurveYield v10 controller deployment');\n   controller=deployment.receipt.contractAddress;\n   if(!ok(controller))throw Error('Controller creation mined without a valid contract address: '+deployment.hash);\n   const [linkedOp,linkedGov,maxFee,linkedMaster]=await Promise.all([\n    call(controller,'operator() view returns (address)'),call(controller,'governance() view returns (address)'),\n    call(controller,'maxVaultCreationFeeWei() view returns (uint256)'),\n    call(controller,'masterFeePolicy() view returns (address)')\n   ]);\n   if(String(linkedOp).toLowerCase()!==who.toLowerCase()||String(linkedGov).toLowerCase()!==CY_V10_TREASURY.toLowerCase()||BigInt(String(maxFee))!==CY_V10_MAX_CREATION||String(linkedMaster).toLowerCase()!==CY_V10_MASTER_POLICY.toLowerCase())throw Error('Controller deployment parameters could not be verified: '+controller);\n   localStorage.setItem(key,JSON.stringify({controller,operator:who,creationTx:deployment.hash}));\n  }\n  const fee=BigInt(String(await call(controller,'vaultCreationFeeWei() view returns(uint256)')));\n  if(fee>CY_V10_MAX_CREATION)throw Error('Controller fee exceeds the immutable creation-fee cap.');\n  const balance=BigInt(await window.ethereum.request({method:'eth_getBalance',params:[who,'latest']}));\n  if(balance<=fee)throw Error('Insufficient native FRAX: need '+String(fee)+' wei creation fee plus gas. Your controller was saved for resuming.');\n  const saltBytes=new Uint8Array(32);crypto.getRandomValues(saltBytes);\n  const salt='0x'+Array.from(saltBytes,x=>x.toString(16).padStart(2,'0')).join('');\n  const callData=abi('createVault(address,address,uint256,string,string,bytes32) returns (address)').encodeFunctionData('createVault',[asset,who,opWad.toString(),name.trim(),symbol.trim(),salt]);\n  const created=await sendAndConfirm({from:who,to:controller,data:callData,value:'0x'+fee.toString(16)},'Morpho vault creation with native FRAX fee');\n  const address=String(await call(controller,'vault() view returns(address)'));\n  const [factoryVerified,owner,curator,recipient,initialized]=await Promise.all([\n   call(F,'isVaultV2(address) view returns(bool)',[address]),\n   call(address,'owner() view returns(address)'),call(address,'curator() view returns(address)'),\n   call(address,'performanceFeeRecipient() view returns(address)'),\n   call(controller,'initialized() view returns(bool)')\n  ]);\n  const performanceCustody=String(await call(controller,'performanceFeeCustody() view returns(address)'));\n  if(!ok(address)||!Boolean(factoryVerified)||!Boolean(initialized)||String(owner).toLowerCase()!==controller.toLowerCase()||String(curator).toLowerCase()!==controller.toLowerCase()||String(recipient).toLowerCase()!==performanceCustody.toLowerCase())throw Error('Vault creation mined but protected routing did not verify. Inspect '+created.hash+' and '+controller);\n  store({address,controller,operator:who,name:name.trim(),symbol:symbol.trim(),asset,owner:controller,hash:created.hash,kind:'CurveYield-v10'});\n  localStorage.removeItem(key);\n  location.assign('/vaults/'+address);\n }catch(e){info(e?.message||String(e),true);loading=false;render();}\n}\n\nasync function importVault(){const address=$('v-import-address')?.value.trim();try{if(!ok(address))throw Error('Enter a valid vault address.');await connect();if(!(await call(F,'isVaultV2(address) view returns (bool)',[address])))throw Error('Vault was not deployed by Morpho’s Fraxtal V2 factory.');store({address,name:'Imported Vault V2'});location.assign('/vaults/'+address+SUFFIX);}catch(e){info(e.message||String(e),true);}}\nasync function refresh(){\n if(!vault||!window.ethereum)return;\n try{\n  const chain=await window.ethereum.request({method:'eth_chainId'});\n  if(parseInt(chain,16)!==CH_ID){info('Switch wallet to '+NETWORK+' to load vault settings.',true);return;}\n  if(!Boolean(await call(F,'isVaultV2(address) view returns (bool)',[vault])))throw Error('Not an official Morpho V2 factory vault.');\n  const specs=['owner() view returns(address)','asset() view returns(address)','name() view returns(string)','symbol() view returns(string)','curator() view returns(address)','totalAssets() view returns(uint256)'];\n  const out=await Promise.all(specs.map(sig=>call(vault,sig).catch(()=>null)));\n  if(!ok(String(out[0])))throw Error('Unable to read vault owner.');\n  let controller=null,operator=null,operatorFeeWad='0',operatorManagementFeeAnnualWad='0',policyMaster=null,policyNeedsSync=null,appliedPolicyVersion=null;\n  if(!IS_ETH&&String(out[0]).toLowerCase()===String(out[4]).toLowerCase()){\n   const linked=await call(String(out[0]),'vault() view returns(address)').catch(()=>null);\n   if(linked&&String(linked).toLowerCase()===vault.toLowerCase()){\n    controller=String(out[0]);\n    [operator,operatorFeeWad,operatorManagementFeeAnnualWad]=await Promise.all([\n     call(controller,'operator() view returns(address)'),\n     call(controller,'operatorFeeWad() view returns(uint256)'),\n     call(controller,'operatorManagementFeeAnnualWad() view returns(uint256)')\n    ]);\n    operator=String(operator);\n    const master=await call(controller,'masterFeePolicy() view returns(address)').catch(()=>null);\n    if(ok(String(master))){\n     policyMaster=String(master);\n     const [pending,applied]=await Promise.all([\n      call(controller,'policySyncRequired() view returns(bool)').catch(()=>null),\n      call(controller,'appliedPolicyVersion() view returns(uint256)').catch(()=>null)\n     ]);\n     policyNeedsSync=pending===null?null:Boolean(pending);\n     appliedPolicyVersion=applied===null?null:String(applied);\n    }\n   }\n  }\n  details={owner:String(out[0]),asset:String(out[1]),name:String(out[2]||''),symbol:String(out[3]||''),curator:String(out[4]||zero),total:String(out[5]??'—'),controller,operator,operatorFeeWad:String(operatorFeeWad),operatorManagementFeeAnnualWad:String(operatorManagementFeeAnnualWad),policyMaster,policyNeedsSync,appliedPolicyVersion};\n  const existing=records().find(x=>x.address.toLowerCase()===vault.toLowerCase());\n  if(existing&&(details.name&&existing.name!==details.name||controller&&existing.controller!==controller))store({...existing,name:details.name,controller,operator});\n  render();await loadDead();\n  if(lChoice&&!IS_ETH)await lmRead();\n  if(IS_ETH&&details?.asset&&!lBusy)void lmFetch(true);\n }catch(e){info(e?.message||String(e),true);}\n}\n\nasync function finishBasics(){\n if(loading)return;loading=true;\n try{\n  if(!details||!wallet||wallet.toLowerCase()!==(details.operator||details.owner).toLowerCase())throw Error('Connect the authorized vault operator.');\n  const n=$('v-edit-name')?.value.trim(),sym=$('v-edit-symbol')?.value.trim();\n  if(!n||!sym)throw Error('Name and share symbol required.');\n  if(details.name!==n)await signed(details.controller||vault,details.controller?'setVaultName(string)':'setName(string)',[n],'vault name');\n  if(details.symbol!==sym)await signed(details.controller||vault,details.controller?'setVaultSymbol(string)':'setSymbol(string)',[sym],'vault symbol');\n  if(!details.controller){\n   const cur=$('v-curator')?.value.trim();\n   if(!ok(cur))throw Error('Valid curator required.');\n   if(details.curator.toLowerCase()!==cur.toLowerCase())await signed(vault,'setCurator(address)',[cur],'curator assignment');\n  }\n  await refresh();info('Basic vault configuration saved.');\n }catch(e){info(e?.message||String(e),true);}\n finally{loading=false;const b=$('v-finish');if(b)b.disabled=false;}\n}\nasync function saveName(){\n try{\n  if(!details||!wallet||wallet.toLowerCase()!==(details.operator||details.owner).toLowerCase())throw Error('Only the vault operator may rename.');\n  const n=$('v-edit-name')?.value.trim(),sym=$('v-edit-symbol')?.value.trim();\n  if(!n||!sym)throw Error('Name and symbol required.');\n  if(n!==details.name)await signed(details.controller||vault,details.controller?'setVaultName(string)':'setName(string)',[n],'vault name');\n  if(sym!==details.symbol)await signed(details.controller||vault,details.controller?'setVaultSymbol(string)':'setSymbol(string)',[sym],'vault symbol');\n  await refresh();info('Vault name and symbol saved.');\n }catch(e){info(e?.message||String(e),true);}\n}\nasync function saveCurator(){\n try{\n  if(details?.controller)throw Error('Protected vault curator is permanently the dedicated controller. Operator permissions are managed through the controller.');\n  if(!details||wallet.toLowerCase()!==details.owner.toLowerCase())throw Error('Only owner can set curator.');\n  const c=$('v-curator')?.value.trim();\n  if(!ok(c))throw Error('Enter a valid curator wallet or Safe.');\n  await signed(vault,'setCurator(address)',[c],'curator assignment');\n  await refresh();\n }catch(e){info(e?.message||String(e),true);}\n}\nasync function saveOperatorFees(){\n try{\n  if(!details?.controller||wallet?.toLowerCase()!==details.operator?.toLowerCase())throw Error('Connect the protected vault operator.');\n  const perf=pctToWad($('v-performance-percent')?.value||'0');\n  const mgmt=pctToWad($('v-management-percent')?.value||'0');\n  if(perf!==BigInt(details.operatorFeeWad))await signed(details.controller,'setOperatorPerformanceFee(uint256)',[perf.toString()],'operator performance fee');\n  if(mgmt!==BigInt(details.operatorManagementFeeAnnualWad))await signed(details.controller,'setOperatorManagementFee(uint256)',[mgmt.toString()],'operator annual management fee');\n  await refresh();info('Operator fee configuration confirmed on-chain.');\n }catch(e){info(e?.message||String(e),true);}\n}\nasync function syncMasterPolicy(){\n try{\n  if(!details?.controller||!ok(details.policyMaster))throw Error('This vault has no master fee policy.');\n  await signed(details.controller,'syncProtocolFees()',[],'synchronize CurveYield master fee rates');\n  await refresh();\n  info('Master fee rates are synchronized on-chain.');\n }catch(e){info(e?.message||String(e),true);}\n}\nasync function proposeOperatorTransfer(){\n try{\n  if(!details?.controller||wallet?.toLowerCase()!==details.operator?.toLowerCase())throw Error('Only current operator may propose transfer.');\n  const next=$('v-next-operator')?.value.trim();\n  if(!ok(next))throw Error('Valid new wallet or Safe address required.');\n  await signed(details.controller,'proposeOperator(address)',[next],'propose protected vault operator transfer');\n  info('Proposal recorded. The new operator wallet/Safe must call acceptOperator() on '+details.controller+'.');\n }catch(e){info(e?.message||String(e),true);}\n}\n\nrender();lmFetch();if(window.ethereum){window.ethereum.request({method:'eth_accounts'}).then(a=>{wallet=a?.[0]||'';render();if(vault)refresh();}).catch(()=>{});window.ethereum.on?.('accountsChanged',a=>{wallet=a?.[0]||'';render();if(vault)refresh();});window.ethereum.on?.('chainChanged',()=>location.reload());if(vault)refresh();}\n})();\n";
const VAULT_STYLE="\n.v-page{padding-bottom:75px}.v-heading{padding:10px 0 30px}.v-heading h1{font-size:38px;letter-spacing:-1px;margin:10px 0}.v-heading p{color:#82888d;line-height:1.6}.v-heading a:not(.v-primary){font-size:12px;color:#b58017}.v-tokens{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin:17px 0}.v-token{padding:14px 9px;border-radius:10px;border:1px solid #e7e6e2;background:#fcfcfb;font-weight:620}.v-token.active,.v-token:hover{background:#fff7e6;border-color:#d3ab50;color:#936400}.v-field{display:block;margin:18px 0}.v-field span{display:block;font-size:12px;font-weight:680;margin-bottom:8px}.v-field input{width:100%;padding:13px;border:1px solid #e4e4e2;border-radius:9px;outline:0}.v-field input:focus{border-color:#bf9425}.v-field small,.v-hint{display:block;font-size:12px;line-height:1.65;color:#92979e;margin:8px 0}.v-option{display:flex;gap:9px;align-items:center;border:1px solid #ebe9e4;border-radius:9px;padding:14px;margin:9px 0}.v-line{display:flex;justify-content:space-between;gap:12px;padding:13px 0;border-bottom:1px solid #f0efef;font-size:12px}.v-line span{color:#8d9197}.v-line b{text-align:right;overflow-wrap:anywhere}.v-alert{font-size:12px;color:#13916a;line-height:1.7;padding-top:9px}.v-alert.error{color:#b34735}.v-primary,.v-secondary{display:inline-block;border:1px solid #d6a33e;border-radius:10px;padding:12px 16px;font-weight:650;background:#fff8e5;color:#a67b12}.v-primary{background:#d59600;color:white}.v-action-link{text-decoration:none;margin-top:14px}.v-item{display:flex;align-items:center;gap:16px;padding:20px;border-bottom:1px solid #efefef}.v-item small{color:#999}.v-item span{margin-left:auto;color:#b4861f}.v-import{display:flex;gap:9px;margin-top:22px}.v-import input{flex:1;min-width:0;padding:13px;border:1px solid #e7e7e7;border-radius:10px}.v-steps{margin-top:15px}.v-steps div{padding:14px;border-bottom:1px solid #eee;color:#8b8d91;font-size:13px}.v-steps .complete{color:#128e6c}.v-edit{border-top:1px solid #eee;padding-top:10px;margin-top:20px}@media(max-width:800px){.v-tokens{grid-template-columns:1fr 1fr}.v-heading h1{font-size:30px}.v-import{flex-direction:column}}\n\n.v-dead{background:#fffaf0;border:1px solid #ebdbaf;border-radius:13px;padding:22px;margin:18px 0 24px}.v-dead h3{font-size:18px;margin:10px 0}.v-dead a{font-size:12px;color:#9b7517;display:inline-block;margin-top:12px}.v-dead .action-primary{margin:14px 0 7px}.v-dead .v-line{border-color:#eee2c8}.v-bad{font-weight:620;color:#b34f41;font-size:13px;line-height:1.65}.v-good{font-size:13px;font-weight:650;color:#0e875d}\n\n.lm-panel{margin-top:16px}.lm-filters{display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin:15px 0}\n.lm-filters select{border:1px solid #ddd;background:white;border-radius:7px;padding:9px}.lm-filters label{font-size:12px;color:#737373}\n.lm-results{max-height:560px;overflow:auto;border:1px solid #eaeaea;border-radius:9px}\n.lm-item{display:grid;grid-template-columns:1.5fr 1fr 1fr auto;align-items:center;gap:10px;padding:12px;border-bottom:1px solid #eee}\n.lm-item strong,.lm-item b{font-size:13px}.lm-item small{font-size:11px;color:#777;display:block;margin-top:4px}\n.lm-detail{padding:15px;margin-top:15px;background:#fcfcfc;border:1px solid #e9e9e9;border-radius:9px}\n.lm-detail .v-line{margin:12px 0}.lm-detail button{margin:3px}.lm-controls{border-top:1px solid #eee;padding-top:12px;margin-top:12px}\n.lm-controls label{display:block;font-size:12px;margin:7px 0}.lm-controls input{display:block;width:100%;max-width:245px;padding:9px;border:1px solid #ddd;border-radius:7px}\n.lm-panel .v-bad{color:#bb2929;font-size:13px}\n@media(max-width:650px){.lm-item{grid-template-columns:1fr 1fr}.lm-item button{width:100%}}\n\n.lm-deposit-asset{display:flex;flex-direction:column;gap:6px;padding:14px;border:1px solid #e9e5d9;background:#fbfaf6;border-radius:9px;margin:15px 0}.lm-deposit-asset strong{font-size:15px;overflow-wrap:anywhere}.lm-deposit-asset small{color:#6a6f76;font-size:12px;line-height:1.5}.lm-panel>h3{font-size:15px;margin:13px 0}\n\n.lm-chain-tabs{display:flex;gap:10px;margin:12px 0 25px}.lm-chain-tabs a{border:1px solid #ddd;color:#5d6470;padding:10px 18px;border-radius:9px;text-decoration:none;font-size:13px}.lm-chain-tabs .selected{background:#fff8e5;border-color:#ddb14a;color:#a8791a}\n";
const VAULT_HTML=HTML.replace('<link rel="stylesheet" href="/assets/app.css">','<link rel="stylesheet" href="/assets/app.css"><link rel="stylesheet" href="/assets/vaults.css?v=77">').replace('<script defer src="/assets/app.js"></script>','<script defer src="/assets/vaults.js?v=77"></script>');

/* CurveYield Fraxtal lending discovery v23: authoritative on-chain registries. */
const CY_LEND_CURVE='0xf3c9bdab17b7016fbe3b77d17b1602a7db93ac66';
const CY_LEND_FRAX='0x8c22ebc8f9b96ceac97ea21c53f3b27ef2f45e57';
const CY_LEND_ADAPTER_FACTORY='0x3d36d5a098881e34d391b01032126c1ee802b31c';
const CY_VAULT_V2_FACTORY='0x711bce12269a3a496efaabb8b9ad5a4485e08a24';
const CY_LEND_SELECT={
 curveCount:'0xfd775c78',curveAt:'0x8c64ea4a',
 fraxCount:'0x36683100',fraxAt:'0x31c315df',
 asset:'0x38d52e0f',curveCollateral:'0x2621db2f',fraxCollateral:'0xc6e1c7c9',
 totalAssets:'0x01e1d114',lendApr:'0xa980497e',borrowApr:'0xbac4daa2',
 fraxTotalAsset:'0xf9557ccb',fraxTotalBorrow:'0x8285ef40',fraxRate:'0x95d14ca8',
 decimals:'0x313ce567',symbol:'0x95d89b41'
};
function cyLendAddress(raw){const w=oneWord(raw);return w===null?null:'0x'+w.toString(16).padStart(40,'0');}
function cyLendValid(a){return typeof a==='string' && /^0x[0-9a-f]{40}$/.test(a) && a!=='0x0000000000000000000000000000000000000000';}
function cyLendRate(n){if(n==null)return null;const val=Number(n)/1e16;return Number.isFinite(val)&&val>=0&&val<1e8?val:null;}
async function cyFraxtalLendingCatalogue(){
 const hdr=await rpc([ethCall(CY_LEND_CURVE,CY_LEND_SELECT.curveCount),ethCall(CY_LEND_FRAX,CY_LEND_SELECT.fraxCount),
  {method:'eth_blockNumber',params:[]},ethCall(CY_LEND_CURVE,'0x570ca735')]);
 const cn=oneWord(hdr[0]?.result),fn=oneWord(hdr[1]?.result);
 if(cn===null||fn===null||cn>128n||fn>128n)throw Error('CurveLend or Fraxlend registry unavailable, or unexpected market count.');
 const pointers=[];
 for(let i=0;i<Number(cn);i++)pointers.push({protocol:'CurveLend',index:i,call:ethCall(CY_LEND_CURVE,calldata(CY_LEND_SELECT.curveAt,i))});
 for(let i=0;i<Number(fn);i++)pointers.push({protocol:'Fraxlend',index:i,call:ethCall(CY_LEND_FRAX,calldata(CY_LEND_SELECT.fraxAt,i))});
 const found=await rpcChunks(pointers.map(p=>p.call));
 const markets=pointers.map((p,i)=>({...p,address:cyLendAddress(found[i]?.result)})).filter(p=>cyLendValid(p.address));
 const requests=[];
 for(const m of markets){
  const qs=m.protocol==='CurveLend'
  ?[{k:'asset',sel:CY_LEND_SELECT.asset},{k:'collateral',sel:CY_LEND_SELECT.curveCollateral},
    {k:'supplied',sel:CY_LEND_SELECT.totalAssets},{k:'lendApr',sel:CY_LEND_SELECT.lendApr},
    {k:'borrowApr',sel:CY_LEND_SELECT.borrowApr}]
  :[{k:'asset',sel:CY_LEND_SELECT.asset},{k:'collateral',sel:CY_LEND_SELECT.fraxCollateral},
    {k:'supply',sel:CY_LEND_SELECT.fraxTotalAsset},{k:'borrow',sel:CY_LEND_SELECT.fraxTotalBorrow},
    {k:'rate',sel:CY_LEND_SELECT.fraxRate}];
  for(const q of qs)requests.push({at:m.address,key:q.k,call:ethCall(m.address,q.sel)});
 }
 const vals=await rpcChunks(requests.map(p=>p.call));const byAddr=new Map();
 requests.forEach((q,i)=>{if(!byAddr.has(q.at))byAddr.set(q.at,{});byAddr.get(q.at)[q.key]=vals[i]?.result??null;});
 const tokenSet=new Set();for(const m of markets){const obj=byAddr.get(m.address)||{};m.asset=cyLendAddress(obj.asset);m.collateral=cyLendAddress(obj.collateral);if(cyLendValid(m.asset))tokenSet.add(m.asset);if(cyLendValid(m.collateral))tokenSet.add(m.collateral);}
 const tokens=[...tokenSet];const tokenQs=[];
 for(const a of tokens){tokenQs.push({a,k:'decimals',call:ethCall(a,CY_LEND_SELECT.decimals)});
   tokenQs.push({a,k:'symbol',call:ethCall(a,CY_LEND_SELECT.symbol)});}
 const tokenR=await rpcChunks(tokenQs.map(x=>x.call));const tokenInfo={};
 tokenQs.forEach((q,i)=>{const entry=tokenInfo[q.a]??(tokenInfo[q.a]={});
  if(q.k==='decimals'){const num=oneWord(tokenR[i]?.result);entry.decimals=num!==null&&num<=36n?Number(num):null;}
  else entry.symbol=safeSymbol(tokenR[i]?.result)||null;});
 const prices=await rpc([ethCall(USD_WFRAX_CURVE,calldata('0x68727653',1)),
   ethCall(USD_SFRX_REDEMPTION,calldata('0x07a2d13a',10n**18n))]);
 const wPrice=asFloat(oneWord(prices[0]?.result)),sPrice=asFloat(oneWord(prices[1]?.result));
 const crvUsd=cyLendAddress(hdr[3]?.result);
 const out=markets.map(m=>{
  const data=byAddr.get(m.address)||{},meta=tokenInfo[m.asset]||{},coll=tokenInfo[m.collateral]||{};
  const decimals=meta.decimals,known=decimals!==null&&decimals!==undefined;
  const raw=(m.protocol==='CurveLend'?oneWord(data.supplied):oneWord(data.supply));
  const totalAssetsRaw=raw?.toString()??null;
  const supplied=raw!==null&&known?asFloat(raw,decimals):null;
  let lendApr=m.protocol==='CurveLend'?cyLendRate(oneWord(data.lendApr)):null;
  let borrowApr=m.protocol==='CurveLend'?cyLendRate(oneWord(data.borrowApr)):null;
  let borrowed=null,utilization=null,rateSource=m.protocol==='CurveLend'?'on-chain lend_apr()':'estimated from ratePerSec, utilization and protocol fee';
  if(m.protocol==='Fraxlend'){
   const debt=words(data.borrow??'0x'),r=words(data.rate??'0x');
   if(debt.length>=2&&r.length>=5&&raw!==null&&raw>0n){
    borrowed=known?asFloat(debt[0],decimals):null;
    utilization=finite(Number(debt[0])*100/Number(raw));
    borrowApr=finite(Number(r[3])/1e18*31536000*100);
    const fee=Number(r[1])/100000;
    lendApr=finite(borrowApr*(Number(debt[0])/Number(raw))*(1-fee));
    if(lendApr!==null&&(lendApr<0||lendApr>1e8))lendApr=null;
   }
  }
  if(m.protocol==='CurveLend')rateSource='on-chain lend_apr()';
  let usdRate=null,usdSource=null;
  if(m.asset==='0xfc00000000000000000000000000000000000001'){usdRate=1;usdSource='frxUSD $1 reference';}
  else if(m.asset==='0xfc00000000000000000000000000000000000008'&&sPrice>0){usdRate=sPrice;usdSource='verified sfrxUSD redemption / frxUSD $1 reference';}
  else if(m.asset==='0xfc00000000000000000000000000000000000002'&&wPrice>0){usdRate=wPrice;usdSource='Curve oracle / frxUSD $1 reference';}
  else if(crvUsd!==null&&m.asset===crvUsd){usdRate=1;usdSource='crvUSD $1 reference';}
  const tvlUsd=supplied!=null&&usdRate!=null?finite(supplied*usdRate):null;
  return {protocol:m.protocol,chainId:252,index:m.index,address:m.address,
   asset:m.asset,collateral:m.collateral,assetSymbol:meta.symbol||null,collateralSymbol:coll.symbol||null,
   decimals:known?decimals:null,totalAssetsRaw,tvlAssets:supplied,tvlUsdEstimate:tvlUsd,usdSource,
   lendApr,borrowApr,rateSource,borrowedAssets:borrowed,utilization,
   adapterFactory:CY_LEND_ADAPTER_FACTORY,protocolId:m.protocol==='CurveLend'?1:2,
   registryVerified:true,adapterStatus:'deployable_for_verified_vault_only'};
 });
 const block=hdr[2]?.result?Number(BigInt(hdr[2].result)):null;
 return {chainId:252,block,curveFactory:CY_LEND_CURVE,fraxlendRegistry:CY_LEND_FRAX,
  adapterFactory:CY_LEND_ADAPTER_FACTORY,vaultFactory:CY_VAULT_V2_FACTORY,
  marketCount:{CurveLend:Number(cn),Fraxlend:Number(fn)},discovered:out.length,
  pricingNote:'USD TVL is an estimate only for assets with an available live quote or named $1 stablecoin reference; other assets show token-denominated supplied assets.',
  rateNote:'CurveLend calls its lend_apr(). Fraxlend supply APR is estimated using current ratePerSec, total borrowed, total supplied and protocol fee. Neither includes incentive rewards.',
  opportunities:out,updatedAt:new Date().toISOString()};
}


/* v49: obsolete per-request Ethereum RPC enumeration retired in favor of cached API catalog. */
const cyEValid=x=>typeof x==='string'&&/^0x[0-9a-f]{40}$/.test(x)&&x!=='0x0000000000000000000000000000000000000000';
/* Ethereum verified-source lending discovery, v34.
 * Index-backed sources are display-only until confirmed against the execution contract.
 */
const CY_E_COMETS=[
 {name:'Compound III USDC',address:'0xc3d688b66703497daa19211eedff47f25384cdc3',asset:'0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'},
 {name:'Compound III USDS',address:'0x5d409e56d886231adaf00c8775665ad0f9897b56',asset:'0xdc035d45d973e3ec169d2276ddab16f1e407384f'},
 {name:'Compound III USDT',address:'0x3afdc9bca9213a35503b077a6072f3d0d5ab0840',asset:'0xdac17f958d2ee523a2206206994597c13d831ec7'},
 {name:'Compound III WBTC',address:'0xe85dc543813b8c2cfeaac371517b925a166a9293',asset:'0x2260fac5e5542a773aa44fbcfedf7c193bc2c599'},
 {name:'Compound III WETH',address:'0xa17581a9e3356d9a858b789d68b4d866e593ae94',asset:'0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2'},
 {name:'Compound III wstETH',address:'0x3d0bb1ccab520a66e607822fc55bc921738fafe3',asset:'0x7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0'}
];
const CY_E_AAVE_V3_POOLS=[
 {name:'Core',address:'0x87870bca3f3fd6335c3f4ce8392d69350b4fa4e2'},
 {name:'EtherFi',address:'0x0aa97c284e98396202b6a04024f5e2c65026f3c0'},
 {name:'Lido',address:'0x4e033931ad43597d96d6bcc25c280717730b58b1'},
 {name:'Horizon',address:'0xae05cd22df81871bc7cc2a04becfb516bfe332c8'}
];
const cyEAsNum=x=>{if(x===null||x===undefined)return null;const n=Number(x);return Number.isFinite(n)&&n>=0?n:null};
const cyERate=x=>{const n=cyEAsNum(x);return n!==null&&n<100000?n:null};
async function cyEHttpJson(url){
 const response=await fetch(url,{headers:{'Accept':'application/json'},signal:AbortSignal.timeout(14000)});
 if(!response.ok)throw Error('Upstream HTTP '+response.status);
 return response.json();
}
async function cyEGraphQl(url,query){
 const response=await fetch(url,{method:'POST',headers:{'content-type':'application/json'},
 body:JSON.stringify({query}),signal:AbortSignal.timeout(14000)});
 if(!response.ok)throw Error('GraphQL HTTP '+response.status);
 const data=await response.json();
 if(data.errors?.length)throw Error(data.errors.map(x=>x.message).join(' / ').slice(0,340));
 return data.data??{};
}
async function cyEEssentialMarkets(asset,protocol,page=0){
 asset=String(asset||'').toLowerCase();
 if(!cyEValid(asset))throw Error('Invalid Ethereum vault asset');
 const out=[],meta={protocol,chainId:1,sourceFailures:[],counts:{},pagination:{eulerHasNext:false,morphoNextCursor:null}};
 const add=x=>{if(x.asset&&x.asset.toLowerCase()!==asset)return;if(!cyEValid(x.address))return;out.push({
  chainId:1,asset,registryVerified:false,sourceBound:true,
  lendApr:null,tvlAssets:null,tvlUsdEstimate:null,rateSource:'Unavailable',
  adapterStatus:'discovery_only_awaiting_omniadapter',...x});};
 const safe=x=>{try{return Number.isFinite(Number(x))?Number(x):null}catch{return null}};
 if(protocol==='CurveLend V2'||protocol==='CurveLend V1'){
  const data=await cyEHttpJson('https://api.curve.finance/v1/getLendingVaults/all/ethereum');
  if(data.success!==true||!Array.isArray(data.data?.lendingVaultData))throw Error('Curve lending API schema changed');
  const rows=data.data.lendingVaultData.filter(x=>(protocol==='CurveLend V2'?x.id?.startsWith('oneway-v2-'):x.id?.startsWith('oneway-')&&!x.id?.startsWith('oneway-v2-')));
  meta.counts[protocol]=rows.length;
  for(const r of rows){
   const loan=r.assets?.borrowed,coll=r.assets?.collateral;
   if(loan?.address?.toLowerCase()!==asset)continue;
   add({protocol,address:r.address.toLowerCase(),marketName:r.name||'LlamaLend',assetSymbol:loan.symbol,
    collateral:coll?.address?.toLowerCase()||null,collateralSymbol:coll?.symbol||null,
    tvlAssets:safe(r.totalSupplied?.total),tvlUsdEstimate:safe(r.totalSupplied?.usdTotal),
    borrowedAssets:safe(r.borrowed?.total),availableLiquidity:safe(r.availableToBorrow?.total),
    lendApr:cyERate(safe(r.rates?.lendApr)*100),borrowApr:cyERate(safe(r.rates?.borrowApr)*100),
    rateType:'APR',rateSource:'Curve lending API',sourceUrl:'https://api.curve.finance/v1/getLendingVaults/all/ethereum',
    protocolId:protocol==='CurveLend V2'?3:1,registryVerified:true,oracleStatus:'Curve API USD quote',
    adapterStatus:'factory_pending',marketUrl:r.lendingVaultUrls?.deposit||null});
  }
  return {...meta,opportunities:out};
 }
 if(protocol==='Euler EVK'){
  const limit=100,offset=Math.min(30,Math.max(0,page))*limit;
  const url='https://v3.euler.finance/v3/evk/vaults?chainId=1&limit='+limit+'&offset='+offset;
  const response=await cyEHttpJson(url),rows=response?.data;
  if(!Array.isArray(rows)||!response.meta||!Number.isInteger(response.meta.total))throw Error('Euler V3 vault API schema changed');
  meta.counts['Euler indexed eVaults']=response.meta.total;
  meta.pagination.eulerHasNext=offset+rows.length<response.meta.total;
  meta.pagination.eulerPage=page;
  for(const row of rows){
   if(row.vaultType!=='evk'||row.asset?.address?.toLowerCase()!==asset)continue;
   const amount=row.asset.decimals!=null&&/^[0-9]+$/.test(String(row.totalAssets||''))
    ?Number(BigInt(row.totalAssets))/10**Number(row.asset.decimals):null;
   add({protocol,address:row.address.toLowerCase(),marketName:row.name||'Euler eVault',
    assetSymbol:row.asset.symbol||null,decimals:row.asset.decimals,tvlAssets:Number.isFinite(amount)?amount:null,
    tvlUsdEstimate:cyEAsNum(row.totalSupplyUsd),lendApr:cyERate(cyEAsNum(row.supplyApy)*100),
    borrowApr:cyERate(cyEAsNum(row.borrowApy)*100),rateType:'APY',rateSource:'Euler V3 Data API',
    deprecated:row.visibility?.decidedBy==='deprecated',sourceUrl:url,
    timestamp:row.snapshotTimestamp||null,
    adapterStatus:row.visibility?.explorableLend?'factory_pending_evk_registry':'inactive_or_restricted_vault'});
  }
  meta.incompleteSources=['Euler factory-created unlisted vaults require separate on-chain enumeration.'];
  return {...meta,opportunities:out};
 }
 if(protocol==='Compound III'){
  const matched=CY_E_COMETS.filter(x=>x.asset===asset);
  meta.counts['Compound III mainnet Comets']=CY_E_COMETS.length;
  for(const market of matched)add({protocol,address:market.address,marketName:market.name,
   assetSymbol:market.name.slice('Compound III '.length),
   rateSource:'Compound Comet deployment registry; current APR pending',
   sourceUrl:'https://github.com/compound-finance/comet/tree/main/deployments/mainnet'});
  return {...meta,opportunities:out};
 }
 if(protocol==='Liquity V2 (legacy BOLD SP)'||protocol==='Liquity'){
  const boldLegacy='0xb01dd87b29d187f3e3a4bf6cdaebfb97f3d9ab98',
    boldCurrent='0x6440f144b7e50d6a8439336510312d2f54beb01d',
    lusd='0x5f98805a4e8be255a32880fdec7f6728c6568ba0';
  const currentBranches=[
   {name:'ETH',address:'0x5721cbbd64fc7ae3ef44a0a3f9a790a9264cf9bf'},
   {name:'wstETH',address:'0x9502b7c397e9aa22fe9db7ef7daf21cd2aebe56b'},
   {name:'rETH',address:'0xd442e41019b7f5c4dd78f50dc03726c446148695'}
  ];
  if(asset===lusd)add({protocol:'Liquity V1',address:'0x66017d22b0f8556afdd19fc67041899eb65a21bb',
    marketName:'Liquity V1 · LUSD Stability Pool',assetSymbol:'LUSD',rateSource:'Variable liquidation and incentive rewards; no fixed APR',
    sourceUrl:'https://docs.liquity.org/liquity-v1/documentation/resources',adapterStatus:'stability_pool_specialized_adapter_required'});
  if(asset===boldCurrent)for(const x of currentBranches)add({protocol:'Liquity V2',address:x.address,
    marketName:'Liquity V2 · '+x.name+' Stability Pool',assetSymbol:'BOLD',
    rateSource:'Variable BOLD borrowing interest and liquidation rewards; no fixed APR',
    sourceUrl:'https://github.com/liquity/bold/blob/main/frontend/app/.env',adapterStatus:'stability_pool_specialized_adapter_required'});
  if(asset===boldLegacy)add({protocol:'Liquity V2 Legacy',address:'0xf69eb8c0d95d4094c16686769460f678727393cf',
    marketName:'Liquity V2 legacy · ETH Stability Pool',assetSymbol:'BOLD (legacy)',
    rateSource:'Legacy stability-pool variable rewards',sourceUrl:'https://docs.liquity.org/v2-documentation/technical-resources',
    adapterStatus:'legacy_stability_pool_adapter_required'});
  meta.counts['Liquity current BOLD stability pools']=currentBranches.length;
  meta.incompleteSources=['Other legacy BOLD stability-pool branches are omitted until individually verified.'];
  return {...meta,opportunities:out};
 }
 throw Error('No official-backed discovery implementation for '+protocol);
}

const OP_CLIENT="\n'use strict';(()=>{\nconst $=id=>document.getElementById(id),esc=x=>String(x??'').replace(/[&<>\"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;',\"'\":'&#39;'}[c])),\nmoney=n=>n==null?'—':'$'+Number(n).toLocaleString(undefined,{maximumFractionDigits:0}),\nrate=n=>n==null?'—':Number(n).toFixed(2)+'%';\nlet doc=null,rows=[],offset=0,total=0,baseTotal=0,visibleLimit=100,loading=false,sort='yield',protocol='all',asset='',search='',quality='high',view='verified',sourceDocs={},sourceIds={};\nconst SOURCES=[\n {key:'stakedao',native:'Stake DAO native locker registry',protocols:['Stake DAO Lockers']},\n {key:'ipor',native:'IPOR Fusion v2',gate:'IPOR onchain ERC4626 deposit capacity',protocols:['IPOR Fusion']},\n {key:'fluid',native:'Fluid official fTokens',gate:'Fluid onchain ERC4626 deposit capacity',protocols:['Fluid Lending']},\n {key:'yearn',native:'Yearn Kong REST V2/V3',gate:'Independent ERC4626 deposit eligibility',protocols:['Yearn V2','Yearn V3']},\n {key:'curvelend',native:'Curve official Ethereum lending',gate:'Independent ERC4626 deposit eligibility',protocols:['CurveLend V1','CurveLend V2']},\n {key:'maple',native:'Maple Finance official V2 pools',gate:'Independent ERC4626 deposit eligibility',protocols:['Maple Syrup']},\n {key:'morphoblue',native:'Morpho Blue complete Ethereum market index',protocols:['Morpho Blue']},\n {key:'morphov1',native:'Morpho Vault V1 bulk USD',protocols:['Morpho Vault V1']},\n {key:'morphov2',native:'Morpho Vault V2 bulk USD',protocols:['Morpho Vault V2']},\n {key:'gearbox',native:'Gearbox official Ethereum passive ERC4626 pools',protocols:['Gearbox Pools']},\n {key:'silo',native:'Silo V3 official Ethereum GraphQL markets',protocols:['Silo Vaults']},\n {key:'spark',native:'Spark official Ethereum Savings V2 REST',protocols:['Spark Savings']},\n {key:'sky',native:'Sky official Ethereum Savings ERC4626 contracts',protocols:['Sky Savings']},\n {key:'harvest',native:'Harvest official Ethereum vault registry API',protocols:['Harvest Finance']},\n {key:'eulerearn',native:'Euler Earn official Ethereum curated vaults',protocols:['Euler Earn']}\n];\n$('page').innerHTML='<div class=\"container\" style=\"padding-bottom:80px\"><div class=\"over-head\"><h1>Ethereum opportunities</h1><p class=\"sub\">Lending markets and yield vaults with reported USD TVL above $100. API-sourced, edge-cached and discoverable without user-load RPC scans.</p></div>'+\n'<div class=\"overview-summary\"><div class=\"summary-number\"><span>Matching opportunities</span><strong id=\"o-count\">—</strong></div><div class=\"summary-number\"><span>Updated</span><strong id=\"o-updated\" style=\"font-size:17px\">—</strong></div><div class=\"summary-number\"><span>LP compositions indexed</span><strong id=\"o-lp-count\">—</strong></div><div class=\"summary-number\"><span>Market-specific URLs</span><strong id=\"o-links-exact\">—</strong></div><div class=\"summary-number\"><span>Unresolved links</span><strong id=\"o-links-dir\">—</strong></div></div>'+\n'<div class=\"filterbar\" style=\"padding:22px 0\"><select id=\"o-sort\" class=\"sort-select\"><option value=\"tvl\">Highest TVL</option><option value=\"yield\" selected>Highest reported rate</option><option value=\"asset\">Deposit asset (A–Z)</option></select>'+\n'<span class=\"small muted\">Single-token deposit markets only</span>'+\n'<select id=\"o-protocol\" class=\"sort-select\"><option value=\"all\">All protocols</option></select>'+\n'<select id=\"o-quality\" class=\"sort-select\" aria-label=\"Yield quality\"><option value=\"all\">All rates</option><option value=\"high\" selected>5%+ yield · $1M+ TVL</option><option value=\"explore\">5%+ yield · $100K+ TVL (explore)</option><option value=\"premium\">8%+ yield · $1M+ TVL</option></select>'+\n'<select id=\"o-core\" class=\"sort-select\" aria-label=\"Core deposit asset\"><option value=\"\">Any deposit token</option><option value=\"0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48\">USDC</option><option value=\"0xdac17f958d2ee523a2206206994597c13d831ec7\">USDT</option><option value=\"0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2\">WETH</option><option value=\"0x2260fac5e5542a773aa44fbcfedf7c193bc2c599\">WBTC</option><option value=\"0x7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0\">wstETH</option><option value=\"0x6b175474e89094c44da98b954eedeac495271d0f\">DAI</option><option value=\"0xdc035d45d973e3ec169d2276ddab16f1e407384f\">USDS</option><option value=\"0x6c3ea9036406852006290770bedfcaba0e23a0e8\">PYUSD</option><option value=\"0x8292bb45bf1ee4d140127049757c2e0ff06317ed\">RLUSD</option><option value=\"0x00000000efe302beaa2b3e6e1b18d08d69a9012a\">AUSD</option><option value=\"0xf939e0a03fb07f59a73314e73794be0e57ac1b4e\">crvUSD</option><option value=\"0xcacd6fd266af91b8aed52accc382b4e165586e29\">frxUSD</option><option value=\"0x40d16fc0246ad3160ccc09b8d0d3a2cd28ae6c2f\">GHO</option><option value=\"0x4c9edd5852cd905f086c759e8383e09bff1e68b3\">USDe</option><option value=\"0x1abaea1f7c830bd89acc67ec4af516284b1bc33c\">EURC</option><option value=\"0xe343167631d89b6ffc58b88d6b7fb0228795491d\">USDG</option><option value=\"0x98a878b1cd98131b271883b390f68d2c90674665\">apxUSD</option><option value=\"0x6440f144b7e50d6a8439336510312d2f54beb01d\">BOLD</option><option value=\"0xcbb7c0000ab88b473b1f5afd9ef808440eed33bf\">cbBTC</option><option value=\"0x18084fba666a33d37592fa2633fd49a74dd93a88\">tBTC</option><option value=\"0xcd5fe23c85820f7b72d0926fc9b05b43e359b7ee\">weETH</option><option value=\"0xae78736cd615f374d3085123a210448e74fc6393\">rETH</option><option value=\"0xbe9895146f7af43049ca1c1ae358b0541ea49704\">cbETH</option><option value=\"0x085780639cc2cacd35e474e71f4d000e2405d8f6\">fxUSD</option><option value=\"0x9d39a5de30e57443bff2a8307a4256c8797a3497\">sUSDe</option></select>'+\n'<input id=\"o-asset\" class=\"sort-select\" placeholder=\"Deposit token address (optional)\">'+\n'<input id=\"o-search\" class=\"sort-select\" placeholder=\"Search asset or market\">'+\n'<button id=\"o-filter\" class=\"filterbtn\">Apply filters</button></div>'+\n'<p id=\"o-status\" class=\"small muted\">Reading cached public APIs…</p>'+\n'<div class=\"tablewrap\" style=\"overflow-x:auto\"><table><thead><tr><th>Protocol / opportunity</th><th>Deposit token / underlying basket</th><th>TVL (USD)</th><th>Source APR / APY</th><th>Source</th></tr></thead><tbody id=\"o-body\"></tbody></table></div>'+\n'<div style=\"padding:24px;display:flex;justify-content:center\"><button id=\"o-more\" class=\"filterbtn\">Load more</button></div>'+\n'<p id=\"o-diagnostics\" class=\"small muted\"></p>'+\n'<p class=\"overview-footnote\">Only direct single-ERC20 deposit opportunities are listed. LP tokens, baskets, dual-asset markets and all conversion candidates are excluded. APR and APY are reported separately. Exact source-bound protocol URLs are not claimed to have been individually browser-tested. Vault allocation requires separately verified adapters.</p></div>';\n$('o-filter').onclick=()=>{sort=$('o-sort').value;view='verified';protocol=$('o-protocol').value;quality=$('o-quality').value;asset=$('o-core').value||$('o-asset').value.trim().toLowerCase();search=$('o-search').value.trim();load(true)};\n$('o-more').onclick=()=>{if(visibleLimit<rows.length){visibleLimit+=100;render()}else load(false)};\nfunction render(){\n $('o-count').textContent=total.toLocaleString();\n $('o-updated').textContent=doc?.updatedAt?new Date(doc.updatedAt).toLocaleString():'—';\n $('o-lp-count').textContent=Number(doc?.lpCompositionCount||0).toLocaleString();\n $('o-links-exact').textContent=Number(doc?.linkStats?.marketSpecific||0).toLocaleString();\n $('o-links-dir').textContent=Number(doc?.linkStats?.missing||0).toLocaleString();\n $('o-status').textContent=(view==='research'?'Research only — native data, no vault deployment approval. ':'Verified direct deposit entries. ')+(doc?.partial?'Partial coverage. ':'')+(doc?.stale?'Last verified data; refresh overdue or incomplete. ':'')+(doc?.storage?.r2Catalog?'Persistent catalog; per-market rates are timestamped snapshots. ':'')+'Showing '+rows.length+' / '+total+' indexed Ethereum entries ('+(doc?.basketOnlyCount||0)+' underlying-basket entries; '+(doc?.indexOnlyCount||0)+' index-only records).';\n const lpDisplay=v=>{\n  const lp=v.lpComposition;if(!lp)return '';\n  const coins=Array.isArray(lp.coins)?lp.coins:[],under=Array.isArray(lp.underlyingCoins)?lp.underlyingCoins:[];\n  const item=c=>'<div style=\"display:flex;justify-content:space-between;gap:8px;padding:3px 0\"><span>'+esc(c.symbol||'Token')+' <small class=\"muted monospace\">'+esc((c.address||'').slice(0,8))+'…</small></span><b>'+(c.poolSharePct==null?'—':Number(c.poolSharePct).toFixed(1)+'%')+'</b></div>';\n  return '<details style=\"margin-top:8px\"><summary>LP constituents · '+coins.length+' coins</summary><div style=\"min-width:210px;padding:8px 0\">'+\n   (coins.map(item).join('')||esc(lp.symbolicComponents?.join(' · ')||'Component addresses unavailable'))+\n   (under.length?'<small class=\"muted\">Underlying: '+esc(under.map(c=>c.symbol).join(' · '))+'</small>':'')+\n   '<small class=\"muted\">Reserve shares estimated; single-token conversion requires a verified adapter quote.</small>'+\n   (lp.poolAddress?'<a class=\"mini-link\" href=\"https://etherscan.io/address/'+esc(lp.poolAddress)+'\" target=\"_blank\" rel=\"noopener\">Pool contract ↗</a>':'')+'</div></details>';\n };\n $('o-body').innerHTML=rows.slice(0,visibleLimit).map(v=>'<tr><td>'+((v.dappLinkType==='detail'||v.dappLinkType==='legacy-detail')&&v.dappUrl?'<a href=\"'+esc(v.dappUrl)+'\" target=\"_blank\" rel=\"noopener noreferrer\" title=\"Open '+esc(v.protocol)+' pool\"><b>'+esc(v.protocol)+'</b><div class=\"subvalue strong\" style=\"color:#9b6900\">'+esc(v.marketName)+' ↗</div></a><div class=\"tiny muted\">'+(v.dappLinkType==='legacy-detail'?'Legacy pool-specific app route · not yet verified':'Market-specific dapp')+'</div>':'<b>'+esc(v.protocol)+'</b><div class=\"subvalue\">'+esc(v.marketName)+'</div><div class=\"negative tiny\">Exact market frontend unresolved</div>')+\n (v.matchKind&&v.matchKind!=='direct-token'?'<small class=\"muted\">Matched via '+esc(v.matchKind.replaceAll('-',' '))+'</small>'+(v.conversionRoute?'<small class=\"muted\">Pool coin index: '+esc(v.conversionRoute.poolCoinIndex??'nested/unknown')+(v.conversionRoute.boosterPid!=null?' · Booster PID '+esc(v.conversionRoute.boosterPid):'')+' · Quote required</small>':''):'')+'</td>'+\n  '<td><b>'+esc(v.assetSymbol||'Token')+(v.additionalAssetSymbols?.length?' + '+esc(v.additionalAssetSymbols.join(' + ')):'')+'</b><div class=\"subvalue monospace\">'+esc(v.asset.slice(0,10)+'…'+v.asset.slice(-6))+'</div>'+lpDisplay(v)+'</td>'+\n  '<td>'+money(v.tvlUsdEstimate)+'</td><td>'+(v.lendApr==null?'<small class=\"muted\">Rate unavailable</small>':rate(v.lendApr)+' <small class=\"muted\">'+esc(v.rateType)+'</small>')+(Number(v.lendApr)>30?'<div class=\"negative tiny\">Extreme reported rate; independently verify sustainability and withdrawal depth</div>':'')+(v.rateWarning?'<div class=\"negative tiny\">'+esc(v.rateWarning)+'</div>':'')+(v.directDepositCompatible===false?'<div class=\"tiny muted\">'+esc(v.depositMode)+'</div>':'')+'</td>'+\n  '<td>'+(v.address?'<a class=\"mini-link\" href=\"https://etherscan.io/address/'+esc(v.address)+'\" target=\"_blank\" rel=\"noopener\">Contract ↗</a>':'Index only')+\n  (v.sourceUrl?.startsWith('https://')?' <a class=\"mini-link\" href=\"'+esc(v.sourceUrl)+'\" target=\"_blank\" rel=\"noopener\">API ↗</a>':'')+'</td></tr>').join('');\n $('o-more').style.display=visibleLimit<rows.length||offset<baseTotal?'':'none';\n $('o-protocol').innerHTML=['all',...Object.keys(doc?.counts||{}).sort()].map(p=>'<option value=\"'+esc(p)+'\" '+(p===protocol?'selected':'')+'>'+esc(p==='all'?'All protocols':p)+'</option>').join('');\n $('o-diagnostics').textContent='Provider status: '+(doc?.sourceStatus||[]).map(s=>s.name+' ('+s.status+')').join(' · ')+\n  (doc?.sourceFailures?.length?' · Errors: '+doc.sourceFailures.map(s=>s.source+': '+s.error).join('; '):'')+\n  (doc?.coverageWarnings?.length?' · Coverage gaps: '+doc.coverageWarnings.join('; '):'');\n}\nasync function load(reset){\n if(loading)return;loading=true;\n if(reset){rows=[];offset=0;baseTotal=0;visibleLimit=100;sourceDocs={};sourceIds={}}\n try{\n  const q=new URLSearchParams({view,sort,protocol,limit:'100',offset:String(offset)});\n  if(asset)q.set('asset',asset);if(search)q.set('q',search);if(quality==='high'){q.set('minYield','5');q.set('minTvl','1000000')}else if(quality==='premium'){q.set('minYield','8');q.set('minTvl','1000000')}else if(quality==='explore'){q.set('minYield','5');q.set('minTvl','100000')}\n  const baseResponse=await fetch('/api/opportunities?'+q),d=await baseResponse.json().catch(()=>null);\n  if(!baseResponse.ok||!Array.isArray(d?.opportunities))throw Error(d?.error||'Source API failed');\n  if(d.storage?.r2Catalog){\n   doc=d;baseTotal=d.total;total=d.total;offset+=d.opportunities.length;\n   rows=[...new Map([...rows,...d.opportunities].map(x=>[x.id,x])).values()];\n   render();return;\n  }\n  const pending=[];\n  if(reset)for(const spec of SOURCES){\n   const params=new URLSearchParams(q);params.set('limit','500');params.set('offset','0');\n   pending.push(fetch('/api/opportunities?source='+spec.key+'&'+params).catch(()=>null));\n  }\n  const responses=[baseResponse,...await Promise.all(pending)];\n  if(reset)for(let j=0;j<SOURCES.length;j++){\n   const spec=SOURCES[j],response=responses[j+1];\n   if(!response?.ok)continue;\n   const feed=await response.json().catch(()=>null);\n   if(!feed||feed.sourceFailures?.length||!Array.isArray(feed.opportunities)||\n     feed.total>feed.opportunities.length||\n     !feed.sourceStatus?.some(x=>x.name===spec.native&&x.status==='ok')||\n     (spec.gate&&!feed.sourceStatus.some(x=>x.name===spec.gate&&x.status==='ok')))continue;\n   sourceDocs[spec.key]=feed;\n   sourceIds[spec.key]=new Set(feed.opportunities.map(x=>x.id));\n  }\n  baseTotal=d.total;\n  const rowMap=new Map(rows.map(x=>[x.id,x]));\n  for(const x of d.opportunities){\n   const spec=SOURCES.find(s=>s.protocols.includes(x.protocol)&&sourceIds[s.key]);\n   if(spec&&!sourceIds[spec.key].has(x.id))continue;\n   rowMap.set(x.id,x);\n  }\n  // A source-bound verified record always takes precedence over a cached base record.\n  for(const spec of SOURCES)for(const x of sourceDocs[spec.key]?.opportunities||[])rowMap.set(x.id,x);\n  rows=[...rowMap.values()];\n  offset+=d.opportunities.length;\n  const counts={...(d.counts||{})},byProtocol={...(d.linkStats?.byProtocol||{})};\n  const replacedSources=new Set();\n  for(const spec of SOURCES){\n   const feed=sourceDocs[spec.key];if(!feed)continue;\n   replacedSources.add(spec.native);\n   for(const p of spec.protocols){\n    counts[p]=feed.counts?.[p]||0;\n    byProtocol[p]=feed.linkStats?.byProtocol?.[p]||{total:0,marketSpecific:0,legacyMarketSpecific:0,protocolDirectory:0,missing:0};\n   }\n  }\n  let modifiedTotal=d.total;\n  if(protocol==='all'&&!asset&&!search){\n   for(const spec of SOURCES)if(sourceDocs[spec.key]){\n    const baseGroup=spec.protocols.reduce((sum,p)=>sum+(d.counts?.[p]||0),0);\n    modifiedTotal+=sourceDocs[spec.key].total-baseGroup;\n   }\n  }else if(protocol!=='all'){\n   const spec=SOURCES.find(s=>s.protocols.includes(protocol)&&sourceDocs[s.key]);\n   if(spec)modifiedTotal=sourceDocs[spec.key].total;\n  }else modifiedTotal=Math.max(rows.length,d.total);\n  total=Math.max(0,modifiedTotal,rows.length);\n  const linkStats={total:0,marketSpecific:0,legacyMarketSpecific:0,protocolDirectory:0,missing:0,byProtocol};\n  for(const part of Object.values(byProtocol))for(const key of ['total','marketSpecific','legacyMarketSpecific','protocolDirectory','missing'])linkStats[key]+=Number(part[key]||0);\n  const sourceFailures=(d.sourceFailures||[]).filter(x=>!replacedSources.has(x.source));\n  const sourceStatus=[...(d.sourceStatus||[]).filter(x=>!replacedSources.has(x.name))];\n  for(const spec of SOURCES)if(sourceDocs[spec.key])sourceStatus.push(...sourceDocs[spec.key].sourceStatus);\n  doc={...d,count:Object.values(counts).reduce((n,x)=>n+Number(x||0),0),counts,linkStats,sourceFailures,\n   sourceStatus,partial:!!sourceFailures.length||!!d.coverageWarnings?.length,\n   coverageWarnings:[...(d.coverageWarnings||[]),\n    ...SOURCES.filter(s=>!sourceDocs[s.key]).map(s=>'Unverified source: '+s.key)]};\n  if(sort==='yield')rows.sort((x,y)=>(y.lendApr??-999)-(x.lendApr??-999)||y.tvlUsdEstimate-x.tvlUsdEstimate);\n  else if(sort==='asset')rows.sort((x,y)=>String(x.assetSymbol||x.asset).localeCompare(String(y.assetSymbol||y.asset))||y.tvlUsdEstimate-x.tvlUsdEstimate);\n  else rows.sort((x,y)=>y.tvlUsdEstimate-x.tvlUsdEstimate);\n  render();\n }catch(e){$('o-status').textContent=String(e?.message||e)}\n finally{loading=false}\n}load(true);\n})();"
const OP_HTML=HTML.replace('<script defer src="/assets/app.js"></script>','<script defer src="/assets/opportunities.js?v=188"></script>')
 .replace('CurveYield Markets · Fraxtal lending','CurveYield · Ethereum opportunities')
 .replace('CurveYield Markets — lend and borrow WFRAX, frxUSD and sfrxUSD against cysdFXS on Fraxtal, powered by Morpho Blue.',
   'Ethereum mainnet lending and yield vault opportunities indexed from public DeFi APIs.')
 .replace('<span class="chain-dot"></span>Fraxtal','<span class="chain-dot"></span>Ethereum')
 .replace('Non-custodial · Fraxtal chain 252','Non-custodial · Ethereum chain 1');

/* Markets v44 API-first catalog: zero RPC, R2, D1, or KV operations. */
const OP_TTL=900,OP_CACHE="https://markets.curveyield.org/__catalog_140",
 OP_RESEARCH_CACHE="https://markets.curveyield.org/__native_research_catalog_116";
const OP_ADDRESS=/^0x[0-9a-f]{40}$/i,OP_ID=/^0x[0-9a-f]{64}$/i;
const opAddr=x=>typeof x==="string"&&OP_ADDRESS.test(x)?x.toLowerCase():null;
const opNum=x=>x==null||x===""||!Number.isFinite(Number(x))?null:Number(x);
const opArray=x=>Array.isArray(x)?x:Array.isArray(x?.data)?x.data:Array.isArray(x?.vaults)?x.vaults:Array.isArray(x?.markets)?x.markets:[];
const opStates={verified:{memory:null,expire:0,promise:null},research:{memory:null,expire:0,promise:null},fraxlend:{memory:null,expire:0,promise:null},stakedao:{memory:null,expire:0,promise:null},ipor:{memory:null,expire:0,promise:null},fluid:{memory:null,expire:0,promise:null},gearbox:{memory:null,expire:0,promise:null},silo:{memory:null,expire:0,promise:null},spark:{memory:null,expire:0,promise:null},harvest:{memory:null,expire:0,promise:null},eulerearn:{memory:null,expire:0,promise:null},sky:{memory:null,expire:0,promise:null},curve:{memory:null,expire:0,promise:null},maple:{memory:null,expire:0,promise:null},yearn:{memory:null,expire:0,promise:null},morphoblue:{memory:null,expire:0,promise:null},morphov1:{memory:null,expire:0,promise:null},morphov2:{memory:null,expire:0,promise:null}};
function opName(s,details){
 const p=String(s||"").toLowerCase(),m=p+" "+String(details||"").toLowerCase();
 if(p.includes("aave"))return m.includes("v4")?"Aave V4":m.includes("v2")?"Aave V2":"Aave V3";
 if(p.includes("morpho"))return /vault.*v2/.test(m)?"Morpho Vault V2":/vault|meta/.test(m)?"Morpho Vault V1":/aave|compound/.test(m)?"Morpho Optimizer":"Morpho Blue";
 if(p.includes("spark"))return "SparkLend";
 if(p.includes("compound"))return /v2|compound-finance|c-token/.test(m)?"Compound II":"Compound III";
 if(p.includes("fluid"))return /smart/.test(m)?"Fluid Smart Lending":/vault/.test(m)?"Fluid Vaults":"Fluid Lending";
 if(p.includes("maple")||p.includes("syrup"))return /syrup/.test(m)?"Maple Syrup":"Maple Finance";
 if(p.includes("yearn"))return /v3/.test(m)?"Yearn V3":/v2/.test(m)?"Yearn V2":"Yearn Vaults";
 if(p.includes("beefy"))return "Beefy Vaults";
 if(p.includes("convex"))return "Convex Finance";
 if(p.includes("stake-dao")||p.includes("stakedao")||p.includes("stake dao"))return "Stake DAO";
 if(p.includes("ipor")||p.includes("fusion"))return "IPOR Fusion";
 if(p.includes("curve")&&/lend|llama/.test(m))return /v2/.test(m)?"CurveLend V2":"CurveLend V1";
 if(p.includes("fraxlend"))return "Fraxlend";
 return null;
}

/* v78 protocol-owned dapp links, with source-bound market or vault identity. */
function opDappLink(x,address,marketId,asset){
 const p=String(x.protocol||""),a=opAddr(address),m=String(x.marketName||""),sym=String(x.assetSymbol||"");
 const id=OP_ID.test(String(marketId||""))?String(marketId).toLowerCase():null;
 const detail=url=>({url,kind:"detail"}),unresolved=()=>({url:null,kind:"unresolved"});
 if(p==="Aave V3"){
  // The GraphQL display name is NOT the Aave app's marketName query argument.
  // These route keys are from Aave's documented frontend links and market pool identities.
  const raw=(String(x.aaveMarketName||"")+" "+m).toLowerCase();
  let slug="";
  if(a==="0x87870bca3f3fd6335c3f4ce8392d69350b4fa4e2")slug="proto_mainnet_v3";
  else if(a==="0x4e033931ad43597d96d6bcc25c280717730b58b1")slug="proto_lido_v3";
  else if(raw.includes("horizon"))slug="proto_horizon_v3";
  else if(raw.includes("lido"))slug="proto_lido_v3";
  else if(raw==="aavev3ethereum "+sym.toLowerCase()||raw.startsWith("aavev3ethereum "+sym.toLowerCase()+" "))slug="proto_mainnet_v3";
  return slug?detail("https://app.aave.com/reserve-overview/?underlyingAsset="+asset+"&marketName="+slug):unresolved();
 }
 if(p==="Aave V4"){
  let id4=String(x.aaveReserveId||"").trim();
  if(/^1::0x[0-9a-f]{40}::[0-9]+$/i.test(id4))id4=btoa(id4).replace(/=/g,"").replace(/\+/g,"-").replace(/\//g,"_");
  try{
   const decoded=atob(id4.replace(/-/g,"+").replace(/_/g,"/")+"==".slice(0,(4-id4.length%4)%4));
   return /^1::0x[0-9a-f]{40}::[0-9]+$/i.test(decoded)?
    detail("https://pro.aave.com/explore/reserve/"+id4):unresolved();
  }catch{return unresolved()}
 }
 if(p==="Aave V2")return unresolved();
 if(p==="Morpho Blue"){
  if(!id)return unresolved();
  const slug=m.toLowerCase().replace(/[^a-z0-9]+/g,"-").replace(/^-|-$/g,"").slice(0,80)||"market";
  return detail("https://app.morpho.org/ethereum/variable/"+id+"/"+slug);
 }
 if(p==="Morpho Vault V1"||p==="Morpho Vault V2"){
  if(!a)return unresolved();
  const slug=m.toLowerCase().normalize("NFKD").replace(/[̀-ͯ]/g,"")
   .replace(/[^a-z0-9]+/g,"-").replace(/^-|-$/g,"").slice(0,110);
  return slug?detail("https://app.morpho.org/ethereum/vault/"+a+"/"+slug):unresolved();
 }
 if(p==="Euler Earn")return a?detail("https://app.euler.finance/earn/"+a+"?network=ethereum"):unresolved();
 if(p==="Euler EVK")return a?detail("https://app.euler.finance/vault/"+a+"?network=ethereum"):unresolved();
 if(p==="Beefy Vaults"){
  const v=String(x.beefyVaultId||"");
  return /^[\w.-]{1,120}$/.test(v)?detail("https://app.beefy.com/vault/"+encodeURIComponent(v)):unresolved();
 }
 if(p==="Fraxlend"){
  // Frax officially keys the /fraxlend/pair page by loan asset and collateral;
  // links are ambiguous if multiple pair versions share the same tokens.
  const collateral=opAddr(x.collateralToken);
  return a&&collateral&&x.fraxUniquePair===true?
   detail("https://app.frax.finance/fraxlend/pair?asset="+asset+"&collateral="+collateral):
   unresolved();
 }
 if(p==="Yearn V2"||p==="Yearn V3"||p==="Yearn Vaults")return a?
  detail("https://yearn.fi/vaults/1/"+a):unresolved();
 if(p==="CurveLend V1"||p==="CurveLend V2"){
  // Curve API delivers its own canonical lendingVaultUrls.deposit,
  // generated from controllerAddress rather than the vault or onchain ID.
  const official=String(x.curveOfficialDepositUrl||"");
  try{
   const url=new URL(official);
   if(url.protocol==="https:"&&(url.hostname==="www.curve.finance"||url.hostname==="curve.finance")
    &&url.pathname.startsWith("/lend/ethereum/markets/")&&url.pathname.endsWith("/vault"))
    return detail(url.href);
  }catch{}
  const controller=opAddr(x.curveController);
  return controller?detail("https://www.curve.finance/lend/ethereum/markets/"+controller+"/vault"):unresolved();
 }
 // No source-bound verified 2026 deep route: old Maple hash routes are retired.
 if(p==="Maple Syrup"){
  // All three URLs are sourced from Maple's own product-specific Earn links.
  const canonical={
   "0x80ac24aa929eaf5013f6436cda2a7ba190f5cc0b":"usdc",
   "0x356b8d89c1e1239cbbb9de4815c39a1474d5ba7d":"usdt",
   "0x87b65c4aaffa76881f9e96f3e7ed945ddfc3cd7a":"usdg"};
  const slug=canonical[a];
  return slug&&String(x.assetSymbol||"").toLowerCase()===slug&&
   !!opAddr(x.depositRouter)&&!!opAddr(x.syrupWithdrawalManager)?
   detail("https://app.maple.finance/earn?asset="+slug):unresolved();
 }
 if(p==="Maple Finance")return unresolved();
 if(p==="Stake DAO"){
  // /yield?protocol=... is a directory, not a verified exact vault route.
  return unresolved();
 }
 if(p==="Stake DAO Lockers"){
  let locker=String(x.lockerSlug||sym).toLowerCase().replace(/^(sd|ve)/,"").replace(/[^a-z0-9]/g,"");
  const allowed=["crv","fxn","fxs","yb","ynd","yfi","pendle","bal","bpt","spectra","sdt","cvx"];
  return allowed.includes(locker)?detail("https://app.stakedao.org/lockers/"+locker):unresolved();
 }
 if(p==="Convex Finance"){
  const pid=Number(x.boosterPid);
  return x.boosterPid!=null&&Number.isSafeInteger(pid)&&pid>=0&&pid<2000?
   detail("https://curve.convexfinance.com/stake/ethereum/"+pid):unresolved();
 }
 if(p==="IPOR Fusion")return a?detail("https://app.ipor.io/fusion/ethereum/"+a+"/vault-info"):unresolved();
 if(p==="SparkLend"){
  // The SPK Farming Pool is a separate farm, not the Aave-style reserve.
  if(/farming|reward|staking/i.test(m))return unresolved();
  let token=asset;
  if(token==="0x0000000000000000000000000000000000000000"&&sym.toUpperCase()==="ETH")
   token="0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2";
  return opAddr(token)?detail("https://app.spark.finance/markets/1/"+token):unresolved();
 }
 if(p==="Compound III"){
  const market=String(x.compoundMarket||"").toLowerCase();
  return /^[a-z0-9]{2,20}$/.test(market)&&market===String(x.assetSymbol||"").toLowerCase()?
   detail("https://app.compound.xyz/?market="+market+"-mainnet"):unresolved();
 }
 if(p==="Sky Savings"){const known={USDS:"0xa3931d71877c0e7a3148cb7eb4463524fec27fbd",DAI:"0x83f20f44975d03b1b09e64809b757c47f942beea"};return a&&known[x.assetSymbol]===a?detail("https://app.spark.finance/savings/mainnet/s"+x.assetSymbol.toLowerCase()):unresolved();}
 if(p==="Spark Savings"){const map={USDC:["0x28b3a8fb53b741a8fd78c0fb9a6b2393d896a43d","spusdc"],USDT:["0xe2e7a17dff93280dec073c995595155283e3c372","spusdt"],WETH:["0xfe6eb3b609a7c8352a241f7f3a21cea4e9209b8f","speth"],PYUSD:["0x80128dbb9f07b93dde62a6daeadb69ed14a7d354","sppyusd"]};
  return a&&map[x.assetSymbol]?.[0]===a?detail("https://app.spark.finance/savings/mainnet/"+map[x.assetSymbol][1]):unresolved();}
 if(p==="Silo Vaults")return a?detail("https://app.silo.finance/vaults/ethereum-"+a):unresolved();
 if(p==="Harvest Finance")return a?detail("https://app.harvest.finance/ethereum/"+a):unresolved();
 if(p==="Gearbox Pools")return a?detail("https://app.gearbox.finance/earn/lp/1/"+a):unresolved();
 if(p==="Fluid Lending"){
  const token=String(x.fluidAssetSymbol||sym).toLowerCase().replace(/[^a-z0-9]/g,"");
  return token&&token.length<=28?detail("https://fluid.io/1/lending/"+token+"?mode=deposit"):unresolved();
 }
 if(p==="Fluid Vaults"){
  const vaultId=String(x.fluidVaultId||"");
  return /^[1-9][0-9]{0,5}$/.test(vaultId)?detail("https://fluid.io/1/borrowing/vaults/"+vaultId):unresolved();
 }
 if(p==="Fluid Smart Lending"){
  const pair=String(x.fluidPair||"");
  return /^[a-z0-9]+-[a-z0-9]+$/i.test(pair)?
   detail("https://fluid.io/smart-lending/1/"+pair):unresolved();
 }
 // Do not make homepages, generic protocol directories or explorer pages primary.
 return unresolved();
}
function opPut(out,x){
 const asset=opAddr(x.asset),tvl=opNum(x.tvlUsdEstimate);
 if(!asset||tvl===null||tvl<=100||!x.protocol)return;
 const address=opAddr(x.address),marketId=OP_ID.test(String(x.marketId||""))?String(x.marketId).toLowerCase():null;
 const poolId=String(x.poolId||"").slice(0,140);
  const dapp=opDappLink(x,address,marketId,asset);
  const rawRate=opNum(x.lendApr),checkedRate=rawRate!==null&&rawRate>=-100&&rawRate<=1000?rawRate:null;
 const id="1:"+String(x.protocol).toLowerCase()+":"+(address||marketId||poolId||asset)+":"+asset+":"+(marketId||"");
 const entry={id,chainId:1,protocol:String(x.protocol).slice(0,80),marketName:String(x.marketName||x.protocol).slice(0,140),
  asset,assetSymbol:String(x.assetSymbol||"").slice(0,35),address,marketId,poolId,tvlUsdEstimate:tvl,
  lendApr:checkedRate,rateType:x.rateType==="APR"?"APR":"APY",rateSource:String(x.rateSource||"").slice(0,110),
  utilizationPercent:opNum(x.utilizationPercent),tvlSource:String(x.tvlSource||"").slice(0,160),
  dappUrl:dapp.url,dappLinkType:dapp.kind,
   sourceUrl:String(x.sourceUrl||"").slice(0,220),adapterStatus:String(x.adapterStatus||"discovery_only_not_verified").slice(0,100),
  depositRouter:opAddr(x.depositRouter),syrupWithdrawalManager:opAddr(x.syrupWithdrawalManager),
  fraxUniquePair:x.fraxUniquePair===true,analyticsUrl:String(x.analyticsUrl||"").slice(0,245),
  fraxlendDeployer:opAddr(x.fraxlendDeployer),
  withdrawalStatus:String(x.withdrawalStatus||"").slice(0,110),
  availableWithdrawLiquidityUsd:opNum(x.availableWithdrawLiquidityUsd),
  depositCapacityRaw:String(x.depositCapacityRaw||"").slice(0,85),
  boosterPid:Number.isSafeInteger(Number(x.boosterPid))&&x.boosterPid!=null?Number(x.boosterPid):null,
  registryVerified:!!x.registryVerified,
   aaveMarketName:String(x.aaveMarketName||"").slice(0,100),aaveReserveId:String(x.aaveReserveId||"").slice(0,180),
   stakeDaoProtocol:String(x.stakeDaoProtocol||"").slice(0,40),curveMarketSlug:String(x.curveMarketSlug||"").slice(0,80),
   curveController:opAddr(x.curveController),curveOfficialDepositUrl:String(x.curveOfficialDepositUrl||"").slice(0,280),lockerSlug:String(x.lockerSlug||"").slice(0,40),
   fluidVaultId:String(x.fluidVaultId||"").slice(0,12),fluidPair:String(x.fluidPair||"").slice(0,70),
   fluidAssetSymbol:String(x.fluidAssetSymbol||"").slice(0,40),compoundMarket:String(x.compoundMarket||"").slice(0,35),
  convexReceiptToken:opAddr(x.convexReceiptToken),convexGauge:opAddr(x.convexGauge),
  lpComposition:x.lpComposition||null,depositAssetType:"erc20-or-unknown",singleTokenConversionStatus:"not_indexed",
   collateralToken:opAddr(x.collateralToken),collateralSymbol:String(x.collateralSymbol||"").slice(0,35),
  beefyVaultId:String(x.beefyVaultId||"").slice(0,120),beefyOracleId:String(x.beefyOracleId||"").slice(0,130),
  beefyAssetSymbols:Array.isArray(x.beefyAssetSymbols)?x.beefyAssetSymbols.map(z=>String(z).slice(0,40)):[]};
 entry.additionalAssets=Array.isArray(x.additionalAssets)?x.additionalAssets.map(opAddr).filter(Boolean):[];
 entry.additionalAssetSymbols=Array.isArray(x.additionalAssetSymbols)?x.additionalAssetSymbols.map(z=>String(z||"").slice(0,32)):[];
 entry.depositMode=String(x.depositMode||"single-token");
 entry.indexOnly=entry.depositMode.startsWith("underlying basket;")||(!address&&!marketId);
 entry.directDepositCompatible=x.directDepositCompatible!==false&&!entry.indexOnly;
 entry.rateWarning=rawRate!==null&&checkedRate===null?"Unverified provider rate suppressed (invalid or >1,000%)":null;
 const old=out.get(id);
 if(!old||String(x.sourceUrl||"").startsWith("https://hub.stakedao.org/")||(!old.registryVerified&&entry.registryVerified)||(!old.address&&entry.address))out.set(id,entry);
}
async function opGet(url){
 const r=await fetch(url,{headers:{accept:"application/json"},signal:AbortSignal.timeout(15000)});
 if(!r.ok)throw Error("HTTP "+r.status+" from "+new URL(url).hostname);
 return await r.json();
}

/* v91: strict source-bound Ethereum single-asset yield discoveries.
   A dapp URL must identify the actual official supply/vault interface.
   Native source identity establishes a trusted contract-specific route;
   wallet interactivity is not claimed to be individually browser-tested. */
const OP_KNOWN_UNAVAILABLE_DAPPS=new Set(["0xe4db1c5a1b709ce4d2ada6985d9d506e58f73829","0x0655977feb2f289a4ab78af67bab0d17aab84367","0xbe53a109b494e5c9f97b9cd39fe969be68bf6204","0xde6c23e561f3e55846207ec45a91b777e0f7c889","0xe48fc1a3fd6c3da483fb587d6c24151e402be02c","0x6bb9d07be70d5c2c80c30b469759be92f6405c6b","0xf5730f6f5bcc2a3e98da199f40b1a8af1ac37a43","0x5e577efb2807d106e2a8bdde3fc5fcffffc9ec13","0x6e77018ee146d520edfc05f7ca33585ccedc7ea8","0x1c7245863000722a71f98dc8ebfe704579f13056","0xec7fe6e856fab7b3f6f82787ae73bc70a1e70192","0xbff47bd3916c89f366fa7517049ce18808c6dbf7","0x7b5a0182e400b241b317e781a4e9dedfc1429822","0x696d02db93291651ed510704c9b286841d506987","0xf470eb50b4a60c9b069f7fd6032532b8f5cc014d","0x3ed6aa32c930253fc990de58ff882b9186cd0072","0x697c54a84d83f37380d034e2bfc6f7ce8d89f4ee","0x9cfb40acedac259b1d23e790f6c6d0c3898361ad","0x46e9893422b9ae9246793489433f72c548cb2455","0xd91b6ded55c0fba2c1e88f2cdf6e051ecd788952","0x620082f33d442e5806122f71a72b12134f75ff2d","0xf20b02131c45b22e147c98e30cc889a20dc8a00d"]);
function opAnnualizedApr(x){
 const y=opNum(x?.lendApr);
 if(y===null||y<=0||y>1000)return null;
 const apr=x.rateType==="APR"?y:Math.log1p(y/100)*100;
 return Number.isFinite(apr)?apr:null;
}
function opNativeDepositDapp(x){
 if(x.dappLinkType!=="detail"||!x.dappUrl||OP_KNOWN_UNAVAILABLE_DAPPS.has(x.address))return false;
 let u;
 try{u=new URL(x.dappUrl);if(u.protocol!=="https:"||u.username||u.password)return false}catch{return false}
 const p=x.protocol,a=x.address,id=x.marketId,asset=x.asset;
 if(p==="Morpho Blue")return !!id&&u.hostname==="app.morpho.org"&&
   u.pathname.startsWith("/ethereum/variable/"+id+"/");
 if(p==="Morpho Vault V1"||p==="Morpho Vault V2")return !!a&&
   u.hostname==="app.morpho.org"&&u.pathname.startsWith("/ethereum/vault/"+a+"/");
 if(p==="Yearn V2"||p==="Yearn V3")return !!a&&
   u.hostname==="yearn.fi"&&u.pathname==="/vaults/1/"+a;
 if(p==="Aave V3")return !!a&&u.hostname==="app.aave.com"&&
   u.pathname==="/reserve-overview/"&&u.searchParams.get("underlyingAsset")===asset&&
   /^proto_(mainnet|lido|horizon)_v3$/.test(u.searchParams.get("marketName")||"");
 if(p==="Aave V4")return !!a&&u.hostname==="pro.aave.com"&&
   /^\/explore\/reserve\/[A-Za-z0-9_-]+$/.test(u.pathname)&&!!x.aaveReserveId;
 if(p==="CurveLend V1"||p==="CurveLend V2")return !!a&&
   (u.hostname==="www.curve.finance"||u.hostname==="curve.finance")&&
   /^\/lend\/ethereum\/markets\/0x[a-f0-9]{40}\/vault$/i.test(u.pathname)&&
   !!x.curveController&&u.pathname.toLowerCase().includes(x.curveController);
 if(p==="Euler Earn")return !!a&&u.hostname==="app.euler.finance"&&
  u.pathname.toLowerCase()==="/earn/"+a&&u.searchParams.get("network")==="ethereum";
 if(p==="Euler EVK")return !!a&&u.hostname==="app.euler.finance"&&
   u.pathname.toLowerCase()==="/vault/"+a&&u.searchParams.get("network")==="ethereum";
 if(p==="Beefy Vaults")return !!a&&u.hostname==="app.beefy.com"&&
   u.pathname==="/vault/"+encodeURIComponent(x.beefyVaultId);
 if(p==="SparkLend")return !!asset&&u.hostname==="app.spark.finance"&&
   u.pathname.toLowerCase()==="/markets/1/"+asset;
 if(p==="Compound III")return !!a&&u.hostname==="app.compound.xyz"&&
   u.pathname==="/"&&u.searchParams.get("market")===String(x.compoundMarket||"").toLowerCase()+"-mainnet"&&
   String(x.assetSymbol||"").toLowerCase()===String(x.compoundMarket||"").toLowerCase();
 if(p==="Maple Syrup"){
  const allowed={
   "0x80ac24aa929eaf5013f6436cda2a7ba190f5cc0b":"usdc",
   "0x356b8d89c1e1239cbbb9de4815c39a1474d5ba7d":"usdt",
   "0x87b65c4aaffa76881f9e96f3e7ed945ddfc3cd7a":"usdg"};
  const slug=allowed[a];
  return !!slug&&!!opAddr(x.depositRouter)&&!!opAddr(x.syrupWithdrawalManager)&&
   String(x.assetSymbol||"").toLowerCase()===slug&&
   u.hostname==="app.maple.finance"&&u.pathname==="/earn"&&
   u.searchParams.get("asset")===slug;
 }
 if(p==="Fraxlend")return false; // Quarantine until pair-specific UI points at the requested contract.
 if(p==="Stake DAO Lockers")return ["crv","yb","fxn"].includes(x.lockerSlug)&&!!opAddr(x.depositRouter)&&
   u.hostname==="app.stakedao.org"&&u.pathname==="/lockers/"+x.lockerSlug;
 if(p==="Sky Savings")return !!a&&u.hostname==="app.spark.finance"&&
  u.pathname==="/savings/mainnet/s"+String(x.assetSymbol).toLowerCase()&&
  ({USDS:"0xa3931d71877c0e7a3148cb7eb4463524fec27fbd",DAI:"0x83f20f44975d03b1b09e64809b757c47f942beea"})[x.assetSymbol]===a;
 if(p==="Spark Savings")return !!a&&u.hostname==="app.spark.finance"&&
  ({USDC:["0x28b3a8fb53b741a8fd78c0fb9a6b2393d896a43d","spusdc"],USDT:["0xe2e7a17dff93280dec073c995595155283e3c372","spusdt"],WETH:["0xfe6eb3b609a7c8352a241f7f3a21cea4e9209b8f","speth"],PYUSD:["0x80128dbb9f07b93dde62a6daeadb69ed14a7d354","sppyusd"]})[x.assetSymbol]?.[0]===a&&
  u.pathname==="/savings/mainnet/"+({USDC:"spusdc",USDT:"spusdt",WETH:"speth",PYUSD:"sppyusd"})[x.assetSymbol];
 if(p==="Silo Vaults")return !!a&&u.hostname==="app.silo.finance"&&
  u.pathname.toLowerCase()==="/vaults/ethereum-"+a;
 if(p==="Harvest Finance")return !!a&&u.hostname==="app.harvest.finance"&&
  u.pathname.toLowerCase()==="/ethereum/"+a;
 if(p==="Gearbox Pools")return !!a&&u.hostname==="app.gearbox.finance"&&
  u.pathname.toLowerCase()==="/earn/lp/1/"+a;
 if(p==="Fluid Lending")return !!a&&u.hostname==="fluid.io"&&
   u.pathname.startsWith("/1/lending/")&&u.searchParams.get("mode")==="deposit";
 if(p==="IPOR Fusion")return !!a&&u.hostname==="app.ipor.io"&&
   u.pathname==="/fusion/ethereum/"+a+"/vault-info";
 return false;
}
function opEligibleDiscovery(x){
 // Original governance deposits into Stake DAO liquid lockers are permanently
 // locked. Unstaking sdTokens from a gauge does not redeem the original token.
 // Under CurveYield's same-asset immediate-withdrawal rule, exclude lockers
 // while leaving independently redeemable Stake DAO vaults eligible.
 if(x.protocol==="Stake DAO Lockers")return false;
 if(x.chainId!==1||!opAddr(x.asset)||!opAddr(x.address)||
    x.registryVerified!==true||x.indexOnly||x.directDepositCompatible!==true||
    x.depositMode!=="single-token"||x.depositAssetType!=="erc20-or-unknown"||
    x.lpComposition||x.additionalAssets?.length||x.beefyAssetSymbols?.length)return false;
 const symbol=String(x.assetSymbol||"").toLowerCase();
 if(!symbol||/^staked-g\(yb-/i.test(symbol)||
    /(?:^|[-_/])(?:lp|bpt|3crv|2crv|4crv)(?:$|[-_/])|(?:[-_]lp|crv-f)$/i.test(symbol))return false;
 const apr=opAnnualizedApr(x);
 return apr!==null&&apr>1&&opNativeDepositDapp(x);
}

async function opBuild(research=false, sourceOnly=null){
 let curveByLp=null,curveByCoins=null,convexPools=null,convexRpcCall=null;
 let fraxlendRegisteredCount=0,fraxlendDecodedCount=0,fraxlendPricedCount=0,fraxlendCatalogCount=0;
 const out=new Map(),failures=[],status=[],gaps=[],put=x=>opPut(out,x);
 // Re-enable source-bound discovery from existing collectors without restoring
 // DeFiLlama's unresolved synthetic/opague pool rows.
 const nativeSources=new Set(["IPOR Fusion v2",
 "Curve official Ethereum LP composition registry","Aave V4 native GraphQL Ethereum spoke reserves",
 "Aave V3 native GraphQL Ethereum market reserves","Yearn Kong REST V2/V3",
 "Yearn yDaemon official legacy vault reconciliation","Curve official Ethereum lending",
 "Fluid official fTokens","Fluid smart lending dual-token","Fluid collateral borrow vaults",
 "Euler EVK official Ethereum vaults","Beefy official vault/TVL/APY",
 "Beefy official LP component balances Ethereum","SparkLend Ethereum native reserves",
 "Compound III native Ethereum Comets","Morpho Blue complete Ethereum market index",
 "Stake DAO Hub comprehensive Ethereum VaultV2/V1","Stake DAO Hub lockers comprehensive",
 "Stake DAO native strategy registry","Stake DAO native locker registry",
 "Maple Finance official V2 pools","Convex Booster onchain batched pool registry",
 "Convex native receipt supply and Curve LP TVL",
 "Fraxlend native registry and pair-level Ethereum RPC",
 "Balancer official Ethereum BPT token composition"]);
 // The direct vault-eligible catalog retains the v104 provider set.
 // Research failures must not delay direct-market browsing.
 const directSources=new Set([
 "Curve official Ethereum LP composition registry",
 "Aave V4 native GraphQL Ethereum spoke reserves",
 "Aave V3 native GraphQL Ethereum market reserves",
 "Euler EVK official Ethereum vaults",
 "Beefy official vault/TVL/APY",
 "SparkLend Ethereum native reserves",
 "Compound III native Ethereum Comets"]);
 const allowedDiscoverySource=name=>sourceOnly?(name===sourceOnly||(sourceOnly==="IPOR Fusion v2"&&name==="IPOR onchain ERC4626 deposit capacity")||(sourceOnly==="Fluid official fTokens"&&name==="Fluid onchain ERC4626 deposit capacity")||(["Curve official Ethereum lending","Maple Finance official V2 pools","Yearn Kong REST V2/V3"].includes(sourceOnly)&&name==="Independent ERC4626 deposit eligibility")):(research?nativeSources:directSources).has(name)||(research&&(/^Morpho Vault V[12] bulk USD$/.test(name)||/^Morpho REST v0\/vaults-v[12]$/.test(name)));
 const collect=async(name,fn)=>{
  // v91: skip network requests to providers whose opportunities cannot meet
  // the native single-asset deposit + exact front-end + >1% yield rules.
  if(!allowedDiscoverySource(name))return;
  try{await fn();status.push({name,status:"ok"})}
  catch(e){failures.push({source:name,error:String(e?.message||e).slice(0,170)});status.push({name,status:"failed"})}};
 await collect("DeFiLlama yields",async()=>{
  const j=await opGet("https://yields.llama.fi/pools");if(!Array.isArray(j?.data))throw Error("Invalid yields schema");
  for(const p of j.data){
   if(String(p.chain||"").toLowerCase()!=="ethereum")continue;
   const protocol=opName(p.project,p.poolMeta);if(!protocol)continue;
   const addresses=Array.isArray(p.underlyingTokens)?p.underlyingTokens.map(x=>opAddr(x?.address||x)).filter(Boolean):[];
   // Convex's public index sometimes describes a basket of underlying pool coins,
   // NOT the actual depositable LP token. Preserve those records for aggregate
   // discovery, but never label them single-token compatible or permit allocation.
   const convexBasket=protocol==="Convex Finance"&&addresses.length>1;
   if(addresses.length===0||(addresses.length!==1&&!convexBasket))continue;
   const pool=String(p.pool||"");
   put({protocol,address:opAddr(pool),marketId:OP_ID.test(pool)?pool:null,poolId:pool,
    asset:addresses[0],assetSymbol:convexBasket?"Basket (unverified LP)":p.symbol,
    additionalAssets:convexBasket?addresses.slice(1):[],
    additionalAssetSymbols:convexBasket?[String(p.symbol||"Curve pool")]:[],
    depositMode:convexBasket?"underlying basket; LP deposit token not verified":"single-token",
    directDepositCompatible:!convexBasket,
    marketName:p.poolMeta||p.symbol||protocol,
    tvlUsdEstimate:p.tvlUsd,lendApr:p.apy,rateType:"APY",rateSource:"DeFiLlama public yields",
    sourceUrl:"https://yields.llama.fi/pools"});
  }
 });
 await Promise.all([
  collect("IPOR Fusion v2",async()=>{
   const j=await opGet("https://api.ipor.io/v2/fusion/vaults");
   if(!Array.isArray(j?.vaults))throw Error("Invalid IPOR schema");
   for(const v of j.vaults)if(Number(v.chainId)===1)put({protocol:"IPOR Fusion",address:v.address,asset:v.assetAddress,
    assetSymbol:v.asset,marketName:v.name,tvlUsdEstimate:v.tvl,lendApr:v.netApy??v.apy,rateType:"APY",
    rateSource:v.netApy!=null?"IPOR after-fees net APY":"IPOR before-fees APY",
    sourceUrl:"https://api.ipor.io/v2/fusion/vaults",registryVerified:true});
  }),
  collect("SparkLend Ethereum native reserves",async()=>{
 const registry="0x02c3ea4e34c0cbd694d2adfa2c690eecbc1793ee",mc="0xca11bde05977b3631167028862be2a173976ca11";
 const endpoints=["https://ethereum-rpc.publicnode.com","https://eth.llamarpc.com","https://eth.drpc.org"];
 const word=n=>BigInt(n).toString(16).padStart(64,"0"),addressWord=a=>a.slice(2).padStart(64,"0");
 const addr=s=>opAddr("0x"+s.slice(-40));
 const read=(s,o)=>{const h=s.slice(o*2,(o+32)*2);if(h.length!==64)throw Error("Spark ABI truncated");return BigInt("0x"+h)};
 let pref=0;
 const rpc=async(to,data)=>{
  let err;
  for(let n=0;n<endpoints.length;n++){
   const index=(pref+n)%endpoints.length;
   try{
    const r=await fetch(endpoints[index],{method:"POST",headers:{"content-type":"application/json"},
     body:JSON.stringify({jsonrpc:"2.0",id:1,method:"eth_call",params:[{to,data,gas:"0x1c9c380"},"latest"]}),
     signal:AbortSignal.timeout(18000)});
    const j=await r.json();
    if(!r.ok||j?.error||!/^0x[0-9a-f]+$/i.test(j?.result||""))
     throw Error("Spark RPC "+r.status+" "+JSON.stringify(j?.error||j).slice(0,140));
    pref=index;return j.result.toLowerCase();
   }catch(e){err=e}
  }
  throw err||Error("Spark RPC unavailable");
 };
 const locate=async sel=>{
  const h=(await rpc(registry,sel)).slice(2),a=addr(h);
  if(h.length!==64||!a||/^0x0{40}$/.test(a))throw Error("Spark registry address invalid");
  return a;
 };
 const [pool,provider,oracle]=await Promise.all([
  locate("0x026b1d5f"),locate("0xe860accb"),locate("0xfca513a8")]);
 const ret=(await rpc(pool,"0xd1946dbc")).slice(2),head=Number(read(ret,0));
 const count=Number(read(ret,head));
 if(!Number.isSafeInteger(count)||count<1||count>80||ret.length<(head+32+32*count)*2)
  throw Error("Spark reserve registry malformed");
 const assets=Array.from({length:count},(_,i)=>addr(ret.slice((head+32+i*32)*2,(head+64+i*32)*2)));
 if(assets.some(a=>!a)||new Set(assets).size!==count)throw Error("Spark reserve list invalid");
 const requests=assets.flatMap(a=>[
  {a,k:"data",to:provider,data:"0x35ea6a75"+addressWord(a)},
  {a,k:"config",to:pool,data:"0xc44b11f7"+addressWord(a)},
  {a,k:"caps",to:provider,data:"0x46fbe558"+addressWord(a)},
  {a,k:"price",to:oracle,data:"0xb3596f07"+addressWord(a)},
  {a,k:"symbol",to:a,data:"0x95d89b41"}]);
 const byAsset=new Map(assets.map(a=>[a,{}]));
 for(let start=0;start<requests.length;start+=40){
  const jobs=requests.slice(start,start+40);
  const tuples=jobs.map(q=>{
   const h=q.data.slice(2),len=h.length/2;
   return addressWord(q.to)+word(1)+word(96)+word(len)+h.padEnd(Math.ceil(len/32)*64,"0");
  });
  let cursor=jobs.length*32;
  const heads=tuples.map(t=>{const w=word(cursor);cursor+=t.length/2;return w});
  const buf=(await rpc(mc,"0x82ad56cb"+word(32)+word(jobs.length)+heads.join("")+tuples.join(""))).slice(2);
  const offset=Number(read(buf,0)),n=Number(read(buf,offset)),base=offset+32;
  if(n!==jobs.length)throw Error("Spark RPC batch count mismatch");
  for(let i=0;i<n;i++){
   const p=base+Number(read(buf,base+i*32)),success=read(buf,p)!==0n;
   const ptr=p+Number(read(buf,p+32)),len=Number(read(buf,ptr));
   if(!success||len<=0||len>4096)throw Error("Spark reserve read failed: "+jobs[i].k+" "+jobs[i].a);
   const value=buf.slice((ptr+32)*2,(ptr+32+len)*2);
   if(value.length!==len*2)throw Error("Spark batch return truncated");
   byAsset.get(jobs[i].a)[jobs[i].k]=value;
  }
 }
 const symbol=h=>{
  const offset=Number(read(h,0)),size=Number(read(h,offset));
  if(size<1||size>60||h.length<(offset+32+size)*2)throw Error("Spark ERC20 symbol malformed");
  const parts=h.slice((offset+32)*2,(offset+32+size)*2).match(/../g);
  return new TextDecoder().decode(Uint8Array.from(parts.map(p=>parseInt(p,16))));
 };
 const qualified=[];
 for(const a of assets){
  const d=byAsset.get(a),cfg=read(d.config,0);
  const active=(cfg>>56n&1n)!==0n,frozen=(cfg>>57n&1n)!==0n,paused=(cfg>>60n&1n)!==0n;
  const decimals=Number(cfg>>48n&255n);
  if(decimals>36)throw Error("Spark invalid token decimals");
  const total=Number(read(d.data,64))/10**decimals;
  const apr=Number(read(d.data,160))/1e27*100;
  const price=Number(read(d.price,0))/1e8;
  const cap=Number(read(d.caps,0)),tvl=total*price;
  if(!Number.isFinite(total)||!Number.isFinite(apr)||!Number.isFinite(tvl)||!Number.isSafeInteger(cap))
   throw Error("Spark reserve returned invalid numbers");
  if(!active||frozen||paused||apr<=1||tvl<=100||(cap>0&&total>=cap))continue;
  const sym=symbol(d.symbol);
  if(!/^[\w.-]{1,30}$/.test(sym))throw Error("Spark unrecognized token symbol");
  qualified.push({protocol:"SparkLend",address:pool,asset:a,assetSymbol:sym,
   marketName:"SparkLend "+sym,tvlUsdEstimate:tvl,lendApr:apr,rateType:"APR",
   rateSource:"Spark on-chain PoolDataProvider liquidityRate RAY",
   sourceUrl:"https://github.com/sparkdotfi/spark-address-registry/blob/master/src/Ethereum.sol",
   registryVerified:true,directDepositCompatible:true,depositMode:"single-token"});
 }
 for(const x of qualified)put(x);
}),
  collect("Compound III native Ethereum Comets",async()=>{
   // Discover current Comet market directories through Compound's maintained hardhat deployment imports.
   const official=async path=>{
    const hosts=["https://raw.githubusercontent.com/compound-finance/comet/main/",
     "https://cdn.jsdelivr.net/gh/compound-finance/comet@main/"];
    let last;
    for(const h of hosts){
     try{
      const resp=await fetch(h+path,{headers:{accept:"text/plain,application/json"},signal:AbortSignal.timeout(18000)});
      if(!resp.ok)throw Error("HTTP "+resp.status);
      const t=await resp.text();
      if(!t||t.length>250000)throw Error("Invalid source size");
      return t;
     }catch(e){last=e}
    }
    throw Error("Compound official source unavailable "+path+": "+String(last));
   };
   const textConfig=await official("hardhat.config.ts");
   const folders=[...new Set([...textConfig.matchAll(/from\s+['"]\.\/deployments\/mainnet\/([a-z0-9-]{2,30})\/relations['"]/g)].map(m=>m[1]))].sort();
   if(!folders.length||folders.length>50)throw Error("Compound mainnet deployment imports invalid");
   const roots=await Promise.all(folders.map(async name=>{
    const path="deployments/mainnet/"+name+"/roots.json";
    const url="https://raw.githubusercontent.com/compound-finance/comet/main/"+path;
    const comet=opAddr(JSON.parse(await official(path))?.comet);
    if(!comet)throw Error("Compound official Comet manifest invalid "+name);
    return {name,comet,url};
   }));
   if(new Set(roots.map(x=>x.comet)).size!==roots.length)throw Error("Compound duplicate Comet contracts");
   const mc="0xca11bde05977b3631167028862be2a173976ca11";
   const endpoints=["https://ethereum-rpc.publicnode.com","https://eth.llamarpc.com","https://eth.drpc.org"];
   const word=n=>BigInt(n).toString(16).padStart(64,"0"),aw=a=>a.slice(2).padStart(64,"0");
   const addr=h=>opAddr("0x"+h.slice(-40));
   const read=(h,off)=>{
    const w=h.slice(off*2,(off+32)*2);
    if(w.length!==64)throw Error("Compound ABI truncated at "+off);
    return BigInt("0x"+w);
   };
   let preferred=0;
   const rpc=async(to,data)=>{
    let last;
    for(let n=0;n<endpoints.length;n++){
     const ix=(preferred+n)%endpoints.length;
     try{
      const res=await fetch(endpoints[ix],{method:"POST",headers:{"content-type":"application/json"},
       body:JSON.stringify({jsonrpc:"2.0",id:1,method:"eth_call",params:[{to,data,gas:"0x1c9c380"},"latest"]}),
       signal:AbortSignal.timeout(18000)});
      const json=await res.json();
      if(!res.ok||json?.error||!/^0x[0-9a-f]+$/i.test(json?.result||""))
       throw Error("Compound RPC "+res.status+" "+JSON.stringify(json?.error||json).slice(0,100));
      preferred=ix;return json.result.toLowerCase();
     }catch(e){last=e}
    }
    throw last||Error("Compound Ethereum RPC unavailable");
   };
   const multi=async jobs=>{
    const ret=[];
    for(let start=0;start<jobs.length;start+=35){
     const section=jobs.slice(start,start+35),tuples=section.map(q=>{
      const h=q.data.slice(2),n=h.length/2;
      return aw(q.to)+word(1)+word(96)+word(n)+h.padEnd(Math.ceil(n/32)*64,"0");
     });
     let cursor=section.length*32;
     const heads=tuples.map(t=>{const h=word(cursor);cursor+=t.length/2;return h});
     const buffer=(await rpc(mc,"0x82ad56cb"+word(32)+word(section.length)+heads.join("")+tuples.join(""))).slice(2);
     const offset=Number(read(buffer,0)),count=Number(read(buffer,offset)),base=offset+32;
     if(count!==section.length)throw Error("Compound batch count mismatch");
     for(let i=0;i<count;i++){
      const p=base+Number(read(buffer,base+i*32)),success=read(buffer,p)!==0n;
      const ptr=p+Number(read(buffer,p+32)),len=Number(read(buffer,ptr));
      if(!success||len<=0||len>4096)throw Error("Compound Comet field failed "+section[i].name+" "+section[i].key);
      const h=buffer.slice((ptr+32)*2,(ptr+32+len)*2);
      if(h.length!==len*2)throw Error("Compound Comet batch truncated");
      ret.push({...section[i],result:h});
     }
    }
    return ret;
   };
   const byName=new Map(roots.map(x=>[x.name,{}]));
   const basic=[
    ["token","c55dae63"],["scale","44c1e5eb"],["feed","e7dad6bd"],["util","7eb71131"],
    ["supply","18160ddd"],["supplyPaused","0bc47ad1"],["withdrawPaused","67800b5f"]];
   const first=await multi(roots.flatMap(x=>basic.map(([key,selector])=>({
    name:x.name,key,to:x.comet,data:"0x"+selector
   }))));
   for(const x of first)byName.get(x.name)[x.key]=x.result;
   const nextCalls=[];
   for(const market of roots){
    const a=byName.get(market.name),util=read(a.util,0),feed=addr(a.feed);
    if(!feed)throw Error("Compound Comet base feed invalid "+market.name);
    a.feedAddress=feed;
    nextCalls.push(
      {name:market.name,key:"rate",to:market.comet,data:"0xd955759d"+word(util)},
      {name:market.name,key:"price",to:market.comet,data:"0x41976e09"+aw(feed)},
      {name:market.name,key:"symbol",to:addr(a.token),data:"0x95d89b41"},
      {name:market.name,key:"decimals",to:addr(a.token),data:"0x313ce567"});
   }
   for(const q of nextCalls)if(!q.to)throw Error("Compound Comet base token missing");
   const second=await multi(nextCalls);
   for(const x of second)byName.get(x.name)[x.key]=x.result;
   const parseSymbol=h=>{
    const off=Number(read(h,0)),len=Number(read(h,off));
    if(len<1||len>40||h.length<(off+32+len)*2)throw Error("Compound token symbol invalid");
    const octets=h.slice((off+32)*2,(off+32+len)*2).match(/../g);
    return new TextDecoder().decode(Uint8Array.from(octets.map(k=>parseInt(k,16))));
   };
   const feedPrice=async(feed)=>{
    const h=(await rpc(feed,"0xfeaf968c")).slice(2);
    if(h.length!==320)throw Error("Chainlink latestRoundData ABI malformed");
    const answer=read(h,32),updated=Number(read(h,96)),now=Math.floor(Date.now()/1000);
    if(answer<=0n||updated>now+120||now-updated>14400)throw Error("Chainlink USD price invalid/stale");
    const d=(await rpc(feed,"0x313ce567")).slice(2),dec=Number(read(d,0));
    if(dec<0||dec>18)throw Error("Chainlink USD decimals invalid");
    return Number(answer)/10**dec;
   };
   const qualified=[];
   for(const m of roots){
    const x=byName.get(m.name),sym=parseSymbol(x.symbol),token=addr(x.token);
    if(!token||sym.toLowerCase()!==m.name.toLowerCase())continue;
    const scale=Number(read(x.scale,0)),decimals=Number(read(x.decimals,0)),rawRate=Number(read(x.rate,0));
    const supply=Number(read(x.supply,0)),paused=read(x.supplyPaused,0)!==0n,
     withdrawPaused=read(x.withdrawPaused,0)!==0n;
    if(!Number.isFinite(scale)||scale<=0||decimals<0||decimals>36||
       scale!==10**decimals||!Number.isFinite(rawRate)||!Number.isFinite(supply))
     throw Error("Compound onchain token supply/scale invalid "+m.name);
    const apr=rawRate/1e18*31536000*100;
    if(!Number.isFinite(apr)||apr<=1||paused||withdrawPaused)continue;
    let usd=null;
    if(["USDC","USDT","USDS"].includes(sym))usd=Number(read(x.price,0))/1e8;
    else if(sym==="WETH")usd=await feedPrice("0x5f4ec3df9cbd43714fe2740f5e3616155c5b8419");
    else if(sym==="WBTC")usd=await feedPrice("0xf4030086522a5beea4988f8ca5b36dbc97bee88c");
    else if(sym==="wstETH"){
     const [eth,ratio]=await Promise.all([
      feedPrice("0x5f4ec3df9cbd43714fe2740f5e3616155c5b8419"),
      rpc(token,"0x035faf82")]);
     usd=eth*Number(read(ratio.slice(2),0))/1e18;
    }else continue; // Unknown denomination requires a source-bound USD oracle before listing.
    if(!Number.isFinite(usd)||usd<=0)throw Error("Compound USD price invalid "+m.name);
    const tvl=supply/scale*usd;
    if(tvl<=100)continue;
    qualified.push({protocol:"Compound III",address:m.comet,asset:token,assetSymbol:sym,
     compoundMarket:m.name,marketName:"Compound III "+sym+" Ethereum",
     tvlUsdEstimate:tvl,lendApr:apr,rateType:"APR",
     rateSource:"Compound III native Comet getSupplyRate annualized at live utilization",
     sourceUrl:m.url,registryVerified:true,directDepositCompatible:true,depositMode:"single-token"});
   }
   for(const x of qualified)put(x);
  }),
  collect("Beefy official vault/TVL/APY",async()=>{
   const [vaults,apy,tvl,fees]=await Promise.all(["vaults","apy","tvl","fees"].map(p=>opGet("https://api.beefy.finance/"+p)));
   if(!Array.isArray(vaults)||!fees||typeof fees!=="object")throw Error("Invalid Beefy vault/fee schemas");
   for(const v of vaults){
    if(!["ethereum","eth"].includes(String(v.chain||v.network).toLowerCase())||
       v.status!=="active"||v.type!=="standard"||
       !Array.isArray(v.assets)||v.assets.length<1||
       ["pendle","yb","yieldbasis"].includes(String(v.platformId||"").toLowerCase())||
       /^staked-g\(yb-/i.test(String(v.token||""))||
       /(?:^|[-_/])(?:lp|bpt)(?:$|[-_/])/i.test(String(v.token||"")))continue;
    // The direct ERC20 route deposits and withdraws the exact vault want token.
    // Withdrawal or deposit penalties are disqualifying, regardless of amount or time held.
    // Refresh published fee settings with each catalog build; never assume absent means zero.
    const fee=fees[v.id],withdraw=opNum(fee?.withdraw),deposit=opNum(fee?.deposit);
    const feeTime=opNum(fee?.lastUpdated);
    if(withdraw!==0||deposit!==0||feeTime===null||feeTime<=0||
       Date.now()-feeTime>172800000||feeTime>Date.now()+300000)continue;
    const address=opAddr(v.earnContractAddress),asset=opAddr(v.tokenAddress),rate=opNum(apy?.[v.id]);
    const suppliedTvl=opNum(tvl?.["1"]?.[v.id]);
    if(!address||!asset||rate===null||rate<0||rate>10||suppliedTvl===null)continue;
    put({protocol:"Beefy Vaults",address,asset,assetSymbol:v.token,marketName:v.name||v.id,
     beefyVaultId:v.id,beefyOracleId:v.oracleId||v.id,
     beefyAssetSymbols:v.assets.length>1?v.assets:[],
     tvlUsdEstimate:suppliedTvl,lendApr:rate*100,rateType:"APY",
     rateSource:"Beefy active standard vault API APY (deposit/withdraw fees both zero)",
     sourceUrl:"https://api.beefy.finance/vaults",registryVerified:true,
     directDepositCompatible:v.assets.length===1,
     depositMode:v.assets.length===1?"single-token":"LP-token vault (actual want token only)"});
   }
  }),





  collect("Curve official Ethereum LP composition registry",async()=>{
   const url="https://api.curve.finance/v1/getPools/all/ethereum";
   const resp=await fetch(url,{headers:{accept:"application/json"},signal:AbortSignal.timeout(28000)});
   if(!resp.ok)throw Error("Curve pool registry HTTP "+resp.status);
   const j=await resp.json();
   if(!Array.isArray(j?.data?.poolData)||j.success!==true)throw Error("Curve pool schema changed");
   const byLp=new Map(),byCoins=new Map(),candidateByLp=new Map();
   const validCoin=c=>{
    const addr=opAddr(c?.address);
    if(!addr||addr==="0x0000000000000000000000000000000000000000")return null;
    const decimals=Number(c?.decimals);
    const safeDecimals=Number.isInteger(decimals)&&decimals>=0&&decimals<=36?decimals:null;
    const raw=typeof c.poolBalance==="string"?c.poolBalance:String(c.poolBalance??"");
    const balance=safeDecimals==null||!/^\d+$/.test(raw)?null:Number(raw)/10**safeDecimals;
    const price=opNum(c.usdPrice);
    const usd=balance!=null&&Number.isFinite(balance)&&price!=null?balance*price:null;
    return {address:addr,symbol:String(c.symbol||"").slice(0,35),
     decimals:safeDecimals,poolBalanceRaw:/^\d+$/.test(raw)?raw:null,
     balance:balance!=null&&Number.isFinite(balance)?balance:null,
     usdPrice:price,usdValue:usd!=null&&Number.isFinite(usd)?usd:null,
     isBasePoolLpToken:!!c.isBasePoolLpToken};
   };
   for(const p of j.data.poolData){
    const lp=opAddr(p.lpTokenAddress||p.address),pool=opAddr(p.address);
    if(!lp||!pool)continue;
    const coins=(Array.isArray(p.coins)?p.coins:[]).map(validCoin).filter(Boolean);
    if(!coins.length)continue;
    const underlying=(Array.isArray(p.underlyingCoins)?p.underlyingCoins:[]).map(validCoin).filter(Boolean);
    const total=coins.reduce((v,c)=>v+(c.usdValue||0),0);
    const packed=coins.map(c=>({...c,poolSharePct:total>0&&c.usdValue!=null?100*c.usdValue/total:null}));
    const composition={
     lpToken:lp,poolAddress:pool,poolName:String(p.name||"").slice(0,100),
     lpSymbol:String(p.symbol||"").slice(0,40),poolRegistry:String(p.registryId||"").slice(0,45),
     tvlUsd:opNum(p.usdTotal),lpTotalSupplyRaw:String(p.totalSupply??""),gaugeAddress:opAddr(p.gaugeAddress),
     coins:packed,underlyingCoins:underlying,
     singleCoinCandidates:packed.map(c=>({address:c.address,symbol:c.symbol,
      requiresMetaRoute:!!c.isBasePoolLpToken,kind:"direct-pool-coin"})),
     underlyingCandidates:underlying.filter(c=>!packed.some(z=>z.address===c.address))
      .map(c=>({address:c.address,symbol:c.symbol,kind:"nested-underlying-candidate"})),
     compositionStatus:total>0?"pool-reserve-estimate":"token-identities-only",
     sourceUrl:url};
    // Keep the first nonbroken candidate if duplicate registry rows represent same pool.
    if(!byLp.has(lp)||(!p.isBroken&&(byLp.get(lp).isBroken)))byLp.set(lp,{...composition,isBroken:!!p.isBroken});
    const key=[...new Set(coins.map(c=>c.address))].sort().join(",");
    if(key){
     if(!byCoins.has(key))byCoins.set(key,[]);
     byCoins.get(key).push(composition);
    }
   }
   if(!byLp.size)throw Error("Curve registry contained no recognized LPs");
   curveByLp=byLp;curveByCoins=byCoins;
  }),
  collect("Stake DAO Hub comprehensive Ethereum VaultV2/V1",async()=>{
   const base="https://hub.stakedao.org/v1/vaults";
   let offset=0,finished=false,seen=new Set();
   for(let n=0;n<10;n++){
    const url=new URL(base);
    url.searchParams.set("chainId","1");url.searchParams.set("sort","tvl");
    url.searchParams.set("order","desc");url.searchParams.set("limit","500");
    url.searchParams.set("offset",String(offset));
    url.searchParams.set("fields","vault,lpToken,tvl,apr,name,protocol,version,chainId,isLending,streaming,coins,underlyingCoins");
    const j=await opGet(url.toString());
    if(!Array.isArray(j?.items)||!Number.isInteger(j?.total))throw Error("Stake DAO Hub schema changed");
    for(const v of j.items){
     const address=opAddr(v.vault),asset=opAddr(v.lpToken?.address);
     if(Number(v.chainId)!==1||!address||!asset)continue;
     if(seen.has(address))continue;
     seen.add(address);
     const rate=opNum(v.apr?.current?.total),tvl=opNum(v.tvl);
     const parseCoins=a=>(Array.isArray(a)?a:[]).map(c=>({
      address:opAddr(c?.address),symbol:String(c?.symbol||"").slice(0,35),
      decimals:Number.isInteger(Number(c?.decimals))?Number(c.decimals):null,
      balance:null,usdPrice:opNum(c?.price),usdValue:null,poolSharePct:null})).filter(c=>c.address);
     const depositCoins=parseCoins(v.coins),underlying=parseCoins(v.underlyingCoins);
     const lpFallback=depositCoins.length?{
      lpToken:asset,poolAddress:null,poolName:String(v.name||"Stake DAO LP"),
      lpSymbol:String(v.lpToken?.symbol||""),poolRegistry:"Stake DAO Hub",
      tvlUsd:opNum(v.tvl),gaugeAddress:null,coins:depositCoins,underlyingCoins:underlying,
      singleCoinCandidates:depositCoins.map(c=>({address:c.address,symbol:c.symbol,kind:"source-listed-component"})),
      underlyingCandidates:underlying.filter(c=>!depositCoins.some(z=>z.address===c.address))
       .map(c=>({address:c.address,symbol:c.symbol,kind:"nested-underlying-candidate"})),
      compositionStatus:"token-identities-only",sourceUrl:"https://hub.stakedao.org/v1/vaults"}:null;
     put({protocol:"Stake DAO",address,asset,stakeDaoProtocol:v.protocol,assetSymbol:v.lpToken?.symbol,lpComposition:lpFallback,
      marketName:"Stake DAO "+String(v.protocol||"")+" v"+String(v.version||"?")+" "+String(v.name||"Vault"),
      tvlUsdEstimate:tvl,lendApr:rate,rateType:"APR",
      rateSource:"Stake DAO Hub current total APR",sourceUrl:base,
      registryVerified:true,directDepositCompatible:true,
      depositMode:v.isLending?"lending-vault":"LP-token staking"});
    }
    offset+=j.items.length;
    if(offset>=j.total||j.items.length===0){finished=true;break}
   }
   if(!finished)gaps.push("Stake DAO Hub enumeration exceeds 5000 vaults");
  }),
  collect("Stake DAO Hub lockers comprehensive",async()=>{
   const endpoint="https://hub.stakedao.org/v1/lockers?chainId=1&limit=500&offset=0";
   const j=await opGet(endpoint),items=j?.items;
   if(!Array.isArray(items)||!Number.isInteger(j.total))throw Error("Stake DAO Hub locker schema changed");
   if(j.total>items.length)gaps.push("Stake DAO Hub lockers exceeded 500 records");
   for(const v of items){
    const address=opAddr(v.sdToken?.address),asset=opAddr(v.token?.address);
    if(!address||!asset||Number(v.chainId)!==1)continue;
    const rate=opNum(Array.isArray(v.apr)?v.apr[0]:null);
    put({protocol:"Stake DAO Lockers",address,asset,assetSymbol:v.token?.symbol,
     marketName:"Stake DAO "+String(v.symbol||v.protocol||"") + " locker",
     tvlUsdEstimate:v.tvl,lendApr:rate,rateType:"APR",
     rateSource:"Stake DAO Hub variable locker APR",sourceUrl:"https://hub.stakedao.org/v1/lockers",
     registryVerified:true,directDepositCompatible:false,
     depositMode:"vote-locked staking, withdrawal restrictions"});
   }
  }),
  collect("Stake DAO native strategy registry",async()=>{
   for(const group of ["curve","pendle","pancakeswap","balancer"]){
    const url="https://api.stakedao.org/api/strategies/"+group+"/1.json";
    const j=await opGet(url);
    if(!Array.isArray(j?.deployed))throw Error("Stake DAO "+group+" deployed schema changed");
    for(const v of j.deployed){
     if(Number(v.chainId)!==1)continue;
     const vault=opAddr(v.vault),lp=opAddr(v.lpToken?.address);
     if(!vault||!lp)continue;
     const tvl=opNum(v.tvl),current=opNum(v.apr?.current?.total);
     put({protocol:"Stake DAO",address:vault,asset:lp,stakeDaoProtocol:group,assetSymbol:v.lpToken?.symbol,
      marketName:"Stake DAO "+group+" "+String(v.name||v.key||""),
      tvlUsdEstimate:tvl,lendApr:current,rateType:"APR",
      rateSource:"Stake DAO API current total APR",sourceUrl:url,registryVerified:true,
      directDepositCompatible:true,depositMode:"LP-token staking"});
     // Stake DAO Curve snapshots also carry Convex pool registry metadata, including
     // the exact underlying LP, booster reward contract and Convex pool USD TVL.
     const c=v.convexPool,convexContract=opAddr(c?.crvRewards);
     if(group==="curve"&&c&&convexContract&&c.shutdown!==true){
      put({protocol:"Convex Finance",address:convexContract,asset:lp,
       assetSymbol:v.lpToken?.symbol,marketName:"Convex Curve "+String(v.name||v.key||""),
       tvlUsdEstimate:c.usdTotal,lendApr:null,rateType:"APR",
       rateSource:"Stake DAO cross-referenced Convex pool TVL (yield unavailable)",
       sourceUrl:url,registryVerified:true,
       depositRouter:"0xF403C135812408BFbE8713b5A23a04b3D48AAE31",boosterPid:c.id,
       adapterStatus:"requires_verified_Convex_Booster_and_LP_conversion_adapter",
       directDepositCompatible:true,depositMode:"Booster LP deposit then cvxLP reward staking"});
     }
    }
   }
  }),
  collect("Stake DAO native locker registry",async()=>{
   const url="https://api.stakedao.org/api/lockers",j=await opGet(url);
   const rows=Array.isArray(j?.parsed)?j.parsed:Array.isArray(j?.parsed?.lockers)?j.parsed.lockers:
    Array.isArray(j?.lockers)?j.lockers:[];
   if(!rows.length)throw Error("Stake DAO locker parsed schema empty");
   const safeSlugs=new Set(["crv","yb","fxn"]);
   for(const v of rows){
    const slug=String(v.id||"").toLowerCase();
    if(Number(v.chainId)!==1||!safeSlugs.has(slug))continue;
    const asset=opAddr(v.token?.address),address=opAddr(v.sdToken?.address),depositor=opAddr(v.modules?.depositor);
    if(!asset||!address||!depositor||!/^0x[0-9a-f]{8}$/i.test(v.extensions?.mintSig||""))continue;
    const rates=Array.isArray(v.apr)?v.apr.map(opNum).filter(z=>z!==null&&z>0&&z<=1000):[];
    put({protocol:"Stake DAO Lockers",address,asset,lockerSlug:slug,depositRouter:depositor,
     assetSymbol:v.token?.symbol,marketName:"Stake DAO "+String(v.symbol||v.protocol||"Locker"),
     tvlUsdEstimate:v.tvl,lendApr:rates.length?Math.min(...rates):null,
     rateType:"APR",rateSource:"Stake DAO locker API APR: governance token locked in exchange for liquid sdToken",
     sourceUrl:url,registryVerified:true,directDepositCompatible:true,depositMode:"single-token",
     withdrawalStatus:"Permanent lock: minted sdToken may trade but governance token is not directly redeemable",
     adapterStatus:"discovery_only_nonredeemable_underlying_vault_allocation_unsupported"});
   }
  }),

  collect("Aave V4 native GraphQL Ethereum spoke reserves",async()=>{
   const endpoint="https://api.v4.aave.com/graphql";
   const query="{ reserves(request:{query:{chainIds:[1]}}) { id chain {chainId} "+
    "spoke {address name} asset {underlying {address info {symbol}}} "+
    "summary { supplied { exchange {value} } supplyApy {normalized} } "+
    "status {frozen paused active} canSupply } }";
   const r=await fetch(endpoint,{method:"POST",headers:{"content-type":"application/json","accept":"application/json"},
    body:JSON.stringify({query}),signal:AbortSignal.timeout(15000)});
   const j=await r.json().catch(()=>null);
   if(!r.ok)throw Error("Aave V4 HTTP "+r.status+": "+JSON.stringify(j?.errors||j).slice(0,280));
   if(j?.errors?.length)throw Error("Aave V4 schema: "+j.errors.map(e=>e.message).join("; ").slice(0,320));
   if(!Array.isArray(j?.data?.reserves))throw Error("Aave V4 reserves response missing");
   for(const v of j.data.reserves){
    if(Number(v.chain?.chainId)!==1)continue;
    const token=v.asset?.underlying,contract=opAddr(v.spoke?.address);
    if(!token||!contract)continue;
    const tvl=opNum(v.summary?.supplied?.exchange?.value);
    const rate=opNum(v.summary?.supplyApy?.normalized);
    put({protocol:"Aave V4",address:contract,aaveReserveId:v.id,asset:token.address,assetSymbol:token.info?.symbol,
     marketName:String(v.spoke?.name||"Aave V4")+" "+String(token.info?.symbol||""),
     tvlUsdEstimate:tvl,lendApr:rate,rateType:"APY",
     rateSource:"Aave V4 native spoke supply APY",
     sourceUrl:endpoint,registryVerified:true,
     directDepositCompatible:!!v.canSupply&&v.status?.frozen!==true&&v.status?.paused!==true&&v.status?.active!==false,
     depositMode:v.canSupply===false?"supply-not-enabled":"single-token"});
   }
  }),
  collect("Aave V3 native GraphQL Ethereum market reserves",async()=>{
   const endpoint="https://api.v3.aave.com/graphql";
   const query="{ markets(request:{chainIds:[1]}) { name address chain {chainId} reserves { "+
    "underlyingToken {address symbol} aToken {address} size {usd} "+
    "isFrozen isPaused supplyInfo {apy {formatted} total {value}} } } }";
   const r=await fetch(endpoint,{method:"POST",
    headers:{"content-type":"application/json","accept":"application/json"},
    body:JSON.stringify({query}),signal:AbortSignal.timeout(14000)});
   const j=await r.json().catch(()=>null);
   if(!r.ok)throw Error("Aave API HTTP "+r.status+": "+JSON.stringify(j?.errors||j).slice(0,260));
   if(j?.errors?.length)throw Error("Aave schema: "+j.errors.map(e=>e.message).join("; ").slice(0,250));
   if(!Array.isArray(j?.data?.markets))throw Error("Aave markets array unavailable");
   for(const m of j.data.markets){
    if(Number(m.chain?.chainId)!==1)continue;
    for(const v of m.reserves||[]){
     const rate=opNum(v.supplyInfo?.apy?.formatted);
     put({protocol:"Aave V3",address:m.address,aaveMarketName:m.name,asset:v.underlyingToken?.address,
      assetSymbol:v.underlyingToken?.symbol,
      marketName:String(m.name||"Aave V3")+" "+String(v.underlyingToken?.symbol||""),
      tvlUsdEstimate:v.size?.usd,lendApr:rate,rateType:"APY",
      rateSource:"Aave V3 native reserve supply APY",
      sourceUrl:endpoint,registryVerified:true,
      directDepositCompatible:!v.isFrozen&&!v.isPaused,
      depositMode:v.isFrozen||v.isPaused?"frozen-or-paused-reserve":"single-token"});
    }
   }
  }),
  collect("Euler Earn official Ethereum curated vaults",async()=>{
  const base="https://v3.euler.finance/v3/earn/vaults", all=[];
  for(let off=0;off<1000;off+=100){
   const j=await opGet(base+"?chainId=1&limit=100&offset="+off);
   if(!Array.isArray(j?.data)||!Number.isInteger(j.meta?.total))throw Error("Euler Earn API schema");
   all.push(...j.data);
   if(all.length>=j.meta.total)break;
   if(j.data.length!==100||off>=900)throw Error("Euler Earn API incomplete enumeration");
  }
  const shortlist=all.filter(v=>v.chainId===1&&v.vaultType==="earn"&&
   v.visibility?.status==="visible"&&v.visibility?.explorableLend===true&&
   Number(v.supplyApy)>=5&&Number(v.supplyApy)<100&&Number(v.totalSupplyUsd)>=100000&&opAddr(v.address));
  const call=async(to,data)=>{
   let err;for(const url of ["https://eth.llamarpc.com","https://eth.drpc.org","https://ethereum-rpc.publicnode.com"]){
    try{const r=await fetch(url,{method:"POST",headers:{"content-type":"application/json"},
     body:JSON.stringify({jsonrpc:"2.0",id:1,method:"eth_call",params:[{to,data},"latest"]}),
     signal:AbortSignal.timeout(14000)});
     const j=await r.json();if(!r.ok||j.error||!/^0x[0-9a-f]{64}$/i.test(j.result||""))throw Error("Euler Earn RPC "+r.status+" "+JSON.stringify(j.error||j.result).slice(0,105));
     return BigInt(j.result);
    }catch(e){err=e}
   }throw err||Error("Ethereum read unavailable");
  };
  let qualified=0,pendingLiquidity=0,rejected=0;
  for(const entry of shortlist){
   const addr=opAddr(entry.address),d=(await opGet(base+"/1/"+addr))?.data;
   const asset=opAddr(d?.asset?.address),dec=Number(d?.asset?.decimals);
   const updated=Date.parse(String(d?.snapshotTimestamp||""));
   const tvl=Number(d?.totalSupplyUsd),available=Number(d?.availableAssetsUsd);
   if(!asset||!Number.isInteger(dec)||dec<0||dec>30||
      !Number.isFinite(updated)||Math.abs(Date.now()-updated)>86400000||
      !(tvl>=100000&&Number(d.supplyApy)>=5)){
    rejected++;continue;
   }
   if(!Array.isArray(d.strategies)||!d.strategies.some(x=>x.inWithdrawQueue===true&&
       BigInt(x.availableAssets||0)>0n)||!(available>=1000&&available/tvl>=0.005)){
    pendingLiquidity++;continue;
   }
   try{
    const [a,t,cap]=await Promise.all([
     call(addr,"0x38d52e0f"),call(addr,"0x01e1d114"),
     call(addr,"0x402d267d"+"000000000000000000000000000000000000000000000000000000000000dead")]);
    const matching=opAddr("0x"+a.toString(16).slice(-40).padStart(40,"0"))===asset;
    const live=Number(t)/10**dec;
    if(!matching||cap===0n||!(live>0)||
       Math.abs(live-Number(d.totalAssets)/10**dec)/Math.max(live,Number(d.totalAssets)/10**dec)>0.10){
     rejected++;continue;
    }
    put({protocol:"Euler Earn",address:addr,asset,assetSymbol:d.asset.symbol,
     marketName:d.name||"Euler Earn vault",tvlUsdEstimate:tvl,
     lendApr:Number(d.supplyApy),rateType:"APY",
     rateSource:"Euler Earn API net supply APY, current and rolling history",
     sourceUrl:base+"?chainId=1",registryVerified:true,
     directDepositCompatible:true,depositMode:"single-token",
     depositCapacityRaw:cap.toString(),availableWithdrawLiquidityUsd:available,
     withdrawalStatus:"Source-reported strategy withdrawal queue liquidity; not vault idle balance; dynamic and may revert",
     adapterStatus:"Discovery only; execution not tested"});
    qualified++;
   }catch(e){rejected++}
  }
  status.push({name:"Euler Earn strategy-aware withdrawal qualification",status:"ok",
   discovered:all.length,highYieldCandidates:shortlist.length,qualified,
   pendingStrategyLiquidity:pendingLiquidity,rejected});
 }),
 collect("Euler EVK official Ethereum vaults",async()=>{
   const base="https://v3.euler.finance/v3/evk/vaults?chainId=1&limit=100&offset=";
   let offset=0,complete=false;
   for(let page=0;page<100;page++){
    const j=await opGet(base+String(offset));
    if(!Array.isArray(j?.data)||!Number.isInteger(j?.meta?.total))throw Error("Euler V3 API schema changed");
    for(const v of j.data){
     if(Number(v.chainId)!==1||v.vaultType!=="evk"||v.isEscrow===true||
        v.visibility?.status!=="visible"||v.visibility?.explorableLend!==true)continue;
     const rate=opNum(v.supplyApy);
     const ts=Date.parse(String(v.snapshotTimestamp||""));
     if(!Number.isFinite(ts)||Math.abs(Date.now()-ts)>86400000)continue;
     put({protocol:"Euler EVK",address:v.address,asset:v.asset?.address,
      assetSymbol:v.asset?.symbol,marketName:v.name||"Euler eVault",tvlUsdEstimate:v.totalSupplyUsd,
      lendApr:rate,rateType:"APY",rateSource:"Euler native EVK supplyApy (percentage APY)",
      sourceUrl:"https://v3.euler.finance/v3/evk/vaults?chainId=1",registryVerified:true,
      directDepositCompatible:true,depositMode:"single-token"});
    }
    offset+=j.data.length;
    if(offset>=j.meta.total||j.data.length===0){complete=true;break}
   }
   if(!complete)gaps.push("Euler API inventory exceeds 10,000 vaults");
  }),
  collect("Maple Finance official V2 pools",async()=>{
   const endpoint="https://api.maple.finance/v2/graphql",pageSize=200;
   const all=[];let finished=false;
   for(let page=0;page<20;page++){
    const query="{ poolV2S(first:"+pageSize+",skip:"+(page*pageSize)+") { "+
     "id name tvl weeklyApy asset { id symbol decimals } "+
     "syrupRouter { id } withdrawalManagerQueue { id } } }";
    const response=await fetch(endpoint,{method:"POST",
     headers:{"content-type":"application/json","accept":"application/json"},
     body:JSON.stringify({query}),signal:AbortSignal.timeout(14000)});
    if(!response.ok)throw Error("Maple GraphQL HTTP "+response.status);
    const json=await response.json();
    if(json.errors?.length)throw Error(json.errors.map(e=>e.message).join("; ").slice(0,240));
    const batch=json.data?.poolV2S;
    if(!Array.isArray(batch))throw Error("Maple poolV2S schema changed");
    all.push(...batch);
    if(batch.length<pageSize){finished=true;break}
   }
   if(!finished)gaps.push("Maple pool inventory reached 4,000-entry scan cap");
   const knownSyrup=new Set([
    "0x80ac24aa929eaf5013f6436cda2a7ba190f5cc0b",
    "0x356b8d89c1e1239cbbb9de4815c39a1474d5ba7d",
    "0x87b65c4aaffa76881f9e96f3e7ed945ddfc3cd7a"]);
   // Maple's poolV2.tvl is NOT ERC-4626 vault totalAssets. For the three
   // documented single-token Syrup vaults read live totalAssets() on Ethereum,
   // then USD-price the actual underlying ERC20 token.
   const originals=all.filter(v=>knownSyrup.has(opAddr(v.id)));
   const underlying=[...new Set(originals.map(v=>opAddr(v.asset?.id)).filter(Boolean))];
   const usdQuote=underlying.length?
    await opGet("https://coins.llama.fi/prices/current/"+
     underlying.map(x=>"ethereum:"+x).join(",")):{coins:{}};
   if(!usdQuote?.coins||typeof usdQuote.coins!=="object")
    throw Error("Maple Syrup underlying USD pricing unavailable");
   const callTotalAssets=async pool=>{
    let last;
    for(const endpoint of ["https://ethereum-rpc.publicnode.com",
      "https://eth.llamarpc.com","https://eth.drpc.org"]){
     try{
      const r=await fetch(endpoint,{method:"POST",
       headers:{"content-type":"application/json"},
       body:JSON.stringify({jsonrpc:"2.0",id:1,method:"eth_call",
        params:[{to:pool,data:"0x01e1d114"},"latest"]}),
       signal:AbortSignal.timeout(17000)});
      const j=await r.json();
      if(!r.ok||j?.error||!/^0x[0-9a-f]{64}$/i.test(j?.result||""))
       throw Error("Maple totalAssets RPC invalid");
      return BigInt(j.result);
     }catch(e){last=e}
    }
    throw last||Error("Maple onchain vault totalAssets unavailable");
   };
   const nativeUsd=new Map();
   await Promise.all(originals.map(async v=>{
    const pool=opAddr(v.id),asset=opAddr(v.asset?.id),dec=Number(v.asset?.decimals);
    if(!pool||!asset||!Number.isInteger(dec)||dec<0||dec>24)
     throw Error("Maple vault asset identity or decimals invalid");
    const price=opNum(usdQuote.coins["ethereum:"+asset]?.price);
    if(price===null||price<=0||price>100000)
     throw Error("Maple Syrup price unavailable for "+asset);
    const raw=await callTotalAssets(pool);
    const usd=Number(raw)/10**dec*price;
    if(!Number.isFinite(usd)||usd<=0)throw Error("Maple vault TVL invalid "+pool);
    nativeUsd.set(pool,usd);
   }));
   for(const v of all){
    const address=opAddr(v.id),asset=opAddr(v.asset?.id);
    if(!address||!asset)continue;
    const router=opAddr(v.syrupRouter?.id),queue=opAddr(v.withdrawalManagerQueue?.id);
    const isSyrup=knownSyrup.has(address)||!!router;
    const tvl=opNum(v.tvl),apy=opNum(v.weeklyApy);
    const slug={
     "0x80ac24aa929eaf5013f6436cda2a7ba190f5cc0b":"usdc",
     "0x356b8d89c1e1239cbbb9de4815c39a1474d5ba7d":"usdt",
     "0x87b65c4aaffa76881f9e96f3e7ed945ddfc3cd7a":"usdg"}[address];
    const sourceIdentifiedSyrup=!!slug&&String(v.asset?.symbol||"").toLowerCase()===slug&&!!router&&!!queue;
    // Never substitute the opaque GraphQL pool TVL for vault totalAssets.
    if(!sourceIdentifiedSyrup||!nativeUsd.has(address))continue;
    put({protocol:"Maple Syrup",address,asset,
     assetSymbol:v.asset?.symbol,marketName:v.name||"Maple V2 lending pool",
     depositRouter:router,syrupWithdrawalManager:queue,
     withdrawalStatus:isSyrup?"withdrawal-queue-can-delay-redemptions-up-to-30-days":null,
     analyticsUrl:slug?"https://maple.finance/transparency/products/syrup"+slug:null,
     tvlUsdEstimate:nativeUsd.get(address),
     tvlSource:"Ethereum ERC4626 totalAssets() / underlying decimals × live token USD quote",
     reportedPoolTvlUsd:tvl==null?null:tvl/1e6,
     lendApr:apy==null?null:apy/1e28,rateType:"APY",
     rateSource:"Maple native GraphQL weekly APY (1e28 percentage units)",
     sourceUrl:endpoint,registryVerified:true,
     directDepositCompatible:sourceIdentifiedSyrup,
     depositMode:sourceIdentifiedSyrup?"single-token":
      isSyrup?"syrup-pool-unverified-router-or-symbol":"institutional-permissioned-lending"});
   }
  }),
  collect("Yearn Kong REST V2/V3",async()=>{
   const j=await opGet("https://kong.yearn.fi/api/rest/list/vaults/1");
   if(!Array.isArray(j))throw Error("Yearn Kong list schema changed");
   for(const v of j){
    if(Number(v.chainId)!==1||!opAddr(v.asset?.address))continue;
    // Kong also indexes non-Yearn ERC4626 products: classify only confirmed Yearn vaults.
    const version=String(v.apiVersion||"");
    const yearnV3=Boolean(v.v3)&&version.startsWith("3.");
    const yearnV2=/^0\.[234]\./.test(version);
    if(!yearnV3&&!yearnV2)continue;
    const rate=opNum(v.performance?.oracle?.netAPY??v.performance?.oracle?.apy??
      v.performance?.estimated?.apy??v.performance?.historical?.net);
    put({protocol:yearnV3?"Yearn V3":"Yearn V2",address:v.address,
     asset:v.asset.address,assetSymbol:v.asset.symbol,marketName:v.name||v.symbol,
     tvlUsdEstimate:v.tvl,lendApr:rate==null?null:rate*100,rateType:"APY",
     rateSource:"Yearn Kong net APY",sourceUrl:"https://kong.yearn.fi/api/rest/list/vaults/1",
     registryVerified:true});
   }
  }),
  collect("Curve official Ethereum lending",async()=>{
   const endpoint="https://api.curve.finance/v1/getLendingVaults/all/ethereum";
   const j=await opGet(endpoint);
   const rows=j?.data?.lendingVaultData;if(!Array.isArray(rows))throw Error("Curve lending schema changed");
   for(const v of rows){
    const a=v.assets?.borrowed;
    if(!opAddr(a?.address))continue;
    const version=/v2|lending-v2|llamalend-v2/.test(String(v.registryId||v.version||v.type||"").toLowerCase())
      ?"CurveLend V2":"CurveLend V1";
    put({protocol:version,address:v.address,curveMarketSlug:v.id||v.marketId||v.poolId,
      curveController:v.controllerAddress,curveOfficialDepositUrl:v.lendingVaultUrls?.deposit,
      asset:a.address,assetSymbol:a.symbol,marketName:v.name,
     tvlUsdEstimate:v.totalSupplied?.usdTotal??v.usdTotal,lendApr:opNum(v.rates?.lendApyPcent)??(
      opNum(v.rates?.lendApy)==null?null:v.rates.lendApy*100),
     rateType:"APY",rateSource:"Curve Lending official API",sourceUrl:endpoint,registryVerified:true});
   }
  }),
  collect("Fluid official fTokens",async()=>{
   const endpoint="https://api.fluid.instadapp.io/v2/lending/1/tokens";
   const j=await opGet(endpoint),arr=opArray(j);
   if(!arr.length)throw Error("Fluid lending fToken API returned no records");
   for(const v of arr){
    const a=v.asset||{},address=opAddr(v.address),asset=opAddr(v.assetAddress||a.address);
    const decimals=Number(a.decimals),assets=Number(v.totalAssets),price=Number(a.price);
    const native=opNum(v.totalRate??v.supplyRate);
    if(!address||!asset||v.isNativeUnderlying===true||!Number.isInteger(decimals)||
       decimals<0||decimals>36||!Number.isFinite(assets)||assets<=0||
       !Number.isFinite(price)||price<=0||native===null)continue;
    const staking=opNum(a.stakingApr);
    const stakingBps=staking!==null&&staking>=0&&staking<=10000?staking:0;
    // Fluid publishes totalRate excluding any underlying staking and external
    // reward campaigns. All three components are basis points (not %).
    const activeRewards=opArray(v.rewards).filter(r=>
      r?.type==="supply"&&opAddr(r?.token?.address)&&
      r?.metadata?.restricted!==true&&Number(r?.endTime)>Date.now()&&
      opNum(r?.rate)!==null&&opNum(r.rate)>=0&&opNum(r.rate)<=10000);
    const bonusBps=activeRewards.reduce((n,r)=>n+opNum(r.rate),0);
    const tvl=assets/10**decimals*price;
    if(!Number.isFinite(tvl)||native<0)continue;
    put({protocol:"Fluid Lending",address,asset,fluidAssetSymbol:a.symbol,
     assetSymbol:a.symbol,marketName:v.name||v.symbol||"Fluid fToken",
     tvlUsdEstimate:tvl,lendApr:(native+stakingBps+bonusBps)/100,rateType:"APR",
     rateSource:"Fluid API native "+(native/100).toFixed(2)+"%"+
      (stakingBps?" + underlying staking "+(stakingBps/100).toFixed(2)+"%":"")+
      (bonusBps?" + active external rewards "+(bonusBps/100).toFixed(2)+"%":""),
     sourceUrl:endpoint,registryVerified:true,directDepositCompatible:true,depositMode:"single-token"});
   }
  }),
  collect("Fluid smart lending dual-token",async()=>{
   const endpoint="https://api.fluid.instadapp.io/v2/smart-lending/1/tokens",arr=opArray(await opGet(endpoint));
   if(!arr.length)throw Error("Fluid smart-lending API empty");
   for(const v of arr){
    const a=v.tokens?.token0,b=v.tokens?.token1,x=opAddr(a?.address),y=opAddr(b?.address);
    if(!x||!y)continue;
    const da=Number(a.decimals),db=Number(b.decimals),na=opNum(v.totalUnderlyingAssetsToken0),
     nb=opNum(v.totalUnderlyingAssetsToken1),pa=opNum(a.price),pb=opNum(b.price);
    if(!Number.isInteger(da)||!Number.isInteger(db)||da>36||db>36||[na,nb,pa,pb].some(n=>n==null))continue;
    put({protocol:"Fluid Smart Lending",address:v.address,fluidPair:String(a.symbol||"")+"-"+String(b.symbol||""),asset:x,assetSymbol:a.symbol,
     additionalAssets:[y],additionalAssetSymbols:[b.symbol],depositMode:"dual-token",
     directDepositCompatible:false,marketName:v.name||v.symbol,
     tvlUsdEstimate:na/10**da*pa+nb/10**db*pb,lendApr:null,rateType:"APR",
     rateSource:"Dual-asset variable rates",sourceUrl:endpoint,registryVerified:true});
   }
  }),
  collect("Fluid collateral borrow vaults",async()=>{
   const endpoint="https://api.fluid.instadapp.io/v2/borrowing/1/vaults",arr=opArray(await opGet(endpoint));
   if(!arr.length)throw Error("Fluid borrow API empty");
   for(const v of arr){
    const a=v.supplyToken?.token0,b=v.supplyToken?.token1,x=opAddr(a?.address),y=opAddr(b?.address);
    if(!x)continue;
    const da=Number(a.decimals),na=opNum(v.liquiditySupplyData?.token0?.supply),pa=opNum(a.price);
    if(!Number.isInteger(da)||da>36||na==null||pa==null)continue;
    let tvl=na/10**da*pa;
    if(y){
     const db=Number(b.decimals),nb=opNum(v.liquiditySupplyData?.token1?.supply),pb=opNum(b.price);
     if(!Number.isInteger(db)||db>36||nb==null||pb==null)continue;
     tvl+=nb/10**db*pb;
    }
    put({protocol:"Fluid Vaults",address:v.address,fluidVaultId:v.id,asset:x,assetSymbol:a.symbol,
     additionalAssets:y?[y]:[],additionalAssetSymbols:y?[b.symbol]:[],
     depositMode:"collateral-borrowing",directDepositCompatible:false,
     marketName:"Fluid borrowing vault "+String(v.id||""),tvlUsdEstimate:tvl,lendApr:null,
     rateType:"APR",rateSource:"Collateral supply estimate (not deposit APY)",
     sourceUrl:endpoint,registryVerified:true});
   }
  })
 ]);

// Gearbox official Ethereum native pool registry; no leverage strategies
 // and no main-catalog subrequests. Verify instant unborrowed withdrawals.
 await collect("Gearbox official Ethereum passive ERC4626 pools",async()=>{
  const registry="https://raw.githubusercontent.com/Gearbox-protocol/static/main/src/pools/index.ts";
  const response=await fetch(registry,{signal:AbortSignal.timeout(15000)});
  if(!response.ok)throw Error("Gearbox pool registry HTTP "+response.status);
  const source=await response.text();
  if(!source.includes("POOLS_LIST"))throw Error("Gearbox native pool registry schema changed");
  const records=[...source.matchAll(/\{\s*name:\s*"([^"]+)"\s*,\s*address:\s*"(0x[a-fA-F0-9]{40})"\s*,\s*chainId:\s*(\d+)\s*,\s*network:\s*"([^"]+)"/g)]
   .filter(m=>m[3]==="1"&&m[4]==="Mainnet")
   .map(m=>({name:m[1],address:m[2].toLowerCase()}));
  if(!records.length||records.length>100)throw Error("Gearbox Ethereum pool registry absent or oversized");
  const unique=[...new Map(records.map(x=>[x.address,x])).values()];
  const mc="0xca11bde05977b3631167028862be2a173976ca11",
   word=n=>BigInt(n).toString(16).padStart(64,"0");
  const selectors=[
   ["asset","38d52e0f"],["assets","01e1d114"],["rate","ad2961a3"],
   ["maxDeposit","402d267d"+word("0x000000000000000000000000000000000000dead")],
   ["liquid","74375359"],["fee","e941fa78"]];
  const jobs=unique.flatMap(pool=>selectors.map(([field,data])=>({pool,field,data})));
  const vals=new Map();
  for(let start=0;start<jobs.length;start+=48){
   const batch=jobs.slice(start,start+48);
   const tuples=batch.map(x=>x.pool.address.slice(2).padStart(64,"0")+
    word(1)+word(96)+word(x.data.length/2)+x.data.padEnd(Math.ceil(x.data.length/64)*64,"0"));
   let cursor=batch.length*32;
   const offsets=tuples.map(t=>{const o=word(cursor);cursor+=t.length/2;return o});
   const data="0x82ad56cb"+word(32)+word(batch.length)+offsets.join("")+tuples.join("");
   let buffer=null,last=null;
   for(const rpc of ["https://eth.llamarpc.com","https://eth.drpc.org","https://ethereum-rpc.publicnode.com"]){
    try{
     const r=await fetch(rpc,{method:"POST",headers:{"content-type":"application/json"},
      body:JSON.stringify({jsonrpc:"2.0",id:1,method:"eth_call",params:[{to:mc,data,gas:"0x1c9c380"},"latest"]}),
      signal:AbortSignal.timeout(19000)});
     const j=await r.json();
     if(!r.ok||j.error||!/^0x[0-9a-f]+$/i.test(j.result||""))throw Error("Gearbox RPC "+r.status);
     buffer=j.result.slice(2);break;
    }catch(e){last=e}
   }
   if(!buffer)throw last||Error("Gearbox native pool RPC failed");
   const read=p=>{const h=buffer.slice(p*2,(p+32)*2);if(h.length!==64)throw Error("Gearbox multicall truncated");return Number(BigInt("0x"+h))};
   const root=read(0),num=read(root),base=root+32;
   if(num!==batch.length)throw Error("Gearbox multicall response count mismatch");
   for(let i=0;i<num;i++){
    const job=batch[i],p=base+read(base+i*32);
    const success=read(p)!==0,d=read(p+32),size=read(p+d),
     hex=buffer.slice((p+d+32)*2,(p+d+32+size)*2);
    const row=vals.get(job.pool.address)||{};
    if(success&&size===32&&hex.length===64)row[job.field]=hex;
    vals.set(job.pool.address,row);
   }
  }
  const assets=[...new Set(unique.map(p=>opAddr("0x"+String(vals.get(p.address)?.asset||"").slice(-40))).filter(Boolean))];
  if(!assets.length)throw Error("Gearbox: no ABI-verified Ethereum underlying assets");
  const quotes=await opGet("https://coins.llama.fi/prices/current/"+
   assets.map(a=>"ethereum:"+a).join(","));
  let priced=0,published=0,excluded=0;
  for(const pool of unique){
   const val=vals.get(pool.address),asset=opAddr("0x"+String(val?.asset||"").slice(-40));
   const price=quotes?.coins?.["ethereum:"+asset],decimals=Number(price?.decimals);
   if(!asset||!val?.assets||!val?.rate||!val?.maxDeposit||!val?.liquid||!val?.fee||
      !Number.isInteger(decimals)||decimals<0||decimals>30||
      !Number.isFinite(price?.price)||price.price<=0||
      Math.abs(Date.now()/1000-Number(price.timestamp||0))>43200){excluded++;continue}
   priced++;
   const tvl=Number(BigInt("0x"+val.assets))/10**decimals*price.price;
   const available=Number(BigInt("0x"+val.liquid))/10**decimals*price.price;
   const apr=Number(BigInt("0x"+val.rate)*1000000000n/1000000000000000000000000000n)/10000000;
   if(!Number.isFinite(tvl)||tvl<=100||!Number.isFinite(available)||available<1000||
      available/tvl<0.005||apr<=1||apr>1000||BigInt("0x"+val.maxDeposit)===0n||
      BigInt("0x"+val.fee)!==0n){excluded++;continue}
   put({protocol:"Gearbox Pools",address:pool.address,asset,assetSymbol:price.symbol,
    marketName:"Gearbox "+pool.name,tvlUsdEstimate:tvl,lendApr:apr,rateType:"APR",
    rateSource:"Gearbox PoolV3 current onchain supplyRate RAY; incentives excluded",
    sourceUrl:registry,registryVerified:true,directDepositCompatible:true,depositMode:"single-token",
    depositCapacityRaw:BigInt("0x"+val.maxDeposit).toString(),availableWithdrawLiquidityUsd:available,
    withdrawalStatus:"Instant same-asset withdrawals subject to available unborrowed liquidity",
    adapterStatus:"ERC4626 candidate; Vault V2 allocation requires separate verification"});
   published++;
  }
  status.push({name:"Gearbox live native market qualification",status:"ok",
   discovered:unique.length,decoded:vals.size,priced,published,excluded});
 });
 
// Harvest source-native Ethereum single-token vaults; ERC4626 and idle withdrawal
// eligibility via Multicall3. Exclude locked/LP/redeem-in-kind products.
 await collect("Harvest official Ethereum vault registry API",async()=>{
  const endpoint="https://api.harvest.finance/vaults?key=harvest-key";
  const data=await opGet(endpoint),rows=Object.values(data?.eth||{});
  if(!rows.length||rows.length>500)throw Error("Harvest API Ethereum vault inventory missing or oversized");
  const symbols={
   "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48":"USDC",
   "0xdac17f958d2ee523a2206206994597c13d831ec7":"USDT",
   "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2":"WETH",
   "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599":"WBTC",
   "0x6b175474e89094c44da98b954eedeac495271d0f":"DAI",
   "0xdc035d45d973e3ec169d2276ddab16f1e407384f":"USDS",
   "0x7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0":"wstETH"};
  const candidates=rows.filter(x=>String(x?.chain)==="1"&&x.inactive===false&&
   symbols[opAddr(x.tokenAddress)]&&opAddr(x.vaultAddress)&&x.redeemInKindEnabled!==true&&
   Number(x.estimatedApy)>1&&Number(x.estimatedApy)<=1000&&Number(x.totalValueLocked)>100);
  if(!candidates.length)throw Error("Harvest active mainstream positive-yield inventory missing");
  const tokens=[...new Set(candidates.map(x=>opAddr(x.tokenAddress)))];
  const prices=await opGet("https://coins.llama.fi/prices/current/"+
   tokens.map(x=>"ethereum:"+x).join(","));
  const mc="0xca11bde05977b3631167028862be2a173976ca11",
   word=n=>BigInt(n).toString(16).padStart(64,"0"),
   jobs=candidates.flatMap(x=>{
    const addr=opAddr(x.vaultAddress),asset=opAddr(x.tokenAddress);
    return [["asset",addr,"38d52e0f"],["tvl",addr,"01e1d114"],
     ["capacity",addr,"402d267d"+word("0x000000000000000000000000000000000000dead")],
     ["idle",asset,"70a08231"+addr.slice(2).padStart(64,"0")]]
     .map(([field,to,call])=>({addr,field,to,call}));
   });

  // Extend the EXISTING Harvest Multicall3 batches with bounded withdrawal evidence:
  // 52 initial calls + 24 strategy reads still fit within the original 2 RPC batches.
  const hD="0xab7fa2b2985bccfc13c6d86b1d5a17486ab1e04c",hsD="0x19641d708940d3764652a7e9b52ab1b7f0829fe3",vD="0x500331c9ff24d9d11aee6b07734aa72343ea74a5";
  const hU="0xf0358e8c3cd5fa238a29301d0bea3d63a17bedbe",hsU="0xd8b26062d52614c4c12be552a1e9292f2af14154",vU="0x55c1b6e461a6334b567baf0feb5d728715446f05";
  const ma="0xa2f362079dbc570a6df5bd04ad91002d17c0db9a",morpho="0xbbbbbbbbbb9cc5e90e3b3af64bdaf62c37eeffcb",mId="0x1e9d614631a7df0ec07fb05b2c8cb2491575fd1a63a33bf187a6afb295a4fc64";
  const mParams="000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000ecfafdc7741323a945a163ed068b5a3c43483957000000000000000000000000217d6ddcdb95112c51657f6270e8c079cfdb51f0000000000000000000000000870ac11d48b15db9a138cf899d20f13f79ba00bc0000000000000000000000000000000000000000000000000cb2bba6f17b8000";
  const addProof=(addr,field,to,call)=>jobs.push({addr,field,to,call});
  if(candidates.some(x=>opAddr(x.vaultAddress)===hD)){
   const arg=hsD.slice(2).padStart(64,"0");
   addProof(hD,"dStrategy",hD,"a8c62e76");
   addProof(hD,"dImpl",hsD,"5c60da1b");
   addProof(hD,"dVault",hsD,"5169379c");
   addProof(hD,"dAsset",vD,"38d52e0f");
   addProof(hD,"dMax",vD,"ce96cb77"+arg);
  }
  if(candidates.some(x=>opAddr(x.vaultAddress)===hU)){
   const arg=hsU.slice(2).padStart(64,"0"),id=mId.slice(2);
   addProof(hU,"uStrategy",hU,"a8c62e76");
   addProof(hU,"uImpl",hsU,"5c60da1b");
   addProof(hU,"uVault",hsU,"5169379c");
   addProof(hU,"uAsset",vU,"38d52e0f");
   addProof(hU,"uAdapter",vU,"ad468d11");
   addProof(hU,"uLiqData",vU,"2e029228");
   addProof(hU,"uMorpho",ma,"d8fbc833");
   addProof(hU,"uParent",ma,"0fe36536");
   addProof(hU,"uMarketParams",morpho,"2c3c9157"+id);
   addProof(hU,"uSendShares",vU,"8e511e4d"+arg);
   addProof(hU,"uReceiveAssets",vU,"0d326b18"+arg);
   addProof(hU,"uSendAssets",vU,"20fe8d58"+arg);
   addProof(hU,"uReceiveShares",vU,"98c9b49c"+arg);
   addProof(hU,"uAdapterAssets",ma,"99f7e861"+id);
   addProof(hU,"uMarket",morpho,"5c60e39a"+id);
   addProof(hU,"uMorphoCash","0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48","70a08231"+morpho.slice(2).padStart(64,"0"));
   addProof(hU,"uV2Cash","0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48","70a08231"+vU.slice(2).padStart(64,"0"));
   addProof(hU,"uCurrentSupplied",hsU,"59932db2");
  }
  const results=new Map();
  for(let start=0;start<jobs.length;start+=40){
   const batch=jobs.slice(start,start+40);
   const tuples=batch.map(x=>x.to.slice(2).padStart(64,"0")+
    word(1)+word(96)+word(x.call.length/2)+x.call.padEnd(Math.ceil(x.call.length/64)*64,"0"));
   let cursor=batch.length*32;
   const offsets=tuples.map(t=>{const o=word(cursor);cursor+=t.length/2;return o});
   const callData="0x82ad56cb"+word(32)+word(batch.length)+offsets.join("")+tuples.join("");
   let buf=null,last=null;
   for(const rpc of ["https://eth.llamarpc.com","https://eth.drpc.org","https://ethereum-rpc.publicnode.com"]){
    try{
     const r=await fetch(rpc,{method:"POST",headers:{"content-type":"application/json"},
      body:JSON.stringify({jsonrpc:"2.0",id:1,method:"eth_call",params:[
       {to:mc,data:callData,gas:"0x1c9c380"},"latest"]}),signal:AbortSignal.timeout(19000)});
     const j=await r.json();
     if(!r.ok||j.error||!/^0x[0-9a-f]+$/i.test(j.result||""))throw Error("Harvest RPC "+r.status);
     buf=j.result.slice(2);break;
    }catch(e){last=e}
   }
   if(!buf)throw last||Error("Harvest batched RPC unavailable");
   const read=p=>{const h=buf.slice(p*2,(p+32)*2);
    if(h.length!==64)throw Error("Harvest multicall truncated");return Number(BigInt("0x"+h))};
   const root=read(0),count=read(root),base=root+32;
   if(count!==batch.length)throw Error("Harvest multicall item count");
   for(let i=0;i<count;i++){
    const job=batch[i],pos=base+read(base+i*32);
    const success=read(pos)!==0,off=read(pos+32),len=read(pos+off);
    const hex=buf.slice((pos+off+32)*2,(pos+off+32+len)*2);
    const row=results.get(job.addr)||{};
    if(success&&len>=32&&len<=224&&len%32===0&&hex.length===len*2)row[job.field]=hex;
    results.set(job.addr,row);
   }
  }
  let published=0,notERC4626=0,pendingStrategyLiquidity=0,rejectedTvlMismatch=0,rejected=0,strategyReadFailures=0;
  for(const v of candidates){
   const addr=opAddr(v.vaultAddress),asset=opAddr(v.tokenAddress),
    record=results.get(addr)||{},p=prices?.coins?.["ethereum:"+asset];
   const dec=Number(p?.decimals),usd=Number(p?.price),apy=Number(v.estimatedApy);
   const onchainAsset=record.asset?opAddr("0x"+record.asset.slice(-40)):null;
   if(!record.tvl||!record.capacity||!record.idle||onchainAsset!==asset||
      BigInt("0x"+record.capacity)===0n){notERC4626++;continue}
   if(!Number.isInteger(dec)||dec<0||dec>30||!(usd>0)||
      Math.abs(Date.now()/1000-Number(p.timestamp||0))>43200){rejected++;continue}
   const tvl=Number(BigInt("0x"+record.tvl))/10**dec*usd;
   const idle=Number(BigInt("0x"+record.idle))/10**dec*usd;
   if(!(tvl>100)||Math.abs(tvl-Number(v.totalValueLocked))/Math.max(tvl,Number(v.totalValueLocked))>0.3){
    rejectedTvlMismatch++;continue;
   }

   // Harvest vaults may invest all idle assets; inspect pinned verified strategy
   // and the designated immediate exit only. Multicall3 shares existing RPC budget.
   let available=idle;
   let withdrawalStatus="Immediate same-token ERC4626 exit, idle balance lower bound only";
   if(idle<1000||idle/tvl<0.005){
    const strat=opAddr(v.strategyAddress),aw=x=>opAddr("0x"+x.slice(-40));
    const proofOk=(fields)=>fields.every(f=>record[f]&&/^[0-9a-f]+$/i.test(record[f]));
    if(addr===hD&&strat===hsD){
     try{
      if(!proofOk(["dStrategy","dImpl","dVault","dAsset","dMax"])||
       aw(record.dStrategy)!==hsD||
       aw(record.dImpl)!=="0x39036815d0f958738b35cc3ad15bd56db1f1589c"||
       aw(record.dVault)!==vD||aw(record.dAsset)!==asset)throw Error("DAI route proof unavailable/changed");
      available=Math.min(tvl,idle+Number(BigInt("0x"+record.dMax))/10**dec*usd);
      withdrawalStatus="Same-token withdrawal through verified Morpho V1 strategy; capacity is an upper bound, not execution proof";
     }catch(e){strategyReadFailures++}
    }else if(addr===hU&&strat===hsU){
     try{
      const fields=["uStrategy","uImpl","uVault","uAsset","uAdapter","uLiqData",
       "uMorpho","uParent","uMarketParams","uSendShares","uReceiveAssets",
       "uSendAssets","uReceiveShares","uAdapterAssets","uMarket",
       "uMorphoCash","uV2Cash","uCurrentSupplied"];
      if(!proofOk(fields)||aw(record.uStrategy)!==hsU||
       aw(record.uImpl)!=="0x7de301e5136bec68aa625c308213ac9dc1c2118a"||
       aw(record.uVault)!==vU||aw(record.uAsset)!==asset||
       aw(record.uAdapter)!==ma||aw(record.uMorpho)!==morpho||aw(record.uParent)!==vU||
       record.uLiqData!==word(32)+word(160)+mParams||
       record.uMarketParams!==mParams||
       ["uSendShares","uReceiveAssets","uSendAssets","uReceiveShares"]
        .some(f=>BigInt("0x"+record[f])!==1n))throw Error("USDC V2 route proof unavailable/changed");
      const mk=record.uMarket;
      if(mk.length!==384)throw Error("USDC Morpho market response changed");
      const supply=BigInt("0x"+mk.slice(0,64)),borrow=BigInt("0x"+mk.slice(128,192));
      if(supply<=borrow)throw Error("USDC Morpho market has no idle");
      const liquid=[BigInt("0x"+record.uAdapterAssets),supply-borrow,
       BigInt("0x"+record.uMorphoCash)].reduce((a,b)=>a<b?a:b);
      const redeemable=[BigInt("0x"+record.uCurrentSupplied),
       BigInt("0x"+record.uV2Cash)+liquid].reduce((a,b)=>a<b?a:b);
      available=Math.min(tvl,idle+Number(redeemable)/10**dec*usd);
      withdrawalStatus="Same-token exit via verified Morpho V2 liquidity adapter; upper-bound estimate, not execution proof";
     }catch(e){strategyReadFailures++}
    }
    if(available<1000||available/tvl<0.005){pendingStrategyLiquidity++;continue}
   }
   put({protocol:"Harvest Finance",address:addr,asset,assetSymbol:symbols[asset],
    marketName:"Harvest "+String(v.platform?.[0]||v.id).slice(0,80)+" "+symbols[asset],
    tvlUsdEstimate:tvl,lendApr:apy,rateType:"APY",
    rateSource:"Harvest official API estimatedApy net of fees",
    tvlSource:"Harvest official API plus Ethereum ERC4626 totalAssets",
    sourceUrl:endpoint,registryVerified:true,directDepositCompatible:true,
    depositMode:"single-token",availableWithdrawLiquidityUsd:available,
    depositCapacityRaw:BigInt("0x"+record.capacity).toString(),
    withdrawalStatus,
    adapterStatus:"Discovery only; no OmniAdapter compatibility asserted"});
   published++;
  }
  status.push({name:"Harvest ERC4626 and withdrawal liquidity qualification",status:"ok",
   discovered:rows.length,candidates:candidates.length,checked:results.size,published,
   rejectedNotERC4626OrClosed:notERC4626,pendingStrategyWithdrawalVerification:pendingStrategyLiquidity,rejectedTvlMismatch,
   rejectedPrice:rejected,pendingStrategyReadFailures:strategyReadFailures});
 });
 
// Sky onchain ERC4626 savings and RAY APY, fail closed.
 await collect("Sky official Ethereum Savings ERC4626 contracts",async()=>{
  const defs=[["USDS","0xa3931d71877c0e7a3148cb7eb4463524fec27fbd","0xdc035d45d973e3ec169d2276ddab16f1e407384f","0x03607ceb",null],
   ["DAI","0x83f20f44975d03b1b09e64809b757c47f942beea","0x6b175474e89094c44da98b954eedeac495271d0f","0x487bf082","0x197e90f9fad81970ba7976f33cbd77088e5d7cf7"]];
  const rpc=async(to,data)=>{let err;for(const url of ["https://eth.llamarpc.com","https://eth.drpc.org","https://ethereum-rpc.publicnode.com"]){try{
   const r=await fetch(url,{method:"POST",headers:{"content-type":"application/json"},
    body:JSON.stringify({jsonrpc:"2.0",id:1,method:"eth_call",params:[{to,data},"latest"]}),signal:AbortSignal.timeout(16000)});
   const j=await r.json();if(!r.ok||j.error||!/^0x[0-9a-f]{64}$/i.test(j.result||""))throw Error("Sky RPC");return BigInt(j.result);
  }catch(e){err=e}}throw err||Error("Sky RPC failed")};
  const prices=await opGet("https://coins.llama.fi/prices/current/"+defs.map(x=>"ethereum:"+x[2]).join(","));
  let qualified=0,filtered=0;
  for(const [sym,vault,underlying,selector,rateTarget] of defs){try{
   const [asset,tvl,cap,rate]=await Promise.all([rpc(vault,"0x38d52e0f"),rpc(vault,"0x01e1d114"),
    rpc(vault,"0x402d267d"+"000000000000000000000000000000000000000000000000000000000000dead"),
    rpc(rateTarget||vault,selector)]);
   const p=prices?.coins?.["ethereum:"+underlying],usd=Number(p?.price),dec=Number(p?.decimals),
    volume=Number(tvl)/10**dec*usd,apy=100*Math.expm1(31536000*Math.log(Number(rate)/1e27));
   if(opAddr("0x"+asset.toString(16).padStart(64,"0").slice(-40))!==underlying||
    cap<=0n||!(usd>0&&Number.isInteger(dec)&&dec===18&&volume>1000&&apy>1&&apy<1000)||
    Math.abs(Date.now()/1000-Number(p.timestamp||0))>43200){filtered++;continue}
   put({protocol:"Sky Savings",address:vault,asset:underlying,assetSymbol:sym,
    marketName:"Sky Savings "+sym,tvlUsdEstimate:volume,lendApr:apy,rateType:"APY",
    rateSource:"Sky onchain SSR/Pot DSR per-second RAY annualized",
    sourceUrl:"https://developers.skyeco.com/protocol/tokens/susds/",
    registryVerified:true,directDepositCompatible:true,depositMode:"single-token",
    depositCapacityRaw:cap.toString(),
    withdrawalStatus:"Sky instant same-asset ERC4626 redemption; no lock",
    adapterStatus:"ERC4626 candidate; OmniAdapter allocation must be verified"});
   qualified++;
  }catch(e){filtered++}}
  status.push({name:"Sky onchain SSR and DSR verification",status:"ok",discovered:2,qualified,filtered});
 });
 
// Spark Savings V2 official REST + onchain capacity/liquidity checks.
// Only native USDC and USDT direct synchronous withdrawals within verified buffer.
 await collect("Spark official Ethereum Savings V2 REST",async()=>{
  const verified=[["usdc","0x28B3a8fb53B741A8Fd78c0fb9A6B2393d896a43d","0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"],
   ["usdt","0xe2e7a17dFf93280dec073C995595155283e3C372","0xdac17f958d2ee523a2206206994597c13d831ec7"]];
  const rpc=async(to,data)=>{
   let e;for(const url of ["https://eth.llamarpc.com","https://eth.drpc.org","https://ethereum-rpc.publicnode.com"]){
    try{const r=await fetch(url,{method:"POST",headers:{"content-type":"application/json"},
      body:JSON.stringify({jsonrpc:"2.0",id:1,method:"eth_call",params:[{to,data},"latest"]}),
      signal:AbortSignal.timeout(16000)});
     const j=await r.json();if(!r.ok||j.error||!/^0x[0-9a-f]{64}$/.test(j.result||""))throw Error("Spark RPC");return j.result;
    }catch(x){e=x}
   }throw e||Error("Spark RPC unavailable");
  };
  let published=0,filtered=0;
  for(const [token,contract,underlying] of verified){
   const r=await fetch("https://api.spark.fi/v1/savings/spark/mainnet/"+token,{signal:AbortSignal.timeout(18000)});
   const j=await r.json(),d=j?.data;
   if(!r.ok||!d||opAddr(d.vault?.address)!==opAddr(contract)||
      opAddr(d.asset?.address)!==opAddr(underlying)){filtered++;continue}
   const tvl=Number(d.tvl),apr=100*Math.log1p(Number(d.apy)),
    idle=(d.liquidity||[]).filter(x=>x.protocol==="idle").reduce((n,x)=>n+Number(x.value||0),0);
   if(!(tvl>100&&apr>1&&idle>1000&&idle/tvl>0.005)){filtered++;continue}
   const addr=opAddr(contract),asset=opAddr(underlying),dec=Number(d.asset.decimals);
   try{
    const [a,t,c,b]=await Promise.all([rpc(addr,"0x38d52e0f"),rpc(addr,"0x01e1d114"),
     rpc(addr,"0x402d267d"+"000000000000000000000000000000000000000000000000000000000000dead"),
     rpc(asset,"0x70a08231"+addr.slice(2).padStart(64,"0"))]);
    const total=Number(BigInt(t))/10**dec,liquid=Number(BigInt(b))/10**dec;
    if(opAddr("0x"+a.slice(-40))!==asset||BigInt(c)===0n||
       !(total>100&&liquid>1000)||Math.abs(total-tvl)/Math.max(total,tvl)>0.25||
       Math.abs(liquid-idle)/Math.max(liquid,idle)>0.55){filtered++;continue}
    put({protocol:"Spark Savings",address:contract,asset,assetSymbol:d.asset.symbol,
     sparkVaultSymbol:d.vault.symbol,marketName:"Spark "+d.vault.symbol+" "+d.asset.symbol,
     tvlUsdEstimate:total,lendApr:Number(d.apy)*100,rateType:"APY",
     rateSource:"Spark official Savings Data API APY",
     tvlSource:"Spark API and ERC4626 onchain totalAssets",
     sourceUrl:"https://docs.spark.finance/integrators",
     registryVerified:true,directDepositCompatible:true,depositMode:"single-token",
     availableWithdrawLiquidityUsd:liquid,depositCapacityRaw:BigInt(c).toString(),
     adapterStatus:"ERC4626 conditional; large withdrawals may require asynchronous intents"});
    published++;
   }catch(e){filtered++}
  }
  // Officially registered Ethereum V2 vaults omitted from the Savings REST API.
  const more=[["WETH","0xfe6eb3b609a7c8352a241f7f3a21cea4e9209b8f","0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"],
   ["PYUSD","0x80128dbb9f07b93dde62a6daeadb69ed14a7d354","0x6c3ea9036406852006290770bedfcaba0e23a0e8"]];
  const quotes=await opGet("https://coins.llama.fi/prices/current/"+more.map(x=>"ethereum:"+x[2]).join(","));
  for(const [sym,addr,asset] of more){
   const q=quotes?.coins?.["ethereum:"+asset],dec=Number(q?.decimals),price=Number(q?.price);
   if(!Number.isInteger(dec)||dec<0||dec>30||!(price>0)||
      Math.abs(Date.now()/1000-Number(q.timestamp||0))>43200){filtered++;continue}
   try{
    const [a,t,c,b,v]=await Promise.all([rpc(addr,"0x38d52e0f"),
      rpc(addr,"0x01e1d114"),
      rpc(addr,"0x402d267d"+"000000000000000000000000000000000000000000000000000000000000dead"),
      rpc(asset,"0x70a08231"+addr.slice(2).padStart(64,"0")),
      rpc(addr,"0x1e7b14d3")]); // vsr() RAY / second
    const tvl=Number(BigInt(t))/10**dec*price,idle=Number(BigInt(b))/10**dec*price;
    const apy=100*Math.expm1(31536000*Math.log(Number(BigInt(v))/1e27));
    if(opAddr("0x"+a.slice(-40))!==asset||BigInt(c)===0n||
      !(tvl>100&&idle>=1000&&idle/tvl>=0.005&&apy>1&&apy<=1000)){filtered++;continue}
    put({protocol:"Spark Savings",address:addr,asset,assetSymbol:sym,
      marketName:"Spark Savings "+sym+" Ethereum",tvlUsdEstimate:tvl,lendApr:apy,
      rateType:"APY",rateSource:"Spark V2 onchain vsr() RAY annualized",
      tvlSource:"ERC4626 totalAssets with live Ethereum token USD quote",
      sourceUrl:"https://github.com/sparkdotfi/spark-address-registry/blob/master/src/Ethereum.sol",
      registryVerified:true,directDepositCompatible:true,depositMode:"single-token",
      availableWithdrawLiquidityUsd:idle,depositCapacityRaw:BigInt(c).toString(),
      withdrawalStatus:"Instant same-token exit limited to idle vault funds; larger exits may require intents",
      adapterStatus:"Discovery only; external OmniAdapter compatibility untested"});
    published++;
   }catch(e){filtered++}
  }
  status.push({name:"Spark Savings V2 onchain and immediate buffer",status:"ok",
   discovered:verified.length+more.length,published,filtered});
 });
 
// Silo official Ethereum lending and managed vault discovery; unsupported markets
// fail closed unless exact dapp and synchronous ERC4626 eligibility are demonstrated.
 await collect("Silo V3 official Ethereum GraphQL markets",async()=>{
  const endpoint="https://api-v3.silo.finance",gql=async query=>{
   const r=await fetch(endpoint,{method:"POST",headers:{"content-type":"application/json","accept":"application/json"},
    body:JSON.stringify({query}),signal:AbortSignal.timeout(18000)});
   const j=await r.json();if(!r.ok||j.errors?.length||!j.data)
    throw Error("Silo GraphQL: "+JSON.stringify(j.errors||j).slice(0,180));return j.data;
  };
  const markets=[],vaults=[];
  for(const [key,fields,out] of [
   ["markets","id chainId liquidityUsd",markets],
   ["vaults","id chainId name assetId apr userApr totalAssetsUsd idleVaultAssets isWhitelisted withdrawQueue asset{id symbol decimals latestUsdPrice latestUsdPriceTimestamp}",vaults]
  ]){
   for(let offset=0;offset<3000;offset+=100){
    const d=await gql('{'+key+'(where:{chainId:1},limit:100,offset:'+offset+'){totalCount items{'+fields+'}}}');
    const page=d[key];if(!Array.isArray(page?.items)||!Number.isInteger(page?.totalCount))
     throw Error("Silo "+key+" schema invalid");
    out.push(...page.items);
    if(out.length>=page.totalCount)break;
    if(page.items.length!==100||offset>=2900)throw Error("Silo "+key+" inventory truncated");
   }
  }
  const marketMap=new Map(markets.map(m=>[String(m.id).toLowerCase(),m]));
  const mainstream=new Set(["USDC","USDT","WETH","WBTC","DAI","USDS","wstETH"]);
  const candidates=vaults.filter(v=>v.chainId===1&&v.isWhitelisted===true&&
    mainstream.has(v.asset?.symbol)&&opAddr(v.id)&&opAddr(v.assetId)===opAddr(v.asset?.id)&&
    Number(v.userApr)>1&&Number(v.userApr)<1000&&Number(v.totalAssetsUsd)>100);
  let qualified=0,filtered=0,rpcErrors=0;
  const call=async(v,calldata)=>{
   let error=null;
   for(const url of ["https://eth.llamarpc.com","https://eth.drpc.org","https://ethereum-rpc.publicnode.com"]){
    try{
     const r=await fetch(url,{method:"POST",headers:{"content-type":"application/json"},
      body:JSON.stringify({jsonrpc:"2.0",id:1,method:"eth_call",params:[{to:v.id,data:calldata},"latest"]}),
      signal:AbortSignal.timeout(17000)});
     const j=await r.json();if(!r.ok||j.error||!/^0x[0-9a-f]{64}$/.test(j.result||""))throw Error("Silo RPC invalid");
     return j.result;
    }catch(e){error=e}
   }
   throw error||Error("Silo RPC unavailable");
  };
  for(const v of candidates){
   const queue=Array.isArray(v.withdrawQueue)?v.withdrawQueue:[];
   const liquidity=queue.reduce((sum,id)=>sum+Math.max(0,Number(marketMap.get(String(id).toLowerCase())?.liquidityUsd)||0),0);
   const tvl=Number(v.totalAssetsUsd);
   if(!queue.length||liquidity<1000||liquidity/tvl<0.005){filtered++;continue}
   const a=opAddr(v.asset.id),decimals=Number(v.asset.decimals);
   let price=Number(v.asset.latestUsdPrice);
   if(!Number.isInteger(decimals)||decimals<0||decimals>30||!(price>0)){
    filtered++;continue;
   }
   try{
    const [asset,assets,cap]=await Promise.all([
     call(v,"0x38d52e0f"),call(v,"0x01e1d114"),
     call(v,"0x402d267d"+"000000000000000000000000000000000000000000000000000000000000dead")]);
    const onchainAsset=opAddr("0x"+asset.slice(-40));
    const onchainTvl=Number(BigInt(assets))/10**decimals*price;
    if(onchainAsset!==a||BigInt(cap)===0n||!(onchainTvl>100)||
       Math.abs(onchainTvl-tvl)/Math.max(onchainTvl,tvl)>0.25){
     filtered++;continue;
    }
    put({protocol:"Silo Vaults",address:v.id,asset:a,assetSymbol:v.asset.symbol,
     marketName:"Silo "+v.name+" "+v.asset.symbol,tvlUsdEstimate:onchainTvl,
     lendApr:Number(v.userApr),rateType:"APR",
     rateSource:"Silo V3 API userApr (after vault fees)",tvlSource:"Silo API plus onchain totalAssets",
     sourceUrl:"https://docs.silo.finance/docs/developers/apis/api-overview/",
     registryVerified:true,directDepositCompatible:true,depositMode:"single-token",
     depositCapacityRaw:BigInt(cap).toString(),
     availableWithdrawLiquidityUsd:liquidity,
     withdrawalStatus:"Same-asset immediate withdrawals subject to underlying market liquidity; aggregate upper-bound",
     adapterStatus:"ERC4626 market candidate; separate OmniAdapter allocation verification required"});
    qualified++;
   }catch(e){rpcErrors++;filtered++}
  }
  status.push({name:"Silo Ethereum fully enumerated ERC4626 vault qualification",status:"ok",
   discoveredMarkets:markets.length,discoveredManagedVaults:vaults.length,
   screenedManagedVaults:candidates.length,qualified,filtered,rpcErrors,
   excludedIsolatedMarkets:"No individually verified Silo market-specific deposit and withdrawal app route"});
 });
 
// Source-isolated IPOR Fusion live ERC-4626 deposit-capacity check.
 // Only the dedicated IPOR request executes RPC, keeping main discovery <50 subrequests.
 if(["IPOR Fusion v2","Fluid official fTokens","Curve official Ethereum lending","Maple Finance official V2 pools","Yearn Kong REST V2/V3"].includes(sourceOnly)){
  const isFluid=sourceOnly==="Fluid official fTokens",isYearn=sourceOnly==="Yearn Kong REST V2/V3";
  const wanted=isFluid?["Fluid Lending"]:isYearn?["Yearn V2","Yearn V3"]:sourceOnly==="Curve official Ethereum lending"?["CurveLend V1","CurveLend V2"]:sourceOnly==="Maple Finance official V2 pools"?["Maple Syrup"]:["IPOR Fusion"];
  const gateName=isFluid?"Fluid onchain ERC4626 deposit capacity":sourceOnly==="IPOR Fusion v2"?"IPOR onchain ERC4626 deposit capacity":"Independent ERC4626 deposit eligibility";
  await collect(gateName,async()=>{
   const mc="0xca11bde05977b3631167028862be2a173976ca11",
    word=n=>BigInt(n).toString(16).padStart(64,"0"),
    eligibleRows=[...out.entries()].filter(([key,x])=>wanted.includes(x.protocol));
   if(!eligibleRows.length)throw Error("No priced "+wanted.join("/")+" candidates");
   const jobs=eligibleRows.flatMap(([key,x])=>x.protocol==="Yearn V2"?[
    {key,contract:x.address,field:"asset",data:"fc0c546a"}, // token()
    {key,contract:x.address,field:"capacity",data:"153c27c4"}, // availableDepositLimit()
    {key,contract:x.address,field:"shutdown",data:"3403c2fc"} // emergencyShutdown()
   ]:[
    {key,contract:x.address,field:"asset",data:"38d52e0f"},
    {key,contract:x.address,field:"capacity",data:"402d267d"+word("0x000000000000000000000000000000000000dead")}
   ]);
   const result=new Map();
   for(let start=0;start<jobs.length;start+=80){
    const batch=jobs.slice(start,start+80);
    const tuples=batch.map(x=>x.contract.slice(2).padStart(64,"0")+
     word(1)+word(96)+word(x.data.length/2)+x.data.padEnd(Math.ceil(x.data.length/64)*64,"0"));
    let cursor=batch.length*32;
    const offsets=tuples.map(t=>{const w=word(cursor);cursor+=t.length/2;return w});
    const args=word(32)+word(batch.length)+offsets.join("")+tuples.join("");
    let buf=null,last=null;
    for(const endpoint of ["https://eth.llamarpc.com","https://eth.drpc.org","https://ethereum-rpc.publicnode.com"]){
     try{
      const r=await fetch(endpoint,{method:"POST",headers:{"content-type":"application/json"},
       body:JSON.stringify({jsonrpc:"2.0",id:1,method:"eth_call",params:[
        {to:mc,data:"0x82ad56cb"+args,gas:"0x1c9c380"},"latest"]}),signal:AbortSignal.timeout(19000)});
      const j=await r.json();
      if(!r.ok||j.error||!/^0x[0-9a-f]+$/i.test(j.result||""))throw Error("RPC HTTP "+r.status);
      buf=j.result.slice(2);break;
     }catch(e){last=e}
    }
    if(!buf)throw last||Error("IPOR onchain call unavailable");
    const read=p=>{const h=buf.slice(p*2,(p+32)*2);if(h.length!==64)throw Error("Multicall response truncated");return Number(BigInt("0x"+h))};
    const off=read(0),num=read(off),base=off+32;
    if(num!==batch.length)throw Error("Unexpected multicall result count");
    for(let i=0;i<num;i++){
     const j=batch[i],p=base+read(base+i*32),success=read(p)!==0,d=read(p+32),len=read(p+d),
      hex=buf.slice((p+d+32)*2,(p+d+32+len)*2);
     const row=result.get(j.key)||{};
     if(success&&len===32&&hex.length===64)row[j.field]=hex;
     result.set(j.key,row);
    }
   }
   let accepted=0,rejected=0;
   for(const [key,x] of eligibleRows){
    const v=result.get(key),underlying=opAddr("0x"+String(v?.asset||"").slice(-40));
    const capacity=v?.capacity?BigInt("0x"+v.capacity):0n;
    const running=x.protocol!=="Yearn V2"||(v?.shutdown!=null&&BigInt("0x"+v.shutdown)===0n);
    if(underlying!==x.asset||capacity<=0n||!running){out.delete(key);rejected++;continue}
    x.depositCapacityRaw=capacity.toString();
    accepted++;
   }
   status.push({name:wanted.join("/")+" ERC4626 live deposits",status:"ok",inspected:eligibleRows.length,accepted,rejected});
  });
  if(!status.some(x=>x.name===gateName&&x.status==="ok"))for(const [key,row] of out)if(wanted.includes(row.protocol))out.delete(key);
 }
 
// Cross-reference aggregate-only Yearn products against the protocol's
// official legacy vault catalog. Never infer a market from its base token alone.
 let yearnLegacyMatchedCount=0;
 await collect("Yearn yDaemon official legacy vault reconciliation",async()=>{
  const url="https://ydaemon.yearn.fi/1/vaults/all?first=1200&skip=0&strategiesDetails=noDetails";
  const docs=await opGet(url);
  if(!Array.isArray(docs))throw Error("Yearn yDaemon vault inventory unavailable");
  const nativeByToken=new Map();
  for(const d of docs){
   if(Number(d.chainID)!==1)continue;
   const addr=opAddr(d.address),asset=opAddr(d.token?.address),tvl=opNum(d.tvl?.tvl);
   if(!addr||!asset||tvl===null||tvl<=100)continue;
   if(!nativeByToken.has(asset))nativeByToken.set(asset,[]);
   nativeByToken.get(asset).push({addr,tvl,apr:opNum(d.apr?.netAPR),
    name:String(d.name||""),symbol:String(d.symbol||"")});
  }
  if(!nativeByToken.size)throw Error("Yearn legacy native catalog returned no usable vault contracts");
  for(const x of out.values()){
   if(!/^Yearn /.test(x.protocol)||x.address||x.additionalAssets?.length)continue;
   const normal=z=>String(z||"").toLowerCase().replace(/[^a-z0-9]/g,"");
   const label=normal(x.marketName),symbol=normal(x.assetSymbol);
   const candidates=(nativeByToken.get(x.asset)||[]).filter(v=>{
    const delta=Math.abs(x.tvlUsdEstimate-v.tvl)/Math.max(x.tvlUsdEstimate,v.tvl,100);
    const sameName=label.length>5&&(label===normal(v.name)||label===normal(v.symbol));
    const sameSymbol=symbol.length>5&&symbol===normal(v.symbol);
    if(delta>(sameName||sameSymbol?0.30:0.08))return false;
    if(x.lendApr!==null&&v.apr!==null&&Math.abs(x.lendApr-v.apr*100)>(sameName||sameSymbol?8:5))return false;
    return true;
   }).sort((a,b)=>Math.abs(a.tvl-x.tvlUsdEstimate)-Math.abs(b.tvl-x.tvlUsdEstimate));
   if(candidates.length!==1)continue;
   x.address=candidates[0].addr;x.registryVerified=true;x.indexOnly=false;
   x.resolutionSource="Yearn yDaemon uniquely matched native vault address by underlying, TVL and APR";
   yearnLegacyMatchedCount++;
  }
 });
 
 // Bulk indexed Morpho Vault V1/V2 data. Official GraphQL sunsets 2027-01-29.
 async function morphoBulk(query) {
  let last;
  for(const url of ["https://api.morpho.org/graphql","https://blue-api.morpho.org/graphql"]){
   try{
    const r=await fetch(url,{method:"POST",headers:{"content-type":"application/json","accept":"application/json"},
     body:JSON.stringify({query}),signal:AbortSignal.timeout(15000)});
    const j=await r.json().catch(()=>null);
    if(!r.ok)throw Error("HTTP "+r.status+": "+JSON.stringify(j?.errors||j?.message||"unknown").slice(0,300));
    if(j?.errors?.length)throw Error(j.errors.map(e=>e.message).join("; ").slice(0,260));
    if(!j.data)throw Error("No GraphQL data");
    return j.data;
   }catch(e){last=e}
  }
  throw Error("Morpho API unavailable: "+String(last?.message||last));
 }

 await collect("Morpho Blue complete Ethereum market index",async()=>{
  const core="0xbbbbbbbbbb9cc5e90e3b3af64bdaf62c37eeffcb",batch=200;
  let complete=false,added=0;
  for(let page=0;page<120;page++){
   const query="{ markets(first:"+batch+",skip:"+(page*batch)+
    ",orderBy:SupplyAssetsUsd,orderDirection:Desc,where:{chainId_in:[1]}) { items { "+
    "marketId loanAsset { address symbol } collateralAsset { address symbol } "+
    "state { supplyAssetsUsd supplyApy netSupplyApy avgSupplyApy } } } }";
   const j=await morphoBulk(query),items=j.markets?.items;
   if(!Array.isArray(items))throw Error("Morpho Blue GraphQL markets list unavailable");
   let last=null;
   for(const v of items){
    const loan=opAddr(v.loanAsset?.address),marketId=String(v.marketId||"");
    if(!loan||!OP_ID.test(marketId))continue;
    const tvl=opNum(v.state?.supplyAssetsUsd),instantApy=opNum(v.state?.netSupplyApy??v.state?.supplyApy),
      averageApy=opNum(v.state?.avgSupplyApy),apy=averageApy??instantApy;
    if(tvl!==null)last=tvl;
    if(tvl===null||tvl<=100)continue;
    put({protocol:"Morpho Blue",address:core,marketId,asset:loan,
     assetSymbol:v.loanAsset?.symbol,marketName:(v.loanAsset?.symbol||"Loan asset")+
      " / "+(v.collateralAsset?.symbol||"uncollateralized"),
     tvlUsdEstimate:tvl,lendApr:apy===null?null:apy*100,rateType:"APY",
     rateSource:averageApy!==null?"Morpho Blue rolling-average supply APY (base, excludes incentives)":"Morpho Blue instantaneous supply APY",sourceUrl:"https://api.morpho.org/graphql",registryVerified:true});
    added++;
   }
   if(items.length<batch||(last!==null&&last<=100)){complete=true;break}
  }
  if(!complete)gaps.push("Morpho Blue full enumeration exceeded 24,000 indexed markets");
  // Replace opaque pool UUID entries ONLY after complete authoritative native enumeration.
  if(complete&&added>0){
   for(const [id,row] of out){
    if(row.protocol==="Morpho Blue"&&!row.marketId&&row.rateSource==="DeFiLlama public yields")
     out.delete(id);
   }
  }
 });
 await Promise.all(["v1","v2"].map(version=>collect("Morpho Vault "+version.toUpperCase()+" bulk USD",async()=>{
  const key=version==="v1"?"vaults":"vaultV2s";
  let complete=false;
  for(let page=0;page<20;page++){
   const fields=version==="v1"?
    "address name asset { address symbol } state { totalAssetsUsd netApy avgNetApy }":
    "address name asset { address symbol } totalAssetsUsd netApy avgNetApy";
   const query="{ "+key+"(first:200,skip:"+String(page*200)+
    ",orderBy:TotalAssetsUsd,orderDirection:Desc,where:{chainId_in:[1]}) { items { "+fields+" } } }";
   const data=await morphoBulk(query),list=data[key]?.items;
   if(!Array.isArray(list))throw Error("Unrecognized Morpho GraphQL response");
   let lastTvl=null;
   for(const v of list){
    const tvl=opNum(version==="v1"?v.state?.totalAssetsUsd:v.totalAssetsUsd);
    if(tvl!=null)lastTvl=tvl;
    const avg=opNum(version==="v1"?v.state?.avgNetApy:v.avgNetApy),
      apy=avg??opNum(version==="v1"?v.state?.netApy:v.netApy);
    put({protocol:version==="v1"?"Morpho Vault V1":"Morpho Vault V2",address:v.address,
     asset:v.asset?.address,assetSymbol:v.asset?.symbol,marketName:v.name||"Morpho vault",
     tvlUsdEstimate:tvl,lendApr:apy==null?null:apy*100,rateType:"APY",
     rateSource:avg!==null?"Morpho reported rolling-average net APY":"Morpho reported instantaneous net APY",sourceUrl:"https://api.morpho.org/graphql",registryVerified:true});
   }
   if(list.length<200||(lastTvl!=null&&lastTvl<=100)){complete=true;break}
  }
  if(!complete)gaps.push("Morpho "+version+" data exceeded 4,000 entries");
 })));
 // Morpho REST inventories report identity but not USD TVL; enrich already USD-priced records only.
 await Promise.all(["v0/vaults-v1","v0/vaults-v2"].map(path=>collect("Morpho REST "+path,async()=>{
  let cursor=null,complete=false;const used=new Set();
  for(let i=0;i<12;i++){
   const u=new URL("https://api.morpho.org/"+path);
   u.searchParams.set("chain_ids","1");u.searchParams.set("limit","1000");
   if(cursor)u.searchParams.set("cursor",cursor);
   const j=await opGet(u.toString());
   if(!Array.isArray(j?.data))throw Error("Morpho REST schema changed");
   const known=new Map([...out.values()].filter(v=>v.address).map(v=>[v.address,v]));
   for(const v of j.data){
    if(Number(v.chain_id)!==1)continue;
    const match=known.get(opAddr(v.vault_address));
    if(match){match.protocol=path.endsWith("v2")?"Morpho Vault V2":"Morpho Vault V1";
     match.marketName=v.name||match.marketName;match.registryVerified=true;}
   }
   if(!j.cursor){complete=true;break}
   if(used.has(j.cursor))throw Error("Repeated Morpho cursor");
   used.add(j.cursor);cursor=j.cursor;
  }
  if(!complete)gaps.push("Morpho "+path+" cursor inventory exceeded 12 pages");
 })));
 // When Beefy's native active-vault inventory succeeds, drop opaque aggregator-only
 // Beefy proxy rows; each native result has a verified contract + exact want token.

 await collect("Beefy official LP component balances Ethereum",async()=>{
  const [breakdowns,tokens,prices]=await Promise.all([
   opGet("https://api.beefy.finance/lps/breakdown"),
   opGet("https://api.beefy.finance/tokens/ethereum"),
   opGet("https://api.beefy.finance/prices")]);
  if(!breakdowns||typeof breakdowns!=="object"||!tokens||typeof tokens!=="object")
   throw Error("Beefy LP component API schema changed");
  const byTokenAddress=new Map();
  for(const t of Object.values(tokens)){
   const addr=opAddr(t?.address);if(!addr)continue;
   if(!byTokenAddress.has(addr)||t.oracle==="tokens")byTokenAddress.set(addr,t);
  }
  for(const row of out.values()){
   if(row.protocol!=="Beefy Vaults"||!row.beefyOracleId)continue;
   const lp=breakdowns[row.beefyOracleId];
   if(!lp||!Array.isArray(lp.tokens)||!Array.isArray(lp.balances)||lp.tokens.length!==lp.balances.length)
    continue;
   const coins=[];
   for(let i=0;i<lp.tokens.length;i++){
    const address=opAddr(lp.tokens[i]);if(!address||address==="0x0000000000000000000000000000000000000000")continue;
    const token=byTokenAddress.get(address),balance=opNum(lp.balances[i]);
    const price=opNum(prices?.[token?.oracleId]??prices?.[token?.symbol]);
    const usdValue=balance!=null&&price!=null?balance*price:null;
    coins.push({address,symbol:String(token?.symbol||"").slice(0,35),
     decimals:Number.isInteger(Number(token?.decimals))?Number(token.decimals):null,
     poolBalanceRaw:null,balance,usdPrice:price,
     usdValue:usdValue!=null&&Number.isFinite(usdValue)?usdValue:null,
     isBasePoolLpToken:false});
   }
   if(!coins.length)continue;
   const total=coins.reduce((v,c)=>v+(c.usdValue||0),0);
   const ready=coins.map(c=>({...c,poolSharePct:total>0&&c.usdValue!=null?100*c.usdValue/total:null}));
   row.lpComposition={lpToken:row.asset,poolAddress:null,
    poolName:row.marketName,lpSymbol:row.assetSymbol,poolRegistry:"Beefy LP oracle",
    tvlUsd:null,gaugeAddress:null,coins:ready,underlyingCoins:[],
    singleCoinCandidates:ready.map(c=>({address:c.address,symbol:c.symbol,
     kind:"external_lp_component_candidate"})),
    underlyingCandidates:[],compositionStatus:total>0?"pool-reserve-estimate":"token-identities-and-balances",
    sourceUrl:"https://api.beefy.finance/lps/breakdown"};
   row.depositAssetType="external-lp";
   row.singleTokenConversionStatus="requires_supported_pool_adapter_and_quote";
  }
 });
 if(curveByLp&&curveByCoins){
  const byLp=curveByLp,byCoins=curveByCoins;
   // Exact LP identity takes precedence over token-symbol matches.
   for(const v of out.values()){
    const match=byLp.get(v.asset);
    if(match){
     const {isBroken,...c}=match;
     v.lpComposition=c;
     v.depositAssetType="curve-lp";
     v.singleTokenConversionStatus="route_candidate_requires_adapter_quote";
    }
   }
   // DeFiLlama may expose the coin basket for Convex rather than its Curve LP.
   // Resolve ONLY if the native Curve pool has an exactly matching full coin set,
   // and that match is unique. Booster pool ID remains unverified, so this remains
   // index-only until the Convex destination itself is resolved.
   for(const [id,v] of [...out]){
    if(v.protocol!=="Convex Finance"||!v.depositMode.startsWith("underlying basket;"))continue;
    const basket=[v.asset,...v.additionalAssets].filter(Boolean);
    const key=[...new Set(basket)].sort().join(",");
    const matches=byCoins.get(key)||[];
    const distinct=[...new Map(matches.map(p=>[p.lpToken,p])).values()];
    if(distinct.length===1){
     const pool=distinct[0];
     out.delete(id);
     v.asset=pool.lpToken;v.assetSymbol=pool.lpSymbol||"Curve LP";
     v.lpComposition=pool;v.depositAssetType="curve-lp";
     v.depositMode="Curve LP composition matched; Convex Booster pool ID unresolved";
     v.singleTokenConversionStatus="route_candidate_requires_adapter_quote";
     v.lpResolution="unique_exact_Curve_coin_set_not_Convex_destination_verified";
     v.indexOnly=true;v.directDepositCompatible=false;
     v.additionalAssets=pool.coins.map(c=>c.address);
     v.additionalAssetSymbols=pool.coins.map(c=>c.symbol);
     v.id="1:convex finance:"+(v.address||v.marketId||v.poolId||v.asset)+":"+v.asset+":"+(v.marketId||"");
     if(!out.has(v.id))out.set(v.id,v);
    }else if(distinct.length>1){
     v.lpCandidates=distinct.slice(0,8).map(p=>({lpToken:p.lpToken,
      poolAddress:p.poolAddress,poolName:p.poolName,lpSymbol:p.lpSymbol}));
     v.lpResolution="ambiguous_multiple_Curve_pools_same_coins";
    }
   }
 }

 // The Convex Booster has no complete native public REST API. Read all onchain
 // poolInfo records in bounded Multicall3 batches (one eth_call per 160 pools),
 // never per-market RPC requests and never on each frontend page load.
 await collect("Convex Booster onchain batched pool registry",async()=>{
  const booster="0xf403c135812408bfbe8713b5a23a04b3d48aae31";
  const multicall="0xca11bde05977b3631167028862be2a173976ca11";
  const rpcs=["https://eth.llamarpc.com","https://eth.drpc.org","https://ethereum-rpc.publicnode.com"],width=64;
  const word=n=>BigInt(n).toString(16).padStart(width,"0");
  let preferredRpc=0;
  const call=async(to,data)=>{
   let failure=null;
   const ordered=[rpcs[preferredRpc],...rpcs.filter((_,i)=>i!==preferredRpc)];
   for(const rpc of ordered){
    try{
     const r=await fetch(rpc,{method:"POST",headers:{"content-type":"application/json"},
      body:JSON.stringify({jsonrpc:"2.0",id:1,method:"eth_call",params:[{to,data,gas:"0x1c9c380"},"latest"]}),
      signal:AbortSignal.timeout(19000)});
     const j=await r.json().catch(()=>null);
     if(!r.ok||j?.error||!/^0x[0-9a-f]*$/i.test(j?.result||""))
      throw Error("RPC "+new URL(rpc).hostname+" HTTP "+r.status+" "+JSON.stringify(j?.error||j).slice(0,130));
     preferredRpc=rpcs.indexOf(rpc);return j.result.toLowerCase();
    }catch(e){failure=e}
   }
   throw failure||Error("No public Ethereum RPC available");
  };
  const lenRaw=await call(booster,"0x081e3eda");
  const length=Number(BigInt(lenRaw));
  if(!Number.isSafeInteger(length)||length<1||length>1000)
   throw Error("Convex Booster returned invalid poolLength "+String(length));
  const jobs=[];
  for(let first=0;first<length;first+=160){
   const ids=Array.from({length:Math.min(160,length-first)},(_,i)=>i+first);
   const tuple=ids.map(pid=>booster.slice(2).padStart(64,"0")+word(1)+word(96)+word(36)+"1526fe27"+word(pid)+"0".repeat(56));
   const args=word(32)+word(ids.length)+tuple.map((_,i)=>word(32*ids.length+192*i)).join("")+tuple.join("");
   jobs.push({ids,calldata:"0x82ad56cb"+args});
  }
  const resolved=[];
  for(let j=0;j<jobs.length;j+=2){
   const segment=await Promise.all(jobs.slice(j,j+2).map(async job=>{
   const bytes=(await call(multicall,job.calldata).catch(e=>{throw Error("Booster batch "+job.ids[0]+"-"+job.ids.at(-1)+": "+String(e?.message||e))})).slice(2);
   const read=(pos)=>{const v=bytes.slice(pos*2,(pos+32)*2);if(v.length!==64)throw Error("Convex multicall response truncated");return Number(BigInt("0x"+v));};
   const arrayOffset=read(0),count=read(arrayOffset),base=arrayOffset+32;
   if(count!==job.ids.length)throw Error("Convex multicall pool count mismatch");
   const decoded=[];
   for(let i=0;i<count;i++){
    const start=base+read(base+i*32),success=read(start)!==0,lenPtr=read(start+32);
    const lengthBytes=read(start+lenPtr),ptr=start+lenPtr+32;
    if(!success||lengthBytes!==192)continue;
    const slots=Array.from({length:6},(_,k)=>bytes.slice((ptr+k*32)*2,(ptr+(k+1)*32)*2));
    if(slots.some(x=>x.length!==64))continue;
    const pool={
     pid:job.ids[i],lp:opAddr("0x"+slots[0].slice(-40)),
     receipt:opAddr("0x"+slots[1].slice(-40)),
     gauge:opAddr("0x"+slots[2].slice(-40)),
     reward:opAddr("0x"+slots[3].slice(-40)),
     stash:opAddr("0x"+slots[4].slice(-40)),
     shutdown:BigInt("0x"+slots[5])!==0n};
    if(pool.lp&&pool.reward)decoded.push(pool);
   }
   return decoded;
  }));resolved.push(...segment.flat());
  }
  if(!resolved.length)throw Error("Convex Booster batched registry returned no active pools");
  convexPools=resolved;convexRpcCall=call;
  const byLp=new Map();
  for(const p of resolved){
   if(!byLp.has(p.lp))byLp.set(p.lp,[]);
   byLp.get(p.lp).push(p);
  }
  for(const [oldId,row] of [...out]){
   if(row.protocol!=="Convex Finance"||row.depositAssetType!=="curve-lp"||!row.asset)continue;
   const active=(byLp.get(row.asset)||[]).filter(p=>!p.shutdown);
   let pool=null;
   if(row.address)pool=active.find(p=>p.reward===row.address)||null;
   if(!pool&&row.boosterPid!=null)pool=active.find(p=>p.pid===row.boosterPid)||null;
    if(!pool&&row.convexGauge)pool=active.find(p=>p.gauge===row.convexGauge)||null;
    if(!pool&&row.convexReceiptToken)pool=active.find(p=>p.receipt===row.convexReceiptToken)||null;
    if(!pool&&row.lpComposition?.gaugeAddress)pool=active.find(p=>p.gauge===row.lpComposition.gaugeAddress)||null;
   if(!pool&&active.length===1)pool=active[0];
   if(!pool){
    if(active.length>1)row.convexBoosterCandidates=active.map(p=>({
     pid:p.pid,rewardContract:p.reward,gauge:p.gauge,receiptToken:p.receipt}));
    continue;
   }
   out.delete(oldId);
   row.address=pool.reward;row.boosterPid=pool.pid;
   row.depositRouter=booster;row.convexGauge=pool.gauge;
   row.convexReceiptToken=pool.receipt;
   row.registryVerified=true;row.indexOnly=false;
   row.directDepositCompatible=true;
   row.adapterStatus="requires_verified_Convex_Booster_and_LP_conversion_adapter";
   row.depositMode="Curve LP deposit via Convex Booster (adapter required)";
   row.lpResolution="onchain_booster_poolInfo_verified";
   row.id="1:convex finance:"+pool.reward+":"+row.asset+":";
   const prior=out.get(row.id);
   if(prior){
    if(prior.lendApr==null&&row.lendApr!=null){
     prior.lendApr=row.lendApr;prior.rateType=row.rateType;prior.rateSource=row.rateSource;
    }
    if(!prior.lpComposition&&row.lpComposition)prior.lpComposition=row.lpComposition;
    if(!prior.convexGauge)prior.convexGauge=pool.gauge;
    if(!prior.convexReceiptToken)prior.convexReceiptToken=pool.receipt;
    if(prior.boosterPid==null)prior.boosterPid=pool.pid;
   }else out.set(row.id,row);
  }
 });

 await collect("Convex native receipt supply and Curve LP TVL",async()=>{
  if(!convexPools||!convexRpcCall||!curveByLp)
   throw Error("Convex receipt TVL depends on confirmed Booster and Curve LP registries");
  const multicall="0xca11bde05977b3631167028862be2a173976ca11";
  const word=n=>BigInt(n).toString(16).padStart(64,"0");
  const active=convexPools.filter(p=>!p.shutdown&&p.receipt&&curveByLp.has(p.lp)&&
   !curveByLp.get(p.lp).isBroken&&opNum(curveByLp.get(p.lp).tvlUsd)>0&&
   /^\d+$/.test(curveByLp.get(p.lp).lpTotalSupplyRaw)&&BigInt(curveByLp.get(p.lp).lpTotalSupplyRaw)>0n);
  if(!active.length)throw Error("No active Convex pools with usable Curve LP valuations");
  const batches=[];
  for(let first=0;first<active.length;first+=256){
   const chunk=active.slice(first,first+256);
   const tuple=chunk.map(p=>p.receipt.slice(2).padStart(64,"0")+word(1)+word(96)+word(4)+
    "18160ddd"+"0".repeat(56));
   const args=word(32)+word(chunk.length)+tuple.map((_,i)=>word(32*chunk.length+160*i)).join("")+tuple.join("");
   batches.push({chunk,calldata:"0x82ad56cb"+args});
  }
  const pending=[];
  for(let first=0;first<batches.length;first+=2){
   const results=await Promise.all(batches.slice(first,first+2).map(async job=>{
    const data=(await convexRpcCall(multicall,job.calldata).catch(e=>{throw Error("Receipt PID "+job.chunk[0]?.pid+"-"+job.chunk.at(-1)?.pid+": "+String(e?.message||e))})).slice(2);
    const valueAt=pos=>{const h=data.slice(pos*2,(pos+32)*2);
     if(h.length!==64)throw Error("Convex receipt supply multicall truncated");
     return Number(BigInt("0x"+h))};
    const offset=valueAt(0),count=valueAt(offset),base=offset+32;
    if(count!==job.chunk.length)throw Error("Convex receipt batch response length mismatch");
    const rows=[];
    for(let i=0;i<count;i++){
     const p=base+valueAt(base+i*32),success=valueAt(p)!==0,head=valueAt(p+32);
     const n=valueAt(p+head);
     if(!success||n!==32)continue;
     const raw=data.slice((p+head+32)*2,(p+head+64)*2);
     if(raw.length!==64)continue;
     rows.push({pool:job.chunk[i],supply:BigInt("0x"+raw)});
    }
    return rows;
   }));
   for(const {pool,supply} of results.flat()){
    if(supply<=0n)continue;
    const curve=curveByLp.get(pool.lp),curveSupply=BigInt(curve.lpTotalSupplyRaw);
    const poolTvl=opNum(curve.tvlUsd),ratio=Number(supply)/Number(curveSupply);
    if(!Number.isFinite(ratio)||ratio<=0||ratio>1.05||poolTvl==null)continue;
    const tvl=poolTvl*ratio;
    if(!Number.isFinite(tvl)||tvl<=100)continue;
    pending.push({pool,supply,curve,tvl});
   }
  }
  if(!pending.length)throw Error("No active Convex reward pools have verified positive receipt supply valuation");
  // Commit only after every receipt-supply batch succeeds: never publish partial catalogs.
  for(const {pool,supply,curve,tvl} of pending){
    const id="1:convex finance:"+pool.reward+":"+pool.lp+":";
    const existing=out.get(id);
    const tvlSource="Booster receipt totalSupply / Curve LP totalSupply * Curve pool USD TVL";
    if(existing){
     existing.tvlUsdEstimate=tvl;
     existing.tvlSource=tvlSource;
     existing.convexReceiptSupplyRaw=supply.toString();
     existing.convexGauge=pool.gauge;existing.convexReceiptToken=pool.receipt;
    }else{
     put({protocol:"Convex Finance",address:pool.reward,
      asset:pool.lp,assetSymbol:curve.lpSymbol,marketName:"Convex "+curve.poolName,
      tvlUsdEstimate:tvl,lendApr:null,rateType:"APR",
      rateSource:"Yield unavailable; official native LP/Booster staked supply",
      sourceUrl:"https://api.curve.finance/v1/getPools/all/ethereum",
      registryVerified:true,lpComposition:((({isBroken,...rest})=>rest)(curve)),
      convexReceiptToken:pool.receipt,convexGauge:pool.gauge,
      boosterPid:pool.pid,depositRouter:"0xf403c135812408bfbe8713b5a23a04b3d48aae31",
      directDepositCompatible:true,depositMode:"Curve LP deposit via Convex Booster (adapter required)",
      adapterStatus:"requires_verified_Convex_Booster_and_LP_conversion_adapter"});
     const inserted=out.get(id);
     if(inserted){
      inserted.depositAssetType="curve-lp";
      inserted.singleTokenConversionStatus="route_candidate_requires_adapter_quote";
      inserted.lpResolution="onchain_booster_poolInfo_verified";
      inserted.tvlSource=tvlSource;
      inserted.convexReceiptSupplyRaw=supply.toString();
     }
    }

  }
 });



// Join opaque Convex yield-index rows to independently decoded Booster poolInfo
 // only when the same LP identity or exact Curve coin set is found, and unique
 // native pool TVL corroborates the match. No PID is inferred from a pool name.
 let convexNativeJoins=0;
 {
  const verified=[...out.values()].filter(x=>x.protocol==="Convex Finance"&&x.boosterPid!=null&&
   x.address&&x.registryVerified&&x.lpComposition?.coins?.length&&x.tvlUsdEstimate>100);
  const sortTokens=a=>[...new Set(a.filter(Boolean))].sort().join(",");
  const poolCoins=x=>sortTokens((x.lpComposition?.coins||[]).map(c=>opAddr(c.address)).filter(Boolean));
  for(const x of out.values()){
   if(x.protocol!=="Convex Finance"||x.boosterPid!=null||x.tvlUsdEstimate<=100)continue;
   const basket=sortTokens([x.asset,...(x.additionalAssets||[])].map(opAddr).filter(Boolean));
   const lp=opAddr(x.lpComposition?.lpToken);
   const norm=z=>String(z||"").toLowerCase().replace(/\b(convex|curve|finance|pool)\b/g,"").replace(/[^a-z0-9]/g,"");
   const matches=verified.filter(y=>{
    const exactLP=(lp&&lp===y.asset)||(x.asset&&x.asset===y.asset);
    const exactBasket=!exactLP&&basket&&basket.includes(",")&&basket===poolCoins(y);
    const sameName=norm(x.marketName).length>=6&&
     (norm(x.marketName)===norm(y.marketName)||norm(x.marketName)===norm(y.lpComposition?.poolName));
    const knownCoins=[x.asset,...(x.additionalAssets||[])].map(opAddr).filter(Boolean);
    const nativeCoins=new Set((y.lpComposition?.coins||[]).map(c=>opAddr(c.address)).filter(Boolean));
    const coinsAgree=knownCoins.length>=2&&knownCoins.every(a=>a===y.asset||nativeCoins.has(a));
    if(!exactLP&&!exactBasket&&!(sameName&&coinsAgree))return false;
    const delta=Math.abs(x.tvlUsdEstimate-y.tvlUsdEstimate)/
      Math.max(100,x.tvlUsdEstimate,y.tvlUsdEstimate);
    return delta<=(exactLP||exactBasket?0.12:0.08);
   });
   if(matches.length!==1)continue;
   const y=matches[0];
   x.address=y.address;x.boosterPid=y.boosterPid;x.depositRouter=y.depositRouter;
   x.asset=y.asset;x.assetSymbol=y.assetSymbol;
   x.registryVerified=true;x.indexOnly=false;x.directDepositCompatible=true;
   x.lpComposition=y.lpComposition;x.depositMode=y.depositMode;
   x.lpResolution="exact_LP_or_coins_and_unique_12pct_TVL_correspondence";
   x.resolutionSource="unique source-bound official Convex Booster poolInfo and Curve LP TVL";
   convexNativeJoins++;
  }
 }

 await collect("Fraxlend native registry and pair-level Ethereum RPC",async()=>{
  // Official deployed FraxlendPairDeployer contracts on Ethereum, sourced
  // from independently maintained, onchain LogDeploy-validated inventories.
  // Do not mistake an unknown registry address for a factory.
  const deployers=[
   "0x7ab788d0483551428f2291232477f1818952998c",
   "0xaa913c26dd7723fcae9dbd2036d28171a56c6251",
   "0xeb8816baeb70690660ce6c0eda2b07a21493e664",
   "0xf767a82a188305461b6f01a7706f7bc0ba941fff"
  ];
  const multicall="0xca11bde05977b3631167028862be2a173976ca11";
  const word=n=>BigInt(n).toString(16).padStart(64,"0");
  const rpc=convexRpcCall||(async(to,data)=>{
   let last;
   for(const url of ["https://eth.llamarpc.com","https://eth.drpc.org","https://ethereum-rpc.publicnode.com"]){
    try{
     const r=await fetch(url,{method:"POST",headers:{"content-type":"application/json"},
      body:JSON.stringify({jsonrpc:"2.0",id:1,method:"eth_call",params:[{to,data,gas:"0x1c9c380"},"latest"]}),
      signal:AbortSignal.timeout(19000)});
     const j=await r.json().catch(()=>null);
     if(!r.ok||j?.error||!/^0x[0-9a-f]*$/i.test(j?.result||""))throw Error("Fraxlend RPC "+new URL(url).hostname+" HTTP "+r.status);
     return j.result.toLowerCase();
    }catch(e){last=e}
   }
   throw last||Error("Ethereum RPC unavailable");
  });
  const pairDeployer=new Map();
  for(const deployer of deployers){
   const raw=(await rpc(deployer,"0x607b6d16")).slice(2);
   if(raw.length<128||Number(BigInt("0x"+raw.slice(0,64)))!==32)
    throw Error("Fraxlend deployer ABI invalid: "+deployer);
   const count=Number(BigInt("0x"+raw.slice(64,128)));
   if(!Number.isSafeInteger(count)||count<0||count>2000||raw.length<128+count*64)
    throw Error("Fraxlend deployer enumeration malformed: "+deployer);
   const list=Array.from({length:count},(_,i)=>opAddr("0x"+
    raw.slice(128+i*64+24,128+(i+1)*64)));
   if(list.some(p=>!p)||new Set(list).size!==list.length)
    throw Error("Fraxlend deployer duplicates or malformed pair: "+deployer);
   for(const pair of list){
    if(pairDeployer.has(pair)&&pairDeployer.get(pair)!==deployer)
     throw Error("Fraxlend pair unexpectedly registered by multiple deployers");
    pairDeployer.set(pair,deployer);
   }
  }
  const pairs=[...pairDeployer.keys()];
  if(!pairs.length)throw Error("Fraxlend verified deployers returned no pools");
  fraxlendRegisteredCount=pairs.length;
  // These selectors correspond to verified FraxlendPair getters.
  // ERC4626.asset, collateralContract, accounting, rate, DEPLOYER_ADDRESS.
  const methods=["38d52e0f","c6e1c7c9","cdd72d52","95d14ca8","d2a156e0"];
  const queries=pairs.flatMap(pair=>methods.map((method,index)=>({pair,index,method})));
  const dataByPair=new Map();
  for(let start=0;start<queries.length;start+=120){
   const jobs=queries.slice(start,start+120);
   const tuple=jobs.map(x=>x.pair.slice(2).padStart(64,"0")+word(1)+word(96)+word(4)+x.method+"0".repeat(56));
   const args=word(32)+word(jobs.length)+jobs.map((_,i)=>word(32*jobs.length+160*i)).join("")+tuple.join("");
   const buf=(await rpc(multicall,"0x82ad56cb"+args)).slice(2);
   const read=offset=>{
    const part=buf.slice(offset*2,(offset+32)*2);
    if(part.length!==64)throw Error("Fraxlend Multicall response truncated");
    return Number(BigInt("0x"+part));
   };
   const off=read(0),len=read(off),base=off+32;
   if(len!==jobs.length)throw Error("Fraxlend Multicall count mismatch");
   for(let i=0;i<len;i++){
    const x=jobs[i],p=base+read(base+i*32),success=read(p)!==0,dataOff=read(p+32);
    const size=read(p+dataOff),payload=buf.slice((p+dataOff+32)*2,(p+dataOff+32+size)*2);
    if(success&&size&&payload.length===size*2){
     if(!dataByPair.has(x.pair))dataByPair.set(x.pair,{});
     dataByPair.get(x.pair)[x.index]=payload;
    }
   }
  }
  const parsed=[];
  for(const pair of pairs){
   const v=dataByPair.get(pair)||{};
   const asset=opAddr("0x"+String(v[0]||"").slice(24,64));
   const collateral=opAddr("0x"+String(v[1]||"").slice(24,64));
   const origin=opAddr("0x"+String(v[4]||"").slice(24,64));
   // Verify the pair itself authenticates the deployed registry origin,
   // not merely that a registry returned an arbitrary address.
   if(!asset||!collateral||!v[2]||v[2].length<320||
      origin!==pairDeployer.get(pair))continue;
   const amount=BigInt("0x"+v[2].slice(0,64)),borrow=BigInt("0x"+v[2].slice(128,192));
   const rate=v[3]?.length>=320?Number(BigInt("0x"+v[3].slice(192,256))):null;
   const fee=v[3]?.length>=320?Number(BigInt("0x"+v[3].slice(64,128))):null;
   parsed.push({pair,asset,collateral,amount,borrow,rate,fee});
  }
  if(parsed.length<Math.min(10,pairs.length))throw Error("Fraxlend resolved too few pair ABIs: "+parsed.length+"/"+pairs.length);
  fraxlendDecodedCount=parsed.length;
  const tokens=[...new Set(parsed.flatMap(x=>[x.asset,x.collateral]))],pricedTokens={};
  // Bounded price reads prevent long registry queries from exceeding URL limits.
  // No partial pair uploads if a price batch fails.
  for(let first=0;first<tokens.length;first+=60){
   const part=tokens.slice(first,first+60);
   const quote=await opGet("https://coins.llama.fi/prices/current/"+
    part.map(x=>"ethereum:"+x).join(","));
   if(!quote?.coins||typeof quote.coins!=="object")
    throw Error("Fraxlend token USD price batch "+first+" unavailable");
   Object.assign(pricedTokens,quote.coins);
  }
  const identityCounts=new Map();
  for(const pair of parsed){
   const key=pair.asset+":"+pair.collateral;
   identityCounts.set(key,(identityCounts.get(key)||0)+1);
  }
  const additions=[];
  let priced=0;
  for(const x of parsed){
   const meta=pricedTokens["ethereum:"+x.asset],coll=pricedTokens["ethereum:"+x.collateral];
   const decimal=Number(meta?.decimals),price=Number(meta?.price);
   if(!Number.isInteger(decimal)||decimal<0||decimal>30||!Number.isFinite(price)||price<=0)continue;
   priced++;
   const usd=Number(x.amount)/10**decimal*price;
   if(!Number.isFinite(usd)||usd<=100)continue;
   const util=x.amount>0n?Math.max(0,Math.min(1,Number(x.borrow)/Number(x.amount))):0;
   const apr=x.rate!==null&&x.fee!==null&&x.fee>=0&&x.fee<=100000?
    x.rate/1e18*31536000*100*util*(1-x.fee/100000):null;
   const sym=String(meta?.symbol||x.asset.slice(0,10)),csym=String(coll?.symbol||x.collateral.slice(0,10));
   additions.push({protocol:"Fraxlend",address:x.pair,asset:x.asset,assetSymbol:sym,
    collateralToken:x.collateral,collateralSymbol:csym,marketName:"Fraxlend "+csym+" / "+sym,
    tvlUsdEstimate:usd,tvlSource:"Fraxlend onchain supplied amount × USD token price",
    analyticsUrl:null,fraxlendDeployer:pairDeployer.get(x.pair),
    fraxUniquePair:identityCounts.get(x.asset+":"+x.collateral)===1,
    utilizationPercent:util*100,
    lendApr:Number.isFinite(apr)?apr:null,rateType:"APR",rateSource:"Fraxlend onchain last ratePerSec, utilization and protocol fee",
    sourceUrl:"https://etherscan.io/address/"+x.pair,registryVerified:true,
    depositMode:"single-token",directDepositCompatible:true});
  }
  if(priced<Math.min(10,parsed.length))throw Error("Fraxlend too few priced assets: "+priced+"/"+parsed.length);
  fraxlendPricedCount=priced;

  // Single-token pair viability: the actual ERC-4626 deposit limit must have
  // available capacity, and withdrawing principal must not be paused.
  // Batch only priced candidates, not the entire 2k-pair universe.
  const prospective=additions.filter(x=>x.lendApr!==null&&x.lendApr>1);
  const gates=new Map();
  const queriesGate=prospective.flatMap(x=>[
   {pair:x.address,key:"limit",sel:"ecf70858"},
   {pair:x.address,key:"maxDeposit",sel:"402d267d"+
    "000000000000000000000000000000000000000000000000000000000000dead"},
   {pair:x.address,key:"withdrawPaused",sel:"67800b5f"}]);
  for(let start=0;start<queriesGate.length;start+=100){
   const jobs=queriesGate.slice(start,start+100);
   const tuples=jobs.map(x=>{
    const data=x.sel,bytes=data.length/2;
    return x.pair.slice(2).padStart(64,"0")+word(1)+word(96)+word(bytes)+
     data.padEnd(Math.ceil(bytes/32)*64,"0");
   });
   let cursor=jobs.length*32;
   const offsets=tuples.map(t=>{const o=word(cursor);cursor+=t.length/2;return o});
   const args=word(32)+word(jobs.length)+offsets.join("")+tuples.join("");
   const buffer=(await rpc(multicall,"0x82ad56cb"+args)).slice(2);
   const read=pos=>{
    const hex=buffer.slice(pos*2,(pos+32)*2);
    if(hex.length!==64)throw Error("Fraxlend gate batch truncated");
    return Number(BigInt("0x"+hex));
   };
   const off=read(0),count=read(off),base=off+32;
   if(count!==jobs.length)throw Error("Fraxlend gate batch size mismatch");
   for(let i=0;i<count;i++){
    const j=jobs[i],p=base+read(base+i*32),success=read(p)!==0,offset=read(p+32);
    const n=read(p+offset),hex=buffer.slice((p+offset+32)*2,(p+offset+32+n)*2);
    if(!success||n!==32||hex.length!==64)continue;
    if(!gates.has(j.pair))gates.set(j.pair,{});
    gates.get(j.pair)[j.key]=BigInt("0x"+hex);
   }
  }
  const accounting=new Map(parsed.map(x=>[x.pair,x]));
  const eligible=prospective.filter(x=>{
   const gate=gates.get(x.address),original=accounting.get(x.address);
   if(!gate||gate.limit==null||gate.maxDeposit==null||gate.withdrawPaused!==0n||!original)return false;
   if(gate.limit<=original.amount||gate.maxDeposit<=0n)return false;
   x.depositCapacityRaw=String(gate.maxDeposit<gate.limit-original.amount?
    gate.maxDeposit:gate.limit-original.amount);
   return true;
  });
  if(eligible.length<prospective.length)
   gaps.push("Fraxlend suppressed "+(prospective.length-eligible.length)+
    " no-capacity/withdraw-paused/unsupported-ABI single-asset pairs");
  // Commit an authoritative complete registry read atomically, replacing overlapping aggregator rows.
  for(const [key,row] of out)if(row.protocol==="Fraxlend")out.delete(key);
  for(const x of eligible){
   put(x);
   const entry=out.get("1:fraxlend:"+x.address+":"+x.asset+":");
   if(entry){entry.tvlSource=x.tvlSource;entry.collateralToken=x.collateralToken;entry.collateralSymbol=x.collateralSymbol}
  }
  fraxlendCatalogCount=eligible.length;
 });

 await collect("Balancer official Ethereum BPT token composition",async()=>{
  const endpoint="https://api-v3.balancer.fi",all=new Map();
  let finished=false;
  for(let page=0;page<9;page++){
   const query="{poolGetPools(where:{chainIn:[MAINNET],minTvl:100},first:200,skip:"+
    String(page*200)+"){id address name symbol version type poolTokens{address symbol balance hasNestedPool} "+
    "dynamicData{totalLiquidity}}}";
   const r=await fetch(endpoint,{method:"POST",headers:{"content-type":"application/json","accept":"application/json"},
    body:JSON.stringify({query}),signal:AbortSignal.timeout(18000)});
   const j=await r.json().catch(()=>null);
   if(!r.ok)throw Error("Balancer GraphQL HTTP "+r.status+" "+JSON.stringify(j?.errors||j).slice(0,130));
   if(j?.errors?.length)throw Error("Balancer GraphQL schema: "+j.errors.map(e=>e.message).join("; ").slice(0,220));
   if(!Array.isArray(j?.data?.poolGetPools))throw Error("Balancer poolGetPools result is not an array");
   const pools=j.data.poolGetPools;
   for(const p of pools){
    const lp=opAddr(p.address),rows=Array.isArray(p.poolTokens)?p.poolTokens:[];
    if(!lp||!rows.length)continue;
    const coins=rows.map(t=>{
     const address=opAddr(t.address),balance=opNum(t.balance);
     return {address,symbol:String(t.symbol||"").slice(0,35),
      decimals:null,poolBalanceRaw:null,balance,usdPrice:null,usdValue:null,poolSharePct:null,
      isBasePoolLpToken:!!t.hasNestedPool};
    }).filter(c=>c.address&&c.address!==lp);
    if(!coins.length)continue;
    const underlying=(Array.isArray(p.allTokens)?p.allTokens:[])
     .map(t=>({address:opAddr(t.address),symbol:String(t.name||"Token").slice(0,35),
      decimals:null,poolBalanceRaw:null,balance:null,usdPrice:null,usdValue:null,poolSharePct:null}))
     .filter(t=>t.address&&!coins.some(c=>c.address===t.address));
    all.set(lp,{
     lpToken:lp,poolAddress:lp,poolName:String(p.name||"Balancer Pool").slice(0,105),
     lpSymbol:String(p.symbol||"BPT").slice(0,35),
     poolRegistry:"Balancer V"+String(p.version??"?")+" "+String(p.type||"").slice(0,32),
     tvlUsd:opNum(p.dynamicData?.totalLiquidity),gaugeAddress:null,
     coins,underlyingCoins:underlying,
     singleCoinCandidates:coins.map(c=>({address:c.address,symbol:c.symbol,
      requiresMetaRoute:!!c.isBasePoolLpToken,kind:"Balancer router add-liquidity quote candidate"})),
     underlyingCandidates:underlying.map(c=>({address:c.address,symbol:c.symbol,
      kind:"nested Balancer pool token; router route required"})),
     compositionStatus:"Balancer native constituent token balances; no token USD weights",
     sourceUrl:endpoint});
   }
   if(pools.length<200){finished=true;break}
  }
  if(!finished)gaps.push("Balancer pool registry pagination reached configured limit");
  let matched=0;
  for(const row of out.values()){
   const bpt=all.get(row.asset);
   if(!bpt)continue;
   if(row.lpComposition?.coins?.length&&row.lpComposition?.compositionStatus!=="symbolic-only-unresolved-addresses")
    continue;
   row.lpComposition=bpt;row.depositAssetType="balancer-bpt";
   row.singleTokenConversionStatus="Balancer router join quote and adapter required";
   matched++;
  }
 });
 if(status.some(x=>x.name==="Beefy official vault/TVL/APY"&&x.status==="ok")){
  for(const [key,value] of out)if(value.protocol==="Beefy Vaults"&&!value.registryVerified)out.delete(key);
 }

 // Native registries are authoritative when available: remove only opaque
 // DeFiLlama rows for already fully indexed protocol versions, not native rows.
 // This avoids double counting the same Aave reserve via a second synthetic ID.
 const authoritative=[
  ["Aave V3","Aave V3 native GraphQL Ethereum market reserves"],
  ["Aave V4","Aave V4 native GraphQL Ethereum spoke reserves"],
  ["Stake DAO","Stake DAO Hub comprehensive Ethereum VaultV2/V1"]
 ];
 for(const [protocol,source] of authoritative){
  if(!status.some(x=>x.name===source&&x.status==="ok"))continue;
  for(const [id,row] of out){
   if(row.protocol===protocol&&!row.registryVerified&&row.rateSource==="DeFiLlama public yields")out.delete(id);
  }
 }
 // Resolve opaque-index Yearn entries only when a single official Kong vault
 // has the identical underlying and matching USD TVL/APY evidence.
 const nativeYearn=[...out.values()].filter(x=>(x.protocol==="Yearn V2"||x.protocol==="Yearn V3")&&x.address&&x.registryVerified);
 let yearnNativeJoins=0;
 for(const x of out.values()){
  if(x.protocol!=="Yearn Vaults"||x.address||x.additionalAssets?.length)continue;
  const norm=z=>String(z||"").toLowerCase().replace(/[^a-z0-9]/g,"");
  const matches=nativeYearn.filter(y=>{
   if(y.asset!==x.asset)return false;
   const sameName=norm(x.marketName).length>=5&&norm(x.marketName)===norm(y.marketName);
   const tvlDelta=Math.abs(x.tvlUsdEstimate-y.tvlUsdEstimate)/Math.max(100,x.tvlUsdEstimate,y.tvlUsdEstimate);
   if(tvlDelta>(sameName?0.25:0.025))return false;
   if(x.lendApr!=null&&y.lendApr!=null&&Math.abs(x.lendApr-y.lendApr)>(sameName?8:3))return false;
   return true;
  });
  if(matches.length===1){
   x.address=matches[0].address;x.registryVerified=true;x.indexOnly=false;
   x.resolutionSource="unique Yearn Kong asset, TVL and rate match";yearnNativeJoins++;
  }
 }
 const discovered=[...out.values()].sort((a,b)=>b.tvlUsdEstimate-a.tvlUsdEstimate);
 // Recompute contract-specific front-end routes after official provider reconciliation.
 for(const x of discovered){
  const link=opDappLink(x,x.address,x.marketId,x.asset);
  x.dappUrl=link.url;x.dappLinkType=link.kind;
 }
 const opportunities=discovered.filter(opEligibleDiscovery),counts={};
 // Single-token-only: the research alias cannot list LPs, baskets, locked
 // strategies, conversion candidates or any other non-direct input.
 const researchOpportunities=opportunities.map(x=>({
  ...x,discoveryTier:"verified-direct",yieldVerified:true,
  annualizedAprPercent:opAnnualizedApr(x),
  routeStatus:"source-bound-single-asset-dapp-route",
  eligibleForVaultAllocation:false
 }));
 const filteredOutCount=discovered.length-opportunities.length;
 for(const x of opportunities){
  counts[x.protocol]=(counts[x.protocol]||0)+1;
  if(x.protocol==="Beefy Vaults"&&!x.lpComposition&&x.beefyAssetSymbols?.length>1){
   x.depositAssetType="unresolved-lp";
   x.lpComposition={lpToken:x.asset,poolAddress:null,poolName:x.marketName,
    lpSymbol:x.assetSymbol,poolRegistry:"Beefy vault metadata",
    tvlUsd:null,gaugeAddress:null,coins:[],underlyingCoins:[],
    symbolicComponents:x.beefyAssetSymbols,
    singleCoinCandidates:[],underlyingCandidates:[],
    compositionStatus:"symbolic-only-unresolved-addresses",
    sourceUrl:"https://api.beefy.finance/vaults"};
  }
 }
 // Deliberately excluded protocols are not source failures or coverage gaps.
 return {chainId:1,count:opportunities.length,
  discoveryFilter:{singleAsset:true,depositTokenMatchesListedAsset:true,aprGreaterThanPercent:1,annualizedAprFromApy:true,requiresOfficialContractSpecificDapp:true,requiresNativeProtocolSource:true,accepted:opportunities.length,rejected:filteredOutCount},
  fraxlendRegisteredCount,fraxlendDecodedCount,fraxlendPricedCount,fraxlendCatalogCount,yearnNativeJoins,yearnLegacyMatchedCount,convexNativeJoins,
  convexBoosterResolvedCount:opportunities.filter(x=>x.protocol==="Convex Finance"&&x.boosterPid!=null&&x.address).length,
  convexNativePricedCount:opportunities.filter(x=>x.protocol==="Convex Finance"&&!!x.tvlSource).length,
  lpCompositionCount:opportunities.filter(x=>x.lpComposition?.coins?.length).length,
  lpNativeCount:opportunities.filter(x=>x.lpComposition?.coins?.length&&x.lpComposition?.sourceUrl?.includes("api.curve.finance")).length,
  depositAssetIdentifiedCount:opportunities.filter(x=>!x.depositMode.startsWith("underlying basket;")).length,
  indexOnlyCount:opportunities.filter(x=>x.indexOnly).length,
  basketOnlyCount:opportunities.filter(x=>x.depositMode.startsWith("underlying basket;")).length,
  counts,opportunities,researchOpportunities,researchCount:researchOpportunities.length,
  researchCounts:researchOpportunities.reduce((m,x)=>(m[x.protocol]=(m[x.protocol]||0)+1,m),{}),
  updatedAt:new Date().toISOString(),
  minTvlUsdExclusive:100,sourceStatus:status,sourceFailures:failures,coverageWarnings:gaps,
  partial:!!(failures.length||gaps.length),storage:{r2Writes:0,durableWrites:0,cache:"edge cache + memory",ttlSeconds:OP_TTL}};
}
async function opCatalog(research=false,sourceOnly=null){
 const state=sourceOnly==="Euler Earn official Ethereum curated vaults"?opStates.eulerearn:sourceOnly==="Harvest official Ethereum vault registry API"?opStates.harvest:sourceOnly==="Sky official Ethereum Savings ERC4626 contracts"?opStates.sky:sourceOnly==="Spark official Ethereum Savings V2 REST"?opStates.spark:sourceOnly==="Silo V3 official Ethereum GraphQL markets"?opStates.silo:sourceOnly==="Gearbox official Ethereum passive ERC4626 pools"?opStates.gearbox:sourceOnly==="Morpho Blue complete Ethereum market index"?opStates.morphoblue:sourceOnly==="Morpho Vault V1 bulk USD"?opStates.morphov1:sourceOnly==="Morpho Vault V2 bulk USD"?opStates.morphov2:sourceOnly==="Curve official Ethereum lending"?opStates.curve:sourceOnly==="Maple Finance official V2 pools"?opStates.maple:sourceOnly==="Yearn Kong REST V2/V3"?opStates.yearn:sourceOnly==="Fluid official fTokens"?opStates.fluid:sourceOnly==="IPOR Fusion v2"?opStates.ipor:sourceOnly==="Stake DAO native locker registry"?opStates.stakedao:(sourceOnly?opStates.fraxlend:(research?opStates.research:opStates.verified));
 const key=new Request(sourceOnly==="Euler Earn official Ethereum curated vaults"?"https://markets.curveyield.org/__catalog_eulerearn_180":sourceOnly==="Harvest official Ethereum vault registry API"?"https://markets.curveyield.org/__catalog_harvest_187":sourceOnly==="Sky official Ethereum Savings ERC4626 contracts"?"https://markets.curveyield.org/__catalog_sky_155":sourceOnly==="Spark official Ethereum Savings V2 REST"?"https://markets.curveyield.org/__catalog_spark_166":sourceOnly==="Silo V3 official Ethereum GraphQL markets"?"https://markets.curveyield.org/__catalog_silo_151":sourceOnly==="Gearbox official Ethereum passive ERC4626 pools"?"https://markets.curveyield.org/__catalog_gearbox_145":sourceOnly==="Morpho Blue complete Ethereum market index"?"https://markets.curveyield.org/__catalog_morphoblue_138":sourceOnly==="Morpho Vault V1 bulk USD"?"https://markets.curveyield.org/__catalog_morphov1_138":sourceOnly==="Morpho Vault V2 bulk USD"?"https://markets.curveyield.org/__catalog_morphov2_138":sourceOnly==="Curve official Ethereum lending"?"https://markets.curveyield.org/__catalog_curve_135":sourceOnly==="Maple Finance official V2 pools"?"https://markets.curveyield.org/__catalog_maple_135":sourceOnly==="Yearn Kong REST V2/V3"?"https://markets.curveyield.org/__catalog_yearn_136":sourceOnly==="Fluid official fTokens"?"https://markets.curveyield.org/__catalog_fluid_133":sourceOnly==="IPOR Fusion v2"?"https://markets.curveyield.org/__catalog_ipor_128":sourceOnly==="Stake DAO native locker registry"?"https://markets.curveyield.org/__catalog_stakedao_125":sourceOnly?"https://markets.curveyield.org/__catalog_fraxlend_132":research?OP_RESEARCH_CACHE:OP_CACHE);
 if(state.memory&&Date.now()<state.expire)return state.memory;
 if(state.promise)return state.promise;
 state.promise=(async()=>{
  try{
   if(typeof caches!=="undefined"&&caches.default){
    const response=await caches.default.match(key);
    if(response?.ok){const d=await response.json();if((d?.opportunities?.length||(sourceOnly&&Array.isArray(d?.opportunities)&&!d.sourceFailures?.length&&d.sourceStatus?.some(x=>x.name===sourceOnly&&x.status==="ok")))&&(!research||Array.isArray(d.researchOpportunities))){
     state.memory=d;state.expire=Date.now()+OP_TTL*1000;return d
    }}
   }
   const data=await opBuild(research,sourceOnly);
   if(!sourceOnly&&(research?!data.researchOpportunities?.length:!data.opportunities.length))
    throw Error("No priced qualifying entries from public APIs");
   state.memory=data;state.expire=Date.now()+OP_TTL*1000;
   if(typeof caches!=="undefined"&&caches.default)try{
    await caches.default.put(key,new Response(JSON.stringify(data),
     {headers:{"content-type":"application/json","cache-control":"public,max-age="+OP_TTL}}));
   }catch(e){}
   return data;
  }catch(e){if(state.memory){state.expire=Date.now()+120000;
   return {...state.memory,stale:true,refreshError:String(e)}}throw e}
 })();
 try{return await state.promise}finally{state.promise=null}
}
// Merge bounded native provider snapshots from edge cache only: no additional RPCs.
const CY_NATIVE_SPECS=[
  {id:"stakedao",name:"Stake DAO native locker registry",cache:"__catalog_stakedao_125",protocols:["Stake DAO Lockers"]},
  {id:"ipor",name:"IPOR Fusion v2",cache:"__catalog_ipor_128",gate:"IPOR onchain ERC4626 deposit capacity",protocols:["IPOR Fusion"]},
  {id:"fluid",name:"Fluid official fTokens",cache:"__catalog_fluid_133",gate:"Fluid onchain ERC4626 deposit capacity",protocols:["Fluid Lending"]},
  {id:"yearn",name:"Yearn Kong REST V2/V3",cache:"__catalog_yearn_136",gate:"Independent ERC4626 deposit eligibility",protocols:["Yearn V2","Yearn V3"]},
  {id:"curve",name:"Curve official Ethereum lending",cache:"__catalog_curve_135",gate:"Independent ERC4626 deposit eligibility",protocols:["CurveLend V1","CurveLend V2"]},
  {id:"maple",name:"Maple Finance official V2 pools",cache:"__catalog_maple_135",gate:"Independent ERC4626 deposit eligibility",protocols:["Maple Syrup"]},
  {id:"morphoblue",name:"Morpho Blue complete Ethereum market index",cache:"__catalog_morphoblue_138",protocols:["Morpho Blue"]},
  {id:"morphov1",name:"Morpho Vault V1 bulk USD",cache:"__catalog_morphov1_138",protocols:["Morpho Vault V1"]},
  {id:"morphov2",name:"Morpho Vault V2 bulk USD",cache:"__catalog_morphov2_138",protocols:["Morpho Vault V2"]},
  {id:"gearbox",name:"Gearbox official Ethereum passive ERC4626 pools",cache:"__catalog_gearbox_145",protocols:["Gearbox Pools"]},
  {id:"silo",name:"Silo V3 official Ethereum GraphQL markets",cache:"__catalog_silo_151",protocols:["Silo Vaults"]},
  {id:"spark",name:"Spark official Ethereum Savings V2 REST",cache:"__catalog_spark_166",protocols:["Spark Savings"]},
  {id:"sky",name:"Sky official Ethereum Savings ERC4626 contracts",cache:"__catalog_sky_155",protocols:["Sky Savings"]},
  {id:"harvest",name:"Harvest official Ethereum vault registry API",cache:"__catalog_harvest_187",protocols:["Harvest Finance"]},
  {id:"eulerearn",name:"Euler Earn official Ethereum curated vaults",cache:"__catalog_eulerearn_180",protocols:["Euler Earn"]}
 ];
async function opMergeNativeCaches(d){
 const specs=CY_NATIVE_SPECS;
 const map=new Map(d.opportunities.map(x=>[x.id,x]));
 const status=[...(d.sourceStatus||[])],failed=[...(d.sourceFailures||[])],gaps=[...(d.coverageWarnings||[])],snapshots={};
 let rejected=Number(d.discoveryFilter?.rejected||0);
 for(const spec of specs){
  let f=null;
  const state=opStates[spec.id];
  if(state?.memory&&Date.now()<state.expire)f=state.memory;
  if(!f&&typeof caches!=="undefined"&&caches.default)try{
   const hit=await caches.default.match(new Request("https://markets.curveyield.org/"+spec.cache));
   if(hit?.ok)f=await hit.json();
  }catch(e){}
  const valid=Array.isArray(f?.opportunities)&&!f?.sourceFailures?.length&&
   f.sourceStatus?.some(x=>x.name===spec.name&&x.status==="ok")&&
   (!spec.gate||f.sourceStatus.some(x=>x.name===spec.gate&&x.status==="ok"));
  if(!valid){gaps.push("Unverified or cold source cache: "+spec.id);continue}
  for(const [id,x] of map)if(spec.protocols.includes(x.protocol))map.delete(id);
  for(const x of f.opportunities)if(spec.protocols.includes(x.protocol)&&opEligibleDiscovery(x))map.set(x.id,x);
  status.push(...f.sourceStatus);
  rejected+=Number(f.discoveryFilter?.rejected||0);
  snapshots[spec.id]=f.updatedAt;
 }
 const opportunities=[...map.values()].sort((x,y)=>y.tvlUsdEstimate-x.tvlUsdEstimate),counts={};
 for(const x of opportunities)counts[x.protocol]=(counts[x.protocol]||0)+1;
 return {...d,opportunities,count:opportunities.length,counts,
  sourceStatus:status,sourceFailures:failed,coverageWarnings:gaps,
  partial:!!(failed.length||gaps.length),sourceSnapshots:snapshots,
  discoveryFilter:{...d.discoveryFilter,accepted:opportunities.length,rejected}};
}
/* v81: inventory-wide destination audit, computed from the actual catalog. */
function opLinkStats(rows){
 const result={total:rows.length,marketSpecific:0,legacyMarketSpecific:0,protocolDirectory:0,missing:0,byProtocol:{}};
 for(const x of rows){
  const kind=x.dappLinkType==="detail"?"marketSpecific":x.dappLinkType==="legacy-detail"?"legacyMarketSpecific":
   x.dappLinkType==="protocol-directory"&&typeof x.dappUrl==="string"&&
   x.dappUrl.startsWith("https://")&&!x.dappUrl.includes("markets.curveyield.org")?"protocolDirectory":"missing";
  result[kind]++;
  const row=result.byProtocol[x.protocol]||(result.byProtocol[x.protocol]={total:0,marketSpecific:0,legacyMarketSpecific:0,protocolDirectory:0,missing:0});
  row.total++;row[kind]++;
 }
 return result;
}

/* v188 persistent Markets catalog. Native verification remains unchanged.
   Cron: every three minutes (one provider batch per slot; aggregate publication at :51).
   No public request writes R2. All token views are complete atomic objects. */
const CY_CAT_PREFIX="catalog/v1/1/";
const CY_CAT_SPECS=[{id:"base",name:null,protocols:["Aave V3","Aave V4","Beefy Vaults","Compound III","Euler EVK","SparkLend"]},...CY_NATIVE_SPECS,{id:"fraxlend",name:"Fraxlend native registry and pair-level Ethereum RPC",protocols:["Fraxlend"]}];
const CY_CAT_HOUR=3600000;
async function cyCatGet(bucket,key){const obj=await bucket.get(CY_CAT_PREFIX+key);return obj?{etag:obj.etag,doc:await obj.json()}:null}
async function cyCatPut(bucket,key,doc,prior){const options={httpMetadata:{contentType:"application/json"}};
 if(prior!==undefined)options.onlyIf=prior?{etagMatches:prior.etag}:{etagDoesNotMatch:"*"};
 return bucket.put(CY_CAT_PREFIX+key,JSON.stringify(doc),options);
}
async function cyCatBatch(bucket,spec,epoch){
 const key="source/"+spec.id+".json",prior=await cyCatGet(bucket,key);
 if(prior?.doc?.epoch>=epoch)return;
 const d=await opBuild(false,spec.name);
 if(d.partial||d.sourceFailures?.length||!Array.isArray(d.opportunities)||
   (spec.name&&!d.sourceStatus?.some(x=>x.name===spec.name&&x.status==="ok"))||
   (spec.gate&&!d.sourceStatus?.some(x=>x.name===spec.gate&&x.status==="ok")))
   throw Error("Incomplete native batch: "+spec.id);
 if(!spec.name&&d.sourceStatus?.filter(x=>x.status==="ok").length<7)throw Error("Incomplete base sources");
 const opportunities=d.opportunities.filter(x=>spec.protocols.includes(x.protocol)&&opEligibleDiscovery(x));
 const record={epoch,updatedAt:d.updatedAt,opportunities,sourceStatus:d.sourceStatus,discoveryFilter:d.discoveryFilter};
 await cyCatPut(bucket,key,record,prior);
}
async function cyCatParallel(items,fn){for(let i=0;i<items.length;i+=4)await Promise.all(items.slice(i,i+4).map(fn))}
async function cyCatPublish(bucket,epoch){
 const lock=await cyCatGet(bucket,"publish-lock.json");
 if(lock?.doc?.epoch>=epoch)return;
 const parts=new Map();
 await cyCatParallel(CY_CAT_SPECS,async spec=>{const p=await cyCatGet(bucket,"source/"+spec.id+".json");if(p?.doc)parts.set(spec.id,p.doc)});
 const missing=CY_CAT_SPECS.filter(s=>!parts.has(s.id));
 if(missing.length)throw Error("Initial catalog awaits "+missing.map(s=>s.id).join(","));
 const previous=await cyCatGet(bucket,"all.json");
 const rows=new Map(),counts={},byAsset=new Map(),status=[],warnings=[],asOf={};
 let rejected=0;
 for(const spec of CY_CAT_SPECS){
  const p=parts.get(spec.id);asOf[spec.id]=p.updatedAt;
  if(p.epoch<epoch)warnings.push("Last verified snapshot retained: "+spec.id+" ("+p.updatedAt+")");
  status.push(...p.sourceStatus);rejected+=Number(p.discoveryFilter?.rejected||0);
  for(const x of p.opportunities)if(opEligibleDiscovery(x))rows.set(x.id,{...x,metricsUpdatedAt:p.updatedAt,metricsStale:p.epoch<epoch});
 }
 const opportunities=[...rows.values()].sort((a,b)=>b.tvlUsdEstimate-a.tvlUsdEstimate);
 for(const x of opportunities){counts[x.protocol]=(counts[x.protocol]||0)+1;const a=x.asset.toLowerCase();if(!byAsset.has(a))byAsset.set(a,[]);byAsset.get(a).push(x)}
 // Include existing token objects so a successful complete removal clears old views.
 let cursor;
 do{const list=await bucket.list({prefix:CY_CAT_PREFIX+"token/",cursor,limit:1000});
  for(const x of list.objects){const a=x.key.slice((CY_CAT_PREFIX+"token/").length,-5);if(opAddr(a)&&!byAsset.has(a))byAsset.set(a,[])}
  cursor=list.truncated?list.cursor:undefined;
 }while(cursor);
 // R2 write budget: source batches hourly, token views at a cadence derived from the
 // requested <20% of the 1M monthly Class A free allocation (31-day worst case).
 const perDay=Math.floor(199999/31)-24*CY_CAT_SPECS.length;
 const interval=Math.max(1,Math.ceil(24*(byAsset.size+5)/perDay));
 if(epoch%interval!==0)return;
 if(byAsset.size+5>perDay)throw Error("Catalog publication exceeds authorized daily write budget");
 if(!await cyCatPut(bucket,"publish-lock.json",{epoch},lock))return;
 const updatedAt=new Date().toISOString(),stale=warnings.length>0;
 const linkStats=opLinkStats(opportunities),assetCounts={};
 for(const [a,x] of byAsset)if(x.length)assetCounts[a]={symbol:x[0].assetSymbol,count:x.length};
 const doc={chainId:1,epoch,updatedAt,count:opportunities.length,counts,assetCounts,
  opportunities,depositAssetIdentifiedCount:opportunities.length,indexOnlyCount:0,basketOnlyCount:0,lpCompositionCount:0,lpNativeCount:0,convexBoosterResolvedCount:0,convexNativePricedCount:0,
  discoveryFilter:{...parts.get("base").discoveryFilter,accepted:opportunities.length,rejected},
  sourceStatus:status,sourceFailures:[],coverageWarnings:warnings,partial:stale,stale,sourceSnapshots:asOf,
  persistentLinkStats:linkStats,storage:{r2Catalog:true,cache:"R2 persistent catalog + edge cache",protocolBatchCount:CY_CAT_SPECS.length,tokenCount:Object.keys(assetCounts).length,refreshHours:interval,readBatch:"one object per deposit token; aggregate one object",r2WritesOnRead:0}};
 const meta={...doc,opportunities:undefined};
 // Token views are individually atomic; aggregate is committed last. A failed
 // provider keeps its last verified batch. No temporary partial listing replaces it.
 await cyCatParallel([...byAsset],async ([a,x])=>{await cyCatPut(bucket,"token/"+a+".json",{...meta,opportunities:x})});
 // Preserve one immutable historical aggregate per UTC day, not per market.
 const day=updatedAt.slice(0,10);
 await cyCatPut(bucket,"history/"+day+".json",doc,null);
 await cyCatPut(bucket,"all.json",doc,previous);
}
async function cyCatRead(bucket,u){
 if(!bucket)return null;
 const raw=u.searchParams.get("asset")||"",asset=opAddr(raw);
 if(raw&&!asset)throw Error("Invalid deposit asset address");
 const key=asset?"token/"+asset+".json":"all.json";
 const cacheKey=new Request("https://markets.curveyield.org/__persistent_catalog_v1/"+key);
 let d=null;
 try{const hit=await caches.default.match(cacheKey);if(hit?.ok)d=await hit.json()}catch{}
 if(!d){
  const obj=await cyCatGet(bucket,key);
  if(!obj)return null;
  d=obj.doc;
  if(!d?.storage?.r2Catalog||!Array.isArray(d.opportunities))throw Error("Invalid persistent catalog");
  try{await caches.default.put(cacheKey,new Response(JSON.stringify(d),{headers:{"content-type":"application/json","cache-control":"public,max-age=90"}}))}catch{}
 }
 const old=Date.now()-Date.parse(d.updatedAt)>(Number(d.storage.refreshHours||1)+1)*CY_CAT_HOUR;
 return old?{...d,stale:true,partial:true,coverageWarnings:[...(d.coverageWarnings||[]),"Catalog refresh overdue; last verified data retained"]}:d;
}
async function cyCatScheduled(event,env){
 const bucket=env.MARKETS_CATALOG;if(!bucket)throw Error("Missing MARKETS_CATALOG R2 binding");
 const now=new Date(event.scheduledTime),epoch=Math.floor(event.scheduledTime/CY_CAT_HOUR),slot=Math.floor(now.getUTCMinutes()/3);
 if(slot<CY_CAT_SPECS.length)return cyCatBatch(bucket,CY_CAT_SPECS[slot],epoch);
 if(slot===CY_CAT_SPECS.length)return cyCatPublish(bucket,epoch);
}

function opPage(d,u){
 const research=u.searchParams.get("view")==="research";
 const sourceRows=d.opportunities;
 const a=String(u.searchParams.get("asset")||"").toLowerCase(),p=String(u.searchParams.get("protocol")||"all"),
 q=String(u.searchParams.get("q")||"").toLowerCase().slice(0,90),sort=u.searchParams.get("sort")||"tvl";
 const n=Math.min(500,Math.max(1,Number(u.searchParams.get("limit"))||100));
 const off=Math.min(1000000,Math.max(0,Number(u.searchParams.get("offset"))||0));
 const compatibleOnly=u.searchParams.get("compatible")==="1";
 const minYield=Math.max(0,Math.min(1000,Number(u.searchParams.get("minYield"))||0));
 const minTvl=Math.max(0,Math.min(1e12,Number(u.searchParams.get("minTvl"))||0));
 // No conversion route or multi-token option is supported.
 const matchKind=x=>a&&x.asset===a?"direct-token":null;
 const conversionRoute=x=>null;
 const arr=sourceRows.filter(x=>opEligibleDiscovery(x)&&
  (!a||x.asset===a)&&(p==="all"||x.protocol===p)&&(!minYield||Number(x.lendApr)>=minYield)&&(!minTvl||Number(x.tvlUsdEstimate)>=minTvl)&&
  (!q||(x.marketName+" "+x.protocol+" "+x.assetSymbol+" "+x.asset).toLowerCase().includes(q)));
 if(sort==="yield")arr.sort((x,y)=>(y.lendApr??-999)-(x.lendApr??-999)||y.tvlUsdEstimate-x.tvlUsdEstimate);
 else if(sort==="asset")arr.sort((x,y)=>String(x.assetSymbol||x.asset).localeCompare(String(y.assetSymbol||y.asset))||y.tvlUsdEstimate-x.tvlUsdEstimate);
 else arr.sort((x,y)=>y.tvlUsdEstimate-x.tvlUsdEstimate);
 return {chainId:1,updatedAt:d.updatedAt,view:research?"research":"verified",
  count:research?d.researchCount:d.count,counts:research?d.researchCounts:d.counts,
  discoveryFilter:d.discoveryFilter,
  depositAssetIdentifiedCount:d.depositAssetIdentifiedCount,indexOnlyCount:d.indexOnlyCount,basketOnlyCount:d.basketOnlyCount,lpCompositionCount:d.lpCompositionCount,lpNativeCount:d.lpNativeCount,convexBoosterResolvedCount:d.convexBoosterResolvedCount,convexNativePricedCount:d.convexNativePricedCount,
  lpCompositionCount:d.lpCompositionCount,lpNativeCount:d.lpNativeCount,convexBoosterResolvedCount:d.convexBoosterResolvedCount,convexNativePricedCount:d.convexNativePricedCount,convexBoosterResolvedCount:d.convexBoosterResolvedCount,convexNativePricedCount:d.convexNativePricedCount,
  linkStats:d.persistentLinkStats||opLinkStats(sourceRows),partial:d.partial,stale:!!d.stale,
  minTvlUsdExclusive:100,sourceStatus:d.sourceStatus,sourceFailures:d.sourceFailures,sourceSnapshots:d.sourceSnapshots,assetCounts:d.assetCounts,
  coverageWarnings:d.coverageWarnings,total:arr.length,limit:n,offset:off,hasMore:off+n<arr.length,
  opportunities:arr.slice(off,off+n).map(x=>a?({...x,matchKind:matchKind(x),conversionRoute:conversionRoute(x)}):x),storage:d.storage};
}


/* v48: coalesced Fraxtal registry index, previously RPC-scanned on every HTTP request. */
const FRX_CACHE="https://markets.curveyield.org/__fraxtal_discovery_v48",FRX_TTL=300000;
let frxHot=null,frxDeadline=0,frxInFlight=null;
async function frxCached(){
 if(frxHot&&Date.now()<frxDeadline)return frxHot;
 if(frxInFlight)return frxInFlight;
 frxInFlight=(async()=>{
  const key=new Request(FRX_CACHE);
  if(typeof caches!=="undefined"&&caches.default){
   try{
    const found=await caches.default.match(key);
    if(found?.ok){const cached=await found.json();if(Array.isArray(cached?.opportunities)){
     frxHot=cached;frxDeadline=Date.now()+FRX_TTL;return cached;
    }}
   }catch(e){}
  }
  const fresh=await cyFraxtalLendingCatalogue();
  if(!Array.isArray(fresh?.opportunities))throw Error("Fraxtal index returned malformed catalog");
  frxHot=fresh;frxDeadline=Date.now()+FRX_TTL;
  if(typeof caches!=="undefined"&&caches.default)try{
   await caches.default.put(key,new Response(JSON.stringify(fresh),
    {headers:{"content-type":"application/json","cache-control":"public,max-age=300"}}));
  }catch(e){}
  return fresh;
 })();
 try{return await frxInFlight}catch(e){
  if(frxHot){frxDeadline=Date.now()+60000;return {...frxHot,stale:true,refreshError:String(e?.message||e)}}
  throw e;
 }finally{frxInFlight=null}
}


// CURVEYIELD_CURATOR_PREVIEW_V1: isolated visual-only UI, no chain writes.
// Assets are compressed only to keep the Worker under the existing source-size limit.
async function cyCuratorPreviewAsset(which,method){
 const filename=which==="html"?"index.html.gz":which==="css"?"app.css.gz":which==="js"?"app.js.gz":null;
 if(!filename)return new Response("Not found",{status:404});
 const mime=which==="html"?"text/html; charset=utf-8":which==="css"?"text/css; charset=utf-8":"text/javascript; charset=utf-8";
 const headers={"content-type":mime,"content-encoding":"gzip","cache-control":"public, max-age=300","x-content-type-options":"nosniff"};
 if(method==="HEAD")return new Response(null,{headers});
 try{
  const upstream=await fetch("https://raw.githubusercontent.com/curveyield3/Smart-Contracts/499c1501a9fdfeb2308ed366503916e8b4c67001/CurveYield%20Markets/Marketplace%20Web%20UI/site/"+filename,{cf:{cacheEverything:true,cacheTtl:300}});
  if(!upstream.ok)return new Response("Preview asset unavailable",{status:502});
  const bytes=await upstream.arrayBuffer();
  if(bytes.byteLength<100||bytes.byteLength>200000)return new Response("Invalid preview asset",{status:502});
  return new Response(bytes,{headers,encodeBody:"manual"});
 }catch(e){return new Response("Preview asset temporarily unavailable",{status:503});}
}


// CurveYield Marketplace live visual integration v10: read-only markets and portfolio.
// Keep legacy create-market, create-vault, vault manager, mainnet opportunities and trading routes.
const CY_LIVE_MARKETPLACE_JS="https://raw.githubusercontent.com/curveyield3/Smart-Contracts/15225f18a7069609837d5824b303069cc077d50e/CurveYield%20Markets/Marketplace%20Web%20UI/site/marketplace-live-v12.js";
const CY_LIVE_MARKETPLACE_HTML="https://raw.githubusercontent.com/curveyield3/Smart-Contracts/499c1501a9fdfeb2308ed366503916e8b4c67001/CurveYield%20Markets/Marketplace%20Web%20UI/site/index.html.gz";
async function cyMarketplaceLiveHtml(request){
 try{
  const r=await fetch(CY_LIVE_MARKETPLACE_HTML,{cf:{cacheEverything:true,cacheTtl:300}});
  if(!r.ok)return new Response("Marketplace template unavailable",{status:503});
  const bytes=await r.arrayBuffer();
  if(bytes.byteLength<100||bytes.byteLength>200000)return new Response("Invalid marketplace template",{status:502});
  const html=await new Response(new Response(bytes).body.pipeThrough(new DecompressionStream("gzip"))).text();
  if(!html.includes('./app.css')||!html.includes('./app.js'))return new Response("Marketplace template integrity error",{status:502});
  const body=html.replace('href="./app.css"','href="/curator-preview/app.css"')
    .replace('src="./app.js"','src="/curator-preview/app.js"')
    .replace("<body>","<body data-cy-live>")
    .replace("</body>",'<script defer src="/assets/marketplace-live.js"></script></body>');
  const headers={...PAGE_HEADERS,"cache-control":"public, max-age=60"};
  return new Response(request.method==="HEAD"?null:body,{headers});
 }catch(e){return new Response("Marketplace template temporarily unavailable",{status:503});}
}
async function cyMarketplaceLiveScript(request){
 try{
  const r=await fetch(CY_LIVE_MARKETPLACE_JS,{cf:{cacheEverything:true,cacheTtl:300}});
  if(!r.ok)return new Response("Marketplace client unavailable",{status:503});
  const source=await r.text();
  if(source.length<500||source.length>45000||!source.includes("data-cy-live"))return new Response("Marketplace client integrity error",{status:502});
  return new Response(request.method==="HEAD"?null:source,{headers:{"content-type":"text/javascript; charset=utf-8","cache-control":"public, max-age=120","x-content-type-options":"nosniff"}});
 }catch(e){return new Response("Marketplace client temporarily unavailable",{status:503});}
}
const CY_CREATE_MARKET_STYLE_V10="\n/* CurveYield v10: approved Morpho-style create-market layout, preserve transaction controls. */\n.create-shell{width:min(100%,1280px);padding-inline:clamp(20px,4.5vw,68px);box-sizing:border-box}\n.create-head{text-align:center;padding-block:26px 34px}\n.create-head h1{text-align:center;font-size:clamp(30px,3vw,39px)}\n.create-head p{margin-inline:auto;max-width:740px}\n.create-grid{grid-template-columns:minmax(0,1.52fr) minmax(285px,.78fr);gap:20px}\n.create-card,.create-summary-card{padding:22px 23px;min-width:0}\n.create-card .create-field{display:grid;grid-template-columns:minmax(145px,.78fr) minmax(0,1.25fr);column-gap:15px;row-gap:5px;align-items:start}\n.create-card .create-field>span{margin:12px 0 0}\n.create-card .create-field input,.create-card .create-field select,.create-card .create-field .create-fee-input{min-width:0;max-width:100%;box-sizing:border-box}\n.create-card .create-field small{grid-column:2;min-width:0;margin:0}\n.create-card,.create-summary,.create-summary-card,.create-form,.create-grid{min-width:0}\n.create-review,.create-submit,.create-cta button{max-width:100%;box-sizing:border-box;overflow-wrap:anywhere}\n@media(max-width:1040px){.create-grid{grid-template-columns:minmax(0,1fr)}.create-summary{position:static}}\n@media(max-width:700px){.create-shell{padding-inline:16px}.create-head{padding-block:10px 26px}.create-card .create-field{grid-template-columns:minmax(0,1fr)}.create-card .create-field>span{margin:0}.create-card .create-field small{grid-column:1}.create-card,.create-summary-card{padding:17px}}\n";

// CurveYield Vault UI v11, Fraxtal only. The original VAULT_CLIENT owns all contract calls.
const CY_VAULT_UI_V12="86d3771b62797bdcf3ae0295040612240fba1074";
const CY_VAULT_ASSET_BASE="https://raw.githubusercontent.com/curveyield3/Smart-Contracts/"+CY_VAULT_UI_V12+"/CurveYield%20Markets/Marketplace%20Web%20UI/site/";
async function cyVaultUiAsset(path,request){
 const name=path.endsWith(".css")?"vault-ui-v11.css":"vault-ui-v12.js";
 try{
  const r=await fetch(CY_VAULT_ASSET_BASE+name,{cf:{cacheEverything:true,cacheTtl:300}});
  if(!r.ok)return new Response("Vault UI asset unavailable",{status:503});
  const content=await r.text();if(content.length<500||content.length>16000||!content.includes("cy-"))return new Response("Vault UI asset invalid",{status:502});
  return new Response(request.method==="HEAD"?null:content,{headers:{"content-type":name.endsWith(".css")?"text/css; charset=utf-8":"text/javascript; charset=utf-8","cache-control":"public, max-age=120","x-content-type-options":"nosniff"}});
 }catch(e){return new Response("Vault UI asset temporarily unavailable",{status:503});}
}
async function cyVaultExperienceHtml(request,isMarketCreate=false){
 const fallback=isMarketCreate?HTML:VAULT_HTML;
 try{
  const r=await fetch(CY_LIVE_MARKETPLACE_HTML,{cf:{cacheEverything:true,cacheTtl:300}});
  if(!r.ok)return new Response(request.method==="HEAD"?null:fallback,{headers:PAGE_HEADERS});
  const bytes=await r.arrayBuffer();
  if(bytes.byteLength<100||bytes.byteLength>200000)return new Response(request.method==="HEAD"?null:fallback,{headers:PAGE_HEADERS});
  const html=await new Response(new Response(bytes).body.pipeThrough(new DecompressionStream("gzip"))).text();
  if(!html.includes('<main id="content" class="page"></main>')||!html.includes('<script defer src="./app.js"></script>'))return new Response(request.method==="HEAD"?null:fallback,{headers:PAGE_HEADERS});
  const styles=isMarketCreate
   ?'<link rel="stylesheet" href="/assets/app.css"></head>'
   :'<link rel="stylesheet" href="/assets/app.css"><link rel="stylesheet" href="/assets/vaults.css"><link rel="stylesheet" href="/assets/vault-ui-v11.css"></head>';
  const scripts='<script defer src="https://boosthub.curveyield.org/vendor/ethers.umd.min.js"></script><script defer src="/assets/vault-ui-v12.js"></script><script defer src="'+(isMarketCreate?'/assets/app.js':'/assets/vaults.js')+'"></script>';
  const modified=html.replace('href="./app.css"','href="/curator-preview/app.css"')
    .replace('</head>',styles)
    .replace('<body>',isMarketCreate?'<body data-cy-market-create>':'<body data-cy-vault>')
    .replace('<main id="content" class="page"></main>','<main id="content" class="page"><div id="page" aria-live="polite"></div></main>')
    .replace('<button class="wallet-pill" type="button">','<button class="wallet-pill" id="walletButton" type="button">')
    .replace('<span class="wallet-name">curveyield.eth</span>','<span class="wallet-name" id="walletButtonText">Connect Wallet</span>')
    .replace('<span class="connected">Preview</span>','<span class="connected">Fraxtal</span>')
    .replace('<script defer src="./app.js"></script>',scripts);
  if(!modified.includes('id="walletButton"')||!modified.includes('id="page"'))return new Response(request.method==="HEAD"?null:fallback,{headers:PAGE_HEADERS});
  return new Response(request.method==="HEAD"?null:modified,{headers:{...PAGE_HEADERS,"cache-control":"public, max-age=45"}});
 }catch(e){return new Response(request.method==="HEAD"?null:fallback,{headers:PAGE_HEADERS});}
}

// Source-bound, read-only Fraxtal vault configuration + discovery — 2026-11-18.
const CY_V2_FRAXTAL_FACTORY="0x711bCE12269a3a496eFaABB8B9AD5A4485E08A24";
const CY_V2_SELECTORS=[
 ["Add adapter","60d54d41"],["Increase absolute cap","f6f98fd5"],
 ["Increase relative cap","2438525b"],["Change allocator","b192a84a"],
 ["Performance fee","70897b23"],["Management fee","fe56e232"],
 ["Increase timelock","47966291"],["Decrease timelock","5c1a1a4f"]
];
const cyV2Addr=x=>typeof x==="string"&&/^0x[0-9a-f]{40}$/i.test(x)?x.toLowerCase():null;
const cyV2HexAddress=n=>n==null?null:"0x"+n.toString(16).padStart(40,"0").slice(-40);
async function cyVaultReadiness(u){
 const vault=cyV2Addr(u.searchParams.get("address")),check=cyV2Addr(u.searchParams.get("check"));
 if(!vault)return {error:"Valid vault address required",status:400};
 const verification=(await rpc([ethCall(CY_V2_FRAXTAL_FACTORY,calldata("0x5edec50d",vault))]))[0];
 if(verification.error||oneWord(verification.result)!==1n)return {error:"Not factory-verified as a Fraxtal Vault V2",status:404};
 const calls=[ethCall(vault,"0x8da5cb5b"),ethCall(vault,"0xe66f53b7"),ethCall(vault,"0x5aa22bc8")];
 for(const [,selector] of CY_V2_SELECTORS){
  const abiWord=selector.padEnd(64,"0");
  calls.push(ethCall(vault,"0xe78ab14e"+abiWord));
  calls.push(ethCall(vault,"0xe470b8bc"+abiWord));
 }
 const result=await rpc(calls);
 const owner=cyV2HexAddress(oneWord(result[0]?.result)),curator=cyV2HexAddress(oneWord(result[1]?.result));
 const timelocks=CY_V2_SELECTORS.map(([name,selector],i)=>{
  const timeResult=result[3+2*i],abdResult=result[4+2*i],duration=oneWord(timeResult?.result),abd=oneWord(abdResult?.result);
  return {name,selector:"0x"+selector,seconds:duration===null?null:duration.toString(),abdicated:abd===null?null:abd!==0n,error:timeResult?.error||abdResult?.error||null};
 });
 const candidates=[owner,curator,check].filter(Boolean);
 const unique=[...new Set(candidates)];
 const roleResults=unique.length?await rpc(unique.map(a=>ethCall(vault,calldata("0xba03a75f",a)))):[];
 const sentinelChecks=unique.map((address,i)=>({address,isSentinel:oneWord(roleResults[i]?.result)===null?null:oneWord(roleResults[i].result)!==0n,error:roleResults[i]?.error||null}));
 return {chainId:252,vault,verified:true,factory:CY_V2_FRAXTAL_FACTORY,owner,curator,
   adaptersLength:oneWord(result[2]?.result)?.toString()??null,timelocks,sentinelChecks,
   sentinelListComplete:false,pendingActionsIndexed:false,updatedAt:new Date().toISOString()};
}
let cyFactoryWideFailUntil=0,cyFactoryFullCache=null;
const CY_V2_CREATE_TOPIC="0x341ce009267aa0d78cc12b34155e223904a51ed49d144beb6eb8be87813edb4e";
async function cyVaultDirectoryFallback(u){
 const floor=30000000; // factory code independently verified absent at this Fraxtal block
 const headResponse=(await rpc([{method:"eth_blockNumber",params:[]}]))[0];
 if(!headResponse?.result)throw Error("Fraxtal head unavailable");
 const head=Number(BigInt(headResponse.result));
 const cursorRaw=u.searchParams.get("cursor");
 if(cursorRaw&&!/^[0-9]{7,9}$/.test(cursorRaw))return {available:false,status:400,error:"Invalid scan cursor"};
 const high=cursorRaw?Number(cursorRaw):head;
 if(high>head||high<floor)return {available:false,status:400,error:"Scan cursor outside verified factory history"};
 const baseFilter={address:CY_V2_FRAXTAL_FACTORY,topics:[CY_V2_CREATE_TOPIC]};
 let logs=null,low=floor,full=false;
 if(!cursorRaw&&cyFactoryFullCache&&cyFactoryFullCache.head===head&&Date.now()<cyFactoryFullCache.expires){
  logs=cyFactoryFullCache.logs;full=true;
 }
 if(!logs&&!cursorRaw&&Date.now()>cyFactoryWideFailUntil){
  try{
   const req={jsonrpc:"2.0",id:1,method:"eth_getLogs",params:[{...baseFilter,fromBlock:"0x"+floor.toString(16),toBlock:"0x"+head.toString(16)}]};
   const res=await fetch(RPC_ENDPOINTS[0],{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify(req),signal:AbortSignal.timeout(4400)});
   if(!res.ok)throw Error("Wide factory log scan HTTP "+res.status);
   const answer=await res.json();
   if(answer.error||!Array.isArray(answer.result))throw Error(answer.error?.message||"Wide scan unsupported");
   logs=answer.result;full=true;cyFactoryFullCache={head,logs,expires:Date.now()+45000};
  }catch{cyFactoryWideFailUntil=Date.now()+900000;}
 }
 if(!logs){
  low=Math.max(floor,high-49999);
  const req=[];for(let start=low;start<=high;start+=2500){
   req.push({method:"eth_getLogs",params:[{...baseFilter,fromBlock:"0x"+start.toString(16),toBlock:"0x"+Math.min(high,start+2499).toString(16)}]});
  }
  const portions=await rpc(req);
  if(portions.some(x=>x.error||!Array.isArray(x.result)))throw Error("Incomplete factory-event RPC scan. No partial result is shown.");
  logs=portions.flatMap(x=>x.result);full=low===floor;
 }
 const seen=new Set(),vaults=[];
 for(const log of logs){
  if(log?.address?.toLowerCase()!==CY_V2_FRAXTAL_FACTORY.toLowerCase()||
   log?.topics?.[0]?.toLowerCase()!==CY_V2_CREATE_TOPIC||log?.topics?.length!==4)continue;
  const address=cyV2Addr("0x"+log.topics[3].slice(-40));
  if(!address||seen.has(address))continue;
  seen.add(address);
  vaults.push({address,owner:cyV2Addr("0x"+log.topics[1].slice(-40)),
    asset:cyV2Addr("0x"+log.topics[2].slice(-40)),name:null,creationBlock:Number(BigInt(log.blockNumber))});
 }
 vaults.sort((a,b)=>b.creationBlock-a.creationBlock);
 return {chainId:252,available:true,source:"Official Fraxtal VaultV2Factory CreateVaultV2 logs",
  factory:CY_V2_FRAXTAL_FACTORY,vaults,cursor:full?null:String(low-1),
  coverage:{fromBlock:low,toBlock:high,complete:full},
  factoryVerifiedOnchainIndividually:false,updatedAt:new Date().toISOString()};
}


const CY_V2_SNAPSHOT_URL="https://raw.githubusercontent.com/curveyield3/Smart-Contracts/09b029c2873566cd21e368a42f60e45d88d02006/CurveYield%20Markets/Marketplace%20Web%20UI/site/fraxtal-vault-factory-index.json";
async function cyVaultDirectoryApi(u){
 let snapshot;
 try{
  const response=await fetch(CY_V2_SNAPSHOT_URL,{cf:{cacheEverything:true,cacheTtl:86400},signal:AbortSignal.timeout(5000)});
  if(!response.ok)throw Error("Historical index unavailable");
  const d=await response.json();
  if(d.version!==1||d.chainId!==252||d.factory?.toLowerCase()!==CY_V2_FRAXTAL_FACTORY.toLowerCase()||
    d.scannedFromBlock!==30000000||!Number.isSafeInteger(d.scannedThroughBlock)||
    !Array.isArray(d.entries)||d.entries.length>1000)throw Error("Index integrity mismatch");
  snapshot=d;
 }catch(e){const fallback=await cyVaultDirectoryFallback(u);fallback.historicalSnapshotUnavailable=String(e.message||e);return fallback}
 const headResponse=(await rpc([{method:"eth_blockNumber",params:[]}]))[0];
 if(!headResponse?.result)throw Error("Fraxtal head unavailable");
 const head=Number(BigInt(headResponse.result)),floor=snapshot.scannedThroughBlock+1;
 const rawCursor=u.searchParams.get("cursor");
 if(rawCursor&&!/^[0-9]{7,9}$/.test(rawCursor))return {available:false,status:400,error:"Invalid cursor"};
 const hi=rawCursor?Number(rawCursor):head;
 if(hi>head||hi<floor)return {available:false,status:400,error:"Cursor outside unindexed tail"};
 const lo=Math.max(floor,hi-49999);
 const req=[];
 for(let n=lo;n<=hi;n+=2500)req.push({method:"eth_getLogs",params:[{
  address:CY_V2_FRAXTAL_FACTORY,topics:[CY_V2_CREATE_TOPIC],
  fromBlock:"0x"+n.toString(16),toBlock:"0x"+Math.min(hi,n+2499).toString(16)}]});
 let extra=[],tailVerified=true,error=null;
 if(req.length){try{const chunks=await rpc(req);if(chunks.some(x=>x.error||!Array.isArray(x.result)))throw Error("An on-chain event range was unavailable");extra=chunks.flatMap(x=>x.result)}catch(e){tailVerified=false;error=String(e.message||e)}}
 const entries=!rawCursor?snapshot.entries.filter(v=>cyV2Addr(v.address)).map(v=>({...v})):[],seen=new Set(entries.map(v=>v.address.toLowerCase()));
 for(const log of extra){
  if(log?.address?.toLowerCase()!==CY_V2_FRAXTAL_FACTORY.toLowerCase()||
    log?.topics?.[0]?.toLowerCase()!==CY_V2_CREATE_TOPIC||log?.topics?.length!==4)continue;
  const address=cyV2Addr("0x"+log.topics[3].slice(-40));
  if(!address||seen.has(address))continue;
  seen.add(address);entries.push({address,owner:cyV2Addr("0x"+log.topics[1].slice(-40)),
    asset:cyV2Addr("0x"+log.topics[2].slice(-40)),name:null,creationBlock:Number(BigInt(log.blockNumber))});
 }
 entries.sort((a,b)=>(b.creationBlock||0)-(a.creationBlock||0));
 const complete=tailVerified&&lo===floor&&!rawCursor;
 return {chainId:252,available:true,
  source:"Official Fraxtal Vault V2 factory event snapshot and on-chain update",
  factory:CY_V2_FRAXTAL_FACTORY,vaults:entries,
  cursor:tailVerified&&lo>floor?String(lo-1):null,
  coverage:{fromBlock:snapshot.scannedFromBlock,toBlock:tailVerified?hi:snapshot.scannedThroughBlock,
    complete,tailGapBlocks:tailVerified?Math.max(0,lo-floor):Math.max(0,head-snapshot.scannedThroughBlock)},
  snapshotThroughBlock:snapshot.scannedThroughBlock,
  factoryVerifiedOnchainIndividually:false,
  warning:error,updatedAt:new Date().toISOString()};
}

async function cyPortfolioActivity(wallet){
 const walletAddress=cyV2Addr(wallet);
 if(!walletAddress)return {error:"Valid wallet address required",status:400};
 const head=(await rpc([{method:"eth_blockNumber",params:[]}]))[0];
 if(!head?.result)throw Error("Fraxtal block head unavailable");
 const top=Number(BigInt(head.result)),start=Math.max(MORPHO_DEPLOY_BLOCK,top-23999);
 const mids=Object.values(MARKET_INFO).map(m=>m.id);
 const req=[];for(let from=start;from<=top;from+=2500){
  req.push({method:"eth_getLogs",params:[{address:MORPHO,fromBlock:"0x"+from.toString(16),
    toBlock:"0x"+Math.min(top,from+2499).toString(16),topics:[null,mids]}]});
 }
 const answers=await rpc(req);
 if(answers.some(x=>x.error||!Array.isArray(x.result)))throw Error("At least one RPC event range failed; cannot report activity as complete");
 const marketById=Object.fromEntries(Object.values(MARKET_INFO).map(x=>[x.id.toLowerCase(),x]));
 const entries=[];
 for(const part of answers)for(const log of part.result){
  const desc=MARKET_EVENTS[log.topics?.[0]?.toLowerCase()],market=marketById[log.topics?.[1]?.toLowerCase()];
  if(!desc||!market)continue;
  const onBehalfIndex=/^(Withdraw|Borrow)/.test(desc.kind)?2:3;
  const indexed=log.topics?.[onBehalfIndex];
  if(!indexed||"0x"+indexed.slice(-40).toLowerCase()!==walletAddress)continue;
  entries.push({kind:desc.kind,market:market.token,marketId:market.id,block:Number(BigInt(log.blockNumber)),
    txHash:log.transactionHash,logIndex:Number(BigInt(log.logIndex||"0x0"))});
 }
 entries.sort((a,b)=>b.block-a.block||b.logIndex-a.logIndex);
 return {chainId:252,wallet:walletAddress,fromBlock:start,toBlock:top,
   complete:start===MORPHO_DEPLOY_BLOCK,scope:"Three primary CurveYield Fraxtal markets; most recent 24,000 blocks",
   count:entries.length,activity:entries.slice(0,100),updatedAt:new Date().toISOString()};
}

export default{async scheduled(event,env,ctx){ctx.waitUntil(cyCatScheduled(event,env))},async fetch(request,env){const u=new URL(request.url),path=u.pathname.toLowerCase();
if(path==="/assets/vault-ui-v12.js"||path==="/assets/vault-ui-v11.css"){
 if(!["GET","HEAD"].includes(request.method))return new Response("Method not allowed",{status:405});
 return cyVaultUiAsset(path,request);
}
if(u.searchParams.get("chain")!=="ethereum"&&(path==="/vaults/create"||/^\/vaults\/0x[a-f0-9]{40}$/.test(path))){
 if(!["GET","HEAD"].includes(request.method))return new Response("Method not allowed",{status:405});
 return cyVaultExperienceHtml(request);
}
if(path==="/create"){
 if(!["GET","HEAD"].includes(request.method))return new Response("Method not allowed",{status:405});
 return cyVaultExperienceHtml(request,true);
}

 if(path==="/assets/marketplace-live.js"){if(!["GET","HEAD"].includes(request.method))return new Response("Method not allowed",{status:405});return cyMarketplaceLiveScript(request);}
 const isMarketplaceLive=(path==="/"||path==="/markets"||/^\/markets\/(wfrax|frxusd|sfrxusd|0x[a-f0-9]{64})(?:\/(?:overview|positions|risk|activity))?$/.test(path)||path==="/portfolio"||/^\/portfolio\/(?:positions|vaults|activity)$/.test(path)||(path==="/vaults"&&u.searchParams.get("legacy")!=="1"&&!u.searchParams.has("chain")));
 if(isMarketplaceLive){if(!["GET","HEAD"].includes(request.method))return new Response("Method not allowed",{status:405});return cyMarketplaceLiveHtml(request);}
if(path==="/curator-preview"||path==="/curator-preview/"||path==="/curator-preview/app.css"||path==="/curator-preview/app.js"){if(!["GET","HEAD"].includes(request.method))return new Response("Method not allowed",{status:405});return cyCuratorPreviewAsset(path.endsWith(".css")?"css":path.endsWith(".js")?"js":"html",request.method);}if(!['GET','HEAD'].includes(request.method))return responseJson({error:'Method not allowed'},405);
 if(path==='/api/opportunities'||path==='/api/opportunities/status'){try{const research=false;const sourceOnly=u.searchParams.get('source')?.toLowerCase()==='fraxlend'?'Fraxlend native registry and pair-level Ethereum RPC':u.searchParams.get('source')?.toLowerCase()==='stakedao'?'Stake DAO native locker registry':u.searchParams.get('source')?.toLowerCase()==='ipor'?'IPOR Fusion v2':u.searchParams.get('source')?.toLowerCase()==='fluid'?'Fluid official fTokens':u.searchParams.get('source')?.toLowerCase()==='curvelend'?'Curve official Ethereum lending':u.searchParams.get('source')?.toLowerCase()==='maple'?'Maple Finance official V2 pools':u.searchParams.get('source')?.toLowerCase()==='yearn'?'Yearn Kong REST V2/V3':u.searchParams.get('source')?.toLowerCase()==='morphoblue'?'Morpho Blue complete Ethereum market index':u.searchParams.get('source')?.toLowerCase()==='morphov1'?'Morpho Vault V1 bulk USD':u.searchParams.get('source')?.toLowerCase()==='morphov2'?'Morpho Vault V2 bulk USD':u.searchParams.get('source')?.toLowerCase()==='gearbox'?'Gearbox official Ethereum passive ERC4626 pools':u.searchParams.get('source')?.toLowerCase()==='silo'?'Silo V3 official Ethereum GraphQL markets':u.searchParams.get('source')?.toLowerCase()==='spark'?'Spark official Ethereum Savings V2 REST':u.searchParams.get('source')?.toLowerCase()==='sky'?'Sky official Ethereum Savings ERC4626 contracts':u.searchParams.get('source')?.toLowerCase()==='harvest'?'Harvest official Ethereum vault registry API':u.searchParams.get('source')?.toLowerCase()==='eulerearn'?'Euler Earn official Ethereum curated vaults':null;const persistent=sourceOnly?null:await cyCatRead(env?.MARKETS_CATALOG,u);const d=sourceOnly?await opCatalog(false,sourceOnly):persistent||await opMergeNativeCaches(await opCatalog(false));return responseJson(path.endsWith('/status')?{chainId:1,count:d.count,updatedAt:d.updatedAt,counts:d.counts,depositAssetIdentifiedCount:d.depositAssetIdentifiedCount,indexOnlyCount:d.indexOnlyCount,basketOnlyCount:d.basketOnlyCount,lpCompositionCount:d.lpCompositionCount,lpNativeCount:d.lpNativeCount,convexBoosterResolvedCount:d.convexBoosterResolvedCount,convexNativePricedCount:d.convexNativePricedCount,
 fraxlendRegisteredCount:d.fraxlendRegisteredCount,fraxlendDecodedCount:d.fraxlendDecodedCount,fraxlendPricedCount:d.fraxlendPricedCount,fraxlendCatalogCount:d.fraxlendCatalogCount,
 researchCount:research?d.researchCount:undefined,researchCounts:research?d.researchCounts:undefined,linkStats:d.persistentLinkStats||opLinkStats(research?d.researchOpportunities:d.opportunities),assetCounts:d.assetCounts,sourceSnapshots:d.sourceSnapshots,stale:!!d.stale,discoveryFilter:d.discoveryFilter,partial:d.partial,sourceStatus:d.sourceStatus,sourceFailures:d.sourceFailures,coverageWarnings:d.coverageWarnings,storage:d.storage}:opPage(d,u),200,90)}catch(e){return responseJson({available:false,error:String(e?.message||e)},503,15)}}
 if(path==='/api/vault-lending-markets'){try{return responseJson(await frxCached(),200,60)}catch(e){return responseJson({chainId:252,available:false,error:String(e.message||e)},503,2)}};
 if(path==='/api/ethereum-lending-markets'){
  try{
   const asset=String(u.searchParams.get("asset")||"").toLowerCase(),protocol=u.searchParams.get("protocol")||"all",
    page=Number(u.searchParams.get("page")||0);
   if(!opAddr(asset)||!Number.isInteger(page)||page<0||page>64)
    return responseJson({chainId:1,error:"Invalid asset or page"},400);
   if(protocol==="Liquity"||protocol==="Liquity V2 (legacy BOLD SP)")
    return responseJson(await cyEEssentialMarkets(asset,protocol,page),200,90);
   const doc=await cyCatRead(env?.MARKETS_CATALOG,u)||await opMergeNativeCaches(await opCatalog()),query=new URL(u.href);
   query.searchParams.set("asset",asset);query.searchParams.set("sort","tvl");
   query.searchParams.set("limit","100");query.searchParams.set("offset",String(page*100));
   const listing=opPage(doc,query);
   return responseJson({
    chainId:1,asset,page,opportunities:listing.opportunities,counts:doc.counts,
    pagination:{eulerPage:page,eulerHasNext:listing.hasMore,morphoNextCursor:null},
    sourceFailures:doc.sourceFailures,coverageWarnings:doc.coverageWarnings,
    partial:doc.partial,updatedAt:doc.updatedAt,
    factoryStatus:"Ethereum adapter deployment not verified; discovery only",
    rateNote:"API yields vary; USD TVL is reported by public sources"
   },200,90);
  }catch(e){return responseJson({chainId:1,available:false,error:String(e?.message||e)},503,15)}
 }
 if(path==='/api/vault-readiness'){try{const d=await cyVaultReadiness(u);return responseJson(d,d.status||200,d.status?0:20)}catch(e){return responseJson({error:String(e.message||e)},503)}}
 if(path==='/api/vault-directory'){try{const d=await cyVaultDirectoryApi(u);return responseJson(d,d.status||200,d.status?0:60)}catch(e){return responseJson({available:false,error:String(e.message||e)},503)}}
 if(path==='/api/portfolio-activity'){try{const d=await cyPortfolioActivity(u.searchParams.get('wallet'));return responseJson(d,d.status||200,d.status?0:20)}catch(e){return responseJson({available:false,error:String(e.message||e)},503)}}
 if(path==='/api/health')return responseJson({status:'ok',chainId:252,seedMarkets:3,supportedFactories:SUPPORTED_FACTORIES.length,morpho:MORPHO,vault:VAULT},200,30);
 if(path==='/api/markets'||/^\/api\/market\/(wfrax|frxusd|sfrxusd|0x[a-f0-9]{64})$/.test(path)){
  try{const all=await liveMarkets();if(path==='/api/markets')return responseJson(all,200,8);const slug=path.split('/').at(-1);return responseJson({chainId:252,block:all.block,market:all.markets[slug],networkOk:all.networkOk},200,8)}catch(e){return responseJson({networkOk:false,error:String(e.message||e),markets:{}},503)}
 }
 if(/^\/api\/activity\/(wfrax|frxusd|sfrxusd|0x[a-f0-9]{64})$/.test(path)){
  try{return responseJson(await marketHistory(path.split('/').at(-1)),200,20)}catch(e){return responseJson({available:false,error:String(e.message||e)},503)}
 }
 if(path==='/api/positions'){try{return responseJson(await walletPositions(u.searchParams.get('wallet')||'',u.searchParams.get('market')||''))}catch(e){return responseJson({error:String(e.message||e)},503)}}
 if(path==='/assets/sdfxs.svg')return new Response(SDFXS_AUTHENTIC,{headers:{'content-type':'image/svg+xml; charset=utf-8','cache-control':'public,max-age=86400','x-content-type-options':'nosniff'}});
 if(path==='/assets/cysdfxs-poster.webp')return new Response(Uint8Array.from(atob(CYSD_POSTER_B64),c=>c.charCodeAt(0)),{headers:{'content-type':'image/webp','cache-control':'public,max-age=86400','x-content-type-options':'nosniff'}});
 if(path==='/assets/curveyield-logo.webp')return new Response(Uint8Array.from(atob(CY_LOGO_B64),c=>c.charCodeAt(0)),{headers:{'content-type':'image/webp','cache-control':'public,max-age=86400','x-content-type-options':'nosniff'}});
 if(path==='/favicon.svg')return new Response(FAVICON,{headers:{'content-type':'image/svg+xml','cache-control':'public,max-age=86400'}});
 if(path==='/assets/app.css')return new Response(CSS+CY_CREATE_MARKET_STYLE_V10,{headers:{'content-type':'text/css; charset=utf-8','cache-control':'public,max-age=300'}});
 if(path==='/assets/opportunities.js')return new Response(OP_CLIENT,{headers:{'content-type':'text/javascript; charset=utf-8','cache-control':'public,max-age=300'}});
 if(path==='/assets/vaults.js')return new Response(VAULT_CLIENT,{headers:{'content-type':'text/javascript; charset=utf-8','cache-control':'public,max-age=300'}});
 if(path==='/assets/vaults.css')return new Response(VAULT_STYLE,{headers:{'content-type':'text/css; charset=utf-8','cache-control':'public,max-age=300'}});
 if(path==='/assets/app.js')return new Response(APP,{headers:{'content-type':'text/javascript; charset=utf-8','cache-control':'public,max-age=300'}});
 if(path==='/opportunities')return new Response(request.method==='HEAD'?null:OP_HTML,{headers:PAGE_HEADERS});
 if(path==='/robots.txt')return new Response('User-agent: *\nAllow: /\n',{headers:{'content-type':'text/plain'}});
 if(path==='/vaults'||path==='/vaults/create'||/^\/vaults\/0x[a-f0-9]{40}$/.test(path)){
  const html=u.searchParams.get('chain')==='ethereum'?VAULT_HTML
   .replace('CurveYield Markets · Fraxtal lending','CurveYield · Ethereum vaults')
   .replace('<span class="chain-dot"></span>Fraxtal','<span class="chain-dot"></span>Ethereum')
   .replace('Non-custodial · Fraxtal chain 252','Non-custodial · Ethereum chain 1'):VAULT_HTML;
  return new Response(request.method==='HEAD'?null:html,{headers:PAGE_HEADERS});
 }
 if(['/','/wfrax','/frxusd','/sfrxusd','/create','/index.html'].includes(path)||/^\/market\/0x[a-f0-9]{64}$/.test(path))return new Response(request.method==='HEAD'?null:HTML,{headers:PAGE_HEADERS});
 return new Response('Not found',{status:404,headers:{'content-type':'text/plain; charset=utf-8'}})
 }};
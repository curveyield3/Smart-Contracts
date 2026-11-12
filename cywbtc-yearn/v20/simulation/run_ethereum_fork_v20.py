#!/usr/bin/env python3
"""cyWBTC v20 mainnet-FORK-only deployment and functional simulation.

Requires Foundry's anvil, forge, and cast, and an Ethereum upstream RPC. This
runner NEVER sends transactions to its upstream RPC. All writes go to a locally
spawned Anvil instance after checking anvil_nodeInfo and eth_chainId.
"""
from __future__ import annotations
import argparse
import copy
import json
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "simulation-output"
WBTC = "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599"
FXUSD = "0x085780639cc2cacd35e474e71f4d000e2405d8f6"
FXMINT_POOL = "0xAB709e26Fa6B0A30c119D8c55B887DeD24952473"
YEARN_FACTORY = "0x310aC28ACF5E514abDbFF9Ab25e21f1bfe22bcAC"
UINT_MAX = (1 << 256) - 1

def hexint(x): return hex(int(x))
def word(x: int) -> str: return int(x).to_bytes(32, "big").hex()
def addrword(a: str) -> str: return word(int(a, 16))
def nonzero_address(s: str) -> bool: return isinstance(s,str) and bool(re.fullmatch(r"0x[a-fA-F0-9]{40}",s)) and int(s,16)!=0

def read_env_address(key, default=None):
    val = os.environ.get(key, default)
    if not nonzero_address(val): raise Blocked(f"Missing/invalid {key} Ethereum address")
    return val

def number_env(key, default):
    v = int(os.environ.get(key,str(default)),0)
    if v < 0: raise Blocked(f"{key} must be nonnegative")
    return v

class Blocked(RuntimeError): pass
class Failed(RuntimeError): pass

class Rpc:
    def __init__(self, uri):
        assert uri.startswith("http://127.0.0.1:") or uri.startswith("http://localhost:")
        self.uri = uri; self.request_id = 0
    def call(self, method, params=None):
        self.request_id += 1
        body = json.dumps({"jsonrpc":"2.0","method":method,"params":params or [],"id":self.request_id}).encode()
        req = urllib.request.Request(self.uri, data=body, headers={"Content-Type":"application/json"})
        with urllib.request.urlopen(req, timeout=120) as response:
            data = json.loads(response.read())
        if data.get("error") is not None: raise Failed(f"{method}: {data['error']}")
        return data.get("result")

class Sim:
    def __init__(self,args):
        self.args=args
        self.rpc=None;self.anvil=None;self.sig_cache={}
        self.context={"WBTC":WBTC,"FXUSD":FXUSD,"FXMINT_POOL":FXMINT_POOL}
        self.report={"schema":"curveyield-mainnet-fork-simulation-v20","version":"v20",
            "chainId":1,"mode":"ISOLATED_LOCAL_ANVIL_MAINNET_FORK_ONLY",
            "sourceArchive":"cyWBTC_IPOR_Source_v18_Simulation_WIP.zip",
            "overall":"NOT_RUN","entries":[],"blockers":[],"receipts":[],
            "limitations":["This test suite cannot establish security of all smart-contract paths.",
                "No live-mainnet broadcasts are permitted.",
                "The v17 archive lacks a finished IPOR vault deployment/configuration script.",
                "Tests need genuine mainnet state, role holders, liquidity and working protocol endpoints."]}
    def save(self):
        OUT.mkdir(exist_ok=True)
        f=OUT/"simulation-report-v20.json"
        f.write_text(json.dumps(self.report,indent=2,sort_keys=True)+"\n")
        lines=["# cyWBTC Ethereum fork simulation — v20", "",
               f"**Overall:** {self.report['overall']}",
               "**Network:** isolated local Anvil Ethereum mainnet fork (chain ID 1)",
               "**Evidence produced on an executed run:** local-fork RPC state reads, transaction receipts and before/after snapshots", "",
               "| Step | Status | Block / gas |", "|---|---|---|"]
        for x in self.report['entries']:
            result=x.get('result')
            gas=str(result.get('gasUsed')) if isinstance(result,dict) and result.get('gasUsed') is not None else '—'
            block=str(result.get('blockNumber')) if isinstance(result,dict) and result.get('blockNumber') is not None else '—'
            lines.append(f"| `{x['step']}` | **{x['status']}** | {block} / {gas} |")
        lines.extend(["", "## Blockers and failures",""])
        for x in self.report['entries']:
            if x['status']!='PASS':
                lines.append(f"- **{x['status']}** `{x['step']}`: {str(x.get('error',x.get('reason','unspecified')))[:900]}")
        lines.extend(["", "## Function-use state snapshots",""])
        for x in self.report['entries']:
            if 'before' in x or 'after' in x:
                lines.extend([f"### {x['step']} — {x['status']}","",
                    "Before: `"+json.dumps(x.get('before',{}),sort_keys=True)+"`", "",
                    "After: `"+json.dumps(x.get('after',{}),sort_keys=True)+"`", ""])
        lines.extend(["", "## Latest actual local-fork state", "",
            "```json",json.dumps(self.report.get('finalState',{}),indent=2),"```","",
            "## Important limits","", "This report proves only the observed outcomes on the recorded fork state. "+
            "It is not a contract security audit or mainnet deployment receipt."])
        (OUT/"simulation-report-v20.md").write_text("\n".join(lines)+"\n")
        return f
    def record(self, name, status, **data):
        entry={"step":name,"status":status,**data}
        self.report["entries"].append(entry)
        print(f"[{status}] {name}",flush=True)
        self.save()
        return entry
    def block(self,name,reason):
        self.report["blockers"].append({"step":name,"reason":str(reason)})
        return self.record(name,"BLOCKED",reason=str(reason))
    def tool(self,args,env=None,timeout=600):
        cp=subprocess.run(args,cwd=ROOT,env=env,capture_output=True,text=True,timeout=timeout)
        if cp.returncode:
            # Never include environment variables or command-line secrets in logs.
            msg=cp.stderr[-1800:]
            for value in (os.environ.get("ETHEREUM_FORK_RPC_URL"),os.environ.get("SIM_DEPLOYER_PRIVATE_KEY")):
                if value:msg=msg.replace(value,"[REDACTED]")
            raise Failed(f"{' '.join([str(x) for x in args if not str(x).startswith('0x')][:4])} failed: {msg}")
        return cp.stdout.strip()
    def sig(self,s):
        if s not in self.sig_cache:
            v=self.tool(["cast","sig",s],timeout=20).strip()
            if not re.fullmatch(r"0x[a-f0-9A-F]{8}",v): raise Failed(f"Invalid selector for {s}: {v}")
            self.sig_cache[s]=v
        return self.sig_cache[s]
    def calldata(self,fn,*args):
        v=self.tool(["cast","calldata",fn,*[str(x) for x in args]],timeout=30).strip()
        if not v.startswith("0x"): raise Failed("cast calldata failed")
        return v
    def eth_call(self,to,fn,*args,from_=None):
        call={"to":to,"data":self.calldata(fn,*args)}
        if from_:call["from"]=from_
        return self.rpc.call("eth_call",[call,"latest"])
    def read_u(self,to,fn,*args):
        return int(self.eth_call(to,fn,*args),16)
    def read_address(self,to,fn,*args):
        d=self.eth_call(to,fn,*args)
        return "0x"+d[-40:]
    def read_bool(self,to,fn,*args):return bool(self.read_u(to,fn,*args))
    def read_array_address(self,to,fn,*args):
        d=self.eth_call(to,fn,*args)[2:]
        if len(d)<128:raise Failed(f"Short array response {fn}")
        off=int(d[:64],16)*2; n=int(d[off:off+64],16)
        if n>100:raise Failed("Suspiciously long array")
        return ["0x"+d[off+64+i*64:off+128+i*64][-40:] for i in range(n)]
    def impersonate(self,address):
        if not nonzero_address(address): raise Blocked("Invalid impersonation address")
        self.rpc.call("anvil_impersonateAccount",[address])
        self.rpc.call("anvil_setBalance",[address,hex(10**21)])
    def transact(self,who,to,data,gas=11_000_000):
        self.impersonate(who)
        oldblock=int(self.rpc.call("eth_blockNumber"),16)
        h=self.rpc.call("eth_sendTransaction",[{"from":who,"to":to,"data":data,"gas":hex(gas),"value":"0x0"}])
        receipt=None
        for _ in range(120):
            receipt=self.rpc.call("eth_getTransactionReceipt",[h])
            if receipt:break
            time.sleep(.15)
        if not receipt:raise Failed(f"Transaction not mined: {h}")
        item={"hash":h,"status":int(receipt["status"],16),"gasUsed":int(receipt["gasUsed"],16),
              "effectiveGasPrice":int(receipt.get("effectiveGasPrice","0x0"),16),
              "blockNumber":int(receipt["blockNumber"],16),"from":who,"to":to,
              "logsCount":len(receipt.get("logs",[]))}
        self.report["receipts"].append(item)
        if item["status"]!=1:raise Failed(f"Transaction reverted (receipt status=0), hash={h}, block={oldblock+1}")
        return item
    def read_price(self,to,asset):
        d=self.eth_call(to,"getAssetPrice(address)",asset)[2:]
        if len(d)<128:raise Failed("Oracle returned fewer than two words")
        price=int(d[:64],16);decimals=int(d[64:128],16)
        if price<=0 or decimals>36:raise Failed(f"Invalid oracle price/decimals for {asset}")
        return {"price":price,"decimals":decimals}
    def query(self,to,fn,*args):
        try:return self.read_u(to,fn,*args)
        except Exception as e:return {"readError":str(e)[:500]}
    def snapshot(self,tag):
        c=self.context; v=c.get("YEARN_VAULT");m=c.get("YEARN_MASTER");ip=c.get("IPOR_VAULT");actor=c.get("DEPOSITOR")
        s={"tag":tag,"blockNumber":int(self.rpc.call("eth_blockNumber"),16)}
        if actor and nonzero_address(actor):
            for nm in ("WBTC","FXUSD","YEARN_VAULT","IPOR_VAULT"):
                tok=c.get(nm)
                if tok:s[f"depositor_{nm}_balance"]=self.query(tok,"balanceOf(address)",actor)
        if v:
            for k,f in [("yearn_totalAssets","totalAssets()"),("yearn_totalSupply","totalSupply()"),
                        ("yearn_totalIdle","totalIdle()"),("yearn_totalDebt","totalDebt()")]:
                s[k]=self.query(v,f)
            for who in ([v,m,ip]):
                if who:s[f"fxusd_balance_{who.lower()}"]=self.query(c["FXUSD"],"balanceOf(address)",who)
            if m:
                s["yearn_master_shares_owned_by_vault"]=self.query(m,"balanceOf(address)",v)
                s["master_totalAssets"]=self.query(m,"totalAssets()")
                s["master_reserved_fxusd"]=self.query(m,"totalReservedFxUSD()")
                if c.get("FXN") and nonzero_address(c.get("FXN")):
                    s["master_FXN_rewards"]=self.query(c["FXN"],"balanceOf(address)",m)
                    if c.get("FXN_REWARD_CHILD"):
                        s["reward_child_FXN"]=self.query(c["FXN"],"balanceOf(address)",c["FXN_REWARD_CHILD"])
                if actor:s["yearn_maxWithdraw_for_depositor"]=self.query(v,"maxWithdraw(address)",actor)
                for ch in ["CHILD_32","CHILD_37"]:
                    ca=c.get(ch)
                    if ca:
                        s[f"{ch}_shares_owned_by_master"]=self.query(ca,"balanceOf(address)",m)
                        s[f"{ch}_totalAssets"]=self.query(ca,"totalAssets()")
        if ip:
            s["ipor_totalAssets"]=self.query(ip,"totalAssets()")
            s["ipor_totalSupply"]=self.query(ip,"totalSupply()")
            s["ipor_idle_WBTC"]=self.query(c["WBTC"],"balanceOf(address)",ip)
            s["ipor_idle_fxUSD"]=self.query(c["FXUSD"],"balanceOf(address)",ip)
            if v:s["ipor_Yearn_shares"]=self.query(v,"balanceOf(address)",ip)
            for market in (7,49,100001):
                s[f"ipor_totalAssetsInMarket_{market}"]=self.query(ip,"totalAssetsInMarket(uint256)",market)
            if actor:
                s["ipor_maxWithdraw_for_depositor"]=self.query(ip,"maxWithdraw(address)",actor)
                s["ipor_maxRedeem_for_depositor"]=self.query(ip,"maxRedeem(address)",actor)
        mg=c.get("LTV_MANAGER");adapter=c.get("ACCOUNTING_ADAPTER")
        if mg:
            s["targetLtvWad"]=self.query(mg,"targetLtvWad()")
            s["withdrawSlippageBps"]=self.query(mg,"withdrawSlippageBps()")
        if adapter:
            pid=self.query(adapter,"positionId()")
            s["positionId"]=pid
            if isinstance(pid,int) and pid>0:
                try:
                    d=self.eth_call(c["FXMINT_POOL"],"getPosition(uint256)",pid)[2:]
                    col=int(d[:64],16);debt=int(d[64:128],16)
                    s.update({"rawCollateral":col,"rawDebtFxUSD":debt})
                    try:
                        oracle=self.read_address(c["FXMINT_POOL"],"priceOracle()")
                        px=self.read_u(oracle,"getExchangePrice()")
                        s["collateralExchangePriceWad"]=px
                        if col and px:s["ltvWad"]=(debt*10**36)//(col*px)
                    except Exception as e:s["ltvReadError"]=str(e)[:300]
                except Exception as e:s["positionReadError"]=str(e)[:300]
        return s
    def check(self,name,check_fn,description):
        before=self.snapshot(f"before:{name}")
        try:
            result=check_fn()
            after=self.snapshot(f"after:{name}")
            return self.record(name,"PASS",description=description,before=before,after=after,result=result)
        except Blocked as e:
            return self.block(name,e)
        except Exception as e:
            after=self.snapshot(f"after-error:{name}")
            return self.record(name,"FAIL",description=description,before=before,after=after,error=str(e))
    def tx(self,name,who,to,signature,*args,condition=None):
        def execute():
            data=self.calldata(signature,*args)
            rc=self.transact(who,to,data)
            if condition:condition()
            return rc
        return self.check(name,execute,signature)
    def expect_revert(self,name,who,to,signature,*args):
        def attempt():
            self.impersonate(who)
            try:self.eth_call(to,signature,*args,from_=who)
            except Failed as e:return {"expectedRevert":str(e)[:500]}
            raise Failed("Unexpected success: negative authorization/bounds case")
        return self.check(name,attempt,"read-only eth_call; expected revert; no transaction submitted")
    def assert_match(self,actual,expected,label):
        if actual.lower()!=expected.lower():raise Failed(f"{label}: expected {expected}, got {actual}")
    def yearn_suite(self):
        c=self.context
        def preflight():
            v=c["YEARN_VAULT"];m=c["YEARN_MASTER"]
            self.assert_match(self.read_address(v,"asset()"),c["FXUSD"],"Yearn asset")
            self.assert_match(self.read_address(m,"YEARN_VAULT()"),v,"master bound vault")
            if self.read_u(m,"childCount()")!=2:raise Failed("Expected exactly two weighted children")
            if self.read_u(m,"allocationBps(address)",c["CHILD_32"])!=5500:raise Failed("Pool 32 allocation != 55%")
            if self.read_u(m,"allocationBps(address)",c["CHILD_37"])!=4500:raise Failed("Pool 37 allocation != 45%")
            if self.read_u(m,"fxnRewardAllocationBps()")!=800:raise Failed("FXN diversion != 8%")
            if not self.read_bool(v,"auto_allocate()"):raise Failed("Yearn auto_allocate disabled")
            if not self.read_bool(v,"use_default_queue()"):raise Failed("Yearn default queue disabled")
            queue=self.read_array_address(v,"get_default_queue()")
            if len(queue)!=1:raise Failed("Yearn default queue must have one strategy")
            self.assert_match(queue[0],m,"default queue master")
            accountant=self.read_address(v,"accountant()")
            if not nonzero_address(accountant):raise Failed("Yearn accountant is missing")
            fee_raw=self.eth_call(accountant,"defaultConfig()")[2:]
            if len(fee_raw)<128:raise Failed("Accountant did not report management/performance config")
            mgmt_fee=int(fee_raw[:64],16);performance_fee=int(fee_raw[64:128],16)
            expected_mgmt=number_env("VAULT_MANAGEMENT_FEE_BPS",0)
            expected_perf=number_env("VAULT_PERFORMANCE_FEE_BPS",1000)
            if mgmt_fee!=expected_mgmt or performance_fee!=expected_perf:
                raise Failed(f"Yearn fee mismatch {mgmt_fee}/{performance_fee} != {expected_mgmt}/{expected_perf}")
            return {"queue":queue,"allocations":[5500,4500],"fxnDiversionBps":800,
                    "accountant":accountant,"managementFeeBps":mgmt_fee,"performanceFeeBps":performance_fee}
        if self.check("yearn.configuration.readback",preflight,
                "Verify actual Yearn source-bound vault, master, queue and allocation state")["status"]!="PASS":
            self.block("yearn.functional_deposit_and_redemption","Initial Yearn configuration readback failed")
            return
        actor=c["DEPOSITOR"];v=c["YEARN_VAULT"];fx=c["FXUSD"]
        amt=number_env("SIM_YEARN_DEPOSIT_RAW",100*10**18)
        funder=os.environ.get("SIM_FXUSD_FUNDER")
        def fund():
            if amt<=0:raise Blocked("SIM_YEARN_DEPOSIT_RAW must be >0")
            if self.read_u(fx,"balanceOf(address)",actor)>=amt:return {"existingFunding":True}
            if not nonzero_address(funder):raise Blocked("SIM_FXUSD_FUNDER required to fund real fxUSD for local-fork simulation")
            if self.read_u(fx,"balanceOf(address)",funder)<amt:raise Blocked("Chosen mainnet fxUSD funder has insufficient fxUSD at fork height")
            return self.transact(funder,fx,self.calldata("transfer(address,uint256)",actor,amt))
        funded=self.check("yearn.fund_depositor_on_fork",fund,"Fund with an impersonated actual token holder on local fork only")
        if funded["status"]!="PASS":
            self.block("yearn.functional_deposit_and_redemption","Dependent fork fxUSD funding unavailable")
            return
        approved=self.tx("yearn.approve",actor,fx,"approve(address,uint256)",v,amt)
        if approved["status"]!="PASS":
            self.block("yearn.functional_deposit_and_redemption","Yearn token approval failed")
            return
        pre_shares=self.query(v,"balanceOf(address)",actor)
        before32=self.query(c["CHILD_32"],"balanceOf(address)",c["YEARN_MASTER"])
        before37=self.query(c["CHILD_37"],"balanceOf(address)",c["YEARN_MASTER"])
        def verify_deposit():
            now=self.read_u(v,"balanceOf(address)",actor)
            if not isinstance(pre_shares,int) or now<=pre_shares:raise Failed("No new Yearn shares minted")
            after32=self.read_u(c["CHILD_32"],"balanceOf(address)",c["YEARN_MASTER"])
            after37=self.read_u(c["CHILD_37"],"balanceOf(address)",c["YEARN_MASTER"])
            if not isinstance(before32,int) or after32<=before32:raise Failed("55% child did not receive new shares")
            if not isinstance(before37,int) or after37<=before37:raise Failed("45% child did not receive new shares")
        deposited=self.tx("yearn.deposit.auto_allocated",actor,v,"deposit(uint256,address)",amt,actor,condition=verify_deposit)
        if deposited["status"]!="PASS":
            self.block("yearn.redeem.25bps_loss_limit","Dependent Yearn deposit failed")
            return
        shares=self.query(v,"balanceOf(address)",actor)
        if isinstance(shares,int) and shares>0:
            part=max(1,shares//10)
            # Native Yearn Vault V3.1 5-argument accepted-loss exit.
            self.tx("yearn.redeem.25bps_loss_limit",actor,v,
                    "redeem(uint256,address,address,uint256,address[])",part,actor,actor,25,"[]")
        else:self.block("yearn.redeem.25bps_loss_limit","Deposit did not produce redeemable shares")
    def yearn_ops_suite(self):
        c=self.context
        v=c["YEARN_VAULT"]
        keeper=os.environ.get("HARVEST_KEEPER")
        if nonzero_address(keeper):
            harvest=self.tx("yearn.harvest_active",keeper,c["YEARN_MASTER"],"harvestActive()")
            role_manager=os.environ.get("VAULT_OWNER")
            if harvest["status"]=="PASS" and nonzero_address(role_manager):
                self.tx("yearn.process_report.master",role_manager,v,"process_report(address)",c["YEARN_MASTER"])
            else:self.block("yearn.process_report.master","Harvest failed or VAULT_OWNER role-bearing account unavailable")
            self.tx("yearn.reward_engine_harvest",keeper,c["YEARN_MASTER"],
                    "harvestFXNRewardChild(address[],uint256[],uint256)","[]","[]",0)
        else:
            self.block("yearn.harvest_active","HARVEST_KEEPER address absent")
            self.block("yearn.process_report.master","HARVEST_KEEPER address absent")
            self.block("yearn.reward_engine_harvest","HARVEST_KEEPER address absent")
        # Management exercises precise mutation + readback + rollback on fork only.
        m=c["YEARN_MASTER"]
        try:manager=self.read_address(m,"management()")
        except Exception as e:
            self.block("yearn.management_paths",f"Cannot establish live management address: {e}");return
        self.expect_revert("yearn.reject_bad_allocation",manager,m,"setStrategyAllocations(uint16[])","[9500,9500]")
        weights_before=[self.query(m,"allocationBps(address)",c["CHILD_32"]),self.query(m,"allocationBps(address)",c["CHILD_37"])]
        self.tx("yearn.configure_allocation_60_40",manager,m,"setStrategyAllocations(uint16[])","[6000,4000]")
        self.tx("yearn.restore_allocation",manager,m,"setStrategyAllocations(uint16[])",f"[{weights_before[0]},{weights_before[1]}]")
        self.expect_revert("yearn.reject_reward_allocation_gt20pct",manager,m,"setFXNRewardAllocationBps(uint16)",2001)
        old=self.query(m,"fxnRewardAllocationBps()")
        self.tx("yearn.fx_n_diversion_max20pct",manager,m,"setFXNRewardAllocationBps(uint16)",2000)
        if isinstance(old,int):self.tx("yearn.restore_fx_n_diversion",manager,m,"setFXNRewardAllocationBps(uint16)",old)
    def cooldown_suite(self):
        """Real two-stage fxBASE cooldown plus Yearn-share escrow and settlement.

        Run last: time traveling past cooldown must not invalidate oracle tests.
        """
        c=self.context
        for key in ("YEARN_VAULT","YEARN_MASTER","CHILD_37","DEPOSITOR"):
            if not nonzero_address(c.get(key)):
                self.block("yearn.cooldown_flow",f"Missing {key}")
                return
        v=c["YEARN_VAULT"];m=c["YEARN_MASTER"];ch=c["CHILD_37"];actor=c["DEPOSITOR"]
        try:
            user_shares=self.read_u(v,"balanceOf(address)",actor)
            min_shares=self.read_u(m,"minCooldownShares()")
            avail=self.read_u(m,"availableCooldownAssets()")
            share_count=min(user_shares//5,user_shares)
            if share_count<min_shares:share_count=min_shares
            if user_shares<share_count:
                raise Blocked(f"Need at least {min_shares} user Yearn shares for cooldown case")
            # Reduce requested shares until the position's actual cooldown
            # liquidity can cover the request, never guessing an arbitrary cap.
            while share_count>=min_shares:
                expected=self.read_u(v,"previewRedeem(uint256)",share_count)
                if 0<expected<=avail:break
                share_count//=2
            if share_count<min_shares:
                raise Blocked(f"Pool37 cooldown liquidity {avail} cannot cover minimum {min_shares} shares")
        except Blocked as e:
            self.block("yearn.cooldown_flow",e);return
        except Exception as e:
            self.record("yearn.cooldown_flow","FAIL",error=str(e));return
        if self.tx("yearn.cooldown.share_approval",actor,v,"approve(address,uint256)",m,share_count)["status"]!="PASS":
            self.block("yearn.cooldown_flow","Share approval failed")
            return
        claim0=self.query(ch,"pendingUserCooldownRequestId()")
        if isinstance(claim0,int) and claim0!=0:
            self.block("yearn.cooldown_flow",f"Pool37 already has pending request id {claim0}")
            return
        if self.tx("yearn.cooldown.request",actor,m,"requestCooldownWithdrawal(uint256,uint256)",share_count,0)["status"]!="PASS":
            self.block("yearn.cooldown_flow","Cooldown request reverted")
            return
        request_id=self.query(ch,"pendingUserCooldownRequestId()")
        if not isinstance(request_id,int) or request_id==0:
            self.record("yearn.cooldown.read_request_id","FAIL",error="No registered cooldown request")
            return
        try:
            raw=self.eth_call(ch,"cooldownClaims(uint256)",request_id)[2:]
            if len(raw)<320:raise Failed("Invalid cooldown claim readback")
            owner="0x"+raw[24:64]
            if owner.lower()!=actor.lower():raise Failed("Cooldown claim belongs to incorrect user")
            unlock=int(raw[128:192],16)
            if unlock<=0:raise Failed("Missing cooldown unlock timestamp")
            now=int(self.rpc.call("eth_getBlockByNumber",["latest",False])["timestamp"],16)
            if unlock>=now:
                self.rpc.call("evm_increaseTime",[unlock-now+1])
                self.rpc.call("evm_mine",[])
            self.record("yearn.cooldown.wait_to_unlock","PASS",requestId=request_id,
                        unlockAt=unlock,postForkTimestamp=int(self.rpc.call("eth_getBlockByNumber",["latest",False])["timestamp"],16))
        except Exception as e:
            self.record("yearn.cooldown.wait_to_unlock","FAIL",error=str(e));return
        if self.tx("yearn.cooldown.settle",actor,m,"settleCooldownWithdrawal(uint256)",request_id)["status"]!="PASS":
            self.block("yearn.cooldown.claim","Settlement failed")
            return
        before=self.query(FXUSD,"balanceOf(address)",actor)
        def paid():
            after=self.read_u(FXUSD,"balanceOf(address)",actor)
            if not isinstance(before,int) or after<=before:
                raise Failed("Cooldown claim did not pay fxUSD to user")
        self.tx("yearn.cooldown.claim",actor,m,"claimCooldownWithdrawal(uint256,uint256,uint16)",
                request_id,0,25,condition=paid)

    def execute_actions(self,actor,vault,items):
        # ABI layout for execute((address,bytes)[]) and its dynamic tuple[] argument.
        # Keccak selector is supplied by canonical Foundry cast sig, never SHA3-256.
        elements=[]
        for address,calldata in items:
            if not nonzero_address(address):raise Blocked("Missing actual fuse address")
            raw=bytes.fromhex(calldata.removeprefix("0x"))
            padded=raw+b"\x00"*((32-len(raw)%32)%32)
            tup=bytes.fromhex(addrword(address)+word(64)+word(len(raw)))+padded
            elements.append(tup)
        offsets=[];start=32*len(elements)
        for elem in elements:
            offsets.append(bytes.fromhex(word(start)));start+=len(elem)
        encoded=bytes.fromhex(word(32)+word(len(elements)))+b"".join(offsets)+b"".join(elements)
        data=self.sig("execute((address,bytes)[])")+encoded.hex()
        return self.transact(actor,vault,data)
    def ipor_suite(self):
        c=self.context
        needed={"IPOR_VAULT":"SIM_IPOR_VAULT","LTV_MANAGER":"SIM_LTV_MANAGER",
                "COLLATERAL_FUSE":"SIM_FXMINT_COLLATERAL_FUSE",
                "ACCOUNTING_ADAPTER":"SIM_FXMINT_ACCOUNTING_ADAPTER",
                "ALPHA":"SIM_IPOR_ALPHA","MANAGER_OWNER":"SIM_LTV_MANAGER_OWNER"}
        missing=[v for k,v in needed.items() if not nonzero_address(c.get(k))]
        if missing:raise Blocked("Missing deployed IPOR stack or authorized actor addresses: "+", ".join(missing))
        v=c["IPOR_VAULT"];mg=c["LTV_MANAGER"];alpha=c["ALPHA"];depositor=c["DEPOSITOR"]
        def preflight():
            self.assert_match(self.read_address(v,"asset()"),c["WBTC"],"IPOR asset")
            self.assert_match(self.read_address(mg,"VAULT()"),v,"LTV manager VAULT")
            self.assert_match(self.read_address(mg,"YEARN_VAULT()"),c["YEARN_VAULT"],"LTV manager Yearn")
            if self.read_u(mg,"MARKET_ID()")!=49:raise Failed("Manager market ID !=49")
            if self.read_u(c["COLLATERAL_FUSE"],"MARKET_ID()")!=49:raise Failed("Collateral market ID !=49")
            if self.read_u(c["ACCOUNTING_ADAPTER"],"MARKET_ID()")!=49:raise Failed("Accounting adapter market ID !=49")
            # A valid fxUSD price is necessary for Yearn shares market accounting.
            price_addr=os.environ.get("SIM_PRICE_MIDDLEWARE")
            if not nonzero_address(price_addr):raise Blocked("SIM_PRICE_MIDDLEWARE required for actual fxUSD pricing readback")
            source=self.read_price(price_addr,FXUSD)
            withdraw_fuses=self.read_array_address(v,"getInstantWithdrawalFuses()")
            if len(withdraw_fuses)!=1 or withdraw_fuses[0].lower()!=mg.lower():
                raise Failed("Instant-withdraw fuse list does NOT contain exactly the LTV manager")
            return {"priceMiddleware":price_addr,"fxusdOracle":source,"instantFuses":withdraw_fuses,"marketId":49}
        checked=self.check("ipor.configuration.price_and_fuses",preflight,"Check live IPOR vault, fxMINT, Yearn and middleware linkage")
        if checked["status"]!="PASS":
            raise Blocked("IPOR configuration preflight failed: further write scenarios blocked")
        amt=number_env("SIM_WBTC_DEPOSIT_RAW",100000) # 0.001 WBTC
        funder=os.environ.get("SIM_WBTC_FUNDER")
        def fund():
            if amt<=0:raise Blocked("SIM_WBTC_DEPOSIT_RAW must be >0")
            if self.read_u(WBTC,"balanceOf(address)",depositor)>=amt:return {"existingFunding":True}
            if not nonzero_address(funder):raise Blocked("SIM_WBTC_FUNDER required for real WBTC fork funding")
            if self.read_u(WBTC,"balanceOf(address)",funder)<amt:raise Blocked("Source has insufficient WBTC")
            return self.transact(funder,WBTC,self.calldata("transfer(address,uint256)",depositor,amt))
        if self.check("ipor.fund_depositor_on_fork",fund,"Transfer real fork-state WBTC from impersonated token holder")["status"]!="PASS":
            raise Blocked("WBTC funding failed: further IPOR write scenarios blocked")
        if self.tx("ipor.approve_WBTC",depositor,WBTC,"approve(address,uint256)",v,amt)["status"]!="PASS":
            raise Blocked("WBTC approval failed: further IPOR write scenarios blocked")
        old_shares=self.query(v,"balanceOf(address)",depositor)
        def minted():
            after=self.read_u(v,"balanceOf(address)",depositor)
            if not isinstance(old_shares,int) or after<=old_shares:raise Failed("IPOR deposit did not mint shares")
        if self.tx("ipor.deposit_WBTC",depositor,v,"deposit(uint256,address)",amt,depositor,condition=minted)["status"]!="PASS":
            raise Blocked("IPOR deposit failed: further IPOR write scenarios blocked")
        adapter=c["ACCOUNTING_ADAPTER"]
        pid=self.query(adapter,"positionId()")
        if pid==0:
            free_wbtc=self.read_u(WBTC,"balanceOf(address)",v)
            if free_wbtc==0:raise Blocked("IPOR has no idle WBTC available for fxMINT after deposit fee")
            self.check("ipor.open_fxmint_and_register_atomically",
              lambda:self.execute_actions(alpha,v,[(c["COLLATERAL_FUSE"],self.calldata("enterNewPosition(uint256)",free_wbtc)),
                 (adapter,self.calldata("enterRegisterLatestPosition()"))]),
              "Open genuine fxMINT NFT and register ID in one IPOR execute batch")
        elif isinstance(pid,int) and pid>0:
            self.record("ipor.open_fxmint_and_register_atomically","BLOCKED",
                        reason="Vault already has registered position; new-position path cannot be re-run in this state",positionId=pid)
        else:self.block("ipor.open_fxmint_and_register_atomically","Adapter positionId unavailable")
        newpid=self.query(adapter,"positionId()")
        if not isinstance(newpid,int) or newpid==0:
            raise Blocked("fxMINT position registration failed: dependent leverage/exit scenarios blocked")
        if self.read_address(c["FXMINT_POOL"],"ownerOf(uint256)",newpid).lower()!=v.lower():
            raise Blocked("fxMINT position NFT not owned by IPOR vault")
        self.expect_revert("ipor.reject_direct_manager_call",depositor,mg,"rebalanceUp(uint256)",0)
        before_up=self.snapshot("before-ipor.rebalance_up")
        def up():
            receipt=self.execute_actions(alpha,v,[(mg,self.calldata("rebalanceUp(uint256)",0))])
            after=self.snapshot("after-ipor.rebalance_up")
            if not (isinstance(before_up.get("rawDebtFxUSD"),int) and isinstance(after.get("rawDebtFxUSD"),int)
                    and after["rawDebtFxUSD"]>before_up["rawDebtFxUSD"]):
                raise Failed("Wind-up did not increase live fxMINT debt")
            if not (isinstance(before_up.get("ipor_Yearn_shares"),int) and isinstance(after.get("ipor_Yearn_shares"),int)
                    and after["ipor_Yearn_shares"]>before_up["ipor_Yearn_shares"]):
                raise Failed("Wind-up did not invest new fxUSD into Yearn shares")
            return receipt
        if self.check("ipor.rebalance_up",up,"Borrow fxUSD and deposit Yearn via registered execution fuses")["status"]!="PASS":
            raise Blocked("Rebalance-up failed; cannot correctly evaluate dependent down/withdraw paths")
        original=self.query(mg,"targetLtvWad()")
        if not isinstance(original,int) or original<=2*10**16:raise Blocked("Invalid manager target LTV for down-rebalance scenario")
        reduced=original-2*10**16
        self.tx("ipor.set_lower_target_on_fork",c["MANAGER_OWNER"],mg,"setTargetLtvWad(uint256)",reduced)
        before_down=self.snapshot("before-ipor.rebalance_down")
        def down():
            receipt=self.execute_actions(alpha,v,[(mg,self.calldata("rebalanceDown()"))])
            after=self.snapshot("after-ipor.rebalance_down")
            if not (isinstance(before_down.get("rawDebtFxUSD"),int) and isinstance(after.get("rawDebtFxUSD"),int)
                    and after["rawDebtFxUSD"]<before_down["rawDebtFxUSD"]):
                raise Failed("Down-rebalance did not reduce fxMINT debt")
            return receipt
        self.check("ipor.rebalance_down",down,"Redeem needed Yearn fxUSD and reduce fxMINT debt")
        self.tx("ipor.restore_target",c["MANAGER_OWNER"],mg,"setTargetLtvWad(uint256)",original)
        self.expect_revert("ipor.reject_invalid_slippage",c["MANAGER_OWNER"],mg,"setWithdrawSlippageBps(uint256)",56)
        old_s=self.query(mg,"withdrawSlippageBps()")
        self.tx("ipor.set_slippage_limit_55bps",c["MANAGER_OWNER"],mg,"setWithdrawSlippageBps(uint256)",55)
        if isinstance(old_s,int):self.tx("ipor.restore_slippage_limit",c["MANAGER_OWNER"],mg,"setWithdrawSlippageBps(uint256)",old_s)
        # User withdrawal MUST go through IPOR withdraw(), never direct Yearn or its instant fuse.
        withdraw=number_env("SIM_IPOR_WITHDRAW_RAW",max(1,amt//10))
        pre_withdraw=self.snapshot("before-ipor.withdraw")
        def guard_withdraw():
            post=self.snapshot("after-ipor.withdraw")
            if not (isinstance(post.get("rawCollateral"),int) and isinstance(pre_withdraw.get("rawCollateral"),int)
                    and post["rawCollateral"]<pre_withdraw["rawCollateral"]):
                raise Failed("Collateral was not released on instant withdrawal")
            if post.get("rawDebtFxUSD",0)>pre_withdraw.get("rawDebtFxUSD",0):
                raise Failed("Instant withdrawal increased fxMINT debt")
            if isinstance(post.get("ltvWad"),int) and isinstance(pre_withdraw.get("ltvWad"),int):
                original_ltv=pre_withdraw["ltvWad"];target=pre_withdraw.get("targetLtvWad")
                if isinstance(target,int):
                    permitted=max(target,original_ltv-10**16)
                    if post["ltvWad"]>permitted+10**14:
                        raise Failed(f"Post-withdraw LTV > permitted policy: {post['ltvWad']} > {permitted}")
        self.tx("ipor.instant_withdraw_WBTC_with_debt_protection",depositor,v,
                "withdraw(uint256,address,address)",withdraw,depositor,depositor,condition=guard_withdraw)
    def collect_forge_receipts(self):
        b=ROOT/"broadcast"
        # Native Foundry transaction receipts prove execution on Anvil RPC, NOT source audit approval.
        for p in b.glob("*/1/run-latest.json"):
            try:
                data=json.loads(p.read_text())
                for i,r in enumerate(data.get("receipts",[])):
                    status=r.get("status")
                    if status not in ("0x1",1,"1"):
                        self.report["blockers"].append({"step":"foundry.receipt","reason":f"Non-success receipt in {p}: {status}"})
                    self.report["receipts"].append({"path":str(p.relative_to(ROOT)),"index":i,
                        "hash":r.get("transactionHash"),"status":status,
                        "gasUsed":r.get("gasUsed"),"blockNumber":r.get("blockNumber"),
                        "contractAddress":r.get("contractAddress")})
            except Exception as e:self.block("foundry.receipts",e)
    def start_anvil(self):
        if not all(shutil.which(x) for x in ("anvil","forge","cast")):
            raise Blocked("Foundry anvil/forge/cast must be installed; none are bundled or mocked")
        url=os.environ.get("ETHEREUM_FORK_RPC_URL","")
        if not url.startswith(("https://","http://")):
            raise Blocked("ETHEREUM_FORK_RPC_URL required for actual Ethereum mainnet fork")
        sock=socket.socket();sock.bind(("127.0.0.1",0));port=sock.getsockname()[1];sock.close()
        argv=["anvil","--fork-url",url,"--chain-id","1","--host","127.0.0.1","--port",str(port),"--silent"]
        if os.environ.get("SIM_FORK_BLOCK_NUMBER"):
            argv += ["--fork-block-number",str(number_env("SIM_FORK_BLOCK_NUMBER",0))]
        # No upstream URL is ever written to an output file or printed to the console.
        self.anvil=subprocess.Popen(argv,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        self.rpc=Rpc(f"http://127.0.0.1:{port}")
        for _ in range(150):
            if self.anvil.poll() is not None:raise Blocked("Anvil fork process terminated")
            try:
                if int(self.rpc.call("eth_chainId"),16)==1:
                    self.rpc.call("anvil_nodeInfo")
                    for a in (WBTC, FXMINT_POOL, YEARN_FACTORY):
                        if self.rpc.call("eth_getCode",[a,"latest"])=="0x":
                            raise Blocked(f"Ethereum fork missing code at expected mainnet contract {a}")
                    self.record("fork.ethereum_mainnet_preflight","PASS",localRpc=self.rpc.uri,
                                forkBlock=int(self.rpc.call("eth_blockNumber"),16))
                    return
            except (ConnectionRefusedError,urllib.error.URLError,TimeoutError):pass
            time.sleep(.2)
        raise Blocked("Could not verify a live Ethereum mainnet Anvil fork")
    def deploy_yearn(self):
        key=os.environ.get("SIM_DEPLOYER_PRIVATE_KEY")
        if not key:
            # Disposable CSPRNG-generated signer for the local Anvil fork only.
            # Do not persist or print this key; no upstream transactions occur.
            import secrets
            key = "0x" + secrets.token_hex(32)
        deployer = self.tool(["cast","wallet","address","--private-key",key],timeout=30).strip()
        if not nonzero_address(deployer):
            raise Blocked("Generated Anvil deployer address was invalid")
        self.rpc.call("anvil_setBalance",[deployer,hex(10**23)])
        # Do not print or persist the private key.
        env=os.environ.copy()
        env["DEPLOYER_PRIVATE_KEY"]=key
        args=["forge","script","script/DeployFXUSDYearnV20.s.sol:DeployFXUSDYearnV20",
              "--rpc-url",self.rpc.uri,"--broadcast","-vvvv"]
        cp=subprocess.run(args,cwd=ROOT,env=env,capture_output=True,text=True,timeout=1800)
        if cp.returncode:
            msg=cp.stderr[-2000:]+" "+cp.stdout[-1000:]
            for value in (os.environ.get("ETHEREUM_FORK_RPC_URL"),key):
                if value:msg=msg.replace(value,"[REDACTED]")
            raise Failed(f"Yearn deployment/configuration failed on fork: {msg}")
        patterns={"YEARN_VAULT":"CY_SIM_DEPLOYED_YEARN_VAULT", "YEARN_MASTER":"CY_SIM_DEPLOYED_YEARN_MASTER",
                  "CHILD_32":"CY_SIM_DEPLOYED_CHILD_32", "CHILD_37":"CY_SIM_DEPLOYED_CHILD_37",
                  "FXN_REWARD_CHILD":"CY_SIM_DEPLOYED_FXN_REWARD_CHILD",
                  "FXN_ROUTER":"CY_SIM_DEPLOYED_REWARD_ROUTER",
                  "YEARN_ACCOUNTANT":"CY_SIM_DEPLOYED_ACCOUNTANT"}
        for k,needle in patterns.items():
            matches=re.findall(re.escape(needle)+r"\s*:?\s*(0x[0-9A-Fa-f]{40})",cp.stdout)
            if not matches:raise Blocked(f"Deployment succeeded but report marker {needle} was not found; inspect forge logs manually")
            self.context[k]=matches[-1]
        self.record("yearn.deploy_and_configure","PASS",addresses={k:self.context[k] for k in patterns},
                    chainId=1)
    def run(self):
        try:
            self.start_anvil()
            self.context["DEPOSITOR"]=read_env_address("SIM_DEPOSITOR")
            if os.environ.get("FXUSD") and os.environ["FXUSD"].lower()!=FXUSD.lower():
                raise Blocked("FXUSD environment value is not canonical Ethereum mainnet fxUSD")
            self.context["FXN"]=os.environ.get("FXN")
            for name,env in [("IPOR_VAULT","SIM_IPOR_VAULT"),("LTV_MANAGER","SIM_LTV_MANAGER"),
               ("COLLATERAL_FUSE","SIM_FXMINT_COLLATERAL_FUSE"),
               ("ACCOUNTING_ADAPTER","SIM_FXMINT_ACCOUNTING_ADAPTER"),
               ("ALPHA","SIM_IPOR_ALPHA"),("MANAGER_OWNER","SIM_LTV_MANAGER_OWNER")]:
                self.context[name]=os.environ.get(env)
            if os.environ.get("SIM_SKIP_YEARN_DEPLOY")=="1":
                for name,env in [("YEARN_VAULT","SIM_YEARN_VAULT"),("YEARN_MASTER","SIM_YEARN_MASTER"),
                                 ("CHILD_32","SIM_YEARN_CHILD_32"),("CHILD_37","SIM_YEARN_CHILD_37")]:
                    self.context[name]=read_env_address(env)
            else:self.deploy_yearn()
            self.yearn_suite()
            self.yearn_ops_suite()
            try:self.ipor_suite()
            except Blocked as e:self.block("ipor.full_function_suite",e)
            # Cooldown uses fork time travel; execute it after oracle-sensitive
            # IPOR scenarios to avoid artificial stale-oracle false failures.
            self.cooldown_suite()
        except (Blocked,Failed,Exception) as e:self.block("simulation.execution",e)
        finally:
            if self.rpc:
                try:
                    self.report["finalState"]=self.snapshot("final-on-anvil")
                    self.report["finalForkBlock"]=int(self.rpc.call("eth_blockNumber"),16)
                except Exception as e:self.report["finalStateError"]=str(e)
            self.collect_forge_receipts()
            if self.anvil:
                self.anvil.terminate()
                try:self.anvil.wait(timeout=8)
                except subprocess.TimeoutExpired:self.anvil.kill()
            statuses=[x["status"] for x in self.report["entries"]]
            if "FAIL" in statuses:self.report["overall"]="FAILED"
            elif "BLOCKED" in statuses or self.report["blockers"]:
                self.report["overall"]="INCOMPLETE_BLOCKED"
            elif statuses and all(x=="PASS" for x in statuses):self.report["overall"]="SIMULATION_PASSED_SCOPED_CASES_ONLY"
            else:self.report["overall"]="NOT_EXECUTED"
            file=self.save();print(f"Report: {file}\nOverall: {self.report['overall']}")
            return 0 if self.report["overall"]=="SIMULATION_PASSED_SCOPED_CASES_ONLY" else 2

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    a=ap.parse_args()
    raise SystemExit(Sim(a).run())
if __name__=="__main__":main()
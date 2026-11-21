#!/usr/bin/env python3
"""Isolated local-Anvil receipt benchmark; does NOT run forge tests or broadcast to a real network."""
import json
import os
import pathlib
import statistics
import subprocess
import time
from web3 import Web3

ROOT = pathlib.Path("/tmp/boosthub-bench")
RESULT = pathlib.Path(os.environ.get("GITHUB_WORKSPACE", ".")) / "results"
BENCH = pathlib.Path(os.environ.get("GITHUB_WORKSPACE", ".")) / "BoostHub/gas-benchmark-v1"
RESULT.mkdir(exist_ok=True)
URL = "http://127.0.0.1:8545"
w3 = Web3(Web3.HTTPProvider(URL, request_kwargs={"timeout": 60}))
assert w3.is_connected() and w3.eth.chain_id == 1
ACCTS = w3.eth.accounts
OWNER, VAULT, USER, FEES = ACCTS[:4]
ETHER = 10 ** 18
GAS_LIMIT = 15_000_000
VARIANTS = ("baseline", "candidate")

def rpc(name, params=None):
    response = w3.provider.make_request(name, [] if params is None else params)
    if "error" in response:
        raise RuntimeError(str(response["error"]))
    return response.get("result")

def reset():
    rpc("anvil_reset")
    assert w3.eth.chain_id == 1

def transact(fn, sender=OWNER):
    tx = fn.transact({"from": sender, "gas": GAS_LIMIT})
    receipt = w3.eth.wait_for_transaction_receipt(tx, timeout=90)
    return {"gas": int(receipt.gasUsed), "success": receipt.status == 1,
            "tx": receipt.transactionHash.hex(), "block": int(receipt.blockNumber)}

def deploy(abi, code, args=(), sender=OWNER):
    factory = w3.eth.contract(abi=abi, bytecode=code)
    t = transact(factory.constructor(*args), sender)
    if not t["success"]:
        raise RuntimeError("Fixture deploy reverted: " + repr(args))
    receipt = w3.eth.get_transaction_receipt(t["tx"])
    return w3.eth.contract(address=receipt.contractAddress, abi=abi)

def load_sol_artifact(variant, contract):
    p = ROOT / variant / "out" / ("GasBenchFixture_v2.sol/" + contract + ".json")
    a = json.loads(p.read_text())
    return a["abi"], a["bytecode"]["object"]

def load_master(variant):
    p = ROOT / variant / "out" / "StrategyDualFXNMasterV42.sol/StrategyDualFXNMasterV42.json"
    a = json.loads(p.read_text())
    return a["abi"], a["bytecode"]["object"]

def load_vyper(variant):
    p = ROOT / "vyper" / variant / "BoostHubStaking.vy"
    abi = json.loads(subprocess.run(["vyper", "--evm-version", "cancun", "-f", "abi", str(p)],
                                    check=True, capture_output=True, text=True).stdout)
    code = (RESULT / ("vyper_creation_" + variant + ".hex")).read_text().strip()
    return abi, code

def init_master(variant, boost, convex, target=(5000,5000), guard=True):
    token = deploy(*load_sol_artifact(variant, "GasBenchToken"))
    fxn = deploy(*load_sol_artifact(variant, "GasBenchToken"))
    swap = deploy(*load_sol_artifact(variant, "GasBenchSwapper"))
    dummy_guard = deploy(*load_sol_artifact(variant, "GasBenchGuard"))
    master = deploy(*load_master(variant), (VAULT, token.address, fxn.address, swap.address))
    child1 = deploy(*load_sol_artifact(variant,"GasBenchChild"), (master.address,token.address))
    child2 = deploy(*load_sol_artifact(variant,"GasBenchChild"), (master.address,token.address))
    for fn in (master.functions.configureChildren(child1.address,child2.address),):
        assert transact(fn)["success"]
    if guard:
        assert transact(master.functions.setConvexCurveLiquidityGuard(dummy_guard.address))["success"]
    if variant == "baseline":
        assert transact(master.functions.setAllocationCaps(*target))["success"]
    else:
        assert transact(master.functions.setAllocationTargets(*target))["success"]
    if boost:
        assert transact(token.functions.mint(child1.address,boost*ETHER))["success"]
    if convex:
        assert transact(token.functions.mint(child2.address,convex*ETHER))["success"]
    return token, master, child1, child2

MASTER_CASES = [
    ("deposit_initial_equal", 0, 0, 100, 0, (5000,5000), True, "deposit"),
    ("deposit_topup_at_target", 60, 40, 20, 0, (6000,4000), True, "deposit"),
    ("deposit_all_to_underweight", 60, 40, 50, 0, (3000,7000), True, "deposit"),
    ("deposit_boost_only_guard_unused", 0, 0, 100, 0, (10000,0), False, "deposit"),
    ("deposit_convex_guard_reject", 0, 0, 100, 0, (5000,5000), False, "deposit"),
    ("withdraw_overweight_boost", 80, 20, 0, 20, (5000,5000), True, "withdraw"),
    ("withdraw_overweight_convex", 30, 70, 0, 20, (5000,5000), True, "withdraw"),
    ("withdraw_at_target_two_children", 50, 50, 0, 20, (5000,5000), True, "withdraw"),
    ("withdraw_full_two_children", 80, 20, 0, 100, (5000,5000), True, "withdraw"),
    ("rebalance_no_idle", 50, 50, 0, 0, (5000,5000), True, "rebalance"),
    ("harvest_both_children", 50, 50, 0, 0, (5000,5000), True, "harvest"),
]

def master_run(variant, scenario):
    name, boost, convex, new_deposit, amount, target, guard, mode = scenario
    token, master, cb, cc = init_master(variant, boost, convex, target, guard)
    if new_deposit:
        assert transact(token.functions.mint(master.address, new_deposit*ETHER))["success"]
    if mode == "deposit":
        r = transact(master.functions.deposit(), USER)
    elif mode == "withdraw":
        r = transact(master.functions.withdraw(amount*ETHER), VAULT)
    elif mode == "rebalance":
        r = transact(master.functions.rebalanceAllocations(), USER)
    else:
        r = transact(master.functions.harvest(), USER)
    out = [token.functions.balanceOf(x).call() // ETHER for x in
           (cb.address, cc.address, master.address, VAULT)]
    r.update({"after_boost":out[0], "after_convex":out[1],
              "after_idle":out[2], "after_vault":out[3]})
    return r

def init_vyper(variant, extra_rewards=0):
    token = deploy(*load_sol_artifact(variant, "GasBenchToken"))
    hub = deploy(*load_sol_artifact(variant,"GasBenchHub"), (token.address,))
    adapter = deploy(*load_vyper(variant), (token.address, hub.address, 1, OWNER,
                                               [Web3.to_checksum_address("0x"+"0"*40)] * 8, FEES, 0))
    assert transact(token.functions.mint(USER, 1000*ETHER))["success"]
    assert transact(token.functions.approve(adapter.address, 2**256-1), USER)["success"]
    for i in range(extra_rewards):
        reward = deploy(*load_sol_artifact(variant,"GasBenchToken"))
        assert transact(adapter.functions.add_external_reward(reward.address))["success"]
    return token, hub, adapter

VYPER_CASES = (
    "deposit_first", "deposit_topup_same_day", "checkpoint_same_day",
    "checkpoint_after_five_days", "claim_no_reward", "withdraw_twenty",
    "harvest_no_reward", "harvest_with_reward", "claim_after_harvest",
    "checkpoint_four_rewards_five_days"
)

def vyper_run(variant, name):
    many = 3 if name == "checkpoint_four_rewards_five_days" else 0
    token, hub, staking = init_vyper(variant, many)
    d = staking.functions.deposit
    if name != "deposit_first":
        first = transact(d(100*ETHER), USER)
        if not first["success"]:
            raise RuntimeError("Vyper setup deposit failed")
    if name in ("harvest_with_reward","claim_after_harvest"):
        assert transact(hub.functions.seedReward(10*ETHER))["success"]
    if name == "claim_after_harvest":
        assert transact(staking.functions.harvest(), USER)["success"]
    if name in ("checkpoint_after_five_days", "checkpoint_four_rewards_five_days"):
        rpc("evm_increaseTime", [5*86400])
        rpc("evm_mine")
    if name == "deposit_first":
        r = transact(d(100*ETHER), USER)
    elif name == "deposit_topup_same_day":
        r = transact(d(20*ETHER), USER)
    elif name.startswith("checkpoint"):
        r = transact(staking.functions.checkpoint(USER), USER)
    elif name == "claim_no_reward" or name == "claim_after_harvest":
        r = transact(staking.functions.claim_rewards(), USER)
    elif name == "withdraw_twenty":
        r = transact(staking.functions.withdraw(20*ETHER), USER)
    else:
        r = transact(staking.functions.harvest(), USER)
    r["total_staked"] = staking.functions.total_staked().call() // ETHER
    r["reward_count"] = staking.functions.reward_count().call()
    r["fee_receiver_balance_wei"] = token.functions.balanceOf(FEES).call()
    r["user_balance_wei"] = token.functions.balanceOf(USER).call()
    return r

def prepare_compiler_inputs():
    fixture = BENCH / "GasBenchFixture_v2.sol"
    for variant in VARIANTS:
        dst = ROOT / variant / "contracts" / fixture.name
        dst.write_text(fixture.read_text())
        result = subprocess.run(["forge","build","--root",str(ROOT/variant)],
                                capture_output=True, text=True, timeout=300)
        (RESULT / ("bench_fixture_build_"+variant+".log")).write_text(result.stdout+"\n"+result.stderr)
        if result.returncode: raise RuntimeError("Fixture compile "+variant+": "+result.stderr[-4000:])

def summarize(entries):
    groups = {}
    for item in entries:
        groups.setdefault((item["family"],item["scenario"],item["repetition"]),{})[item["variant"]] = item
    out = []
    for key, p in groups.items():
        b,c=p.get("baseline"),p.get("candidate")
        if not b or not c: continue
        same = b["success"] == c["success"] and all(
            b.get(k) == c.get(k) for k in
            ("after_boost","after_convex","after_idle","after_vault","total_staked",
             "reward_count","fee_receiver_balance_wei","user_balance_wei"))
        out.append({"family":key[0], "scenario":key[1],"repetition":key[2],
                    "baseline_gas":b["gas"],"candidate_gas":c["gas"],
                    "delta_gas":c["gas"]-b["gas"],
                    "saved_gas":b["gas"]-c["gas"],
                    "saving_pct":round(100*(b["gas"]-c["gas"])/b["gas"],3),
                    "comparable_state_and_outcome":same,
                    "baseline_success":b["success"], "candidate_success":c["success"],
                    "baseline_outcome":{k:v for k,v in b.items() if k.startswith("after_")},
                    "candidate_outcome":{k:v for k,v in c.items() if k.startswith("after_")}})
    return out

def main():
    prepare_compiler_inputs()
    runs = []
    repetitions = int(os.environ.get("BENCH_REPETITIONS", "3"))
    for family, cases, handler in (("master",MASTER_CASES,master_run),
                                    ("staking",VYPER_CASES,vyper_run)):
        for case in cases:
            name = case[0] if family=="master" else case
            for rep in range(1, repetitions+1):
                for variant in VARIANTS:
                    reset()
                    try:
                        r = handler(variant,case)
                        r.update({"family":family,"scenario":name,"repetition":rep,"variant":variant})
                        runs.append(r)
                        print(json.dumps({k:r[k] for k in ("family","scenario","repetition",
                              "variant","gas","success")}),flush=True)
                    except Exception as exc:
                        error={"family":family,"scenario":name,"repetition":rep,"variant":variant,
                               "error":repr(exc)}
                        runs.append(error)
                        print("BENCH_SCENARIO_ERROR "+json.dumps(error),flush=True)
    paired = summarize([x for x in runs if "gas" in x])
    (RESULT/"per_run_raw_v2.json").write_text(json.dumps(runs,indent=2))
    (RESULT/"per_run_pairs_v2.json").write_text(json.dumps(paired,indent=2))
    group_summary = []
    for family in ("master","staking"):
        for name in sorted({x["scenario"] for x in paired if x["family"]==family}):
            p=[x for x in paired if x["family"]==family and x["scenario"]==name]
            good=[x for x in p if x["comparable_state_and_outcome"] and x["baseline_success"]]
            group_summary.append({"family":family,"scenario":name,"repetitions":len(p),
                                  "comparable_repetitions":len(good),
                                  "baseline_median_gas":statistics.median(x["baseline_gas"] for x in good) if good else None,
                                  "candidate_median_gas":statistics.median(x["candidate_gas"] for x in good) if good else None,
                                  "median_saved_gas":statistics.median(x["saved_gas"] for x in good) if good else None,
                                  "median_saving_pct":statistics.median(x["saving_pct"] for x in good) if good else None})
    (RESULT/"per_run_summary_v2.json").write_text(json.dumps(group_summary,indent=2))
    print("BENCH_SUMMARY_START")
    print(json.dumps(group_summary,indent=2))
    print("BENCH_SUMMARY_END")
    print("Summary intentionally excludes reverted or state-divergent paths.",flush=True)

if __name__ == "__main__":
    main()

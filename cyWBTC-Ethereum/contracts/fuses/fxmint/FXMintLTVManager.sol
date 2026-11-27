// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IFuseCommon} from "../IFuseCommon.sol";
import {IFuseInstantWithdraw} from "../IFuseInstantWithdraw.sol";
import {FuseAction} from "../../interfaces/IPlasmaVault.sol";

interface IFXMPosition {
    function ownerOf(uint256 id) external view returns (address);
    function getPosition(uint256 id) external view returns (uint256,uint256);
    function getDebtRatioRange() external view returns (uint256,uint256);
    function priceOracle() external view returns (address);
    function configuration() external view returns (address);
    function poolManager() external view returns (address);
    function collateralToken() external view returns (address);
    function fxUSD() external view returns (address);
}
interface IFXMRegistry { function positionId() external view returns(uint256); }
interface IFXMOracle { function getExchangePrice() external view returns(uint256); }
interface IFXMFees { function getPoolFeeRatio(address,address) external view returns(uint256,uint256,uint256,uint256); }
interface IFXMScale { function getTokenScalingFactor(address) external view returns(uint256); }
interface IFXMAccess { function hasRole(uint64,address) external view returns(bool,uint32); }
interface IFXMVault {
    function authority() external view returns(address);
    function executeInternal(FuseAction[] calldata) external;
    function getManagementFeeData() external view returns(address,uint16,uint32);
    function getPerformanceFeeData() external view returns(address,uint16);
}
interface IFXMWithdraw {
    struct Request { uint256 shares; uint256 end; bool canWithdraw; uint256 window; }
    function requestInfo(address) external view returns(Request memory);
    function getSharesToRelease() external view returns(uint256);
}
interface IFXMFxSP {
    function nav() external view returns(uint256);
    function redeemRequests(address) external view returns(uint128,uint128);
}
interface IFXMConvex {
    function stakedBalanceOf(address) external view returns(uint256);
    function GAUGE() external view returns(address);
    function FXSP() external view returns(address);
}
interface IFXMSettlement {
    function pending() external view returns(address user,uint256 shares,uint256 end,uint256 cooldownShares,uint256 unlockAt,bool closed);
    function settling() external view returns(bool);
}
interface IFXMCollateralActions {
    function enter(uint256,uint256) external;
    function exit(uint256,uint256,uint256) external returns(uint256);
    function exitAndRepayFull(uint256,uint256,uint256) external returns(uint256,uint256);
}
interface IFXMBorrowActions {
    function enter(uint256,uint256,uint256) external returns(uint256);
    function exit(uint256,uint256,bool,uint256) external returns(uint256);
}
interface IFXMSupplyActions {
    struct Enter { address vault; uint256 amount; uint256 minShares; }
    struct Exit { address vault; uint256 shares; }
    function enter(Enter calldata) external returns(uint256);
    function exit(Exit calldata) external returns(uint256);
    function finalizeExit(Exit calldata) external returns(uint256,uint256);
}
interface IFXMStakeActions {
    struct Amount { address gauge; uint256 shares; }
    function enter(Amount calldata) external returns(address,uint256);
    function exit(Amount calldata) external returns(address,uint256);
}

/// @notice LTV policy and native IPOR fuse coordination only. No custody, swaps,
/// harvesting, direct protocol execution, or standalone vault execute fallback.
contract FXMintLTVManager is IFuseCommon, IFuseInstantWithdraw {
    uint256 private constant WAD=1e18;
    uint256 private constant SCALE=1e10; // raw collateral per WBTC atomic unit
    uint256 private constant FEE=1e9;
    uint256 private constant BUFFER=1e12;
    bytes32 private constant INSTANT_USED=keccak256("curveyield.fxmint.v4.instant.used");
    uint256 public constant MARKET_ID=49;
    address public immutable VERSION;
    address public immutable VAULT;
    address public immutable POSITION_REGISTRY;
    address public immutable WITHDRAW_EXECUTOR;
    address public immutable WITHDRAW_MANAGER;
    address public immutable FXSP;
    address public immutable WBTC;
    address public immutable FXUSD;
    address private immutable POOL;
    address private immutable COLLATERAL;
    address private immutable BORROW;
    address private immutable SUPPLY;
    address private immutable STAKE;
    address private immutable GAUGE;
    uint256 public targetLtvWad;
    uint256 public withdrawSlippageBps=20;

    struct Addresses { address vault; address registry; address pool; address collateralFuse; address borrowFuse; address supplyFuse; address stakeFuse; address fxsp; address withdrawManager; address withdrawExecutor; }
    struct Risk { uint256 id; uint256 collateral; uint256 debt; uint256 price; uint256 target; uint256 minimum; }
    struct Plan { bool full; uint256 id; uint256 gross; uint256 reduction; uint256 budget; uint256 fxspShares; }
    error Invalid(); error Unauthorized(); error Unsafe(); error InsufficientLiquidity(); error ScheduledRequired();
    event TargetLtvSet(uint256 oldTarget,uint256 newTarget);
    event WithdrawSlippageSet(uint256 oldBps,uint256 newBps);
    event DebtRebalanced(uint256 indexed id,uint256 debtReduction);
    event TargetWindUp(uint256 indexed id,uint256 nominalBorrow,uint256 actualReceived);
    event CollateralWithdrawal(uint256 indexed id,uint256 grossWBTC,uint256 netWBTC,uint256 debtReduction);

    constructor(Addresses memory a,uint256 target) {
        VERSION=address(this); VAULT=a.vault; POSITION_REGISTRY=a.registry; POOL=a.pool;
        COLLATERAL=a.collateralFuse; BORROW=a.borrowFuse; SUPPLY=a.supplyFuse; STAKE=a.stakeFuse;
        FXSP=a.fxsp; WITHDRAW_MANAGER=a.withdrawManager; WITHDRAW_EXECUTOR=a.withdrawExecutor;
        WBTC=IFXMPosition(a.pool).collateralToken(); FXUSD=IFXMPosition(a.pool).fxUSD();
        GAUGE=IFXMConvex(a.stakeFuse).GAUGE();
        if (a.vault==address(0)||a.registry==address(0)||a.withdrawManager==address(0)||a.withdrawExecutor==address(0)
            ||IFXMScale(IFXMPosition(a.pool).poolManager()).getTokenScalingFactor(WBTC)!=SCALE*WAD
            ||IFuseCommon(a.registry).MARKET_ID()!=49||IFuseCommon(a.collateralFuse).MARKET_ID()!=49
            ||IFuseCommon(a.borrowFuse).MARKET_ID()!=49||IFuseCommon(a.supplyFuse).MARKET_ID()!=16
            ||IFuseCommon(a.stakeFuse).MARKET_ID()!=17||IFXMConvex(a.stakeFuse).FXSP()!=a.fxsp
            ||IERC4626(a.vault).asset()!=WBTC) revert Invalid();
        _validate(target); targetLtvWad=target;
    }

    // Read the existing IPOR ATOMIST_ROLE directly. Initialized vaults revoke
    // ADMIN_ROLE and cannot register new target selectors through that role.
    // Only active members with zero execution delay may configure this manager.
    function authority() public view returns(address) { return IFXMVault(VAULT).authority(); }
    function _authorized() private view {
        if(address(this)!=VERSION) revert Invalid();
        (bool active,uint32 delay)=IFXMAccess(authority()).hasRole(100,msg.sender);
        if(!active||delay!=0) revert Unauthorized();
    }
    function setTargetLtvWad(uint256 target) external {
        _authorized(); _validate(target); emit TargetLtvSet(targetLtvWad,target); targetLtvWad=target;
    }
    function setWithdrawSlippageBps(uint256 bps) external {
        _authorized(); if(bps<5||bps>55) revert Invalid();
        emit WithdrawSlippageSet(withdrawSlippageBps,bps); withdrawSlippageBps=bps;
    }
    function _validate(uint256 target) private view returns(uint256 minimum) {
        uint256 maximum; (minimum,maximum)=IFXMPosition(POOL).getDebtRatioRange();
        if(target<0.30e18||target>0.75e18||target<=minimum||target>maximum) revert Invalid();
    }
    function _risk() private view returns(Risk memory r) {
        IFXMPosition p=IFXMPosition(POOL); r.id=IFXMRegistry(POSITION_REGISTRY).positionId();
        if(r.id==0||p.ownerOf(r.id)!=VAULT) revert Invalid();
        (r.collateral,r.debt)=p.getPosition(r.id);
        r.price=IFXMOracle(p.priceOracle()).getExchangePrice();
        if(r.price==0) revert Invalid();
        r.target=FXMintLTVManager(VERSION).targetLtvWad(); r.minimum=_validate(r.target);
    }
    function _usd(uint256 raw,uint256 price) private pure returns(uint256) { return Math.mulDiv(raw,price,WAD); }
    function _ratio(uint256 debt,uint256 usd) private pure returns(uint256) {
        return debt==0?0:usd==0?type(uint256).max:Math.mulDiv(debt,WAD,usd,Math.Rounding.Up);
    }
    function _fees() private view returns(uint256 withdrawal,uint256 repayment) {
        (,withdrawal,,repayment)=IFXMFees(IFXMPosition(POOL).configuration()).getPoolFeeRatio(POOL,VAULT);
        if(withdrawal>=FEE||repayment>=FEE) revert Invalid();
    }
    function _budget(uint256 debt) private view returns(uint256) {
        if(debt==0) return 0;
        (,uint256 fee)=_fees();
        uint256 bps=Math.max(30,Math.mulDiv(fee,10_000,FEE,Math.Rounding.Up))
            +FXMintLTVManager(VERSION).withdrawSlippageBps();
        return debt+Math.mulDiv(debt,bps,10_000,Math.Rounding.Up)+BUFFER;
    }
    function _preview(Risk memory r,uint256 need) private view returns(uint256 gross,uint256 reduction,uint256 projected) {
        if(need==0) return(0,0,_ratio(r.debt,_usd(r.collateral,r.price)));
        (uint256 fee,)=_fees(); gross=Math.mulDiv(need,FEE,FEE-fee,Math.Rounding.Up);
        uint256 raw=gross*SCALE;
        if(raw>r.collateral) revert InsufficientLiquidity();
        uint256 afterUsd=_usd(r.collateral-Math.min(r.collateral,raw+SCALE+1),r.price);
        // The existing collateral fuse enforces the current target, even on an above-target partial exit.
        uint256 allowed=Math.mulDiv(afterUsd,r.target,WAD);
        if(r.debt>allowed) reduction=Math.min(r.debt,r.debt-allowed+BUFFER);
        projected=_ratio(r.debt-reduction,afterUsd);
    }
    function previewWithdrawal(uint256 need) external view returns(uint256,uint256,uint256) { return _preview(_risk(),need); }
    function _balance(address token) private view returns(uint256) { return IERC20(token).balanceOf(VAULT); }
    function _availableWBTC(uint256 reservedShares) private view returns(uint256) {
        uint256 reserved=IERC4626(VAULT).convertToAssets(reservedShares);
        uint256 balance=_balance(WBTC); return balance>reserved?balance-reserved:0;
    }
    // Only the native self-call is used. IPOR itself verifies self-caller, supported fuses and updates NAV.
    function _one(address fuse,bytes memory data) private {
        FuseAction[] memory a=new FuseAction[](1); a[0]=FuseAction(fuse,data);
        IFXMVault(address(this)).executeInternal(a);
    }
    function _exit(uint256 id,uint256 gross,uint256 net) private {
        _one(COLLATERAL,abi.encodeCall(IFXMCollateralActions.exit,(id,gross,net)));
    }
    function _repay(Risk memory r,uint256 amount,uint256 budget) private {
        if(amount==0) return;
        if(_balance(FXUSD)<budget) revert InsufficientLiquidity();
        uint256 remaining=r.debt-amount;
        if(remaining==0||remaining<Math.mulDiv(_usd(r.collateral,r.price),r.minimum,WAD,Math.Rounding.Up)) revert Unsafe();
        _one(BORROW,abi.encodeCall(IFXMBorrowActions.exit,(r.id,amount,false,budget)));
        (,uint256 afterDebt)=IFXMPosition(POOL).getPosition(r.id);
        if(afterDebt>remaining) revert Unsafe();
        emit DebtRebalanced(r.id,r.debt-afterDebt);
    }
    function rebalanceUp(uint256 minFxspSharesOut) external {
        (address user,,,,,)=IFXMSettlement(WITHDRAW_EXECUTOR).pending();
        if(user!=address(0)) revert Invalid();
        Risk memory r=_risk();
        uint256 idle=_availableWBTC(IFXMWithdraw(WITHDRAW_MANAGER).getSharesToRelease());
        // One f(x) operate per transaction: a supply and borrow must be separate invocations.
        if(idle!=0) { _one(COLLATERAL,abi.encodeCall(IFXMCollateralActions.enter,(r.id,idle))); return; }
        uint256 allowed=Math.mulDiv(_usd(r.collateral,r.price),r.target,WAD);
        if(allowed<=r.debt+BUFFER) return;
        uint256 borrow=allowed-r.debt-BUFFER;
        uint256 beforeStable=_balance(FXUSD);
        _one(BORROW,abi.encodeCall(IFXMBorrowActions.enter,(r.id,borrow,1)));
        Risk memory afterRisk=_risk();
        if(_ratio(afterRisk.debt,_usd(afterRisk.collateral,afterRisk.price))>afterRisk.target) revert Unsafe();
        uint256 received=_balance(FXUSD)-beforeStable;
        uint256 beforeShares=_balance(FXSP);
        _one(SUPPLY,abi.encodeCall(IFXMSupplyActions.enter,(IFXMSupplyActions.Enter(FXSP,received,minFxspSharesOut))));
        uint256 minted=_balance(FXSP)-beforeShares;
        if(minted==0) revert InsufficientLiquidity();
        _one(STAKE,abi.encodeCall(IFXMStakeActions.enter,(IFXMStakeActions.Amount(GAUGE,minted))));
        emit TargetWindUp(r.id,borrow,received);
    }
    function rebalanceDown() external {
        Risk memory r=_risk(); uint256 allowed=Math.mulDiv(_usd(r.collateral,r.price),r.target,WAD);
        if(r.debt<=allowed) return;
        uint256 reduction=r.debt-allowed; _repay(r,reduction,_budget(reduction));
        Risk memory afterRisk=_risk();
        if(_ratio(afterRisk.debt,_usd(afterRisk.collateral,afterRisk.price))>afterRisk.target) revert Unsafe();
    }
    function isFinalizingScheduledWithdrawal() external view returns(bool) { return IFXMSettlement(WITHDRAW_EXECUTOR).settling(); }
    function instantWithdraw(bytes32[] calldata params) external override {
        if(params.length!=1) revert Invalid();
        if(IFXMSettlement(WITHDRAW_EXECUTOR).settling()) return;
        uint256 need=uint256(params[0]); if(need==0) return;
        bytes32 slot=INSTANT_USED; uint256 used; assembly { used := tload(slot) }
        if(used!=0) return;
        Risk memory r=_risk(); uint256 net=Math.mulDiv(need,125,100,Math.Rounding.Up);
        (uint256 gross,uint256 reduction,uint256 projected)=_preview(r,net);
        if(reduction!=0||projected>r.target) revert ScheduledRequired();
        _exit(r.id,gross,net); assembly { tstore(slot,1) }
        emit CollateralWithdrawal(r.id,gross,need,0);
    }

    // Native withdrawal request is authoritative. No request/share ledger here.
    function _request(address user,uint256 shares) private view returns(IFXMWithdraw.Request memory q) {
        q=IFXMWithdraw(WITHDRAW_MANAGER).requestInfo(user);
        if(user==address(0)||shares==0||q.shares!=shares||q.end<=block.timestamp||q.end<q.window
            ||block.timestamp<q.end-q.window||IERC20(VAULT).balanceOf(user)<shares
            ||IERC20(VAULT).allowance(user,WITHDRAW_EXECUTOR)<shares) revert Invalid();
    }
    function _last(address user,uint256 shares) private view returns(bool) {
        (address m,,)=IFXMVault(VAULT).getManagementFeeData();
        (address p,)=IFXMVault(VAULT).getPerformanceFeeData();
        uint256 other=IERC20(VAULT).totalSupply()-shares;
        if(m!=user&&m!=address(0)) other-=IERC20(VAULT).balanceOf(m);
        if(p!=user&&p!=m&&p!=address(0)) other-=IERC20(VAULT).balanceOf(p);
        if(WITHDRAW_MANAGER!=user&&WITHDRAW_MANAGER!=m&&WITHDRAW_MANAGER!=p) other-=IERC20(VAULT).balanceOf(WITHDRAW_MANAGER);
        return other==0;
    }
    function _fxspAvailable() private view returns(uint256) { return _balance(FXSP)+IFXMConvex(STAKE).stakedBalanceOf(VAULT); }
    function _scheduled(address user,uint256 shares) private view returns(Plan memory p) {
        IFXMWithdraw.Request memory q=_request(user,shares); Risk memory r=_risk(); p.id=r.id;
        p.full=_last(user,shares);
        if(p.full) { p.gross=type(uint256).max; p.reduction=r.debt; }
        else {
            uint256 reserved=IFXMWithdraw(WITHDRAW_MANAGER).getSharesToRelease();
            if(q.canWithdraw&&reserved>=shares) reserved-=shares;
            uint256 available=_availableWBTC(reserved); uint256 needed=IERC4626(VAULT).convertToAssets(shares);
            if(needed>available) (p.gross,p.reduction,)=_preview(r,needed-available);
        }
        p.budget=_budget(p.reduction); uint256 availableFxSP=_fxspAvailable();
        if(p.full) p.fxspShares=availableFxSP;
        else if(p.budget>_balance(FXUSD)&&availableFxSP!=0) {
            uint256 nav=IFXMFxSP(FXSP).nav(); if(nav==0) revert Invalid();
            p.fxspShares=Math.min(availableFxSP,Math.mulDiv(p.budget-_balance(FXUSD),WAD,nav,Math.Rounding.Up));
        }
    }
    function scheduledPlan(address user,uint256 shares) external view returns(Plan memory) { return _scheduled(user,shares); }
    function _active(address user,uint256 shares) private view {
        (address pendingUser,uint256 pendingShares,uint256 end,uint256 cooling,,bool closed)=IFXMSettlement(WITHDRAW_EXECUTOR).pending();
        if(user!=pendingUser||shares!=pendingShares||cooling!=0||closed||_request(user,shares).end!=end) revert Invalid();
    }
    function requestFxsp(address user,uint256 shares) external {
        _active(user,shares); Plan memory p=_scheduled(user,shares);
        (uint128 outstanding,)=IFXMFxSP(FXSP).redeemRequests(VAULT);
        if(outstanding!=0||p.fxspShares==0) revert Invalid();
        uint256 idle=_balance(FXSP);
        if(p.fxspShares>idle) _one(STAKE,abi.encodeCall(IFXMStakeActions.exit,(IFXMStakeActions.Amount(GAUGE,p.fxspShares-idle))));
        _one(SUPPLY,abi.encodeCall(IFXMSupplyActions.exit,(IFXMSupplyActions.Exit(FXSP,p.fxspShares))));
    }
    function finalizeFxsp() external {
        (address user,,,uint256 cooling,uint256 unlockAt,)=IFXMSettlement(WITHDRAW_EXECUTOR).pending();
        if(user==address(0)||cooling==0||block.timestamp<unlockAt) revert Invalid();
        (uint128 outstanding,uint128 matureAt)=IFXMFxSP(FXSP).redeemRequests(VAULT);
        if(outstanding!=cooling||block.timestamp<matureAt) revert Invalid();
        _one(SUPPLY,abi.encodeCall(IFXMSupplyActions.finalizeExit,(IFXMSupplyActions.Exit(FXSP,cooling))));
        (outstanding,)=IFXMFxSP(FXSP).redeemRequests(VAULT);
        if(outstanding!=0) revert Invalid();
    }
    function repayForWithdrawal(address user,uint256 shares) external {
        _active(user,shares); Plan memory p=_scheduled(user,shares);
        if(p.full||p.reduction==0) revert Invalid();
        _repay(_risk(),p.reduction,p.budget);
    }
    function releaseForWithdrawal(address user,uint256 shares) external {
        _active(user,shares); Plan memory p=_scheduled(user,shares);
        if(p.full||p.reduction!=0||p.gross==0) revert Invalid();
        _exit(p.id,p.gross,0); emit CollateralWithdrawal(p.id,p.gross,0,0);
    }
    function fullCloseEligible() public view returns(bool) {
        (address user,uint256 shares,uint256 end,uint256 cooling,,bool closed)=IFXMSettlement(WITHDRAW_EXECUTOR).pending();
        if(user==address(0)||closed||cooling!=0||_request(user,shares).end!=end||!_last(user,shares)||_fxspAvailable()!=0) return false;
        (uint128 outstanding,)=IFXMFxSP(FXSP).redeemRequests(VAULT);
        if(outstanding!=0) return false;
        return _balance(FXUSD)>=_budget(_risk().debt);
    }
    function closeFull() external {
        if(!fullCloseEligible()) revert Invalid(); Risk memory r=_risk();
        _one(COLLATERAL,abi.encodeCall(IFXMCollateralActions.exitAndRepayFull,(r.id,_budget(r.debt),0)));
    }
}

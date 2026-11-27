// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IPlasmaVault,FuseAction} from "../interfaces/IPlasmaVault.sol";
import {FXMintLTVManager,IFXMWithdraw,IFXMFxSP} from "../fuses/fxmint/FXMintLTVManager.sol";

interface INativeWithdrawSettlement is IFXMWithdraw {
    function releaseFunds(uint256,uint256) external;
}

/// @notice Replacement of the existing two-button withdrawal executor. It is
/// not a general executor: callers cannot choose targets, selectors or amounts.
/// Its fixed calls use the existing IPOR vault and WithdrawManager roles.
/// Manager supplies the policy; only the native IPOR contracts settle assets.
contract FulfillWithdrawExecutor {
    FXMintLTVManager public immutable MANAGER;
    IPlasmaVault public immutable VAULT;
    INativeWithdrawSettlement public immutable WITHDRAW_MANAGER;
    struct Pending {
        address user;
        uint256 shares;
        uint256 end;
        uint256 cooldownShares;
        uint256 unlockAt;
        bool closed;
    }
    Pending public pending;
    bool public settling;
    uint256 private status=1;
    error Invalid(); error NotMature();
    event WithdrawRequestInitialized(address indexed user,uint256 shares);
    event WithdrawRequestAdvanced(address indexed user,uint8 stage,uint256 detail);
    event WithdrawRequestFinalized(address indexed user,uint256 shares,uint256 assets);
    event WithdrawRequestInvalidated(address indexed user);
    modifier nonReentrant() { if(status!=1) revert Invalid(); status=2; _; status=1; }

    constructor(address manager) {
        MANAGER=FXMintLTVManager(manager);
        if(MANAGER.WITHDRAW_EXECUTOR()!=address(this)) revert Invalid();
        VAULT=IPlasmaVault(MANAGER.VAULT());
        WITHDRAW_MANAGER=INativeWithdrawSettlement(MANAGER.WITHDRAW_MANAGER());
    }
    function _native(bytes memory data) private {
        FuseAction[] memory calls=new FuseAction[](1);
        calls[0]=FuseAction(address(MANAGER),data); VAULT.execute(calls);
    }
    function _refresh() private {
        uint256[] memory markets=new uint256[](4);
        markets[0]=49; markets[1]=17; markets[2]=16; markets[3]=7;
        VAULT.updateMarketsBalances(markets);
    }
    function _valid(Pending storage p,IFXMWithdraw.Request memory r) private view returns(bool) {
        return p.user!=address(0)&&p.shares!=0&&r.shares==p.shares&&r.end==p.end
            &&r.end>block.timestamp&&r.end>=r.window&&block.timestamp>=r.end-r.window
            &&IERC20(address(VAULT)).balanceOf(p.user)>=p.shares
            &&IERC20(address(VAULT)).allowance(p.user,address(this))>=p.shares;
    }
    function InitializeFulfillWithdrawRequest(address user) external nonReentrant {
        if(pending.user!=address(0)) revert Invalid();
        IFXMWithdraw.Request memory r=WITHDRAW_MANAGER.requestInfo(user);
        pending=Pending(user,r.shares,r.end,0,0,false);
        if(!_valid(pending,r)) revert Invalid();
        (uint128 existing,)=IFXMFxSP(MANAGER.FXSP()).redeemRequests(address(VAULT));
        if(existing!=0) revert Invalid();
        _refresh();
        FXMintLTVManager.Plan memory plan=MANAGER.scheduledPlan(user,r.shares);
        if(plan.fxspShares!=0) _cool(pending,plan.fxspShares);
        emit WithdrawRequestInitialized(user,r.shares);
    }
    function _cool(Pending storage p,uint256 shares) private {
        _native(abi.encodeCall(FXMintLTVManager.requestFxsp,(p.user,p.shares)));
        (uint128 amount,uint128 unlock)=IFXMFxSP(MANAGER.FXSP()).redeemRequests(address(VAULT));
        if(amount!=shares||unlock<block.timestamp+1 hours||unlock>=p.end) revert Invalid();
        p.cooldownShares=amount; p.unlockAt=unlock;
        emit WithdrawRequestAdvanced(p.user,0,unlock);
    }
    function FinalizeFulfillWithdrawRequest() external nonReentrant {
        Pending storage p=pending;
        if(p.user==address(0)) revert Invalid();
        if(p.cooldownShares!=0) {
            (uint128 outstanding,)=IFXMFxSP(MANAGER.FXSP()).redeemRequests(address(VAULT));
            if(outstanding!=0) {
                if(block.timestamp<p.unlockAt) revert NotMature();
                _native(abi.encodeCall(FXMintLTVManager.finalizeFxsp,()));
            }
            p.cooldownShares=0; p.unlockAt=0;
            emit WithdrawRequestAdvanced(p.user,1,0);
            return;
        }
        IFXMWithdraw.Request memory r=WITHDRAW_MANAGER.requestInfo(p.user);
        if(!_valid(p,r)) { emit WithdrawRequestInvalidated(p.user); delete pending; return; }
        _refresh();
        if(!p.closed) {
            FXMintLTVManager.Plan memory plan=MANAGER.scheduledPlan(p.user,p.shares);
            if(plan.fxspShares!=0) { _cool(p,plan.fxspShares); return; }
            if(plan.budget>IERC20(MANAGER.FXUSD()).balanceOf(address(VAULT))) {
                emit WithdrawRequestAdvanced(p.user,2,plan.budget); return;
            }
            if(plan.full) {
                _native(abi.encodeCall(FXMintLTVManager.closeFull,()));
                p.closed=true; emit WithdrawRequestAdvanced(p.user,3,0); return;
            }
            if(plan.reduction!=0) {
                _native(abi.encodeCall(FXMintLTVManager.repayForWithdrawal,(p.user,p.shares)));
                emit WithdrawRequestAdvanced(p.user,4,plan.reduction); return;
            }
            if(plan.gross!=0) {
                _native(abi.encodeCall(FXMintLTVManager.releaseForWithdrawal,(p.user,p.shares)));
                emit WithdrawRequestAdvanced(p.user,5,plan.gross); return;
            }
        }
        _settle(p,r);
    }
    function _settle(Pending storage p,IFXMWithdraw.Request memory r) private {
        uint256 reserved=WITHDRAW_MANAGER.getSharesToRelease();
        bool alreadyReleased=r.canWithdraw&&reserved>=p.shares;
        uint256 total=alreadyReleased?reserved:reserved+p.shares;
        uint256 required=IERC4626(address(VAULT)).convertToAssets(total);
        if(IERC20(MANAGER.WBTC()).balanceOf(address(VAULT))<required) {
            emit WithdrawRequestAdvanced(p.user,6,required); return;
        }
        // Preserve other released shares; never overwrite their reserve.
        // Native release timestamp must be strictly after request timestamp.
        if(!alreadyReleased) {
            if(block.timestamp<=r.end-r.window+1) revert Invalid();
            WITHDRAW_MANAGER.releaseFunds(block.timestamp-1,total);
        }
        settling=true;
        address user=p.user; uint256 shares=p.shares;
        uint256 assets=VAULT.redeemFromRequest(shares,user,user);
        settling=false; delete pending;
        emit WithdrawRequestFinalized(user,shares,assets);
    }
}

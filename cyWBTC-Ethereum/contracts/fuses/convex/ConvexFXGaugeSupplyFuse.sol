// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IFuseCommon} from "../IFuseCommon.sol";
import {PlasmaVaultConfigLib} from "../../libraries/PlasmaVaultConfigLib.sol";
import {TransientStorageLib} from "../../transient_storage/TransientStorageLib.sol";
import {TypeConversionLib} from "../../libraries/TypeConversionLib.sol";

interface IConvexFXBooster {
    function createVault(uint256 pid) external returns(address);
}
interface IConvexFXPoolRegistry {
    function vaultMap(uint256 pid,address owner) external view returns(address);
    function poolInfo(uint256 pid) external view returns(address implementation,address gauge,address stakingToken,address rewards,uint8 active);
}
interface IConvexFXPersonalVault {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
}
struct ConvexFXGaugeSupplyFuseEnterData {
    address childLiquidityGauge;
    uint256 lpTokenAmount;
}
struct ConvexFXGaugeSupplyFuseExitData {
    address childLiquidityGauge;
    uint256 lpTokenAmount;
}
/// @dev Minimal protocol-specific adaptation of IPOR-Labs/ipor-fusion/contracts/fuses/curve_gauge/CurveChildLiquidityGaugeSupplyFuse.sol
///      at commit 636bb4c2b78826586a0c0c8c9083c5c285692657. IPOR's delegatecall, substrate and market ID model is retained.

/// @notice Staking/unstaking fxSP in Convex f(x) PID 37. No leverage, routing or accounting logic.
contract ConvexFXGaugeSupplyFuse is IFuseCommon {
    using SafeERC20 for IERC20;
    event ConvexFXGaugeSupplyFuseEnter(address version,address gauge,uint256 amount);
    event ConvexFXGaugeSupplyFuseExit(address version,address gauge,uint256 amount);
    error ConvexFXGaugeSupplyFuseUnsupportedGauge(address gauge);
    address public immutable VERSION;
    uint256 public immutable MARKET_ID;
    address public immutable BOOSTER;
    address public immutable REGISTRY;
    address public immutable GAUGE;
    address public immutable FXSP;
    uint256 public constant PID=37;
    constructor(uint256 marketId_,address booster_,address registry_){
        VERSION=address(this); MARKET_ID=marketId_; BOOSTER=booster_; REGISTRY=registry_;
        (,address gauge,address stakingToken,,uint8 active)=IConvexFXPoolRegistry(registry_).poolInfo(PID);
        require(active==1,"INACTIVE_POOL");
        GAUGE=gauge; FXSP=stakingToken;
    }
    function enter(ConvexFXGaugeSupplyFuseEnterData memory data_) public returns(address childLiquidityGauge,uint256 lpTokenAmount){
        _check(data_.childLiquidityGauge);
        childLiquidityGauge=GAUGE;
        if(data_.lpTokenAmount==0) return (GAUGE,0);
        uint256 available=IERC20(FXSP).balanceOf(address(this));
        lpTokenAmount=data_.lpTokenAmount<available?data_.lpTokenAmount:available;
        if(lpTokenAmount==0) return (GAUGE,0);
        address personal=_personal(true);
        IERC20(FXSP).forceApprove(personal,lpTokenAmount);
        IConvexFXPersonalVault(personal).deposit(lpTokenAmount);
        emit ConvexFXGaugeSupplyFuseEnter(VERSION,GAUGE,lpTokenAmount);
    }
    function enterTransient() external {
        bytes32[] memory inputs=TransientStorageLib.getInputs(VERSION);
        (address gauge,uint256 amount)=enter(ConvexFXGaugeSupplyFuseEnterData(TypeConversionLib.toAddress(inputs[0]),TypeConversionLib.toUint256(inputs[1])));
        bytes32[] memory outputs=new bytes32[](2);
        outputs[0]=TypeConversionLib.toBytes32(gauge);
        outputs[1]=TypeConversionLib.toBytes32(amount);
        TransientStorageLib.setOutputs(VERSION,outputs);
    }
    function exit(ConvexFXGaugeSupplyFuseExitData memory data_) public returns(address childLiquidityGauge,uint256 lpTokenAmount){
        _check(data_.childLiquidityGauge);
        childLiquidityGauge=GAUGE;
        if(data_.lpTokenAmount==0) return (GAUGE,0);
        address personal=_personal(false);
        if(personal==address(0)) return (GAUGE,0);
        lpTokenAmount=data_.lpTokenAmount;
        IConvexFXPersonalVault(personal).withdraw(lpTokenAmount);
        emit ConvexFXGaugeSupplyFuseExit(VERSION,GAUGE,lpTokenAmount);
    }
    function exitTransient() external {
        bytes32[] memory inputs=TransientStorageLib.getInputs(VERSION);
        (address gauge,uint256 amount)=exit(ConvexFXGaugeSupplyFuseExitData(TypeConversionLib.toAddress(inputs[0]),TypeConversionLib.toUint256(inputs[1])));
        bytes32[] memory outputs=new bytes32[](2);
        outputs[0]=TypeConversionLib.toBytes32(gauge);
        outputs[1]=TypeConversionLib.toBytes32(amount);
        TransientStorageLib.setOutputs(VERSION,outputs);
    }
    function stakedBalanceOf(address account) external view returns(uint256) {
        address personal = _personalFor(account);
        return personal == address(0) ? 0 : IERC20(GAUGE).balanceOf(personal);
    }
    function _personalFor(address account) private view returns(address) {
        return IConvexFXPoolRegistry(REGISTRY).vaultMap(PID,account);
    }
    function _personal(bool create) private returns(address vault){
        vault=_personalFor(address(this));
        if(vault==address(0) && create) vault=IConvexFXBooster(BOOSTER).createVault(PID);
        if(vault==address(0) && !create) revert ConvexFXGaugeSupplyFuseUnsupportedGauge(GAUGE);
    }
    function _check(address gauge) private view {
        if(gauge!=GAUGE || !PlasmaVaultConfigLib.isSubstrateAsAssetGranted(MARKET_ID,gauge))
            revert ConvexFXGaugeSupplyFuseUnsupportedGauge(gauge);
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.30;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFuseCommon} from "../IFuseCommon.sol";
import {IporMath} from "../../libraries/math/IporMath.sol";
import {PlasmaVaultConfigLib} from "../../libraries/PlasmaVaultConfigLib.sol";
import {TransientStorageLib} from "../../transient_storage/TransientStorageLib.sol";
import {TypeConversionLib} from "../../libraries/TypeConversionLib.sol";

interface IFxSPBasePool {
    function deposit(address receiver,address tokenIn,uint256 amount,uint256 minSharesOut) external returns(uint256 shares);
    function requestRedeem(uint256 shares) external;
    function redeem(address receiver,uint256 shares) external returns(uint256 amountYieldOut,uint256 amountStableOut);
    function balanceOf(address) external view returns(uint256);
}

struct FxSPSupplyFuseEnterData {
    address vault;
    uint256 vaultAssetAmount;
    uint256 minSharesOut;
}
struct FxSPSupplyFuseExitData {
    address vault;
    uint256 shares;
}

/// @dev Minimal protocol-specific adaptation of IPOR-Labs/ipor-fusion/contracts/fuses/erc4626/Erc4626SupplyFuse.sol
///      at commit 636bb4c2b78826586a0c0c8c9083c5c285692657. IPOR's delegatecall, substrate and market ID model is retained.

/// @notice fxUSD <-> fxSP pool entry and native one-hour scheduled exit.
/// @dev Replaces ERC4626-only calls; pool is not ERC4626. No instant withdrawal selector.
contract FxSPSupplyFuse is IFuseCommon {
    using SafeERC20 for IERC20;
    address public immutable VERSION;
    uint256 public immutable MARKET_ID;
    address public immutable FXSP;
    address public immutable FXUSD;
    event FxSPSupplyFuseEnter(address version,address asset,address vault,uint256 amount);
    event FxSPSupplyFuseExitRequested(address version,address vault,uint256 shares);
    event FxSPSupplyFuseExit(address version,address vault,uint256 shares,uint256 fxusdOut,uint256 usdcOut);
    error FxSPSupplyFuseUnsupportedVault(address vault);
    constructor(uint256 marketId_,address fxsp_,address fxusd_){
        VERSION=address(this);
        MARKET_ID=marketId_;
        FXSP=fxsp_;
        FXUSD=fxusd_;
    }
    function enter(FxSPSupplyFuseEnterData memory data_) public returns(uint256 finalVaultAssetAmount){
        if(data_.vaultAssetAmount==0) return 0;
        _check(data_.vault);
        finalVaultAssetAmount=IporMath.min(data_.vaultAssetAmount,IERC20(FXUSD).balanceOf(address(this)));
        if(finalVaultAssetAmount==0) return 0;
        IERC20(FXUSD).forceApprove(FXSP,finalVaultAssetAmount);
        IFxSPBasePool(FXSP).deposit(address(this),FXUSD,finalVaultAssetAmount,data_.minSharesOut);
        emit FxSPSupplyFuseEnter(VERSION,FXUSD,FXSP,finalVaultAssetAmount);
    }
    function enterTransient() external {
        bytes32[] memory inputs=TransientStorageLib.getInputs(VERSION);
        uint256 amount=enter(FxSPSupplyFuseEnterData(TypeConversionLib.toAddress(inputs[0]),TypeConversionLib.toUint256(inputs[1]),TypeConversionLib.toUint256(inputs[2])));
        bytes32[] memory outputs=new bytes32[](1);
        outputs[0]=TypeConversionLib.toBytes32(amount);
        TransientStorageLib.setOutputs(VERSION,outputs);
    }
    /// @notice Request a normal scheduled exit; fxSP tracks its own unlock timestamp.
    function exit(FxSPSupplyFuseExitData memory data_) public returns(uint256 shares){
        _check(data_.vault);
        shares=IporMath.min(data_.shares,IFxSPBasePool(FXSP).balanceOf(address(this)));
        if(shares==0) return 0;
        IFxSPBasePool(FXSP).requestRedeem(shares);
        emit FxSPSupplyFuseExitRequested(VERSION,FXSP,shares);
    }
    function exitTransient() external {
        bytes32[] memory inputs=TransientStorageLib.getInputs(VERSION);
        uint256 shares=exit(FxSPSupplyFuseExitData(TypeConversionLib.toAddress(inputs[0]),TypeConversionLib.toUint256(inputs[1])));
        bytes32[] memory outputs=new bytes32[](1);
        outputs[0]=TypeConversionLib.toBytes32(shares);
        TransientStorageLib.setOutputs(VERSION,outputs);
    }
    /// @notice Complete f(x)'s already-unlocked request. USDC swapping uses the existing IPOR swap fuse.
    function finalizeExit(FxSPSupplyFuseExitData memory data_) external returns(uint256 fxusdOut,uint256 usdcOut){
        _check(data_.vault);
        (fxusdOut,usdcOut)=IFxSPBasePool(FXSP).redeem(address(this),data_.shares);
        emit FxSPSupplyFuseExit(VERSION,FXSP,data_.shares,fxusdOut,usdcOut);
    }
    function _check(address vault_) private view {
        if(vault_!=FXSP || !PlasmaVaultConfigLib.isSubstrateAsAssetGranted(MARKET_ID,vault_))
            revert FxSPSupplyFuseUnsupportedVault(vault_);
    }
}

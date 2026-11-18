// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.30;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IMarketBalanceFuse} from "../IMarketBalanceFuse.sol";
import {PlasmaVaultConfigLib} from "../../libraries/PlasmaVaultConfigLib.sol";
import {IConvexFXPoolRegistry} from "./ConvexFXGaugeSupplyFuse.sol";
import {IFxSPNav} from "../fxsp/FxSPCurveBalanceFuse.sol";

interface IConvexFXGaugeBalance {
    function balanceOf(address owner) external view returns(uint256);
}
/// @dev Minimal protocol-specific adaptation of IPOR-Labs/ipor-fusion/contracts/fuses/curve_gauge/CurveChildLiquidityGaugeErc4626BalanceFuse.sol
///      at commit 636bb4c2b78826586a0c0c8c9083c5c285692657. IPOR's delegatecall, substrate and market ID model is retained.

/// @notice USD value of fxSP actually staked in this PlasmaVault's personal Convex PID 37 vault.
contract ConvexFXGaugeBalanceFuse is IMarketBalanceFuse {
    uint256 public immutable MARKET_ID;
    address public immutable REGISTRY;
    uint256 public constant PID=37;
    constructor(uint256 marketId_,address registry_){MARKET_ID=marketId_;REGISTRY=registry_;}
    function balanceOf() external view override returns(uint256){
        bytes32[] memory substrates=PlasmaVaultConfigLib.getMarketSubstrates(MARKET_ID);
        address personal=IConvexFXPoolRegistry(REGISTRY).vaultMap(PID,address(this));
        if(personal==address(0))return 0;
        uint256 balance;
        for(uint256 i;i<substrates.length;++i){
            address gauge=PlasmaVaultConfigLib.bytes32ToAddress(substrates[i]);
            (,address expectedGauge,address fxsp,,uint8 active)=IConvexFXPoolRegistry(REGISTRY).poolInfo(PID);
            require(gauge==expectedGauge && active==1,"WRONG_GAUGE");
            uint256 staked=IConvexFXGaugeBalance(gauge).balanceOf(personal);
            if(staked!=0) balance+=Math.mulDiv(staked,IFxSPNav(fxsp).nav(),1e18);
        }
        return balance;
    }
}

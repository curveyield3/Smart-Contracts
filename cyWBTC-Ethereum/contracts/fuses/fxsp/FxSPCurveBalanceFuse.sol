// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IMarketBalanceFuse} from "../IMarketBalanceFuse.sol";
import {PlasmaVaultConfigLib} from "../../libraries/PlasmaVaultConfigLib.sol";

interface IFxSPNav {
    function nav() external view returns(uint256);
}
/// @dev Minimal protocol-specific adaptation of IPOR-Labs/ipor-fusion/contracts/fuses/curve_stableswap_ng/CurveStableswapNGSingleSideBalanceFuse.sol
///      at commit 636bb4c2b78826586a0c0c8c9083c5c285692657. IPOR's delegatecall, substrate and market ID model is retained.

/// @notice Curve-market accounting for fxSP held idle by the PlasmaVault (including cooldown shares).
/// @dev Only the canonical f(x) fxSP pool's USD NAV is used; fxSP is not a StableSwap-NG token.
contract FxSPCurveBalanceFuse is IMarketBalanceFuse {
    uint256 public immutable MARKET_ID;
    constructor(uint256 marketId_){MARKET_ID=marketId_;}
    function balanceOf() external view override returns(uint256){
        bytes32[] memory substrates=PlasmaVaultConfigLib.getMarketSubstrates(MARKET_ID);
        uint256 balance;
        for(uint256 i;i<substrates.length;++i){
            address fxsp=PlasmaVaultConfigLib.bytes32ToAddress(substrates[i]);
            uint256 shares=IERC20(fxsp).balanceOf(address(this));
            if(shares!=0) balance+=Math.mulDiv(shares,IFxSPNav(fxsp).nav(),1e18);
        }
        return balance;
    }
}

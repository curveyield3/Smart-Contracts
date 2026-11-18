// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IFuseCommon} from "../IFuseCommon.sol";
import {IMarketBalanceFuse} from "../IMarketBalanceFuse.sol";
import {IPriceOracleMiddleware} from "../../price_oracle/IPriceOracleMiddleware.sol";
import {PlasmaVaultLib} from "../../libraries/PlasmaVaultLib.sol";

/// @notice Values only fxSP shares in the PlasmaVault wallet, never Convex-staked shares.
contract FxSPIdleBalanceFuse is IFuseCommon, IMarketBalanceFuse {
    uint256 public constant MARKET_ID = 16; // Curve-pool namespace
    address public immutable FXSP;

    constructor(address fxsp_) {
        require(fxsp_ != address(0), "ZERO_ADDRESS");
        FXSP = fxsp_;
    }

    function balanceOf() external view override returns (uint256) {
        uint256 shares = IERC20(FXSP).balanceOf(address(this));
        if (shares == 0) return 0;
        (uint256 price, uint256 decimals_) = IPriceOracleMiddleware(
            PlasmaVaultLib.getPriceOracleMiddleware()
        ).getAssetPrice(FXSP);
        if (price == 0 || decimals_ > 36) revert("INVALID_PRICE");
        uint256 priceWad = decimals_ <= 18 ? price * 10 ** (18 - decimals_) : price / 10 ** (decimals_ - 18);
        return Math.mulDiv(shares, priceWad, 1e18);
    }
}

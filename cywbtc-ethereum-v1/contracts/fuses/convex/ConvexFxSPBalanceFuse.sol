// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IFuseCommon} from "../IFuseCommon.sol";
import {IMarketBalanceFuse} from "../IMarketBalanceFuse.sol";
import {IPriceOracleMiddleware} from "../../price_oracle/IPriceOracleMiddleware.sol";
import {PlasmaVaultLib} from "../../libraries/PlasmaVaultLib.sol";

interface IConvexPid37RegistryForBalance {
    function vaultMap(uint256 pid, address owner) external view returns (address);
}
interface IFxspGaugeForBalance {
    function balanceOf(address staker) external view returns (uint256);
}

/// @notice USD balance of fxSP actually staked in the PlasmaVault's personal Convex PID37 vault.
contract ConvexFxSPBalanceFuse is IFuseCommon, IMarketBalanceFuse {
    uint256 public constant MARKET_ID = 17; // Curve-gauge namespace
    address public immutable REGISTRY;
    address public immutable GAUGE;
    address public immutable FXSP;

    constructor(address registry_, address gauge_, address fxsp_) {
        require(registry_ != address(0) && gauge_ != address(0) && fxsp_ != address(0), "ZERO_ADDRESS");
        REGISTRY = registry_;
        GAUGE = gauge_;
        FXSP = fxsp_;
    }

    function balanceOf() external view override returns (uint256) {
        address personalVault = IConvexPid37RegistryForBalance(REGISTRY).vaultMap(37, address(this));
        if (personalVault == address(0)) return 0;
        uint256 shares = IFxspGaugeForBalance(GAUGE).balanceOf(personalVault);
        if (shares == 0) return 0;
        (uint256 price, uint256 decimals_) = IPriceOracleMiddleware(
            PlasmaVaultLib.getPriceOracleMiddleware()
        ).getAssetPrice(FXSP);
        if (price == 0 || decimals_ > 36) revert("INVALID_PRICE");
        uint256 priceWad = decimals_ <= 18 ? price * 10 ** (18 - decimals_) : price / 10 ** (decimals_ - 18);
        return Math.mulDiv(shares, priceWad, 1e18);
    }
}

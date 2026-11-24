// SPDX-License-Identifier: MIT

/**
 * @title CurveYield System Component
 * @notice CurveYield is a decentralized NGO building optimized DeFi systems for the good of all.
 *
 * @dev CurveYield integrates specialized AMM infrastructure, tokenized yield strategies, credit
 * markets, and protocol-owned liquidity into a unified, capital-efficient liquidity stack governed
 * by an open, international DAO community.
 *
 * Protocol operations are enhanced by cross-chain bridging and messaging, MEV capture systems,
 * off-chain to on-chain automation, and peer-to-peer data networks.
 *
 * This contract is one component of the CurveYield system.
 *
 * CurveYield uses proven DeFi primitives where possible and adds targeted coordination and
 * capital-efficiency-enhancing contracts where needed. Users and integrators must review
 * CurveYield documentation before use.
 *
 * Learn more:
 * dApp: https://curveyield.com & https://curveyield.org
 *
 * Decentralized links may have limited or delayed availability during periods of high network activity:
 * https://curveyield.eth.limo
 * https://curveyield.dao -  may require a Brave Browser or an Unstoppable Domains browser plugin to use
 *
 */

pragma solidity 0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

interface IStableSwapNG {
    function coins(uint256 index) external view returns (address);
    function price_oracle(uint256 index) external view returns (uint256);
}

interface IRevenueVault {
    function asset() external view returns (address);
    function decimals() external view returns (uint8);
    function convertToAssets(uint256 shares) external view returns (uint256);
}

interface IOracleToken {
    function decimals() external view returns (uint8);
}

/// @notice 18-decimal share-denominated historical prices for the SDT/cyvlSDT/cyvlSDTav pool.
/// @dev Pool coin ordering: SDT, cyvlSDT, cyvlSDTav. EMA prices are rate-normalized.
///      Current ERC-4626 conversion is applied once; it is not itself an EMA.
contract CurveYieldSDTShareOracle {
    error InvalidPool();
    error InvalidPair();
    error InvalidRate();

    IStableSwapNG public immutable pool;
    IRevenueVault public immutable vault;

    constructor(address pool_, address sdt_, address cyvlSDT_, address vault_) {
        if (
            pool_ == address(0) ||
            sdt_ == address(0) ||
            cyvlSDT_ == address(0) ||
            vault_ == address(0) ||
            IStableSwapNG(pool_).coins(0) != sdt_ ||
            IStableSwapNG(pool_).coins(1) != cyvlSDT_ ||
            IStableSwapNG(pool_).coins(2) != vault_ ||
            IRevenueVault(vault_).asset() != cyvlSDT_ ||
            IOracleToken(sdt_).decimals() != 18 ||
            IOracleToken(cyvlSDT_).decimals() != 18 ||
            IRevenueVault(vault_).decimals() != 18
        ) revert InvalidPool();

        pool = IStableSwapNG(pool_);
        vault = IRevenueVault(vault_);
    }

    /// @param pair 0: SDT per cyvlSDT; 1: SDT per vault share;
    ///             2: cyvlSDT per vault share. Use the router's inversion for reverse routes.
    function price_oracle(uint256 pair) external view returns (uint256 rate) {
        if (pair == 0) {
            rate = pool.price_oracle(0);
        } else {
            if (pair > 2) revert InvalidPair();
            uint256 normalized = pool.price_oracle(1);
            uint256 pps = vault.convertToAssets(1e18);
            uint256 denominator = pair == 1 ? 1e18 : pool.price_oracle(0);
            if (denominator == 0) revert InvalidRate();
            rate = Math.mulDiv(normalized, pps, denominator);
        }
        if (rate == 0) revert InvalidRate();
    }
}

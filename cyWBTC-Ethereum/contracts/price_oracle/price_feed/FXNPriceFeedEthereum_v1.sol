// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.30;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @dev Minimal interfaces matching the verified Ethereum Curve FXN/WETH
///      CryptoSwap pool and Chainlink ETH/USD aggregator proxy.
interface IFXNCurveCryptoOracle {
    function coins(uint256 index) external view returns (address);
    function price_oracle() external view returns (uint256);
}

interface IFXNChainlinkETHUSD {
    function decimals() external view returns (uint8);
    function latestRoundData()
        external view returns (uint80, int256, uint256, uint256, uint80);
}

/// @title FXNPriceFeedEthereum
/// @notice IPOR IPriceFeed-compatible FXN/USD source with 8 decimals.
/// @dev Like IPOR's chain-specific WstETHPriceFeedEthereum, composes a
///      token/ETH rate with a Chainlink ETH/USD price. The FXN/ETH leg is the
///      Curve pool's 10-minute-half-life EMA, NEVER its spot price.
///      This source is intended ONLY for the known Ethereum mainnet pool.
///      Register it as a vault-specific FXN source, not as the WBTC price.
contract FXNPriceFeedEthereum {
    uint8 public constant decimals = 8;
    uint256 private constant WAD = 1e18;
    uint256 private constant MAX_ETH_FEED_AGE = 1 days;

    address public constant FXN = 0x365AccFCa291e7D3914637ABf1F7635dB165Bb09;
    address public constant WETH = 0xC02aaA39b223FE8D0A0E5C4F27eAD9083C756Cc2;
    address public constant FXN_WETH_POOL = 0xc15f285679a1ef2d25f53d4cbd0265e1d02f2a92;
    address public constant ETH_USD_CHAINLINK = 0x5f4eC3Df9CbD43714FE2740f5E3616155c5b8419;

    error InvalidPool();
    error InvalidETHFeed();
    error StaleETHFeed();
    error InvalidFXNPrice();

    constructor() {
        IFXNCurveCryptoOracle pool = IFXNCurveCryptoOracle(FXN_WETH_POOL);
        // Curve Crypto pool oracle is coin[1] (FXN) priced in coin[0] (WETH).
        if (pool.coins(0) != WETH || pool.coins(1) != FXN) revert InvalidPool();
        if (IFXNChainlinkETHUSD(ETH_USD_CHAINLINK).decimals() != decimals) revert InvalidETHFeed();
    }

    /// @notice Latest FXN/USD valuation; mirrors IPOR's IPriceFeed ABI.
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        int256 ethUsd;
        (roundId, ethUsd, startedAt, updatedAt, answeredInRound) =
            IFXNChainlinkETHUSD(ETH_USD_CHAINLINK).latestRoundData();
        if (ethUsd <= 0) revert InvalidETHFeed();
        if (updatedAt == 0 || updatedAt > block.timestamp ||
            block.timestamp - updatedAt > MAX_ETH_FEED_AGE) revert StaleETHFeed();

        // EMA: WETH per whole FXN with 1e18 scaling; Chainlink: USD per ETH with 1e8 scaling.
        uint256 fxnWeth = IFXNCurveCryptoOracle(FXN_WETH_POOL).price_oracle();
        if (fxnWeth == 0) revert InvalidFXNPrice();
        uint256 fxnUsd8 = Math.mulDiv(fxnWeth, uint256(ethUsd), WAD);
        if (fxnUsd8 == 0 || fxnUsd8 > uint256(type(int256).max)) revert InvalidFXNPrice();
        answer = int256(fxnUsd8);
    }
}

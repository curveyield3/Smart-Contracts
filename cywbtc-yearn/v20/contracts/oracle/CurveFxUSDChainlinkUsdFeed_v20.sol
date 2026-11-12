// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice On-chain fxUSD/USD quote from real Curve USDC/fxUSD EMA and
///         Chainlink USDC/USD; implements IPOR's IPriceFeed interface.
/// @dev This feed is NOT a constant-dollar peg or a mock. The FXUSD/USDC
///      StableSwap-NG EMA is expressed with 1e18 scaling. Chainlink's
///      observed Ethereum USDC/USD feed is 8 decimals. It deliberately
///      fails closed on missing or stale Chainlink data. Assess this
///      source's oracle manipulation and cross-protocol suitability
///      separately before a production vault deployment.
interface ICurveFxUsdEMA {
    function price_oracle(uint256 index) external view returns (uint256);
    function coins(uint256 index) external view returns (address);
}
interface IChainlinkUSDCUSD {
    function decimals() external view returns (uint8);
    function latestRoundData() external view returns (
        uint80 roundId,int256 answer,uint256 startedAt,uint256 updatedAt,uint80 answeredInRound
    );
}
contract CurveFxUSDChainlinkUsdFeed_v20 {
    address public immutable CURVE_POOL;
    address public immutable CHAINLINK_USDC_USD;
    address public immutable FXUSD;
    address public immutable USDC;
    uint256 public immutable MAX_CHAINLINK_AGE;

    error InvalidSource();
    error InvalidQuote();

    constructor(address curvePool_,address usdcUsdFeed_,address fxusd_,address usdc_,uint256 maxAge_) {
        if (curvePool_ == address(0)||usdcUsdFeed_ == address(0)||fxusd_ == address(0)
            ||usdc_ == address(0)||maxAge_ < 5 minutes||maxAge_ > 24 hours)
            revert InvalidSource();
        if (ICurveFxUsdEMA(curvePool_).coins(0) != usdc_
            || ICurveFxUsdEMA(curvePool_).coins(1) != fxusd_
            || IChainlinkUSDCUSD(usdcUsdFeed_).decimals() != 8) revert InvalidSource();
        CURVE_POOL=curvePool_;
        CHAINLINK_USDC_USD=usdcUsdFeed_;
        FXUSD=fxusd_;
        USDC=usdc_;
        MAX_CHAINLINK_AGE=maxAge_;
        _price();
    }
    function decimals() external pure returns (uint8) { return 8; }
    function latestRoundData() external view returns (
        uint80 roundId,int256 price,uint256 startedAt,uint256 updatedAt,uint80 answeredInRound
    ) {
        uint256 p;
        (p,roundId,startedAt,updatedAt,answeredInRound)=_price();
        if (p > uint256(type(int256).max)) revert InvalidQuote();
        return (roundId,int256(p),startedAt,updatedAt,answeredInRound);
    }
    function _price() private view returns (
        uint256 p,uint80 roundId,uint256 startedAt,uint256 updatedAt,uint80 answeredInRound
    ){
        int256 usdcUsd;
        (roundId,usdcUsd,startedAt,updatedAt,answeredInRound)=
            IChainlinkUSDCUSD(CHAINLINK_USDC_USD).latestRoundData();
        if (usdcUsd <= 0||updatedAt == 0||updatedAt > block.timestamp
            || block.timestamp - updatedAt > MAX_CHAINLINK_AGE
            || answeredInRound < roundId) revert InvalidQuote();
        uint256 fxusdPerUsdcEMA=ICurveFxUsdEMA(CURVE_POOL).price_oracle(0);
        // Confirm the EMA is positive, bounded (<= $20 / fxUSD), and
        // never silently replace depeg values with a synthetic $1.
        if (fxusdPerUsdcEMA==0||fxusdPerUsdcEMA > 20e18) revert InvalidQuote();
        p=fxusdPerUsdcEMA*uint256(usdcUsd)/1e18;
        if (p==0) revert InvalidQuote();
    }
}

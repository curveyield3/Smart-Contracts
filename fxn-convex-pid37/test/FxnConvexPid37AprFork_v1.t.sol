// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

interface IERC20Minimal {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IConvexBooster {
    function createVault(uint256 pid) external returns (address);
    function isShutdown() external view returns (bool);
}

interface IPoolRegistry {
    function poolInfo(uint256 pid)
        external
        view
        returns (address implementation, address gauge, address stakingToken, address rewards, uint8 active);
    function vaultMap(uint256 pid, address account) external view returns (address);
}

interface IConvexUserVault {
    function deposit(uint256 amount) external;
    function getReward() external;
    function owner() external view returns (address);
    function gaugeAddress() external view returns (address);
    function stakingToken() external view returns (address);
    function rewards() external view returns (address);
    function usingProxy() external view returns (address);
}

interface IFxnGauge {
    function stakingToken() external view returns (address);
    function totalSupply() external view returns (uint256);
    function workingSupply() external view returns (uint256);
    function workingBalanceOf(address account) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function getStakerVoteOwner(address account) external view returns (address);
    function getActiveRewardTokens() external view returns (address[] memory);
    function rewardData(address token)
        external
        view
        returns (uint96 queued, uint80 rate, uint40 lastUpdate, uint40 finishAt);
    function inflationParams() external view returns (uint192 rate, uint64 futureEpochTime);
}

interface IGaugeController {
    function gauge_relative_weight(address gauge, uint256 timestamp) external view returns (uint256);
}

interface IFxnToken {
    function rate() external view returns (uint256);
}

interface IFeeRegistry {
    function totalFees() external view returns (uint256);
    function getFeeDepositor(address from) external view returns (address);
}

interface IConvexPoolRewards {
    function rewardTokenLength() external view returns (uint256);
    function rewardState() external view returns (uint8);
}

interface IPoolUtilities {
    function poolRewardRatesById(uint256 pid)
        external
        view
        returns (address[] memory tokens, uint256[] memory rates);
    function poolBoostRatioById(uint256 pid) external view returns (uint256);
}

interface IFxSP {
    function nav() external view returns (uint256);
}

/// @notice Fork-only measurement of Convex f(x) PID 37.
/// @dev Creates a fresh personal Convex vault, deposits exactly 1 fxSP, advances
///      the fork clock by 24 hours, harvests through the real Convex vault, and
///      measures the FXN actually received by the depositor and fee recipient.
///      No transaction is broadcast to Ethereum.
contract FxnConvexPid37AprForkV1 is Test {
    uint256 internal constant PID = 37;
    uint256 internal constant ONE_FXSP = 1e18;
    uint256 internal constant ONE_DAY = 1 days;
    uint256 internal constant WEEK = 7 days;
    uint256 internal constant RATE_SCALE = 1e36;

    address internal constant BOOSTER = 0xAffe966B27ba3E4Ebb8A0eC124C7b7019CC762f8;
    address internal constant POOL_REGISTRY = 0xdB95d646012bB87aC2E6CD63eAb2C42323c1F5AF;
    address internal constant POOL_UTILITIES = 0x91B6D814a393e38e6Bfb9A155d043b30Fc9937b2;
    address internal constant FEE_REGISTRY = 0x4f258feCc91b2ff162cA702c2Bd9ABf2AF089611;
    address internal constant GAUGE_CONTROLLER = 0xe60eB8098B34eD775ac44B1ddE864e098C6d7f37;
    address internal constant CONVEX_PROXY = 0xd11a4Ee017cA0BECA8FA45fF2abFe9C6267b7881;

    address internal constant FXSP = 0x65C9A641afCEB9C0E6034e558A319488FA0FA3be;
    address internal constant FXN = 0x365AccFCa291e7D3914637ABf1F7635dB165Bb09;
    address internal constant EXPECTED_GAUGE = 0x215D87bd3c7482E2348338815E059DE07Daf798A;

    event FxnPid37AprMeasured(
        uint256 indexed forkBlock,
        uint256 startTimestamp,
        uint256 elapsedSeconds,
        uint256 depositFxsp,
        uint256 vaultWorkingBalance,
        uint256 gaugeWorkingSupply,
        uint256 fxnPriceUsdE8,
        uint256 fxspNavUsdE18,
        uint256 actualNetFxnWei,
        uint256 actualFeeFxnWei,
        uint256 actualGrossFxnWei,
        uint256 directExpectedGrossFxnWei,
        uint256 poolUtilitiesExpectedGrossFxnWei,
        uint256 actualNetAprBps,
        uint256 actualGrossAprBps,
        uint256 poolUtilitiesGrossAprBps,
        uint256 convexFeeBps,
        uint256 poolUtilitiesBoostRatioE18
    );

    function test_pid37_depositOneFxsp_pause24h_andHarvest() external {
        assertEq(block.chainid, 1, "must run against Ethereum mainnet fork");
        assertFalse(IConvexBooster(BOOSTER).isShutdown(), "Convex Booster is shut down");

        (address implementation, address gaugeAddress, address stakingToken, address rewardsAddress, uint8 active) =
            IPoolRegistry(POOL_REGISTRY).poolInfo(PID);

        assertEq(active, 1, "PID 37 is not active in PoolRegistry");
        assertEq(stakingToken, FXSP, "PID 37 is not the fxSP staking market");
        assertEq(gaugeAddress, EXPECTED_GAUGE, "unexpected PID 37 gauge");
        assertEq(IFxnGauge(gaugeAddress).stakingToken(), FXSP, "gauge staking token mismatch");
        assertEq(IERC20Minimal(FXSP).decimals(), 18, "unexpected fxSP decimals");

        uint256 fxnPriceUsdE8 = vm.envUint("FXN_USD_PRICE_E8");
        assertGt(fxnPriceUsdE8, 0, "FXN USD price unavailable");

        address user = address(0xF00D0037);
        vm.label(user, "Fork-only one-fxSP depositor");
        assertEq(IPoolRegistry(POOL_REGISTRY).vaultMap(PID, user), address(0), "test user already has a PID 37 vault");

        // Fund exactly one fxSP share on the fork only. No mainnet assets move.
        deal(FXSP, user, ONE_FXSP);
        assertEq(IERC20Minimal(FXSP).balanceOf(user), ONE_FXSP, "fork funding failed");

        address vault;
        vm.prank(user);
        vault = IConvexBooster(BOOSTER).createVault(PID);

        assertTrue(vault != address(0), "Convex vault creation failed");
        assertEq(IConvexUserVault(vault).owner(), user, "vault owner mismatch");
        assertEq(IConvexUserVault(vault).gaugeAddress(), gaugeAddress, "vault gauge mismatch");
        assertEq(IConvexUserVault(vault).stakingToken(), FXSP, "vault staking token mismatch");
        assertEq(IConvexUserVault(vault).rewards(), rewardsAddress, "vault extra-rewards contract mismatch");
        assertEq(IFxnGauge(gaugeAddress).getStakerVoteOwner(vault), CONVEX_PROXY, "Convex vote sharing not enabled");

        vm.prank(user);
        assertTrue(IERC20Minimal(FXSP).approve(vault, ONE_FXSP), "fxSP approval failed");
        vm.prank(user);
        IConvexUserVault(vault).deposit(ONE_FXSP);

        assertEq(IERC20Minimal(FXSP).balanceOf(user), 0, "deposit did not consume exactly one fxSP");
        assertEq(IFxnGauge(gaugeAddress).balanceOf(vault), ONE_FXSP, "gauge did not receive exactly one fxSP");

        uint256 startTimestamp = block.timestamp;
        uint256 startBlock = block.number;
        uint256 startWeek = (startTimestamp / WEEK) * WEEK;
        uint256 endTimestamp = startTimestamp + ONE_DAY;
        assertEq(endTimestamp / WEEK, startTimestamp / WEEK, "24-hour measurement crosses gauge weight week");

        uint256 fxspNavBefore = IFxSP(FXSP).nav();
        uint256 fxnUserBefore = IERC20Minimal(FXN).balanceOf(user);
        address feeRecipient = IFeeRegistry(FEE_REGISTRY).getFeeDepositor(IConvexUserVault(vault).usingProxy());
        uint256 fxnFeeBefore = IERC20Minimal(FXN).balanceOf(feeRecipient);

        (uint192 cachedFxnRate, uint64 futureEpochTime) = IFxnGauge(gaugeAddress).inflationParams();
        assertTrue(futureEpochTime == 0 || futureEpochTime > endTimestamp, "24-hour measurement crosses FXN rate epoch");

        uint256 gaugeWeight = IGaugeController(GAUGE_CONTROLLER).gauge_relative_weight(gaugeAddress, startWeek);
        uint256 gaugeWorkingSupply = IFxnGauge(gaugeAddress).workingSupply();
        uint256 vaultWorkingBalance = IFxnGauge(gaugeAddress).workingBalanceOf(vault);
        uint256 gaugeTotalSupply = IFxnGauge(gaugeAddress).totalSupply();
        uint256 poolUtilitiesBoostRatio = IPoolUtilities(POOL_UTILITIES).poolBoostRatioById(PID);

        assertGt(gaugeWeight, 0, "PID 37 has zero gauge weight");
        assertGt(cachedFxnRate, 0, "FXN gauge inflation rate is zero");
        assertGt(gaugeWorkingSupply, 0, "PID 37 working supply is zero");
        assertGt(vaultWorkingBalance, 0, "Convex vault has zero working balance");
        assertEq(gaugeTotalSupply, IFxnGauge(gaugeAddress).totalSupply(), "gauge supply changed unexpectedly");

        (address[] memory utilityTokens, uint256[] memory utilityRates) =
            IPoolUtilities(POOL_UTILITIES).poolRewardRatesById(PID);
        assertEq(utilityTokens.length, utilityRates.length, "PoolUtilities token/rate array mismatch");

        uint256 utilityFxnRate;
        for (uint256 i; i < utilityTokens.length; ++i) {
            if (utilityTokens[i] == FXN) utilityFxnRate += utilityRates[i];
        }
        assertGt(utilityFxnRate, 0, "PoolUtilities returned no FXN rate");

        // PID 37 currently has no additional Convex-side reward streams.
        assertEq(IConvexPoolRewards(rewardsAddress).rewardTokenLength(), 0, "PID 37 gained extra Convex reward tokens");

        // The gauge lists FXN as an extra-reward token, but its stream is currently zero.
        address[] memory gaugeRewardTokens = IFxnGauge(gaugeAddress).getActiveRewardTokens();
        for (uint256 i; i < gaugeRewardTokens.length; ++i) {
            (,, , uint40 finishAt) = IFxnGauge(gaugeAddress).rewardData(gaugeRewardTokens[i]);
            (, uint80 extraRate,,) = IFxnGauge(gaugeAddress).rewardData(gaugeRewardTokens[i]);
            if (gaugeRewardTokens[i] != FXN && extraRate > 0 && finishAt >= endTimestamp) {
                revert("unpriced non-FXN gauge reward is active");
            }
        }
        (, uint80 fxnExtraRate,, uint40 fxnExtraFinish) = IFxnGauge(gaugeAddress).rewardData(FXN);
        assertTrue(fxnExtraRate == 0 || fxnExtraFinish < endTimestamp, "FXN has a second active gauge reward stream");

        uint256 feeBps = IFeeRegistry(FEE_REGISTRY).totalFees();
        uint256 fxnPriceUsdE8Snapshot = fxnPriceUsdE8;

        // Pause the fork clock for 24 hours; this is not a real wait and cannot affect mainnet.
        vm.warp(endTimestamp);
        vm.roll(startBlock + (ONE_DAY / 12));

        // Harvest through the actual Convex user vault. This mints FXN via the
        // native f(x) gauge minter, claims gauge rewards, applies Convex's fee,
        // and forwards the remaining FXN to the vault owner.
        vm.prank(user);
        IConvexUserVault(vault).getReward();

        uint256 elapsed = block.timestamp - startTimestamp;
        uint256 fxnUserAfter = IERC20Minimal(FXN).balanceOf(user);
        uint256 fxnFeeAfter = IERC20Minimal(FXN).balanceOf(feeRecipient);
        uint256 actualNetFxn = fxnUserAfter - fxnUserBefore;
        uint256 actualFeeFxn = fxnFeeAfter - fxnFeeBefore;
        uint256 actualGrossFxn = actualNetFxn + actualFeeFxn;

        // Independent reconstruction of the native gauge's own integral:
        // reward = cached rate * weekly gauge weight * elapsed * user working
        // balance / (1e18 * gauge working supply).
        uint256 directExpectedGrossFxn =
            (uint256(cachedFxnRate) * gaugeWeight * elapsed * vaultWorkingBalance)
                / (1e18 * gaugeWorkingSupply);

        // PoolUtilities rates are 1e36-scaled per-deposit FXN/second values.
        uint256 poolUtilitiesExpectedGrossFxn = (utilityFxnRate * ONE_FXSP * elapsed) / RATE_SCALE;

        uint256 fxspNavAfter = IFxSP(FXSP).nav();
        uint256 actualNetAprBps = _aprBps(actualNetFxn, ONE_FXSP, elapsed, fxnPriceUsdE8Snapshot, fxspNavBefore);
        uint256 actualGrossAprBps = _aprBps(actualGrossFxn, ONE_FXSP, elapsed, fxnPriceUsdE8Snapshot, fxspNavBefore);
        uint256 poolUtilitiesGrossAprBps =
            _aprBps(poolUtilitiesExpectedGrossFxn, ONE_FXSP, elapsed, fxnPriceUsdE8Snapshot, fxspNavBefore);
        uint256 directGaugeGrossAprBps =
            _aprBps(directExpectedGrossFxn, ONE_FXSP, elapsed, fxnPriceUsdE8Snapshot, fxspNavBefore);

        uint256 directDiff = actualGrossFxn > directExpectedGrossFxn
            ? actualGrossFxn - directExpectedGrossFxn
            : directExpectedGrossFxn - actualGrossFxn;
        uint256 directDiffBps = directExpectedGrossFxn == 0 ? 0 : (directDiff * 10_000) / directExpectedGrossFxn;
        uint256 utilityToActualBps =
            actualGrossFxn == 0 ? 0 : (poolUtilitiesExpectedGrossFxn * 10_000) / actualGrossFxn;
        uint256 actualFeeShareBps = actualGrossFxn == 0 ? 0 : (actualFeeFxn * 10_000) / actualGrossFxn;

        console2.log("FORK_BLOCK", startBlock);
        console2.log("PID", PID);
        console2.log("DEPOSIT_FXSP_WEI", ONE_FXSP);
        console2.log("ELAPSED_SECONDS", elapsed);
        console2.log("FXN_PRICE_USD_E8", fxnPriceUsdE8Snapshot);
        console2.log("FXSP_NAV_BEFORE_E18", fxspNavBefore);
        console2.log("FXSP_NAV_AFTER_E18", fxspNavAfter);
        console2.log("GAUGE_WEIGHT_E18", gaugeWeight);
        console2.log("FXN_CACHED_RATE_WEI_PER_SECOND", uint256(cachedFxnRate));
        console2.log("GAUGE_WORKING_SUPPLY", gaugeWorkingSupply);
        console2.log("VAULT_WORKING_BALANCE", vaultWorkingBalance);
        console2.log("VAULT_WORKING_RATIO_BPS", (vaultWorkingBalance * 10_000) / ONE_FXSP);
        console2.log("VAULT_BOOST_VS_40_PERCENT_BPS", (vaultWorkingBalance * 10_000) / (ONE_FXSP * 40 / 100));
        console2.log("POOL_UTILITIES_BOOST_RATIO_E18", poolUtilitiesBoostRatio);
        console2.log("CONVEX_TOTAL_FEE_BPS", feeBps);
        console2.log("POOL_UTILITIES_FXN_RATE_RAW", utilityFxnRate);
        console2.log("ACTUAL_NET_FXN_WEI", actualNetFxn);
        console2.log("ACTUAL_FEE_FXN_WEI", actualFeeFxn);
        console2.log("ACTUAL_GROSS_FXN_WEI", actualGrossFxn);
        console2.log("DIRECT_GAUGE_EXPECTED_GROSS_FXN_WEI", directExpectedGrossFxn);
        console2.log("POOL_UTILITIES_EXPECTED_GROSS_FXN_WEI", poolUtilitiesExpectedGrossFxn);
        console2.log("DIRECT_GAUGE_GROSS_APR_BPS", directGaugeGrossAprBps);
        console2.log("ACTUAL_GROSS_APR_BPS", actualGrossAprBps);
        console2.log("ACTUAL_NET_APR_BPS", actualNetAprBps);
        console2.log("POOL_UTILITIES_GROSS_APR_BPS", poolUtilitiesGrossAprBps);
        console2.log("DIRECT_RECONCILIATION_DIFF_BPS", directDiffBps);
        console2.log("POOL_UTILITIES_TO_ACTUAL_GROSS_BPS", utilityToActualBps);
        console2.log("ACTUAL_FEE_SHARE_BPS", actualFeeShareBps);

        emit FxnPid37AprMeasured(
            startBlock,
            startTimestamp,
            elapsed,
            ONE_FXSP,
            vaultWorkingBalance,
            gaugeWorkingSupply,
            fxnPriceUsdE8Snapshot,
            fxspNavBefore,
            actualNetFxn,
            actualFeeFxn,
            actualGrossFxn,
            directExpectedGrossFxn,
            poolUtilitiesExpectedGrossFxn,
            actualNetAprBps,
            actualGrossAprBps,
            poolUtilitiesGrossAprBps,
            feeBps,
            poolUtilitiesBoostRatio
        );

        assertGt(actualGrossFxn, 0, "24-hour harvest produced no FXN");
        assertGt(actualNetFxn, 0, "depositor received no net FXN");
        assertTrue(feeRecipient != address(0), "Convex fee recipient is unset");
        assertEq(actualGrossFxn, actualNetFxn + actualFeeFxn, "gross reward reconciliation failed");

        // The real harvested amount is the authoritative result. A mismatch
        // against PoolUtilities is intentionally reported, not hidden by an
        // assertion that would prevent the measured APR from being emitted.
        console2.log("POOL_UTILITIES_RATE_MATCHES_HARVEST", utilityToActualBps >= 9_900 && utilityToActualBps <= 10_100);
        console2.log("NATIVE_GAUGE_MATCHES_HARVEST", directDiffBps <= 10);
    }

    function _aprBps(
        uint256 rewardFxnWei,
        uint256 depositFxspWei,
        uint256 elapsedSeconds,
        uint256 fxnPriceUsdE8,
        uint256 fxspNavUsdE18
    ) internal pure returns (uint256) {
        if (rewardFxnWei == 0 || depositFxspWei == 0 || elapsedSeconds == 0 || fxspNavUsdE18 == 0) return 0;
        return (
            rewardFxnWei * fxnPriceUsdE8 * 1e18 * 365 days * 10_000
                / (depositFxspWei * fxspNavUsdE18 * 1e8 * elapsedSeconds)
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

interface IToken {
    function balanceOf(address) external view returns (uint256);
    function approve(address,uint256) external returns (bool);
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
}
interface IBooster {
    function createVault(uint256) external returns (address);
    function isShutdown() external view returns (bool);
}
interface IRegistry {
    function poolInfo(uint256) external view returns (address,address,address,address,uint8);
    function vaultMap(uint256,address) external view returns (address);
}
interface IConvexVault {
    function deposit(uint256) external;
    function getReward() external;
    function owner() external view returns (address);
    function gaugeAddress() external view returns (address);
    function usingProxy() external view returns (address);
}
interface IGauge {
    function deposit(uint256) external;
    function claim() external;
    function minter() external view returns (address);
    function stakingToken() external view returns (address);
    function workingBalanceOf(address) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function workingSupply() external view returns (uint256);
    function getStakerVoteOwner(address) external view returns (address);
    function integrate_fraction(address) external view returns (uint256);
}
interface IMinter {
    function mint(address) external;
    function minted(address,address) external view returns (uint256);
}
interface IFee {
    function totalFees() external view returns (uint256);
    function getFeeDepositor(address) external view returns (address);
}
interface IFxsp {
    function nav() external view returns (uint256);
}
interface IFxSave {
    function asset() external view returns (address);
    function vault() external view returns (address);
    function harvester() external view returns (address);
    function gauge() external view returns (address);
    function getThreshold() external view returns (uint256);
    function deposit(uint256,address) external returns (uint256);
    function previewRedeem(uint256) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function harvest() external;
    function nav() external view returns (uint256);
}

contract FxStabilityAprComparisonV6 is Test {
    uint256 internal constant ONE_FXSP = 1e18;
    uint256 internal constant YEAR = 365 days;
    uint256 internal constant FEE_DENOM = 10000;

    address internal constant FXSP = 0x65C9A641afCEB9C0E6034e558A319488FA0FA3be;
    address internal constant FXN = 0x365AccFCa291e7D3914637ABf1F7635dB165Bb09;
    address internal constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal constant FX_SAVE = 0x7743e50F534a7f9F1791DdE7dCD89F7783Eefc39;
    address internal constant GAUGE_WST = 0xEd92dDe3214c24Ae04F5f96927E3bE8f8DbC3289;
    address internal constant GAUGE_FXN = 0x215D87bd3c7482E2348338815E059DE07Daf798A;
    address internal constant BOOSTER = 0xAffe966B27ba3E4Ebb8A0eC124C7b7019CC762f8;
    address internal constant REGISTRY = 0xdB95d646012bB87aC2E6CD63eAb2C42323c1F5AF;
    address internal constant FEES = 0x4f258feCc91b2ff162cA702c2Bd9ABf2AF089611;
    address internal constant CONVEX_PROXY = 0xd11a4Ee017cA0BECA8FA45fF2abFe9C6267b7881;

    // Modes: 1=Convex FXN, 2=native FXN, 3=native wstETH, 4=fxSAVE.
    // Every mode starts with precisely 1.0 fxSP deposited; forks are isolated.
    // FXSAVE: actual ERC4626 deposit of 1 fxSP. At the current 100 fxSP
    // batching threshold it sits idle; existing staked share exposure remains
    // pro-rata. Harvested reward tokens go to an off-chain swap harvester
    // and do NOT compound into fxSAVE shares without an external swap.
    function test_fourPositions_threePeriods() external {
        assertEq(block.chainid, 1, "Ethereum fork required");
        assertFalse(IBooster(BOOSTER).isShutdown(), "Convex shutdown");
        assertEq(IToken(FXSP).decimals(), 18, "fxSP decimals");
        assertEq(IFxSave(FX_SAVE).asset(), FXSP, "fxSAVE asset not fxSP");
        assertEq(IFxSave(FX_SAVE).gauge(), GAUGE_WST, "fxSAVE gauge changed");

        ( , address cg, address ct, , uint8 ca) = IRegistry(REGISTRY).poolInfo(37);
        assertEq(ca, 1, "Convex PID37 inactive");
        assertEq(cg, GAUGE_FXN, "Convex PID37 gauge changed");
        assertEq(ct, FXSP, "Convex PID37 staking asset changed");
        assertEq(IGauge(GAUGE_FXN).stakingToken(), FXSP, "native FXN gauge token");
        assertEq(IGauge(GAUGE_WST).stakingToken(), FXSP, "native wst gauge token");

        uint256 fxnUsdE8 = vm.envUint("FXN_USD_PRICE_E8");
        uint256 wstUsdE8 = vm.envUint("WSTETH_USD_PRICE_E8");
        assertGt(fxnUsdE8, 0, "zero FXN quote");
        assertGt(wstUsdE8, 0, "zero wstETH quote");

        uint256 originalTimestamp = this.chainClock();
        uint256 originalBlock = block.number;
        uint256 root = vm.snapshotState();
        for (uint256 mode = 1; mode <= 4; ++mode) {
            for (uint256 i = 0; i < 3; ++i) {
                assertTrue(vm.revertToState(root), "fork rollback failed");
                root = vm.snapshotState();
                // Restore the exact same starting chain time for every run.
                vm.warp(originalTimestamp);
                vm.roll(originalBlock);
                uint256 duration = i == 0 ? 1 hours : i == 1 ? 1 days : 3 days;
                _simulate(mode, duration, fxnUsdE8, wstUsdE8);
            }
        }
    }

    function chainClock() external view returns (uint256) {
        return block.timestamp;
    }

    function _simulate(uint256 mode, uint256 duration, uint256 fxnPrice, uint256 wstPrice) internal {
        address user = address(uint160(0xF000000000 + mode * 100 + duration));
        address keeper = address(0xF00D00D);
        vm.label(user, "One fxSP fork depositor");
        uint256 navStart = IFxsp(FXSP).nav();
        uint256 tsBefore = this.chainClock();
        uint256 blockBefore = block.number;

        // FXSAVE's harvest moves rewards to a separate real harvester but
        // does not reinvest them. Clear historical pending reward balances
        // BEFORE making the new deposit to isolate only the chosen period.
        if (mode == 4) {
            vm.prank(keeper);
            IFxSave(FX_SAVE).harvest();
        }

        deal(FXSP, user, ONE_FXSP);
        assertEq(IToken(FXSP).balanceOf(user), ONE_FXSP, "must fund exactly 1 fxSP");

        address feeRecipient = address(0);
        address saveHarvester = address(0);
        uint256 saveShares = 0;
        uint256 saveConvertStart = 0;
        uint256 saveTotalSupply = 0;
        uint256 gaugeWorking = 0;
        uint256 fxnBefore = IToken(FXN).balanceOf(user);
        uint256 wstBefore = IToken(WSTETH).balanceOf(user);
        uint256 feeBefore = 0;
        uint256 harvesterFxnBefore = 0;
        uint256 harvesterWstBefore = 0;

        if (mode == 1) {
            assertEq(IRegistry(REGISTRY).vaultMap(37, user), address(0), "user already has Convex vault");
            vm.prank(user);
            address vault = IBooster(BOOSTER).createVault(37);
            assertEq(IConvexVault(vault).owner(), user, "Convex owner mismatch");
            assertEq(IConvexVault(vault).gaugeAddress(), GAUGE_FXN, "Convex gauge mismatch");
            assertEq(IGauge(GAUGE_FXN).getStakerVoteOwner(vault), CONVEX_PROXY, "Convex vote sharing missing");
            vm.prank(user);
            assertTrue(IToken(FXSP).approve(vault, ONE_FXSP), "Convex approval failed");
            vm.prank(user);
            IConvexVault(vault).deposit(ONE_FXSP);
            assertEq(IGauge(GAUGE_FXN).balanceOf(vault), ONE_FXSP, "Convex gauge did not stake 1 fxSP");
            gaugeWorking = IGauge(GAUGE_FXN).workingBalanceOf(vault);
            feeRecipient = IFee(FEES).getFeeDepositor(IConvexVault(vault).usingProxy());
            feeBefore = IToken(FXN).balanceOf(feeRecipient);
        } else if (mode == 2 || mode == 3) {
            address gauge = mode == 2 ? GAUGE_FXN : GAUGE_WST;
            vm.prank(user);
            assertTrue(IToken(FXSP).approve(gauge, ONE_FXSP), "native gauge approval failed");
            vm.prank(user);
            IGauge(gauge).deposit(ONE_FXSP);
            assertEq(IGauge(gauge).balanceOf(user), ONE_FXSP, "native gauge did not stake 1 fxSP");
            gaugeWorking = IGauge(gauge).workingBalanceOf(user);
        } else {
            assertEq(mode, 4, "unknown mode");
            assertEq(IFxSave(FX_SAVE).getThreshold(), 100e18, "fxSAVE batch threshold changed");
            vm.prank(user);
            assertTrue(IToken(FXSP).approve(FX_SAVE, ONE_FXSP), "fxSAVE approval failed");
            vm.prank(user);
            saveShares = IFxSave(FX_SAVE).deposit(ONE_FXSP, user);
            assertGt(saveShares, 0, "fxSAVE minted zero shares");
            saveConvertStart = IFxSave(FX_SAVE).previewRedeem(saveShares);
            saveTotalSupply = IFxSave(FX_SAVE).totalSupply();
            saveHarvester = IFxSave(FX_SAVE).harvester();
            assertTrue(saveHarvester != address(0), "fxSAVE harvester absent");
            harvesterFxnBefore = IToken(FXN).balanceOf(saveHarvester);
            harvesterWstBefore = IToken(WSTETH).balanceOf(saveHarvester);
            // fxSAVE's own Convex vault is already staked via PID36.
            gaugeWorking = IGauge(GAUGE_WST).workingBalanceOf(IFxSave(FX_SAVE).vault());
        }
        assertEq(IToken(FXSP).balanceOf(user), 0, "exactly one fxSP must leave wallet");

        uint256 endTimestamp = tsBefore + duration;
        vm.warp(endTimestamp);
        vm.roll(blockBefore + duration / 12);
        // Read timestamp from a distinct external EVM context, rather than
        // relying on optimizer-cached block.timestamp after the cheatcode.
        assertEq(this.chainClock(), endTimestamp, "fork clock advance failed");

        if (mode == 1) {
            address vault = IRegistry(REGISTRY).vaultMap(37, user);
            vm.prank(user);
            IConvexVault(vault).getReward();
        } else if (mode == 2 || mode == 3) {
            address gauge = mode == 2 ? GAUGE_FXN : GAUGE_WST;
            vm.prank(user);
            IGauge(gauge).claim();
            vm.prank(user);
            IMinter(IGauge(gauge).minter()).mint(gauge);
            console2.log("NATIVE_MINTED_TOTAL_FXN_WEI", IMinter(IGauge(gauge).minter()).minted(user, gauge));
            console2.log("NATIVE_GAUGE_INTEGRATE_FXN_WEI", IGauge(gauge).integrate_fraction(user));
        } else {
            vm.prank(keeper);
            IFxSave(FX_SAVE).harvest();
        }

        uint256 userFxn = IToken(FXN).balanceOf(user) - fxnBefore;
        uint256 userWst = IToken(WSTETH).balanceOf(user) - wstBefore;
        uint256 feeFxn = mode == 1 ? IToken(FXN).balanceOf(feeRecipient) - feeBefore : 0;
        uint256 pooledFxn = mode == 4 ? IToken(FXN).balanceOf(saveHarvester) - harvesterFxnBefore : 0;
        uint256 pooledWst = mode == 4 ? IToken(WSTETH).balanceOf(saveHarvester) - harvesterWstBefore : 0;

        uint256 actualFxn = userFxn;
        uint256 actualWst = userWst;
        if (mode == 4) {
            // Pro-rata reward entitlement of the newly minted fxSAVE shares
            // from the real pool harvest. This is accrued income awaiting
            // an external swap/onHarvest; it is NOT earned fxSP NAV.
            actualFxn = pooledFxn * saveShares / saveTotalSupply;
            actualWst = pooledWst * saveShares / saveTotalSupply;
        }

        uint256 effectiveAprBps = _aprBps(actualFxn, actualWst, navStart, duration, fxnPrice, wstPrice);
        uint256 convexGrossAprBps = mode == 1 ?
            _aprBps(userFxn + feeFxn, userWst, navStart, duration, fxnPrice, wstPrice) : 0;
        uint256 saveRedeemEnd = mode == 4 ? IFxSave(FX_SAVE).previewRedeem(saveShares) : 0;
        uint256 navEnd;
        bool navEndVerified;
        try IFxsp(FXSP).nav() returns (uint256 observedNav) {
            navEnd = observedNav;
            navEndVerified = true;
        } catch {
            // The real oracle may expire during a 3-day time-warp because
            // Chainlink feeds do not receive fresh updates on the static fork.
            // This must not invalidate already-collected actual reward balances.
            navEnd = 0;
            navEndVerified = false;
        }
        uint256 shareChangeBps = mode == 4 && saveConvertStart != 0 && saveRedeemEnd >= saveConvertStart
            ? (saveRedeemEnd - saveConvertStart) * 10000 / saveConvertStart
            : 0;

        console2.log("=== APR_RESULT_START ===");
        console2.log("MODE", mode);
        console2.log("PERIOD_SECONDS", duration);
        console2.log("FORK_BLOCK", blockBefore);
        console2.log("START_TIMESTAMP", tsBefore);
        console2.log("END_TIMESTAMP", this.chainClock());
        console2.log("DEPOSIT_FXSP_WEI", ONE_FXSP);
        console2.log("FXN_PRICE_USD_E8", fxnPrice);
        console2.log("WSTETH_PRICE_USD_E8", wstPrice);
        console2.log("FXSP_NAV_START_E18", navStart);
        console2.log("FXSP_NAV_END_E18", navEnd);
        console2.log("FXSP_NAV_END_VERIFIED", navEndVerified);
        console2.log("GAUGE_WORKING_BALANCE", gaugeWorking);
        console2.log("USER_FXN_WEI", userFxn);
        console2.log("USER_WSTETH_WEI", userWst);
        console2.log("CONVEX_FEE_FXN_WEI", feeFxn);
        console2.log("POOL_HARVEST_FXN_WEI", pooledFxn);
        console2.log("POOL_HARVEST_WSTETH_WEI", pooledWst);
        console2.log("ATTRIBUTABLE_FXN_WEI", actualFxn);
        console2.log("ATTRIBUTABLE_WSTETH_WEI", actualWst);
        console2.log("INCENTIVE_APR_BPS", effectiveAprBps);
        console2.log("CONVEX_GROSS_APR_BPS", convexGrossAprBps);
        console2.log("FXSAVE_MINTED_SHARES", saveShares);
        console2.log("FXSAVE_CONVERT_START_FXSP_WEI", saveConvertStart);
        console2.log("FXSAVE_CONVERT_END_FXSP_WEI", saveRedeemEnd);
        console2.log("FXSAVE_SHARE_CHANGE_BPS", shareChangeBps);
        console2.log("=== APR_RESULT_END ===");

        if (mode == 4) {
            assertGt(saveShares, 0, "fxSAVE deposit failed");
            // fxSAVE external swaps are intentionally not fabricated;
            // the measured claim is the actual reward sent to harvester.
        } else if (mode == 1) {
            assertGt(userFxn, 0, "Convex FXN harvest produced zero FXN");
        } else if (mode == 2) {
            console2.log("NATIVE_ZERO_FXN_FLAG", userFxn == 0);
        } else {
            assertGt(userWst + userFxn, 0, "native wst gauge harvest produced no rewards");
        }
        assertGt(gaugeWorking, 0, "zero gauge working balance");
    }

    function _aprBps(
        uint256 fxnWei,
        uint256 wstWei,
        uint256 fxspNavE18,
        uint256 secondsElapsed,
        uint256 fxnPriceE8,
        uint256 wstPriceE8
    ) internal pure returns (uint256) {
        // 1 fxSP = fxspNavE18 USD-denominated wei. Both reward tokens
        // are 18-decimal. Prices have eight USD decimals.
        uint256 rewardUsdE8 = fxnWei * fxnPriceE8 / 1e18 + wstWei * wstPriceE8 / 1e18;
        uint256 depositUsdE8 = fxspNavE18 * 1e8 / 1e18;
        if (depositUsdE8 == 0 || secondsElapsed == 0) return 0;
        return rewardUsdE8 * YEAR * 10000 / (depositUsdE8 * secondsElapsed);
    }
}

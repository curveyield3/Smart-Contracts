// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// All writes in this file occur only on a Foundry Ethereum mainnet fork.
// Snapshots and failed-call evidence survive in simulation-output/ as GitHub Actions artifacts.
// A PASS for an expected revert means the *tested* guard reverted with no accounting-state change.
// This focused suite is a starting slice; it is NOT a claim that all vault ABI selectors are tested.

import {Vm} from "forge-std/Vm.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {FuseAction} from "../../contracts/interfaces/IPlasmaVault.sol";
import {FXMintBorrowFuse} from "../../contracts/fuses/fxmint/FXMintBorrowFuse.sol";
import {FXMintCollateralFuse} from "../../contracts/fuses/fxmint/FXMintCollateralFuse.sol";
import {FXMintBalanceFuse} from "../../contracts/fuses/fxmint/FXMintBalanceFuse.sol";
import {FXMintLTVManager} from "../../contracts/fuses/fxmint/FXMintLTVManager.sol";
import {FulfillWithdrawExecutor} from "../../contracts/executors/FulfillWithdrawExecutor.sol";
import {FxSPSupplyFuse} from "../../contracts/fuses/fxsp/FxSPSupplyFuse.sol";
import {FxSPCurveBalanceFuse} from "../../contracts/fuses/fxsp/FxSPCurveBalanceFuse.sol";
import {ConvexFXGaugeSupplyFuse} from "../../contracts/fuses/convex/ConvexFXGaugeSupplyFuse.sol";
import {ConvexFXGaugeBalanceFuse} from "../../contracts/fuses/convex/ConvexFXGaugeBalanceFuse.sol";
import {FXNPriceFeedEthereum} from "../../contracts/price_oracle/price_feed/FXNPriceFeedEthereum_v1.sol";

interface IFxMintPositionFork {
    function getPosition(uint256) external view returns (uint256, uint256);
    function priceOracle() external view returns (address);
}
interface IFxMintPriceFork {
    function getExchangePrice() external view returns (uint256);
}
interface IWithdrawalRequestFork {
    function requestShares(uint256) external;
    function requestInfo(address) external view returns (uint256, uint256, bool, uint256);
    function getSharesToRelease() external view returns (uint256);
}


interface ICurveYieldRouterFork {
    struct Oracle {
        address oracleAddress;
        bytes4 readFunctionID;
        bytes requiredInputs;
        bool invert;
        uint8 rateDecimals;
    }
    struct Hop {
        uint16 poolType;
        address tokenOut;
        address swapContract;
        bytes32 poolId;
        bytes poolData;
        Oracle oracle;
    }
    function setRoute(address tokenIn, address tokenOut, Hop[] calldata pathway) external;
    function routeLength(address tokenIn, address tokenOut) external view returns (uint256);
}

contract CyWBTCLTVManagerV4QualificationV1 {
    using Math for uint256;
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    address private constant VAULT = address(bytes20(hex"45849ce33dd49db664d37af44d0e0aa3d3dd61de"));
    address private constant OWNER = address(bytes20(hex"47623c62f281807d615eeb4a2ceee9d97f9d3c49"));
    address private constant ACCESS = address(bytes20(hex"63de0303fddf536c775c1006b8c8395333658b3f"));
    address private constant PRICE_MANAGER = address(bytes20(hex"f6b4484a3e1d727059a930ed9972e125bf8d6901"));
    address private constant WITHDRAW_MANAGER = address(bytes20(hex"bd48c3b8e4368dc97c27b2206a6c79fa3c9e16b8"));
    address private constant FEE_MANAGER = address(bytes20(hex"3be66678baac9ec9f2514a2e31b18a186173c15c"));

    address private constant WBTC = address(bytes20(hex"2260fac5e5542a773aa44fbcfedf7c193bc2c599"));
    address private constant FXUSD = address(bytes20(hex"085780639cc2cacd35e474e71f4d000e2405d8f6"));
    address private constant FXN = address(bytes20(hex"365accfca291e7d3914637abf1f7635db165bb09"));
    address private constant FXSP = address(bytes20(hex"65c9a641afceb9c0e6034e558a319488fa0fa3be"));
    address private constant USDC = address(bytes20(hex"a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"));
    address private constant FXMINT_POOL = address(bytes20(hex"ab709e26fa6b0a30c119d8c55b887ded24952473"));
    address private constant POOL_MANAGER = address(bytes20(hex"250893ca4ba5d05626c785e8da758026928fcd24"));
    address private constant BOOSTER = address(bytes20(hex"affe966b27ba3e4ebb8a0ec124c7b7019cc762f8"));
    address private constant REGISTRY = address(bytes20(hex"db95d646012bb87ac2e6cd63eab2c42323c1f5af"));
    address private constant GAUGE = address(bytes20(hex"215d87bd3c7482e2348338815e059de07daf798a"));
    address private constant OMNI = address(bytes20(hex"a4a533025fef8d3446e7cb8a434824e1ee865b00"));
    address private constant OMNI_FUSE = address(bytes20(hex"a301d6f34f2c8399e8564681cf675999cc1f1584"));
    address private constant ERC20_BALANCE_FUSE = address(bytes20(hex"6cebf3e3392d0860ed174402884b941dcbb30654"));
    address private constant ZERO_BALANCE_FUSE = address(bytes20(hex"e9562d7bd06b43e6391c5be4b3c5f5c2bc1e06bf"));
    address private constant USD_FEED = address(bytes20(hex"02b2f2809ce74563cb4b2eca1adafb188e4ed8d7"));
    address private constant WBTC_FUNDING_HOLDER = address(bytes20(hex"7f86bf177dd4f3494b841a37e810a34dd56c829b"));
    address private constant CURVE_USDC_FXUSD = address(bytes20(hex"5018be882dcce5e3f2f3b0913ae2096b9b3fb61f"));
    address private constant UNIV3_USDC_WBTC = address(bytes20(hex"9a772018fbd77fcd2d25657e5c547baff3fd7d16"));
    address private constant USER = address(0xB001);
    address private constant USER2 = address(0xB004);
    address private constant PUBLIC_CALLER = address(0xB002);
    address private constant UNAUTHORIZED = address(0xB003);
    uint256 private constant TARGET = 6e17;
    uint256 private simulatedPriceShiftBeforeFinalizeBps;

    FXMintBalanceFuse private balanceFuse;
    FXMintBorrowFuse private borrowFuse;
    FXMintCollateralFuse private collateralFuse;
    FXMintLTVManager private ltvManager;
    FulfillWithdrawExecutor private executor;
    FxSPSupplyFuse private fxspFuse;
    FxSPCurveBalanceFuse private fxspBalance;
    ConvexFXGaugeSupplyFuse private convexFuse;
    ConvexFXGaugeBalanceFuse private convexBalance;
    FXNPriceFeedEthereum private fxnFeed;

    struct FeeRecipientFork { address recipient; uint256 feeValue; }

    struct State {
        uint256 totalAssets;
        uint256 totalSupply;
        uint256 wbtcIdle;
        uint256 fxusdIdle;
        uint256 usdcIdle;
        uint256 fxnIdle;
        uint256 fxspIdle;
        uint256 gaugeStakedShares;
        uint256 fxspNavWad;
        uint256 userShares;
        uint256 userWBTC;
        uint256 user2Shares;
        uint256 user2WBTC;
        uint256 positionId;
        uint256 rawCollateral;
        uint256 rawDebt;
        uint256 managerLtv;
        uint256 sharesReserved;
    }

    error CallOutcomeMismatch(string label, bool expected, bool actual);

    function setUp() public {
        require(block.chainid == 1, "Requires Ethereum mainnet fork");
        vm.createDir("simulation-output", true);
        require(VAULT.code.length > 0 && FXMINT_POOL.code.length > 0
            && WITHDRAW_MANAGER.code.length > 0 && WBTC.code.length > 0, "Real protocol code missing");
    }

    function _state() private view returns (State memory s) {
        s.totalAssets = IERC4626(VAULT).totalAssets();
        s.totalSupply = IERC20(VAULT).totalSupply();
        s.wbtcIdle = IERC20(WBTC).balanceOf(VAULT);
        s.fxusdIdle = IERC20(FXUSD).balanceOf(VAULT);
        s.usdcIdle = IERC20(USDC).balanceOf(VAULT);
        s.fxnIdle = IERC20(FXN).balanceOf(VAULT);
        s.fxspIdle = IERC20(FXSP).balanceOf(VAULT);
        (bool regOk, bytes memory childData) = REGISTRY.staticcall(
            abi.encodeWithSignature("vaultMap(uint256,address)", uint256(37), VAULT));
        if (regOk && childData.length == 32) {
            address child = abi.decode(childData, (address));
            if (child != address(0)) s.gaugeStakedShares = IERC20(GAUGE).balanceOf(child);
        }
        (bool navOk, bytes memory navData) = FXSP.staticcall(abi.encodeWithSignature("nav()"));
        if (navOk && navData.length >= 32) s.fxspNavWad = abi.decode(navData, (uint256));
        s.userShares = IERC20(VAULT).balanceOf(USER);
        s.userWBTC = IERC20(WBTC).balanceOf(USER);
        s.user2Shares = IERC20(VAULT).balanceOf(USER2);
        s.user2WBTC = IERC20(WBTC).balanceOf(USER2);
        s.sharesReserved = IWithdrawalRequestFork(WITHDRAW_MANAGER).getSharesToRelease();
        if (address(balanceFuse) != address(0)) {
            s.positionId = balanceFuse.positionId();
            if (s.positionId != 0) {
                (s.rawCollateral, s.rawDebt) = IFxMintPositionFork(FXMINT_POOL).getPosition(s.positionId);
                uint256 price = IFxMintPriceFork(IFxMintPositionFork(FXMINT_POOL).priceOracle()).getExchangePrice();
                uint256 collateralUsd = Math.mulDiv(s.rawCollateral, price, 1e18);
                s.managerLtv = collateralUsd == 0 ? (s.rawDebt > 0 ? type(uint256).max : 0)
                    : Math.mulDiv(s.rawDebt, 1e18, collateralUsd, Math.Rounding.Up);
            }
        }
    }

    function _snapshot(string memory stage) private {
        State memory s = _state();
        string memory k = string.concat("cywbtc_", stage);
        vm.serializeString(k, "stage", stage);
        vm.serializeUint(k, "chainId", block.chainid);
        vm.serializeUint(k, "blockNumber", block.number);
        vm.serializeUint(k, "timestamp", block.timestamp);
        vm.serializeUint(k, "totalAssetsWBTC", s.totalAssets);
        vm.serializeUint(k, "totalSupplyShares", s.totalSupply);
        vm.serializeUint(k, "vaultIdleWBTC", s.wbtcIdle);
        vm.serializeUint(k, "vaultIdleFXUSD", s.fxusdIdle);
        vm.serializeUint(k, "vaultIdleUSDC", s.usdcIdle);
        vm.serializeUint(k, "vaultIdleFXN", s.fxnIdle);
        vm.serializeUint(k, "vaultIdleFXSP", s.fxspIdle);
        vm.serializeUint(k, "convexPersonalGaugeFxspShares", s.gaugeStakedShares);
        vm.serializeUint(k, "fxspNavWad", s.fxspNavWad);
        vm.serializeUint(k, "userShares", s.userShares);
        vm.serializeUint(k, "userWBTC", s.userWBTC);
        vm.serializeUint(k, "user2Shares", s.user2Shares);
        vm.serializeUint(k, "user2WBTC", s.user2WBTC);
        vm.serializeUint(k, "fxMintPositionId", s.positionId);
        vm.serializeUint(k, "fxMintRawCollateral", s.rawCollateral);
        vm.serializeUint(k, "fxMintRawDebt", s.rawDebt);
        vm.serializeUint(k, "fxMintLtvWad", s.managerLtv);
        vm.serializeUint(k, "releasedSharesReserved", s.sharesReserved);
        if (address(ltvManager) != address(0)) vm.serializeUint(k, "targetLtvWad", ltvManager.targetLtvWad());
        string memory json = vm.serializeString(k, "forkEvidence", "local Foundry Ethereum fork, no mainnet writes");
        vm.writeJson(json, string.concat("simulation-output/state_", stage, ".json"));
    }

    function _sameAccounting(State memory a, State memory b) private pure returns (bool) {
        return a.totalAssets == b.totalAssets && a.totalSupply == b.totalSupply
            && a.wbtcIdle == b.wbtcIdle && a.fxusdIdle == b.fxusdIdle
            && a.usdcIdle == b.usdcIdle && a.fxnIdle == b.fxnIdle && a.fxspIdle == b.fxspIdle
            && a.gaugeStakedShares == b.gaugeStakedShares
            && a.userShares == b.userShares && a.userWBTC == b.userWBTC
            && a.user2Shares == b.user2Shares && a.user2WBTC == b.user2WBTC
            && a.positionId == b.positionId && a.rawCollateral == b.rawCollateral
            && a.rawDebt == b.rawDebt && a.sharesReserved == b.sharesReserved;
    }

    struct CallEvidence {
        string label;
        address sender;
        address target;
        bytes calldataCopy;
        bytes result;
        bool success;
        bool expected;
        bool accountingUnchanged;
        uint256 gasMeasured;
    }

    function _saveCall(CallEvidence memory c) private {
        string memory k = string.concat("call_", c.label);
        vm.serializeString(k, "label", c.label);
        vm.serializeAddress(k, "from", c.sender);
        vm.serializeAddress(k, "to", c.target);
        vm.serializeBytes(k, "calldata", c.calldataCopy);
        vm.serializeBytes(k, "rawReturnOrRevertData", c.result);
        vm.serializeBool(k, "success", c.success);
        vm.serializeBool(k, "expectedSuccess", c.expected);
        vm.serializeUint(k, "gasMeasuredInsideForge", c.gasMeasured);
        vm.serializeUint(k, "blockNumber", block.number);
        vm.serializeBool(k, "accountingUnchanged", c.accountingUnchanged);
        string memory json = vm.serializeString(k, "executionType", "fork EVM call in Foundry test (not standalone tx hash)");
        vm.writeJson(json, string.concat("simulation-output/transaction_", c.label, ".json"));
    }

    function _tx(
        string memory label, address sender, address target, bytes memory callData, bool shouldSucceed
    ) private returns (bytes memory returnData) {
        _snapshot(string.concat(label, "_before"));
        State memory beforeState = _state();
        uint256 startGas = gasleft();
        vm.prank(sender);
        (bool success, bytes memory result) = target.call(callData);
        CallEvidence memory rec;
        rec.label = label;
        rec.sender = sender;
        rec.target = target;
        rec.calldataCopy = callData;
        rec.result = result;
        rec.success = success;
        rec.expected = shouldSucceed;
        rec.gasMeasured = startGas - gasleft();
        rec.accountingUnchanged = _sameAccounting(beforeState, _state());
        _snapshot(string.concat(label, "_after"));
        _saveCall(rec);
        if (!success && !rec.accountingUnchanged) revert("Reverting call changed accounting");
        if (success != shouldSucceed) revert CallOutcomeMismatch(label, shouldSucceed, success);
        return result;
    }

    function _deploy() private {
        _snapshot("deploy_before");
        balanceFuse = new FXMintBalanceFuse(VAULT, OWNER, FXMINT_POOL, WBTC, FXUSD);
        borrowFuse = new FXMintBorrowFuse(FXMINT_POOL, POOL_MANAGER, FXUSD);
        collateralFuse = new FXMintCollateralFuse(FXMINT_POOL, POOL_MANAGER, WBTC, address(balanceFuse));
        fxspFuse = new FxSPSupplyFuse(16, FXSP, FXUSD);
        fxspBalance = new FxSPCurveBalanceFuse(16);
        convexFuse = new ConvexFXGaugeSupplyFuse(17, BOOSTER, REGISTRY);
        convexBalance = new ConvexFXGaugeBalanceFuse(17, REGISTRY);
        fxnFeed = new FXNPriceFeedEthereum();
        address predictedExecutor = vm.computeCreateAddress(address(this), uint256(vm.getNonce(address(this))) + 1);
        FXMintLTVManager.Addresses memory a = FXMintLTVManager.Addresses({
            vault: VAULT, registry: address(balanceFuse), pool: FXMINT_POOL,
            collateralFuse: address(collateralFuse), borrowFuse: address(borrowFuse),
            supplyFuse: address(fxspFuse), stakeFuse: address(convexFuse), fxsp: FXSP,
            withdrawManager: WITHDRAW_MANAGER, withdrawExecutor: predictedExecutor
        });
        ltvManager = new FXMintLTVManager(a, TARGET);
        executor = new FulfillWithdrawExecutor(address(ltvManager));
        require(address(executor)==predictedExecutor,"Executor binding");
        _tx("safe_registers_live_risk_manager", OWNER, address(balanceFuse),
            abi.encodeWithSignature("setRiskManager(address)", address(ltvManager)), true);
        require(ltvManager.targetLtvWad() == TARGET, "60% LTV constructor failed");
        _snapshot("deploy_after");
    }

    function _grant(uint64 role, address actor, string memory label) private {
        _tx(label, OWNER, ACCESS,
            abi.encodeWithSignature("grantRole(uint64,address,uint32)", role, actor, uint32(0)), true);
    }

    function _configure() private {
        _grant(100, OWNER, "grant_atomist_safe");
        // Production currently gates deposit/mint with DEPOSITOR_ROLE=800.
        // Grant only the fork test depositor; do not silently open the vault globally.
        _grant(800, USER, "grant_depositor_role_to_test_user");
        _grant(200, OWNER, "grant_alpha_safe");
        _grant(200, address(executor), "grant_alpha_executor");
        // Only the already-validating scheduled-withdraw manager may refresh
        // balances before pricing a real user's authorized withdrawal request.
        _grant(1000, address(executor), "grant_nav_refresh_executor");
        _grant(300, OWNER, "grant_fuse_manager_safe");
        _grant(900, OWNER, "grant_instant_config_safe");
        _grant(901, OWNER, "grant_request_fee_safe");
        _grant(902, OWNER, "grant_withdraw_fee_safe");
        _grant(1200, OWNER, "grant_oracle_config_safe");

        address[] memory assets = new address[](2);
        address[] memory feeds = new address[](2);
        assets[0] = FXUSD; assets[1] = FXN;
        feeds[0] = USD_FEED; feeds[1] = address(fxnFeed);
        _tx("configure_fxusd_and_fxn_prices", OWNER, PRICE_MANAGER,
            abi.encodeWithSignature("setAssetsPriceSources(address[],address[])", assets, feeds), true);

        address[] memory fuses = new address[](7);
        fuses[0] = address(balanceFuse);
        fuses[1] = address(borrowFuse);
        fuses[2] = address(collateralFuse);
        fuses[3] = address(fxspFuse);
        fuses[4] = address(convexFuse);
        fuses[5] = address(ltvManager);
        fuses[6] = OMNI_FUSE;
        _tx("register_action_fuses", OWNER, VAULT,
            abi.encodeWithSignature("addFuses(address[])", fuses), true);

        _tx("balance_fxmint", OWNER, VAULT,
            abi.encodeWithSignature("addBalanceFuse(uint256,address)", 49, address(balanceFuse)), true);
        _tx("balance_convex", OWNER, VAULT,
            abi.encodeWithSignature("addBalanceFuse(uint256,address)", 17, address(convexBalance)), true);
        _tx("balance_fxsp", OWNER, VAULT,
            abi.encodeWithSignature("addBalanceFuse(uint256,address)", 16, address(fxspBalance)), true);
        _tx("balance_erc20", OWNER, VAULT,
            abi.encodeWithSignature("addBalanceFuse(uint256,address)", 7, ERC20_BALANCE_FUSE), true);
        _tx("balance_swap", OWNER, VAULT,
            abi.encodeWithSignature("addBalanceFuse(uint256,address)", 12, ZERO_BALANCE_FUSE), true);

        bytes32[] memory g = new bytes32[](1);
        g[0] = bytes32(uint256(uint160(GAUGE)));
        _tx("substrates_convex", OWNER, VAULT,
            abi.encodeWithSignature("grantMarketSubstrates(uint256,bytes32[])", 17, g), true);
        bytes32[] memory p = new bytes32[](1);
        p[0] = bytes32(uint256(uint160(FXSP)));
        _tx("substrates_fxsp", OWNER, VAULT,
            abi.encodeWithSignature("grantMarketSubstrates(uint256,bytes32[])", 16, p), true);
        bytes32[] memory ts = new bytes32[](3);
        ts[0] = bytes32(uint256(uint160(FXUSD)));
        ts[1] = bytes32(uint256(uint160(USDC)));
        ts[2] = bytes32(uint256(uint160(FXN)));
        _tx("substrates_idle_erc20", OWNER, VAULT,
            abi.encodeWithSignature("grantMarketSubstrates(uint256,bytes32[])", 7, ts), true);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 49; ids[1] = 17; ids[2] = 16; ids[3] = 12; ids[4] = 7;
        uint256[][] memory deps = new uint256[][](5);
        deps[0] = new uint256[](1); deps[0][0] = 7;
        deps[1] = new uint256[](2); deps[1][0] = 16; deps[1][1] = 7;
        deps[2] = new uint256[](1); deps[2][0] = 7;
        deps[3] = new uint256[](1); deps[3][0] = 7;
        deps[4] = new uint256[](0);
        _tx("configure_dependency_graph", OWNER, VAULT,
            abi.encodeWithSignature("updateDependencyBalanceGraphs(uint256[],uint256[][])", ids, deps), true);

        structDummy(); // no-op, keep all configuration in this test, not production changes
        InstantFuse[] memory q = new InstantFuse[](1);
        q[0].fuse = address(ltvManager);
        q[0].params = new bytes32[](1);
        q[0].params[0] = bytes32(0);
        _tx("configure_only_ltv_instant_withdraw", OWNER, VAULT,
            abi.encodeWithSignature("configureInstantWithdrawalFuses((address,bytes32[])[])", q), true);
    }

    struct InstantFuse { address fuse; bytes32[] params; }
    function structDummy() private pure {}

    /// @dev Only the existing required redemption route is installed. No swap benchmarking.
    function _configureScheduledRedeemSwap() private {
        bytes32[] memory x = new bytes32[](8);
        x[0] = bytes32((uint256(1) << 248) | uint256(uint160(FXUSD)));
        x[1] = bytes32((uint256(1) << 248) | uint256(uint160(USDC)));
        x[2] = bytes32((uint256(1) << 248) | uint256(uint160(FXN)));
        x[3] = bytes32((uint256(1) << 248) | uint256(uint160(WBTC)));
        x[4] = bytes32((uint256(2) << 248) | uint256(uint160(USDC)));
        x[5] = bytes32((uint256(2) << 248) | uint256(uint160(OMNI)));
        x[6] = bytes32((uint256(2) << 248) | uint256(uint160(WBTC)));
        x[7] = bytes32((uint256(2) << 248) | uint256(uint160(FXUSD)));
        _tx("substrates_existing_universal_swapper", OWNER, VAULT,
            abi.encodeWithSignature("grantMarketSubstrates(uint256,bytes32[])", 12, x), true);
        ICurveYieldRouterFork.Hop[] memory route = new ICurveYieldRouterFork.Hop[](1);
        route[0] = ICurveYieldRouterFork.Hop({
            poolType: 7,
            tokenOut: FXUSD,
            swapContract: CURVE_USDC_FXUSD,
            poolId: bytes32(0),
            poolData: abi.encode(uint8(0), uint8(1)),
            oracle: ICurveYieldRouterFork.Oracle({
                oracleAddress: CURVE_USDC_FXUSD,
                readFunctionID: bytes4(keccak256("price_oracle(uint256)")),
                requiredInputs: abi.encode(uint256(0)),
                invert: true,
                rateDecimals: 18
            })
        });
        _tx("configure_existing_usdc_fxusd_curve_route", OWNER, OMNI,
            abi.encodeCall(ICurveYieldRouterFork.setRoute, (USDC, FXUSD, route)), true);
        require(ICurveYieldRouterFork(OMNI).routeLength(USDC, FXUSD) == 1, "Scheduled route not installed on fork");
        // Entire vault exit must settle *all* remaining idle fxUSD into WBTC
        // after the atomic fxMINT debt+collateral close. The same approved
        // direct two-hop route is used; never introduce an extra WETH hop.
        ICurveYieldRouterFork.Hop[] memory fullExit = new ICurveYieldRouterFork.Hop[](2);
        fullExit[0] = ICurveYieldRouterFork.Hop({
            poolType: 7, tokenOut: USDC, swapContract: CURVE_USDC_FXUSD,
            poolId: bytes32(0), poolData: abi.encode(uint8(1), uint8(0)),
            oracle: ICurveYieldRouterFork.Oracle({
                oracleAddress: CURVE_USDC_FXUSD,
                readFunctionID: bytes4(keccak256("price_oracle(uint256)")),
                requiredInputs: abi.encode(uint256(0)), invert: false, rateDecimals: 18
            })
        });
        fullExit[1] = ICurveYieldRouterFork.Hop({
            poolType: 2, tokenOut: WBTC, swapContract: UNIV3_USDC_WBTC,
            poolId: bytes32(0), poolData: new bytes(0),
            oracle: ICurveYieldRouterFork.Oracle({
                oracleAddress: address(0), readFunctionID: bytes4(0),
                requiredInputs: new bytes(0), invert: false, rateDecimals: 0
            })
        });
        _tx("configure_existing_fxusd_usdc_wbtc_final_settlement_route", OWNER, OMNI,
            abi.encodeCall(ICurveYieldRouterFork.setRoute, (FXUSD, WBTC, fullExit)), true);
        require(ICurveYieldRouterFork(OMNI).routeLength(FXUSD, WBTC) == 2, "Final settlement route not installed");
    }


    struct SwapCalls { address[] targets; bytes[] data; }
    struct SwapData { address tokenIn; address tokenOut; uint256 amount; uint256 minOut; SwapCalls calls; }

    function _action(string memory label,address fuse,bytes memory data,bool succeeds) private {
        FuseAction[] memory a=new FuseAction[](1);
        a[0]=FuseAction(fuse,data);
        _tx(label,OWNER,VAULT,abi.encodeWithSignature("execute((address,bytes)[])",a),succeeds);
    }
    function _setTarget(uint256 target) private {
        _tx("set_target",OWNER,address(ltvManager),abi.encodeCall(FXMintLTVManager.setTargetLtvWad,(target)),true);
        require(ltvManager.targetLtvWad()==target,"Target not applied");
    }
    function _deposit(uint256 amount) private {
        _tx("fund_user_real_wbtc",WBTC_FUNDING_HOLDER,WBTC,abi.encodeCall(IERC20.transfer,(USER,amount)),true);
        _tx("user_approve_wbtc",USER,WBTC,abi.encodeCall(IERC20.approve,(VAULT,amount)),true);
        uint256 oldShares=IERC20(VAULT).balanceOf(USER);
        _tx("user_deposit_wbtc",USER,VAULT,abi.encodeCall(IERC4626.deposit,(amount,USER)),true);
        require(IERC20(VAULT).balanceOf(USER)>oldShares,"No shares minted");
    }
    function _open() private {
        FuseAction[] memory a=new FuseAction[](2);
        a[0]=FuseAction(address(collateralFuse),abi.encodeCall(FXMintCollateralFuse.enterNewPosition,(IERC20(WBTC).balanceOf(VAULT))));
        a[1]=FuseAction(address(balanceFuse),abi.encodeCall(FXMintBalanceFuse.enterRegisterLatestPosition,()));
        _tx("open_and_register_position",OWNER,VAULT,abi.encodeWithSignature("execute((address,bytes)[])",a),true);
        require(_state().rawDebt>0&&_state().rawCollateral>0,"Position missing");
    }
    function _up() private {
        _action("rebalance_up",address(ltvManager),abi.encodeCall(FXMintLTVManager.rebalanceUp,(0)),true);
        State memory st=_state();
        require(st.managerLtv<=ltvManager.targetLtvWad(),"LTV exceeds target");
    }
    function _start(uint256 amount,uint256 target) private {
        _deploy(); _configure(); _setTarget(target); _deposit(amount); _open(); _up();
        State memory st=_state();
        require(st.managerLtv+1e15>=target,"Borrow not near target");
        require(convexFuse.stakedBalanceOf(VAULT)>0,"No staked fxSP");
        _snapshot("leveraged");
    }
    function _shock(uint256 bps) private {
        address oracle=IFxMintPositionFork(FXMINT_POOL).priceOracle();
        uint256 price=Math.mulDiv(IFxMintPriceFork(oracle).getExchangePrice(),bps,10000);
        vm.mockCall(oracle,abi.encodeCall(IFxMintPriceFork.getExchangePrice,()),abi.encode(price));
        vm.mockCall(PRICE_MANAGER,abi.encodeWithSignature("getAssetPrice(address)",WBTC),abi.encode(price,uint256(18)));
        _snapshot("simulated_price_shock");
    }
    function _swapIndependent(address tokenIn,address tokenOut) private {
        uint256 amount=IERC20(tokenIn).balanceOf(VAULT);
        if(amount==0) return;
        address[] memory targets=new address[](2);
        bytes[] memory data=new bytes[](2);
        targets[0]=tokenIn; targets[1]=OMNI;
        data[0]=abi.encodeCall(IERC20.approve,(OMNI,amount));
        data[1]=abi.encodeWithSignature("swap(address,address,uint256)",tokenIn,tokenOut,amount);
        SwapData memory d=SwapData(tokenIn,tokenOut,amount,0,SwapCalls(targets,data));
        _action("independent_ipor_conversion",OMNI_FUSE,abi.encodeWithSignature("enter((address,address,uint256,uint256,(address[],bytes[])))",d),true);
    }
    function _request(uint256 shares) private {
        _tx("user_requests_shares",USER,WITHDRAW_MANAGER,abi.encodeCall(IWithdrawalRequestFork.requestShares,(shares)),true);
        (uint256 requested,,,)=IWithdrawalRequestFork(WITHDRAW_MANAGER).requestInfo(USER);
        require(requested>0,"No request");
        _tx("user_approves_executor",USER,VAULT,abi.encodeCall(IERC20.approve,(address(executor),requested)),true);
        _tx("initialize_scheduled",PUBLIC_CALLER,address(executor),abi.encodeCall(FulfillWithdrawExecutor.InitializeFulfillWithdrawRequest,(USER)),true);
        (address user,uint256 pendingShares,,,,)=executor.pending();
        require(user==USER&&pendingShares==requested,"Pending mismatch");
    }
    function _advance(string memory label) private {
        _tx(label,PUBLIC_CALLER,address(executor),abi.encodeCall(FulfillWithdrawExecutor.FinalizeFulfillWithdrawRequest,()),true);
    }
    function _finish(bool full) private {
        uint256 initialUserShares=IERC20(VAULT).balanceOf(USER);
        uint256 initialWBTC=IERC20(WBTC).balanceOf(USER);
        for(uint256 i;i<14;i++){
            (address user,,uint256 end,uint256 cooling,uint256 unlock,bool closed)=executor.pending();
            if(user==address(0)) break;
            if(cooling>0&&block.timestamp<unlock){vm.warp(unlock+2);vm.roll(block.number+20);}
            else {vm.warp(block.timestamp+2);vm.roll(block.number+1);}
            require(block.timestamp<end,"Request window expired");
            if(cooling==0){
                if(closed) {
                    _swapIndependent(USDC,FXUSD);
                    _swapIndependent(FXUSD,WBTC);
                } else {
                    _swapIndependent(USDC,FXUSD);
                }
            }
            _advance(string.concat("advance_",vm.toString(i)));
        }
        (address pendingUser,,,,,)=executor.pending();
        require(pendingUser==address(0),"Scheduled request not settled");
        State memory st=_state();
        require(st.userShares<initialUserShares&&st.userWBTC>initialWBTC,"User settlement missing");
        if(full) require(st.userShares==0&&st.rawDebt==0&&st.rawCollateral==0,"Full unwind incomplete");
        else require(st.managerLtv<=ltvManager.targetLtvWad(),"Partial exit exceeds target");
        _snapshot("settlement_complete");
    }
    function test_01_target_configuration() public {
        _deploy(); _configure();
        _setTarget(30e16); _setTarget(45e16); _setTarget(60e16); _setTarget(75e16);
        _tx("non_atomist_target_rejected",UNAUTHORIZED,address(ltvManager),abi.encodeCall(FXMintLTVManager.setTargetLtvWad,(60e16)),false);
        _tx("non_atomist_reserve_rejected",UNAUTHORIZED,address(ltvManager),abi.encodeCall(FXMintLTVManager.setWithdrawSlippageBps,(35)),false);
        require(ltvManager.targetLtvWad()==75e16,"Rejected call changed target");
        _tx("below_min",OWNER,address(ltvManager),abi.encodeCall(FXMintLTVManager.setTargetLtvWad,(30e16-1)),false);
        _tx("above_max",OWNER,address(ltvManager),abi.encodeCall(FXMintLTVManager.setTargetLtvWad,(75e16+1)),false);
        _tx("slippage_config",OWNER,address(ltvManager),abi.encodeCall(FXMintLTVManager.setWithdrawSlippageBps,(35)),true);
        require(ltvManager.withdrawSlippageBps()==35,"Slippage not applied");
    }
    function test_02_open_and_leverage_30() public { _start(5_000_000,30e16); }
    function test_03_open_and_leverage_45() public { _start(8_000_000,45e16); }
    function test_04_open_and_leverage_60() public { _start(10_000_000,60e16); }
    function test_05_open_and_leverage_75() public { _start(15_000_000,75e16); }
    function test_06_subsequent_deposit_and_raise_target() public {
        _start(10_000_000,45e16);
        uint256 oldCollateral=_state().rawCollateral; _deposit(2_000_000); _up();
        require(_state().rawCollateral>oldCollateral,"Idle WBTC not supplied");
        _setTarget(60e16); _up();
        require(_state().managerLtv+1e15>=60e16,"Not rebalanced to higher target");
    }
    function test_07_appreciation_instant_withdraw() public {
        _start(10_000_000,60e16); _shock(13000);
        State memory beforeState=_state();
        (uint256 gross,uint256 reduction,uint256 projected)=ltvManager.previewWithdrawal(200_000);
        require(gross>=200_000&&reduction==0&&projected<=60e16,"Bad safe preview");
        _tx("instant_withdraw",USER,VAULT,abi.encodeCall(IERC4626.withdraw,(200_000,USER,USER)),true);
        State memory afterState=_state();
        require(afterState.rawDebt==beforeState.rawDebt&&afterState.userWBTC>beforeState.userWBTC&&afterState.managerLtv<=60e16,"Instant exit state");
    }
    function test_08_depreciation_no_windup() public {
        _start(10_000_000,60e16); _shock(9000); State memory beforeState=_state();
        require(beforeState.managerLtv>60e16,"Shock did not raise LTV");
        _action("rebalance_no_extra_debt",address(ltvManager),abi.encodeCall(FXMintLTVManager.rebalanceUp,(0)),true);
        require(_state().rawDebt==beforeState.rawDebt,"Unexpected debt change");
        (,uint256 reduction,)=ltvManager.previewWithdrawal(200_000);
        require(reduction>0,"Preview failed to require repayment");
        _action("deleveraging_without_liquidity",address(ltvManager),abi.encodeCall(FXMintLTVManager.rebalanceDown,()),false);
    }
    function test_09_deleverage_funded() public {
        _start(10_000_000,60e16);
        // Fork-only funding fixture, no live transfer; preserves real repayment token and protocol calls.
        _tx("fork_fixture_funds_idle_fxusd",CURVE_USDC_FXUSD,FXUSD,abi.encodeCall(IERC20.transfer,(VAULT,1_000e18)),true);
        _shock(9000); State memory beforeState=_state();
        _action("rebalance_down",address(ltvManager),abi.encodeCall(FXMintLTVManager.rebalanceDown,()),true);
        State memory afterState=_state();
        require(afterState.rawDebt<beforeState.rawDebt&&afterState.managerLtv<=60e16&&afterState.rawCollateral==beforeState.rawCollateral,"Deleveraging failed");
    }
    function test_10_partial_scheduled() public {
        _start(10_000_000,60e16); _configureScheduledRedeemSwap();
        _request(IERC20(VAULT).balanceOf(USER)/10);
        (,,,uint256 cooling,uint256 unlock,)=executor.pending();
        require(cooling>0&&unlock>block.timestamp,"Cooldown not started");
        _tx("early_finalize",PUBLIC_CALLER,address(executor),abi.encodeCall(FulfillWithdrawExecutor.FinalizeFulfillWithdrawRequest,()),false);
        _finish(false);
    }
    function test_11_full_scheduled() public {
        _start(10_000_000,60e16); _configureScheduledRedeemSwap();
        _request(IERC20(VAULT).balanceOf(USER));
        _finish(true);
    }
    function test_12_full_scheduled_price_change() public {
        _start(10_000_000,45e16); _configureScheduledRedeemSwap();
        _request(IERC20(VAULT).balanceOf(USER)); _shock(11000); _finish(true);
    }
}

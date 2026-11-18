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
import {FxSPSupplyFuse} from "../../contracts/fuses/fxsp/FxSPSupplyFuse.sol";
import {FxSPCurveBalanceFuse} from "../../contracts/fuses/fxsp/FxSPCurveBalanceFuse.sol";
import {ConvexFXGaugeSupplyFuse} from "../../contracts/fuses/convex/ConvexFXGaugeSupplyFuse.sol";
import {ConvexFXGaugeBalanceFuse} from "../../contracts/fuses/convex/ConvexFXGaugeBalanceFuse.sol";
import {FulfillWithdrawExecutor} from "../../contracts/executors/FulfillWithdrawExecutor.sol";
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

contract CyWBTCSafetyForkV1 {
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
    address private constant PUBLIC_CALLER = address(0xB002);
    address private constant UNAUTHORIZED = address(0xB003);
    uint256 private constant TARGET = 6e17;
    uint256 private simulatedPriceShiftBeforeFinalizeBps;

    FXMintBalanceFuse private balanceFuse;
    FXMintBorrowFuse private borrowFuse;
    FXMintCollateralFuse private collateralFuse;
    FXMintLTVManager private ltvManager;
    FxSPSupplyFuse private fxspFuse;
    FxSPCurveBalanceFuse private fxspBalance;
    ConvexFXGaugeSupplyFuse private convexFuse;
    ConvexFXGaugeBalanceFuse private convexBalance;
    FulfillWithdrawExecutor private publicExecutor;
    FXNPriceFeedEthereum private fxnFeed;

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
        FXMintLTVManager.Addresses memory a = FXMintLTVManager.Addresses({
            vault: VAULT, owner: OWNER, balanceFuse: address(balanceFuse), fxMintPool: FXMINT_POOL,
            poolManager: POOL_MANAGER, wbtc: WBTC, fxusd: FXUSD, fxn: FXN, fxsp: FXSP,
            fxMintBorrowFuse: address(borrowFuse), fxMintCollateralFuse: address(collateralFuse),
            convexStakeFuse: address(convexFuse), fxspSupplyFuse: address(fxspFuse),
            convexGauge: GAUGE, omniSwapFuse: OMNI_FUSE, omniRouter: OMNI,
            usdc: USDC, withdrawManager: WITHDRAW_MANAGER
        });
        ltvManager = new FXMintLTVManager(a, TARGET);
        _tx("safe_registers_live_risk_manager", OWNER, address(balanceFuse),
            abi.encodeWithSignature("setRiskManager(address)", address(ltvManager)), true);
        publicExecutor = new FulfillWithdrawExecutor(address(ltvManager));
        require(ltvManager.targetLtvWad() == TARGET, "60% LTV constructor failed");
        require(address(publicExecutor.MANAGER()) == address(ltvManager), "Wrong public manager");
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
        _grant(200, address(ltvManager), "grant_alpha_ltv_manager");
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
        // The same exact user-approved WBTC -> USDC 0.05% V3 -> fxUSD Curve
        // route is needed only if native scheduled debt repayment is short.
        ICurveYieldRouterFork.Hop[] memory collateralRecovery = new ICurveYieldRouterFork.Hop[](2);
        collateralRecovery[0] = ICurveYieldRouterFork.Hop({
            poolType: 2,
            tokenOut: USDC,
            swapContract: UNIV3_USDC_WBTC,
            poolId: bytes32(0),
            poolData: new bytes(0),
            oracle: ICurveYieldRouterFork.Oracle({
                oracleAddress: address(0),
                readFunctionID: bytes4(0),
                requiredInputs: new bytes(0),
                invert: false,
                rateDecimals: 0
            })
        });
        collateralRecovery[1] = route[0];
        _tx("configure_existing_wbtc_usdc_fxusd_repayment_route", OWNER, OMNI,
            abi.encodeCall(ICurveYieldRouterFork.setRoute, (WBTC, FXUSD, collateralRecovery)), true);
        require(ICurveYieldRouterFork(OMNI).routeLength(WBTC, FXUSD) == 2, "Recovery route not installed on fork");

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

    function _pendingUnlock() private view returns (uint256 unlockAt) {
        (bool ok, bytes memory result) = address(ltvManager).staticcall(abi.encodeWithSignature("pendingRequest()"));
        require(ok && result.length >= 224, "No manager pending request");
        (, , , , , , unlockAt) = abi.decode(
            result, (address, uint256, uint256, uint256, uint256, uint256, uint256)
        );
    }

    function _pendingStage() private view returns (uint8 stage) {
        (bool ok, bytes memory result) = address(ltvManager).staticcall(
            abi.encodeWithSignature("pendingRequest()"));
        require(ok && result.length >= 256, "Pending stage unavailable");
        (, , , , , , , stage) = abi.decode(
            result, (address, uint256, uint256, uint256, uint256, uint256, uint256, uint8)
        );
    }

    function _fullScheduledExit() private {
        uint256 allUserShares = IERC20(VAULT).balanceOf(USER);
        require(allUserShares > 0, "No user shares before full exit");
        _tx("user_requests_100_percent_of_shares", USER, WITHDRAW_MANAGER,
            abi.encodeWithSignature("requestShares(uint256)", allUserShares), true);
        (uint256 requested, uint256 endWindow, bool canWithdraw, uint256 windowSec) =
            IWithdrawalRequestFork(WITHDRAW_MANAGER).requestInfo(USER);
        require(requested > 0 && endWindow >= block.timestamp + 3600 && windowSec >= 3600, "Bad native IPOR request");
        require(!canWithdraw, "Unreleased user request unexpectedly withdrawable");
        _tx("user_authorizes_manager_share_burn", USER, VAULT,
            abi.encodeWithSignature("approve(address,uint256)", address(ltvManager), requested), true);
        _tx("public_caller_starts_native_scheduled_exit", PUBLIC_CALLER, address(publicExecutor),
            abi.encodeWithSignature("InitializeFulfillWithdrawRequest(address)", USER), true);
        uint256 unlockAt = _pendingUnlock();
        require(unlockAt >= block.timestamp + 3600, "No cooldown initiated");
        _tx("public_caller_cannot_finalize_before_unlock", PUBLIC_CALLER, address(publicExecutor),
            abi.encodeWithSignature("FinalizeFulfillWithdrawRequest()"), false);
        _snapshot("user_scheduled_cooldown_pending");
        vm.warp(unlockAt + 2);
        vm.roll(block.number + 20);
        if (simulatedPriceShiftBeforeFinalizeBps != 0) {
            _shockWBTC(simulatedPriceShiftBeforeFinalizeBps);
        }
        _snapshot("user_scheduled_after_cooldown");
        if (simulatedPriceShiftBeforeFinalizeBps != 0) {
            _driveShockedRequestWithSafeRecovery();
            return;
        }
        // f(x) PoolConfiguration uses a transaction-long transient lock:
        // each finalize invocation can use at most ONE fxMINT operate.
        _tx("any_public_caller_can_redeem_fxsp_and_partially_repay", UNAUTHORIZED, address(publicExecutor),
            abi.encodeWithSignature("FinalizeFulfillWithdrawRequest()"), true);
        _snapshot("scheduled_after_first_finalize_tx");
        if (IERC20(VAULT).balanceOf(USER) != 0) {
            uint8 currentStage = _pendingStage();
            if (currentStage == 1) {
                _tx("another_public_caller_can_release_safe_recovery_collateral", PUBLIC_CALLER, address(publicExecutor),
                    abi.encodeWithSignature("FinalizeFulfillWithdrawRequest()"), true);
                require(_pendingStage() == 2, "Recovery collateral stage not reached");
                _snapshot("scheduled_after_recovery_collateral_tx");
                _tx("public_caller_completes_atomic_debt_and_collateral_close", UNAUTHORIZED, address(publicExecutor),
                    abi.encodeWithSignature("FinalizeFulfillWithdrawRequest()"), true);
                _snapshot("scheduled_after_atomic_position_close_tx");
            } else if (currentStage == 3) {
                _tx("public_caller_can_finally_redeem_all_user_shares", PUBLIC_CALLER, address(publicExecutor),
                    abi.encodeWithSignature("FinalizeFulfillWithdrawRequest()"), true);
            } else revert("Unexpected scheduled withdrawal stage");
        }
        _snapshot("user_full_exit_final");
        require(IERC20(VAULT).balanceOf(USER) == 0, "User did not redeem all shares");
        require(IERC20(WBTC).balanceOf(USER) > 0, "User got no WBTC on full withdrawal");
        State memory post = _state();
        require(post.rawDebt == 0, "Debt left after 100% user exit");
        require(_pendingUnlock() == 0, "Manager pending request not cleared");
    }

    function _fundAndDeposit(uint256 amount) private {
        require(IERC20(WBTC).balanceOf(WBTC_FUNDING_HOLDER) >= amount,
            "Fork source lacks real WBTC liquidity");
        _tx("fund_user_real_wbtc", WBTC_FUNDING_HOLDER, WBTC,
            abi.encodeWithSignature("transfer(address,uint256)", USER, amount), true);
        _tx("user_approve_wbtc", USER, WBTC,
            abi.encodeWithSignature("approve(address,uint256)", VAULT, amount), true);
        bytes memory result = _tx("user_deposit_wbtc", USER, VAULT,
            abi.encodeWithSignature("deposit(uint256,address)", amount, USER), true);
        require(abi.decode(result, (uint256)) > 0, "User obtained no shares");
        require(IERC20(VAULT).balanceOf(USER) > 0, "User balance not credited");
    }

    function _openNft() private {
        uint256 amount = IERC20(WBTC).balanceOf(VAULT);
        require(amount > 0, "No WBTC collateral");
        FuseAction[] memory actions = new FuseAction[](2);
        actions[0] = FuseAction(address(collateralFuse),
            abi.encodeWithSignature("enterNewPosition(uint256)", amount));
        actions[1] = FuseAction(address(balanceFuse),
            abi.encodeWithSignature("enterRegisterLatestPosition()"));
        _tx("owner_open_nft_and_register_atomically", OWNER, VAULT,
            abi.encodeWithSignature("execute((address,bytes)[])", actions), true);
        require(balanceFuse.positionId() > 0, "NFT ID not registered");
        (uint256 collateral, uint256 debt) = IFxMintPositionFork(FXMINT_POOL).getPosition(balanceFuse.positionId());
        require(collateral > 0 && debt > 0, "fxMINT missing position");
    }

    function _up() private {
        FuseAction[] memory actions = new FuseAction[](1);
        actions[0] = FuseAction(address(ltvManager),
            abi.encodeWithSignature("rebalanceUp(uint256)", uint256(0)));
        _tx("owner_borrow_to_60_percent_and_stake", OWNER, VAULT,
            abi.encodeWithSignature("execute((address,bytes)[])", actions), true);
        State memory s = _state();
        require(s.managerLtv <= TARGET, "Vault operation exceeded target 60% LTV");
        require(s.rawDebt != 0, "No borrowed debt recorded");
    }

    function test_00_permission_guards_with_persistent_snapshots() public {
        _deploy();
        address[] memory noFuses = new address[](0);
        _tx("reject_user_add_fuses", UNAUTHORIZED, VAULT,
            abi.encodeWithSignature("addFuses(address[])", noFuses), false);
        _tx("reject_user_release_funds", UNAUTHORIZED, WITHDRAW_MANAGER,
            abi.encodeWithSignature("releaseFunds(uint256,uint256)", block.timestamp, uint256(1)), false);
        _tx("reject_direct_execute_internal", UNAUTHORIZED, VAULT,
            abi.encodeWithSignature("executeInternal((address,bytes)[])", new FuseAction[](0)), false);
        _tx("reject_nonowner_set_ltv", UNAUTHORIZED, address(ltvManager),
            abi.encodeWithSignature("setTargetLtvWad(uint256)", uint256(5e17)), false);
        _tx("reject_zero_ltv", OWNER, address(ltvManager),
            abi.encodeWithSignature("setTargetLtvWad(uint256)", uint256(0)), false);
        _tx("reject_overprotocol_ltv", OWNER, address(ltvManager),
            abi.encodeWithSignature("setTargetLtvWad(uint256)", uint256(99e16)), false);
        _tx("reject_invalid_slippage", OWNER, address(ltvManager),
            abi.encodeWithSignature("setWithdrawSlippageBps(uint256)", uint256(56)), false);
        _tx("reject_direct_instant_withdraw", UNAUTHORIZED, address(ltvManager),
            abi.encodeWithSignature("instantWithdraw(bytes32[])", new bytes32[](1)), false);
        _tx("reject_initialize_without_request", PUBLIC_CALLER, address(publicExecutor),
            abi.encodeWithSignature("InitializeFulfillWithdrawRequest(address)", USER), false);
        _tx("reject_finalize_without_request", PUBLIC_CALLER, address(publicExecutor),
            abi.encodeWithSignature("FinalizeFulfillWithdrawRequest()"), false);
        require(ltvManager.targetLtvWad() == TARGET, "Owner and guard tests corrupted target");
    }

    function test_01_config_user_deposit_nft_and_leverage() public {
        _deploy();
        _configure();
        _fundAndDeposit(10_000_000); // 0.1 real WBTC from existing fork-state liquidity
        _openNft();
        _up();
        _snapshot("leverage_final_state");
    }
    function test_02_user_request_public_two_button_full_scheduled_exit() public {
        _deploy();
        _configure();
        _configureScheduledRedeemSwap();
        _fundAndDeposit(10_000_000);
        _openNft();
        _up();
        _fullScheduledExit();
    }

    function test_03_direct_alpha_borrow_must_not_bypass_target_ltv() public {
        _deploy();
        _configure();
        _fundAndDeposit(10_000_000);
        _openNft();
        _up();
        uint256 beforeLtv = _state().managerLtv;
        require(beforeLtv <= TARGET, "Initial over-target position");
        FuseAction[] memory actions = new FuseAction[](1);
        actions[0] = FuseAction(address(borrowFuse),
            abi.encodeWithSignature("enter(uint256,uint256,uint256)", balanceFuse.positionId(), uint256(100e18), uint256(0)));
        _tx("reject_alpha_direct_borrow_above_target", OWNER, VAULT,
            abi.encodeWithSignature("execute((address,bytes)[])", actions), false);
        require(_state().managerLtv == beforeLtv, "Direct borrow bypassed target");
        _snapshot("over_target_borrow_rejected");
    }

    function test_04_direct_alpha_collateral_exit_must_not_bypass_ltv() public {
        _deploy();
        _configure();
        _fundAndDeposit(10_000_000);
        _openNft();
        _up();
        uint256 beforeLtv = _state().managerLtv;
        require(beforeLtv <= TARGET, "Initial over-target position");
        FuseAction[] memory actions = new FuseAction[](1);
        actions[0] = FuseAction(address(collateralFuse),
            abi.encodeWithSignature("exit(uint256,uint256,uint256)",
                balanceFuse.positionId(), uint256(100_000), uint256(0)));
        _tx("reject_alpha_direct_collateral_exit_above_target", OWNER, VAULT,
            abi.encodeWithSignature("execute((address,bytes)[])", actions), false);
        require(_state().managerLtv == beforeLtv, "Direct collateral exit bypassed target");
        _snapshot("over_target_collateral_exit_rejected");
    }

    /// @notice An ordinary user must never force immediate debt repayment or
    /// protocol fxSP redemption by requesting all shares instantly.
    function test_05_user_cannot_force_instant_debt_repayment_or_exit_tax() public {
        _deploy();
        _configure();
        _fundAndDeposit(10_000_000);
        _openNft();
        _up();
        State memory beforeState = _state();
        require(beforeState.rawDebt > 0, "Precondition missing live f(x) debt");
        _tx("user_instant_100pct_exit_rejected_without_debt_repay", USER, VAULT,
            abi.encodeWithSignature("redeem(uint256,address,address)", beforeState.userShares, USER, USER), false);
        State memory afterState = _state();
        require(_sameAccounting(beforeState, afterState), "Instant rejection changed position");
        require(afterState.rawDebt == beforeState.rawDebt, "Instant path repaid debt");
        require(afterState.gaugeStakedShares == beforeState.gaugeStakedShares,
            "Instant path caused forced Convex unstake / fxSP tax");
        _snapshot("instant_exit_blocked_without_tax");
    }

    function _mockWBTCExchangePrice(uint256 numerator, uint256 denominator) private returns (uint256) {
        require(numerator > 0 && denominator > 0, "Bad price shock");
        address oracle = IFxMintPositionFork(FXMINT_POOL).priceOracle();
        uint256 original = IFxMintPriceFork(oracle).getExchangePrice();
        uint256 shifted = Math.mulDiv(original, numerator, denominator);
        // Change the *real f(x) exchange price call* on the local fork only.
        // This models repricing of collateral; it does not modify real mainnet.
        vm.mockCall(oracle, abi.encodeWithSignature("getExchangePrice()"), abi.encode(shifted));
        return shifted;
    }

    /// @notice At an appreciated WBTC price, a safe instant release must be
    /// possible without changing debt, un-staking fxSP or incurring repayment.
    function test_06_instant_withdraw_after_wbtc_appreciation_keeps_debt_exact() public {
        _deploy();
        _configure();
        _fundAndDeposit(10_000_000);
        _openNft();
        _up();
        _mockWBTCExchangePrice(130, 100);
        State memory beforeState = _state();
        require(beforeState.managerLtv < TARGET, "Positive price shock did not improve LTV");
        // 0.002 WBTC from 0.1 WBTC collateral is small enough to remain below 60%.
        _tx("user_instant_release_after_30pct_wbtc_appreciation", USER, VAULT,
            abi.encodeWithSignature("withdraw(uint256,address,address)", uint256(200_000), USER, USER), true);
        State memory afterState = _state();
        require(afterState.rawDebt == beforeState.rawDebt, "Instant withdrawal repaid debt");
        require(afterState.gaugeStakedShares == beforeState.gaugeStakedShares,
            "Instant withdrawal unstaked yield / caused a tax");
        require(afterState.fxspIdle == beforeState.fxspIdle, "Instant withdrawal used fxSP");
        require(afterState.userWBTC > beforeState.userWBTC, "No WBTC reached user");
        require(afterState.managerLtv <= TARGET, "Instant release violated target LTV");
        _snapshot("positive_shock_instant_safe_no_repay");
    }

    /// @notice External price decline may put an existing position over target,
    /// but vault actions may not further increase debt or allow a forced instant
    /// repayment or collateral withdrawal at that shocked price.
    function test_07_price_crashes_block_instant_exit_and_extra_leverage() public {
        _deploy();
        _configure();
        _fundAndDeposit(10_000_000);
        _openNft();
        _up();
        uint256 originalDebt = _state().rawDebt;
        require(originalDebt > 0, "No debt to challenge against price crashes");
        address oracle = IFxMintPositionFork(FXMINT_POOL).priceOracle();
        uint256 initialPrice = IFxMintPriceFork(oracle).getExchangePrice();
        uint256[4] memory shockBps = [uint256(9_500), 9_000, 8_000, 7_000];
        for (uint256 i; i < shockBps.length; i++) {
            vm.mockCall(oracle, abi.encodeWithSignature("getExchangePrice()"),
                abi.encode(Math.mulDiv(initialPrice, shockBps[i], 10_000)));
            State memory beforeState = _state();
            require(beforeState.managerLtv > TARGET, "Price drop did not exceed the initial 60% LTV");
            string memory label = string.concat("crash_", vm.toString(shockBps[i]));
            _tx(string.concat(label, "_instant_exit_rejected"), USER, VAULT,
                abi.encodeWithSignature("withdraw(uint256,address,address)", uint256(50_000), USER, USER), false);
            // Rebalance-up must not initiate new debt when already above target.
            FuseAction[] memory actions = new FuseAction[](1);
            actions[0] = FuseAction(address(ltvManager),
                abi.encodeWithSignature("rebalanceUp(uint256)", uint256(0)));
            _tx(string.concat(label, "_rebalance_up_cannot_add_debt"), OWNER, VAULT,
                abi.encodeWithSignature("execute((address,bytes)[])", actions), true);
            State memory afterState = _state();
            require(afterState.rawDebt == originalDebt, "Rebalance added debt during collateral crash");
            require(afterState.userShares == beforeState.userShares, "Price-shock action burned shares");
            require(afterState.gaugeStakedShares == beforeState.gaugeStakedShares,
                "Price-shock action caused forced taxed unstake");
            _snapshot(string.concat(label, "_verified"));
        }
    }

    /// @notice Full withdrawal must remain possible even after repeated owner
    /// adjustments and no-op operational cycles, not only after fresh leverage.
    function test_08_full_scheduled_exit_after_owner_and_vault_operations() public {
        _deploy();
        _configure();
        _configureScheduledRedeemSwap();
        _fundAndDeposit(10_000_000);
        _openNft();
        _up();
        _tx("owner_changes_slippage_to_55bps", OWNER, address(ltvManager),
            abi.encodeWithSignature("setWithdrawSlippageBps(uint256)", uint256(55)), true);
        _tx("owner_restores_slippage_to_20bps", OWNER, address(ltvManager),
            abi.encodeWithSignature("setWithdrawSlippageBps(uint256)", uint256(20)), true);
        _tx("owner_sets_target_65pct_then_restores_60pct", OWNER, address(ltvManager),
            abi.encodeWithSignature("setTargetLtvWad(uint256)", uint256(65e16)), true);
        _tx("owner_restores_60pct_target", OWNER, address(ltvManager),
            abi.encodeWithSignature("setTargetLtvWad(uint256)", TARGET), true);
        FuseAction[] memory actions = new FuseAction[](1);
        actions[0] = FuseAction(address(ltvManager),
            abi.encodeWithSignature("rebalanceUp(uint256)", uint256(0)));
        _tx("owner_rebalance_up_after_previous_complete_cycle", OWNER, VAULT,
            abi.encodeWithSignature("execute((address,bytes)[])", actions), true);
        actions[0] = FuseAction(address(ltvManager),
            abi.encodeWithSignature("compound(uint256)", uint256(0)));
        _tx("owner_compound_no_idle_fxn", OWNER, VAULT,
            abi.encodeWithSignature("execute((address,bytes)[])", actions), true);
        _snapshot("before_full_exit_after_operating_cycles");
        _fullScheduledExit();
    }

    /// @dev Price shocks are applied only to fork reads; the historical
    ///      price oracle remains untouched on Ethereum mainnet.
    function _shockWBTC(uint256 newPriceBps) private {
        address fxMintOracle = IFxMintPositionFork(FXMINT_POOL).priceOracle();
        uint256 oldPrice = IFxMintPriceFork(fxMintOracle).getExchangePrice();
        uint256 newPrice = Math.mulDiv(oldPrice, newPriceBps, 10_000);
        require(newPrice != 0 && newPrice < type(uint128).max, "Shock price outside scale");
        vm.mockCall(fxMintOracle, abi.encodeWithSignature("getExchangePrice()"), abi.encode(newPrice));
        vm.mockCall(PRICE_MANAGER, abi.encodeWithSignature("getAssetPrice(address)", WBTC),
            abi.encode(newPrice, uint256(18)));
        _snapshot(string.concat("wbtc_shock_", vm.toString(newPriceBps)));
    }

    function _vaultManagerAction(string memory name, bytes memory data) private {
        FuseAction[] memory actions = new FuseAction[](1);
        actions[0] = FuseAction(address(ltvManager), data);
        _tx(name, OWNER, VAULT, abi.encodeWithSignature("execute((address,bytes)[])", actions), true);
    }

    function test_05_instant_redeem_at_target_cannot_trigger_taxed_debt_repay() public {
        _deploy();
        _configure();
        _fundAndDeposit(10_000_000);
        _openNft();
        _up();
        State memory beforeState = _state();
        uint256 requested = beforeState.userShares / 100;
        require(requested > 0, "Need positive instant request");
        _tx("user_instant_redeem_rejected_when_debt_repay_needed", USER, VAULT,
            abi.encodeWithSignature("redeem(uint256,address,address)", requested, USER, USER), false);
        State memory afterState = _state();
        require(_sameAccounting(beforeState, afterState), "Rejected instant redeem changed assets, debt or shares");
        _snapshot("instant_redeem_rejected_no_forced_tax");
    }

    function test_06_wbtc_price_crash_cannot_trigger_bad_admin_or_user_actions() public {
        _deploy();
        _configure();
        _fundAndDeposit(10_000_000);
        _openNft();
        _up();
        State memory beforeShock = _state();
        require(beforeShock.managerLtv <= TARGET, "Original entry unsafe");
        _shockWBTC(7500); // Realistic 25% rapid Bitcoin drawdown.
        State memory shocked = _state();
        require(shocked.managerLtv > TARGET, "Price decline did not create undercollateralization");
        require(shocked.rawCollateral == beforeShock.rawCollateral &&
            shocked.rawDebt == beforeShock.rawDebt, "A price read changed live position");
        _vaultManagerAction("no_additional_borrow_after_wbtc_price_crash",
            abi.encodeWithSignature("rebalanceUp(uint256)", uint256(0)));
        require(_state().rawDebt == shocked.rawDebt, "Admin increased debt after adverse shock");
        _tx("reject_rebalance_down_without_idle_stablecoin_liquidity", OWNER, VAULT,
            _oneManagerAction(abi.encodeWithSignature("rebalanceDown()")), false);
        uint256 shares = IERC20(VAULT).balanceOf(USER) / 100;
        _tx("reject_instant_exit_during_wbtc_price_crash", USER, VAULT,
            abi.encodeWithSignature("redeem(uint256,address,address)", shares, USER, USER), false);
        // Repricing and subsequent balance-cache refresh legitimately change
        // totalAssets; require the real balances and obligations stay unchanged.
        State memory postShock = _state();
        require(postShock.rawDebt == shocked.rawDebt &&
            postShock.rawCollateral == shocked.rawCollateral &&
            postShock.userShares == shocked.userShares &&
            postShock.wbtcIdle == shocked.wbtcIdle &&
            postShock.fxusdIdle == shocked.fxusdIdle &&
            postShock.fxspIdle == shocked.fxspIdle &&
            postShock.gaugeStakedShares == shocked.gaugeStakedShares,
            "Vault changed real balances or debt during price shock");
        _snapshot("price_crash_final_account_state");
    }

    function _oneManagerAction(bytes memory payload) private view returns (bytes memory) {
        FuseAction[] memory actions = new FuseAction[](1);
        actions[0] = FuseAction(address(ltvManager), payload);
        return abi.encodeWithSignature("execute((address,bytes)[])", actions);
    }

    function test_07_wbtc_price_rally_allows_safe_instant_exit_without_debt_repay() public {
        _deploy();
        _configure();
        _fundAndDeposit(10_000_000);
        _openNft();
        _up();
        _shockWBTC(15000); // 50% intracycle BTC rally.
        State memory beforeState = _state();
        require(beforeState.managerLtv < TARGET, "Rally failed to improve LTV");
        uint256 requested = beforeState.userShares / 200;
        _tx("user_instant_redeem_after_wbtc_rally", USER, VAULT,
            abi.encodeWithSignature("redeem(uint256,address,address)", requested, USER, USER), true);
        State memory afterState = _state();
        require(afterState.rawDebt == beforeState.rawDebt,
            "Instant redemption must not force fxMINT debt repayment or tax");
        require(afterState.managerLtv <= TARGET, "Instant redemption exceeded 60% target");
        require(afterState.userShares < beforeState.userShares &&
            afterState.userWBTC > beforeState.userWBTC, "Shares/assets not settled");
        _snapshot("price_rally_safe_instant_exit");
    }

    function test_08_admin_routine_actions_then_full_public_user_exit() public {
        _deploy();
        _configure();
        _configureScheduledRedeemSwap();
        _fundAndDeposit(10_000_000);
        _openNft();
        _up();
        _tx("owner_set_65pct_ltv_target", OWNER, address(ltvManager),
            abi.encodeWithSignature("setTargetLtvWad(uint256)", 65e16), true);
        require(ltvManager.targetLtvWad() == 65e16, "Target did not update");
        _tx("owner_reset_60pct_ltv_target", OWNER, address(ltvManager),
            abi.encodeWithSignature("setTargetLtvWad(uint256)", TARGET), true);
        _tx("owner_set_withdraw_slippage_25bps", OWNER, address(ltvManager),
            abi.encodeWithSignature("setWithdrawSlippageBps(uint256)", uint256(25)), true);
        _vaultManagerAction("owner_rebalance_up_already_at_target",
            abi.encodeWithSignature("rebalanceUp(uint256)", uint256(0)));
        _vaultManagerAction("owner_compound_without_claimed_fxn",
            abi.encodeWithSignature("compound(uint256)", uint256(0)));
        require(_state().managerLtv <= TARGET, "Routine manager action created excess debt");
        _fullScheduledExit();
        // Fee accrual during the cooldown can mint a few shares to the
        // official DAO recipient. User 100% exit is valid when those tiny
        // *owned* shares and their corresponding WBTC dust are the only residue.
        _assertUserFullyExitedWithOnlyFeeAccountDust();
        _snapshot("full_exit_only_fee_account_dust");
    }

    function test_09_fee_admin_config_and_unauthorized_fee_guards() public {
        _deploy();
        _configure();
        _tx("reject_unauthorized_deposit_fee", UNAUTHORIZED, FEE_MANAGER,
            abi.encodeWithSignature("setDepositFee(uint256)", 5e15), false);
        _tx("set_40bps_deposit_fee", OWNER, FEE_MANAGER,
            abi.encodeWithSignature("setDepositFee(uint256)", 4e15), true);
        _tx("set_45bps_regular_withdraw_fee", OWNER, WITHDRAW_MANAGER,
            abi.encodeWithSignature("updateWithdrawFee(uint256)", 45e14), true);
        _tx("set_45bps_scheduled_request_fee", OWNER, WITHDRAW_MANAGER,
            abi.encodeWithSignature("updateRequestFee(uint256)", 45e14), true);
        (bool ok, bytes memory ret) = FEE_MANAGER.staticcall(abi.encodeWithSignature("getDepositFee()"));
        require(ok && abi.decode(ret, (uint256)) == 4e15, "Deposit fee differs from expected");
        (ok, ret) = WITHDRAW_MANAGER.staticcall(abi.encodeWithSignature("getWithdrawFee()"));
        require(ok && abi.decode(ret, (uint256)) == 45e14, "Regular withdrawal fee differs");
        (ok, ret) = WITHDRAW_MANAGER.staticcall(abi.encodeWithSignature("getRequestFee()"));
        require(ok && abi.decode(ret, (uint256)) == 45e14, "Scheduled request fee differs");
        _tx("reject_nonowner_withdraw_fee_change", UNAUTHORIZED, WITHDRAW_MANAGER,
            abi.encodeWithSignature("updateWithdrawFee(uint256)", uint256(0)), false);
        _tx("reject_nonowner_scheduled_fee_change", UNAUTHORIZED, WITHDRAW_MANAGER,
            abi.encodeWithSignature("updateRequestFee(uint256)", uint256(0)), false);
        _snapshot("fee_configuration_after_role_checks");
    }

    /// @notice Stress mainnet-priced f(x) and IPOR collateral reads together
    /// between the user's initial request and the matured exit.
    function test_10_full_exit_succeeds_after_20pct_wbtc_crash_during_cooldown() public {
        _deploy();
        _configure();
        _configureScheduledRedeemSwap();
        _fundAndDeposit(10_000_000);
        _openNft();
        _up();
        simulatedPriceShiftBeforeFinalizeBps = 8_000;
        _fullScheduledExit();
        _assertUserFullyExitedWithOnlyFeeAccountDust();
        _snapshot("full_exit_after_mature_cooldown_20pct_crash");
    }

    function test_11_full_exit_succeeds_after_40pct_wbtc_rally_during_cooldown() public {
        _deploy();
        _configure();
        _configureScheduledRedeemSwap();
        _fundAndDeposit(10_000_000);
        _openNft();
        _up();
        simulatedPriceShiftBeforeFinalizeBps = 14_000;
        _fullScheduledExit();
        _assertUserFullyExitedWithOnlyFeeAccountDust();
        _snapshot("full_exit_after_mature_cooldown_40pct_rally");
    }
    /// @notice A large oracle change can precede DEX repricing. In that
    /// temporarily inconsistent market state the existing UniversalTokenSwapper
    /// slippage guard MUST revert without losing state, and the request must be
    /// completable after prices again agree. Do not weaken the live swap guard.
    function _driveShockedRequestWithSafeRecovery() private {
        bool slippageProtected;
        for (uint256 i; i < 8 && _pendingUnlock() != 0; i++) {
            string memory label = string.concat("shock_finalize_step_", vm.toString(i));
            _snapshot(string.concat(label, "_before"));
            State memory beforeState = _state();
            uint256 gasBefore = gasleft();
            bytes memory calldataCopy = abi.encodeWithSignature("FinalizeFulfillWithdrawRequest()");
            vm.prank(PUBLIC_CALLER);
            (bool ok, bytes memory result) = address(publicExecutor).call(calldataCopy);
            CallEvidence memory c;
            c.label = label;
            c.sender = PUBLIC_CALLER;
            c.target = address(publicExecutor);
            c.calldataCopy = calldataCopy;
            c.result = result;
            c.success = ok;
            c.expected = ok;
            c.gasMeasured = gasBefore - gasleft();
            c.accountingUnchanged = _sameAccounting(beforeState, _state());
            _snapshot(string.concat(label, "_after"));
            _saveCall(c);
            if (!ok) {
                require(!slippageProtected, "Failed again after restoring consistent prices");
                require(c.accountingUnchanged, "Blocked price-shock swap changed vault accounting");
                require(result.length >= 4 &&
                    bytes4(result) == FXMintLTVManager.FuseExecutionFailed.selector,
                    "Unexpected price-shock revert (not fuse slippage protection)");
                slippageProtected = true;
                vm.clearMockedCalls(); // fork-only: restore the real f(x)/IPOR oracle state
                _snapshot("restore_consistent_chain_pricing_after_shock_guard");
            }
        }
        require(slippageProtected, "Market/oracle mismatch did not trigger protection");
        require(_pendingUnlock() == 0, "Request remained stuck after prices recovered");
        require(IERC20(VAULT).balanceOf(USER) == 0, "User shares not fully redeemed after shock");
        State memory post = _state();
        require(post.rawDebt == 0, "fxMINT debt persisted after shock recovery");
        require(post.gaugeStakedShares == 0, "Convex position persisted after full exit");
        _snapshot("price_shock_then_recovery_full_user_exit");
    }
    /// @notice Fee shares are minted to IPOR's FeeManager account rather than
    /// directly to the DAO Safe. At full user exit this account can retain
    /// very small accrued management-fee shares against a few WBTC satoshis.
    function _assertUserFullyExitedWithOnlyFeeAccountDust() private view {
        require(IERC20(VAULT).balanceOf(USER) == 0, "User has unredeemed shares");
        (bool okM, bytes memory managementRaw) =
            VAULT.staticcall(abi.encodeWithSignature("getManagementFeeData()"));
        (bool okP, bytes memory performanceRaw) =
            VAULT.staticcall(abi.encodeWithSignature("getPerformanceFeeData()"));
        require(okM && managementRaw.length >= 96 && okP && performanceRaw.length >= 64,
            "IPOR fee accounts unavailable");
        (address managementAccount,,) = abi.decode(managementRaw, (address, uint16, uint32));
        (address performanceAccount,) = abi.decode(performanceRaw, (address, uint16));
        require(managementAccount != address(0) && performanceAccount != address(0),
            "Invalid fee accounts");
        uint256 sharesLeft = IERC20(VAULT).totalSupply();
        uint256 feeShares = IERC20(VAULT).balanceOf(managementAccount)
            + (managementAccount == performanceAccount ? 0 : IERC20(VAULT).balanceOf(performanceAccount));
        require(sharesLeft == feeShares, "Non-fee shares remain after user exit");
        // Discrete fee realization after a sudden oracle recovery can mint
        // performance-fee shares and keep the proportional WBTC in custody.
        // This is fee-owned capital, NOT user shares or unowned collateral.
        // Reject any unexpectedly large share allocation (1% initial user shares).
        require(sharesLeft <= 10_000_000, "Excessive fee share residue");
        State memory s = _state();
        require(s.rawDebt == 0 && s.rawCollateral == 0 && s.gaugeStakedShares == 0 &&
            s.fxusdIdle == 0 && s.fxspIdle == 0 && s.usdcIdle == 0 && s.wbtcIdle <= 100_000,
            "Residual leverage or unaccounted collateral after user exit");
    }
    /// @notice ERC4626 mint() must work as a distinct user entry point
    /// (not just deposit()), preserve share accounting, then allow a complete
    /// scheduled close after all strategy assets have entered live markets.
    function test_12_user_mint_entrypoint_and_full_withdrawal() public {
        _deploy();
        _configure();
        _configureScheduledRedeemSwap();
        uint256 funding = 10_000_000;
        _tx("mint_user_funded_with_real_wbtc", WBTC_FUNDING_HOLDER, WBTC,
            abi.encodeWithSignature("transfer(address,uint256)", USER, funding), true);
        _tx("mint_user_approves_underlying", USER, WBTC,
            abi.encodeWithSignature("approve(address,uint256)", VAULT, funding), true);
        uint256 shares = IERC4626(VAULT).previewDeposit(funding);
        require(shares > 0, "No mintable shares");
        uint256 requiredAssets = IERC4626(VAULT).previewMint(shares);
        require(requiredAssets > 0 && requiredAssets <= funding, "Invalid mint preview");
        uint256 beforeWBTC = IERC20(WBTC).balanceOf(USER);
        bytes memory ret = _tx("user_mint_erc4626_shares", USER, VAULT,
            abi.encodeWithSignature("mint(uint256,address)", shares, USER), true);
        require(abi.decode(ret,(uint256)) == requiredAssets, "Mint charged unexpected assets");
        require(IERC20(VAULT).balanceOf(USER) == shares, "Mint did not issue shares");
        require(beforeWBTC - IERC20(WBTC).balanceOf(USER) == requiredAssets, "Mint debit mismatch");
        _openNft();
        _up();
        require(_state().managerLtv <= TARGET, "Mint-funded strategy exceeded LTV");
        _fullScheduledExit();
        _assertUserFullyExitedWithOnlyFeeAccountDust();
    }

    /// @notice No third party can redeem, transfer or withdraw somebody else's
    /// shares without allowance, including after user capital is leveraged.
    function test_13_reject_unauthorized_user_share_spending_and_preserve_full_exit() public {
        _deploy();
        _configure();
        _configureScheduledRedeemSwap();
        _fundAndDeposit(10_000_000);
        _openNft();
        _up();
        uint256 shares = IERC20(VAULT).balanceOf(USER);
        State memory initial = _state();
        _tx("reject_third_party_redeem_user_shares", UNAUTHORIZED, VAULT,
            abi.encodeWithSignature("redeem(uint256,address,address)", shares / 10, UNAUTHORIZED, USER), false);
        _tx("reject_third_party_withdraw_user_assets", UNAUTHORIZED, VAULT,
            abi.encodeWithSignature("withdraw(uint256,address,address)", uint256(10_000), UNAUTHORIZED, USER), false);
        _tx("reject_unapproved_transfer_from_user", UNAUTHORIZED, VAULT,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", USER, UNAUTHORIZED, shares / 10), false);
        require(_sameAccounting(initial, _state()), "Unauthorized call changed account state");
        _fullScheduledExit();
        _assertUserFullyExitedWithOnlyFeeAccountDust();
    }
    /// @notice The nonterminal withdrawal path must reduce principal debt
    /// safely, preserve the remaining user's position, and not strand the
    /// subsequent 100% exit request behind native f(x) cooldown state.
    function test_14_partial_scheduled_withdrawal_then_remaining_full_exit() public {
        _deploy();
        _configure();
        _configureScheduledRedeemSwap();
        _fundAndDeposit(10_000_000);
        _openNft();
        _up();
        State memory original = _state();
        uint256 partialShares = original.userShares / 4;
        require(partialShares > 0 && partialShares < original.userShares, "Partial setup invalid");
        _tx("partial_user_requests_quarter_shares", USER, WITHDRAW_MANAGER,
            abi.encodeWithSignature("requestShares(uint256)", partialShares), true);
        _tx("partial_user_authorizes_manager", USER, VAULT,
            abi.encodeWithSignature("approve(address,uint256)", address(ltvManager), partialShares), true);
        _tx("public_starts_partial_exit", PUBLIC_CALLER, address(publicExecutor),
            abi.encodeWithSignature("InitializeFulfillWithdrawRequest(address)", USER), true);
        uint256 unlockAt = _pendingUnlock();
        require(unlockAt >= block.timestamp + 3600, "Missing partial cooldown");
        State memory scheduled = _state();
        require(scheduled.userShares == original.userShares, "Request prematurely burned user shares");
        vm.warp(unlockAt + 2);
        vm.roll(block.number + 20);
        _snapshot("partial_matured_before_public_finalizations");
        for (uint256 i; i < 8 && _pendingUnlock() != 0; i++) {
            _tx(string.concat("public_completes_partial_step_", vm.toString(i)),
                PUBLIC_CALLER, address(publicExecutor),
                abi.encodeWithSignature("FinalizeFulfillWithdrawRequest()"), true);
        }
        require(_pendingUnlock() == 0, "Partial withdrawal never finalized");
        State memory partiallyExited = _state();
        require(partiallyExited.userShares > 0 && partiallyExited.userShares < original.userShares,
            "Partial withdrawal did not leave correct remaining shares");
        require(partiallyExited.userWBTC > original.userWBTC, "Partial withdrawal delivered no WBTC");
        require(partiallyExited.rawDebt > 0 && partiallyExited.rawDebt < original.rawDebt,
            "Partial withdrawal did not reduce fxMINT principal safely");
        require(partiallyExited.managerLtv <= TARGET,
            "Partial withdrawal left position above owner 60pct LTV target");
        _snapshot("partial_exit_settled_safe");
        _fullScheduledExit();
        _assertUserFullyExitedWithOnlyFeeAccountDust();
    }
}

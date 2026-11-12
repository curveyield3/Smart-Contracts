// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ITokenizedStrategy} from "@tokenized-strategy/interfaces/ITokenizedStrategy.sol";
import {FXNYearnMasterAllocator} from "../contracts/FXNYearnMasterAllocator.sol";
import {FXNCurveRewardRouter} from "../contracts/FXNCurveRewardRouter.sol";
import {Accountant} from "../contracts/Accountant.sol";
import {CurveConvex32YearnStrategy} from "../contracts/CurveConvex32YearnStrategy.sol";
import {FxBaseConvex37YearnStrategy} from "../contracts/FxBaseConvex37YearnStrategy.sol";
import {FXNZeroNAVRewardChild} from "../contracts/FXNZeroNAVRewardChild.sol";

interface IFactoryFxUSDV1 {
    function apiVersion() external view returns (string memory);
    function deploy_new_vault(address asset, string calldata name,
        string calldata symbol, address roleManager, uint256 profitMaxUnlockTime)
        external returns (address);
}
interface IYearnVaultFxUSDV1 {
    function asset() external view returns (address);
    function role_manager() external view returns (address);
    function profitMaxUnlockTime() external view returns (uint256);
    function set_role(address account, uint256 roles) external;
    function set_accountant(address accountant) external;
    function accountant() external view returns (address);
    function add_strategy(address strategy) external;
    function update_max_debt_for_strategy(address strategy, uint256 debt) external;
    function set_default_queue(address[] calldata queue) external;
    function set_use_default_queue(bool enabled) external;
    function set_auto_allocate(bool enabled) external;
    function withdraw_hook() external view returns (address);
    function auto_allocate() external view returns (bool);
    function use_default_queue() external view returns (bool);
    function get_default_queue() external view returns (address[] memory);
    function set_minimum_total_idle(uint256 amount) external;
    function set_deposit_limit(uint256 cap) external;
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function transfer_role_manager(address newRoleManager) external;
}

/// @notice Ethereum Yearn V3.1.0 factory deployment reference, adapted from
///         supplied DeployCurveYieldVbUSDCYearn_v16.s.sol (Katana).
/// @dev Protocol/pool/token addresses are environment-supplied; the published
///      Ethereum Yearn V3.1.0 factory and implementation default to the
///      official version-pinned release. This is NOT a funded deployment or
///      verification of the selected Curve pools and Convex routes.
contract DeployFXUSDYearnV18 is Script {
    using SafeERC20 for IERC20;
    uint256 internal constant ROLE_ALL = 16_383;
    // Yearn's published 3.1.0 Ethereum release (verified in official
    // yearn/yearn-devdocs/src/ethereum/constants.ts).
    address internal constant OFFICIAL_FACTORY_3_1_0 = 0x310aC28ACF5E514abDbFF9Ab25e21f1bfe22bcAC;
    address internal constant OFFICIAL_TOKENIZED_3_1_0 = 0x310f5Db015E9d6E542fd41bd4542640790791e76;
    event RewardRouterDeployed(address indexed router);
    event FXNZeroNAVChildDeployed(address indexed child, address indexed curveLP, address indexed boostHub);
    event VaultAccountantDeployed(address indexed accountant, uint16 managementFeeBps,
        uint16 performanceFeeBps, address indexed feeRecipient);
    event Deployed(address indexed vault, address indexed master,
        address indexed curve32Child, address fxBase37Child);

    function run() external returns (address vault, address master, address child32, address child37) {
        require(block.chainid == 1, "Ethereum mainnet/fork required");
        address fxusd = vm.envAddress("FXUSD");
        address fxn = vm.envAddress("FXN");
        address weth = vm.envAddress("WETH");
        address usdc = vm.envAddress("USDC");
        address factory = vm.envOr("YEARN_V3_FACTORY", OFFICIAL_FACTORY_3_1_0);
        address impl = vm.envOr("YEARN_TOKENIZED_STRATEGY_IMPL", OFFICIAL_TOKENIZED_3_1_0);
        require(factory == OFFICIAL_FACTORY_3_1_0 && impl == OFFICIAL_TOKENIZED_3_1_0,
            "unexpected Yearn Ethereum 3.1.0 release");
        address booster = vm.envAddress("CONVEX_FX_BOOSTER");
        address registry = vm.envAddress("CONVEX_FX_POOL_REGISTRY");
        address gauge32 = vm.envAddress("CONVEX_FX_GAUGE_32");
        address gauge37 = vm.envAddress("CONVEX_FX_GAUGE_37");
        address gauge8 = vm.envAddress("CONVEX_FX_GAUGE_8");
        address sdFXN = vm.envAddress("SDFXN");
        address sdFXNCurveLP = vm.envOr("CURVE_SDFXN_FXN_POOL", address(0x28Ca243dc0aC075dD012fCf9375C25D18A844d96));
        address boostHub = vm.envAddress("BOOSTHUB");
        uint256 boostHubPid = vm.envOr("BOOSTHUB_SDFXN_PID", uint256(1));
        address fxBase = vm.envAddress("FXBASE_POOL");
        address curveStable = vm.envAddress("CURVE_USDC_FXUSD_POOL");
        address curveFXN = vm.envAddress("CURVE_FXN_WETH_POOL");
        address curveTri = vm.envAddress("CURVE_WETH_USDC_POOL");
        address owner = vm.envAddress("VAULT_OWNER");
        address keeper = vm.envAddress("HARVEST_KEEPER");
        address vaultFeeRecipient = vm.envOr("VAULT_FEE_RECIPIENT", owner);
        uint256 annualManagementFeeBps = vm.envOr("VAULT_MANAGEMENT_FEE_BPS", uint256(0));
        uint256 performanceFeeBps = vm.envOr("VAULT_PERFORMANCE_FEE_BPS", uint256(1_000));
        require(annualManagementFeeBps <= 100 && performanceFeeBps <= 2_000,
            "fee exceeds permitted bounds");
        require(vaultFeeRecipient != address(0), "missing fee recipient");
        uint256 seed = vm.envOr("INITIAL_FXUSD_SEED", uint256(0));
        uint256 vaultCap = vm.envOr("FXUSD_DEPOSIT_CAP", type(uint256).max);
        uint256 key = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(key);
        require(owner != address(0) && keeper != address(0), "missing operator");
        require(factory.code.length > 0 && impl.code.length > 0, "Yearn missing");
        require(keccak256(bytes(IFactoryFxUSDV1(factory).apiVersion())) ==
            keccak256(bytes("3.1.0")), "expected v3.1.0 factory");
        require(keccak256(bytes(ITokenizedStrategy(impl).apiVersion())) ==
            keccak256(bytes("3.1.0")), "expected v3.1.0 tokenized strategy");
        require(seed <= vaultCap, "seed exceeds cap");

        vm.startBroadcast(key);
        FXNCurveRewardRouter router = new FXNCurveRewardRouter(
            fxusd, fxn, weth, usdc, curveFXN, curveTri, curveStable
        );
        FXNYearnMasterAllocator m = new FXNYearnMasterAllocator(
            fxusd, fxn, impl, address(router)
        );
        master = address(m);
        router.bindMaster(master);
        emit RewardRouterDeployed(address(router));
        CurveConvex32YearnStrategy c32 = new CurveConvex32YearnStrategy(
            fxusd, fxn, master, owner, booster, registry, gauge32, curveStable, impl
        );
        FxBaseConvex37YearnStrategy c37 = new FxBaseConvex37YearnStrategy(
            fxusd, usdc, fxn, master, owner, booster, registry, gauge37, fxBase, curveStable, impl
        );
        child32 = address(c32);
        child37 = address(c37);

        FXNZeroNAVRewardChild engine = new FXNZeroNAVRewardChild(
            fxusd, fxn, sdFXN, master, owner, booster, registry,
            gauge8, sdFXNCurveLP, boostHub, boostHubPid, impl
        );
        m.setFXNRewardChild(address(engine));
        emit FXNZeroNAVChildDeployed(address(engine), sdFXNCurveLP, boostHub);
        ITokenizedStrategy(address(engine)).setKeeper(master);
        ITokenizedStrategy(address(engine)).setProfitMaxUnlockTime(0);
        ITokenizedStrategy(child32).setKeeper(master);
        ITokenizedStrategy(child37).setKeeper(master);
        ITokenizedStrategy(child32).setProfitMaxUnlockTime(0);
        ITokenizedStrategy(child37).setProfitMaxUnlockTime(0);
        ITokenizedStrategy(master).setProfitMaxUnlockTime(0);
        require(ITokenizedStrategy(child32).profitMaxUnlockTime() == 0 &&
            ITokenizedStrategy(child37).profitMaxUnlockTime() == 0 &&
            ITokenizedStrategy(master).profitMaxUnlockTime() == 0,
            "strategy profit unlock must be zero");
        ITokenizedStrategy(master).setKeeper(keeper);
        // Initial two routes receive 55% / 45%. Future FXN-compatible
        // Yearn children register through m.addChild(child) at 0% allocation;
        // owner explicitly activates them with m.setStrategyAllocations(...).
        m.bindChildren(child32, child37);

        vault = IFactoryFxUSDV1(factory).deploy_new_vault(
            fxusd, "CurveYield fxUSD", "cyfxUSD", deployer, 0
        );
        IYearnVaultFxUSDV1 v = IYearnVaultFxUSDV1(vault);
        require(v.asset() == fxusd && v.role_manager() == deployer, "vault mismatch");
        require(v.profitMaxUnlockTime() == 0, "vault profit unlock must be zero");
        v.set_role(deployer, ROLE_ALL);
        // The vault alone consults its accountant during process_report();
        // children do not assess these fees again, avoiding double charging.
        // Official Yearn vault-periphery Accountant.sol with ONLY its two
        // fee threshold constants lowered to 1% management / 20% performance.
        // Refunds disabled; health-check thresholds are 0/10000 to preserve
        // original reporting behavior without extra loss/gain gates.
        Accountant accountant = new Accountant(
            deployer, vaultFeeRecipient,
            uint16(annualManagementFeeBps), uint16(performanceFeeBps),
            0, 0, 0, 10_000
        );
        accountant.addVault(vault);
        require(accountant.vaults(vault), "vault not added to accountant");
        v.set_accountant(address(accountant));
        require(v.accountant() == address(accountant) &&
            accountant.feeManager() == deployer &&
            accountant.feeRecipient() == vaultFeeRecipient &&
            accountant.MANAGEMENT_FEE_THRESHOLD() == 100 &&
            accountant.PERFORMANCE_FEE_THRESHOLD() == 2_000,
            "vault fee configuration mismatch");
        (uint16 configuredManagement, uint16 configuredPerformance,,,,,) = accountant.defaultConfig();
        require(configuredManagement == annualManagementFeeBps &&
            configuredPerformance == performanceFeeBps,
            "vault initial fee rates mismatch");
        emit VaultAccountantDeployed(address(accountant),
            uint16(annualManagementFeeBps), uint16(performanceFeeBps), vaultFeeRecipient);
        v.add_strategy(master);
        m.bindYearnVault(vault);
        m.setCooldownFeeRecipient(owner);
        require(m.minCooldownShares() == 10 ** uint256(IERC20Metadata(vault).decimals()),
            "cooldown minimum not one full share");
        v.update_max_debt_for_strategy(master, type(uint256).max);
        address[] memory queue = new address[](1);
        queue[0] = master;
        v.set_default_queue(queue);
        v.set_use_default_queue(true);
        v.set_deposit_limit(vaultCap);
        // Public cooldown withdrawals escrow shares directly in the master;
        // settled fxUSD stays reserved in its own balance until native claim. Factory deposit hooks are NOT
        // modified, and original Yearn vault shares burn only at claim.
        // No approval-based withdrawal hook. Pool 32 and fxBASE Pool 37
        // use native Yearn accepted-loss redeem to charge each exit only.
        // Standard withdraw(max_loss=0) rejects losses; redeem(max_loss)
        // lets the caller accept a lower payout without extra approval.
        // Yearn VaultV3_v3.1.0 _deposit calls _update_debt on queue[0]
        // atomically when auto_allocate is enabled. Zero minimum idle sends
        // the full deposited amount into the master for child fan-out.
        v.set_minimum_total_idle(0);
        v.set_auto_allocate(true);
        address[] memory liveQueue = v.get_default_queue();
        require(v.auto_allocate() && v.use_default_queue() &&
            liveQueue.length == 1 && liveQueue[0] == master,
            "vault atomic-deposit configuration mismatch");
        if (seed != 0) {
            IERC20(fxusd).forceApprove(vault, seed);
            v.deposit(seed, owner);
            IERC20(fxusd).forceApprove(vault, 0);
        }
        // Ownership handoff follows Yearn's two-step pending-management
        // process, as in the attached v16 reference. The final owner accepts.
        ITokenizedStrategy(address(engine)).setPendingManagement(owner);
        ITokenizedStrategy(child32).setPendingManagement(owner);
        ITokenizedStrategy(child37).setPendingManagement(owner);
        ITokenizedStrategy(master).setPendingManagement(owner);
        router.transferOwnership(owner);
        // Official Accountant requires the new fee manager to explicitly accept.
        // The deployer can register the vault first; owner accepts afterwards.
        if (deployer != owner) accountant.setFutureFeeManager(owner);
        v.set_role(owner, ROLE_ALL);
        if (deployer != owner) {
            v.set_role(deployer, 0);
            v.transfer_role_manager(owner);
        }
        emit Deployed(vault, master, child32, child37);
        vm.stopBroadcast();
    }
}
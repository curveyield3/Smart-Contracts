// FRA XTAL V1: Derived from pinned v35 source; only deploys on Fraxtal chain 252.
// Target owner + every controllable fee receiver: 0x9f2B20A772246960810045905B7daccf960eE288.
// Broadcast ONLY by signer 0x064256591313eEb86a84A5CbCc4C6460791B96DD.
// Hub parity factory 0x018D5b5A684F5DA8cb629fBB7FE8661b1c07f6D2 with exact Ethereum salt.
// HUB OWNERSHIP: queued here; target owner must call executeTransactions() after deployment.
// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {CurveYieldOmniRouter} from "../contracts/CurveYieldOmniRouter.sol";
import {BeefyVaultV7Factory} from "../beefy-partner/contracts/BIFI/vaults/BeefyVaultV7Factory.sol";
import {BoostHubPartnerPairDeployerV4} from "../beefy-partner/contracts/BIFI/strategies/BoostHub/BoostHubPartnerPairDeployerV4.sol";
import {IStrategyFactory} from "../beefy-partner/contracts/BIFI/interfaces/beefy/IStrategyFactory.sol";
import {IFeeConfig} from "../beefy-partner/contracts/BIFI/interfaces/common/IFeeConfig.sol";
import {BaseAllToWantBoostHubV5} from "../contracts/BaseAllToWantBoostHubV5.sol";
import {StrategyConvexBoostHubStakingV5} from "../contracts/StrategyConvexBoostHubStakingV5.sol";
import {BeefyVaultV7FixedV2} from "../contracts/BeefyVaultV7FixedV2.sol";
import {IStrategyBoostHubV1} from "../contracts/interfaces/IStrategyBoostHubV1.sol";

import {BoostHub} from "../contracts/BoostHub.sol";
import {BoostHubDeploymentFactory} from "../contracts/BoostHubDeploymentFactory_v1.sol";

/// @dev The already-installed Forge/Anvil runner owns transaction signing.
///      It does not invoke forge-std, a private key, shell commands, FFI,
///      or a second deployment script.
interface VmBoostHub {
    function readFile(string calldata path) external view returns (string memory);
    function parseJsonBytes(string calldata json, string calldata key) external pure returns (bytes memory);
    function parseJsonString(string calldata json, string calldata key) external pure returns (string memory);
    function parseJsonBytes32(string calldata json, string calldata key) external pure returns (bytes32);
    function getNonce(address account) external view returns (uint64);
    function computeCreateAddress(address deployer, uint256 nonce) external pure returns (address);
    function startBroadcast() external;
    function stopBroadcast() external;
}

/// @dev Minimal Foundry Script interface; no forge-std dependency.
abstract contract Script {
    VmBoostHub internal constant vm = VmBoostHub(address(uint160(uint256(keccak256("hevm cheat code")))));
}

interface IBoostHubStaking {
    function lp_token() external view returns (address);
    function boost_hub() external view returns (address);
    function pid() external view returns (uint256);
    function fee_receiver() external view returns (address);
    function commit_transfer_ownership(address newAdmin) external;
}

interface IBoostHubStrategy {
    function vault() external view returns (address);
    function want() external view returns (address);
}

interface IBoostHubVault {
    function strategy() external view returns (address);
    function want() external view returns (address);
}

interface IERC20PartnerMetadata {
    function decimals() external view returns (uint8);
}

/// @notice ONE unified native Foundry deployment and configuration entry point.
/// @dev Deploys the shared-address CREATE3 Hub plus ordinary CREATE staking instances.
///      On Ethereum deploys 2 original vault/strategy pairs plus 2 complementary
///      official Beefy V7 partner pairs. On Fraxtal deploys 1 original pair
///      plus 1 official Beefy V7 partner pair. Each chain deploys its own Omni
///      router and configures its reward/oracle routes in THIS same run().
///      Both chains reuse their existing distributor contracts (Fraxtal URD,
///      Ethereum MultiMerkleStash) for the Hub-integrated Merkle claim methods.
///      No other deployment script is called. Forge compiles all Solidity
///      dependencies directly from these source imports. The build helper stages
///      Vyper 0.4.3 staking bytecode from tooling/make_staking_artifact.py.
///      This script refuses artifacts compiled from a different staking source.
///
///      Only the Hub uses shared CREATE3 address parity; staking is ordinary CREATE.
///      Same factory bytecode/address, deployment ID, and Hub salt
///      MUST be used on both chains. Broadcasting EOAs and nonces may differ. Constructor arguments may differ. This does
///      not autonomously accept pending Hub/Staking ownership.
contract DeployBoostHubFraxtal_v1 is Script {
    address private constant EXPECTED_HUB = 0x40f7085841034f752F17592875703EB5032f2B42;
    address private constant EXPECTED_FACTORY = 0x018D5b5A684F5DA8cb629fBB7FE8661b1c07f6D2;
    bytes32 private constant EXPECTED_HUB_SALT = 0x59f389db9f6874ff387e92bb1728aba09898f253df88506d3a9fe29f829274d9;
    address private constant BROADCASTER = 0x064256591313eEb86a84A5CbCc4C6460791B96DD;
    address private constant FINAL_OWNER = 0x9f2B20A772246960810045905B7daccf960eE288;
    event FraxtalFinalOwnershipPending(address indexed boostHub,address indexed from,address indexed requestedOwner);

    address private constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    bytes32 private constant CREATE2_DEPLOYER_CODEHASH =
        0x2fa86add0aed31f33a762c9d88e807c475bd51d0f52bd0955754b2608f7e4989;
    bytes32 private constant FACTORY_SALT = keccak256("CurveYield.BoostHubDeploymentFactory.v1");
    // New, chain-shared salt namespace: do NOT collide with previously deployed v6 hubs.
    string private constant DEPLOYMENT_ID = "CurveYield.BoostHub.Stack.v16";
    address private constant FRAXTAL_URD = 0xAeB87C92b2E7d3b21fA046Ae1E51E0ebF11A41Af;
    address private constant FRAXTAL_SDFXS = 0x1AEe2382e05Dc68BDfC472F1E46d570feCca5814;
    address private constant FRAXTAL_GAUGE = 0x12992595328E52267c95e45B1a97014D6Ddf8683;
    address private constant FRAXTAL_FRAX_REWARD = 0xFc00000000000000000000000000000000000002;
    address private constant VL_BOOST = 0xaB05ca46d1c78CAbB051efFE35099714Cad2AddA;
    address private constant STASH = 0x03E34b085C52985F6a5D27243F20C84bDdc01Db4;
    address private constant FEE_RECEIVER = 0x9f2B20A772246960810045905B7daccf960eE288;

    address private constant ASSET_0 = 0xD1b5651E55D4CeeD36251c61c50C889B36F6abB5;
    address private constant GAUGE_0 = 0x7f50786A0b15723D741727882ee99a0BF34e3466;
    address private constant ASSET_1 = 0xe19d1c837B8A1C83A56cD9165b2c0256D39653aD;
    address private constant GAUGE_1 = 0xbcfE5c47129253C6B8a9A00565B3358b488D42E0;

    /// @dev Conservative audit-fork economics; do not claim these are approved
    ///      mainnet fee settings. They do not inhibit normal deposit operations.
    uint16 private constant PERFORMANCE_FEE_BPS = 300;
    uint16 private constant CALL_SHARE_BPS = 1000;
    uint16 private constant ADMIN_SHARE_BPS = 9000;
    uint256 private constant VAULT_WITHDRAWAL_FEE_BPS = 0;
    uint256 private constant STRATEGY_LOCK_DURATION_SECONDS = 72 hours;
    uint256 private constant MIN_REWARD_OUTPUT_WANT_BASE_UNITS = 0;
    struct CompilerArtifact {
        bytes creation;
        bytes runtime;
    }

    address private constant ETH_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant ETH_CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    address private constant ETH_CRVUSD = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E;
    address private constant ETH_WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address private constant ETH_FXN = 0x365AccFCa291e7D3914637ABf1F7635dB165Bb09;
    address private constant FRAX_WFRAX = 0xFc00000000000000000000000000000000000002;

    // These *are* the reward-to-want pools read from the verified legacy
    // 2026 BoostHub downstream converters, not speculative routing addresses.
    address private constant ETH_CRV_SDCRV_POOL = 0xCA0253A98D16e9C1e3614caFDA19318EE69772D0;
    address private constant ETH_CRVUSD_WETH_POOL = 0x4eBdF703948ddCEA3B11f675B4D1Fba9d2414A14;
    address private constant ETH_WETH_FXN_POOL = 0xC15F285679a1Ef2d25F53D4CbD0265E1D02F2A92;
    address private constant ETH_FXN_SDFXN_POOL = 0x28Ca243dc0aC075dD012fCf9375C25D18A844d96;
    // V3 pools for the rewards actually verified on the older Ethereum deployment.
    address private constant ETH_CRV_WETH_V3 = 0x919Fa96e88d67499339577Fa202345436bcDaf79; // 0.30%
    address private constant ETH_WSTETH_WETH_V3 = 0xD340B57AAcDD10F96FC1CF10e15921936F41E29c; // 0.05%
    address private constant FRAX_WFRAX_SDFXS_POOL = 0x3df1658e3E76d14eF3C4d410829EA7575bB83B9B;

    address private constant ETH_BEEFY_VAULT_FACTORY = 0xC551dDCE8e5E657503Cd67A39713c06F2c0d2e97;
    address private constant ETH_BEEFY_STRATEGY_FACTORY = 0x52941De3eDE234ae6B8608597440Ac3394C64Ae8;
    // Beefy's published Fraxtal vault factory. Deployment preflight verifies its
    // implementation before use; never deploy a parallel vault factory.
    address private constant FRAX_BEEFY_VAULT_FACTORY = 0x91BB303E972995EbE5f593BCddBb6F5Ef49Dbcbd;
    address private constant FRAX_BEEFY_STRATEGY_FACTORY = 0x4b5f7De737531673B23ceB43D45ea3f1297e4C6d;


    event UnifiedCore(address indexed hub, address indexed localDeployer);
    event DeterministicFactory(address indexed factory, bytes32 indexed factorySalt);
    event CrossChainAddress(uint256 indexed chainId, bytes32 indexed salt, address indexed deployed);
    event UnifiedStaking(uint256 indexed pid, address indexed staking);
    event UnifiedBeefy(uint256 indexed pid, address indexed strategy, address indexed vault);
    event UnifiedOmniRouter(uint256 indexed chainId, address indexed router, address indexed finalOwner);
    event PartnerFactorySelected(uint256 indexed chainId, address indexed vaultFactory, address indexed feeConfigFactory);
    event PartnerDeployed(uint256 indexed chainId, uint256 indexed pid, address indexed strategy, address vault);
    event PartnerFeeReviewRequired(address indexed strategy, uint256 totalPerformanceFee, uint256 callerShare);
    event PartnerOwnershipHandoffPending(address indexed strategy, address indexed vault, address strategyOwner, address vaultOwner);
    event FraxtalRewardsDistributor(address indexed urd, address indexed hub);
    event PendingExternalOwnership(address indexed hub, address indexed owner);

    /// @notice Deploys on exactly one supported chain per invocation.
    /// @dev Broadcasting EOAs and nonces may differ between Ethereum and Fraxtal.
    function run() external {
        // This is a Fraxtal-only script. All transactions must originate from the
        // Blockchain Operations Hub's connected signer, not the final owner.
        require(block.chainid == 252, "BOOSTHUB_FRAXTAL_ONLY");
        bool isEthereum = false;
        address broadcaster = msg.sender;
        require(broadcaster == BROADCASTER, "BOOSTHUB_SIGNER_MISMATCH");

        address distributor = isEthereum ? STASH : FRAXTAL_URD;
        address boost = isEthereum ? VL_BOOST : address(0);
        require(distributor.code.length != 0, "BOOSTHUB_DISTRIBUTOR_MISSING_ON_CHAIN");
        if (!isEthereum) {
            require(FRAXTAL_SDFXS.code.length > 0 && FRAXTAL_GAUGE.code.length > 0
                && FRAXTAL_FRAX_REWARD.code.length > 0, "FRAXTAL_POOL_DEPENDENCY_MISSING");
            // Reject a non-URD target rather than deploying an unusable claim path.
            (bool rootReadable, bytes memory rootData) =
                FRAXTAL_URD.staticcall(abi.encodeWithSignature("root()"));
            require(rootReadable && rootData.length == 32, "FRAXTAL_URD_INTERFACE_MISMATCH");
        }
        require(CREATE2_DEPLOYER.codehash == CREATE2_DEPLOYER_CODEHASH,
            "BOOSTHUB_CREATE2_DEPLOYER_MISMATCH");
        _preflightPartnerDependencies(isEthereum);
        CompilerArtifact memory stakingArtifact = _loadStakingArtifact();

        (address[] memory assets, address[] memory gauges, address[][] memory rewards) =
            isEthereum ? _ethereumPools() : _fraxtalPools();

        // The single deterministic CREATE2 factory is deployed with identical bytecode
        // and factory salt on both chains. Its address is independent of EOA nonce.
        address predictedFactory = _predictFactory();
        require(predictedFactory == EXPECTED_FACTORY, "BOOSTHUB_FACTORY_PARITY_MISMATCH");
        vm.startBroadcast();
        if (predictedFactory.code.length == 0) {
            (bool ok,) = CREATE2_DEPLOYER.call(
                abi.encodePacked(FACTORY_SALT, type(BoostHubDeploymentFactory).creationCode)
            );
            require(ok, "BOOSTHUB_FACTORY_CREATE2_FAILED");
        }
        require(predictedFactory.codehash == keccak256(type(BoostHubDeploymentFactory).runtimeCode),
            "BOOSTHUB_FACTORY_RUNTIME_MISMATCH");
        emit DeterministicFactory(predictedFactory, FACTORY_SALT);
        BoostHubDeploymentFactory factory = BoostHubDeploymentFactory(predictedFactory);

        bytes32 hubSalt = _deploymentSalt("hub");
        require(hubSalt == EXPECTED_HUB_SALT, "BOOSTHUB_SALT_PARITY_MISMATCH");
        address expectedHub = factory.getDeployed(broadcaster, hubSalt);
        require(expectedHub == EXPECTED_HUB, "BOOSTHUB_ETHEREUM_ADDRESS_PARITY_MISMATCH"); // deployer parameter retained for ABI compatibility; salt is caller-independent
        require(expectedHub.code.length == 0, "BOOSTHUB_HUB_SALT_ALREADY_USED");
        address deployedHub = factory.deploy(hubSalt, abi.encodePacked(
            type(BoostHub).creationCode, abi.encode(broadcaster, boost, distributor)
        ));
        require(deployedHub == expectedHub, "BOOSTHUB_HUB_ADDRESS_MISMATCH");
        BoostHub hub = BoostHub(payable(deployedHub));
        require(hub.owner() == broadcaster && hub.rewardDistributor() == distributor,
            "BOOSTHUB_HUB_CONSTRUCTOR_MISMATCH");
        emit UnifiedCore(deployedHub, broadcaster);
        emit CrossChainAddress(block.chainid, hubSalt, deployedHub);
        hub.addPoolsBatch(assets, gauges, rewards);

        address[] memory staking = _deployAllStaking(
            stakingArtifact, deployedHub, broadcaster, assets, rewards, isEthereum
        );
        _configureHub(hub, staking, isEthereum);
        // Initial fee configurations are ready immediately during initial setup.
        hub.executeTransactions();

        // Deploy and configure the SAME chain-local Omni for the original and
        // new Beefy partner strategies. No external Fraxtal adapter is needed.
        CurveYieldOmniRouter omni = new CurveYieldOmniRouter(broadcaster, FEE_RECEIVER);
        address swapper = address(omni);
        if (isEthereum) _configureEthereumRoutes(omni);
        else _configureFraxtalRoutes(omni);

        // Custom BoostHub pairs use the same chain-local Omni as the protected
        // Beefy partner pairs; their v30 simplifications do not alter partner sources.
        for (uint256 pid; pid < assets.length; ++pid) {
            _deployBeefyPair(pid, broadcaster, staking[pid], assets[pid], swapper);
        }
        if (!isEthereum) {
            // URD remains the claim verifier; future roots must include this Hub.
            emit FraxtalRewardsDistributor(FRAXTAL_URD, deployedHub);
        }

        // Complementary partners use Beefy's EXISTING V7 vault clone factory.
        // The BoostHub strategies are independently deployed on BOTH chains;
        // Beefy's strategy factory only provides its fee/keeper/pause settings.
        // The helper creates and initializes the vault and strategy atomically
        // in this same unified run().
        BoostHubPartnerPairDeployerV4 partnerDeployer = new BoostHubPartnerPairDeployerV4(broadcaster);
        address vaultFactory = isEthereum ? ETH_BEEFY_VAULT_FACTORY : FRAX_BEEFY_VAULT_FACTORY;
        address strategyFactory = isEthereum ? ETH_BEEFY_STRATEGY_FACTORY : FRAX_BEEFY_STRATEGY_FACTORY;
        emit PartnerFactorySelected(block.chainid, vaultFactory, strategyFactory);
        for (uint256 pid; pid < assets.length; ++pid) {
            _deployPartnerPair(partnerDeployer, vaultFactory,
                staking[pid], assets[pid], strategyFactory, swapper, broadcaster, pid);
        }
        // The router has immediate ownership transfer; the Hub has a queued
        // two-step ownership flow which only FINAL_OWNER can accept. Never impersonate
        // FINAL_OWNER on mainnet or claim the transfer finished prematurely.
        omni.transferOwnership(FINAL_OWNER);
        require(omni.owner() == FINAL_OWNER && omni.feeRecipient() == FEE_RECEIVER,
            "BOOSTHUB_ROUTER_FINAL_OWNER_MISMATCH");
        hub.transferOwnership(FINAL_OWNER);
        require(hub.owner() == broadcaster, "BOOSTHUB_OWNER_PENDING_EXPECTED");
        emit FraxtalFinalOwnershipPending(deployedHub,broadcaster,FINAL_OWNER);
        emit UnifiedOmniRouter(block.chainid, swapper, FINAL_OWNER);
        vm.stopBroadcast();
    }

    function _predictFactory() internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff), CREATE2_DEPLOYER, FACTORY_SALT,
            keccak256(type(BoostHubDeploymentFactory).creationCode)
        )))));
    }

    function _deploymentSalt(string memory label) internal pure returns (bytes32) {
        return keccak256(bytes(string.concat(DEPLOYMENT_ID, "/", label)));
    }

    function _loadStakingArtifact() internal view returns (CompilerArtifact memory artifact) {
        string memory json = vm.readFile("artifacts/staking.json");
        require(
            vm.parseJsonBytes32(json, ".sourceSha256") == sha256(bytes(vm.readFile("contracts/BoostHubStaking.vy"))),
            "STAKING_SOURCE_ARTIFACT_MISMATCH"
        );
        require(
            keccak256(bytes(vm.parseJsonString(json, ".compilerVersion"))) == keccak256("0.4.3"),
            "STAKING_COMPILER_VERSION_MISMATCH"
        );
        artifact.creation = vm.parseJsonBytes(json, ".bytecode");
        artifact.runtime = vm.parseJsonBytes(json, ".deployedBytecode");
        require(artifact.creation.length > 100 && artifact.runtime.length > 100, "BOOSTHUB_STAKING_BYTECODE_MISSING");
    }
    function _deployAllStaking(
        CompilerArtifact memory a, address hub, address broadcaster,
        address[] memory assets, address[][] memory rewards, bool isEthereum
    ) internal returns (address[] memory staking) {
        staking = new address[](assets.length);
        for (uint256 pid; pid < assets.length; ++pid) {
            address[8] memory constructorRewards;
            uint256 outIndex;
            for (uint256 i; i < rewards[pid].length; ++i) {
                if (rewards[pid][i] == assets[pid]) continue;
                require(outIndex < 8, "BOOSTHUB_REWARD_LIMIT");
                constructorRewards[outIndex++] = rewards[pid][i];
            }
            // 150 units x 8,640 seconds = 15 days; applies to sdCRV, sdFXN, sdFXS.
            uint256 smoothing = 150;
            // Staking addresses do NOT need cross-chain parity. Ordinary CREATE
            // removes needless factory salts/caller constraints for these contracts.
            bytes memory creation = abi.encodePacked(
                a.creation, abi.encode(assets[pid], hub, pid, FINAL_OWNER, constructorRewards, FEE_RECEIVER, smoothing)
            );
            address instanceAddress;
            assembly {
                instanceAddress := create(0, add(creation, 0x20), mload(creation))
            }
            require(instanceAddress != address(0), "BOOSTHUB_STAKING_CREATE_FAILED");
            staking[pid] = instanceAddress;
            // Vyper 0.4.3 appends the three immutables (lp_token, boost_hub,
            // pid) as 32-byte values after the compiler's base runtime code.
            // Compare that entire code segment, then verify the immutable trailer
            // AND the public getters. A full codehash comparison is invalid here.
            uint256 runtimeLength = a.runtime.length;
            require(instanceAddress.code.length == runtimeLength + 96,
                "BOOSTHUB_STAKING_RUNTIME_LENGTH_MISMATCH");
            bytes memory deployedRuntime = new bytes(runtimeLength);
            bytes memory deployedImmutables = new bytes(96);
            assembly {
                extcodecopy(instanceAddress, add(deployedRuntime, 0x20), 0, runtimeLength)
                extcodecopy(instanceAddress, add(deployedImmutables, 0x20), runtimeLength, 96)
            }
            require(keccak256(deployedRuntime) == keccak256(a.runtime),
                "BOOSTHUB_STAKING_RUNTIME_MISMATCH");
            require(keccak256(deployedImmutables) == keccak256(abi.encode(assets[pid], hub, pid)),
                "BOOSTHUB_STAKING_IMMUTABLES_MISMATCH");
            IBoostHubStaking instance = IBoostHubStaking(instanceAddress);
            require(instance.lp_token() == assets[pid] && instance.boost_hub() == hub && instance.pid() == pid
                && instance.fee_receiver() == FEE_RECEIVER, "BOOSTHUB_STAKING_BINDING_MISMATCH");
            // Admin was initialized as broadcaster; do not create a pending handoff.
            emit UnifiedStaking(pid, instanceAddress);
        }
    }

    function _configureHub(BoostHub hub, address[] memory staking, bool isEthereum) internal {
        uint256[] memory pids = new uint256[](staking.length);
        bool[] memory locked = new bool[](staking.length);
        bytes4[] memory selectors = new bytes4[](staking.length);
        BoostHub.FeeConfig[] memory fees = new BoostHub.FeeConfig[](staking.length);
        bool[] memory active = new bool[](staking.length);
        for (uint256 pid; pid < staking.length; ++pid) {
            pids[pid] = pid;
            selectors[pid] = !isEthereum ? bytes4(0) : bytes4(0x4b820093);
            fees[pid] = BoostHub.FeeConfig({platformFeeBps: 500, platformFeeRecipient: FEE_RECEIVER});
            active[pid] = true;
        }
        hub.setDepositors(pids, staking, locked, selectors, fees, active);
        // Keep Hub harvest explicit: an ordinary stake must not trigger gauge reward claims.
        hub.setAutomaticHarvestOnDeposit(false);
    }

    function _deployBeefyPair(
        uint256 pid, address broadcaster, address staking, address want, address swapper
    ) internal {
        // Exactly TWO successive CREATE operations, using the SAME broadcast sender.
        // This is the nonce-coupled constructor condition in the original Beefy
        // strategy/vault architecture. Do not insert any broadcasts between them.
        uint256 nonce = vm.getNonce(broadcaster);
        address predictedVault = vm.computeCreateAddress(broadcaster, nonce + 1);
        BaseAllToWantBoostHubV5.Addresses memory addresses = BaseAllToWantBoostHubV5.Addresses({
            want: want, vault: predictedVault, swapper: swapper, adminFeeReceiver: FEE_RECEIVER
        });
        BaseAllToWantBoostHubV5.FeeSettings memory fees = BaseAllToWantBoostHubV5.FeeSettings({
            totalPerformanceFeeBps: PERFORMANCE_FEE_BPS,
            callShareBps: CALL_SHARE_BPS,
            adminShareBps: ADMIN_SHARE_BPS
        });
        address strategy = address(new StrategyConvexBoostHubStakingV5(
            staking, addresses, fees, STRATEGY_LOCK_DURATION_SECONDS, MIN_REWARD_OUTPUT_WANT_BASE_UNITS
        ));
        address vault = address(new BeefyVaultV7FixedV2(
            IStrategyBoostHubV1(strategy), _vaultName(pid), _vaultSymbol(pid), VAULT_WITHDRAWAL_FEE_BPS, FEE_RECEIVER
        ));
        require(vault == predictedVault, "BOOSTHUB_VAULT_NONCE_MISMATCH");
        require(IBoostHubStrategy(strategy).vault() == vault, "BOOSTHUB_STRATEGY_VAULT_MISMATCH");
        require(IBoostHubStrategy(strategy).want() == want, "BOOSTHUB_STRATEGY_WANT_MISMATCH");
        require(IBoostHubVault(vault).strategy() == strategy, "BOOSTHUB_VAULT_STRATEGY_MISMATCH");
        require(IBoostHubVault(vault).want() == want, "BOOSTHUB_VAULT_WANT_MISMATCH");
        // Newly constructed vault already belongs to broadcaster; retain that owner.
        // The freshly deployed vault is owned by the broadcaster until this handoff.
        require(BeefyVaultV7FixedV2(vault).owner() == broadcaster, "BOOSTHUB_CUSTOM_VAULT_INITIAL_OWNER_MISMATCH");
        BeefyVaultV7FixedV2(vault).transferOwnership(FINAL_OWNER);
        require(BeefyVaultV7FixedV2(vault).owner() == FINAL_OWNER, "BOOSTHUB_CUSTOM_VAULT_FINAL_OWNER_MISMATCH");
        emit UnifiedBeefy(pid, strategy, vault);
    }

    function _vaultName(uint256 pid) internal view returns (string memory) {
        if (block.chainid == 252) return "BoostHub sdFXS Vault";
        if (pid == 0) return "BoostHub sdCRV Vault";
        require(pid == 1, "BOOSTHUB_UNSUPPORTED_POOL");
        return "BoostHub sdFXN Vault";
    }

    function _vaultSymbol(uint256 pid) internal view returns (string memory) {
        if (block.chainid == 252) return "bh-sdFXS";
        if (pid == 0) return "bh-sdCRV";
        require(pid == 1, "BOOSTHUB_UNSUPPORTED_POOL");
        return "bh-sdFXN";
    }

    function _fraxtalPools() internal pure returns (
        address[] memory assets, address[] memory gauges, address[][] memory rewards
    ) {
        assets = new address[](1);
        gauges = new address[](1);
        rewards = new address[][](1);
        assets[0] = FRAXTAL_SDFXS;
        gauges[0] = FRAXTAL_GAUGE;
        rewards[0] = new address[](2);
        rewards[0][0] = FRAXTAL_SDFXS;
        rewards[0][1] = FRAXTAL_FRAX_REWARD;
    }

    function _ethereumPools() internal pure returns (
        address[] memory assets, address[] memory gauges, address[][] memory rewards
    ) {
        assets = new address[](2);
        gauges = new address[](2);
        rewards = new address[][](2);
        assets[0] = ASSET_0; gauges[0] = GAUGE_0;
        assets[1] = ASSET_1; gauges[1] = GAUGE_1;
        rewards[0] = new address[](5);
        rewards[0][0] = ASSET_0;
        rewards[0][1] = 0xD533a949740bb3306d119CC777fa900bA034cd52;
        rewards[0][2] = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E;
        rewards[0][3] = 0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F;
        rewards[0][4] = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490;
        rewards[1] = new address[](3);
        rewards[1][0] = ASSET_1;
        rewards[1][1] = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
        rewards[1][2] = 0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F;
    }

    function _createPartnerPair(
        BoostHubPartnerPairDeployerV4 deployer, address vaultFactory,
        address staking, address want, address strategyFactory, address omni, address strategist,
        address strategyOwner, address vaultOwner, string memory name, string memory symbol, uint256 pid
    ) internal {
        (address strategy,address vault) = deployer.deployPair(
            vaultFactory, staking, want, strategyFactory, omni, strategist,
            strategyOwner, vaultOwner, name, symbol
        );
        emit PartnerDeployed(block.chainid, pid, strategy, vault);
        emit PartnerOwnershipHandoffPending(strategy, vault, strategyOwner, vaultOwner);
        IFeeConfig.FeeCategory memory fees = IFeeConfig(
            IStrategyFactory(strategyFactory).beefyFeeConfig()
        ).getFees(strategy);
        // The Beefy fee-config owner, not this deployer, sets the strategy fee
        // category. Nonzero caller reward configuration must be verified there.
        emit PartnerFeeReviewRequired(strategy, fees.total, fees.call);
    }

    /// @dev Reject empty V3 pools before sending ANY partner deployment transaction.
    function _requireV3Liquidity(address pool) internal view {
        require(pool.code.length != 0, "PARTNER_V3_POOL_MISSING");
        (bool ok, bytes memory ret) = pool.staticcall(abi.encodeWithSignature("liquidity()"));
        require(ok && ret.length >= 32 && abi.decode(ret, (uint128)) > 0,
            "PARTNER_V3_ZERO_ACTIVE_LIQUIDITY");
    }

    /// @dev Revert before deployment if historical oracle data cannot be read.
    function _requirePoolOracle(address pool, bool useIndex) internal view {
        require(pool.code.length != 0, "PARTNER_ORACLE_POOL_MISSING");
        bytes memory payload = useIndex
            ? abi.encodeWithSignature("price_oracle(uint256)", uint256(0))
            : abi.encodeWithSignature("price_oracle()");
        (bool ok, bytes memory ret) = pool.staticcall(payload);
        require(ok && ret.length >= 32 && abi.decode(ret, (uint256)) > 0,
            "PARTNER_HISTORICAL_ORACLE_MISSING");
    }

    /// @dev Returns the read selector actually implemented by the Fraxtal
    ///      Curve pool; never assumes an unverified indexed oracle.
    function _requireFraxtalOracle(address pool) internal view {
        require(pool.code.length != 0, "PARTNER_FRAX_CURVE_POOL_MISSING");
        (bool ok,bytes memory ret) = pool.staticcall(abi.encodeWithSignature("price_oracle()"));
        if (ok && ret.length >= 32 && abi.decode(ret, (uint256)) > 0) return;
        (ok,ret) = pool.staticcall(abi.encodeWithSignature("price_oracle(uint256)", uint256(0)));
        require(ok && ret.length >= 32 && abi.decode(ret, (uint256)) > 0,
            "PARTNER_FRAX_CURVE_EMA_ORACLE_UNAVAILABLE");
    }

    function _curveHop(
        uint16 typeId, address pool, address tokenOut, uint8 i, uint8 j,
        bool invert, bool useIndex
    ) internal pure returns (CurveYieldOmniRouter.SimpleHop memory hop) {
        CurveYieldOmniRouter.SimpleOracle memory oracle = CurveYieldOmniRouter.SimpleOracle({
            oracleAddress: pool,
            readFunctionID: useIndex ? bytes4(keccak256("price_oracle(uint256)")) : bytes4(keccak256("price_oracle()")),
            requiredInputs: useIndex ? abi.encode(uint256(0)) : bytes(""),
            invert: invert, rateDecimals: 18
        });
        hop = CurveYieldOmniRouter.SimpleHop({
            poolType: typeId, tokenOut: tokenOut, swapContract: pool,
            poolId: bytes32(0), poolData: abi.encode(i,j), oracle: oracle
        });
    }

    function _v3Hop(address pool, address tokenOut) internal pure
        returns (CurveYieldOmniRouter.SimpleHop memory hop)
    {
        CurveYieldOmniRouter.SimpleOracle memory nativeTwap = CurveYieldOmniRouter.SimpleOracle({
            oracleAddress: address(0), readFunctionID: bytes4(0), requiredInputs: bytes(""),
            invert: false, rateDecimals: 18
        });
        hop = CurveYieldOmniRouter.SimpleHop({
            poolType: 2, tokenOut: tokenOut, swapContract: pool,
            poolId: bytes32(0), poolData: abi.encode(uint32(300)), oracle: nativeTwap
        });
    }

    function _installPartnerRoute(CurveYieldOmniRouter router, address from, address to,
        CurveYieldOmniRouter.SimpleHop[] memory hops) internal {
        router.setRoute(from, to, hops);
        // Quote one whole input token through every on-chain EMA/TWAP guard;
        // an invalid or missing oracle causes a revert before the next pair.
        uint8 decimals = IERC20PartnerMetadata(from).decimals();
        require(decimals <= 36, "PARTNER_TOKEN_DECIMALS");
        require(router.estimate_exact_output(from, to, 10 ** uint256(decimals)) > 0,
            "PARTNER_ROUTE_ORACLE_QUOTE_ZERO");
    }


    function _fraxtalCurveType(address pool) internal view returns (uint16) {
        (bool crypto, bytes memory data) = pool.staticcall(
            abi.encodeWithSignature("get_dy(uint256,uint256,uint256)", uint256(0), uint256(1), uint256(1e18))
        );
        if (crypto && data.length >= 32) return 4; // TwoCrypto, uint256 index
        (bool stable, bytes memory stableData) = pool.staticcall(
            abi.encodeWithSignature("get_dy(int128,int128,uint256)", int128(0), int128(1), uint256(1e18))
        );
        require(stable && stableData.length >= 32, "PARTNER_FRAX_CURVE_EXCHANGE_UNKNOWN");
        return 6; // StableSwap, int128 index
    }



    function _preflightPartnerDependencies(bool isEthereum) internal view {
        address strategyFactory = isEthereum ? ETH_BEEFY_STRATEGY_FACTORY : FRAX_BEEFY_STRATEGY_FACTORY;
        address nativeToken = isEthereum ? ETH_WETH : FRAX_WFRAX;
        require(strategyFactory.code.length > 0 && nativeToken.code.length > 0,
            "PARTNER_FACTORY_OR_NATIVE_MISSING");
        IStrategyFactory f = IStrategyFactory(strategyFactory);
        require(f.native() == nativeToken, "PARTNER_FACTORY_NATIVE_MISMATCH");
        require(f.beefyFeeConfig().code.length > 0, "PARTNER_FEE_CONFIG_MISSING");
        require(!f.globalPause() && !f.strategyPause("BoostHubStaking"), "PARTNER_FACTORY_PAUSED");
        // Independent BoostHub strategies do not require registration in
        // Beefy's managed strategy beacon. The factory is retained only as
        // the read-only fee, keeper and pause configuration provider.
        // Both chains must use their respective existing Beefy V7 vault factories.
        address vaultFactory = isEthereum ? ETH_BEEFY_VAULT_FACTORY : FRAX_BEEFY_VAULT_FACTORY;
        require(vaultFactory.code.length > 0, "PARTNER_BEEFY_VAULT_FACTORY_MISSING");
        require(address(BeefyVaultV7Factory(vaultFactory).instance()).code.length > 0,
            "PARTNER_BEEFY_VAULT_IMPL_MISSING");
        if (isEthereum) {
            _requirePoolOracle(ETH_CRV_SDCRV_POOL, false);
            _requirePoolOracle(ETH_CRVUSD_WETH_POOL, true);
            _requirePoolOracleIndex(ETH_CRVUSD_WETH_POOL, 1);
            _requirePoolOracle(ETH_WETH_FXN_POOL, false);
            _requirePoolOracle(ETH_FXN_SDFXN_POOL, false);
            _requireV3Liquidity(ETH_CRV_WETH_V3);
            _requireV3Liquidity(ETH_WSTETH_WETH_V3);
        } else {
            _requireFraxtalOracle(FRAX_WFRAX_SDFXS_POOL);
            // Verify pool ordering instead of assuming the token symbols.
            _requireFraxtalPoolTokens(FRAX_WFRAX_SDFXS_POOL, FRAX_WFRAX, FRAXTAL_SDFXS);
        }
    }

    function _requirePoolOracleIndex(address pool, uint256 index) internal view {
        (bool ok, bytes memory ret) = pool.staticcall(abi.encodeWithSignature("price_oracle(uint256)", index));
        require(ok && ret.length >= 32 && abi.decode(ret, (uint256)) > 0,
            "PARTNER_INDEXED_ORACLE_MISSING");
    }

    function _requireFraxtalPoolTokens(address pool, address token0, address token1) internal view {
        // Same uint256->int128 coins() fallback as the unmodified Omni router.
        require(_readFraxtalCoin(pool, 0) == token0 && _readFraxtalCoin(pool, 1) == token1,
            "PARTNER_FRAX_POOL_TOKEN_ORDER");
    }

    function _readFraxtalCoin(address pool, uint8 index) internal view returns (address token) {
        (bool ok, bytes memory out) = pool.staticcall(
            abi.encodeWithSignature("coins(uint256)", uint256(index)));
        if (!ok || out.length < 32) {
            (ok,out) = pool.staticcall(abi.encodeWithSignature("coins(int128)", int128(uint128(index))));
        }
        require(ok && out.length >= 32, "PARTNER_FRAX_POOL_COIN_UNREADABLE");
        token = abi.decode(out, (address));
    }

    function _deployPartnerPair(
        BoostHubPartnerPairDeployerV4 deployer, address vaultFactory,
        address staking, address want, address strategyFactory, address omni,
        address broadcaster, uint256 pid
    ) internal {
        string memory name;
        string memory symbol;
        if (block.chainid == 252) {
            name = "Moo BoostHub sdFXS"; symbol = "mooBoostHubSdFXS";
        } else if (pid == 0) {
            name = "Moo BoostHub sdCRV"; symbol = "mooBoostHubSdCRV";
        } else {
            name = "Moo BoostHub sdFXN"; symbol = "mooBoostHubSdFXN";
        }
        _createPartnerPair(deployer, vaultFactory, staking, want,
            strategyFactory, omni, FINAL_OWNER, FINAL_OWNER, FINAL_OWNER, name, symbol, pid);
    }

    function _configureEthereumRoutes(CurveYieldOmniRouter router) internal {
        CurveYieldOmniRouter.SimpleHop[] memory one = new CurveYieldOmniRouter.SimpleHop[](1);
        CurveYieldOmniRouter.SimpleHop[] memory two = new CurveYieldOmniRouter.SimpleHop[](2);
        CurveYieldOmniRouter.SimpleHop[] memory three = new CurveYieldOmniRouter.SimpleHop[](3);

        // Reward -> underlying for original custom vaults; source pools come
        // from the deployed historical converter routes. No SDT or 3Crv route.
        one[0] = _curveHop(6, ETH_CRV_SDCRV_POOL, ASSET_0, 0, 1, true, false);
        _installPartnerRoute(router, ETH_CRV, ASSET_0, one);
        two[0] = _curveHopIndexed(5, ETH_CRVUSD_WETH_POOL, ETH_CRV, 0, 2, true, 1);
        two[1] = _curveHop(6, ETH_CRV_SDCRV_POOL, ASSET_0, 0, 1, true, false);
        _installPartnerRoute(router, ETH_CRVUSD, ASSET_0, two);
        three[0] = _v3Hop(ETH_WSTETH_WETH_V3, ETH_WETH);
        three[1] = _curveHop(4, ETH_WETH_FXN_POOL, ETH_FXN, 0, 1, true, false);
        three[2] = _curveHop(6, ETH_FXN_SDFXN_POOL, ASSET_1, 0, 1, true, false);
        _installPartnerRoute(router, ETH_WSTETH, ASSET_1, three);

        // Rewards -> native for the three official Beefy partner strategies.
        one[0] = _v3Hop(ETH_CRV_WETH_V3, ETH_WETH);
        _installPartnerRoute(router, ETH_CRV, ETH_WETH, one);
        one[0] = _curveHopIndexed(5, ETH_CRVUSD_WETH_POOL, ETH_WETH, 0, 1, true, 0);
        _installPartnerRoute(router, ETH_CRVUSD, ETH_WETH, one);
        one[0] = _v3Hop(ETH_WSTETH_WETH_V3, ETH_WETH);
        _installPartnerRoute(router, ETH_WSTETH, ETH_WETH, one);

        // Underlying -> native for newly claimed principal-denominated rewards;
        // native -> underlying for fee settlement and compounding.
        two[0] = _curveHop(6, ETH_CRV_SDCRV_POOL, ETH_CRV, 1, 0, false, false);
        two[1] = _v3Hop(ETH_CRV_WETH_V3, ETH_WETH);
        _installPartnerRoute(router, ASSET_0, ETH_WETH, two);
        two[0] = _v3Hop(ETH_CRV_WETH_V3, ETH_CRV);
        two[1] = _curveHop(6, ETH_CRV_SDCRV_POOL, ASSET_0, 0, 1, true, false);
        _installPartnerRoute(router, ETH_WETH, ASSET_0, two);
        two[0] = _curveHop(6, ETH_FXN_SDFXN_POOL, ETH_FXN, 1, 0, false, false);
        two[1] = _curveHop(4, ETH_WETH_FXN_POOL, ETH_WETH, 1, 0, false, false);
        _installPartnerRoute(router, ASSET_1, ETH_WETH, two);
        two[0] = _curveHop(4, ETH_WETH_FXN_POOL, ETH_FXN, 0, 1, true, false);
        two[1] = _curveHop(6, ETH_FXN_SDFXN_POOL, ASSET_1, 0, 1, true, false);
        _installPartnerRoute(router, ETH_WETH, ASSET_1, two);
    }

    function _curveHopIndexed(
        uint16 typeId, address pool, address tokenOut, uint8 i, uint8 j,
        bool invert, uint256 oracleIndex
    ) internal pure returns (CurveYieldOmniRouter.SimpleHop memory hop) {
        hop = _curveHop(typeId, pool, tokenOut, i, j, invert, true);
        hop.oracle.requiredInputs = abi.encode(oracleIndex);
    }

    function _configureFraxtalRoutes(CurveYieldOmniRouter router) internal {
        CurveYieldOmniRouter.SimpleHop[] memory one = new CurveYieldOmniRouter.SimpleHop[](1);
        (bool ok, bytes memory ret) = FRAX_WFRAX_SDFXS_POOL.staticcall(
            abi.encodeWithSignature("price_oracle()"));
        bool indexedOracle = !(ok && ret.length >= 32 && abi.decode(ret, (uint256)) > 0);
        uint16 typeId = _fraxtalCurveType(FRAX_WFRAX_SDFXS_POOL);
        one[0] = _curveHop(typeId, FRAX_WFRAX_SDFXS_POOL, FRAXTAL_SDFXS,
            0, 1, true, indexedOracle);
        _installPartnerRoute(router, FRAX_WFRAX, FRAXTAL_SDFXS, one);
        one[0] = _curveHop(typeId, FRAX_WFRAX_SDFXS_POOL, FRAX_WFRAX,
            1, 0, false, indexedOracle);
        _installPartnerRoute(router, FRAXTAL_SDFXS, FRAX_WFRAX, one);
    }

}

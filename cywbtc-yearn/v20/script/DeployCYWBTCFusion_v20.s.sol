// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {FusionFactory} from "../contracts/factory/FusionFactory.sol";
import {FusionFactoryLogicLib} from "../contracts/factory/lib/FusionFactoryLogicLib.sol";
import {IporFusionAccessManager} from "../contracts/managers/access/IporFusionAccessManager.sol";
import {Roles} from "../contracts/libraries/Roles.sol";
import {IPlasmaVaultGovernance} from "../contracts/interfaces/IPlasmaVaultGovernance.sol";
import {InstantWithdrawalFusesParamsStruct} from "../contracts/libraries/PlasmaVaultLib.sol";
import {AaveV4SubstrateLib} from "../contracts/fuses/aave_v4/AaveV4SubstrateLib.sol";
import {AaveV4BalanceFuse} from "../contracts/fuses/aave_v4/AaveV4BalanceFuse.sol";
import {ERC20BalanceFuse} from "../contracts/fuses/erc20/Erc20BalanceFuse.sol";
import {Erc4626BalanceFuse} from "../contracts/fuses/erc4626/Erc4626BalanceFuse.sol";
import {Erc4626SupplyFuse} from "../contracts/fuses/erc4626/Erc4626SupplyFuse.sol";
import {FXMintAaveV4SpokeAccountingAdapter} from "../contracts/fuses/fxmint/FXMintAaveV4SpokeAccountingAdapter.sol";
import {FXMintBorrowFuse} from "../contracts/fuses/fxmint/FXMintBorrowFuse.sol";
import {FXMintCollateralFuse} from "../contracts/fuses/fxmint/FXMintCollateralFuse.sol";
import {FXMintLTVManager} from "../contracts/fuses/fxmint/FXMintLTVManager_v17.sol";
import {CurveFxUSDChainlinkUsdFeed_v20} from "../contracts/price_oracle/price_feed/CurveFxUSDChainlinkUsdFeed_v20.sol";

interface ICyPriceManager {
    function setAssetsPriceSources(address[] calldata assets, address[] calldata sources) external;
    function getAssetPrice(address asset) external view returns (uint256 price,uint256 decimals);
    function getSourceOfAssetPrice(address asset) external view returns (address);
}
interface ICyFusionVault {
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
}
interface ICyFusionFactory {
    function clone(string memory assetName,string memory assetSymbol,address underlying,
                   uint256 redemptionDelay,address owner,uint256 feePackageIndex)
        external returns (FusionFactoryLogicLib.FusionInstance memory);
}
/// @notice Source-bound, fully configured Ethereum IPOR Fusion/fxMINT/Yearn setup.
/// @dev Uses only actual deployed IPOR factory and real underlying token/protocols.
///      All transactions are real on the selected RPC: use a verified localhost
///      Anvil fork for simulation; do not broadcast to mainnet accidentally.
contract DeployCYWBTCFusion_v20 is Script {
    uint256 internal constant ERC20_MARKET=7;
    uint256 internal constant FXMINT_MARKET=49;
    uint256 internal constant YEARN_MARKET=100_001;
    address internal constant MAINNET_WBTC=0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal constant MAINNET_FXUSD=0x085780639cc2cacd35e474e71f4d000e2405d8f6;
    address internal constant MAINNET_USDC=0xA0b86991c6218b36c1d19d4a2e9eb0ce3606eb48;
    address internal constant MAINNET_FACTORY=0xcd05909C4A1F8E501e4ED554cEF4Ed5E48D9b852;
    address internal constant FXMINT_WBTC_POOL=0xAB709e26Fa6B0A30c119D8c55B887DeD24952473;
    address internal constant FXMINT_POOL_MANAGER=0x250893CA4Ba5d05626C785e8da758026928FCD24;
    address internal constant CURVE_USDC_FXUSD_POOL=0x5018be882dcce5e3f2f3b0913ae2096b9b3fb61f;
    address internal constant CHAINLINK_USDC_USD=0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;

    error ConfigurationMismatch();
    event CyFusionConfigured(address indexed vault,address indexed manager,address indexed oracle,
       address adapter,address collateralFuse,address borrowFuse,address yearnFuse);

    function run() external returns (address vault) {
        require(block.chainid==1,"Ethereum mainnet/fork only");
        address owner=vm.envAddress("VAULT_OWNER");
        address yearnVault=vm.envAddress("SIM_YEARN_VAULT");
        address yearnMaster=vm.envAddress("SIM_YEARN_MASTER");
        address depositor=vm.envOr("SIM_DEPOSITOR",address(0));
        uint256 key=vm.envUint("DEPLOYER_PRIVATE_KEY");
        uint256 target=vm.envOr("CYWBTC_TARGET_LTV_WAD",uint256(70e16));
        uint256 cap=vm.envOr("CYWBTC_SUPPLY_CAP_SHARES",uint256(10_000e10));
        uint256 redemptionDelay=vm.envOr("CYWBTC_REDEMPTION_DELAY_SECS",uint256(0));
        uint256 feePackage=vm.envOr("CYWBTC_FEE_PACKAGE_INDEX",uint256(0));
        require(owner!=address(0)&&yearnVault.code.length>0&&yearnMaster.code.length>0,"missing Yearn stack");
        require(cap>0,"missing cap");
        require(MAINNET_FACTORY.code.length>0&&FXMINT_WBTC_POOL.code.length>0,"missing canonical contracts");

        vm.startBroadcast(key);
        FusionFactoryLogicLib.FusionInstance memory instance=ICyFusionFactory(MAINNET_FACTORY).clone(
            "CurveYield vbWBTC","cyvbWBTC",MAINNET_WBTC,redemptionDelay,owner,feePackage
        );
        vault=instance.plasmaVault;
        if (vault.code.length==0 || ICyFusionVault(vault).asset()!=MAINNET_WBTC) revert ConfigurationMismatch();
        IPlasmaVaultGovernance gov=IPlasmaVaultGovernance(vault);
        IporFusionAccessManager access=IporFusionAccessManager(instance.accessManager);

        // Roles are granted according to IPOR's native owner->atomist hierarchy.
        // On production, assign distinct operational addresses via env vars.
        address alpha=vm.envOr("CYWBTC_ALPHA",owner);
        address atomist=vm.envOr("CYWBTC_ATOMIST",owner);
        address fuseManager=vm.envOr("CYWBTC_FUSE_MANAGER",atomist);
        address oracleManager=vm.envOr("CYWBTC_ORACLE_MANAGER",atomist);
        require(alpha!=address(0)&&atomist!=address(0)&&fuseManager!=address(0)
            &&oracleManager!=address(0),"bad role");
        access.grantRole(Roles.ATOMIST_ROLE,atomist,0);
        access.grantRole(Roles.ALPHA_ROLE,alpha,0);
        access.grantRole(Roles.FUSE_MANAGER_ROLE,fuseManager,0);
        access.grantRole(Roles.CONFIG_INSTANT_WITHDRAWAL_FUSES_ROLE,atomist,0);
        access.grantRole(Roles.PRICE_ORACLE_MIDDLEWARE_MANAGER_ROLE,oracleManager,0);
        if (depositor!=address(0)) access.grantRole(Roles.WHITELIST_ROLE,depositor,0);

        CurveFxUSDChainlinkUsdFeed_v20 feed=new CurveFxUSDChainlinkUsdFeed_v20(
            CURVE_USDC_FXUSD_POOL,CHAINLINK_USDC_USD,MAINNET_FXUSD,MAINNET_USDC,4 hours
        );
        address[] memory assets=new address[](1);
        address[] memory sources=new address[](1);
        assets[0]=MAINNET_FXUSD;
        sources[0]=address(feed);
        ICyPriceManager(instance.priceManager).setAssetsPriceSources(assets,sources);
        if (ICyPriceManager(instance.priceManager).getSourceOfAssetPrice(MAINNET_FXUSD)!=address(feed))
            revert ConfigurationMismatch();
        (uint256 fxPrice,uint256 fxDecimals)=ICyPriceManager(instance.priceManager).getAssetPrice(MAINNET_FXUSD);
        (uint256 btcPrice,uint256 btcDecimals)=ICyPriceManager(instance.priceManager).getAssetPrice(MAINNET_WBTC);
        if(fxPrice==0||btcPrice==0||fxDecimals>18||btcDecimals>18)revert ConfigurationMismatch();

        FXMintAaveV4SpokeAccountingAdapter adapter=new FXMintAaveV4SpokeAccountingAdapter(
            vault,owner,FXMINT_WBTC_POOL,MAINNET_WBTC,MAINNET_FXUSD
        );
        FXMintCollateralFuse collateralFuse=new FXMintCollateralFuse(
            FXMINT_WBTC_POOL,FXMINT_POOL_MANAGER,MAINNET_WBTC
        );
        FXMintBorrowFuse borrowFuse=new FXMintBorrowFuse(
            FXMINT_WBTC_POOL,FXMINT_POOL_MANAGER,MAINNET_FXUSD
        );
        Erc4626SupplyFuse yearnSupplyFuse=new Erc4626SupplyFuse(YEARN_MARKET);
        Erc4626BalanceFuse yearnBalanceFuse=new Erc4626BalanceFuse(YEARN_MARKET);
        AaveV4BalanceFuse fxMintBalanceFuse=new AaveV4BalanceFuse(FXMINT_MARKET);
        ERC20BalanceFuse erc20BalanceFuse=new ERC20BalanceFuse(ERC20_MARKET);

        FXMintLTVManager.Addresses memory cfg=FXMintLTVManager.Addresses({
            vault:vault, owner:owner, positionRegistry:address(adapter),
            fxMintPool:FXMINT_WBTC_POOL,poolManager:FXMINT_POOL_MANAGER,
            wbtc:MAINNET_WBTC,fxusd:MAINNET_FXUSD,
            fxMintBorrowFuse:address(borrowFuse),fxMintCollateralFuse:address(collateralFuse),
            erc4626SupplyFuse:address(yearnSupplyFuse),yearnVault:yearnVault,yearnMaster:yearnMaster
        });
        FXMintLTVManager manager=new FXMintLTVManager(cfg,target);

        address[] memory fuses=new address[](5);
        fuses[0]=address(collateralFuse);
        fuses[1]=address(borrowFuse);
        fuses[2]=address(adapter);
        fuses[3]=address(yearnSupplyFuse);
        fuses[4]=address(manager);
        gov.addFuses(fuses);
        gov.addBalanceFuse(FXMINT_MARKET,address(fxMintBalanceFuse));
        gov.addBalanceFuse(YEARN_MARKET,address(yearnBalanceFuse));
        gov.addBalanceFuse(ERC20_MARKET,address(erc20BalanceFuse));

        bytes32[] memory erc20substrates=new bytes32[](1);
        erc20substrates[0]=bytes32(uint256(uint160(MAINNET_FXUSD)));
        gov.grantMarketSubstrates(ERC20_MARKET,erc20substrates);
        bytes32[] memory yearnsubstrates=new bytes32[](1);
        yearnsubstrates[0]=bytes32(uint256(uint160(yearnVault)));
        gov.grantMarketSubstrates(YEARN_MARKET,yearnsubstrates);
        bytes32[] memory fxsubstrates=new bytes32[](2);
        fxsubstrates[0]=AaveV4SubstrateLib.encodeReserve(address(adapter),0,true,false);
        fxsubstrates[1]=AaveV4SubstrateLib.encodeReserve(address(adapter),1,false,true);
        gov.grantMarketSubstrates(FXMINT_MARKET,fxsubstrates);

        uint256[] memory markets=new uint256[](2);
        uint256[][] memory graph=new uint256[][](2);
        markets[0]=YEARN_MARKET; markets[1]=FXMINT_MARKET;
        graph[0]=new uint256[](1);graph[0][0]=ERC20_MARKET;
        graph[1]=new uint256[](2);graph[1][0]=YEARN_MARKET;graph[1][1]=ERC20_MARKET;
        gov.updateDependencyBalanceGraphs(markets,graph);

        InstantWithdrawalFusesParamsStruct[] memory instant=new InstantWithdrawalFusesParamsStruct[](1);
        instant[0].fuse=address(manager);
        instant[0].params=new bytes32[](1);
        instant[0].params[0]=bytes32(0); // reserved for WBTC shortfall
        gov.configureInstantWithdrawalFuses(instant);
        gov.setTotalSupplyCap(cap);

        if (!gov.isFuseSupported(address(manager))||
            !gov.isFuseSupported(address(yearnSupplyFuse))||
            !gov.isBalanceFuseSupported(FXMINT_MARKET,address(fxMintBalanceFuse))||
            !gov.isBalanceFuseSupported(YEARN_MARKET,address(yearnBalanceFuse))||
            !gov.isMarketSubstrateGranted(YEARN_MARKET,yearnsubstrates[0])||
            !gov.isMarketSubstrateGranted(FXMINT_MARKET,fxsubstrates[0])||
            !gov.isMarketSubstrateGranted(FXMINT_MARKET,fxsubstrates[1]))
            revert ConfigurationMismatch();
        address[] memory instantReadback=gov.getInstantWithdrawalFuses();
        if (instantReadback.length!=1||instantReadback[0]!=address(manager))revert ConfigurationMismatch();

        emit CyFusionConfigured(vault,address(manager),address(feed),
            address(adapter),address(collateralFuse),address(borrowFuse),address(yearnSupplyFuse));
        console2.log("CY_SIM_DEPLOYED_IPOR_VAULT",vault);
        console2.log("CY_SIM_DEPLOYED_LTV_MANAGER",address(manager));
        console2.log("CY_SIM_DEPLOYED_COLLATERAL_FUSE",address(collateralFuse));
        console2.log("CY_SIM_DEPLOYED_ACCOUNTING_ADAPTER",address(adapter));
        console2.log("CY_SIM_DEPLOYED_BORROW_FUSE",address(borrowFuse));
        console2.log("CY_SIM_DEPLOYED_ERC4626_SUPPLY",address(yearnSupplyFuse));
        console2.log("CY_SIM_DEPLOYED_ERC4626_BALANCE",address(yearnBalanceFuse));
        console2.log("CY_SIM_DEPLOYED_FXUSD_FEED",address(feed));
        console2.log("CY_SIM_DEPLOYED_IPOR_ALPHA",alpha);
        console2.log("CY_SIM_DEPLOYED_MANAGER_OWNER",owner);
        vm.stopBroadcast();
    }
}

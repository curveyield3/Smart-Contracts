// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {FusionFactoryLogicLib} from "../contracts/factory/lib/FusionFactoryLogicLib.sol";
import {IporFusionAccessManager} from "../contracts/managers/access/IporFusionAccessManager.sol";
import {Roles} from "../contracts/libraries/Roles.sol";
import {IPlasmaVaultGovernance} from "../contracts/interfaces/IPlasmaVaultGovernance.sol";
import {InstantWithdrawalFusesParamsStruct} from "../contracts/libraries/PlasmaVaultLib.sol";
import {ERC20BalanceFuse} from "../contracts/fuses/erc20/Erc20BalanceFuse.sol";
import {Erc4626BalanceFuse} from "../contracts/fuses/erc4626/Erc4626BalanceFuse.sol";
import {Erc4626SupplyFuse} from "../contracts/fuses/erc4626/Erc4626SupplyFuse.sol";
import {FXMintBalanceFuse} from "../contracts/fuses/fxmint/FXMintBalanceFuse.sol";
import {FXMintBorrowFuse} from "../contracts/fuses/fxmint/FXMintBorrowFuse.sol";
import {FXMintCollateralFuse} from "../contracts/fuses/fxmint/FXMintCollateralFuse.sol";
import {FXMintLTVManager} from "../contracts/fuses/fxmint/FXMintLTVManager_v22.sol";
import {CyWBTCAtomicDepositRouter_v22} from "../contracts/entry/CyWBTCAtomicDepositRouter_v22.sol";
import {CurveFxUSDChainlinkUsdFeed_v20} from "../contracts/price_oracle/price_feed/CurveFxUSDChainlinkUsdFeed_v20.sol";

interface ICyPriceManagerV22 {
    function setAssetsPriceSources(address[] calldata assets, address[] calldata sources) external;
    function getAssetPrice(address asset) external view returns (uint256 price,uint256 decimals);
    function getSourceOfAssetPrice(address asset) external view returns (address);
}
interface ICyVaultV22 {function asset() external view returns(address);}
interface ICyFusionFactoryV22 {
    function clone(string memory name,string memory symbol,address underlying,uint256 redemptionDelay,address owner,uint256 feePackageIndex)
      external returns(FusionFactoryLogicLib.FusionInstance memory);
}
/// @notice v22 draft deployment: existing Ethereum IPOR factory, direct fxMINT net accounting on market 49.
/// @dev The initial owner is deployer, who can authorize setup before granting the final owner.
///      This script assumes the deployed factory supports the pinned `clone` ABI;
///      verify its on-chain ABI and privileges before sending a live transaction.
contract DeployCYWBTCFusion_v22 is Script {
    uint256 internal constant FXMINT_MARKET=49; // official AAVE_V4 numeric ID, no emulation
    uint256 internal constant ERC20_MARKET=7;
    uint256 internal constant YEARN_MARKET=100_001;
    address internal constant WBTC=0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal constant FXUSD=0x085780639CC2cACd35E474e71f4d000e2405d8f6;
    address internal constant USDC=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant FACTORY=0xcd05909C4A1F8E501e4ED554cEF4Ed5E48D9b852;
    address internal constant FXMINT_POOL=0xAB709e26Fa6B0A30c119D8c55B887DeD24952473;
    address internal constant POOL_MANAGER=0x250893CA4Ba5d05626C785e8da758026928FCD24;
    address internal constant CURVE_POOL=0x5018BE882DccE5E3F2f3B0913AE2096B9b3fB61f;
    address internal constant USDC_USD_ORACLE=0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    error ConfigurationMismatch();
    event CyFusionConfigured(address indexed vault,address indexed manager,address indexed fxMintBalanceFuse,address oracle);
    event CyDepositRouterConfigured(address indexed vault,address indexed router);

    function run() external returns(address vault){
        require(block.chainid==1,"Ethereum mainnet / mainnet fork only");
        uint256 key=vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer=vm.addr(key);
        address owner=vm.envAddress("VAULT_OWNER");
        address yearnVault=vm.envAddress("SIM_YEARN_VAULT");
        address yearnMaster=vm.envAddress("SIM_YEARN_MASTER");
        uint256 target=vm.envOr("CYWBTC_TARGET_LTV_WAD",uint256(70e16));
        uint256 cap=vm.envOr("CYWBTC_SUPPLY_CAP_SHARES",uint256(10_000e10));
        uint256 delay=vm.envOr("CYWBTC_REDEMPTION_DELAY_SECS",uint256(0));
        // Router forwards newly minted shares in the same transaction. A
        // nonzero redemption delay blocks this transfer; router exemption
        // would bypass the delay and is intentionally not granted.
        require(delay==0,"atomic deposit router needs zero redemption delay");
        uint256 feePackage=vm.envOr("CYWBTC_FEE_PACKAGE_INDEX",uint256(0));
        address alpha=vm.envOr("CYWBTC_ALPHA",owner);
        address atomist=vm.envOr("CYWBTC_ATOMIST",owner);
        address fuseManager=vm.envOr("CYWBTC_FUSE_MANAGER",atomist);
        address oracleManager=vm.envOr("CYWBTC_ORACLE_MANAGER",atomist);
        // Only the atomic deposit router receives deposit/mint whitelist status.
        // Public PlasmaVault deposits would bypass immediate collateral allocation.
        require(owner!=address(0)&&alpha!=address(0)&&atomist!=address(0)
             &&fuseManager!=address(0)&&oracleManager!=address(0),"invalid roles");
        require(yearnVault.code.length>0&&yearnMaster.code.length>0&&FACTORY.code.length>0&&FXMINT_POOL.code.length>0
             &&cap>0,"missing source contracts or cap");
        vm.startBroadcast(key);
        // Temporary deployer owner. No new factory is deployed.
        FusionFactoryLogicLib.FusionInstance memory instance=ICyFusionFactoryV22(FACTORY).clone(
            "CurveYield vbWBTC","cyvbWBTC",WBTC,delay,deployer,feePackage
        );
        vault=instance.plasmaVault;
        if(vault.code.length==0||ICyVaultV22(vault).asset()!=WBTC) revert ConfigurationMismatch();
        IporFusionAccessManager access=IporFusionAccessManager(instance.accessManager);
        IPlasmaVaultGovernance governance=IPlasmaVaultGovernance(vault);

        // OWNER grants ATOMIST; ATOMIST grants manager/operation roles.
        access.grantRole(Roles.ATOMIST_ROLE,deployer,0);
        access.grantRole(Roles.FUSE_MANAGER_ROLE,deployer,0);
        access.grantRole(Roles.CONFIG_INSTANT_WITHDRAWAL_FUSES_ROLE,deployer,0);
        access.grantRole(Roles.PRICE_ORACLE_MIDDLEWARE_MANAGER_ROLE,deployer,0);
        access.grantRole(Roles.ALPHA_ROLE,deployer,0);
        access.grantRole(Roles.ATOMIST_ROLE,atomist,0);
        access.grantRole(Roles.ALPHA_ROLE,alpha,0);
        access.grantRole(Roles.FUSE_MANAGER_ROLE,fuseManager,0);
        access.grantRole(Roles.PRICE_ORACLE_MIDDLEWARE_MANAGER_ROLE,oracleManager,0);
        access.grantRole(Roles.CONFIG_INSTANT_WITHDRAWAL_FUSES_ROLE,atomist,0);


        CurveFxUSDChainlinkUsdFeed_v20 feed=new CurveFxUSDChainlinkUsdFeed_v20(
            CURVE_POOL,USDC_USD_ORACLE,FXUSD,USDC,4 hours
        );
        address[] memory assets=new address[](1);
        address[] memory sources=new address[](1);
        assets[0]=FXUSD;
        sources[0]=address(feed);
        ICyPriceManagerV22(instance.priceManager).setAssetsPriceSources(assets,sources);
        if(ICyPriceManagerV22(instance.priceManager).getSourceOfAssetPrice(FXUSD)!=address(feed))
            revert ConfigurationMismatch();
        (uint256 fxPrice,)=ICyPriceManagerV22(instance.priceManager).getAssetPrice(FXUSD);
        (uint256 btcPrice,)=ICyPriceManagerV22(instance.priceManager).getAssetPrice(WBTC);
        if(fxPrice==0||btcPrice==0) revert ConfigurationMismatch();

        FXMintBalanceFuse fxMintBalance=new FXMintBalanceFuse(vault,owner,FXMINT_POOL,WBTC,FXUSD);
        FXMintCollateralFuse collateralFuse=new FXMintCollateralFuse(FXMINT_POOL,POOL_MANAGER,WBTC);
        FXMintBorrowFuse borrowFuse=new FXMintBorrowFuse(FXMINT_POOL,POOL_MANAGER,FXUSD);
        Erc4626SupplyFuse yearnSupply=new Erc4626SupplyFuse(YEARN_MARKET);
        Erc4626BalanceFuse yearnBalance=new Erc4626BalanceFuse(YEARN_MARKET);
        ERC20BalanceFuse erc20Balance=new ERC20BalanceFuse(ERC20_MARKET);
        FXMintLTVManager manager=new FXMintLTVManager(FXMintLTVManager.Addresses({
            vault:vault,owner:owner,positionRegistry:address(fxMintBalance),
            fxMintPool:FXMINT_POOL,poolManager:POOL_MANAGER,wbtc:WBTC,fxusd:FXUSD,
            fxMintBorrowFuse:address(borrowFuse),fxMintCollateralFuse:address(collateralFuse),
            erc4626SupplyFuse:address(yearnSupply),yearnVault:yearnVault,yearnMaster:yearnMaster
        }),target);

        address[] memory fuses=new address[](5);
        fuses[0]=address(collateralFuse);
        fuses[1]=address(borrowFuse);
        fuses[2]=address(fxMintBalance); // NFT registration action and balance fuse
        fuses[3]=address(yearnSupply);
        fuses[4]=address(manager);
        governance.addFuses(fuses);
        governance.addBalanceFuse(FXMINT_MARKET,address(fxMintBalance));
        governance.addBalanceFuse(YEARN_MARKET,address(yearnBalance));
        governance.addBalanceFuse(ERC20_MARKET,address(erc20Balance));

        bytes32[] memory idleTokens=new bytes32[](1);
        idleTokens[0]=bytes32(uint256(uint160(FXUSD)));
        governance.grantMarketSubstrates(ERC20_MARKET,idleTokens);
        bytes32[] memory yearnSubstrates=new bytes32[](1);
        yearnSubstrates[0]=bytes32(uint256(uint160(yearnVault)));
        governance.grantMarketSubstrates(YEARN_MARKET,yearnSubstrates);
        bytes32[] memory fxMintSubstrates=new bytes32[](1);
        fxMintSubstrates[0]=bytes32(uint256(uint160(FXMINT_POOL)));
        governance.grantMarketSubstrates(FXMINT_MARKET,fxMintSubstrates);

        uint256[] memory markets=new uint256[](2);
        uint256[][] memory graph=new uint256[][](2);
        markets[0]=YEARN_MARKET;markets[1]=FXMINT_MARKET;
        graph[0]=new uint256[](1);graph[0][0]=ERC20_MARKET;
        graph[1]=new uint256[](2);graph[1][0]=YEARN_MARKET;graph[1][1]=ERC20_MARKET;
        governance.updateDependencyBalanceGraphs(markets,graph);
        InstantWithdrawalFusesParamsStruct[] memory instant=new InstantWithdrawalFusesParamsStruct[](1);
        instant[0].fuse=address(manager);
        instant[0].params=new bytes32[](1);
        instant[0].params[0]=bytes32(0);
        governance.configureInstantWithdrawalFuses(instant);
        governance.setTotalSupplyCap(cap);

        // The vault is intentionally NOT made public for deposits/mints.
        // The router is the sole ordinary user deposit entry, with the tightly
        // scoped ALPHA right to execute only the LTV manager allocation.
        CyWBTCAtomicDepositRouter_v22 router = new CyWBTCAtomicDepositRouter_v22(
            vault, WBTC, address(manager)
        );
        access.grantRole(Roles.WHITELIST_ROLE,address(router),0);
        access.grantRole(Roles.ALPHA_ROLE,address(router),0);
        access.grantRole(Roles.UPDATE_MARKETS_BALANCES_ROLE,address(router),0);
        // Allow the router to forward actual vault ERC20 share tokens to
        // depositors, instead of minting a separate wrapper share token.
        governance.enableTransferShares();

        if(!governance.isFuseSupported(address(fxMintBalance))
            ||!governance.isFuseSupported(address(manager))
            ||!governance.isBalanceFuseSupported(FXMINT_MARKET,address(fxMintBalance))
            ||!governance.isBalanceFuseSupported(ERC20_MARKET,address(erc20Balance))
            ||!governance.isMarketSubstrateGranted(FXMINT_MARKET,fxMintSubstrates[0])
            ||!governance.isMarketSubstrateGranted(YEARN_MARKET,yearnSubstrates[0]))
            revert ConfigurationMismatch();

        // Grant final ownership, then drop deployer temporary privileges in
        // role-administration order: ATOMIST-dependent roles before ATOMIST,
        // and finally OWNER. Final roles explicitly assigned to deployer stay.
        if (owner!=deployer) access.grantRole(Roles.OWNER_ROLE,owner,0);
        if (alpha!=deployer) access.revokeRole(Roles.ALPHA_ROLE,deployer);
        if (fuseManager!=deployer) access.revokeRole(Roles.FUSE_MANAGER_ROLE,deployer);
        if (oracleManager!=deployer) access.revokeRole(Roles.PRICE_ORACLE_MIDDLEWARE_MANAGER_ROLE,deployer);
        if (atomist!=deployer) access.revokeRole(Roles.CONFIG_INSTANT_WITHDRAWAL_FUSES_ROLE,deployer);
        if (atomist!=deployer) access.revokeRole(Roles.ATOMIST_ROLE,deployer);
        if (owner!=deployer) access.revokeRole(Roles.OWNER_ROLE,deployer);
        emit CyFusionConfigured(vault,address(manager),address(fxMintBalance),address(feed));
        emit CyDepositRouterConfigured(vault,address(router));
        console2.log("CY_SIM_DEPLOYED_ATOMIC_DEPOSIT_ROUTER",address(router));
        console2.log("CY_SIM_DEPLOYED_IPOR_VAULT",vault);
        console2.log("CY_SIM_DEPLOYED_LTV_MANAGER",address(manager));
        console2.log("CY_SIM_DEPLOYED_FXMINT_BALANCE_FUSE",address(fxMintBalance));
        console2.log("CY_SIM_DEPLOYED_FXMINT_COLLATERAL_FUSE",address(collateralFuse));
        console2.log("CY_SIM_DEPLOYED_FXMINT_BORROW_FUSE",address(borrowFuse));
        console2.log("CY_SIM_DEPLOYED_FXUSD_FEED",address(feed));
        vm.stopBroadcast();
    }
}

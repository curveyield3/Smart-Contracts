// SPDX-License-Identifier: MIT
// @custom:version v10 — automatic operator-seeded ERC4626 rounding-share reserve; existing selectors preserved.
/**
 * @title CurveYield System Component
 * @notice CurveYield is a decentralized NGO building optimized DeFi systems for the good of all.
 *
 * @dev CurveYield integrates specialized AMM infrastructure, tokenized yield strategies, credit
 * markets, and protocol-owned liquidity into a unified, capital-efficient liquidity stack governed
 * by an open, international DAO community.
 *
 * Protocol operations are enhanced by cross-chain bridging and messaging, MEV capture systems,
 * off-chain to on-chain automation, and peer-to-peer data networks.
 *
 * This contract is one component of the CurveYield system.
 *
 * CurveYield uses proven DeFi primitives where possible and adds targeted coordination and
 * capital-efficiency-enhancing contracts where needed. Users and integrators must review
 * CurveYield documentation before use.
 *
 * Learn more:
 * dApp: https://curveyield.com & https://curveyield.org
 *
 * Decentralized links may have limited or delayed availability during periods of high network activity:
 * https://curveyield.eth.limo
 * https://curveyield.dao
 *
 * Note: curveyield.dao may require a Brave Browser or an Unstoppable Domains browser plugin to use.
 */

pragma solidity 0.8.28;

/**
 * @title CurveYieldOmniAdapterV8
 * @notice A thin, multi-market adapter for the EXISTING Morpho Vault V2.
 *
 * This file also includes an optional minimal native-fee deployer.
 * The deployer charges only at adapter creation and does not implement
 * any vault, fund-management, allocation, or protocol-adapter logic.
 *
 * No custom factory, ownership, curator, allocators, timelocks, risk caps,
 * admin registrations, deposit shares, fee distribution, or vault management.
 * Morpho Vault V2 already implements all of those. Deploy this contract with
 * the parent Vault V2 address, then use VaultV2.addAdapter(address), its normal
 * submit/execute timelocks, its cap ID system, and its allocate/deallocate.
 *
 * One adapter handles unlimited *types* of markets, subject to a bounded active
 * position list (MAX_MARKETS) to make realAssets() practical. Each operation:
 *
 *   VaultV2.allocate(address(this), abi.encode(mode,target,marketId,aux,min), assets)
 *   VaultV2.deallocate(address(this), abi.encode(mode,target,marketId,aux,min), assets)
 *
 * A per-market idData() configures the native Vault V2 absolute/relative caps.
 * No address allowlist is needed here: without the matching native Vault caps
 * the allocator's allocate() reverts atomically.
 *
 * Modes: 1 ERC4626 (Yearn, IPOR, Fluid fTokens, CurveLend V1/V2,
 *                  Euler and compatible synchronous yield vaults);
 *        2 Beefy V7 (BoostHub vaults);
 *        3 Aave V3 / Spark;
 *        4 Compound III Comet;
 *        5 Morpho Blue / compatible core fork;
 *        6 Aave V4 spoke (marketId = reserve ID);
 *        7 Dolomite normal market deposits, account number zero.
 *        8 Yearn V2 vault (non-ERC4626, token()/pricePerShare()).
 *        9 Liquity V2 BOLD stability pool (BOLD principal/yield only; COLL rewards not valued).
 *       10 Dolomite isolation market / distinct account-number positions.
 *
 * IMPORTANT: Maple and Cap are excluded. IPOR Fusion scheduled redemption
 * queues are not fully liquidity-compatible with the
 * synchronous Vault V2 deallocate callback. No live or mock test can turn a
 * time-locked receipt into currently available asset. They are deliberately
 * excluded rather than introducing a false-liquidity path.
 * Liquity V2 COLL reward token is not denominated in underlying BOLD; do not
 * allocate to this mode until a safe, governed reward handling path exists.
 *
 * These modes are not universal protocol compatibility claims.
 *
 * A market must accept the Vault V2 deposit asset. No swaps or conversions.
 * Compilation is not integration testing or an audit.
 * In particular, Morpho projected assets read borrowRateView() and may revert
 * if an integrated IRM is incompatible or reverts, blocking vault-wide reads.
 */

interface ICYV8Factory { function isVaultV2(address vault) external view returns (bool); }
interface ICYV8Parent {
    function asset() external view returns (address);
    function allocation(bytes32 id) external view returns (uint256);
}
interface ICYV8Token {
    function balanceOf(address account) external view returns (uint256);
}
interface ICYV8ERC4626 {
    function asset() external view returns (address);
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function previewRedeem(uint256 shares) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}
interface ICYV8YearnV2 {
    function token() external view returns(address);
    function pricePerShare() external view returns(uint256);
    function decimals() external view returns(uint8);
    function deposit(uint256 assets,address receiver) external returns(uint256);
    function withdraw(uint256 shares,address receiver,uint256 maxLossBps) external returns(uint256);
}
interface ICYV8LiquityBold {
    function boldToken() external view returns(address);
    function getCompoundedBoldDeposit(address account) external view returns(uint256);
    function getDepositorYieldGainWithPending(address account) external view returns(uint256);
    function provideToSP(uint256 assets,bool doClaim) external;
    function withdrawFromSP(uint256 assets,bool doClaim) external;
}
interface ICYV8IsolationFactory {
    function getVaultByAccount(address account) external view returns(address);
}
interface ICYV8Beefy {
    function want() external view returns (address);
    function deposit(uint256 amount) external;
    function withdraw(uint256 shares) external;
    function balanceOf(address) external view returns (uint256);
    function getPricePerFullShare() external view returns (uint256);
}
interface ICYV8AaveV3 {
    struct ReserveConfigurationMap {uint256 data;}
    struct ReserveData {
        ReserveConfigurationMap configuration;
        uint128 liquidityIndex;
        uint128 currentLiquidityRate;
        uint128 variableBorrowIndex;
        uint128 currentVariableBorrowRate;
        uint128 currentStableBorrowRate;
        uint40 lastUpdateTimestamp;
        uint16 id;
        address aTokenAddress;
        address stableDebtTokenAddress;
        address variableDebtTokenAddress;
        address interestRateStrategyAddress;
        uint128 accruedToTreasury;
        uint128 unbacked;
        uint128 isolationModeTotalDebt;
    }
    function getReserveData(address asset_) external view returns (ReserveData memory);
    function supply(address asset_,uint256 amount,address onBehalfOf,uint16 referralCode) external;
    function withdraw(address asset_,uint256 amount,address to) external returns (uint256);
}
interface ICYV8AToken {
    function POOL() external view returns (address);
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
    function balanceOf(address) external view returns (uint256);
}
interface ICYV8Comet {
    function baseToken() external view returns (address);
    function supply(address asset_,uint256 amount) external;
    function withdraw(address asset_,uint256 amount) external;
    function balanceOf(address) external view returns (uint256);
}
interface ICYV8Morpho {
    struct MarketParams {address loanToken;address collateralToken;address oracle;address irm;uint256 lltv;}
    struct Market {uint128 totalSupplyAssets;uint128 totalSupplyShares;uint128 totalBorrowAssets;uint128 totalBorrowShares;uint128 lastUpdate;uint128 fee;}
    struct Position {uint256 supplyShares;uint128 borrowShares;uint128 collateral;}
    function market(bytes32 id) external view returns (Market memory);
    function position(bytes32 id,address account) external view returns (Position memory);
    function idToMarketParams(bytes32 id) external view returns (MarketParams memory);
    function supply(MarketParams memory params,uint256 assets,uint256 shares,address behalf,bytes memory data) external returns (uint256,uint256);
    function withdraw(MarketParams memory params,uint256 assets,uint256 shares,address behalf,address receiver) external returns (uint256,uint256);
}
interface ICYV8Irm {
    function borrowRateView(ICYV8Morpho.MarketParams memory params,ICYV8Morpho.Market memory market) external view returns(uint256);
}
interface ICYV8AaveSpoke {
    struct Reserve {address underlying;address hub;uint16 assetId;uint8 decimals;uint24 collateralRisk;uint8 flags;uint32 dynamicConfigKey;}
    function getReserve(uint256 reserveId) external view returns (Reserve memory);
    function getUserSuppliedAssets(uint256 reserveId,address user) external view returns (uint256);
    function supply(uint256 reserveId,uint256 assets,address behalf) external returns (uint256,uint256);
    function withdraw(uint256 reserveId,uint256 assets,address behalf) external returns (uint256,uint256);
}
interface ICYV8Dolomite {
    struct Account {address owner;uint256 number;}
    struct SignedWei {bool sign;uint256 value;}
    function getMarketTokenAddress(uint256 marketId) external view returns (address);
    function getAccountWei(Account calldata account,uint256 marketId) external view returns (SignedWei memory);
}
interface ICYV8DolomiteRouter {
    function DOLOMITE_MARGIN() external view returns (address);
    function depositWei(uint256 isolationModeMarketId,uint256 accountNumber,uint256 marketId,uint256 assets,uint8 eventFlag) external;
    function withdrawWei(uint256 isolationModeMarketId,uint256 accountNumber,uint256 marketId,uint256 assets,uint8 balanceCheckFlag) external;
}
library CYV8Math {
    // Match Morpho Blue MathLib's three-term WAD compounded interest projection.
    function wTaylorCompounded(uint256 rate,uint256 elapsed) internal pure returns(uint256) {
        uint256 first=rate*elapsed;
        uint256 second=mulDiv(first,first,2e18);
        uint256 third=mulDiv(second,first,3e18);
        return first+second+third;
    }
    function mulDiv(uint256 x,uint256 y,uint256 denominator) internal pure returns(uint256 result) {
        unchecked {
            uint256 p0;uint256 p1;
            assembly {
                let mm := mulmod(x,y,not(0))
                p0 := mul(x,y)
                p1 := sub(sub(mm,p0),lt(mm,p0))
            }
            if(p1==0)return p0/denominator;
            require(denominator>p1,"mulDiv");
            uint256 rem;
            assembly {rem := mulmod(x,y,denominator)}
            assembly {p1 := sub(p1,gt(rem,p0)) p0 := sub(p0,rem)}
            uint256 twos=denominator & (0-denominator);
            assembly {
                denominator := div(denominator,twos)
                p0 := div(p0,twos)
                twos := add(div(sub(0,twos),twos),1)
            }
            p0|=p1*twos;
            uint256 inv=(3*denominator)^2;
            inv*=2-denominator*inv;
            inv*=2-denominator*inv;
            inv*=2-denominator*inv;
            inv*=2-denominator*inv;
            inv*=2-denominator*inv;
            inv*=2-denominator*inv;
            result=p0*inv;
        }
    }
}
contract CurveYieldOmniAdapterV8 {
    uint8 private constant ERC4626=1;
    uint8 private constant BEEFY_V7=2;
    uint8 private constant AAVE_V3=3;
    uint8 private constant COMPOUND=4;
    uint8 private constant MORPHO=5;
    uint8 private constant AAVE_V4=6;
    uint8 private constant DOLOMITE=7;
    uint8 private constant YEARN_V2=8;
    uint8 private constant LIQUITY_BOLD=9;
    uint8 private constant DOLOMITE_ISOLATED=10;
    uint256 private constant SCALE=1e18;
    uint256 public constant MAX_MARKETS=128;

    address public immutable parentVault;
    address public immutable asset;

    // Only data that cannot be recovered from external markets is retained.
    struct MarketRef {
        address target;   // Supply contract, Aave pool/spoke, Morpho core, or Dolomite router
        address auxiliary;// Aave V3 aToken or Dolomite margin; zero otherwise
        bytes32 marketId; // Morpho market ID, Aave V4 reserve ID or Dolomite market ID
        uint8 mode;
        uint256 credit;   // Surplus underlying from an exact withdrawal; market-attributed
        uint256 trackedShares; // Excludes operator-seeded rounding shares from NAV (and unsolicited share donations)
    }
    mapping(bytes32 key=>MarketRef) public markets;
    struct IsolatedAccount {uint256 isolationMarketId;uint256 accountNumber;uint256 underlyingMarketId;address accountVault;}
    mapping(bytes32 key=>IsolatedAccount) private isolationAccounts;
    bytes32[] private active;
    mapping(bytes32 key=>uint256) private indexPlusOne;
    bool private entered;

    error OnlyVault();
    error UnsupportedMode();
    error InvalidMarket();
    error AssetMismatch();
    error InvalidInput();
    error InsufficientAssets();
    error TooManyMarkets();
    error Reentered();
    error ApprovalFailed();
    error ValuationOverflow();

    event EnteredMarket(bytes32 indexed key,address indexed target,uint8 indexed mode);
    event ExitedMarket(bytes32 indexed key);
    event RoundingReserveConsumed(bytes32 indexed key,uint256 shares);

    constructor(address vault) {
        if(vault.code.length==0)revert InvalidMarket();
        parentVault=vault;
        asset=ICYV8Parent(vault).asset();
        if(asset.code.length==0)revert AssetMismatch();
        _approve(vault,type(uint256).max);
    }
    modifier onlyVault() {
        if(msg.sender!=parentVault)revert OnlyVault();
        if(entered)revert Reentered();
        entered=true;_;entered=false;
    }
    function keyOf(uint8 mode,address target,bytes32 marketId,address auxiliary) public view returns(bytes32) {
        return keccak256(abi.encode("curveyield/omni-v8",address(this),mode,target,marketId,auxiliary));
    }
    function idData(uint8 mode,address target,bytes32 marketId,address auxiliary) external view returns(bytes memory) {
        return abi.encode("curveyield/omni-v8",address(this),mode,target,marketId,auxiliary);
    }
    /// @notice Share-token units transferred directly by the operator (or others),
    ///         beyond shares acquired through the vault's own allocations.
    /// @dev Untracked ERC4626 shares never enter NAV. They are used only to
    ///      cover additional rounding shares on redemption. Transfer shares
    ///      to this adapter separately after deployment; no privileged funding
    ///      or share-minting function is needed. This is not a token burn.
    function roundingReserveShares(address shareVault) external view returns(uint256) {
        if(shareVault.code.length==0||ICYV8ERC4626(shareVault).asset()!=asset)revert InvalidMarket();
        uint256 tracked=markets[keyOf(ERC4626,shareVault,bytes32(0),address(0))].trackedShares;
        uint256 held=ICYV8Token(shareVault).balanceOf(address(this));
        return held>tracked?held-tracked:0;
    }
    function marketCount() external view returns(uint256){return active.length;}
    function marketAt(uint256 index) external view returns(bytes32 key,MarketRef memory market) {
        key=active[index];market=markets[key];
    }
    // Native Morpho Vault V2 cap ID: use keccak256(idData(...)).
    function _capId(bytes32 key) private pure returns(bytes32){return key;}
    function _approve(address spender,uint256 amount) private {
        (bool success,bytes memory ret)=asset.call(
            abi.encodeWithSelector(bytes4(0x095ea7b3),spender,amount)
        );
        if(!success||(ret.length!=0&&(ret.length!=32||!abi.decode(ret,(bool)))))
            revert ApprovalFailed();
    }

    function _validate(uint8 mode,address target,bytes32 marketId,address auxiliary,bytes memory extra) private view returns(address cachedAux) {
        if(target.code.length==0)revert InvalidMarket();
        cachedAux=auxiliary;
        if(mode==ERC4626) {
            if(marketId!=0||auxiliary!=address(0)||extra.length!=0||ICYV8ERC4626(target).asset()!=asset)revert AssetMismatch();
        } else if(mode==BEEFY_V7) {
            if(marketId!=0||auxiliary!=address(0)||extra.length!=0||ICYV8Beefy(target).want()!=asset)revert AssetMismatch();
        } else if(mode==AAVE_V3) {
            if(marketId!=0||auxiliary!=address(0)||extra.length!=0)revert InvalidInput();
            cachedAux=ICYV8AaveV3(target).getReserveData(asset).aTokenAddress;
            if(cachedAux.code.length==0||ICYV8AToken(cachedAux).POOL()!=target
               ||ICYV8AToken(cachedAux).UNDERLYING_ASSET_ADDRESS()!=asset)revert InvalidMarket();
        } else if(mode==COMPOUND) {
            if(marketId!=0||auxiliary!=address(0)||extra.length!=0||ICYV8Comet(target).baseToken()!=asset)revert AssetMismatch();
        } else if(mode==MORPHO) {
            if(auxiliary!=address(0)||extra.length!=160)revert InvalidInput();
            ICYV8Morpho.MarketParams memory p=abi.decode(extra,(ICYV8Morpho.MarketParams));
            if(p.loanToken!=asset||keccak256(abi.encode(p))!=marketId)revert AssetMismatch();
            if(ICYV8Morpho(target).market(marketId).lastUpdate==0)revert InvalidMarket();
        } else if(mode==AAVE_V4) {
            if(auxiliary!=address(0)||extra.length!=0||ICYV8AaveSpoke(target).getReserve(uint256(marketId)).underlying!=asset)
                revert AssetMismatch();
        } else if(mode==DOLOMITE) {
            if(extra.length!=0||auxiliary.code.length==0||ICYV8DolomiteRouter(target).DOLOMITE_MARGIN()!=auxiliary||
                ICYV8Dolomite(auxiliary).getMarketTokenAddress(uint256(marketId))!=asset)revert AssetMismatch();
        } else if(mode==YEARN_V2) {
            if(marketId!=0||auxiliary!=address(0)||extra.length!=0||ICYV8YearnV2(target).token()!=asset||
               ICYV8YearnV2(target).decimals()>77||ICYV8YearnV2(target).pricePerShare()==0)revert AssetMismatch();
        } else if(mode==LIQUITY_BOLD) {
            if(marketId!=0||auxiliary!=address(0)||extra.length!=0||ICYV8LiquityBold(target).boldToken()!=asset)revert AssetMismatch();
        } else if(mode==DOLOMITE_ISOLATED) {
            if(auxiliary.code.length==0||ICYV8DolomiteRouter(target).DOLOMITE_MARGIN()!=auxiliary||extra.length!=96)revert InvalidMarket();
            (uint256 isolationId,uint256 accountNumber,uint256 actualMarketId)=abi.decode(extra,(uint256,uint256,uint256));
            if(isolationId==0||keccak256(abi.encode(isolationId,accountNumber,actualMarketId))!=marketId||
               ICYV8Dolomite(auxiliary).getMarketTokenAddress(actualMarketId)!=asset)revert AssetMismatch();
            address factory=ICYV8Dolomite(auxiliary).getMarketTokenAddress(isolationId);
            if(factory.code.length==0)revert InvalidMarket();
        } else revert UnsupportedMode();
    }

    function _value(bytes32 key) private view returns(uint256 amount) {
        MarketRef storage m=markets[key];
        if(m.target==address(0))return 0;
        amount=m.credit;
        if(m.mode==ERC4626) {
            return amount+ICYV8ERC4626(m.target).previewRedeem(m.trackedShares);
        }
        if(m.mode==YEARN_V2) {
            uint256 scale=10**uint256(ICYV8YearnV2(m.target).decimals());
            return amount+CYV8Math.mulDiv(m.trackedShares,ICYV8YearnV2(m.target).pricePerShare(),scale);
        }
        if(m.mode==LIQUITY_BOLD) {
            return amount+ICYV8LiquityBold(m.target).getCompoundedBoldDeposit(address(this))
                +ICYV8LiquityBold(m.target).getDepositorYieldGainWithPending(address(this));
        }
        if(m.mode==BEEFY_V7) {
            uint256 shares=m.trackedShares;
            return amount+CYV8Math.mulDiv(shares,ICYV8Beefy(m.target).getPricePerFullShare(),SCALE);
        }
        if(m.mode==AAVE_V3)return amount+ICYV8AToken(m.auxiliary).balanceOf(address(this));
        if(m.mode==COMPOUND)return amount+ICYV8Comet(m.target).balanceOf(address(this));
        if(m.mode==AAVE_V4)return amount+ICYV8AaveSpoke(m.target).getUserSuppliedAssets(uint256(m.marketId),address(this));
        if(m.mode==MORPHO) {
            if(m.trackedShares==0)return amount;
            ICYV8Morpho.Market memory market=ICYV8Morpho(m.target).market(m.marketId);
            uint256 supplied=uint256(market.totalSupplyAssets);
            uint256 shares=uint256(market.totalSupplyShares);
            uint256 elapsed=block.timestamp-uint256(market.lastUpdate);
            // Morpho's raw market() excludes unaccrued lending interest and fee shares.
            if(elapsed!=0&&market.totalBorrowAssets!=0) {
                ICYV8Morpho.MarketParams memory params=ICYV8Morpho(m.target).idToMarketParams(m.marketId);
                if(params.irm!=address(0)){
                    uint256 rate=ICYV8Irm(params.irm).borrowRateView(params,market);
                    uint256 interest=CYV8Math.mulDiv(uint256(market.totalBorrowAssets),
                        CYV8Math.wTaylorCompounded(rate,elapsed),SCALE);
                    supplied+=interest;
                    if(market.fee!=0) {
                        uint256 feeAmount=CYV8Math.mulDiv(interest,uint256(market.fee),SCALE);
                        shares+=CYV8Math.mulDiv(feeAmount,shares+1e6,supplied-feeAmount+1);
                    }
                }
            }
            return amount+CYV8Math.mulDiv(m.trackedShares,supplied+1,shares+1e6);
        }
        if(m.mode==DOLOMITE||m.mode==DOLOMITE_ISOLATED) {
            address account=address(this);
            uint256 accountNumber;
            uint256 actualMarketId=uint256(m.marketId);
            if(m.mode==DOLOMITE_ISOLATED) {
                IsolatedAccount storage i=isolationAccounts[key];
                account=i.accountVault;accountNumber=i.accountNumber;actualMarketId=i.underlyingMarketId;
            }
            ICYV8Dolomite.SignedWei memory w=ICYV8Dolomite(m.auxiliary).getAccountWei(
                ICYV8Dolomite.Account(account,accountNumber),actualMarketId);
            if(!w.sign&&w.value!=0)revert InvalidMarket();
            return amount+w.value;
        }
        revert UnsupportedMode();
    }
    function realAssets() external view returns(uint256 total) {
        for(uint256 i;i<active.length;++i)total+=_value(active[i]);
    }
    function positionAssets(uint8 mode,address target,bytes32 marketId,address auxiliary) external view returns(uint256) {
        return _value(keyOf(mode,target,marketId,auxiliary));
    }

    function _deposit(MarketRef storage m,uint256 amount,bytes memory extra) private returns(uint256 minted) {
        if(m.mode==ERC4626||m.mode==BEEFY_V7) {
            uint256 beforeShares=ICYV8Token(m.target).balanceOf(address(this));
            if(m.mode==ERC4626)ICYV8ERC4626(m.target).deposit(amount,address(this));
            else ICYV8Beefy(m.target).deposit(amount);
            uint256 afterShares=ICYV8Token(m.target).balanceOf(address(this));
            if(afterShares<=beforeShares)revert InsufficientAssets();
            minted=afterShares-beforeShares;
            m.trackedShares+=minted;
        } else if(m.mode==AAVE_V3)ICYV8AaveV3(m.target).supply(asset,amount,address(this),0);
        else if(m.mode==COMPOUND)ICYV8Comet(m.target).supply(asset,amount);
        else if(m.mode==AAVE_V4)(minted,)=ICYV8AaveSpoke(m.target).supply(uint256(m.marketId),amount,address(this));
        else if(m.mode==MORPHO) {
            ICYV8Morpho.MarketParams memory p=abi.decode(extra,(ICYV8Morpho.MarketParams));
            (,minted)=ICYV8Morpho(m.target).supply(p,amount,0,address(this),"");
            // Match Morpho's native Vault V2 adapter: reject share-price-above-one/inflation states.
            if(minted<amount)revert InsufficientAssets();
            m.trackedShares+=minted;
        } else if(m.mode==DOLOMITE)ICYV8DolomiteRouter(m.target).depositWei(0,0,uint256(m.marketId),amount,0);
        else if(m.mode==DOLOMITE_ISOLATED) {
            IsolatedAccount storage i=isolationAccounts[keyOf(m.mode,m.target,m.marketId,m.auxiliary)];
            ICYV8DolomiteRouter(m.target).depositWei(i.isolationMarketId,i.accountNumber,i.underlyingMarketId,amount,0);
            // Router may create isolation vault during first deposit.
            address f=ICYV8Dolomite(m.auxiliary).getMarketTokenAddress(i.isolationMarketId);
            i.accountVault=ICYV8IsolationFactory(f).getVaultByAccount(address(this));
            if(i.accountVault.code.length==0)revert InvalidMarket();
        } else if(m.mode==YEARN_V2) {
            uint256 beforeShares=ICYV8Token(m.target).balanceOf(address(this));
            uint256 beforeAssets=ICYV8Token(asset).balanceOf(address(this));
            ICYV8YearnV2(m.target).deposit(amount,address(this));
            if(beforeAssets-ICYV8Token(asset).balanceOf(address(this))!=amount)revert InsufficientAssets();
            minted=ICYV8Token(m.target).balanceOf(address(this))-beforeShares;
            if(minted==0)revert InsufficientAssets();
            m.trackedShares+=minted;
        } else if(m.mode==LIQUITY_BOLD) {
            // BOLD yield compounds in stability pool, collateral gains remain stashed there.
            ICYV8LiquityBold(m.target).provideToSP(amount,false);
            minted=amount;
        } else revert UnsupportedMode();
    }
    function _withdraw(MarketRef storage m,uint256 amount,bytes memory extra) private {
        if(m.mode==ERC4626||m.mode==BEEFY_V7) {
            uint256 beforeShares=ICYV8Token(m.target).balanceOf(address(this));
            if(m.mode==ERC4626) {
                // Some otherwise ERC4626-compatible vaults (including aCRV) round
                // withdraw() down by a few wei. Burn enough shares through redeem()
                // to cover the requested underlying, and preserve any overage as
                // per-market credit in _release(). Never conceal genuine losses:
                // _value() uses current redeemable assets, which Vault V2 uses
                // to lower NAV/share price when a strategy loses value.
                ICYV8ERC4626 vault=ICYV8ERC4626(m.target);
                uint256 owned=m.trackedShares;
                if(beforeShares<owned)revert InsufficientAssets();
                uint256 reserve=beforeShares-owned; // Direct transfers, excluded from NAV
                uint256 redeemable=vault.previewRedeem(owned);
                if(owned==0||redeemable==0)revert InsufficientAssets();
                // Proportional principal shares rounded DOWN. Only the extra
                // share units needed to round a redemption UP use the reserve.
                uint256 principalShares=CYV8Math.mulDiv(amount,owned,redeemable);
                if(principalShares>owned)principalShares=owned;
                uint256 shares=principalShares;
                uint256 quote=vault.previewRedeem(shares);
                if(quote<amount) {
                    uint256 extra=CYV8Math.mulDiv(amount-quote,owned,redeemable)+1;
                    uint256 room=beforeShares-shares;
                    shares+=extra>room?room:extra;
                    // Some vaults have nonlinear previews; spend no more than
                    // the physically held shares, including operator seed dust.
                    if(vault.previewRedeem(shares)<amount)shares=beforeShares;
                }
                // No artificial change in principal shares when rounding
                // consumes donor-funded reserve shares instead.
                vault.redeem(shares,address(this),address(this));
                uint256 afterShares=ICYV8Token(m.target).balanceOf(address(this));
                if(afterShares>=beforeShares)revert InsufficientAssets();
                uint256 burned=beforeShares-afterShares;
                uint256 reserveUsed=burned>principalShares?burned-principalShares:0;
                if(reserveUsed>reserve)reserveUsed=reserve;
                uint256 principalBurned=burned-reserveUsed;
                if(principalBurned>owned)revert InsufficientAssets();
                m.trackedShares=owned-principalBurned;
                if(reserveUsed!=0)emit RoundingReserveConsumed(
                    keyOf(ERC4626,m.target,bytes32(0),address(0)),reserveUsed
                );
            }else{
                uint256 pps=ICYV8Beefy(m.target).getPricePerFullShare();
                if(pps==0)revert InsufficientAssets();
                uint256 shares=CYV8Math.mulDiv(amount,SCALE,pps);
                if(CYV8Math.mulDiv(shares,pps,SCALE)<amount)++shares;
                ICYV8Beefy(m.target).withdraw(shares);
                uint256 afterShares=ICYV8Token(m.target).balanceOf(address(this));
                if(afterShares>=beforeShares||beforeShares-afterShares>m.trackedShares)revert InsufficientAssets();
                m.trackedShares-=beforeShares-afterShares;
            }
        } else if(m.mode==AAVE_V3)ICYV8AaveV3(m.target).withdraw(asset,amount,address(this));
        else if(m.mode==COMPOUND)ICYV8Comet(m.target).withdraw(asset,amount);
        else if(m.mode==AAVE_V4)ICYV8AaveSpoke(m.target).withdraw(uint256(m.marketId),amount,address(this));
        else if(m.mode==MORPHO) {
            ICYV8Morpho.MarketParams memory p=abi.decode(extra,(ICYV8Morpho.MarketParams));
            (,uint256 burned)=ICYV8Morpho(m.target).withdraw(p,amount,0,address(this),address(this));
            if(burned>m.trackedShares)revert InsufficientAssets();
            m.trackedShares-=burned;
        } else if(m.mode==DOLOMITE)ICYV8DolomiteRouter(m.target).withdrawWei(0,0,uint256(m.marketId),amount,1);
        else if(m.mode==DOLOMITE_ISOLATED) {
            IsolatedAccount storage i=isolationAccounts[keyOf(m.mode,m.target,m.marketId,m.auxiliary)];
            ICYV8DolomiteRouter(m.target).withdrawWei(i.isolationMarketId,i.accountNumber,i.underlyingMarketId,amount,1);
        } else if(m.mode==LIQUITY_BOLD) {
            ICYV8LiquityBold(m.target).withdrawFromSP(amount,true);
        } else if(m.mode==YEARN_V2) {
            uint256 beforeShares=ICYV8Token(m.target).balanceOf(address(this));
            uint256 scale=10**uint256(ICYV8YearnV2(m.target).decimals());
            uint256 pps=ICYV8YearnV2(m.target).pricePerShare();
            uint256 shares=CYV8Math.mulDiv(amount,scale,pps);
            if(CYV8Math.mulDiv(shares,pps,scale)<amount)++shares;
            if(shares>m.trackedShares)revert InsufficientAssets();
            uint256 maxLoss=extra.length==0?0:abi.decode(extra,(uint256));
            if(maxLoss>10000)revert InvalidInput();
            ICYV8YearnV2(m.target).withdraw(shares,address(this),maxLoss);
            uint256 afterShares=ICYV8Token(m.target).balanceOf(address(this));
            if(afterShares>=beforeShares||beforeShares-afterShares>m.trackedShares)revert InsufficientAssets();
            m.trackedShares-=beforeShares-afterShares;
        } else revert UnsupportedMode();
    }

    function _release(MarketRef storage m,uint256 assets,bytes memory extra) private {
        if(assets<=m.credit) {
            m.credit-=assets;
            return;
        }
        uint256 needed=assets-m.credit;
        uint256 beforeAssets=ICYV8Token(asset).balanceOf(address(this));
        _withdraw(m,needed,extra);
        uint256 received=ICYV8Token(asset).balanceOf(address(this))-beforeAssets;
        if(received<needed)revert InsufficientAssets();
        m.credit=m.credit+received-assets;
    }

    function _response(bytes32 key,uint256 previous) private view returns(bytes32[] memory ids,int256 change) {
        uint256 current=_value(key);
        if(current>uint256(type(int256).max)||previous>uint256(type(int256).max))revert ValuationOverflow();
        ids=new bytes32[](1);
        ids[0]=_capId(key);
        change=int256(current)-int256(previous);
    }

    // data = abi.encode(uint8 mode, address target, bytes32 marketId,
    //                   address auxiliary, uint256 minShares, bytes extra).
    // Morpho Blue extra=MarketParams; isolated Dolomite extra=(isolatedId,accountNum,marketId).
    // Yearn V2 deallocate extra=optional maxLossBps.
    function allocate(bytes memory data,uint256 assets,bytes4,address)
        external onlyVault returns(bytes32[] memory ids,int256 change)
    {
        (uint8 mode,address target,bytes32 marketId,address aux,uint256 minShares,bytes memory extra)=
            abi.decode(data,(uint8,address,bytes32,address,uint256,bytes));
        bytes32 key=keyOf(mode,target,marketId,aux);
        MarketRef storage m=markets[key];
        if(m.target==address(0)){
            address validatedAux=_validate(mode,target,marketId,aux,extra);
            if(active.length>=MAX_MARKETS)revert TooManyMarkets();
            m.target=target;m.auxiliary=validatedAux;m.marketId=marketId;m.mode=mode;
            if(mode==DOLOMITE_ISOLATED) {
                (uint256 isolationId,uint256 accountNum,uint256 actualId)=abi.decode(extra,(uint256,uint256,uint256));
                isolationAccounts[key]=IsolatedAccount(isolationId,accountNum,actualId,address(0));
            }
            indexPlusOne[key]=active.length+1;active.push(key);
            emit EnteredMarket(key,target,mode);
        }else {
            if(m.mode!=mode||m.target!=target|| (mode==DOLOMITE&&m.auxiliary!=aux))revert InvalidMarket();
            if(mode==MORPHO||mode==DOLOMITE_ISOLATED) _validate(mode,target,marketId,aux,extra);
            else if(extra.length!=0)revert InvalidInput();
        }
        uint256 previous=ICYV8Parent(parentVault).allocation(_capId(key));
        uint256 amount=assets+m.credit;
        if(amount!=0){
            m.credit=0;
            _approve(target,amount);
            uint256 minted=_deposit(m,amount,extra);
            _approve(target,0);
            if(minted<minShares)revert InsufficientAssets();
        }else if(minShares!=0)revert InvalidInput();
        (ids,change)=_response(key,previous);
    }

    // data uses identical tuple, but minShares is interpreted as minAssets
    // actually received. Vault V2 pulls the exact requested assets afterwards.
    function deallocate(bytes memory data,uint256 assets,bytes4,address)
        external onlyVault returns(bytes32[] memory ids,int256 change)
    {
        (uint8 mode,address target,bytes32 marketId,address aux,uint256 minAssets,bytes memory extra)=
            abi.decode(data,(uint8,address,bytes32,address,uint256,bytes));
        bytes32 key=keyOf(mode,target,marketId,aux);
        MarketRef storage m=markets[key];
        if(m.target!=target||m.target==address(0)||m.mode!=mode)revert InvalidMarket();
        if(mode==MORPHO||mode==DOLOMITE_ISOLATED)_validate(mode,target,marketId,aux,extra);
        else if(mode==YEARN_V2){if(extra.length!=0&&extra.length!=32)revert InvalidInput();}
        else if(extra.length!=0)revert InvalidInput();
        if(assets<minAssets)revert InsufficientAssets();
        uint256 previous=ICYV8Parent(parentVault).allocation(_capId(key));
        _release(m,assets,extra);
        (ids,change)=_response(key,previous);
        // Remove completely exited positions; cap/ownership rights stay in Vault V2.
        if(m.trackedShares==0&&m.credit==0&&_value(key)==0){
            uint256 index=indexPlusOne[key]-1;
            uint256 last=active.length-1;
            if(index!=last){
                bytes32 swapKey=active[last];active[index]=swapKey;
                indexPlusOne[swapKey]=index+1;
            }
            active.pop();delete indexPlusOne[key];delete markets[key];delete isolationAccounts[key];
            emit ExitedMarket(key);
        }
    }
}

// @notice Optional minimal paid deployment entrypoint. Not a vault.
contract CurveYieldOmniAdapterDeployerV8 {
    address private constant INITIAL_CURVEYIELD_SAFE = 0x47623C62f281807D615eeb4A2CEee9d97F9D3C49;

    address public immutable vaultFactory;
    uint256 public immutable maximumCreationFee;
    address public owner;
    address payable public feeRecipient;
    uint256 public creationFee;
    mapping(address vault => address adapter) public adapterOf;

    error NotOwner();
    error InvalidAddress();
    error InvalidVault();
    error AlreadyCreated();
    error FeeTooHigh();
    error IncorrectFee(uint256 supplied, uint256 required);
    error NativeFeeTransferFailed();

    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event OmniAdapterCreated(address indexed parentVault, address indexed adapter, uint256 nativeFee, address indexed feeReceiver);

    /// @param vaultFactory_ Existing native Morpho Vault V2 factory on the target chain.
    /// @param maximumCreationFeeWei_ Absolute fee ceiling, in native gas-token wei.
    ///        Fraxtal deployment parameter: 1 ether (1 native FRAX, 10**18 wei).
    /// @dev Initial owner & fee recipient = CurveYield Safe. Fee starts at 0.
    ///      The owner can set the fee to any amount <= immutable maximum.
    constructor(address vaultFactory_, uint256 maximumCreationFeeWei_) {
        if(vaultFactory_.code.length == 0) revert InvalidAddress();
        vaultFactory = vaultFactory_;
        maximumCreationFee = maximumCreationFeeWei_;
        owner = INITIAL_CURVEYIELD_SAFE;
        feeRecipient = payable(INITIAL_CURVEYIELD_SAFE);
    }

    modifier onlyOwner() {
        if(msg.sender != owner) revert NotOwner();
        _;
    }

    function setCreationFee(uint256 newFee) external onlyOwner {
        if(newFee > maximumCreationFee) revert FeeTooHigh();
        emit FeeUpdated(creationFee, newFee);
        creationFee = newFee;
    }

    function setFeeRecipient(address payable newRecipient) external onlyOwner {
        if(newRecipient == address(0)) revert InvalidAddress();
        emit FeeRecipientUpdated(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }

    /// @dev Ownership administration ONLY for fee/deployer settings.
    ///      It does not confer any privileges over Vault V2 or deployed adapters.
    function transferOwnership(address nextOwner) external onlyOwner {
        if(nextOwner == address(0)) revert InvalidAddress();
        emit OwnershipTransferred(owner, nextOwner);
        owner = nextOwner;
    }

    /// @notice Deploy one adapter for an existing official Vault V2.
    /// @dev Native fee is transferred immediately to the configured recipient.
    ///      This contract does not custody Vault V2 assets or approve markets.
    function createAdapter(address vault) external payable returns (address deployed) {
        uint256 fee = creationFee;
        if(msg.value != fee) revert IncorrectFee(msg.value, fee);
        if(adapterOf[vault] != address(0)) revert AlreadyCreated();
        if(!ICYV8Factory(vaultFactory).isVaultV2(vault)) revert InvalidVault();
        deployed = address(new CurveYieldOmniAdapterV8(vault));
        adapterOf[vault] = deployed;
        if(fee != 0) {
            (bool sent,) = feeRecipient.call{value: fee}("");
            if(!sent) revert NativeFeeTransferFailed();
        }
        emit OmniAdapterCreated(vault, deployed, fee, feeRecipient);
    }
}

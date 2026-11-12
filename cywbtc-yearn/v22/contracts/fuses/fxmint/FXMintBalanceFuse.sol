// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IFuseCommon} from "../IFuseCommon.sol";
import {IMarketBalanceFuse} from "../IMarketBalanceFuse.sol";
import {PlasmaVaultConfigLib} from "../../libraries/PlasmaVaultConfigLib.sol";
import {PlasmaVaultLib} from "../../libraries/PlasmaVaultLib.sol";
import {IPriceOracleMiddleware} from "../../price_oracle/IPriceOracleMiddleware.sol";

interface IFXMintPositionPoolV22 {
    function ownerOf(uint256 positionId) external view returns (address);
    function getNextPositionId() external view returns (uint32);
    function getPosition(uint256 positionId) external view returns (uint256 rawCollateral, uint256 rawDebt);
    function collateralToken() external view returns (address);
    function fxUSD() external view returns (address);
    function poolManager() external view returns (address);
}

interface IFXMintCollateralScaleV22 {
    function getTokenScalingFactor(address token) external view returns (uint256);
}

/// @title FXMintBalanceFuse
/// @notice Direct on-chain fxMINT NFT accounting for IPOR Fusion; not an Aave adapter.
/// @dev Uses official IPOR market ID 49 provisionally. This does not emulate Aave V4.
///      IPOR's `balanceOf()` interface is uint256: collateral USD minus debt USD must
///      be nonnegative. Net-negative exposure reverts rather than being hidden.
///      The PlasmaVault separately counts wallet-held WBTC as its ERC4626 asset.
///      Market 7's standard ERC20BalanceFuse separately counts wallet-held non-WBTC ERC20s.
///      A single tracked NFT is supported, and it is registered atomically after minting.
contract FXMintBalanceFuse is IFuseCommon, IMarketBalanceFuse {
    uint256 public constant MARKET_ID = 49;
    uint256 private constant WAD = 1e18;

    address public immutable VERSION;
    address public immutable VAULT;
    address public immutable ADMIN;
    address public immutable FXMINT_WBTC_POOL;
    address public immutable FXMINT_POOL_MANAGER;
    address public immutable WBTC;
    address public immutable FXUSD;
    uint8 public immutable WBTC_DECIMALS;
    uint8 public immutable FXUSD_DECIMALS;

    // Implementation-owned state, NOT PlasmaVault delegatecall storage.
    uint256 public positionId;

    error InvalidConfiguration();
    error Unauthorized();
    error WrongExecutionContext();
    error NoMintedPosition();
    error IncorrectOwner(uint256 id, address observed);
    error ActivePositionCannotBeReplaced(uint256 id);
    error EmptyPosition(uint256 id);
    error MarketSubstrateMismatch();
    error InvalidPrice(address token);
    error InvalidScalingFactor();
    error InsolventFxMintPosition(uint256 collateralUsdWad, uint256 debtUsdWad);

    event PositionIdConfigured(uint256 indexed oldId, uint256 indexed newId);
    event LatestPositionRegistered(address indexed vault, uint256 indexed id);

    constructor(address vault_, address admin_, address fxMintPool_, address wbtc_, address fxusd_) {
        if (vault_ == address(0) || admin_ == address(0) || fxMintPool_ == address(0) ||
            wbtc_ == address(0) || fxusd_ == address(0)) revert InvalidConfiguration();

        IFXMintPositionPoolV22 pool = IFXMintPositionPoolV22(fxMintPool_);
        if (pool.collateralToken() != wbtc_ || pool.fxUSD() != fxusd_ ||
            pool.poolManager() == address(0)) revert InvalidConfiguration();

        VERSION = address(this);
        VAULT = vault_;
        ADMIN = admin_;
        FXMINT_WBTC_POOL = fxMintPool_;
        FXMINT_POOL_MANAGER = pool.poolManager();
        WBTC = wbtc_;
        FXUSD = fxusd_;
        WBTC_DECIMALS = IERC20Metadata(wbtc_).decimals();
        FXUSD_DECIMALS = IERC20Metadata(fxusd_).decimals();
        if (WBTC_DECIMALS != 8 || FXUSD_DECIMALS != 18) revert InvalidConfiguration();
    }

    /// @notice Delegatecalled immediately after FXMintCollateralFuse.enterNewPosition.
    /// @dev Calls into this implementation to persist the ID in implementation storage.
    function enterRegisterLatestPosition() external {
        if (address(this) != VAULT) revert WrongExecutionContext();
        FXMintBalanceFuse(VERSION).registerLatestPositionFromVault();
    }

    /// @notice Only the PlasmaVault may register the most recently minted NFT.
    function registerLatestPositionFromVault() external {
        if (msg.sender != VAULT || address(this) != VERSION) revert Unauthorized();
        IFXMintPositionPoolV22 pool = IFXMintPositionPoolV22(FXMINT_WBTC_POOL);
        uint256 nextId = pool.getNextPositionId();
        if (nextId <= 1) revert NoMintedPosition();
        uint256 id = nextId - 1;
        _register(pool, id);
        emit LatestPositionRegistered(VAULT, id);
    }

    /// @notice Governance recovery for a verified existing owned position.
    /// @dev Cannot replace an outstanding nonempty position with a different one.
    function setPositionId(uint256 newId) external {
        if (msg.sender != ADMIN || address(this) != VERSION) revert Unauthorized();
        _register(IFXMintPositionPoolV22(FXMINT_WBTC_POOL), newId);
    }

    function _register(IFXMintPositionPoolV22 pool, uint256 id) private {
        if (id == 0) revert NoMintedPosition();
        address observed = pool.ownerOf(id);
        if (observed != VAULT) revert IncorrectOwner(id, observed);
        (uint256 collateral, uint256 debt) = pool.getPosition(id);
        if (collateral == 0 && debt == 0) revert EmptyPosition(id);

        uint256 old = positionId;
        if (old != 0 && old != id) {
            // Fail closed on inaccessible old NFT state; never erase possible debt.
            (uint256 oldCollateral, uint256 oldDebt) = pool.getPosition(old);
            if (oldCollateral != 0 || oldDebt != 0) revert ActivePositionCannotBeReplaced(old);
        }
        positionId = id;
        emit PositionIdConfigured(old, id);
    }

    /// @inheritdoc IMarketBalanceFuse
    /// @dev Executes through delegatecall in PlasmaVault context. Strict substrate
    ///      enforcement prevents silently dropping the debt when configuration changes.
    function balanceOf() external view override returns (uint256 netUsdWad) {
        if (address(this) != VAULT) revert WrongExecutionContext();
        bytes32[] memory substrates = PlasmaVaultConfigLib.getMarketSubstrates(MARKET_ID);
        if (substrates.length != 1 ||
            PlasmaVaultConfigLib.bytes32ToAddress(substrates[0]) != FXMINT_WBTC_POOL)
            revert MarketSubstrateMismatch();

        uint256 id = FXMintBalanceFuse(VERSION).positionId();
        if (id == 0) return 0;

        IFXMintPositionPoolV22 pool = IFXMintPositionPoolV22(FXMINT_WBTC_POOL);
        // A fully closed NFT may be burned and ownerOf() may then revert.
        // Read the position first: only a demonstrably empty position can be
        // treated as zero; unreadable state and nonzero debt fail closed.
        (uint256 rawCollateral, uint256 rawDebt) = pool.getPosition(id);
        if (rawCollateral == 0 && rawDebt == 0) return 0;
        address observed = pool.ownerOf(id);
        if (observed != VAULT) revert IncorrectOwner(id, observed);

        address middleware = PlasmaVaultLib.getPriceOracleMiddleware();
        uint256 scale = IFXMintCollateralScaleV22(FXMINT_POOL_MANAGER).getTokenScalingFactor(WBTC);
        if (scale == 0) revert InvalidScalingFactor();
        // Same conversion as the existing fxMINT accounting integration and LTV
        // manager: raw collateral -> WBTC units, using the real PoolManager scale.
        uint256 wbtcUnits = Math.mulDiv(rawCollateral, WAD, scale);
        uint256 collateralUsd = _usdValue(wbtcUnits, WBTC_DECIMALS, WBTC, middleware, false);
        uint256 debtUsd = _usdValue(rawDebt, FXUSD_DECIMALS, FXUSD, middleware, true);
        // Mirror the signed collateral-minus-debt aggregation used by official
        // Morpho/Aave balance fuses. IPOR's interface itself remains uint256.
        if (debtUsd > collateralUsd) revert InsolventFxMintPosition(collateralUsd, debtUsd);
        if (collateralUsd > uint256(type(int256).max) || debtUsd > uint256(type(int256).max))
            revert InvalidPrice(WBTC);
        int256 netValue = int256(collateralUsd) - int256(debtUsd);
        return uint256(netValue);
    }

    function _usdValue(uint256 tokenUnits, uint8 tokenDecimals, address token, address middleware, bool roundUp)
        private view returns (uint256 value)
    {
        if (tokenUnits == 0) return 0;
        (uint256 quotedPrice, uint256 priceDecimals) = IPriceOracleMiddleware(middleware).getAssetPrice(token);
        if (quotedPrice == 0 || priceDecimals > 36) revert InvalidPrice(token);
        uint256 usdPriceWad = priceDecimals <= 18
            ? quotedPrice * (10 ** (18 - priceDecimals))
            : quotedPrice / (10 ** (priceDecimals - 18));
        if (usdPriceWad == 0) revert InvalidPrice(token);
        value = Math.mulDiv(tokenUnits, usdPriceWad, 10 ** tokenDecimals,
            roundUp ? Math.Rounding.Ceil : Math.Rounding.Floor);
    }
}

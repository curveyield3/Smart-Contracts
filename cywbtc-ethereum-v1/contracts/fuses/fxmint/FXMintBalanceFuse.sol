// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IFuseCommon} from "../IFuseCommon.sol";
import {IMarketBalanceFuse} from "../IMarketBalanceFuse.sol";
import {IPriceOracleMiddleware} from "../../price_oracle/IPriceOracleMiddleware.sol";
import {PlasmaVaultLib} from "../../libraries/PlasmaVaultLib.sol";

interface IFXMintNetPositionPool {
    function ownerOf(uint256 positionId) external view returns (address);
    function getPosition(uint256 positionId) external view returns (uint256 rawCollateral, uint256 debtFxUSD);
    function collateralToken() external view returns (address);
    function fxUSD() external view returns (address);
    function poolManager() external view returns (address);
}
interface IFXMintNetPositionManager {
    function getTokenScalingFactor(address token) external view returns (uint256);
}

/// @notice Single signed-economic-position representation as an unsigned *net* USD balance.
/// @dev One NFT. One balance line. No Aave adapter, reserve facade, mirrored token balances or Morpho position.
contract FXMintBalanceFuse is IFuseCommon, IMarketBalanceFuse {
    uint256 public constant MARKET_ID = 49; // IPOR market namespace; not an Aave position
    address public immutable VERSION;
    address public immutable VAULT;
    address public immutable POOL;
    address public immutable MANAGER;
    address public immutable WBTC;
    address public immutable FXUSD;

    // Stored on the deployed balance-fuse implementation, never in PlasmaVault delegatecall storage.
    uint256 public positionId;

    error InvalidPool();
    error OnlyPlasmaVault();
    error WrongNftOwner(uint256 id);
    error ActivePosition(uint256 id);
    error EmptyPosition(uint256 id);
    error NetDebtExceedsCollateral(uint256 collateralUsd, uint256 debtUsd);

    event PositionRegistered(uint256 indexed id);

    constructor(address vault_, address pool_, address wbtc_, address fxusd_) {
        if (vault_ == address(0) || pool_ == address(0) || wbtc_ == address(0) || fxusd_ == address(0)) {
            revert InvalidPool();
        }
        IFXMintNetPositionPool p = IFXMintNetPositionPool(pool_);
        address m = p.poolManager();
        if (p.collateralToken() != wbtc_ || p.fxUSD() != fxusd_ || m == address(0)) revert InvalidPool();
        VERSION = address(this);
        VAULT = vault_;
        POOL = pool_;
        MANAGER = m;
        WBTC = wbtc_;
        FXUSD = fxusd_;
    }

    /// @notice Called by FXMintCollateralFuse in the same PlasmaVault.execute that opens the NFT.
    function registerPositionId(uint256 id) external {
        if (msg.sender != VAULT) revert OnlyPlasmaVault();
        IFXMintNetPositionPool p = IFXMintNetPositionPool(POOL);
        if (id == 0 || p.ownerOf(id) != VAULT) revert WrongNftOwner(id);
        (uint256 collateral, uint256 debt) = p.getPosition(id);
        if (collateral == 0 && debt == 0) revert EmptyPosition(id);
        uint256 existing = positionId;
        if (existing != 0 && existing != id) {
            // Never replace an NFT with a live position and silently erase its debt.
            if (p.ownerOf(existing) == VAULT) {
                (uint256 oldColl, uint256 oldDebt) = p.getPosition(existing);
                if (oldColl != 0 || oldDebt != 0) revert ActivePosition(existing);
            }
        }
        positionId = id;
        emit PositionRegistered(id);
    }

    function balanceOf() external view override returns (uint256 netUsdWad) {
        uint256 id = FXMintBalanceFuse(VERSION).positionId();
        if (id == 0) return 0;
        IFXMintNetPositionPool p = IFXMintNetPositionPool(POOL);
        if (p.ownerOf(id) != VAULT) revert WrongNftOwner(id);
        (uint256 rawCollateral, uint256 debtFxUSD) = p.getPosition(id);
        if (rawCollateral == 0 && debtFxUSD == 0) return 0;

        uint256 scale = IFXMintNetPositionManager(MANAGER).getTokenScalingFactor(WBTC);
        if (scale == 0) revert InvalidPool();
        // fxMINT scales collateral from native WBTC units to WAD; restore native units.
        uint256 wbtcAmount = Math.mulDiv(rawCollateral, 1e18, scale);
        address oracle = PlasmaVaultLib.getPriceOracleMiddleware();
        uint256 collateralUsd = _valueUsdWad(oracle, WBTC, wbtcAmount);
        uint256 debtUsd = _valueUsdWad(oracle, FXUSD, debtFxUSD);
        if (debtUsd > collateralUsd) revert NetDebtExceedsCollateral(collateralUsd, debtUsd);
        return collateralUsd - debtUsd;
    }

    function _valueUsdWad(address oracle, address token, uint256 amount) private view returns (uint256) {
        if (amount == 0) return 0;
        (uint256 price, uint256 priceDecimals) = IPriceOracleMiddleware(oracle).getAssetPrice(token);
        if (price == 0 || priceDecimals > 36) revert InvalidPool();
        uint256 tokenDecimals = IERC20Metadata(token).decimals();
        if (tokenDecimals > 36) revert InvalidPool();
        uint256 priceWad = priceDecimals <= 18
            ? price * (10 ** (18 - priceDecimals))
            : price / (10 ** (priceDecimals - 18));
        return Math.mulDiv(amount, priceWad, 10 ** tokenDecimals);
    }
}

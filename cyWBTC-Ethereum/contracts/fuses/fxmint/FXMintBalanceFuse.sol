// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IFuseCommon} from "../IFuseCommon.sol";
import {IMarketBalanceFuse} from "../IMarketBalanceFuse.sol";
import {IPriceOracleMiddleware} from "../../price_oracle/IPriceOracleMiddleware.sol";
import {PlasmaVaultLib} from "../../libraries/PlasmaVaultLib.sol";
import {IporMath} from "../../libraries/math/IporMath.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @notice Minimal view interface required of the actual fxMINT NFT long pool.
interface IFXMintWBTCPositionPool {
    function ownerOf(uint256 positionId) external view returns (address);
    function getNextPositionId() external view returns (uint32);
    function getPosition(uint256 positionId) external view returns (uint256 rawCollateral, uint256 rawDebt);
    function collateralToken() external view returns (address);
    function fxUSD() external view returns (address);
    function poolManager() external view returns (address);
}

interface IFXMintPoolManagerScaling {
    function getTokenScalingFactor(address token) external view returns (uint256);
}

/// @title FXMintBalanceFuse
/// @notice A single fxMINT WBTC collateral minus fxUSD debt position in USD WAD.
/// @dev Adapted from original v19 NFT registration adapter without the Aave reserve facade.
contract FXMintBalanceFuse is IFuseCommon, IMarketBalanceFuse {
    uint256 public constant MARKET_ID = 49; // Official IPOR AAVE_V4 market
    address public immutable VERSION; // Self address when delegatecalled as a fuse

    address public immutable VAULT;
    address public immutable ADMIN;
    address public immutable FXMINT_WBTC_POOL;
    address public immutable FXMINT_POOL_MANAGER;
    address public immutable WBTC;
    address public immutable FXUSD;

    uint256 public positionId;

    error ZeroAddress();
    error Unauthorized();
    error NetPositionInsolvent(uint256 collateralUsd,uint256 debtUsd);
    error WrongPositionOwner(uint256 positionId, address actualOwner);
    error ActivePositionCannotBeReplaced(uint256 positionId);
    error ZeroScalingFactor();
    error MustExecuteThroughPlasmaVault();
    error NoMintedPosition();
    error EmptyPosition(uint256 positionId);

    event PositionIdConfigured(uint256 indexed oldPositionId, uint256 indexed newPositionId);
    event LatestMintedPositionRegistered(address indexed plasmaVault, uint256 indexed positionId);

    /// @param vault_ Exact PlasmaVault whose fxMINT position is reported.
    /// @param admin_ Safe authorized to register a position ID during bootstrap/recovery.
    /// @param fxmintWbtcPool_ Real f(x) WBTC NFT position pool.
    /// @param wbtc_ Canonical underlying WBTC token; expected to have 8 decimals.
    /// @param fxusd_ Canonical real fxUSD debt token; expected to have 18 decimals.
    constructor(address vault_, address admin_, address fxmintWbtcPool_, address wbtc_, address fxusd_) {
        if (
            vault_ == address(0) || admin_ == address(0) || fxmintWbtcPool_ == address(0) ||
            wbtc_ == address(0) || fxusd_ == address(0)
        ) revert ZeroAddress();

        VAULT = vault_;
        ADMIN = admin_;
        VERSION = address(this);
        FXMINT_WBTC_POOL = fxmintWbtcPool_;
        WBTC = wbtc_;
        FXUSD = fxusd_;

        IFXMintWBTCPositionPool pool = IFXMintWBTCPositionPool(fxmintWbtcPool_);
        require(pool.collateralToken() == wbtc_, "WBTC_POOL_MISMATCH");
        require(pool.fxUSD() == fxusd_, "FXUSD_POOL_MISMATCH");
        address poolManager = pool.poolManager();
        if (poolManager == address(0)) revert ZeroAddress();
        FXMINT_POOL_MANAGER = poolManager;
    }

    /// @notice Register a newly minted position from *within* PlasmaVault.execute().
    /// @dev This accounting adapter itself is also authorized as a market-49 action
    ///      fuse. PlasmaVault delegatecalls this method; the adapter's VERSION points
    ///      back to its deployed instance, which records the NFT ID in its own storage.
    ///      Call this immediately AFTER FXMintCollateralFuse.enterNewPosition() in the
    ///      SAME execute() batch. No separate registration-fuse contract is needed.
    function enterRegisterLatestPosition() external {
        if (address(this) != VAULT) revert MustExecuteThroughPlasmaVault();
        // An external CALL from the PlasmaVault into the deployed adapter.
        // Direct calls to this function on the adapter revert because
        // address(this) is the adapter address, not the PlasmaVault address.
        FXMintBalanceFuse(VERSION).registerLatestPositionFromVault();
    }

    /// @notice Called only BY the actual PlasmaVault, as part of the fuse above.
    /// @dev Uses the live on-chain counter AFTER minting and independently verifies
    ///      ownership plus nonempty collateral/debt; there is no off-chain guessed ID.
    ///      Transactions execute atomically, so another independent NFT mint cannot
    ///      interleave between open and registration inside the same execute batch.
    function registerLatestPositionFromVault() external {
        if (msg.sender != VAULT) revert Unauthorized();
        IFXMintWBTCPositionPool pool = IFXMintWBTCPositionPool(FXMINT_WBTC_POOL);
        uint256 nextId = pool.getNextPositionId();
        if (nextId <= 1) revert NoMintedPosition();
        uint256 latest = nextId - 1;
        _registerPositionId(pool, latest);
        emit LatestMintedPositionRegistered(VAULT, latest);
    }

    /// @notice Optional governance/recovery path for a verified existing owned ID.
    /// @dev No value is mirrored, and a live, nonempty former position cannot be hidden.
    function setPositionId(uint256 newPositionId) external {
        if (msg.sender != ADMIN && msg.sender != VAULT) revert Unauthorized();
        _registerPositionId(IFXMintWBTCPositionPool(FXMINT_WBTC_POOL), newPositionId);
    }

    function _registerPositionId(IFXMintWBTCPositionPool pool, uint256 newPositionId) private {
        if (newPositionId == 0) revert NoMintedPosition();
        address actualOwner = pool.ownerOf(newPositionId);
        if (actualOwner != VAULT) revert WrongPositionOwner(newPositionId, actualOwner);
        (uint256 newCollateral, uint256 newDebt) = pool.getPosition(newPositionId);
        if (newCollateral == 0 && newDebt == 0) revert EmptyPosition(newPositionId);

        uint256 old = positionId;
        if (old != 0 && old != newPositionId) {
            address oldOwner;
            try pool.ownerOf(old) returns (address observedOwner) {
                oldOwner = observedOwner;
            } catch {
                oldOwner = address(0);
            }
            if (oldOwner == VAULT) {
                (uint256 collateral, uint256 debt) = pool.getPosition(old);
                if (collateral != 0 || debt != 0) revert ActivePositionCannotBeReplaced(old);
            }
        }
        positionId = newPositionId;
        emit PositionIdConfigured(old, newPositionId);
    }

    /// @notice Real net collateral/debt USD valuation for IPOR market 49.
    /// @dev IPOR delegates this view through the vault, while NFT ID registry is stored here.
    function balanceOf() external view override returns(uint256 netUsdWad) {
        if(address(this)!=VAULT) revert MustExecuteThroughPlasmaVault();
        (uint256 rawCollateral,uint256 rawDebt)=_readPosition();
        if(rawCollateral==0&&rawDebt==0) return 0;
        uint256 scale=IFXMintPoolManagerScaling(FXMINT_POOL_MANAGER).getTokenScalingFactor(WBTC);
        if(scale==0) revert ZeroScalingFactor();
        uint256 collateralNative=Math.mulDiv(rawCollateral,1e18,scale);
        address middleware=PlasmaVaultLib.getPriceOracleMiddleware();
        (uint256 wbtcPrice,uint256 wbtcDecimals)=IPriceOracleMiddleware(middleware).getAssetPrice(WBTC);
        (uint256 fxusdPrice,uint256 fxusdDecimals)=IPriceOracleMiddleware(middleware).getAssetPrice(FXUSD);
        uint256 collateralUSD=IporMath.convertToWad(collateralNative*wbtcPrice,8+wbtcDecimals);
        uint256 debtUSD=IporMath.convertToWad(rawDebt*fxusdPrice,18+fxusdDecimals);
        if(debtUSD>collateralUSD) revert NetPositionInsolvent(collateralUSD,debtUSD);
        return collateralUSD-debtUSD;
    }

    function _readPosition() private view returns (uint256 rawCollateral, uint256 rawDebt) {
        uint256 id = FXMintBalanceFuse(VERSION).positionId();
        if (id == 0) return (0, 0);
        IFXMintWBTCPositionPool pool = IFXMintWBTCPositionPool(FXMINT_WBTC_POOL);
        // A burned or no-longer-owned NFT conveys no current position to the vault.
        // Unexpected getPosition failures propagate rather than silently hide real debt.
        try pool.ownerOf(id) returns (address observedOwner) {
            if (observedOwner != VAULT) return (0, 0);
        } catch {
            return (0, 0);
        }
        return pool.getPosition(id);
    }
}

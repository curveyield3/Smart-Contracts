// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IFuseCommon} from "../IFuseCommon.sol";
import {PlasmaVaultLib} from "../../libraries/PlasmaVaultLib.sol";
import {IPriceOracleMiddleware} from "../../price_oracle/IPriceOracleMiddleware.sol";

interface IFXMintCollateralManager {
    function operate(address pool, uint256 positionId, int256 collateralDelta, int256 debtDelta, bool useStable)
        external returns (uint256 positionIdOut);
}
interface IFXMintCollateralPool {
    function ownerOf(uint256 positionId) external view returns (address);
    function collateralToken() external view returns (address);
    function poolManager() external view returns (address);
    function getPosition(uint256 positionId) external view returns (uint256 collateral, uint256 debt);
    function getNextPositionId() external view returns (uint32);
}

/// @notice Pure fxMINT position execution, not a Morpho/Aave balance or synchronization mechanism.
/// @dev Delegatecalled from an IPOR PlasmaVault. New positions must be registered in the
///      the accounting adapter's own enterRegisterLatestPosition() action in the
///      SAME execute() batch. No separate position registration fuse is used.
///      Initial borrow is max(0.02 fxUSD, strictly greater than 0.02% of deposit USD value).
contract FXMintCollateralFuse is IFuseCommon {
    using SafeERC20 for IERC20;

    uint256 public immutable MARKET_ID;
    address public immutable VERSION;
    address public immutable MANAGER;
    address public immutable POOL;
    address public immutable WBTC;

    uint256 private constant WBTC_BASE = 1e8;
    uint256 private constant MIN_INITIAL_FXUSD_WEI = 2e16; // 0.02 fxUSD
    uint256 private constant STRICT_THRESHOLD_DIVISOR = 5_000; // 0.02%

    error InvalidAddress();
    error InvalidAmount();
    error IncorrectPositionOwner(uint256 positionId);
    error UnexpectedPositionId(uint256 expected, uint256 actual);
    error InsufficientReceived(uint256 actual, uint256 minimum);
    error InvalidOraclePrice();
    error InvalidPriceDecimals();
    error IncorrectExecutionContext();

    event FXMintPositionOpened(address indexed fuse, uint256 indexed positionId, uint256 suppliedWBTC, uint256 borrowedFxUSD);
    event FXMintCollateralAdded(address indexed fuse, uint256 indexed positionId, uint256 suppliedWBTC);
    event FXMintCollateralRemoved(address indexed fuse, uint256 indexed positionId, uint256 receivedWBTC);

    constructor(address pool_, address manager_, address wbtc_) {
        if (pool_ == address(0) || manager_ == address(0) || wbtc_ == address(0)) revert InvalidAddress();
        if (IFXMintCollateralPool(pool_).poolManager() != manager_ ||
            IFXMintCollateralPool(pool_).collateralToken() != wbtc_) revert InvalidAddress();
        MARKET_ID = 49; // official IPOR AAVE_V4 market; accounting uses separate read-only adapter
        VERSION = address(this);
        MANAGER = manager_;
        POOL = pool_;
        WBTC = wbtc_;
    }

    /// @notice Opens a real fxMINT NFT. Pair with accounting adapter registration
    ///         in the same PlasmaVault.execute() transaction.
    /// @param amountWBTC WBTC native units (8 decimals), must be held by the vault.
    /// @dev Reads the expected NFT ID INSIDE the transaction, before the mint.
    function enterNewPosition(uint256 amountWBTC)
        external returns (uint256 actualPositionId, uint256 requestedBorrowFxUSD)
    {
        if (address(this) == VERSION) revert IncorrectExecutionContext();
        if (amountWBTC == 0 || amountWBTC > uint256(type(int256).max)) revert InvalidAmount();
        uint256 expectedPositionId = IFXMintCollateralPool(POOL).getNextPositionId();
        if (expectedPositionId == 0) revert InvalidAmount();
        if (IERC20(WBTC).balanceOf(address(this)) < amountWBTC) revert InvalidAmount();
        uint256 usdWad = _collateralUsdValueWad(amountWBTC);
        requestedBorrowFxUSD = usdWad / STRICT_THRESHOLD_DIVISOR + 1;
        if (requestedBorrowFxUSD < MIN_INITIAL_FXUSD_WEI) requestedBorrowFxUSD = MIN_INITIAL_FXUSD_WEI;
        if (requestedBorrowFxUSD > uint256(type(int256).max)) revert InvalidAmount();

        IERC20(WBTC).forceApprove(MANAGER, amountWBTC);
        actualPositionId = IFXMintCollateralManager(MANAGER).operate(
            POOL, 0, int256(amountWBTC), int256(requestedBorrowFxUSD), false
        );
        IERC20(WBTC).forceApprove(MANAGER, 0);
        if (actualPositionId != expectedPositionId) revert UnexpectedPositionId(expectedPositionId, actualPositionId);
        _onlyOwned(actualPositionId);
        (, uint256 reportedDebt) = IFXMintCollateralPool(POOL).getPosition(actualPositionId);
        if (reportedDebt < requestedBorrowFxUSD) revert InvalidAmount();
        emit FXMintPositionOpened(VERSION, actualPositionId, amountWBTC, requestedBorrowFxUSD);
    }

    /// @notice Add collateral to an already registered and owned real fxMINT position.
    /// @dev May revert under fxMINT's on-chain minimum debt-ratio requirements;
    ///      this fuse intentionally provides only single-purpose collateral operations.
    function enter(uint256 positionId, uint256 amountWBTC) external {
        if (address(this) == VERSION) revert IncorrectExecutionContext();
        _onlyOwned(positionId);
        if (amountWBTC == 0 || amountWBTC > uint256(type(int256).max)) revert InvalidAmount();
        if (IERC20(WBTC).balanceOf(address(this)) < amountWBTC) revert InvalidAmount();
        IERC20(WBTC).forceApprove(MANAGER, amountWBTC);
        IFXMintCollateralManager(MANAGER).operate(POOL, positionId, int256(amountWBTC), 0, false);
        IERC20(WBTC).forceApprove(MANAGER, 0);
        emit FXMintCollateralAdded(VERSION, positionId, amountWBTC);
    }

    /// @notice Real collateral withdrawal. No external accounting executor is invoked.
    function exit(uint256 positionId, uint256 amountWBTC, uint256 minReceived) external returns (uint256 received) {
        if (address(this) == VERSION) revert IncorrectExecutionContext();
        _onlyOwned(positionId);
        if (amountWBTC == 0 || amountWBTC > uint256(type(int256).max)) revert InvalidAmount();
        uint256 beforeBalance = IERC20(WBTC).balanceOf(address(this));
        IFXMintCollateralManager(MANAGER).operate(POOL, positionId, -int256(amountWBTC), 0, false);
        received = IERC20(WBTC).balanceOf(address(this)) - beforeBalance;
        if (received < minReceived) revert InsufficientReceived(received, minReceived);
        emit FXMintCollateralRemoved(VERSION, positionId, received);
    }

    function _onlyOwned(uint256 positionId) private view {
        if (positionId == 0 || IFXMintCollateralPool(POOL).ownerOf(positionId) != address(this)) {
            revert IncorrectPositionOwner(positionId);
        }
    }

    function _collateralUsdValueWad(uint256 amountWBTC) private view returns (uint256 value) {
        (uint256 price, uint256 priceDecimals) = IPriceOracleMiddleware(
            PlasmaVaultLib.getPriceOracleMiddleware()
        ).getAssetPrice(WBTC);
        if (price == 0) revert InvalidOraclePrice();
        if (priceDecimals > 36) revert InvalidPriceDecimals();
        uint256 priceWad = priceDecimals <= 18
            ? price * (10 ** (18 - priceDecimals))
            : price / (10 ** (priceDecimals - 18));
        if (priceWad == 0) revert InvalidOraclePrice();
        value = Math.mulDiv(amountWBTC, priceWad, WBTC_BASE);
    }
}

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
    function priceOracle() external view returns (address);
}
interface IFXMintRiskRegistry {
    function riskManager() external view returns (address);
}
interface IFXMintFullCloseFxUSD {
    function fxUSD() external view returns (address);
}
interface IFXMintTargetReader {
    function targetLtvWad() external view returns (uint256);
}
interface IFXMintExchangePriceReader {
    function getExchangePrice() external view returns (uint256);
}

/// @notice fxMINT position execution. Guard direct collateral exits with the
///         same live 60%-initial LTV target that FXMintLTVManager uses.
/// @dev Delegatecalled from IPOR PlasmaVault. Initial NFT registration is paired
///      in the same execute() batch. Raw exits cannot bypass manager LTV policy.
contract FXMintCollateralFuse is IFuseCommon {
    using SafeERC20 for IERC20;

    uint256 public immutable MARKET_ID;
    address public immutable VERSION;
    address public immutable MANAGER;
    address public immutable POOL;
    address public immutable WBTC;
    address public immutable POSITION_REGISTRY;

    uint256 private constant WBTC_BASE = 1e8;
    uint256 private constant MIN_INITIAL_FXUSD_WEI = 2e16;
    uint256 private constant STRICT_THRESHOLD_DIVISOR = 5_000;

    error InvalidAddress();
    error InvalidAmount();
    error IncorrectPositionOwner(uint256 positionId);
    error UnexpectedPositionId(uint256 expected, uint256 actual);
    error InsufficientReceived(uint256 actual, uint256 minimum);
    error InvalidOraclePrice();
    error InvalidPriceDecimals();
    error IncorrectExecutionContext();
    error RiskManagerNotConfigured();
    error CollateralExitExceedsLtv(uint256 actualLtv, uint256 target);
    error OnlyRegisteredRiskManager();
    error ExcessiveRepayment(uint256 actual, uint256 maximum);
    error ResidualDebt(uint256 debt);
    error ResidualCollateral(uint256 rawCollateral);

    event FXMintPositionOpened(address indexed fuse, uint256 indexed positionId, uint256 suppliedWBTC, uint256 borrowedFxUSD);
    event FXMintCollateralAdded(address indexed fuse, uint256 indexed positionId, uint256 suppliedWBTC);
    event FXMintCollateralRemoved(address indexed fuse, uint256 indexed positionId, uint256 receivedWBTC);
    event FXMintPositionClosed(address indexed fuse, uint256 indexed positionId, uint256 returnedWBTC, uint256 spentFXUSD);

    constructor(address pool_, address manager_, address wbtc_, address registry_) {
        if (pool_ == address(0) || manager_ == address(0) || wbtc_ == address(0) ||
            registry_ == address(0)) revert InvalidAddress();
        if (IFXMintCollateralPool(pool_).poolManager() != manager_ ||
            IFXMintCollateralPool(pool_).collateralToken() != wbtc_) revert InvalidAddress();
        MARKET_ID = 49;
        VERSION = address(this);
        MANAGER = manager_;
        POOL = pool_;
        WBTC = wbtc_;
        POSITION_REGISTRY = registry_;
    }

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

    function exit(uint256 positionId, uint256 amountWBTC, uint256 minReceived) external returns (uint256 received) {
        if (address(this) == VERSION) revert IncorrectExecutionContext();
        _onlyOwned(positionId);
        if (amountWBTC == 0 || amountWBTC > uint256(type(int256).max)) revert InvalidAmount();
        uint256 beforeBalance = IERC20(WBTC).balanceOf(address(this));
        IFXMintCollateralManager(MANAGER).operate(POOL, positionId, -int256(amountWBTC), 0, false);
        _enforceLiveTarget(positionId);
        received = IERC20(WBTC).balanceOf(address(this)) - beforeBalance;
        if (received < minReceived) revert InsufficientReceived(received, minReceived);
        emit FXMintCollateralRemoved(VERSION, positionId, received);
    }

    /// @notice Entire NFT close in exactly ONE fxMINT PoolManager.operate.
    /// @dev The live f(x) configuration uses a tx-long transient lock and
    ///      refuses debt=0 with nonzero collateral (ErrorDebtRatioTooSmall).
    ///      Public scheduled fulfillment MUST repay and withdraw together.
    ///      Only the Safe-registered manager implementation can invoke it.
    function exitAndRepayFull(
        uint256 positionId, uint256 maxSpentFXUSD, uint256 minReceivedWBTC
    ) external returns (uint256 received, uint256 spent) {
        if (address(this) == VERSION) revert IncorrectExecutionContext();
        if (msg.sender != IFXMintRiskRegistry(POSITION_REGISTRY).riskManager())
            revert OnlyRegisteredRiskManager();
        _onlyOwned(positionId);
        address stable = IFXMintFullCloseFxUSD(POOL).fxUSD();
        uint256 beforeWBTC = IERC20(WBTC).balanceOf(address(this));
        uint256 beforeFXUSD = IERC20(stable).balanceOf(address(this));
        // Both type(int256).min values are documented protocol sentinels:
        // withdraw MAX collateral and repay MAX debt in one operate/lock.
        IFXMintCollateralManager(MANAGER).operate(
            POOL, positionId, type(int256).min, type(int256).min, false
        );
        received = IERC20(WBTC).balanceOf(address(this)) - beforeWBTC;
        spent = beforeFXUSD - IERC20(stable).balanceOf(address(this));
        if (received < minReceivedWBTC) revert InsufficientReceived(received, minReceivedWBTC);
        if (spent > maxSpentFXUSD) revert ExcessiveRepayment(spent, maxSpentFXUSD);
        (uint256 afterCollateral, uint256 afterDebt) = IFXMintCollateralPool(POOL).getPosition(positionId);
        if (afterDebt != 0) revert ResidualDebt(afterDebt);
        if (afterCollateral != 0) revert ResidualCollateral(afterCollateral);
        emit FXMintPositionClosed(VERSION, positionId, received, spent);
    }

    function _enforceLiveTarget(uint256 positionId) private view {
        address riskManager = IFXMintRiskRegistry(POSITION_REGISTRY).riskManager();
        if (riskManager == address(0)) revert RiskManagerNotConfigured();
        (uint256 collateral, uint256 debt) = IFXMintCollateralPool(POOL).getPosition(positionId);
        if (debt == 0) return;
        uint256 price = IFXMintExchangePriceReader(
            IFXMintCollateralPool(POOL).priceOracle()).getExchangePrice();
        uint256 collateralUsd = Math.mulDiv(collateral, price, 1e18);
        uint256 actualLtv = collateralUsd == 0 ? type(uint256).max
            : Math.mulDiv(debt, 1e18, collateralUsd, Math.Rounding.Up);
        uint256 target = IFXMintTargetReader(riskManager).targetLtvWad();
        if (target == 0 || actualLtv > target) revert CollateralExitExceedsLtv(actualLtv, target);
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

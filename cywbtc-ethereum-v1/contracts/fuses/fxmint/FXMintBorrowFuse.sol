// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFuseCommon} from "../IFuseCommon.sol";

interface IFXMintBorrowManager {
    function operate(address pool, uint256 positionId, int256 collateralDelta, int256 debtDelta, bool useStable)
        external returns (uint256);
}
interface IFXMintBorrowPool {
    function ownerOf(uint256 positionId) external view returns (address);
    function fxUSD() external view returns (address);
    function poolManager() external view returns (address);
}

/// @notice A narrow fxMINT real borrow/repay fuse for the PlasmaVault's own NFT.
/// @dev No Morpho inventory calls, Aave compatibility calls, or synthetic tokens.
contract FXMintBorrowFuse is IFuseCommon {
    address public immutable VERSION;
    uint256 public immutable MARKET_ID;
    address public immutable MANAGER;
    address public immutable POOL;
    address public immutable FXUSD;

    error InvalidConfiguration();
    error InvalidAmount();
    error IncorrectPositionOwner(uint256 positionId);
    error InsufficientReceived(uint256 actual, uint256 minimum);
    error ExcessiveRepayment(uint256 actual, uint256 maximum);

    event FXMintBorrow(address indexed fuse, uint256 indexed positionId, uint256 receivedFxUSD);
    event FXMintRepay(address indexed fuse, uint256 indexed positionId, uint256 spentFxUSD);

    constructor(address pool_, address manager_, address fxusd_) {
        if (pool_ == address(0) || manager_ == address(0) || fxusd_ == address(0) ||
            IFXMintBorrowPool(pool_).poolManager() != manager_ ||
            IFXMintBorrowPool(pool_).fxUSD() != fxusd_) revert InvalidConfiguration();
        MARKET_ID = 49;
        VERSION = address(this);
        POOL = pool_;
        MANAGER = manager_;
        FXUSD = fxusd_;
    }

    function enter(uint256 positionId, uint256 amountFxUSD, uint256 minReceived)
        external returns (uint256 received)
    {
        _onlyOwned(positionId);
        if (amountFxUSD == 0 || amountFxUSD > uint256(type(int256).max)) revert InvalidAmount();
        uint256 beforeBalance = IERC20(FXUSD).balanceOf(address(this));
        IFXMintBorrowManager(MANAGER).operate(POOL, positionId, 0, int256(amountFxUSD), false);
        received = IERC20(FXUSD).balanceOf(address(this)) - beforeBalance;
        if (received < minReceived) revert InsufficientReceived(received, minReceived);
        emit FXMintBorrow(VERSION, positionId, received);
    }

    /// @notice Repay existing fxUSD debt. useMaxDebt=true passes fxMINT's documented
    ///         type(int256).min sentinel for full debt repayment, including index rounding.
    /// @dev maxSpent includes any protocol repay fee; the PoolManager burns real fxUSD.
    function exit(uint256 positionId, uint256 amountFxUSD, bool useMaxDebt, uint256 maxSpent)
        external returns (uint256 spent)
    {
        _onlyOwned(positionId);
        if (!useMaxDebt && (amountFxUSD == 0 || amountFxUSD > uint256(type(int256).max))) {
            revert InvalidAmount();
        }
        int256 debtDelta = useMaxDebt ? type(int256).min : -int256(amountFxUSD);
        uint256 beforeBalance = IERC20(FXUSD).balanceOf(address(this));
        IFXMintBorrowManager(MANAGER).operate(POOL, positionId, 0, debtDelta, false);
        spent = beforeBalance - IERC20(FXUSD).balanceOf(address(this));
        if (spent > maxSpent) revert ExcessiveRepayment(spent, maxSpent);
        emit FXMintRepay(VERSION, positionId, spent);
    }

    function _onlyOwned(uint256 positionId) private view {
        if (positionId == 0 || IFXMintBorrowPool(POOL).ownerOf(positionId) != address(this)) {
            revert IncorrectPositionOwner(positionId);
        }
    }
}

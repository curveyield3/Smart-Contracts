// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Surgical adaptation of Beefy's BaseAllToNativeFactoryStrat.sol (master).
// Original blob SHA: ffb79bd828a66c12fb2765298ce9241b9f917378
// v5: Direct reward-token -> want conversion, with performance fees only in want.
// One constructor-frozen minimum net want output applies to all non-want rewards.
// Fees are never charged on pre-existing idle underlying principal.
// Rewards are supplied automatically by the BoostHubStaking adapter.
import "@openzeppelin-4/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IBeefySwapperV2.sol";

abstract contract BaseAllToWantBoostHubV5 {
    using SafeERC20 for IERC20;

    address public immutable vault;
    address public immutable swapper;
    address public immutable want;
    address public immutable adminFeeReceiverAddress;
    uint16 public immutable totalPerformanceFeeBps;
    uint16 public immutable callShareBps;
    uint16 public immutable adminShareBps;

    uint256 public lastHarvest;
    uint256 public totalLocked;
    uint256 public immutable lockDuration;
    uint256 public immutable minWantOutput; // In smallest underlying (want) token units
    bool public constant harvestOnDeposit = false;

    uint256 internal constant FEE_DENOMINATOR = 10_000;
    event StratHarvest(address indexed harvester, uint256 wantHarvested);
    event Deposit(uint256 amount);
    event Withdraw(uint256 amount);
    event ChargedFees(address indexed token, uint256 callFees, uint256 adminFees);
    event RewardSwapDeferred(address indexed token, uint256 amount);
    event RewardOutputBelowMinimum(address indexed token, uint256 expectedWantOutput, uint256 minimumWantOutput);

    struct Addresses {
        address want;
        address vault;
        address swapper;
        address adminFeeReceiver;
    }

    struct FeeSettings {
        uint16 totalPerformanceFeeBps;
        uint16 callShareBps;
        uint16 adminShareBps;
    }

    constructor(
        Addresses memory _a,
        FeeSettings memory _fees,
        uint256 _lockDuration,
        uint256 _minWantOutput
    ) {
        require(_a.want != address(0) && _a.vault != address(0) && _a.swapper != address(0), "Missing address");
        require(_a.adminFeeReceiver != address(0), "Missing admin fee receiver");
        require(_fees.totalPerformanceFeeBps <= FEE_DENOMINATOR, "Invalid performance fee");
        require(uint256(_fees.callShareBps) + _fees.adminShareBps == FEE_DENOMINATOR, "Invalid fee shares");
        want = _a.want;
        vault = _a.vault;
        swapper = _a.swapper;
        adminFeeReceiverAddress = _a.adminFeeReceiver;
        totalPerformanceFeeBps = _fees.totalPerformanceFeeBps;
        callShareBps = _fees.callShareBps;
        adminShareBps = _fees.adminShareBps;
        lockDuration = _lockDuration;
        minWantOutput = _minWantOutput;
    }

    function stratName() public view virtual returns (string memory);
    function balanceOfPool() public view virtual returns (uint256);
    function _deposit(uint256 amount) internal virtual;
    function _withdraw(uint256 amount) internal virtual;
    function _claim() internal virtual returns (address[] memory);
    function _swappableRewards() internal view virtual returns (address[] memory);

    function deposit() public {
        // Deposit only stakes want; reward discovery happens when harvesting.
        _depositAvailableWant(balanceOfWant());
    }

    function _depositAvailableWant(uint256 wantBal) internal {
        if (wantBal > 0) {
            _deposit(wantBal);
            emit Deposit(wantBal);
        }
    }

    function withdraw(uint256 _amount) external {
        require(msg.sender == vault, "!vault");
        uint256 wantBal = balanceOfWant();
        if (wantBal < _amount) {
            _withdraw(_amount - wantBal);
            wantBal = balanceOfWant();
        }
        if (wantBal > _amount) wantBal = _amount;
        IERC20(want).safeTransfer(vault, wantBal);
        emit Withdraw(wantBal);
    }

    function claim() external {
        // Claim-only profits must observe the same 72-hour locking policy as harvest.
        uint256 beforeBal = balanceOfWant();
        _claim();
        (uint256 fee, uint256 callerFee) = _wantFees(balanceOfWant() - beforeBal);
        _payWantFees(fee, callerFee, tx.origin);
        uint256 afterBal = balanceOfWant();
        if (afterBal > beforeBal) {
            totalLocked = afterBal - beforeBal + lockedProfit();
            lastHarvest = block.timestamp;
        }
    }

    function harvest() external {
        _harvest(tx.origin);
    }

    function harvest(address callFeeRecipient) external {
        _harvest(callFeeRecipient);
    }

    function _harvest(address callFeeRecipient) internal {
        require(callFeeRecipient != address(0), "Invalid caller reward recipient");
        uint256 beforeBal = balanceOfWant();
        address[] memory tokens = _claim();
        uint256 wantBal = balanceOfWant();
        // Charge only want *newly received* during staking claims, not idle principal.
        (uint256 fee, uint256 callerFee) = _wantFees(wantBal - beforeBal);
        (uint256 swapFees, uint256 swapCallerFees) = _swapRewardsToWant(tokens, wantBal);
        _payWantFees(fee + swapFees, callerFee + swapCallerFees, callFeeRecipient);

        uint256 afterBal = balanceOfWant();
        if (afterBal > beforeBal) {
            uint256 wantHarvested = afterBal - beforeBal;
            totalLocked = wantHarvested + lockedProfit();
            lastHarvest = block.timestamp;
            _depositAvailableWant(afterBal);
            emit StratHarvest(msg.sender, wantHarvested);
        }
    }

    function _swapRewardsToWant(address[] memory swappableRewards, uint256 wantBal)
        internal returns (uint256 fees, uint256 callerFees)
    {
        for (uint256 i; i < swappableRewards.length; ++i) {
            address token = swappableRewards[i];
            // Never convert want: its balance may include users' deposited principal.
            if (token == want) continue;
            uint256 amount = IERC20(token).balanceOf(address(this));
            if (amount == 0) continue;

            // One global threshold in underlying-token base units, using the
            // OmniRouter's direct token -> want quote net of expected fees.
            if (minWantOutput != 0) {
                uint256 quotedWant = _quoteAmountOut(token, want, amount);
                uint256 quotedNetWant = quotedWant - quotedWant * totalPerformanceFeeBps / FEE_DENOMINATOR;
                if (quotedNetWant < minWantOutput) {
                    emit RewardOutputBelowMinimum(token, quotedNetWant, minWantOutput);
                    continue;
                }
            }

            _approveExact(token, swapper, amount);
            // Missing routes or reverting conversions are deferred individually.
            try IBeefySwapperV2(swapper).swap(token, want, amount) returns (uint256) {
                // Measure the real ERC-20 amount received, not the swapper's
                // potentially untrustworthy return value or the input amount.
                uint256 nextWantBal = balanceOfWant();
                uint256 receivedWant = nextWantBal - wantBal;
                wantBal = nextWantBal;
                require(receivedWant != 0, "Router returned no want");
                (uint256 fee, uint256 callerFee) = _wantFees(receivedWant);
                // As in v5, an unexpectedly low *actual* output reverts the
                // harvest atomically; a pre-swap quote is not a slippage limit.
                if (minWantOutput != 0) {
                    require(receivedWant - fee >= minWantOutput, "Want output below minimum");
                }
                // Preserve rounding per reward; transfer the sums only once.
                fees += fee;
                callerFees += callerFee;
            } catch {
                _approveExact(token, swapper, 0);
                emit RewardSwapDeferred(token, amount);
            }
        }
    }

    // Missing or reverting swapper quotes return zero and defer conversion
    // whenever the immutable minimum is nonzero.
    function _quoteAmountOut(address fromToken, address toToken, uint256 amount) internal view returns (uint256) {
        if (amount == 0) return 0;
        if (fromToken == toToken) return amount;
        try IBeefySwapperV2(swapper).getAmountOut(fromToken, toToken, amount) returns (uint256 quoted) {
            return quoted;
        } catch {
            return 0;
        }
    }

    function _wantFees(uint256 grossWant) internal view returns (uint256 fee, uint256 callerFee) {
        fee = grossWant * totalPerformanceFeeBps / FEE_DENOMINATOR;
        callerFee = fee * callShareBps / FEE_DENOMINATOR;
    }

    function _payWantFees(uint256 fee, uint256 callFeeAmount, address callFeeRecipient) internal {
        uint256 adminFeeAmount = fee - callFeeAmount;
        if (callFeeAmount > 0) IERC20(want).safeTransfer(callFeeRecipient, callFeeAmount);
        if (adminFeeAmount > 0) IERC20(want).safeTransfer(adminFeeReceiverAddress, adminFeeAmount);
        if (fee > 0) emit ChargedFees(want, callFeeAmount, adminFeeAmount);
    }

    function _approveExact(address token, address spender, uint256 amount) internal {
        // Supports exact router approvals and the fixed staking allowance at deployment.
        IERC20(token).forceApprove(spender, amount);
    }

    function rewards(uint256 index) external view returns (address) { return _swappableRewards()[index]; }
    function rewardsLength() external view returns (uint256) { return _swappableRewards().length; }

    function lockedProfit() public view returns (uint256) {
        if (lockDuration == 0) return 0;
        uint256 elapsed = block.timestamp - lastHarvest;
        uint256 remaining = elapsed < lockDuration ? lockDuration - elapsed : 0;
        return totalLocked * remaining / lockDuration;
    }

    function balanceOf() public view returns (uint256) {
        return balanceOfWant() + balanceOfPool() - lockedProfit();
    }

    function balanceOfWant() public view returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    function rewardsAvailable() external pure returns (uint256) { return 0; }
    function callReward() external pure returns (uint256) { return 0; }
    function depositFee() external pure returns (uint256) { return 0; }
    function withdrawFee() external pure returns (uint256) { return 0; }
}

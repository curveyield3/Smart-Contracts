// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title StrategyCurveSDTYearnV5
 * @notice SDT -> Curve SDT/WETH LP -> constructor-selected Yearn ERC4626 vault.
 * @dev Compatible with the UNMODIFIED BeefyVaultV7FixedV2 (BoostHub v57).
 *
 * The ORIGINAL vault is deployed with _adminFeeReceiver set to this strategy,
 * and a withdrawal fee of 50 bps. The vault routes its entire fee here via
 * its 30% administrator transfer plus 70% lockVaultProfit callback. The
 * strategy normally remits 30% of the combined fee to realAdminReceiver,
 * reducing the effective share toward 10% ONLY when conversion loss requires
 * additional coverage. No modification to the base vault is involved.
 *
 * On the last share withdrawal, the original vault pays 100% of the fee to the
 * configured fee receiver and calls no hook. The strategy records the final
 * fee and pays the normal 30% administrator share on subsequent settlement;
 * remaining proceeds are held in its excluded conversion reserve.
 * A subsequent new-cycle deposit first settles the pending final fee.
 *
 * This strategy charges a dynamic, quoted conversion/reserve fee on NEW SDT
 * deposits (not on withdrawing users), and uses that excluded reserve to pay
 * conversion shortfalls. Any fee proceeds not needed for PPS are retained as
 * insurance rather than increasing existing holder PPS. The strategy does not
 * deliberately revert on PPS-loss calculations. External contract failures,
 * vault-enforced full-gross settlement and insufficient external liquidity
 * still cannot be guaranteed away by any strategy-only design.
 */

import "@openzeppelin-4/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-4/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-4/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin-4/contracts/utils/math/Math.sol";

interface ICurveSDTWethV5 {
    function coins(uint256 i) external view returns (address);
    function calc_token_amount(uint256[2] calldata amounts, bool deposit) external view returns (uint256);
    function calc_withdraw_one_coin(uint256 tokenAmount, uint256 i) external view returns (uint256);
    function add_liquidity(uint256[2] calldata amounts, uint256 minMintAmount) external returns (uint256);
    function remove_liquidity_one_coin(uint256 tokenAmount, uint256 i, uint256 minAmount) external returns (uint256);
}

interface IYearnCurveLPV5 is IERC20 {
    function asset() external view returns (address);
    function previewRedeem(uint256 shares) external view returns (uint256);
    function maxRedeem(address owner) external view returns (uint256);
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
}

interface IBeefyVaultUnmodifiedV57 {
    function balance() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function withdrawalFeeBps() external view returns (uint256);
    function ADMIN_FEE_SHARE_BPS() external view returns (uint256);
    function adminFeeReceiver() external view returns (address);
    function underlying() external view returns (address);
    function strategy() external view returns (address);
}

contract StrategyCurveSDTYearnV5 is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public constant CURVE_POOL = 0xA19bf6fBf05624282cb6ed498f4761f22e084Edd;
    address public constant SDT = 0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint256 public constant MIN_VAULT_WITHDRAWAL_FEE_BPS = 50; // 0.50% at vault construction
    uint256 public constant DEFAULT_ADMIN_SHARE_BPS = 3_000; // ordinarily 30% of total fee
    uint256 public constant MIN_ADMIN_SHARE_BPS = 1_000;     // at least 10% of total fee
    uint256 public constant VAULT_ADMIN_SHARE_BPS = 3_000;   // original vault's internal split
    uint256 private constant BPS = 10_000;
    uint256 private constant SDT_INDEX = 1;
    uint256 private constant DEPOSIT_QUOTE_TOLERANCE_BPS = 10;
    uint256 private constant LP_SEARCH_STEPS = 32;
    uint256 public constant MIN_STRATEGY_RESERVE_BPS = 10; // 0.10%
    uint256 public constant RESERVE_QUOTE_MARGIN_BPS = 5; // 0.05%

    address public immutable vault;
    address public immutable want;
    address public immutable realAdminReceiver;
    IBeefyVaultUnmodifiedV57 public immutable parent;
    ICurveSDTWethV5 public immutable curve;
    IYearnCurveLPV5 public immutable yearn;
    IERC20 private immutable sdt;
    IERC20 private immutable lp;

    // Recorded only when the original vault has already burned the last shares;
    // its full final fee is transferred to this strategy AFTER withdraw() returns.
    uint256 public pendingFinalFee;
    // Separate from Beefy NAV; funded by a dynamic strategy entry charge.
    uint256 public reserveSDT;
    uint256 public unrecoveredCost;
    // Previous-cycle positions left behind by an otherwise funded final exit.
    // They are excluded from the next shareholder cycle's NAV until settled.
    uint256 public orphanYearnShares;
    uint256 public orphanCurveLp;
    // Ordinary strategy.withdraw() is followed atomically by lockVaultProfit().
    // For idle-only vault withdrawals, the strategy has no advance callback.
    uint256 private pendingOrdinaryFee;
    uint256 private pendingPpsTarget;
    bool private pendingOrdinary;

    event Invested(uint256 sdtIn, uint256 curveLpMinted, uint256 yearnSharesMinted);
    event Redeemed(uint256 sdtRequested, uint256 sdtReturned, uint256 curveLpBurned, uint256 yearnSharesBurned);
    event WithdrawalFeeRecycled(uint256 totalFee, uint256 realAdminFee, uint256 retainedAsStrategyAssets);
    event FinalWithdrawalFeeSettled(uint256 paidToAdmin);
    event StrategyReserveFeeCharged(uint256 deposit, uint256 fee);
    event ReserveApplied(uint256 amount);
    event UncoveredConversionCost(uint256 amount);
    event FeeReceiverMisconfigured(address feeReceiver);
    event AdminShareAdjusted(uint256 totalFee, uint256 actualAdminFee, uint256 effectiveShareBps);
    event InvestmentDeferred(uint8 reason, uint256 idleSdt, uint256 idleCurveLp);
    event ReserveFunded(address indexed sponsor, uint256 amount);
    event ReserveRetained(uint256 amount);
    event OrphanPositionsRecorded(uint256 yearnShares, uint256 lpTokens);
    event OrphanPositionsSettled(uint256 sdtAddedToReserve);

    error NotVault();
    error InvalidDependency();
    error InsufficientLiquidity();

    modifier onlyVault() {
        if (msg.sender != vault) revert NotVault();
        _;
    }

    /**
     * @param parentVault_ Precomputed CREATE2 or nonce-derived address of ORIGINAL vault.
     * @param yearnVault_ Yearn ERC4626 vault holding the exact Curve SDT/WETH LP.
     * @param realAdmin_ Actual treasury fee recipient (distinct from this strategy).
     */
    constructor(address parentVault_, address yearnVault_, address realAdmin_) {
        if (block.chainid != 1 || parentVault_ == address(0) || yearnVault_.code.length == 0 ||
            realAdmin_ == address(0) || realAdmin_ == parentVault_ || realAdmin_ == address(this)) {
            revert InvalidDependency();
        }
        if (CURVE_POOL.code.length == 0) revert InvalidDependency();
        ICurveSDTWethV5 pool = ICurveSDTWethV5(CURVE_POOL);
        if (pool.coins(0) != WETH || pool.coins(SDT_INDEX) != SDT) revert InvalidDependency();
        if (IYearnCurveLPV5(yearnVault_).asset() != CURVE_POOL) revert InvalidDependency();

        vault = parentVault_;
        want = SDT;
        realAdminReceiver = realAdmin_;
        parent = IBeefyVaultUnmodifiedV57(parentVault_);
        curve = pool;
        yearn = IYearnCurveLPV5(yearnVault_);
        sdt = IERC20(SDT);
        lp = IERC20(CURVE_POOL);
        sdt.forceApprove(CURVE_POOL, type(uint256).max);
        lp.forceApprove(yearnVault_, type(uint256).max);
    }

    /**
     * @notice Reports whether the original vault is deployed with required fee routing.
     * @dev A misconfigured fee receiver no longer automatically freezes redemptions;
     *      the administered 30% would go elsewhere, leaving less subsidy for losses.
     */
    function feeRoutingConfigured() public view returns (bool) {
        if (vault.code.length == 0) return false;
        return parent.adminFeeReceiver() == address(this) &&
            parent.withdrawalFeeBps() >= MIN_VAULT_WITHDRAWAL_FEE_BPS &&
            parent.ADMIN_FEE_SHARE_BPS() == VAULT_ADMIN_SHARE_BPS &&
            parent.underlying() == SDT && parent.strategy() == address(this);
    }

    function _managedShares() private view returns (uint256) {
        uint256 shares = yearn.balanceOf(address(this));
        return shares > orphanYearnShares ? shares - orphanYearnShares : 0;
    }

    function _managedLpBalance() private view returns (uint256) {
        uint256 shares = lp.balanceOf(address(this));
        return shares > orphanCurveLp ? shares - orphanCurveLp : 0;
    }

    function _totalLp() private view returns (uint256) {
        uint256 shares = _managedShares();
        if (shares == 0) return _managedLpBalance();
        try yearn.previewRedeem(shares) returns (uint256 assets) {
            return _managedLpBalance() + assets;
        } catch {
            // An inaccessible Yearn valuation cannot justify a fabricated NAV.
            return _managedLpBalance();
        }
    }

    function _lpToSdt(uint256 shares) private view returns (uint256) {
        if (shares == 0) return 0;
        try curve.calc_withdraw_one_coin(shares, SDT_INDEX) returns (uint256 sdtOut) {
            return sdtOut;
        } catch { return 0; }
    }

    /** @notice Any user may pre-fund liquid loss insurance; excluded from NAV. */
    function fundReserve(uint256 amount) external nonReentrant {
        if (amount == 0) return;
        uint256 beforeSdt = sdt.balanceOf(address(this));
        sdt.safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = sdt.balanceOf(address(this)) - beforeSdt;
        reserveSDT += received;
        emit ReserveFunded(msg.sender, received);
    }

    /**
     * @notice Permissionlessly convert any last-cycle orphan assets into
     *         the excluded SDT loss reserve. May leave still-illiquid assets.
     */
    function settleOrphans() external nonReentrant {
        uint256 previous = sdt.balanceOf(address(this));
        uint256 yShares = orphanYearnShares;
        if (yShares != 0) {
            uint256 beforeLp = lp.balanceOf(address(this));
            try yearn.redeem(yShares, address(this), address(this)) returns (uint256) {
                orphanYearnShares = 0;
                orphanCurveLp += lp.balanceOf(address(this)) - beforeLp;
            } catch {}
        }
        uint256 remainingLp = orphanCurveLp;
        if (remainingLp != 0) {
            try curve.remove_liquidity_one_coin(remainingLp, SDT_INDEX, 0) returns (uint256) {
                orphanCurveLp = 0;
            } catch {}
        }
        uint256 converted = sdt.balanceOf(address(this)) - previous;
        reserveSDT += converted;
        emit OrphanPositionsSettled(converted);
    }

    /** @notice SDT redeemable at live Curve exit quote, net of Curve's exit fee. */
    function redeemableSDT() public view returns (uint256) {
        return sdt.balanceOf(address(this)) + _lpToSdt(_totalLp());
    }

    /** @notice SDT value net of Curve exit conversion costs and reserved fees. */
    function balanceOf() public view returns (uint256) {
        uint256 held = sdt.balanceOf(address(this));
        uint256 excluded = reserveSDT + pendingFinalFee;
        uint256 managed = held > excluded ? held - excluded : 0;
        uint256 lpTotal = _totalLp();
        return managed + _lpToSdt(lpTotal);
    }

    /**
     * @notice Additional strategy fee reserved at deposit to protect later exits.
     * @dev Two quotes against the current state are only an estimate; this does
     *      NOT guarantee future Yearn/Curve execution or an upper bound on loss.
     */
    function strategyReserveFee(uint256 inputSDT) public view returns (uint256) {
        if (inputSDT <= 1) return 0;
        uint256 loss;
        uint256[2] memory amounts = [uint256(0), inputSDT];
        try curve.calc_token_amount(amounts, true) returns (uint256 quotedLp) {
            if (quotedLp != 0) {
                uint256 quotedSDT = _lpToSdt(quotedLp);
                if (inputSDT > quotedSDT) loss = inputSDT - quotedSDT;
            }
        } catch { /* leave funds idle when a reliable quote cannot be obtained */ }
        uint256 fee = loss + Math.mulDiv(inputSDT, RESERVE_QUOTE_MARGIN_BPS, BPS);
        uint256 floorFee = Math.mulDiv(inputSDT, MIN_STRATEGY_RESERVE_BPS, BPS);
        if (fee < floorFee) fee = floorFee;
        // Entry fees cannot consume the entire deposit, which the original
        // vault requires to yield positive net assets for share minting.
        return fee >= inputSDT ? inputSDT - 1 : fee;
    }

    /** @notice Settle final exit with normal 30% administrator share. */
    function settleFinalFee() external nonReentrant {
        if (parent.totalSupply() != 0) return;
        _settleFinalFee();
    }

    function _settleFinalFee() private {
        uint256 fee = pendingFinalFee;
        if (fee == 0) return;
        uint256 idle = sdt.balanceOf(address(this));
        uint256 available = idle > reserveSDT ? idle - reserveSDT : 0;
        if (fee > available) fee = available;
        pendingFinalFee -= fee;
        uint256 adminCut = Math.mulDiv(fee, DEFAULT_ADMIN_SHARE_BPS, BPS);
        if (adminCut != 0) sdt.safeTransfer(realAdminReceiver, adminCut);
        reserveSDT += fee - adminCut;
        emit FinalWithdrawalFeeSettled(adminCut);
    }

    function deposit() external onlyVault nonReentrant {
        // The original vault invokes us before first shares are minted.
        if (parent.totalSupply() == 0) _settleFinalFee();
        uint256 held = sdt.balanceOf(address(this));
        uint256 excluded = reserveSDT + pendingFinalFee;
        if (held <= excluded) return;
        uint256 freshSDT = held - excluded;
        uint256 levy = strategyReserveFee(freshSDT);
        if (levy != 0) {
            reserveSDT += levy;
            emit StrategyReserveFeeCharged(freshSDT, levy);
        }
        uint256 invest = freshSDT - levy;
        if (invest == 0) return;

        // An unavailable Curve pool is not a reason to reject a valid vault
        // deposit: the uninvested SDT remains accounted as idle strategy NAV.
        uint256[2] memory amounts = [uint256(0), invest];
        uint256 quote;
        try curve.calc_token_amount(amounts, true) returns (uint256 q) {
            quote = q;
        } catch {
            emit InvestmentDeferred(1, invest, _managedLpBalance());
            return;
        }
        if (quote == 0) {
            emit InvestmentDeferred(1, invest, _managedLpBalance());
            return;
        }
        uint256 minLp = Math.mulDiv(quote, BPS - DEPOSIT_QUOTE_TOLERANCE_BPS, BPS);
        uint256 lpBefore = lp.balanceOf(address(this));
        try curve.add_liquidity(amounts, minLp) returns (uint256) {
            uint256 received = lp.balanceOf(address(this)) - lpBefore;
            if (received == 0) {
                emit InvestmentDeferred(2, 0, _managedLpBalance());
                return;
            }
            uint256 beforeShares = yearn.balanceOf(address(this));
            try yearn.deposit(received, address(this)) returns (uint256) {
                uint256 newShares = yearn.balanceOf(address(this)) - beforeShares;
                emit Invested(invest, received, newShares);
            } catch {
                // Leave Curve LP idle, liquidatable without touching Yearn.
                emit InvestmentDeferred(3, 0, _managedLpBalance());
            }
        } catch {
            emit InvestmentDeferred(2, invest, _managedLpBalance());
        }
    }

    /** @dev Binary search LP for the gross SDT needed, if a live quote is available. */
    function _lpForSdt(uint256 amount, uint256 maxLp) private view returns (uint256) {
        if (maxLp == 0) return 0;
        if (_lpToSdt(maxLp) < amount) return maxLp;
        uint256 lo;
        uint256 hi = maxLp;
        for (uint256 i; i < LP_SEARCH_STEPS && hi - lo > 1; ++i) {
            uint256 mid = lo + (hi - lo) / 2;
            if (_lpToSdt(mid) >= amount) hi = mid;
            else lo = mid;
        }
        return hi;
    }

    function _unwindSdt(uint256 needed) private returns (uint256 lpBurnt, uint256 sharesBurnt) {
        if (needed == 0) return (0, 0);
        uint256 availableLp = _managedLpBalance();
        uint256 lpNeeded = _lpForSdt(needed, _totalLp());
        if (lpNeeded > availableLp) {
            uint256 missingLp = lpNeeded - availableLp;
            try yearn.withdraw(missingLp, address(this), address(this)) returns (uint256 burnt) {
                sharesBurnt += burnt;
            } catch {
                // Prefer a partial Yearn redemption to reverting the whole exit.
                uint256 claimable;
                try yearn.maxRedeem(address(this)) returns (uint256 q) {
                    claimable = q;
                } catch { claimable = 0; }
                uint256 heldShares = _managedShares();
                if (claimable > heldShares) claimable = heldShares;
                if (claimable != 0) {
                    try yearn.redeem(claimable, address(this), address(this)) returns (uint256) {
                        sharesBurnt += claimable;
                    } catch {}
                }
            }
        }
        availableLp = _managedLpBalance();
        if (availableLp == 0) return (0, sharesBurnt);
        lpBurnt = lpNeeded < availableLp ? lpNeeded : availableLp;
        // If the pool cannot settle now, keep the original LP; liquid SDT reserve
        // remains available for the request. The base vault can still revert if
        // total SDT liquidity is insufficient for its gross amount requirement.
        try curve.remove_liquidity_one_coin(lpBurnt, SDT_INDEX, 0) returns (uint256) {} catch {
            lpBurnt = 0;
        }
    }

    function withdraw(uint256 amount) external onlyVault nonReentrant { _withdraw(amount); }

    /** @notice The original vault's emergency entrypoint has the same gross-settlement obligation. */
    function emergencyWithdraw(uint256 amount) external onlyVault nonReentrant { _withdraw(amount); }

    function _withdraw(uint256 amount) private {
        if (amount == 0) return;
        uint256 navBefore = balanceOf();
        uint256 vaultIdle = sdt.balanceOf(vault);
        uint256 grossClaim = vaultIdle + amount;
        bool isFinal = parent.totalSupply() == 0;
        uint256 fee = Math.mulDiv(grossClaim, parent.withdrawalFeeBps(), BPS);
        uint256 held = sdt.balanceOf(address(this));
        uint256 exclusion = reserveSDT + pendingFinalFee;
        uint256 managedIdle = held > exclusion ? held - exclusion : 0;
        uint256 sharesBurnt;
        uint256 lpBurnt;

        if (isFinal) {
            uint256 shares = _managedShares();
            if (shares != 0) {
                try yearn.redeem(shares, address(this), address(this)) returns (uint256) {
                    sharesBurnt = shares;
                } catch {}
            }
            uint256 availableLp = _managedLpBalance();
            if (availableLp != 0) {
                try curve.remove_liquidity_one_coin(availableLp, SDT_INDEX, 0) returns (uint256) {
                    lpBurnt = availableLp;
                } catch {}
            }
        } else if (managedIdle < amount) {
            (lpBurnt, sharesBurnt) = _unwindSdt(amount - managedIdle);
        }

        uint256 available = sdt.balanceOf(address(this));
        // This is a hard constraint inherited from the original vault: the
        // strategy MUST transfer the requested gross SDT amount, even when
        // the user would ultimately receive less after the vault's fixed fee.
        if (available < amount) revert InsufficientLiquidity();
        uint256 excluded = reserveSDT + pendingFinalFee;
        uint256 managedAvailable = available > excluded ? available - excluded : 0;
        if (managedAvailable < amount) {
            uint256 consumed = amount - managedAvailable;
            if (consumed > reserveSDT) consumed = reserveSDT;
            reserveSDT -= consumed;
            emit ReserveApplied(consumed);
        }
        sdt.safeTransfer(vault, amount);
        if (isFinal) {
            reserveSDT = sdt.balanceOf(address(this));
            // No shares remain. Mark any still-illiquid positions as belonging
            // to the completed cycle, never as free assets for a new deposit.
            orphanYearnShares = yearn.balanceOf(address(this));
            orphanCurveLp = lp.balanceOf(address(this));
            emit OrphanPositionsRecorded(orphanYearnShares, orphanCurveLp);
            if (parent.adminFeeReceiver() == address(this)) pendingFinalFee += fee;
        } else {
            pendingPpsTarget = navBefore > amount ? navBefore - amount : 0;
            pendingOrdinaryFee = fee;
            pendingOrdinary = true;
        }
        emit Redeemed(amount, amount, lpBurnt, sharesBurnt);
    }

    /**
     * @notice Recycle the original vault's 30/70 fee flows without changing it.
     * @dev The effective administrator fee is 30% of the TOTAL fee by default.
     *      Reduce it toward 10% only if needed to satisfy the strategy NAV
     *      required for non-dilutive settlement. Additional shortfalls draw from
     *      the previously funded reserve. No artificial PPS revert is added.
     */
    function lockVaultProfit(uint256 retainedAmount) external onlyVault nonReentrant {
        uint256 fee;
        uint256 target;
        bool fromStrategy = pendingOrdinary;
        if (fromStrategy) {
            fee = pendingOrdinaryFee;
            target = pendingPpsTarget;
            pendingOrdinary = false;
            pendingOrdinaryFee = 0;
            pendingPpsTarget = 0;
        } else {
            // Idle-vault withdrawal: this hook is the first strategy call.
            fee = Math.mulDiv(retainedAmount, BPS, BPS - VAULT_ADMIN_SHARE_BPS);
        }

        bool routed = parent.adminFeeReceiver() == address(this);
        if (!routed) emit FeeReceiverMisconfigured(parent.adminFeeReceiver());
        uint256 admin;
        if (routed) {
            uint256 defaultCut = Math.mulDiv(fee, DEFAULT_ADMIN_SHARE_BPS, BPS);
            uint256 minimumCut = Math.mulDiv(fee, MIN_ADMIN_SHARE_BPS, BPS);
            admin = defaultCut;
            if (fromStrategy) {
                uint256 reported = balanceOf();
                uint256 affordable = reported > target ? reported - target : 0;
                if (admin > affordable) {
                    admin = affordable > minimumCut ? affordable : minimumCut;
                }
            }
            // Never redirect the vault's existing fee payment to an arbitrary
            // recipient. Only the immutable realAdminReceiver receives admin tax.
            uint256 held = sdt.balanceOf(address(this));
            if (admin > held) admin = held;
            if (admin != 0) sdt.safeTransfer(realAdminReceiver, admin);
            emit AdminShareAdjusted(fee, admin, fee == 0 ? 0 : Math.mulDiv(admin, BPS, fee));
        }

        if (fromStrategy) {
            uint256 afterFees = balanceOf();
            if (afterFees < target) {
                uint256 shortfall = target - afterFees;
                uint256 released = shortfall < reserveSDT ? shortfall : reserveSDT;
                reserveSDT -= released;
                if (released != 0) emit ReserveApplied(released);
                uint256 remaining = shortfall - released;
                if (remaining != 0) emit UncoveredConversionCost(remaining);
                unrecoveredCost += remaining;
            } else if (afterFees > target) {
                // Do not raise PPS from the withdrawal's tax proceeds: the excess
                // becomes excluded insurance for subsequent withdrawals.
                uint256 excess = afterFees - target;
                uint256 held = sdt.balanceOf(address(this));
                uint256 headroom = held > reserveSDT + pendingFinalFee ?
                    held - reserveSDT - pendingFinalFee : 0;
                if (excess > headroom) excess = headroom;
                reserveSDT += excess;
                if (excess != 0) emit ReserveRetained(excess);
            }
        } else {
            // Idle-only withdrawals incur no Curve conversion, so the fee left
            // after the administrator's ordinary cut funds future coverage.
            uint256 leftover = fee > admin ? fee - admin : 0;
            uint256 available = sdt.balanceOf(address(this));
            uint256 headroom = available > reserveSDT + pendingFinalFee ?
                available - reserveSDT - pendingFinalFee : 0;
            if (leftover > headroom) leftover = headroom;
            reserveSDT += leftover;
            if (leftover != 0) emit ReserveRetained(leftover);
        }
        emit WithdrawalFeeRecycled(fee, admin, fee > admin ? fee - admin : 0);
    }
}
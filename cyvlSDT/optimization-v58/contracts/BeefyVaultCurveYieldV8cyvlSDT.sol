// SPDX-License-Identifier: MIT

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
 * https://curveyield.dao -  may require a Brave Browser or an Unstoppable Domains browser plugin to use
 *
 */
pragma solidity ^0.8.20;

// Based on beefyfinance/beefy-contracts/contracts/BIFI/vaults/BeefyVaultV7.sol
// Original blob SHA: ac3e92ec59a18d728ae57575202c4f31d05a4786
// v63: ERC-4626 entrypoints reuse original v61 Beefy accounting and valuation.
// v2: Send 100% of the fee from the final share withdrawal to adminFeeReceiver.
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin-4/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin-4/contracts/utils/math/Math.sol";
import "./interfaces/IStrategyBoostHubV1.sol";

interface IEmergencyDualFXNMasterV54 {
    function emergencyWithdraw(uint256 amount) external;
}

/// @notice Optional cyvlSDT revenue-staking API; the other Beefy V8 strategies do not expose it.
interface IBeefyRevenueQueueStrategy {
    function immediateWithdrawFeePpm() external view returns (uint256);
    function grossBalanceOf() external view returns (uint256);
    function requestWithdrawal(uint256 amount) external returns (uint256 id, uint256 unlockTime);
    function completeWithdrawal(uint256 id) external returns (uint256 received);
    function withdrawPendingInstant(uint256 id) external returns (uint256 received);
}

contract BeefyVaultCurveYieldV8cyvlSDT is ERC20Upgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;
    error QueueDisabled();
    error VaultInvalidCloneInitialization();
    error VaultInvalidStrategy();
    error VaultInvalidFeeReceiver();
    error VaultInvalidWithdrawalFee();
    error VaultStrategyNotBoundToVault();
    error VaultInvalidUnderlying();
    error VaultDepositFeeExceeds1();
    error VaultInvalidStakingExitFee();
    error Vault100WithdrawalFee();
    error VaultEmptyNav();
    error VaultApySampleOob();
    error VaultZeroShares();
    error VaultZeroAssets();
    error VaultZeroDeposit();
    error VaultInvalidReceiver();
    error VaultNoNetAssetsAdded();
    error VaultMintExecutionShortfall();
    error VaultPendingWithdrawalExists();
    error VaultInvalidShares();
    error VaultUnlockOverflow();
    error VaultNoPendingWithdrawal();
    error VaultWithdrawalNotReady();
    error VaultQueuedWithdrawalShortfall();
    error VaultInsufficientShares();
    error VaultStrategyWithdrawalShortfall();
    error VaultInsufficientNetAssets();
    error VaultFinalExitMustRedeemAll();
    error VaultEmergencyMinAssetsOut();
    error VaultFeeReceiverOnly();
    error VaultInvalidNewReceiver();
    error VaultNoProposal();
    error VaultSevenDayDelay();

    IStrategyBoostHubV1 public strategy;
    IERC20 public underlying;
    uint256 public withdrawalFeeBps;
    bool private queueEnabled;
    bool private fixedStrategy;
    bool private supportsEmergencyWithdraw;
    error StrategyFixed();
    uint256 public depositFeeBps;
    address public adminFeeReceiver;
    address public pendingAdminFeeReceiver;
    uint256 public adminFeeReceiverChangeReadyAt;

    uint256 public constant FEE_DENOMINATOR = 10_000;
    uint256 public constant STAKING_FEE_DENOMINATOR = 1_000_000;

    /// @dev User shares are burned when the queue is requested; the corresponding
    ///      unstaked/queued assets are excluded from NAV by the revenue strategy.
    struct PendingWithdrawal {
        uint256 shares;
        uint256 grossAssets;
        uint256 strategyRequestId;
        uint64 unlockTime;
        address sourceStrategy;
        bool finalHolder;
    }
    mapping(address => PendingWithdrawal) public pendingWithdrawal;
    uint256 public constant MAX_DEPOSIT_FEE_BPS = 100;
    uint256 public constant ADMIN_FEE_SHARE_BPS = 2_000;
    uint256 public constant RECEIVER_CHANGE_DELAY = 7 days;

    // One vault-level ring; every observation contains its actual timestamp and PPS.
    // A checkpoint may be recorded at most once per 12 hours, including manual updates.
    struct APYSample { uint40 timestamp; uint216 pps; }
    APYSample[10] private apyHistory;
    uint40 public lastAPYCheckpoint;
    uint8 public apyNext;
    uint8 public apyCount;
    uint256 public constant APY_MIN_INTERVAL = 12 hours;
    uint256 public constant APY_SAMPLES = 10;
    uint256 private constant APY_HOOK_GAS = 300_000;
    uint256 private constant APY_HOOK_RESERVE = 250_000;
    uint256 private constant WAD = 1e18;
    uint256 private constant YEAR = 365 days;
    // Saturation prevents an extreme PPS movement from reverting public APY reads.
    uint256 private constant MAX_APY_WAD = 1_000_000e18;
    uint256 private constant MAX_FACTOR_WAD = WAD + MAX_APY_WAD;

    // Standard ERC-4626 events; assets denote user-supplied/user-received amounts.
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);

    event APYUpdated(uint256 indexed timestamp, uint256 pps, uint8 observations);
    event APYHistoryReset();
    event StrategyRebound(address indexed previous,address indexed next);

    event DepositFeeChanged(uint256 oldFeeBps, uint256 newFeeBps);
    event AdminFeeReceiverProposed(address indexed previousReceiver, address indexed proposedReceiver, uint256 readyAt);
    event AdminFeeReceiverChanged(address indexed previousReceiver, address indexed newReceiver);
    event WithdrawalFeeCharged(address indexed account, uint256 grossUnderlying, uint256 shareholderRetention, uint256 administratorPayment);
    event EmergencyWithdrawal(address indexed account, uint256 sharesBurned, uint256 grossUnderlying, uint256 assetsPaid);
    event StakingExitFeeRetained(address indexed owner, uint256 feePpm, uint256 amount);
    event TimelockedWithdrawalRequested(address indexed owner, uint256 shares, uint256 grossAssets, uint256 indexed strategyRequestId, uint256 unlockTime);
    event TimelockedWithdrawalCompleted(address indexed owner, uint256 shares, uint256 netAssets);
    event TimelockedWithdrawalExitedImmediately(address indexed owner, uint256 shares, uint256 netAssets);

    address private immutable initialSetupOwner;
    uint256 public immutable mintAllowanceBps;
    error VaultInvalidMintAllowance();
    constructor(address setupOwner_, uint256 mintAllowanceBps_) {
        if (mintAllowanceBps_ > 400) revert VaultInvalidMintAllowance();
        initialSetupOwner = setupOwner_;
        mintAllowanceBps = mintAllowanceBps_;
        _disableInitializers();
    }

    function initialize(
        IStrategyBoostHubV1 _strategy,
        string memory _name,
        string memory _symbol,
        uint256 _withdrawalFeeBps,
        address _adminFeeReceiver,
        address _owner,
        bool _queueEnabled,
        bool _fixedStrategy,
        bool _supportsEmergencyWithdraw
    ) external initializer {
        if (msg.sender != initialSetupOwner || _owner != initialSetupOwner) revert VaultInvalidCloneInitialization();
        __ERC20_init(_name, _symbol);
        __ReentrancyGuard_init();
        __Ownable_init();
        if (owner() != _owner) _transferOwnership(_owner);
        queueEnabled = _queueEnabled;
        fixedStrategy = _fixedStrategy;
        supportsEmergencyWithdraw = _supportsEmergencyWithdraw;
        if (!(address(_strategy) != address(0) && address(_strategy).code.length > 0)) revert VaultInvalidStrategy();
        if (!(_adminFeeReceiver != address(0))) revert VaultInvalidFeeReceiver();
        if (!(_withdrawalFeeBps <= FEE_DENOMINATOR)) revert VaultInvalidWithdrawalFee();
        if (!(_strategy.vault() == address(this))) revert VaultStrategyNotBoundToVault();
        IERC20 _want = IERC20(_strategy.want());
        if (!(address(_want) != address(0))) revert VaultInvalidUnderlying();
        strategy = _strategy;
        underlying = _want;
        withdrawalFeeBps = _withdrawalFeeBps;
        adminFeeReceiver = _adminFeeReceiver;
    }

    /// @notice Owner-selected strategy replacement; caller handles asset migration.
    function setStrategy(address next, bool _supportsEmergencyWithdraw) external onlyOwner {
        if (fixedStrategy) revert StrategyFixed();
        IStrategyBoostHubV1 candidate = IStrategyBoostHubV1(next);
        emit StrategyRebound(address(strategy), next);
        strategy = candidate;
        supportsEmergencyWithdraw = _supportsEmergencyWithdraw;
        _resetAPY();
    }

    function setDepositFeeBps(uint256 _feeBps) external onlyOwner {
        if (!(_feeBps <= MAX_DEPOSIT_FEE_BPS)) revert VaultDepositFeeExceeds1();
        emit DepositFeeChanged(depositFeeBps, _feeBps);
        depositFeeBps = _feeBps;
    }

    function want() public view returns (IERC20) {
        return underlying;
    }

    function balance() public view returns (uint256) {
        return want().balanceOf(address(this)) + strategy.balanceOf();
    }

    function available() public view returns (uint256) {
        return want().balanceOf(address(this));
    }

    function getPricePerFullShare() public view returns (uint256) {
        return totalSupply() == 0 ? 1e18 : balance() * 1e18 / totalSupply();
    }

    /// @notice ERC-4626 asset metadata used by Curve StableSwap-NG (asset type 3).
    function asset() external view returns (address) {
        return address(underlying);
    }

    function totalAssets() external view returns (uint256) {
        return balance();
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return assets;
        uint256 pool = balance();
        return pool == 0 ? 0 : Math.mulDiv(assets, supply, pool);
    }

    /// @notice Underlying assets represented by shares, using the vault's existing NAV accounting.
    /// @dev Curve calls this with 10**decimals() shares to derive its normalized pool rate.
    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? shares : shares * balance() / supply;
    }

    /// @dev Investment entry losses cannot be quoted exactly before execution.
    ///      The preview includes the configured deposit fee but assumes unchanged
    ///      market liquidity; final minting uses actual post-investment NAV.
    function previewDeposit(uint256 assets) public view returns (uint256) {
        uint256 netAssets = assets - Math.mulDiv(assets, depositFeeBps, FEE_DENOMINATOR);
        return convertToShares(netAssets);
    }

    /// @dev Quotes the deposit fee and constructor-set investment-loss allowance.
    ///      Excess NAV stays in the vault; insufficient NAV reverts at execution.
    function previewMint(uint256 shares) public view returns (uint256) {
        if (shares == 0) return 0;
        uint256 supply = totalSupply();
        uint256 netAssets = supply == 0 ? shares : Math.mulDiv(shares, balance(), supply, Math.Rounding.Up);
        uint256 bps = FEE_DENOMINATOR - depositFeeBps;
        return Math.mulDiv(netAssets, FEE_DENOMINATOR * FEE_DENOMINATOR,
            bps * (FEE_DENOMINATOR - mintAllowanceBps), Math.Rounding.Up);
    }

    /// @notice Current StakeDAO immediate-exit fee, in parts per million.
    /// @dev Only revenue strategies expose this optional selector. Other Beefy V8
    ///      strategies keep their original constructor-only withdrawal fee.
    function stakingExitFeePpm() public view returns (uint256) {
        if (!queueEnabled) return 0;
        try IBeefyRevenueQueueStrategy(address(strategy)).immediateWithdrawFeePpm() returns (uint256 ppm) {
            if (!(ppm <= STAKING_FEE_DENOMINATOR)) revert VaultInvalidStakingExitFee();
            return ppm;
        } catch { return 0; }
    }

    /// @dev This fee is retained 100% for the other shareholders. No remaining
    ///      shareholders means there is nobody to receive it, so it is waived.
    function _retainedStakingFee(uint256 gross, bool hasRemainingShares) private view returns (uint256) {
        return hasRemainingShares ? Math.mulDiv(gross, stakingExitFeePpm(), STAKING_FEE_DENOMINATOR) : 0;
    }

    /// @notice Minimum share burn to receive exactly `assets` after both instant-exit fees.
    function previewWithdraw(uint256 assets) public view returns (uint256) {
        if (!queueEnabled) { (uint256 shares,,) = _previewWithdrawWithNav(assets); return shares; }
        if (assets == 0) return 0;
        uint256 supply = totalSupply();
        if (supply == 0) return assets;
        // Full-vault exit does not collect a fee for nonexistent remaining holders.
        uint256 allNet = previewRedeem(supply);
        if (assets == allNet) return supply;
        // Fee is live but consistent within a single view; do not re-query per rounding step.
        uint256 liveFeePpm = stakingExitFeePpm();
        uint256 combinedPpm = withdrawalFeeBps * 100 + liveFeePpm;
        if (!(combinedPpm < STAKING_FEE_DENOMINATOR)) revert Vault100WithdrawalFee();
        uint256 gross = Math.mulDiv(assets, STAKING_FEE_DENOMINATOR,
            STAKING_FEE_DENOMINATOR - combinedPpm, Math.Rounding.Up);
        // Both fee components round down independently; correct the quoted gross
        // for those integer roundings without affecting the original share math.
        while (gross > 0) {
            uint256 smaller = gross - 1;
            uint256 net = smaller - Math.mulDiv(smaller, withdrawalFeeBps, FEE_DENOMINATOR)
                - Math.mulDiv(smaller, liveFeePpm, STAKING_FEE_DENOMINATOR);
            if (net < assets) break;
            gross = smaller;
        }
        uint256 pool = balance();
        if (!(pool != 0)) revert VaultEmptyNav();
        return Math.mulDiv(gross, supply, pool, Math.Rounding.Up);
    }
    function _previewWithdrawWithNav(uint256 assets)
        private view returns (uint256 shares, uint256 supply, uint256 pool)
    {
        if (assets == 0) return (0, 0, 0);
        uint256 netBps = FEE_DENOMINATOR - withdrawalFeeBps;
        if (!(netBps != 0)) revert Vault100WithdrawalFee();
        uint256 gross = Math.mulDiv(assets, FEE_DENOMINATOR, netBps, Math.Rounding.Up);
        // The fee rounds DOWN. Adjust away the at-most-one-unit overestimate.
        if (gross != 0) {
            uint256 smaller = gross - 1;
            if (smaller - Math.mulDiv(smaller, withdrawalFeeBps, FEE_DENOMINATOR) >= assets) gross = smaller;
        }
        supply = totalSupply();
        if (supply == 0) return (gross, 0, 0);
        pool = balance();
        if (!(pool != 0)) revert VaultEmptyNav();
        shares = Math.mulDiv(gross, supply, pool, Math.Rounding.Up);
    }


    /// @notice Assets delivered after the constructor fee and current instant-exit fee.
    function previewRedeem(uint256 shares) public view returns (uint256) {
        if (!queueEnabled) {
        uint256 gross = convertToAssets(shares);
        return gross - Math.mulDiv(gross, withdrawalFeeBps, FEE_DENOMINATOR);
    
        }
        uint256 gross = convertToAssets(shares);
        uint256 fixedFee = Math.mulDiv(gross, withdrawalFeeBps, FEE_DENOMINATOR);
        uint256 liveFee = _retainedStakingFee(gross, shares < totalSupply());
        return gross - fixedFee - (liveFee > gross - fixedFee ? gross - fixedFee : liveFee);
    }

    /// @dev No configured deposit cap. A failing strategy deposit can still revert.
    function maxDeposit(address receiver) external pure returns (uint256) {
        return receiver == address(0) ? 0 : type(uint256).max;
    }

    function maxMint(address receiver) external pure returns (uint256) {
        return receiver == address(0) ? 0 : type(uint256).max;
    }

    function maxRedeem(address owner) external view returns (uint256) {
        return balanceOf(owner);
    }

    function maxWithdraw(address owner) external view returns (uint256) {
        return previewRedeem(balanceOf(owner));
    }

    /// @notice Permissionless vault-only PPS snapshot. Never more than once every 12 hours.
    /// @dev All vault accounting actions also best-effort call this same updater.
    function updateAPY() external { _updateAPY(); }

    /// @notice Chronological observations, index zero is oldest retained checkpoint.
    function apySample(uint256 index) external view returns (uint256 timestamp, uint256 pps) {
        if (!(index < apyCount)) revert VaultApySampleOob();
        uint256 oldest = (uint256(apyNext) + APY_SAMPLES - uint256(apyCount)) % APY_SAMPLES;
        APYSample memory sample = apyHistory[(oldest + index) % APY_SAMPLES];
        return (sample.timestamp, sample.pps);
    }

    function _tryUpdateAPY() private {
        // The empty-vault transition invalidates earlier share-price history.
        if (totalSupply() == 0) { _resetAPY(); return; }
        uint8 count = apyCount;
        if (count != 0 && block.timestamp < uint256(lastAPYCheckpoint) + APY_MIN_INTERVAL) return;
        // Preserve one 12-hour checkpoint maximum and failure-isolated APY updates.
        // A failing strategy valuation must never block a user withdrawal/deposit.
        if (gasleft() > APY_HOOK_GAS + APY_HOOK_RESERVE) {
            try this.updateAPY{gas: APY_HOOK_GAS}() {} catch {}
        }
    }

    function _resetAPY() private {
        if (apyCount == 0) return;
        apyCount = 0;
        apyNext = 0;
        lastAPYCheckpoint = 0;
        emit APYHistoryReset();
    }

    function _updateAPY() private {
        if (totalSupply() == 0) { _resetAPY(); return; }
        if (apyCount != 0 && block.timestamp < uint256(lastAPYCheckpoint) + APY_MIN_INTERVAL) return;
        uint256 pps = getPricePerFullShare();
        if (pps == 0 || pps > type(uint216).max) return;
        apyHistory[apyNext] = APYSample(uint40(block.timestamp), uint216(pps));
        apyNext = uint8((uint256(apyNext) + 1) % APY_SAMPLES);
        if (apyCount < APY_SAMPLES) ++apyCount;
        lastAPYCheckpoint = uint40(block.timestamp);
        emit APYUpdated(block.timestamp, pps, apyCount);
    }

    function _oldestAPY() private view returns (APYSample memory) {
        uint256 oldest = (uint256(apyNext) + APY_SAMPLES - uint256(apyCount)) % APY_SAMPLES;
        return apyHistory[oldest];
    }

    /// @dev Returns the net share-price appreciation per second (WAD units),
    ///      plus a usable-state flag; negative performance is represented as zero.
    function _growthPerSecond(uint256 ppsNow) private view returns (bool ready, uint256 growthWad, uint256 elapsed) {
        if (totalSupply() == 0 || apyCount == 0 || ppsNow == 0) return (false, 0, 0);
        APYSample memory sample = _oldestAPY();
        if (sample.pps == 0 || sample.timestamp >= block.timestamp) return (false, 0, 0);
        elapsed = block.timestamp - uint256(sample.timestamp);
        growthWad = Math.mulDiv(ppsNow, WAD, uint256(sample.pps));
        return (true, growthWad, elapsed);
    }

    function _readGrowth() private view returns (bool, uint256, uint256) {
        // Preserve an always-safe read if an external strategy PPS valuation reverts.
        try this.getPricePerFullShare() returns (uint256 pps) {
            return _growthPerSecond(pps);
        } catch { return (false, 0, 0); }
    }

    /// @notice True once at least one stored PPS and a later live PPS can be compared.
    /// @dev APY remains readable when fewer than all 10 history slots are filled.
    function apyReady() external view returns (bool) {
        (bool ready,,) = _readGrowth();
        return ready;
    }

    function _boundedMulWad(uint256 a, uint256 b) private pure returns (uint256) {
        if (a >= MAX_FACTOR_WAD || b >= MAX_FACTOR_WAD) return MAX_FACTOR_WAD;
        if (a > MAX_FACTOR_WAD * WAD / b) return MAX_FACTOR_WAD;
        return a * b / WAD;
    }

    function _boundedPowWad(uint256 base, uint256 exponent) private pure returns (uint256 result) {
        result = WAD;
        while (exponent != 0) {
            if ((exponent & 1) != 0) result = _boundedMulWad(result, base);
            exponent >>= 1;
            if (exponent != 0) base = _boundedMulWad(base, base);
        }
    }

    /// @notice Vault-wide compounded annual percentage yield; 1e18 represents 100% APY.
    /// @dev Annualizes the oldest available retained PPS vs current live PPS.
    ///      Complete elapsed periods compound geometrically; the fractional
    ///      remainder is linearly interpolated (negligible at ordinary yields).
    function getAPY() public view returns (uint256) {
        (bool ready, uint256 factorWad, uint256 elapsed) = _readGrowth();
        if (!ready || factorWad <= WAD) return 0;
        uint256 fullPeriods = YEAR / elapsed;
        uint256 remainder = YEAR % elapsed;
        uint256 annualFactor = _boundedPowWad(factorWad, fullPeriods);
        if (remainder != 0) {
            uint256 extra = WAD + Math.mulDiv(factorWad - WAD, remainder, elapsed);
            annualFactor = _boundedMulWad(annualFactor, extra);
        }
        return annualFactor - WAD;
    }

    /// @notice Simple per-second realized PPS growth, retained for lending-oracle compatibility.
    /// @dev This is a per-second rate, NOT an APR-labelled public reading. Use getAPY for APY.
    function rate() external view returns (uint256) {
        (bool ready, uint256 factorWad, uint256 elapsed) = _readGrowth();
        return !ready || factorWad <= WAD ? 0 : (factorWad - WAD) / elapsed;
    }

    function depositAll() external {
        deposit(want().balanceOf(msg.sender));
    }

    /// @notice Legacy Beefy deposit; no change to its original selector.
    function deposit(uint256 assets) public nonReentrant {
        _depositAssets(assets, msg.sender, 0);
    }

    /// @notice ERC-4626 exact-asset deposit, shares minted to `receiver`.
    function deposit(uint256 assets, address receiver) external nonReentrant returns (uint256 shares) {
        return _depositAssets(assets, receiver, 0);
    }

    /// @notice ERC-4626 exact-share mint; reverts if NAV after investing is insufficient.
    function mint(uint256 shares, address receiver) external nonReentrant returns (uint256 assets) {
        if (!(shares != 0)) revert VaultZeroShares();
        assets = previewMint(shares);
        if (!(assets != 0)) revert VaultZeroAssets();
        _depositAssets(assets, receiver, shares);
    }

    /// @dev Exactly the v61 deposit economic path; the new ERC-4626 caller may
    ///      choose a shares receiver or ask to mint exactly the quoted shares.
    function _depositAssets(uint256 _amount, address receiver, uint256 exactShares) private returns (uint256 shares) {
        if (!(_amount != 0)) revert VaultZeroDeposit();
        if (!(receiver != address(0))) revert VaultInvalidReceiver();
        uint256 grossAssets = _amount;
        uint256 supply = totalSupply();
        uint256 wantBefore = underlying.balanceOf(address(this));
        uint256 _pool = wantBefore + strategy.balanceOf();
        underlying.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 idleAfterFee = underlying.balanceOf(address(this));
        _amount = idleAfterFee - wantBefore;
        uint256 fee = _amount * depositFeeBps / FEE_DENOMINATOR;
        if (fee != 0) {
            underlying.safeTransfer(adminFeeReceiver, fee);
            idleAfterFee = underlying.balanceOf(address(this));
        }
        // Reuse the already-observed post-fee balance instead of reading the
        // vault's idle token balance a third time in _earn().
        _earn(idleAfterFee);
        // Price actual post-investment NAV; it is still read after strategy deposit.
        uint256 afterPool = balance();
        if (!(afterPool > _pool)) revert VaultNoNetAssetsAdded();
        _amount = afterPool - _pool;
        uint256 affordableShares = supply == 0 ? _amount : (_amount * supply) / _pool;
        if (!(affordableShares != 0)) revert VaultZeroShares();
        shares = exactShares == 0 ? affordableShares : exactShares;
        if (!(shares <= affordableShares)) revert VaultMintExecutionShortfall();
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, grossAssets, shares);
        // Best-effort observation only after all deposit accounting; never required for minting.
        _tryUpdateAPY();
    }

    function earn() public {
        _earn(available());
        _tryUpdateAPY();
    }

    function _earn(uint256 idleAssets) private {
        if (idleAssets != 0) {
            underlying.safeTransfer(address(strategy), idleAssets);
            strategy.deposit();
        }
    }

    function withdrawAll() external {
        withdraw(balanceOf(msg.sender));
    }

    /// @notice Fee-free queue value (before the constructor fee): gross active
    ///         principal rather than the staking-fee-discounted instant NAV.
    function previewQueuedRedeem(uint256 shares) public view returns (uint256) {
        if (!queueEnabled) revert QueueDisabled();
        uint256 supply = totalSupply();
        if (shares == 0 || supply == 0) return 0;
        uint256 grossPool = available() + IBeefyRevenueQueueStrategy(address(strategy)).grossBalanceOf();
        uint256 gross = Math.mulDiv(grossPool, shares, supply);
        return gross - Math.mulDiv(gross, withdrawalFeeBps, FEE_DENOMINATOR);
    }

    /// @notice Burn shares and begin a fee-free seven-day StakeDAO withdrawal.
    /// @dev Existing queued positions do not participate in NAV, APY or new deposits.
    function requestWithdrawal(uint256 shares) external nonReentrant returns (uint256 requestId, uint256 unlockTime) {
        if (!queueEnabled) revert QueueDisabled();
        if (!(pendingWithdrawal[msg.sender].shares == 0)) revert VaultPendingWithdrawalExists();
        if (!(shares != 0 && shares <= balanceOf(msg.sender))) revert VaultInvalidShares();
        // A queued exit avoids the backend's instant withdrawal loss. Quote the
        // actual pro-rata gross staking principal (plus unreserved idle) so a
        // full queued redemption leaves no unclaimed staked principal behind.
        uint256 idle = available();
        uint256 supply = totalSupply();
        uint256 grossPool = idle + IBeefyRevenueQueueStrategy(address(strategy)).grossBalanceOf();
        uint256 grossAssets = Math.mulDiv(grossPool, shares, supply);
        if (!(grossAssets != 0)) revert VaultZeroAssets();
        bool finalHolder = shares == supply;
        _burn(msg.sender, shares);

        // The already-read vault idle balance is unchanged by _burn().
        // Isolate this share's idle assets before queueing in the strategy.
        uint256 seed = idle < grossAssets ? idle : grossAssets;
        if (seed != 0) want().safeTransfer(address(strategy), seed);
        (requestId, unlockTime) = IBeefyRevenueQueueStrategy(address(strategy)).requestWithdrawal(grossAssets);
        if (!(unlockTime <= type(uint64).max)) revert VaultUnlockOverflow();
        pendingWithdrawal[msg.sender] = PendingWithdrawal(
            shares, grossAssets, requestId, uint64(unlockTime), address(strategy), finalHolder
        );
        emit TimelockedWithdrawalRequested(msg.sender, shares, grossAssets, requestId, unlockTime);
        _tryUpdateAPY();
    }

    /// @notice Complete a matured fee-free staking exit; only the constructor
    ///         withdrawal fee applies, with its existing administrator/share split.
    function completeWithdrawal() external nonReentrant returns (uint256 assetsOut) {
        if (!queueEnabled) revert QueueDisabled();
        PendingWithdrawal memory p = pendingWithdrawal[msg.sender];
        if (!(p.shares != 0)) revert VaultNoPendingWithdrawal();
        if (!(block.timestamp >= p.unlockTime)) revert VaultWithdrawalNotReady();
        delete pendingWithdrawal[msg.sender];
        uint256 received = IBeefyRevenueQueueStrategy(p.sourceStrategy).completeWithdrawal(p.strategyRequestId);
        if (!(received == p.grossAssets)) revert VaultQueuedWithdrawalShortfall();
        assetsOut = _settleQueuedWithdrawal(msg.sender, p, received, false);
        emit TimelockedWithdrawalCompleted(msg.sender, p.shares, assetsOut);
        _tryUpdateAPY();
    }

    /// @notice Cancel a queued exit before/after maturity using StakeDAO's live
    ///         instant rate. Applies both vault exit fees to the actual returned assets.
    function withdrawQueuedImmediate() external nonReentrant returns (uint256 assetsOut) {
        if (!queueEnabled) revert QueueDisabled();
        PendingWithdrawal memory p = pendingWithdrawal[msg.sender];
        if (!(p.shares != 0)) revert VaultNoPendingWithdrawal();
        delete pendingWithdrawal[msg.sender];
        uint256 received = IBeefyRevenueQueueStrategy(p.sourceStrategy).withdrawPendingInstant(p.strategyRequestId);
        assetsOut = _settleQueuedWithdrawal(msg.sender, p, received, true);
        emit TimelockedWithdrawalExitedImmediately(msg.sender, p.shares, assetsOut);
        _tryUpdateAPY();
    }

    /// @dev Used by both ordinary and queued exits; constructor fee is split
    ///      30/70 while the extra live staking-exit fee stays with shareholders.
    function _exitFeeBreakdown(uint256 gross, bool hasOtherShares, uint256 livePpm)
        private view returns (uint256 adminPayment, uint256 retainedForShares,
            uint256 netAssets, uint256 shareholderExitFee)
    {
        uint256 fixedFee = queueEnabled ? Math.mulDiv(gross, withdrawalFeeBps, FEE_DENOMINATOR) : gross * withdrawalFeeBps / FEE_DENOMINATOR;
        adminPayment = hasOtherShares
            ? (queueEnabled ? Math.mulDiv(fixedFee, ADMIN_FEE_SHARE_BPS, FEE_DENOMINATOR) : fixedFee * ADMIN_FEE_SHARE_BPS / FEE_DENOMINATOR) : fixedFee;
        shareholderExitFee = Math.mulDiv(gross, livePpm, STAKING_FEE_DENOMINATOR);
        if (shareholderExitFee > gross - fixedFee) shareholderExitFee = gross - fixedFee;
        retainedForShares = fixedFee - adminPayment + shareholderExitFee;
        netAssets = gross - fixedFee - shareholderExitFee;
    }

    function _settleQueuedWithdrawal(
        address receiver, PendingWithdrawal memory p, uint256 received, bool early
    ) private returns (uint256 assetsOut) {
        // A final-holder request was made when no other shareholders existed.
        bool hasOtherShares = !p.finalHolder && totalSupply() != 0;
        uint256 livePpm = early && hasOtherShares
            ? IBeefyRevenueQueueStrategy(p.sourceStrategy).immediateWithdrawFeePpm() : 0;
        (uint256 adminPayment, uint256 retainedForShares, uint256 netAssets,
            uint256 shareholderExitFee) = _exitFeeBreakdown(received, hasOtherShares, livePpm);
        assetsOut = netAssets;
        if (adminPayment != 0) want().safeTransfer(adminFeeReceiver, adminPayment);
        if (assetsOut != 0) want().safeTransfer(receiver, assetsOut);
        if (retainedForShares != 0) {
            want().safeTransfer(address(strategy), retainedForShares);
            strategy.lockVaultProfit(retainedForShares);
        }
        emit WithdrawalFeeCharged(receiver, received, retainedForShares, adminPayment);
        if (shareholderExitFee != 0) emit StakingExitFeeRetained(receiver, livePpm, shareholderExitFee);
        emit Withdraw(msg.sender, receiver, receiver, assetsOut, p.shares);
    }

    /// @notice Emergency share redemption bypasses only the Convex Curve output guard.
    function emergencyWithdraw(uint256 shares, uint256 minAssetsOut) external nonReentrant {
        _withdrawShares(shares, msg.sender, msg.sender, true, minAssetsOut, 0, 0, 0);
    }

    /// @notice Legacy Beefy share withdrawal, preserving its original selector.
    function withdraw(uint256 shares) public nonReentrant {
        _withdrawShares(shares, msg.sender, msg.sender, false, 0, 0, 0, 0);
    }

    /// @notice ERC-4626 exact-net-asset withdrawal, burning the required shares.
    function withdraw(uint256 assets, address receiver, address owner)
        external nonReentrant returns (uint256 shares)
    {
        if (!(assets != 0)) revert VaultZeroAssets();
        uint256 quotedSupply; uint256 quotedPool;
        if (queueEnabled) shares = previewWithdraw(assets);
        else (shares, quotedSupply, quotedPool) = _previewWithdrawWithNav(assets);
        _withdrawShares(shares, receiver, owner, false, 0, assets, quotedSupply, quotedPool);
    }

    /// @notice ERC-4626 exact-share redemption, transferring net assets to receiver.
    function redeem(uint256 shares, address receiver, address owner)
        external nonReentrant returns (uint256 assets)
    {
        return _withdrawShares(shares, receiver, owner, false, 0, 0, 0, 0);
    }

    /// @dev The same v61 gross-assets calculation, strategy settlement, fee split,
    ///      retained-profit lock, and APY ordering for legacy and ERC-4626 callers.
    function _withdrawShares(
        uint256 _shares, address receiver, address owner, bool emergency,
        uint256 minAssetsOut, uint256 exactAssets, uint256 quotedSupply, uint256 quotedPool
    ) private returns (uint256 assetsOut) {
        if (!(_shares > 0)) revert VaultZeroShares();
        if (!(receiver != address(0))) revert VaultInvalidReceiver();
        if (!(_shares <= balanceOf(owner))) revert VaultInsufficientShares();
        if (msg.sender != owner) _spendAllowance(owner, msg.sender, _shares);
        uint256 supply = (!queueEnabled && exactAssets != 0) ? quotedSupply : totalSupply();
        uint256 pool = (!queueEnabled && exactAssets != 0) ? quotedPool : balance();
        uint256 r = (pool * _shares) / supply;
        _burn(owner, _shares);
        uint256 remainingSupply = supply - _shares;

        uint256 b = available();
        if (b < r) {
            uint256 _withdraw = r - b;
            if (emergency && supportsEmergencyWithdraw) {
                IEmergencyDualFXNMasterV54(address(strategy)).emergencyWithdraw(_withdraw);
            } else {
                strategy.withdraw(_withdraw);
            }
            uint256 _after = available();
            uint256 _diff = _after - b;
            if (!(_diff >= _withdraw)) revert VaultStrategyWithdrawalShortfall();
        }

        bool hasOtherShares = remainingSupply != 0;
        // Live exit fee applies only if another shareholder remains.
        uint256 stakingFeePpm = hasOtherShares ? stakingExitFeePpm() : 0;
        (uint256 adminPayment, uint256 retainedForShares, uint256 netAssets,
            uint256 shareholderExitFee) = _exitFeeBreakdown(r, hasOtherShares, stakingFeePpm);
        if (adminPayment != 0) underlying.safeTransfer(adminFeeReceiver, adminPayment);
        // An ERC-4626 withdraw() promises a specified number of net assets;
        // existing Beefy withdraw()/redeem() pay the original full net amount.
        assetsOut = exactAssets == 0 ? netAssets : exactAssets;
        if (exactAssets != 0) {
            if (!(netAssets >= exactAssets)) revert VaultInsufficientNetAssets();
            // Do not strand a final holder's unclaimed assets in a zero-supply vault.
            if (!(remainingSupply != 0 || exactAssets == netAssets)) revert VaultFinalExitMustRedeemAll();
        }
        if (netAssets < minAssetsOut) revert VaultEmergencyMinAssetsOut();
        want().safeTransfer(receiver, assetsOut);
        if (retainedForShares != 0) {
            want().safeTransfer(address(strategy), retainedForShares);
            strategy.lockVaultProfit(retainedForShares);
        }
        emit WithdrawalFeeCharged(owner, r, retainedForShares, adminPayment);
        if (shareholderExitFee != 0) emit StakingExitFeeRetained(owner, stakingFeePpm, shareholderExitFee);
        emit Withdraw(msg.sender, receiver, owner, assetsOut, _shares);
        if (emergency) emit EmergencyWithdrawal(owner, _shares, r, netAssets);
        _tryUpdateAPY(); // optional, after all withdrawal accounting and transfers
    }

    function proposeAdminFeeReceiver(address _newReceiver) external {
        if (!(msg.sender == adminFeeReceiver)) revert VaultFeeReceiverOnly();
        if (!(_newReceiver != address(0) && _newReceiver != adminFeeReceiver)) revert VaultInvalidNewReceiver();
        pendingAdminFeeReceiver = _newReceiver;
        adminFeeReceiverChangeReadyAt = block.timestamp + RECEIVER_CHANGE_DELAY;
        emit AdminFeeReceiverProposed(msg.sender, _newReceiver, adminFeeReceiverChangeReadyAt);
    }

    function executeAdminFeeReceiverChange() external {
        if (!(msg.sender == adminFeeReceiver)) revert VaultFeeReceiverOnly();
        if (!(pendingAdminFeeReceiver != address(0))) revert VaultNoProposal();
        if (!(block.timestamp >= adminFeeReceiverChangeReadyAt)) revert VaultSevenDayDelay();
        address previous = adminFeeReceiver;
        adminFeeReceiver = pendingAdminFeeReceiver;
        pendingAdminFeeReceiver = address(0);
        adminFeeReceiverChangeReadyAt = 0;
        emit AdminFeeReceiverChanged(previous, adminFeeReceiver);
    }
}

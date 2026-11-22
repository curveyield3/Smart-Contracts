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
 * https://curveyield.dao
 *
 * Note: curveyield.dao may require a Brave Browser or an Unstoppable Domains browser plugin to use.
 */
pragma solidity ^0.8.20;

// Specialized v1 fork of the supplied BeefyVaultV7FixedV2.
// The withdrawal tax is NOT paid to the administrator (except any final
// redemption surplus). It is the 50 bp cost allowance for SDT->LP->Yearn.
// For the exact strategy gross-up semantics, see StrategyCurveSDTYearnV1.
// CAUTION: Only compatible with a net-amount strategy, NOT an existing
// BoostHub strategy expecting gross amount payouts.
import "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin-4/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-4/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin-4/contracts/access/Ownable.sol";
import "@openzeppelin-4/contracts/utils/math/Math.sol";
interface ISDTYearnStrategyV1 {
    function vault() external view returns (address);
    function want() external view returns (address);
    function balanceOf() external view returns (uint256);
    function deposit() external;
    function withdraw(uint256 netSDT) external;
}

contract BeefyVaultSDTYearnV1 is ERC20, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    ISDTYearnStrategyV1 public immutable strategy;
    IERC20 public immutable underlying;
    uint256 public constant withdrawalFeeBps = 50; // exactly 0.50%, immutable by design
    uint256 public depositFeeBps;
    address public adminFeeReceiver;
    address public pendingAdminFeeReceiver;
    uint256 public adminFeeReceiverChangeReadyAt;

    uint256 public constant FEE_DENOMINATOR = 10_000;
    uint256 public constant MAX_DEPOSIT_FEE_BPS = 100;
    uint256 public constant RECEIVER_CHANGE_DELAY = 7 days;

    // Preserve the source vault's APY history facility unchanged.
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

    event APYUpdated(uint256 indexed timestamp, uint256 pps, uint8 observations);
    event APYHistoryReset();

    event DepositFeeChanged(uint256 oldFeeBps, uint256 newFeeBps);
    event AdminFeeReceiverProposed(address indexed previousReceiver, address indexed proposedReceiver, uint256 readyAt);
    event AdminFeeReceiverChanged(address indexed previousReceiver, address indexed newReceiver);
    event WithdrawalTaxApplied(address indexed account, uint256 grossClaim, uint256 taxAllowance, uint256 netPayout);

    constructor(
        ISDTYearnStrategyV1 _strategy,
        string memory _name,
        string memory _symbol,
        address _adminFeeReceiver
    ) ERC20(_name, _symbol) {
        require(address(_strategy) != address(0) && address(_strategy).code.length > 0, "Invalid strategy");
        require(_adminFeeReceiver != address(0), "Invalid fee receiver");
        require(_strategy.vault() == address(this), "Strategy not bound to vault");
        IERC20 _want = IERC20(_strategy.want());
        require(address(_want) != address(0), "Invalid underlying");
        strategy = _strategy;
        underlying = _want;
        adminFeeReceiver = _adminFeeReceiver;
    }

    function setDepositFeeBps(uint256 _feeBps) external onlyOwner {
        require(_feeBps <= MAX_DEPOSIT_FEE_BPS, "Deposit fee exceeds 1%");
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

    /// @notice SDT assets represented by shares, using the vault's conversion-aware gross NAV accounting.
    /// @dev Curve calls this with 10**decimals() shares to derive its normalized pool rate.
    function convertToAssets(uint256 shares) external view returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? shares : shares * balance() / supply;
    }

    /// @notice Permissionless vault PPS snapshot. Never more than once every 12 hours.
    /// @dev All vault accounting actions also best-effort call this same updater.
    function updateAPY() external { _updateAPY(); }

    /// @notice Chronological observations, index zero is oldest retained checkpoint.
    function apySample(uint256 index) external view returns (uint256 timestamp, uint256 pps) {
        require(index < apyCount, "APY_SAMPLE_OOB");
        uint256 oldest = (uint256(apyNext) + APY_SAMPLES - uint256(apyCount)) % APY_SAMPLES;
        APYSample memory sample = apyHistory[(oldest + index) % APY_SAMPLES];
        return (sample.timestamp, sample.pps);
    }

    function _tryUpdateAPY() private {
        // The empty-vault transition invalidates earlier share-price history.
        if (totalSupply() == 0) { _resetAPY(); return; }
        if (apyCount != 0 && block.timestamp < uint256(lastAPYCheckpoint) + APY_MIN_INTERVAL) return;
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

    function deposit(uint256 _amount) public nonReentrant {
        require(_amount != 0, "Zero deposit");
        uint256 wantBefore = underlying.balanceOf(address(this));
        uint256 _pool = wantBefore + strategy.balanceOf();
        uint256 oldSupply = totalSupply();
        underlying.safeTransferFrom(msg.sender, address(this), _amount);
        _amount = underlying.balanceOf(address(this)) - wantBefore;
        uint256 fee = _amount * depositFeeBps / FEE_DENOMINATOR;
        if (fee != 0) {
            underlying.safeTransfer(adminFeeReceiver, fee);
            _amount = underlying.balanceOf(address(this)) - wantBefore;
        }
        // Mint for the actual change in NAV after investment (LP slippage),
        // never for the gross input. Prevents overminting at existing holders' expense.
        _earn();
        uint256 afterPool = balance();
        require(afterPool > _pool, "No net assets added");
        _amount = afterPool - _pool;
        uint256 shares = totalSupply() == 0 ? _amount : (_amount * totalSupply()) / _pool;
        require(shares != 0, "Zero shares");
        _mint(msg.sender, shares);
        _requirePPSFloor(_pool, oldSupply);
        // Best-effort observation only after all deposit accounting; never required for minting.
        _tryUpdateAPY();
    }

    function earn() public nonReentrant {
        uint256 oldBalance = balance();
        uint256 oldSupply = totalSupply();
        _earn();
        _requirePPSFloor(oldBalance, oldSupply);
        _tryUpdateAPY();
    }

    function _earn() private {
        uint256 _bal = available();
        if (_bal != 0) {
            want().safeTransfer(address(strategy), _bal);
            strategy.deposit();
        }
    }

    function withdrawAll() external {
        withdraw(balanceOf(msg.sender));
    }

    /// @dev Exact non-dilution test using 512-bit mulDiv, not rounded PPS snapshots.
    ///      This cannot prevent exogenous Yearn/Curve losses *between* transactions.
    function _requirePPSFloor(uint256 oldAssets, uint256 oldSupply) private view {
        if (oldSupply == 0 || totalSupply() == 0) return;
        uint256 minAssets = Math.mulDiv(oldAssets, totalSupply(), oldSupply, Math.Rounding.Up);
        require(balance() >= minAssets, "PPS_DECREASE");
    }

    function withdraw(uint256 shares) public nonReentrant {
        require(shares > 0, "Zero shares");
        require(shares <= balanceOf(msg.sender), "Insufficient shares");
        uint256 oldAssets = balance();
        uint256 oldSupply = totalSupply();
        uint256 grossClaim = Math.mulDiv(oldAssets, shares, oldSupply);
        uint256 taxAllowance = Math.mulDiv(grossClaim, withdrawalFeeBps, FEE_DENOMINATOR, Math.Rounding.Up);
        uint256 netPayout = grossClaim - taxAllowance;
        bool finalWithdrawal = shares == oldSupply;
        _burn(msg.sender, shares);

        // The strategy reports *grossed-up* invested NAV. Only net SDT is
        // requested: 50 bps funds the Curve/Yearn unwinding cost, not admin revenue.
        uint256 b = underlying.balanceOf(address(this));
        if (b < netPayout || finalWithdrawal) {
            uint256 missing = b < netPayout ? netPayout - b : 0;
            // Even if enough idle SDT exists, a final exit closes all positions.
            strategy.withdraw(missing);
        }
        uint256 availableAssets = underlying.balanceOf(address(this));
        require(availableAssets >= netPayout, "WITHDRAWAL_SHORTFALL");
        underlying.safeTransfer(msg.sender, netPayout);

        if (finalWithdrawal) {
            // The final claim empties the strategy. Return any realized
            // conversion surplus to the preconfigured administrator; keep no
            // unowned dust in the vault. There is no guaranteed admin cut.
            uint256 surplus = underlying.balanceOf(address(this));
            if (surplus != 0) underlying.safeTransfer(adminFeeReceiver, surplus);
        } else {
            _requirePPSFloor(oldAssets, oldSupply);
        }
        emit WithdrawalTaxApplied(msg.sender, grossClaim, taxAllowance, netPayout);
        _tryUpdateAPY();
    }

    function proposeAdminFeeReceiver(address _newReceiver) external {
        require(msg.sender == adminFeeReceiver, "Fee receiver only");
        require(_newReceiver != address(0) && _newReceiver != adminFeeReceiver, "Invalid new receiver");
        pendingAdminFeeReceiver = _newReceiver;
        adminFeeReceiverChangeReadyAt = block.timestamp + RECEIVER_CHANGE_DELAY;
        emit AdminFeeReceiverProposed(msg.sender, _newReceiver, adminFeeReceiverChangeReadyAt);
    }

    function executeAdminFeeReceiverChange() external {
        require(msg.sender == adminFeeReceiver, "Fee receiver only");
        require(pendingAdminFeeReceiver != address(0), "No proposal");
        require(block.timestamp >= adminFeeReceiverChangeReadyAt, "Seven day delay");
        address previous = adminFeeReceiver;
        adminFeeReceiver = pendingAdminFeeReceiver;
        pendingAdminFeeReceiver = address(0);
        adminFeeReceiverChangeReadyAt = 0;
        emit AdminFeeReceiverChanged(previous, adminFeeReceiver);
    }
}
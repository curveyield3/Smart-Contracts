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
pragma solidity 0.8.28;

/// @title CurveYield Protected Morpho Vault V2 Controller v8
/// @notice Standalone, immutable per-vault controller with CurveYield fees capped on-chain.
/// @dev Operator administers strategies within an allowlist. CurveYield governance can
///      ONLY schedule fee-rate changes (90-day delay), rotate protocol recipient and
///      rotate its fee-only governance key. Governance cannot move vault assets, replace
///      the controller, change the curator, or transfer Morpho ownership.
interface IVaultV2FactoryCY {
    function createVaultV2(address owner, address asset, bytes32 salt) external returns (address);
    function isVaultV2(address vault) external view returns (bool);
}

interface IVaultV2CY {
    function owner() external view returns (address);
    function curator() external view returns (address);
    function asset() external view returns (address);
    function performanceFee() external view returns (uint96);
    function performanceFeeRecipient() external view returns (address);
    function managementFee() external view returns (uint96);
    function managementFeeRecipient() external view returns (address);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function timelock(bytes4 selector) external view returns (uint256);
    function abdicated(bytes4 selector) external view returns (bool);

    function setOwner(address newOwner) external;
    function setCurator(address newCurator) external;
    function setIsSentinel(address account, bool enabled) external;
    function setName(string calldata newName) external;
    function setSymbol(string calldata newSymbol) external;
    function submit(bytes calldata data) external;
    function revoke(bytes calldata data) external;
    function abdicate(bytes4 selector) external;
    function setPerformanceFee(uint256 newPerformanceFee) external;
    function setPerformanceFeeRecipient(address recipient) external;
    function setManagementFee(uint256 newFeePerSecondWad) external;
    function setManagementFeeRecipient(address recipient) external;
    function accrueInterest() external;
    function transfer(address recipient, uint256 shares) external returns (bool);
}

/// @notice Minimal, non-discretionary custody of ONE category of Morpho fee shares.
/// @dev We deploy the SAME contract twice, once per independent Morpho fee category.
///      It has no upgradeability, configuration, public withdrawals or fee math.
contract CurveYieldFeeShareCustody {
    IVaultV2CY public immutable vault;
    address public immutable controller;

    error Unauthorized();
    error InvalidAddress();
    error TransferFailed();

    constructor(address _vault) {
        if (_vault == address(0)) revert InvalidAddress();
        vault = IVaultV2CY(_vault);
        controller = msg.sender;
    }

    function sendShares(address recipient, uint256 amount) external {
        if (msg.sender != controller) revert Unauthorized();
        if (!vault.transfer(recipient, amount)) revert TransferFailed();
    }
}

/// @notice Owns/curates one Morpho V2 vault and splits BOTH kinds of fee shares.
/// @dev One controller handles fee math, two tiny custody instances hold separate streams.
///      No general-purpose governance call, vault migration, proxy or replacement.
contract CurveYieldProtectedVaultController {
    uint256 public constant DEFAULT_FLAT_FEE_WAD = 2e15; // 0.20% of yield.
    uint256 public constant MAX_FLAT_FEE_WAD = 2e16; // 2.00% of yield.
    uint256 public constant DEFAULT_FLAT_MANAGEMENT_FEE_WAD = 5e14; // 0.05% of TVL APR.
    uint256 public constant MAX_FLAT_MANAGEMENT_FEE_WAD = 25e14; // 0.25% of TVL APR.
    uint256 public constant DEFAULT_MANAGEMENT_SURCHARGE_BPS = 200; // 2% of operator management fee.
    uint256 public constant MAX_MANAGEMENT_SURCHARGE_BPS = 1000; // 10% of operator management fee.
    uint256 public constant MAX_MANAGEMENT_FEE_ANNUAL_WAD = 5e16; // Morpho: 5% TVL APR.
    uint256 public constant YEAR = 365 days;
    uint256 public constant DEFAULT_OPERATOR_SURCHARGE_BPS = 200; // 2% of operator performance fee.
    uint256 public constant MAX_OPERATOR_SURCHARGE_BPS = 1000; // 10% of operator performance fee.
    uint256 public constant BPS = 10_000;
    uint256 public constant FEE_CHANGE_DELAY = 90 days;
    uint256 public constant MORPHO_MAX_PERFORMANCE_FEE_WAD = 5e17;

    address public constant MORPHO_VAULT_V2_FACTORY_FRAXTAL =
        0x711bCE12269a3a496eFaABB8B9AD5A4485E08A24;
    address public governance;
    uint256 public immutable maxVaultCreationFeeWei;
    uint256 public vaultCreationFeeWei;
    address public operator;
    address public pendingOperator;
    address public protocolRecipient;
    address public operatorRecipient;
    IVaultV2CY public vault;
    CurveYieldFeeShareCustody public performanceFeeCustody;
    CurveYieldFeeShareCustody public managementFeeCustody;
    uint256 public operatorManagementFeeAnnualWad;
    uint256 public flatManagementFeeAnnualWad = DEFAULT_FLAT_MANAGEMENT_FEE_WAD;
    uint256 public managementSurchargeBps = DEFAULT_MANAGEMENT_SURCHARGE_BPS;
    uint256 public managementFeeRemainder;
    uint256 public operatorFeeWad;
    uint256 public flatProtocolFeeWad = DEFAULT_FLAT_FEE_WAD;
    uint256 public operatorSurchargeBps = DEFAULT_OPERATOR_SURCHARGE_BPS;
    uint256 public feeRemainder;
    bool public initialized;
    uint256 private entered;

    struct PendingFeeRates {
        uint256 flatFeeWad;
        uint256 surchargeBps;
        uint256 flatManagementFeeAnnualWad;
        uint256 managementSurchargeBps;
        uint256 executableAt;
    }
    PendingFeeRates public pendingFeeRates;

    event VaultCreationFeeUpdated(uint256 previousWei, uint256 nextWei);
    event VaultCreationFeePaid(address indexed payer, address indexed recipient, uint256 amountWei);
    event ProtectedVaultCreated(address indexed vault, address indexed operator,
        address indexed protocolRecipient, address asset, uint256 operatorFeeWad);
    event Distributed(uint256 performanceProtocolShares, uint256 performanceOperatorShares,
        uint256 managementProtocolShares, uint256 managementOperatorShares);
    event OperatorFeeUpdated(uint256 oldOperatorFeeWad, uint256 newOperatorFeeWad, uint256 newTotalFeeWad);
    event OperatorManagementFeeUpdated(uint256 oldAnnualWad, uint256 newAnnualWad, uint256 totalAnnualWad);
    event FeeRatesScheduled(uint256 flatFeeWad, uint256 surchargeBps,
        uint256 flatManagementAnnualWad, uint256 managementSurchargeBps, uint256 executableAt);
    event FeeRatesCancelled();
    event FeeRatesUpdated(uint256 oldFlatFeeWad, uint256 oldSurchargeBps,
        uint256 newFlatFeeWad, uint256 newSurchargeBps,
        uint256 oldFlatManagementAnnualWad, uint256 oldManagementSurchargeBps,
        uint256 newFlatManagementAnnualWad, uint256 newManagementSurchargeBps);
    event GovernanceTransferred(address indexed previousGovernance, address indexed newGovernance);
    event ProtocolFeeRecipientChanged(address indexed previousRecipient, address indexed newRecipient);
    event OperatorFeeRecipientChanged(address indexed previousRecipient, address indexed newRecipient);
    event OperatorProposed(address indexed newOperator);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event CuratorActionSubmitted(bytes data);
    event CuratorActionExecuted(bytes data);
    event CuratorActionRevoked(bytes data);

    error Unauthorized();
    error InvalidAddress();
    error InvalidFee();
    error InvalidOperation();
    error NotInitialized();
    error AlreadyInitialized();
    error UnsafeVault();
    error Reentrancy();
    error TransferFailed();
    error VaultOperationFailed(bytes returnData);
    error WrongChain();
    error DeploymentFailed();
    error InvalidCreationFeePayment();
    error CreationFeeForwardFailed();
    error FeeChangePending();
    error FeeChangeNotReady();

    modifier onlyOperator() {
        if (msg.sender != operator) revert Unauthorized();
        _;
    }

    modifier onlyGovernance() {
        if (msg.sender != governance) revert Unauthorized();
        _;
    }

    modifier ready() {
        if (!initialized) revert NotInitialized();
        _;
    }

    modifier nonReentrant() {
        if (entered != 0) revert Reentrancy();
        entered = 1;
        _;
        entered = 0;
    }

    /// @param _operator Vault operator wallet/Safe.
    /// @param _protocolTreasury CurveYield's initial fee-only governance AND fee recipient.
    /// @param _maxVaultCreationFeeWei Immutable cap in native FRAX wei; Fraxtal deployment 1 ether.
    constructor(address _operator, address _protocolTreasury, uint256 _maxVaultCreationFeeWei) {
        if (block.chainid != 252) revert WrongChain();
        if (_operator == address(0) || _protocolTreasury == address(0)) revert InvalidAddress();
        operator = _operator;
        governance = _protocolTreasury;
        protocolRecipient = _protocolTreasury;
        maxVaultCreationFeeWei = _maxVaultCreationFeeWei;
        vaultCreationFeeWei = _maxVaultCreationFeeWei;
    }

    function _totalFeeFor(uint256 opFee, uint256 flatRate, uint256 surchargeBps)
        internal pure returns (uint256)
    {
        if (flatRate > MAX_FLAT_FEE_WAD || surchargeBps > MAX_OPERATOR_SURCHARGE_BPS ||
            opFee > MORPHO_MAX_PERFORMANCE_FEE_WAD) revert InvalidFee();
        uint256 total = flatRate + opFee + (opFee * surchargeBps) / BPS;
        if (total > MORPHO_MAX_PERFORMANCE_FEE_WAD) revert InvalidFee();
        return total;
    }

    function totalFeeFor(uint256 opFee) public view returns (uint256) {
        return _totalFeeFor(opFee, flatProtocolFeeWad, operatorSurchargeBps);
    }

    function protocolFeeWad() public view returns (uint256) {
        return flatProtocolFeeWad + (operatorFeeWad * operatorSurchargeBps) / BPS;
    }

    function totalPerformanceFeeWad() external view returns (uint256) {
        return totalFeeFor(operatorFeeWad);
    }

    /// @notice Annualized WAD fee rates; Morpho accepts a per-second WAD rate.
    function _managementAnnualFor(uint256 operatorAnnualWad, uint256 flatAnnualWad, uint256 surchargeBps)
        internal pure returns (uint256)
    {
        if (flatAnnualWad > MAX_FLAT_MANAGEMENT_FEE_WAD ||
            surchargeBps > MAX_MANAGEMENT_SURCHARGE_BPS ||
            operatorAnnualWad > MAX_MANAGEMENT_FEE_ANNUAL_WAD) revert InvalidFee();
        uint256 annual = flatAnnualWad + operatorAnnualWad +
            (operatorAnnualWad * surchargeBps) / BPS;
        if (annual > MAX_MANAGEMENT_FEE_ANNUAL_WAD) revert InvalidFee();
        return annual;
    }

    function managementAnnualFor(uint256 operatorAnnualWad) public view returns (uint256) {
        return _managementAnnualFor(operatorAnnualWad, flatManagementFeeAnnualWad, managementSurchargeBps);
    }

    function managementFeePerSecondFor(uint256 operatorAnnualWad) public view returns (uint256) {
        return managementAnnualFor(operatorAnnualWad) / YEAR;
    }

    function managementProtocolFeeAnnualWad() public view returns (uint256) {
        return flatManagementFeeAnnualWad +
            (operatorManagementFeeAnnualWad * managementSurchargeBps) / BPS;
    }

    /// @notice CurveYield fee-only governance adjusts the native FRAX creation fee, capped forever.
    function setVaultCreationFeeWei(uint256 nextFeeWei) external onlyGovernance {
        if (nextFeeWei > maxVaultCreationFeeWei) revert InvalidFee();
        uint256 previous = vaultCreationFeeWei;
        vaultCreationFeeWei = nextFeeWei;
        emit VaultCreationFeeUpdated(previous, nextFeeWei);
    }

    /// @notice Create the only vault that this controller can manage.
    /// @dev Exact native FRAX fee is sent to the current CurveYield protocol recipient atomically.
    function createVault(
        address asset,
        address _operatorRecipient,
        uint256 initialOperatorFeeWad,
        string calldata name,
        string calldata symbol,
        bytes32 salt
    ) external payable onlyOperator nonReentrant returns (address vaultAddress) {
        if (initialized) revert AlreadyInitialized();
        if (msg.value != vaultCreationFeeWei) revert InvalidCreationFeePayment();
        if (asset == address(0) || _operatorRecipient == address(0)) revert InvalidAddress();
        if (bytes(name).length == 0 || bytes(symbol).length == 0) revert InvalidOperation();

        uint256 total = totalFeeFor(initialOperatorFeeWad);
        IVaultV2FactoryCY morphoFactory = IVaultV2FactoryCY(MORPHO_VAULT_V2_FACTORY_FRAXTAL);
        vaultAddress = morphoFactory.createVaultV2(address(this), asset, salt);
        if (!morphoFactory.isVaultV2(vaultAddress)) revert DeploymentFailed();
        IVaultV2CY v = IVaultV2CY(vaultAddress);
        if (v.owner() != address(this) || v.asset() != asset || v.curator() != address(0) ||
            v.totalSupply() != 0 || v.performanceFee() != 0 || v.managementFee() != 0 ||
            v.performanceFeeRecipient() != address(0) ||
            v.managementFeeRecipient() != address(0) ||
            v.timelock(IVaultV2CY.setPerformanceFee.selector) != 0 ||
            v.timelock(IVaultV2CY.setPerformanceFeeRecipient.selector) != 0 ||
            v.timelock(IVaultV2CY.setManagementFee.selector) != 0 ||
            v.timelock(IVaultV2CY.setManagementFeeRecipient.selector) != 0 ||
            v.abdicated(IVaultV2CY.setPerformanceFee.selector) ||
            v.abdicated(IVaultV2CY.setPerformanceFeeRecipient.selector) ||
            v.abdicated(IVaultV2CY.setManagementFee.selector) ||
            v.abdicated(IVaultV2CY.setManagementFeeRecipient.selector)) revert UnsafeVault();

        vault = v;
        performanceFeeCustody = new CurveYieldFeeShareCustody(vaultAddress);
        managementFeeCustody = new CurveYieldFeeShareCustody(vaultAddress);
        operatorFeeWad = initialOperatorFeeWad;
        operatorRecipient = _operatorRecipient;
        v.setName(name);
        v.setSymbol(symbol);
        v.setCurator(address(this));

        bytes memory recipientData = abi.encodeCall(
            IVaultV2CY.setPerformanceFeeRecipient, (address(performanceFeeCustody))
        );
        v.submit(recipientData);
        v.setPerformanceFeeRecipient(address(this));
        bytes memory feeData = abi.encodeCall(IVaultV2CY.setPerformanceFee, (total));
        v.submit(feeData);
        v.setPerformanceFee(total);

        bytes memory managementRecipientAction = abi.encodeCall(
            IVaultV2CY.setManagementFeeRecipient, (address(managementFeeCustody))
        );
        v.submit(managementRecipientAction);
        v.setManagementFeeRecipient(address(managementFeeCustody));

        uint256 initialManagementRate = managementAnnualFor(0) / YEAR;
        bytes memory managementFeeAction = abi.encodeCall(
            IVaultV2CY.setManagementFee, (initialManagementRate)
        );
        v.submit(managementFeeAction);
        v.setManagementFee(initialManagementRate);

        // Ownership/curatorship remain at this immutable controller.
        // Do not abdicate fee-setting: governance and operator need bounded fee adjustments.
        if (v.performanceFeeRecipient() != address(performanceFeeCustody) ||
            v.managementFeeRecipient() != address(managementFeeCustody) ||
            v.performanceFee() != total || v.managementFee() != initialManagementRate ||
            v.curator() != address(this) || v.owner() != address(this)) revert UnsafeVault();

        initialized = true;
        if (msg.value != 0) {
            (bool sent,) = payable(protocolRecipient).call{value: msg.value}("");
            if (!sent) revert CreationFeeForwardFailed();
            emit VaultCreationFeePaid(msg.sender, protocolRecipient, msg.value);
        }
        emit ProtectedVaultCreated(vaultAddress, operator, protocolRecipient, asset, initialOperatorFeeWad);
    }

    /// @notice Permissionless distribution of both independently accrued fee-share streams.
    /// @dev Morpho can mint both kinds during unrelated transactions, so they have
    ///      distinct custody addresses. Controller alone calculates and directs payouts.
    function distribute() external ready nonReentrant
        returns (uint256 protocolShares, uint256 operatorShares)
    {
        return _distribute();
    }

    function _splitShares(uint256 shares, uint256 totalRate, uint256 protocolRate, uint256 carry)
        internal pure returns (uint256 protocolShares, uint256 operatorShares, uint256 newCarry)
    {
        if (shares == 0) return (0, 0, carry);
        if (totalRate == 0) return (0, shares, 0);
        uint256 numerator = (shares % totalRate) * protocolRate + carry;
        protocolShares = (shares / totalRate) * protocolRate + numerator / totalRate;
        newCarry = numerator % totalRate;
        operatorShares = shares - protocolShares;
    }

    function _distribute() internal returns (uint256 protocolShares, uint256 operatorShares) {
        vault.accrueInterest();
        (uint256 perfProtocol, uint256 perfOperator, uint256 perfCarry) = _splitShares(
            vault.balanceOf(address(performanceFeeCustody)),
            totalFeeFor(operatorFeeWad), protocolFeeWad(), feeRemainder
        );
        feeRemainder = perfCarry;
        (uint256 mgmtProtocol, uint256 mgmtOperator, uint256 mgmtCarry) = _splitShares(
            vault.balanceOf(address(managementFeeCustody)),
            managementAnnualFor(operatorManagementFeeAnnualWad),
            managementProtocolFeeAnnualWad(), managementFeeRemainder
        );
        managementFeeRemainder = mgmtCarry;
        if (perfProtocol != 0) performanceFeeCustody.sendShares(protocolRecipient, perfProtocol);
        if (perfOperator != 0) performanceFeeCustody.sendShares(operatorRecipient, perfOperator);
        if (mgmtProtocol != 0) managementFeeCustody.sendShares(protocolRecipient, mgmtProtocol);
        if (mgmtOperator != 0) managementFeeCustody.sendShares(operatorRecipient, mgmtOperator);
        emit Distributed(perfProtocol, perfOperator, mgmtProtocol, mgmtOperator);
        protocolShares = perfProtocol + mgmtProtocol;
        operatorShares = perfOperator + mgmtOperator;
    }

    function _setVaultPerformanceFee(uint256 newTotal) internal {
        if (vault.timelock(IVaultV2CY.setPerformanceFee.selector) != 0 ||
            vault.abdicated(IVaultV2CY.setPerformanceFee.selector)) revert UnsafeVault();
        bytes memory action = abi.encodeCall(IVaultV2CY.setPerformanceFee, (newTotal));
        vault.submit(action);
        vault.setPerformanceFee(newTotal);
        if (vault.performanceFee() != newTotal) revert UnsafeVault();
    }

    function _setVaultManagementFee(uint256 annualWad) internal {
        bytes4 selector = IVaultV2CY.setManagementFee.selector;
        if (vault.timelock(selector) != 0 || vault.abdicated(selector) ||
            vault.managementFeeRecipient() != address(managementFeeCustody)) revert UnsafeVault();
        uint256 perSecond = annualWad / YEAR;
        bytes memory action = abi.encodeCall(IVaultV2CY.setManagementFee, (perSecond));
        vault.submit(action);
        vault.setManagementFee(perSecond);
        if (vault.managementFee() != perSecond) revert UnsafeVault();
    }

    function _rebaseFeeRemainder(uint256 oldTotal, uint256 newTotal) internal {
        feeRemainder = oldTotal == 0 ? 0 : (feeRemainder * newTotal) / oldTotal;
    }

    function _rebaseManagementRemainder(uint256 oldTotal, uint256 newTotal) internal {
        managementFeeRemainder = oldTotal == 0 ? 0 : (managementFeeRemainder * newTotal) / oldTotal;
    }

    /// @notice Schedule four CurveYield fee components behind one immutable 90-day delay.
    /// @dev To leave any component unchanged, supply its current stored value.
    function scheduleProtocolFeeRates(
        uint256 newFlatPerformanceWad,
        uint256 newPerformanceSurchargeBps,
        uint256 newFlatManagementAnnualWad,
        uint256 newManagementSurchargeBps
    ) external onlyGovernance ready {
        if (pendingFeeRates.executableAt != 0) revert FeeChangePending();
        _totalFeeFor(0, newFlatPerformanceWad, newPerformanceSurchargeBps);
        _managementAnnualFor(0, newFlatManagementAnnualWad, newManagementSurchargeBps);
        pendingFeeRates = PendingFeeRates({
            flatFeeWad: newFlatPerformanceWad,
            surchargeBps: newPerformanceSurchargeBps,
            flatManagementFeeAnnualWad: newFlatManagementAnnualWad,
            managementSurchargeBps: newManagementSurchargeBps,
            executableAt: block.timestamp + FEE_CHANGE_DELAY
        });
        emit FeeRatesScheduled(newFlatPerformanceWad, newPerformanceSurchargeBps,
            newFlatManagementAnnualWad, newManagementSurchargeBps, pendingFeeRates.executableAt);
    }

    /// @notice Governance can cancel proposals before or after maturity but before execution.
    function cancelProtocolFeeRates() external onlyGovernance {
        if (pendingFeeRates.executableAt == 0) revert InvalidOperation();
        delete pendingFeeRates;
        emit FeeRatesCancelled();
    }

    /// @notice Anyone may apply a matured proposal. Failed calls can be retried.
    /// @dev Fully settles fees at old rates before changing either Morpho fee setting.
    function executeProtocolFeeRates() external ready nonReentrant {
        PendingFeeRates memory next = pendingFeeRates;
        if (next.executableAt == 0 || block.timestamp < next.executableAt) revert FeeChangeNotReady();
        uint256 newPerfTotal = _totalFeeFor(operatorFeeWad, next.flatFeeWad, next.surchargeBps);
        uint256 newMgmtTotal = _managementAnnualFor(operatorManagementFeeAnnualWad,
            next.flatManagementFeeAnnualWad, next.managementSurchargeBps);
        uint256 oldPerfTotal = totalFeeFor(operatorFeeWad);
        uint256 oldMgmtTotal = managementAnnualFor(operatorManagementFeeAnnualWad);
        _distribute();
        _setVaultPerformanceFee(newPerfTotal);
        _setVaultManagementFee(newMgmtTotal);
        _rebaseFeeRemainder(oldPerfTotal, newPerfTotal);
        _rebaseManagementRemainder(oldMgmtTotal, newMgmtTotal);
        uint256 oldFlatPerf = flatProtocolFeeWad;
        uint256 oldPerfBps = operatorSurchargeBps;
        uint256 oldFlatMgmt = flatManagementFeeAnnualWad;
        uint256 oldMgmtBps = managementSurchargeBps;
        flatProtocolFeeWad = next.flatFeeWad;
        operatorSurchargeBps = next.surchargeBps;
        flatManagementFeeAnnualWad = next.flatManagementFeeAnnualWad;
        managementSurchargeBps = next.managementSurchargeBps;
        delete pendingFeeRates;
        emit FeeRatesUpdated(oldFlatPerf, oldPerfBps, next.flatFeeWad, next.surchargeBps,
            oldFlatMgmt, oldMgmtBps, next.flatManagementFeeAnnualWad, next.managementSurchargeBps);
    }

    /// @notice Operator controls its own portion of the vault performance fee.
    function setOperatorPerformanceFee(uint256 newOperatorFeeWad)
        external onlyOperator ready nonReentrant
    {
        uint256 total = totalFeeFor(newOperatorFeeWad);
        uint256 old = operatorFeeWad;
        if (old == newOperatorFeeWad) return;
        uint256 oldTotal = totalFeeFor(old);
        _distribute();
        _setVaultPerformanceFee(total);
        _rebaseFeeRemainder(oldTotal, total);
        operatorFeeWad = newOperatorFeeWad;
        emit OperatorFeeUpdated(old, newOperatorFeeWad, total);
    }

    /// @notice Treasury rotation for fee collection only: never gains vault powers.
    function setProtocolFeeRecipient(address nextRecipient)
        external onlyGovernance ready nonReentrant
    {
        if (nextRecipient == address(0)) revert InvalidAddress();
        _distribute();
        address previous = protocolRecipient;
        protocolRecipient = nextRecipient;
        emit ProtocolFeeRecipientChanged(previous, nextRecipient);
    }

    /// @notice Change the CurveYield fee-only governance key without upgrading code.
    function transferGovernance(address nextGovernance) external onlyGovernance {
        if (nextGovernance == address(0)) revert InvalidAddress();
        address previous = governance;
        governance = nextGovernance;
        emit GovernanceTransferred(previous, nextGovernance);
    }

    /// @notice Operator's annualized management fee, also charged in losses or flat returns.
    /// @dev Hard-capped together with CurveYield's annualized TVL fee at Morpho's 5% limit.
    function setOperatorManagementFee(uint256 newOperatorAnnualWad)
        external onlyOperator ready nonReentrant
    {
        uint256 newTotal = managementAnnualFor(newOperatorAnnualWad);
        uint256 oldAnnual = operatorManagementFeeAnnualWad;
        if (oldAnnual == newOperatorAnnualWad) return;
        uint256 oldTotal = managementAnnualFor(oldAnnual);
        _distribute();
        _setVaultManagementFee(newTotal);
        _rebaseManagementRemainder(oldTotal, newTotal);
        operatorManagementFeeAnnualWad = newOperatorAnnualWad;
        emit OperatorManagementFeeUpdated(oldAnnual, newOperatorAnnualWad, newTotal);
    }

    function setOperatorFeeRecipient(address nextRecipient)
        external onlyOperator ready nonReentrant
    {
        if (nextRecipient == address(0)) revert InvalidAddress();
        _distribute();
        address previous = operatorRecipient;
        operatorRecipient = nextRecipient;
        emit OperatorFeeRecipientChanged(previous, nextRecipient);
    }

    /// @notice Two-step rotation of OPERATOR access only. Morpho ownership and
    ///         curatorship remain permanently assigned to this controller.
    function proposeOperator(address nextOperator) external onlyOperator {
        if (nextOperator == address(0)) revert InvalidAddress();
        pendingOperator = nextOperator;
        emit OperatorProposed(nextOperator);
    }

    function acceptOperator() external {
        if (msg.sender != pendingOperator) revert Unauthorized();
        address old = operator;
        operator = msg.sender;
        pendingOperator = address(0);
        emit OperatorUpdated(old, msg.sender);
    }

    function setVaultName(string calldata newName) external onlyOperator ready { vault.setName(newName); }
    function setVaultSymbol(string calldata newSymbol) external onlyOperator ready { vault.setSymbol(newSymbol); }
    function setSentinel(address account, bool allowed) external onlyOperator ready {
        vault.setIsSentinel(account, allowed);
    }

    /// @notice Stage an explicitly allowlisted Morpho curator operation.
    /// @dev Morpho's own timelock remains authoritative. After it expires, any caller
    ///      can execute the action either on the vault or via executeCuratorAction().
    ///      No arbitrary gate changes, fee changes, curator replacements, multicalls,
    ///      or ownership transfers can be submitted through this controller.
    function submitCuratorAction(bytes calldata action) external onlyOperator ready {
        _validateCuratorAction(action);
        vault.submit(action);
        emit CuratorActionSubmitted(action);
    }

    function executeCuratorAction(bytes calldata action) external ready {
        _validateCuratorAction(action);
        _callVault(action);
        emit CuratorActionExecuted(action);
    }

    /// @notice Direct, risk-reducing emergency cap decreases permitted to the curator.
    function decreaseCap(bytes calldata action) external onlyOperator ready {
        if (action.length < 4) revert InvalidOperation();
        bytes4 selector = bytes4(action);
        if (selector != bytes4(keccak256("decreaseAbsoluteCap(bytes,uint256)")) &&
            selector != bytes4(keccak256("decreaseRelativeCap(bytes,uint256)"))) revert InvalidOperation();
        _callVault(action);
    }

    function revokeCuratorAction(bytes calldata action) external onlyOperator ready {
        vault.revoke(action);
        emit CuratorActionRevoked(action);
    }

    function _validateCuratorAction(bytes calldata action) internal pure {
        if (action.length < 4) revert InvalidOperation();
        bytes4 selector = bytes4(action);
        if (selector == bytes4(keccak256("setIsAllocator(address,bool)")) ||
            selector == bytes4(keccak256("setAdapterRegistry(address)")) ||
            selector == bytes4(keccak256("addAdapter(address)")) ||
            selector == bytes4(keccak256("removeAdapter(address)")) ||
            selector == bytes4(keccak256("increaseAbsoluteCap(bytes,uint256)")) ||
            selector == bytes4(keccak256("increaseRelativeCap(bytes,uint256)")) ||
            selector == bytes4(keccak256("setForceDeallocatePenalty(address,uint256)"))) return;

        if (selector == bytes4(keccak256("increaseTimelock(bytes4,uint256)")) ||
            selector == bytes4(keccak256("decreaseTimelock(bytes4,uint256)"))) {
            (bytes4 target,) = abi.decode(action[4:], (bytes4, uint256));
            // Never allow time-lock changes for protocol-fee configuration or permanent
            // abdication (and never expose share/asset gates).
            if (target == IVaultV2CY.setPerformanceFee.selector ||
                target == IVaultV2CY.setPerformanceFeeRecipient.selector ||
                target == IVaultV2CY.setManagementFee.selector ||
                target == IVaultV2CY.setManagementFeeRecipient.selector ||
                target == IVaultV2CY.abdicate.selector ||
                target == bytes4(keccak256("setReceiveSharesGate(address)")) ||
                target == bytes4(keccak256("setSendSharesGate(address)")) ||
                target == bytes4(keccak256("setReceiveAssetsGate(address)")) ||
                target == bytes4(keccak256("setSendAssetsGate(address)"))) revert InvalidOperation();
            return;
        }
        revert InvalidOperation();
    }

    function _callVault(bytes calldata data) internal {
        (bool ok, bytes memory result) = address(vault).call(data);
        if (!ok) revert VaultOperationFailed(result);
    }
}

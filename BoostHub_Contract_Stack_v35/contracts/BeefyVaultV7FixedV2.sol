// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Based on beefyfinance/beefy-contracts/contracts/BIFI/vaults/BeefyVaultV7.sol
// Original blob SHA: ac3e92ec59a18d728ae57575202c4f31d05a4786
// v2: Send 100% of the fee from the final share withdrawal to adminFeeReceiver.
import "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin-4/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-4/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin-4/contracts/access/Ownable.sol";
import "./interfaces/IStrategyBoostHubV1.sol";

contract BeefyVaultV7FixedV2 is ERC20, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    IStrategyBoostHubV1 public immutable strategy;
    IERC20 public immutable underlying;
    uint256 public immutable withdrawalFeeBps;
    uint256 public depositFeeBps;
    address public adminFeeReceiver;
    address public pendingAdminFeeReceiver;
    uint256 public adminFeeReceiverChangeReadyAt;

    uint256 public constant FEE_DENOMINATOR = 10_000;
    uint256 public constant MAX_DEPOSIT_FEE_BPS = 100;
    uint256 public constant ADMIN_FEE_SHARE_BPS = 3_000;
    uint256 public constant RECEIVER_CHANGE_DELAY = 7 days;

    event DepositFeeChanged(uint256 oldFeeBps, uint256 newFeeBps);
    event AdminFeeReceiverProposed(address indexed previousReceiver, address indexed proposedReceiver, uint256 readyAt);
    event AdminFeeReceiverChanged(address indexed previousReceiver, address indexed newReceiver);
    event WithdrawalFeeCharged(address indexed account, uint256 grossUnderlying, uint256 shareholderRetention, uint256 administratorPayment);

    constructor(
        IStrategyBoostHubV1 _strategy,
        string memory _name,
        string memory _symbol,
        uint256 _withdrawalFeeBps,
        address _adminFeeReceiver
    ) ERC20(_name, _symbol) {
        require(address(_strategy) != address(0) && address(_strategy).code.length > 0, "Invalid strategy");
        require(_adminFeeReceiver != address(0), "Invalid fee receiver");
        require(_withdrawalFeeBps <= FEE_DENOMINATOR, "Invalid withdrawal fee");
        require(_strategy.vault() == address(this), "Strategy not bound to vault");
        IERC20 _want = IERC20(_strategy.want());
        require(address(_want) != address(0), "Invalid underlying");
        strategy = _strategy;
        underlying = _want;
        withdrawalFeeBps = _withdrawalFeeBps;
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

    function depositAll() external {
        deposit(want().balanceOf(msg.sender));
    }

    function deposit(uint256 _amount) public nonReentrant {
        require(_amount != 0, "Zero deposit");
        uint256 wantBefore = underlying.balanceOf(address(this));
        uint256 _pool = wantBefore + strategy.balanceOf();
        underlying.safeTransferFrom(msg.sender, address(this), _amount);
        _amount = underlying.balanceOf(address(this)) - wantBefore;
        uint256 fee = _amount * depositFeeBps / FEE_DENOMINATOR;
        if (fee != 0) {
            underlying.safeTransfer(adminFeeReceiver, fee);
            _amount = underlying.balanceOf(address(this)) - wantBefore;
        }
        // Fixed strategy stakes exact principal; only the net receipt buys shares.
        earn();
        require(_amount != 0, "Zero received");
        uint256 shares = totalSupply() == 0 ? _amount : (_amount * totalSupply()) / _pool;
        require(shares != 0, "Zero shares");
        _mint(msg.sender, shares);
    }

    function earn() public {
        uint256 _bal = available();
        if (_bal != 0) {
            want().safeTransfer(address(strategy), _bal);
            strategy.deposit();
        }
    }

    function withdrawAll() external {
        withdraw(balanceOf(msg.sender));
    }

    function withdraw(uint256 _shares) public nonReentrant {
        require(_shares > 0, "Zero shares");
        uint256 r = (balance() * _shares) / totalSupply();
        _burn(msg.sender, _shares);

        uint256 b = want().balanceOf(address(this));
        if (b < r) {
            uint256 _withdraw = r - b;
            strategy.withdraw(_withdraw);
            uint256 _after = want().balanceOf(address(this));
            uint256 _diff = _after - b;
            if (_diff < _withdraw) r = b + _diff;
        }

        // The final shareholder's entire fee goes to adminFeeReceiver;
        // otherwise 70% stays in the vault to benefit remaining shares.
        uint256 fee = r * withdrawalFeeBps / FEE_DENOMINATOR;
        uint256 adminPayment = totalSupply() == 0
            ? fee
            : fee * ADMIN_FEE_SHARE_BPS / FEE_DENOMINATOR;
        uint256 retainedForShares = fee - adminPayment;
        if (adminPayment != 0) want().safeTransfer(adminFeeReceiver, adminPayment);
        want().safeTransfer(msg.sender, r - fee);
        emit WithdrawalFeeCharged(msg.sender, r, retainedForShares, adminPayment);
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

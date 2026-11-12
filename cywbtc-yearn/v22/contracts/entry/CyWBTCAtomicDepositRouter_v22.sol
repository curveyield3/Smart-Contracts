// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {FuseAction} from "../interfaces/IPlasmaVault.sol";

interface ICyWBTCRouterPlasmaVault is IERC4626 {
    function execute(FuseAction[] calldata actions) external;
    function updateMarketsBalances(uint256[] calldata marketIds) external returns (uint256);
}

/// @notice Single-transaction WBTC deposit -> fxMINT collateral -> conditional
///         fxUSD borrow -> Yearn investment through a factory-created IPOR vault.
/// @dev Must receive WHITELIST_ROLE and ALPHA_ROLE on the PlasmaVault. The
///      PlasmaVault should remain PRIVATE to prevent deposits/mints bypassing
///      this entry point. The vault share-token transfers must be enabled so
///      the router can forward actual IPOR shares to depositors. This is a
///      deposit entry contract, NOT a second ERC4626 share token.
/// @dev The ALPHA permission is narrowly contained: this contract constructs
///      exactly one registered manager-fuse call with no caller-supplied fuse
///      or arbitrary encoded calldata.
contract CyWBTCAtomicDepositRouter_v22 is ReentrancyGuard {
    using SafeERC20 for IERC20;

    ICyWBTCRouterPlasmaVault public immutable VAULT;
    IERC20 public immutable WBTC;
    address public immutable LTV_MANAGER;

    error InvalidConfiguration();
    error InvalidAmount();
    error InvalidReceiver();
    error IncompleteCollateralAllocation(uint256 idleWBTC);

    event AtomicDeposit(address indexed caller, address indexed receiver, uint256 assets, uint256 vaultShares);

    constructor(address plasmaVault, address wbtc, address ltvManager) {
        if (plasmaVault == address(0) || wbtc == address(0) || ltvManager == address(0)
            || plasmaVault.code.length == 0 || ltvManager.code.length == 0 ||
            IERC4626(plasmaVault).asset() != wbtc) revert InvalidConfiguration();
        VAULT = ICyWBTCRouterPlasmaVault(plasmaVault);
        WBTC = IERC20(wbtc);
        LTV_MANAGER = ltvManager;
    }

    function asset() external view returns (address) { return address(WBTC); }
    function underlyingVault() external view returns (address) { return address(VAULT); }
    function previewDeposit(uint256 assets) external view returns (uint256 shares) {
        return VAULT.previewDeposit(assets);
    }
    function previewMint(uint256 shares) external view returns (uint256 assets) {
        return VAULT.previewMint(shares);
    }

    /// @notice Default drop-in deposit selector. No user-selected fuse calls.
    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        return depositWithMinYearnShares(assets, receiver, 0);
    }

    /// @notice Atomic entry with optional Yearn ERC4626 slippage protection.
    function depositWithMinYearnShares(uint256 assets, address receiver, uint256 minYearnShares)
        public nonReentrant returns (uint256 shares)
    {
        if (assets == 0) revert InvalidAmount();
        if (receiver == address(0) || receiver == address(this)) revert InvalidReceiver();
        _refreshNetAssetValue();
        WBTC.safeTransferFrom(msg.sender, address(this), assets);
        WBTC.forceApprove(address(VAULT), assets);
        shares = VAULT.deposit(assets, address(this));
        WBTC.forceApprove(address(VAULT), 0);
        _allocate(minYearnShares);
        IERC20(address(VAULT)).safeTransfer(receiver, shares);
        emit AtomicDeposit(msg.sender, receiver, assets, shares);
    }

    /// @notice Mint exact PlasmaVault shares, then atomically allocate WBTC.
    function mint(uint256 shares, address receiver) external nonReentrant returns (uint256 assets) {
        if (shares == 0) revert InvalidAmount();
        if (receiver == address(0) || receiver == address(this)) revert InvalidReceiver();
        _refreshNetAssetValue();
        assets = VAULT.previewMint(shares);
        if (assets == 0) revert InvalidAmount();
        _refreshNetAssetValue();
        WBTC.safeTransferFrom(msg.sender, address(this), assets);
        WBTC.forceApprove(address(VAULT), assets);
        uint256 actualAssets = VAULT.mint(shares, address(this));
        WBTC.forceApprove(address(VAULT), 0);
        if (actualAssets != assets) revert InvalidAmount();
        _allocate(0);
        IERC20(address(VAULT)).safeTransfer(receiver, shares);
        emit AtomicDeposit(msg.sender, receiver, assets, shares);
    }

    /// @dev IPOR's market balances are cached between operations. Refresh before
    ///      share minting so accrued fxMINT debt cannot inflate deposit share
    ///      issuance. Router needs UPDATE_MARKETS_BALANCES_ROLE.
    function _refreshNetAssetValue() private {
        uint256[] memory markets = new uint256[](3);
        markets[0] = 49; // fxMINT direct net collateral less debt (temporary ID)
        markets[1] = 100_001; // Yearn ERC4626
        markets[2] = 7; // idle non-underlying tokens
        VAULT.updateMarketsBalances(markets);
    }

    function _allocate(uint256 minYearnShares) private {
        FuseAction[] memory actions = new FuseAction[](1);
        actions[0] = FuseAction({
            fuse: LTV_MANAGER,
            data: abi.encodeWithSignature("allocateAfterDeposit(uint256)", minYearnShares)
        });
        VAULT.execute(actions);
        uint256 idle = WBTC.balanceOf(address(VAULT));
        if (idle != 0) revert IncompleteCollateralAllocation(idle);
    }
}

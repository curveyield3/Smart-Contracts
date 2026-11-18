// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title CurveYieldLendingMarketAdapterV1 / Factory V1
 * @notice One immutable Vault V2 adapter per vault + market, supporting verified
 *         Fraxtal CurveLend v1 ERC-4626 vaults and Fraxlend ERC-4626 pairs.
 * @dev Production onboarding remains gated by the Vault V2 curator, registry,
 *      caps, timelocks, and allocator roles. No public capital-moving methods.
 */
interface ICurveYieldParentVaultV2 {
    function asset() external view returns (address);
    function allocation(bytes32 id) external view returns (uint256);
}
interface ICurveYieldVerifiedVaultFactory {
    function isVaultV2(address vault) external view returns (bool);
}
interface ICurveYield4626Market {
    function asset() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
    function previewRedeem(uint256 shares) external view returns (uint256 assets);
}
interface ICurveYieldLendingRegistry {
    function market_count() external view returns (uint256);
    function vaults(uint256 index) external view returns (address);
}
interface ICurveYieldFraxlendRegistry {
    function deployedPairsLength() external view returns (uint256);
    function deployedPairsArray(uint256 index) external view returns (address);
}
contract CurveYieldLendingMarketAdapterV1 {
    address public immutable factory;
    address public immutable parentVault;
    address public immutable market;
    address public immutable asset;
    bytes32 public immutable adapterId;
    uint8 public immutable protocol; // 1 = CurveLend; 2 = Fraxlend
    uint256 public trackedShares;
    bool private entered;

    error NotVault();
    error InvalidData();
    error AssetMismatch();
    error Reentered();
    error TokenApprovalFailed();
    error InvalidShares();

    constructor(address vault_, address market_, uint8 protocol_) {
        factory = msg.sender;
        parentVault = vault_;
        market = market_;
        protocol = protocol_;
        address a = ICurveYieldParentVaultV2(vault_).asset();
        if (a != ICurveYield4626Market(market_).asset()) revert AssetMismatch();
        asset = a;
        adapterId = keccak256(abi.encode("this", address(this)));
        _approve(a, vault_);
        _approve(a, market_);
    }

    modifier onlyVault() {
        if (msg.sender != parentVault) revert NotVault();
        if (entered) revert Reentered();
        entered = true;
        _;
        entered = false;
    }

    function _approve(address token, address spender) private {
        (bool success, bytes memory result) = token.call(
            abi.encodeWithSelector(bytes4(0x095ea7b3), spender, type(uint256).max)
        );
        if (!success || (result.length != 0 && (result.length != 32 || !abi.decode(result, (bool)))))
            revert TokenApprovalFailed();
    }

    /// @dev Empty data is the canonical market identity for a single-market adapter.
    function ids() public view returns (bytes32[] memory a) {
        a = new bytes32[](1);
        a[0] = adapterId;
    }
    function allocation() public view returns (uint256) {
        return ICurveYieldParentVaultV2(parentVault).allocation(adapterId);
    }

    /// @notice Only shares minted by this adapter are counted; transferred-in shares are ignored.
    function realAssets() external view returns (uint256) {
        if (allocation() == 0) return 0;
        return ICurveYield4626Market(market).previewRedeem(trackedShares);
    }

    function allocate(bytes memory data, uint256 assets, bytes4, address)
        external onlyVault returns (bytes32[] memory, int256)
    {
        if (data.length != 0) revert InvalidData();
        if (assets != 0) {
            uint256 minted = ICurveYield4626Market(market).deposit(assets, address(this));
            if (minted == 0) revert InvalidShares();
            trackedShares += minted;
        }
        uint256 oldRecorded = allocation();
        uint256 current = ICurveYield4626Market(market).previewRedeem(trackedShares);
        return (ids(), _change(current, oldRecorded));
    }

    function deallocate(bytes memory data, uint256 assets, bytes4, address)
        external onlyVault returns (bytes32[] memory, int256)
    {
        if (data.length != 0) revert InvalidData();
        if (assets != 0) {
            uint256 burned = ICurveYield4626Market(market).withdraw(assets, address(this), address(this));
            if (burned == 0 || burned > trackedShares) revert InvalidShares();
            trackedShares -= burned;
        }
        uint256 oldRecorded = allocation();
        uint256 current = ICurveYield4626Market(market).previewRedeem(trackedShares);
        return (ids(), _change(current, oldRecorded));
    }

    function _change(uint256 current, uint256 previous) private pure returns (int256) {
        if (current > uint256(type(int256).max) || previous > uint256(type(int256).max))
            revert InvalidShares();
        return int256(current) - int256(previous);
    }
}

contract CurveYieldLendingMarketAdapterFactoryV1 {
    address public immutable vaultFactory;
    address public immutable curveFactory;
    address public immutable fraxlendRegistry;
    mapping(address vault => mapping(address market => address adapter)) public adapter;
    mapping(address => bool) public isCurveYieldLendingAdapter;

    error InvalidFactory();
    error UnrecognizedVault();
    error UnrecognizedMarket();
    error AlreadyExists();

    event AdapterCreated(address indexed vault, address indexed market, uint8 indexed protocol, address adapter);

    constructor(address vaultFactory_, address curveFactory_, address fraxlendRegistry_) {
        if (vaultFactory_.code.length == 0 || curveFactory_.code.length == 0
            || fraxlendRegistry_.code.length == 0) revert InvalidFactory();
        vaultFactory = vaultFactory_;
        curveFactory = curveFactory_;
        fraxlendRegistry = fraxlendRegistry_;
    }

    /// @notice Permissionless deployment of a unique, vault-bound, market-bound adapter.
    /// @dev Does not enable, approve, fund or allocate. Vault curator must authorize.
    function createAdapter(address vault, address market, uint8 protocol) external returns (address result) {
        if (!ICurveYieldVerifiedVaultFactory(vaultFactory).isVaultV2(vault)) revert UnrecognizedVault();
        if (adapter[vault][market] != address(0)) revert AlreadyExists();
        if (market.code.length == 0 || !_isRegistered(market, protocol)) revert UnrecognizedMarket();
        result = address(new CurveYieldLendingMarketAdapterV1{salt: bytes32(0)}(vault, market, protocol));
        adapter[vault][market] = result;
        isCurveYieldLendingAdapter[result] = true;
        emit AdapterCreated(vault, market, protocol, result);
    }

    function isRegisteredMarket(address market, uint8 protocol) external view returns (bool) {
        return _isRegistered(market, protocol);
    }

    function _isRegistered(address market, uint8 protocol) private view returns (bool) {
        if (protocol == 1) {
            uint256 count = ICurveYieldLendingRegistry(curveFactory).market_count();
            if (count > 256) return false;
            for (uint256 i; i < count; ++i)
                if (ICurveYieldLendingRegistry(curveFactory).vaults(i) == market) return true;
        } else if (protocol == 2) {
            uint256 count = ICurveYieldFraxlendRegistry(fraxlendRegistry).deployedPairsLength();
            if (count > 256) return false;
            for (uint256 i; i < count; ++i)
                if (ICurveYieldFraxlendRegistry(fraxlendRegistry).deployedPairsArray(i) == market) return true;
        }
        return false;
    }
}

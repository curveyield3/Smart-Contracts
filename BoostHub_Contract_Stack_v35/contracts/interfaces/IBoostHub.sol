// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface IBoostHub {
    struct PoolView {
        address asset;
        address gauge;
        bool active;
        uint256 totalStaked;
        address[] rewardTokens;
        address depositor;
        bool depositorLocked;
        bytes4 checkpointSelector;
        uint16 platformFeeBps;
        address platformFeeRecipient;
        bool feeConfigSet;
        uint256[] accRewardPerShare;
    }

    struct PositionView {
        uint256 principal;
        bool approved;
        address[] rewardTokens;
        uint256[] pendingRewards;
    }

    struct SystemView {
        uint256 deployedAt;
        uint256 configChangeDelay;
        address vlBoost;
        address rewardDistributor;
        uint256 vlsdtDelegated;
        uint256 poolCount;
    }

    struct PendingFeeView {
        uint256 pid;
        uint16 platformFeeBps;
        address platformFeeRecipient;
        uint256 readyAt;
    }



    struct PendingTransactionsView {
        address pendingOwner;
        uint256 ownershipTransferReadyAt;
        PendingFeeView[] feeChanges;
        address pendingRewardDistributor;
        uint256 rewardDistributorReadyAt;
    }

    function deposit(uint256 pid, uint256 amount) external;
    function withdraw(uint256 pid, uint256 amount) external;
    function harvest(uint256 pid) external returns (address[] memory tokens, uint256[] memory amounts);
    function claim(uint256 pid, address[] calldata rewardTokens, address receiver) external returns (address[] memory tokens, uint256[] memory amounts);
    struct EthereumMerkleClaim {
        address token;
        uint256 index;
        uint256 amount;
        bytes32[] proof;
    }
    struct FraxtalUrdClaim {
        address reward;
        uint256 cumulativeClaimable;
        bytes32[] proof;
    }
    function claimEthereumMerkleRewards(EthereumMerkleClaim[] calldata claims)
        external returns (uint256[] memory amounts);
    function claimFraxtalMerkleRewards(FraxtalUrdClaim[] calldata claims)
        external returns (uint256[] memory amounts);
    function sweep(address token, address recipient) external;
    function poolInfo(uint256 pid) external view returns (PoolView memory);
    function positionInfo(uint256 pid, address account) external view returns (PositionView memory);
    function pendingTransactions() external view returns (PendingTransactionsView memory);
    function systemInfo() external view returns (SystemView memory);
}

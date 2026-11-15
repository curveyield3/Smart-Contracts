// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice Narrow interface consumed by the existing BoostHub gauge paths.
interface IStakeDaoGauge {
    function staking_token() external view returns (address);
    function deposit(uint256 amount, address receiver) external;
    function withdraw(uint256 amount, bool claimRewards) external;
    function claim_rewards(address user, address receiver) external;
    function reward_tokens(uint256 index) external view returns (address);
    function claimable_reward(address user, address rewardToken) external view returns (uint256);
    function user_checkpoint(address user) external returns (bool);
}

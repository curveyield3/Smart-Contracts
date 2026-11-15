// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Exact public/external function selectors of the attached BoostHubStaking.vy (Vyper 0.4.3).
interface IBoostHubStakingV1 {
    function lp_token() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function deposit(uint256 value, address account) external;
    function withdraw(uint256 value) external;
    function harvest() external;
    function harvest_and_claim() external returns (address[] memory tokens);
    function claim_rewards() external;
    function reward_count() external view returns (uint256);
    function reward_tokens(uint256 index) external view returns (address);
    function reward_disabled(address reward) external view returns (bool);
}

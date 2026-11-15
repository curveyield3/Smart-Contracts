// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Based on Beefy StrategyConvexStakingFraxtal.sol (blob 0560055143e89fb62869dcfb140adb75435bf303).
// Main replacements: exact BoostHubStaking Vyper ABI, dynamic rewards, no external strategy factory.
import "./BaseAllToWantBoostHubV5.sol";
import "./interfaces/IBoostHubStakingV1.sol";

contract StrategyConvexBoostHubStakingV5 is BaseAllToWantBoostHubV5 {
    IBoostHubStakingV1 public immutable staking;
    uint256 public constant MAX_STAKING_REWARDS = 9;

    constructor(
        address _staking,
        Addresses memory _addresses,
        FeeSettings memory _fees,
        uint256 _lockDuration,
        uint256 _minWantOutput
    ) BaseAllToWantBoostHubV5(_addresses, _fees, _lockDuration, _minWantOutput) {
        require(_staking != address(0) && _staking.code.length > 0, "Invalid staking");
        require(IBoostHubStakingV1(_staking).lp_token() == want, "Staking want mismatch");
        staking = IBoostHubStakingV1(_staking);
        _approveExact(want, _staking, type(uint256).max);
    }

    function stratName() public pure override returns (string memory) {
        return "ConvexBoostHubStaking";
    }

    function balanceOfPool() public view override returns (uint256) {
        return staking.balanceOf(address(this));
    }

    function _deposit(uint256 amount) internal override {
        // Vyper function selector is deposit(uint256,address), NOT stake/stakeFor.
        staking.deposit(amount, address(this));
    }

    function _withdraw(uint256 amount) internal override {
        if (amount > 0) staking.withdraw(amount);
    }


    function _claim() internal override returns (address[] memory) {
        return staking.harvest_and_claim();
    }

    /// @notice Current accepted reward tokens, read directly from staking (no stale stored list).
    /// Includes want; underlying-token rewards are charged directly without a swap.
    function acceptedRewardTokens() external view returns (address[] memory tokens) {
        uint256 count = staking.reward_count();
        require(count <= MAX_STAKING_REWARDS, "Excess staking rewards");
        address[] memory available = new address[](count);
        uint256 selected;
        for (uint256 i; i < count; ++i) {
            address token = staking.reward_tokens(i);
            if (token != address(0) && !staking.reward_disabled(token)) {
                available[selected++] = token;
            }
        }
        tokens = new address[](selected);
        for (uint256 i; i < selected; ++i) tokens[i] = available[i];
    }

    function _swappableRewards() internal view override returns (address[] memory swappableRewards) {
        uint256 count = staking.reward_count();
        require(count <= MAX_STAKING_REWARDS, "Excess staking rewards");
        address[MAX_STAKING_REWARDS] memory desired;
        uint256 desiredCount;
        for (uint256 i; i < count; ++i) {
            address token = staking.reward_tokens(i);
            if (token == address(0)) continue;
            // The swap loop checks balances once, including disabled-token leftovers.
            // Never swap want (it can be principal) or the staking address;
            // all other ERC-20 rewards, including wrapped native, swap directly to want.
            if (token == want || token == address(staking)) continue;
            desired[desiredCount++] = token;
        }
        swappableRewards = new address[](desiredCount);
        for (uint256 i; i < desiredCount; ++i) swappableRewards[i] = desired[i];
    }
}

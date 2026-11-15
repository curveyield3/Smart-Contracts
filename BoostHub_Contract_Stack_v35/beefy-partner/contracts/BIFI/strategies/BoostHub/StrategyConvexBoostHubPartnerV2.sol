// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Minimal BoostHub adapter of Beefy's StrategyConvexStakingFraxtal.sol.
// Copy this file into beefy-contracts/contracts/BIFI/strategies/BoostHub/;
// the import below deliberately uses Beefy's UNMODIFIED shared base strategy.
import "../Common/BaseAllToNativeFactoryStrat.sol";

interface IBoostHubPartnerStaking {
    function lp_token() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function deposit(uint256 amount, address account) external;
    function withdraw(uint256 amount) external;
    function harvest() external;
    function claim_rewards() external;
    function reward_count() external view returns (uint256);
    function reward_tokens(uint256 index) external view returns (address);
    function reward_disabled(address token) external view returns (bool);
}

interface IBoostHubOmniRoutes {
    function routeLength(address tokenIn, address tokenOut) external view returns (uint256);
}

contract StrategyConvexBoostHubPartnerV2 is BaseAllToNativeFactoryStrat {
    using SafeERC20 for IERC20;

    uint256 private constant MAX_STAKING_REWARDS = 9;
    IBoostHubPartnerStaking public staking;

    function initialize(
        address _staking,
        address[] calldata _rewards,
        Addresses calldata _addresses
    ) public initializer {
        require(_staking.code.length > 0, "!staking");
        staking = IBoostHubPartnerStaking(_staking);
        require(staking.lp_token() == _addresses.want, "!want");
        // _addresses.swapper is the chain-local v28 Omni router, deployed
        // in the unified script with Beefy-compatible 3-input swap ABI.
        __BaseStrategy_init(_addresses, _rewards);
        _syncStakingRewards();
        // Unlike ConvexStakingFraxtal, do not turn on harvest-on-deposit.
    }

    // IStrategyV7 compatibility: the upstream factory base names this "swapper".
    function unirouter() external view returns (address) {
        return swapper;
    }

    function stratName() public pure override returns (string memory) {
        return "BoostHubStaking";
    }

    function balanceOfPool() public view override returns (uint256) {
        return staking.balanceOf(address(this));
    }

    function _deposit(uint256 amount) internal override {
        IERC20(want).forceApprove(address(staking), amount);
        staking.deposit(amount, address(this));
    }

    function _withdraw(uint256 amount) internal override {
        if (amount > 0) staking.withdraw(amount);
    }

    function _emergencyWithdraw() internal override {
        _withdraw(balanceOfPool());
        IERC20(want).forceApprove(address(staking), 0);
        IERC20(native).forceApprove(swapper, 0);
        for (uint256 i; i < rewards.length; ++i) {
            IERC20(rewards[i]).forceApprove(swapper, 0);
        }
    }

    function _claim() internal override {
        uint256 beforeWant = balanceOfWant();
        staking.harvest();
        staking.claim_rewards();
        _syncStakingRewards();

        // Only newly claimed want rewards, never pre-existing idle principal.
        // Route through native so Beefy's ORIGINAL fee distribution, caller
        // share, profit accounting, and compounding remain unchanged.
        uint256 wantReward = balanceOfWant() - beforeWant;
        if (wantReward > 0) _swap(want, native, wantReward);
    }

    // Populate the inherited Beefy rewards[]; no second reward-accounting array.
    // Retain older reward tokens so disabled tokens can still be converted.
    function _syncStakingRewards() internal {
        uint256 count = staking.reward_count();
        require(count <= MAX_STAKING_REWARDS, "!reward-count");
        for (uint256 i; i < count; ++i) {
            address token = staking.reward_tokens(i);
            if (token == address(0) || token == want || token == native || token == address(staking)) continue;
            if (staking.reward_disabled(token) && IERC20(token).balanceOf(address(this)) == 0) continue;
            // Only configured reward routes can be harvested. Unsupported tokens (including
            // SDT / 3Crv) remain held by this strategy without breaking compounding.
            if (IBoostHubOmniRoutes(swapper).routeLength(token, native) == 0) continue;
            bool known;
            for (uint256 j; j < rewards.length; ++j) {
                if (rewards[j] == token) { known = true; break; }
            }
            if (!known) rewards.push(token);
        }
    }

    function _verifyRewardToken(address token) internal view override {
        require(token != address(staking), "!staking-reward");
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

library BoostHubErrors {
    error ZeroAddress();
    error ZeroAmount();
    error InvalidPool();
    error AlreadySet();
    error PoolInactive();
    error StrategyNotApproved();
    error RewardTokenNotRegistered();
    error RewardTokenLimitExceeded();
    error DuplicateRewardToken();
    error DuplicateGauge();
    error InvalidGaugeAsset();
    error InvalidFee();
    error LengthMismatch();
    error ZeroSelector();
}

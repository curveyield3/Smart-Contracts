// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Isolated benchmark fixtures only. Not deployed into CurveYield production.
contract GasBenchToken {
    uint8 public constant decimals = 18;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    function mint(address to, uint256 amount) external { balanceOf[to] += amount; }
    function approve(address to, uint256 amount) external returns (bool) { allowance[msg.sender][to] = amount; return true; }
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "TOKEN_BALANCE");
        balanceOf[msg.sender] -= amount; balanceOf[to] += amount; return true;
    }
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "TOKEN_BALANCE");
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "TOKEN_ALLOWANCE");
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        balanceOf[from] -= amount; balanceOf[to] += amount; return true;
    }
}
contract GasBenchSwapper {
    function getAmountOut(address, address, uint256 amount) external pure returns (uint256) { return amount; }
}
contract GasBenchGuard { function ping() external pure returns (bool) { return true; } }
contract GasBenchChild {
    address public immutable vault;
    address public immutable want;
    address public curveLiquidityGuard;
    uint256 public lockedProfit;
    constructor(address master, address token) { vault = master; want = token; }
    function balanceOf() external view returns (uint256) { return GasBenchToken(want).balanceOf(address(this)) - lockedProfit; }
    function deposit() external {}
    function withdraw(uint256 amount) external { require(GasBenchToken(want).transfer(msg.sender, amount)); }
    function emergencyWithdraw(uint256 amount) external { require(GasBenchToken(want).transfer(msg.sender, amount)); }
    function withdrawGaugeUnits(uint256 amount) external returns (uint256) {
        require(GasBenchToken(want).transfer(msg.sender, amount)); return amount;
    }
    function harvest(address) external {}
    function setCurveLiquidityGuard(address guard) external { curveLiquidityGuard = guard; }
}
contract GasBenchHub {
    struct Pool {
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
    address public immutable principal;
    uint256 public pendingReward;
    constructor(address token) { principal = token; }
    function poolInfo(uint256) external view returns (Pool memory p) {
        p.asset = principal; p.active = true;
        p.rewardTokens = new address[](1); p.rewardTokens[0] = principal;
        p.accRewardPerShare = new uint256[](1);
    }
    function deposit(uint256, uint256 amount) external { require(GasBenchToken(principal).transferFrom(msg.sender,address(this),amount)); }
    function withdraw(uint256, uint256 amount) external { require(GasBenchToken(principal).transfer(msg.sender,amount)); }
    function seedReward(uint256 amount) external { GasBenchToken(principal).mint(address(this),amount); pendingReward += amount; }
    function harvest(uint256) external view returns (address[] memory t, uint256[] memory a) {
        t = new address[](1); t[0] = principal; a = new uint256[](1); a[0] = pendingReward;
    }
    function claim(uint256, address[] calldata t, address receiver) external returns (address[] memory, uint256[] memory a) {
        a = new uint256[](t.length);
        for (uint256 i; i < t.length; ++i) {
            require(t[i] == principal, "TOKEN");
            a[i] = pendingReward;
            if (pendingReward != 0) {
                require(GasBenchToken(principal).transfer(receiver,pendingReward));
                pendingReward = 0;
            }
        }
        return (t,a);
    }
}

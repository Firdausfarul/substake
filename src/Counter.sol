// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@aave/contracts/interfaces/IPool.sol";
import "@aave/contracts/interfaces/IAToken.sol";

contract YieldSub is Ownable {
    IPool public aavePool;
    IERC20 public depositToken;
    IAToken public aToken;
    
    mapping(address => uint256) public userDepositShares;
    mapping(address => uint256) public creatorShares;
    mapping(address => address) public userSubscriptions;
    
    uint256 public totalShares;
    uint256 public lastDistributionTotal;
    
    event Deposited(address indexed user, uint256 amount, uint256 shares);
    event Withdrawn(address indexed user, uint256 amount, uint256 shares);
    event SubscriptionCreated(address indexed user, address indexed creator);
    event YieldDistributed(address indexed creator, uint256 amount);

    constructor(address _aavePool, address _depositToken, address _aToken) {
        aavePool = IPool(_aavePool);
        depositToken = IERC20(_depositToken);
        aToken = IAToken(_aToken);
    }

    function deposit(uint256 _amount) external {
        require(_amount > 0, "Deposit amount must be greater than 0");
        uint256 sharesToMint = totalShares == 0 ? _amount : (_amount * totalShares) / getTotalATokenBalance();
        
        depositToken.transferFrom(msg.sender, address(this), _amount);
        depositToken.approve(address(aavePool), _amount);
        aavePool.supply(address(depositToken), _amount, address(this), 0);
        
        userDepositShares[msg.sender] += sharesToMint;
        totalShares += sharesToMint;
        
        emit Deposited(msg.sender, _amount, sharesToMint);
    }

    function withdraw() external {
        uint256 shares = userDepositShares[msg.sender];
        require(shares > 0, "No deposit to withdraw");
        
        uint256 totalATokenBalance = getTotalATokenBalance();
        uint256 amountToWithdraw = (shares * totalATokenBalance) / totalShares;
        
        aavePool.withdraw(address(depositToken), amountToWithdraw, msg.sender);
        
        userDepositShares[msg.sender] = 0;
        totalShares -= shares;
        
        emit Withdrawn(msg.sender, amountToWithdraw, shares);
    }

    function subscribe(address _creator) external {
        require(userDepositShares[msg.sender] > 0, "Must have an active deposit");
        require(_creator != address(0), "Invalid creator address");
        
        address oldCreator = userSubscriptions[msg.sender];
        if (oldCreator != address(0)) {
            creatorShares[oldCreator] -= userDepositShares[msg.sender];
        }
        
        userSubscriptions[msg.sender] = _creator;
        creatorShares[_creator] += userDepositShares[msg.sender];
        
        emit SubscriptionCreated(msg.sender, _creator);
    }

    function distributeYield() external onlyOwner {
        uint256 currentTotal = getTotalATokenBalance();
        uint256 yieldAmount = currentTotal - lastDistributionTotal;
        require(yieldAmount > 0, "No yield to distribute");
        
        for (uint256 i = 0; i < getCreatorCount(); i++) {
            address creator = getCreatorAtIndex(i);
            uint256 creatorYield = (yieldAmount * creatorShares[creator]) / totalShares;
            
            if (creatorYield > 0) {
                aavePool.withdraw(address(depositToken), creatorYield, creator);
                emit YieldDistributed(creator, creatorYield);
            }
        }
        
        lastDistributionTotal = getTotalATokenBalance();
    }

    function getTotalATokenBalance() public view returns (uint256) {
        return aToken.balanceOf(address(this));
    }

    // Helper functions (implement these according to your storage structure)
    function getCreatorCount() internal view returns (uint256) {
        // Return the number of unique creators
    }

    function getCreatorAtIndex(uint256 index) internal view returns (address) {
        // Return the creator address at the given index
    }
}
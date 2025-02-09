// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/* solhint-disable no-implicit-dependencies */
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAToken} from "@aave/contracts/interfaces/IAToken.sol";
import {IPool} from "@aave/contracts/interfaces/IPool.sol";
import "forge-std/console.sol";
//import non reentrant
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
//add console.log

contract SubStake is ReentrancyGuard{
    IPool public aavePool;
    IERC20 public depositToken;
    IAToken public aToken;
    
    struct User {
        uint216 rate;
        uint40 lastUpdate;
    }
    struct Stream{
        uint216 rate;
        uint40 lastUpdate;
    }

    mapping (address => uint) public userDeposit;
    mapping (address => uint) public userLastDepositIndex;
    mapping (address => User) public users;
    mapping (bytes32 => Stream) public streamInfo;

    constructor(address _aavePool, address _depositToken, address _aToken) {
        aavePool = IPool(_aavePool);
        depositToken = IERC20(_depositToken);
        aToken = IAToken(_aToken);
    }
    // slither-disable-start timestamp
    function deposit(uint256 _amount) public {
        require(_amount > 0, "Deposit amount must be greater than 0");
        if(userDeposit[msg.sender] == 0){
            userLastDepositIndex[msg.sender] = aavePool.getReserveNormalizedIncome(address(depositToken));
        }
        userDeposit[msg.sender] = getBalance(msg.sender) + _amount;
        userLastDepositIndex[msg.sender] = aavePool.getReserveNormalizedIncome(address(depositToken));

        depositToken.transferFrom(msg.sender, address(this), _amount);
        depositToken.approve(address(aavePool), _amount);
        aavePool.supply(address(depositToken), _amount, address(this), 0);
        
        //emit Deposited(msg.sender, _amount, sharesToMint);
    }

    function getBalance(address _user) public view returns (uint256 res) {
        if(userDeposit[_user] == 0){
            return 0;
        }
        res = userDeposit[_user] * aavePool.getReserveNormalizedIncome(address(depositToken)) / userLastDepositIndex[_user];
    }

    

    function createStream(address _recipient, uint256 _rate) public {
        bytes32 streamId = keccak256(abi.encodePacked(msg.sender, _recipient));
        streamInfo[streamId] = Stream(uint216(_rate), uint40(block.timestamp));
        User storage user = users[msg.sender];
        user.rate += uint216(_rate);
        user.lastUpdate = uint40(block.timestamp);
    }

    //calculate total accrued amount
    //money transfer on the end of function, noneed reentrancyguard
    // slither-disable-start weak-prng, timestamp
    function withdrawStream(address _sender, address _destination) public{
        bytes32 streamId = keccak256(abi.encodePacked(_sender, _destination));
        User storage user = users[_sender];

        //substract user balance    
        uint256 timePassed = block.timestamp - user.lastUpdate;
        uint256 totalAccrued = user.rate * timePassed;
        
        uint256 senderBalance = getBalance(_sender);
        uint lastUpdate;

        if (senderBalance > totalAccrued) {
            userDeposit[_sender] = senderBalance - totalAccrued;
            lastUpdate = block.timestamp;
        } else {
            uint timePaid = senderBalance / user.rate;
            userDeposit[_sender] = senderBalance % user.rate;
            
            lastUpdate = user.lastUpdate + timePaid;
            
        }
        

        uint amountAccrued = (lastUpdate - streamInfo[streamId].lastUpdate) * streamInfo[streamId].rate;
        
        user.lastUpdate = uint40(lastUpdate);
        userLastDepositIndex[_sender] = aavePool.getReserveNormalizedIncome(address(depositToken));
        aavePool.withdraw(address(depositToken), amountAccrued, _destination);
        
        //emit StreamWithdrawn(_sender, msg.sender, amountAccrued);
    }

    // slither-disable-start reentrancy-no-eth
    function cancelStream(address to) public nonReentrant{
        bytes32 streamId = keccak256(abi.encodePacked(msg.sender, to));
        
        User storage user = users[msg.sender];
        withdrawStream(msg.sender, to);
        user.rate -= streamInfo[streamId].rate;
        delete streamInfo[streamId];
        
        //emit StreamCanceled(msg.sender, to);
    }
    // slither-disable-start reentrancy-no-eth
    function modifyStream(address to, uint256 _rate) public {
        cancelStream(to);
        createStream(to, _rate);
        //emit StreamModified(msg.sender, to, _rate);
    }
    //remove this on real deployment 
    function rugpull() public {
        uint256 balance = getBalance(msg.sender);
        userDeposit[msg.sender] = 0;
        aavePool.withdraw(address(depositToken), balance, msg.sender);
    }
}
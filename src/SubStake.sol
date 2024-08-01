// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/* solhint-disable no-implicit-dependencies */
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAToken} from "@aave/contracts/interfaces/IAToken.sol";
import {IPool} from "@aave/contracts/interfaces/IPool.sol";
import "forge-std/console.sol";

//add console.log

contract SubStake {
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
        res = userDeposit[_user] * aavePool.getReserveNormalizedIncome(address(depositToken)) / userLastDepositIndex[_user];
    }

    function _withdraw(address depositor, uint256 _amount, address destination) internal {
        require(_amount > 0, "Withdraw amount must be greater than 0");
        require(getBalance(depositor) >= _amount, "Insufficient balance");

        userDeposit[depositor] = getBalance(depositor) - _amount;
        userLastDepositIndex[depositor] = aavePool.getReserveNormalizedIncome(address(depositToken));

        aavePool.withdraw(address(depositToken), _amount, destination);
        //emit Withdrawn(msg.sender, _amount, sharesToBurn);
    }

    function createStream(address _recipient, uint256 _rate) public {
        bytes32 streamId = keccak256(abi.encodePacked(msg.sender, _recipient));
        streamInfo[streamId] = Stream(uint216(_rate), uint40(block.timestamp));
        User storage user = users[msg.sender];
        user.rate += uint216(_rate);
        user.lastUpdate = uint40(block.timestamp);
    }

    //calculate total accrued amount
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
        
        uint amountAccrued = (block.timestamp - streamInfo[streamId].lastUpdate) * streamInfo[streamId].rate;
        streamInfo[streamId].lastUpdate = uint40(lastUpdate);
        user.lastUpdate = uint40(lastUpdate);
        userLastDepositIndex[_sender] = aavePool.getReserveNormalizedIncome(address(depositToken));
        aavePool.withdraw(address(depositToken), amountAccrued, _destination);
        
        //emit StreamWithdrawn(_sender, msg.sender, amountAccrued);
    }


    function cancelStream(address to) public {
        bytes32 streamId = keccak256(abi.encodePacked(msg.sender, to));
        
        User storage user = users[msg.sender];
        withdrawStream(msg.sender, to);
        user.rate -= streamInfo[streamId].rate;
        delete streamInfo[streamId];
        

        //emit StreamCanceled(msg.sender, to);
    }

    function modifyStream(address to, uint256 _rate) public {
        cancelStream(to);
        createStream(to, _rate);
        //emit StreamModified(msg.sender, to, _rate);
    }


}
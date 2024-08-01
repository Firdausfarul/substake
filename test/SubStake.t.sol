// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/SubStake.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave/contracts/interfaces/IPool.sol";
import {IAToken} from "@aave/contracts/interfaces/IAToken.sol";
import {DataTypes} from '@aave/contracts/protocol/libraries/types/DataTypes.sol';

contract MockERC20 is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;

    function mint(address account, uint256 amount) public {
        _totalSupply += amount;
        _balances[account] += amount;
    }

    function totalSupply() public view  returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view  returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public  returns (bool) {
        _balances[msg.sender] -= amount;
        _balances[recipient] += amount;
        return true;
    }

    function allowance(address owner, address spender) public view  returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public  returns (bool) {
        _allowances[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public  returns (bool) {
        _balances[sender] -= amount;
        _balances[recipient] += amount;
        _allowances[sender][msg.sender] -= amount;
        return true;
    }
}
contract MockAavePool  {
    IERC20 public depositToken;
    MockAToken public aToken;
    uint256 public constant INITIAL_NORMALIZED_INCOME = 1e27;
    uint256 public normalizedIncome = INITIAL_NORMALIZED_INCOME;

    constructor(address _depositToken, address _aToken) {
        depositToken = IERC20(_depositToken);
        aToken = MockAToken(_aToken);
    }

    function supply(address, uint256 amount, address onBehalfOf, uint16) external  {
        depositToken.transferFrom(msg.sender, address(this), amount);
        aToken.mint(onBehalfOf, amount);
    }

    function withdraw(address, uint256 amount, address to) external  returns (uint256) {
        aToken.burn(msg.sender, amount);
        depositToken.transfer(to, amount);
        return amount;
    }

    function getReserveNormalizedIncome(address) external view  returns (uint256) {
        return normalizedIncome;
    }

    // Helper function to simulate interest accrual
    function simulateInterestAccrual(uint256 increase) external {
        normalizedIncome += increase;
    }

    

}

contract MockAToken {
    mapping(address => uint256) private _balances;
    uint256 private _totalSupply;

    function mint(address account, uint256 amount) external {
        _totalSupply += amount;
        _balances[account] += amount;
    }

    function burn(address account, uint256 amount) external {
        _totalSupply -= amount;
        _balances[account] -= amount;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

}

contract SubStakeTest is Test {
    SubStake public subStake;
    MockERC20 public depositToken;
    MockAavePool public aavePool;
    MockAToken public aToken;

    address public alice = address(0x1);
    address public bob = address(0x2);

    function setUp() public {
        depositToken = new MockERC20();
        aToken = new MockAToken();
        aavePool = new MockAavePool(address(depositToken), address(aToken));
        subStake = new SubStake(address(aavePool), address(depositToken), address(aToken));

        // Fund accounts
        depositToken.mint(alice, 1000 ether);
        depositToken.mint(bob, 1000 ether);

        vm.startPrank(alice);
        depositToken.approve(address(subStake), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        depositToken.approve(address(subStake), type(uint256).max);
        vm.stopPrank();
    }

    function testDeposit() public {
        vm.startPrank(alice);
        uint256 depositAmount = 100 ether;
        subStake.deposit(depositAmount);
        
        assertEq(subStake.getBalance(alice), depositAmount, "Deposit balance should match");
        assertEq(aToken.balanceOf(address(subStake)), depositAmount, "AToken balance should match deposit");
        vm.stopPrank();
    }

    function testCreateAndWithdrawStream() public {
        vm.startPrank(alice);
        uint256 depositAmount = 100 ether;
        subStake.deposit(depositAmount);

        uint256 streamRate = 1 ether; // 1 token per second
        subStake.createStream(bob, streamRate);
        vm.stopPrank();

        // Simulate passage of time and interest accrual
        vm.warp(block.timestamp + 10); // 10 seconds pass
        aavePool.simulateInterestAccrual(1e25); // Small interest accrual

        vm.prank(bob);
        subStake.withdrawStream(alice, bob);
        //init mint 1000 + 10 stream
        assertApproxEqAbs(depositToken.balanceOf(bob), 1010 ether, 0.1 ether, "Bob should receive ~10 tokens");
        // + 1 interest 
        assertApproxEqAbs(subStake.getBalance(alice), 91 ether, 0.1 ether, "Alice's balance should be ~90 tokens");
    }

    function testCancelStream() public {
        vm.startPrank(alice);
        uint256 depositAmount = 100 ether;
        subStake.deposit(depositAmount);

        uint256 streamRate = 1 ether; // 1 token per second
        subStake.createStream(bob, streamRate);

        vm.warp(block.timestamp + 5); // 5 seconds pass

        subStake.cancelStream(bob);
        vm.stopPrank();

        assertApproxEqAbs(depositToken.balanceOf(bob), 1005 ether, 0.1 ether, "Bob should receive ~5 tokens");
        assertApproxEqAbs(subStake.getBalance(alice), 95 ether, 0.1 ether, "Alice's balance should be ~95 tokens");
    }

    function testModifyStream() public {
        vm.startPrank(alice);
        uint256 depositAmount = 100 ether;
        subStake.deposit(depositAmount);

        uint256 initialStreamRate = 1 ether; // 1 token per second
        subStake.createStream(bob, initialStreamRate);

        vm.warp(block.timestamp + 5); // 5 seconds pass

        uint256 newStreamRate = 2 ether; // 2 tokens per second
        subStake.modifyStream(bob, newStreamRate);

        vm.warp(block.timestamp + 5); // Another 5 seconds pass
        vm.stopPrank();

        vm.prank(bob);
        subStake.withdrawStream(alice, bob);

        // 5 seconds at 1 ether/second + 5 seconds at 2 ether/second = 15 ether
        assertApproxEqAbs(depositToken.balanceOf(bob), 1015 ether, 0.1 ether, "Bob should receive ~15 tokens");
        assertApproxEqAbs(subStake.getBalance(alice), 85 ether, 0.1 ether, "Alice's balance should be ~85 tokens");
    }

    function testFailInsufficientBalance() public {
        vm.startPrank(alice);
        uint256 depositAmount = 10 ether;
        subStake.deposit(depositAmount);

        uint256 streamRate = 1 ether; // 1 token per second
        subStake.createStream(bob, streamRate);

        vm.warp(block.timestamp + 15); // 15 seconds pass

        // This should fail as Alice only deposited 10 ether
        vm.prank(bob);
        subStake.withdrawStream(alice, bob);
    }
}
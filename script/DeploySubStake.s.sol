// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/SubStake.sol";

contract DeploySubStake is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Sepolia testnet addresses
        address aavePoolAddress = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
        address depositTokenAddress = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8; // usdc-aave on Sepolia
        address aTokenAddress = 0x16dA4541aD1807f4443d92D26044C1147406EB80; // aUSDC on Sepolia

        SubStake subStake = new SubStake(
            aavePoolAddress,
            depositTokenAddress,
            aTokenAddress
        );

        console.log("SubStake deployed to:", address(subStake));

        vm.stopBroadcast();
    }
}
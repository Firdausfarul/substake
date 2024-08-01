# SubStake

 Paystream that handles rebasing interest bearing token like Aave aTokens and lido stETH, that enable depositors to earn interest on their deposit. So depositor can create a payment stream that entirely/partially funded by the interest earned on their deposit.

## Deployments :

- Sepolia - USDC [0x35fc8926A8Ff15FC6652D75DAF4aB9374452c52B](https://etherscan.io/address/0x35fc8926A8Ff15FC6652D75DAF4aB9374452c52B)

## Created by :
Fachrudin

## How to deploy :

1. replace the relevant address in `script/DeploySubStake.s.sol` with token addresss / aave implementation on your chosen chain.

2. set the private key as env variable and run 
```bash
forge script script/DeploySubStake.s.sol:DeploySubStake --rpc-url [YOUR_RPC] --broadcast -vvvv 
```

## Frontend 
Website : https://substake-ui.vercel.app

Repo : https://github.com/Firdausfarul/substake-ui 



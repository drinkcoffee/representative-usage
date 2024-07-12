## Represntative Transactions for Immutable zkEVM

This repo contains contracts snapshotted on July 3, 2024 from various repos. The test code contains code to deploy contracts and the separate functions to call each of the Solidity functions to be called.

**THIS REPO CONTAINS TEST PRIVATE KEYS. These are effectively hard coded. DO NOT USE IN PRODUCTION.**


To generate transactions for installing all contracts:

In one window:

```
anvil
```

In another window:

```
forge script -vvv --rpc-url http://127.0.0.1:8545  script/DeployAll.s.sol:DeployAll
```

Anvil appears to be resetting, so the DeployAll is called at the start of the following RunAll. The calls are deterministic, so the addresses and private keys are the always the same. 

To generate transactions to run against the deployed contracts:

```
forge script -vvv --rpc-url http://127.0.0.1:8545  script/RunAll.s.sol:RunAll
```

Transactions are in files in the `./broadcast` directory. A log file containing the auto generated addresses and keys are in the `./temp` directory.

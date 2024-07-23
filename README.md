## Represntative Transactions for Immutable zkEVM

**THIS REPO CONTAINS A SEED VALUE FROM WHICH MANY TEST PRIVATE KEYS ARE GENERATED. These are effectively hard coded. DO NOT USE IN PRODUCTION.**

The code in this repo allows for creation of transactions that deploy contracts and execute functions that are broadly representative of Immutable zkEVM as of early July 2024.


## How to Run

To generate transactions for installing all contracts, distributing native tokens (ETH or IMX depending on the chain), and then running transactions:

Open three command windows. In window #1:

```
anvil --chain-id 13473 
```

In window #2:

```
socat -r ./temp/a.txt tcp-l:8546,fork,reuseaddr tcp:127.0.0.1:8545
```

Note: If socat is not installed, and if running on MacOS, install using: `brew install socat`.

In window #3:

```
forge script -vvv --rpc-url http://127.0.0.1:8546 --chain-id 13473 --priority-gas-price 10000000000 --with-gas-price 10000000100 script/RunAll.s.sol:RunAll --broadcast -g 150

```

To extract transactions that can then be submitted to a blockchain run the following command and extract the bytes in the param field:

```
python3 scripts/extract-transactions.py temp/tx.txt temp/raw.txt
```


# Adding New Passport Calls
The gas passed to Passport calls needs to be estimated. For the purposes of this test code, a simplistic fixed methodology is used, using the forge command (where in this case it finds gas estimates for the GemGame).
```
forge inspect src/im-contracts/games/gems/GemGame.sol:GemGame gasEstimates
```

# Notes

Configuration:

* The chain id is specified on the command line for `anvil` and `forge script`.
* The addresses and private keys are deterministic. The values are derived the variable `RUN_NAME` in `./script/Globals.s.sol`.
* All addresses are funded from a single initial hard coded address `treasuryPKey`. This is in `./script/DeployAll.s.sol`.
* The amount of gas passed to individual Passport meta transactions is fixed. Function calls can specify this if needed. See `./script/ChainInfrastructure.s.sol` for passport function call alternatives.
* The gas multiplier of 300% has been applied using the `-g 300`. This ensures the available gas, which is derived from forge's gas estimate, is above the fixed Passport meta transaction. This will mean that large transactions will exceed the block gas limit. The fix 
for this is to supply each type of Passport call a better, customised, gas limit.

Output:

* Transactions metadata are in files in the `./broadcast` directory. 
* Calls to the geth client are in `./temp.txt`. To extract just the lines containing transactions, use `cat ./temp/tx.txt | grep eth_send`.
* `./temp/addresses-and-keys.txt` contains auto generated addresses and keys that are used in the deployment. 
* Log information in in the screen for RunAll, before the transaction and block information. 

Known limitations:

* There is currently only one Passport Relayer EOA. When many transactions are submitted in quick succession, geth's transaction pool limit for the number of transactions from the one EOA has been exceeded. Anvil doesn't appear to have this check, and hence the transactions are failing.
* The number of transactions is currently set to 7,000. Numbers of transactions above about 70,000 result in the system failing because forge's EVM simulator runs out of EVM memory.
* Not all of the top transaction types have been implemented. In `./script/RunAll.s.sol` some of the options are listed as `TODO`.

Other Notes:

* The function calls are executed in a pseudo random sequence using a simplistic DRBG. This will generate a repeatable, but random looking set of function calls.
* This repo contains contracts snapshotted on July 3, 2024 from various repos. The test code contains code to deploy contracts and the separate functions to call each of the Solidity functions to be called.


## Reprsentative Transactions for Immutable zkEVM

**THIS REPO CONTAINS A SEED VALUE FROM WHICH MANY TEST PRIVATE KEYS ARE GENERATED. These are effectively hard coded. DO NOT USE IN PRODUCTION.**

The code in this repo allows for creation of transactions that deploy contracts and execute functions that are broadly representative of Immutable zkEVM as of early July 2024.


## How to Run

The process below allows the transactions to be recorded using Anvil, using one treasury private key, and then replayed back on a different chain using a different private key. The chain ids for the two chains must be identical.

The contracts to be deployed on the chain. The deployment is checked. Then, the run time transactions are executed rapidly.

Define constants:

```
CHAINID is the chain id of the target chain.
URIPORT is the URI and port of the target chain's RPC. Shoudl be http://1.2.3.4:8545 or similar.
```


Open three command windows. In window #1 have anvil, window #2 have socat, and window #2 use forge and other commands. The sequence is:

**Part 1: Obtain marker transaction:**

* In .env file, set ACCOUNT_PVT_KEY key to a pre-funded key in anvil
* Forge window: `set -a; source .env; set +a`
* Anvil window: `anvil --chain-id CHAINID`
* Socat window: `socat -r ./temp/a13.txt tcp-l:8546,fork,reuseaddr tcp:127.0.0.1:8545`
* Forge window: `forge script -vvv  --chain-id CHAINID --priority-gas-price 10000000000 --with-gas-price 10000000100 script/RunCustom.s.sol:RunCustom --broadcast -g 150 --sig "run(string memory _executionType)"  --rpc-url http://127.0.0.1:8546 deploy`
* Forge window: `python3 scripts/extract-rpc-sendrawtransactions.py temp/a13.txt temp/raw.txt`
* Copy last transaction - the marker transaction in raw.txt
* Check using https://rawtxdecode.in/ . Should be a value transfer, sending 0 eth to address 0.
* Delete log files in ./temp

**Part 2: Get the runtime transactions:**

* Restart anvil and socat
* Forge window: `forge script -vvv  --chain-id 32382 --priority-gas-price 10000000000 --with-gas-price 10000000100 script/RunCustom.s.sol:RunCustom --broadcast -g 150 --sig "run(string memory _executionType)"  --rpc-url http://127.0.0.1:8546 deploy-execute`
* Stop anvil and socat
* Forge window" `python3 scripts/extract-rpc-sendrawtransactions.py temp/a13.txt temp/raw.txt`
* In raw.txt, delete the marker transaction and all previous transactions.

**Part 3: Deploy contracts on the real chain using the real treasury private key.**

* In .env: set treasury key to the chain’s treasury key
* Forge window: `set -a; source .env; set +a`
* Check that the treasury account has funds in it. Forge window: `forge script -vvv  --chain-id CHAINID --priority-gas-price 10000000000 --with-gas-price 10000000100 script/RunCustom.s.sol:RunCustom --broadcast -g 150 --sig "run(string memory _executionType)"  --rpc-url URIPORT check-treasury` . 
* Deploy the contracts and fund accounts from the treasury account: Forge window: `forge script -vvv  --chain-id CHAINID --priority-gas-price 10000000000 --with-gas-price 10000000100 script/RunCustom.s.sol:RunCustom --broadcast -g 150 --sig "run(string memory _executionType)"  --rpc-url URIPORT deploy`
* Check the deployment. Forge window: `forge script -vvv  --chain-id CHAINID --priority-gas-price 10000000000 --with-gas-price 10000000100 script/RunCustom.s.sol:RunCustom --broadcast -g 150 --sig "run(string memory _executionType)"  --rpc-url URIPORT check-deploy`

**Part 4: Run the "runtime" transactions fast**
* Forge window: `python3 scripts/rpc-call-multi.py ./temp/raw.txt URIPORT`


# Adding New Passport Calls
The gas passed to Passport calls needs to be estimated. For the purposes of this test code, a simplistic fixed methodology is used, using the forge command (where in this case it finds gas estimates for the GemGame).
```
forge inspect src/im-contracts/games/gems/GemGame.sol:GemGame gasEstimates
```

# Notes

Configuration:

* The chain id is specified on the command line for `anvil` and `forge script`.
* The addresses and private keys are deterministic. The values are derived the variable `RUN_NAME` in the `.env` file.
* All addresses are funded from a single initial hard coded address `ACCOUNT_PVT_KEY`. This is in the `.env` file.
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

* This repo contains contracts snapshotted on July 3, 2024 from various repos. The test code contains code to deploy contracts and the separate functions to call each of the Solidity functions to be called.


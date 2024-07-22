# Script to generate ImmutableSeaportCreation.sol

#import argparse
import subprocess
import re

#prog = "Extract Transactions"
#parser = argparse.ArgumentParser(prog)
#parser.add_argument("infile", help="Input file containing all communication between script and Anvil.", type=str)
#parser.add_argument("outfile", help="Output file containing all transactions.", type=str)
#args = parser.parse_args()

print("Welcome to ImmutableSeaportCreation")

outfile = "./temp/ImmutableSeaportCreation.sol"

try: 
    bytecodeWith0xAndReturn = subprocess.check_output(["forge", "inspect", "src/im-contracts/trading/seaport/ImmutableSeaport.sol:ImmutableSeaport", "bytecode", "--optimize", "--optimizer-runs", "0"], text=True) 
    bytecodeWith0x = re.sub("\n", "", bytecodeWith0xAndReturn)
    bytecode = re.sub("0x", "", bytecodeWith0x)
    # print("Result: ", bytecode) 
  
except subprocess.CalledProcessError as e: 
    print(f"Command failed with return code {e.returncode}")
    exit(-2)


with open(outfile, 'wb') as file_out:
    file_out.write(b"// Generated file - do not modify directly\n")
    file_out.write(b"pragma solidity ^0.8;\n")
    file_out.write(b"contract ImmutableSeaportCreation {\n")
    line = "    bytes public constant WALLET_DEPLOY_CODE = hex'" + bytecode + "';\n"
    file_out.write(line.encode())
    file_out.write(b"}\n")

print("Done")


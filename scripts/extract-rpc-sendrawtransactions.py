import argparse
import re

prog = "Extract Transactions"
parser = argparse.ArgumentParser(prog)
parser.add_argument("infile", help="Input file containing all communication between script and Anvil.", type=str)
parser.add_argument("outfile", help="Output file containing all transactions.", type=str)
args = parser.parse_args()
print("Welcome to ", prog)
print("In file: ", args.infile)
print("Out file: ", args.outfile)

text = b'eth_sendRawTransaction'
result = []

with open(args.infile, 'rb') as file_in:
    with open(args.outfile, 'wb') as file_out:
        lines = filter(lambda line: text in line, file_in)
        for line in lines:
            output = re.sub(b"POST \/ HTTP\/1.1", b"", line)
            result.append(output)

        file_out.writelines(result)

print("Done")


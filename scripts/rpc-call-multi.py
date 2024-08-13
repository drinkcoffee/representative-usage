import requests
import argparse
import json
import re

prog = "Process Transactions"
parser = argparse.ArgumentParser(prog)
parser.add_argument("infile", help="Input log file.", type=str)
parser.add_argument("url", help="URL including port.", type=str)
args = parser.parse_args()
print("Welcome to ", prog)
print("In file: ", args.infile)
print("URL: ", args.url)

text = b'eth_sendRawTransaction'
with open(args.infile, 'rb') as file_in:
    lines = filter(lambda line: text in line, file_in)
    for line in lines:
        onlyjsontext = re.sub(b"POST \/ HTTP\/1.1", b"", line)
        obj = json.loads(onlyjsontext)
        x = requests.post(args.url, json = obj)
        print("Request: ", onlyjsontext)
        print("Response: ", x.text)

print("Done")


import requests

url = 'https://rpc.testnet.immutable.com'
myobj = {"method":"eth_sendRawTransaction","params":["0x02f8778234a1808502540be4008502540be4648301057894dd1ec88ef8797f09b4d4a8a1adb3a085476d8c1d888ac7230489e8000080c001a0cf001b4f9a4d3f70d6b5f9d4607dfb791f0d29a1c57897d36caeadb9aa402d82a07b1786ab053601d44893c5d46441dcf36811a041785745d18901ad314547d124"],"id":1,"jsonrpc":"2.0"}

x = requests.post(url, json = myobj)

print(x.text)
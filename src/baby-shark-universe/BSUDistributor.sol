// Decompiled by library.dedaub.com
// then heavily reworked by Peter Robinson
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract BSUDistributor is Ownable{

    // Data structures and variables inferred from the use of storage instructions
    address aToken; // STORAGE[0x1] bytes 0 to 19


    constructor (address _token) Ownable() {
        aToken = _token;
    }


    function withdrawETH(address payable to, uint256 amountOut) public onlyOwner { 
        require(address(this).balance >= amountOut, 'Insufficient balance');
        bool success;
        (success,  /*result*/) = to.call{value: amountOut, gas: 2300}("");
//        require(v0, 0, RETURNDATASIZE()); // checks call status, propagates error data on error
        require(success); // checks call status, propagates error data on error
    }

    function withdrawTokens(address _token, address _to, uint256 _amount) public onlyOwner { 
        require(msg.data.length - 4 >= 96);
        bool success = IERC20(_token).transfer(_to, _amount);
        require(success);
    }


    // Appears to be a bulk transfer - ERC 20 function.
    function func_0x9671e1db(address[] calldata /* _receivers */, uint256 /* varg1 */, uint256 /* varg2 */) public payable { 
        // //require(msg.data.length - 4 >= 96);
        // //require(varg0 <= uint64.max);
        // //require(4 + varg0 + 31 < msg.data.length);
        // //require(varg0.length <= uint64.max, Panic(65)); // failed memory allocation (too much memory)
        // //address v0 = new address[](varg0.length);
        // //require(!((v0 + (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0 & 32 + (varg0.length << 5) + 31) < v0) | (v0 + (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0 & 32 + (varg0.length << 5) + 31) > uint64.max)), Panic(65)); // failed memory allocation (too much memory)
        // uint256 v1 = v0.data;
        // //uint256 v2 = v0.data;
        // require(32 + (4 + varg0 + (varg0.length << 5)) <= msg.data.length);
        // uint256 v3 = varg0.data;
        // //uint256 v4 = varg0.data;
        // while (v3 < 32 + (4 + varg0 + (varg0.length << 5))) {
        //     require(msg.data[v3] == address(msg.data[v3]));
        //     MEM[v1] = msg.data[v3];
        //     v1 += 32;
        //     v3 += 32;
        // }
        // require(varg1 <= uint64.max);
        // require(4 + varg1 + 31 < msg.data.length);
        // require(varg1.length <= uint64.max, Panic(65)); // failed memory allocation (too much memory)
        // v5 = new uint256[](varg1.length);
        // require(!((v5 + (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0 & 32 + (varg1.length << 5) + 31) < v5) | (v5 + (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0 & 32 + (varg1.length << 5) + 31) > uint64.max)), Panic(65)); // failed memory allocation (too much memory)
        // v6 = v7 = v5.data;
        // require(32 + (4 + varg1 + (varg1.length << 5)) <= msg.data.length);
        // v8 = v9 = varg1.data;
        // while (v8 < 32 + (4 + varg1 + (varg1.length << 5))) {
        //     MEM[v6] = msg.data[v8];
        //     v6 += 32;
        //     v8 += 32;
        // }
        // require(varg2 <= uint64.max);
        // require(4 + varg2 + 31 < msg.data.length);
        // require(varg2.length <= uint64.max, Panic(65)); // failed memory allocation (too much memory)
        // v10 = new uint256[](varg2.length);
        // require(!((v10 + (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0 & 32 + (varg2.length << 5) + 31) < v10) | (v10 + (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0 & 32 + (varg2.length << 5) + 31) > uint64.max)), Panic(65)); // failed memory allocation (too much memory)
        // v11 = v12 = v10.data;
        // require(32 + (4 + varg2 + (varg2.length << 5)) <= msg.data.length);
        // v13 = v14 = varg2.data;
        // while (v13 < 32 + (4 + varg2 + (varg2.length << 5))) {
        //     MEM[v11] = msg.data[v13];
        //     v11 += 32;
        //     v13 += 32;
        // }


        // require(msg.sender == _owner, Error('Ownable: caller is not the owner'));
        // v15 = v16 = v0.length == v5.length;
        // if (v16) {
        //     v15 = v0.length == v10.length;
        // }
        // require(v15, Error('Arrays must have the same length'));
        // v17 = v18 = 0;
        // while (v17 < v10.length) {
        //     require(v17 < v10.length, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
        //     v17 = _SafeAdd(v17, v10[v17]);
        //     v17 = 0xe0d(v17);
        // }
        // require(msg.value >= v17, Error('Insufficient ETH sent'));
        // v19 = v20 = 0;
        // while (v19 < v0.length) {
        //     require(v19 < v5.length, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
        //     if (v5[v19] > 0) {
        //         require(v19 < v0.length, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
        //         require(v19 < v5.length, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
        //         (bool v21, bool v22) = _token.transferFrom(msg.sender, address(v0[v19]), v5[v19]).gas(msg.gas);
        //         if (bool(v21)) {
        //             require(MEM[64] + RETURNDATASIZE() - MEM[64] >= 32);
        //             require(v22 == bool(v22));
        //             require(v22, Error('Token transfer failed'));
        //         } else {
        //             RETURNDATACOPY(0, 0, RETURNDATASIZE());
        //             revert(0, RETURNDATASIZE());
        //         }
        //     }
        //     require(v19 < v10.length, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
        //     if (v10[v19] > 0) {
        //         require(v19 < v0.length, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
        //         require(v19 < v10.length, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
        //         v23 = address(v0[v19]).call().value(v10[v19]).gas(!v10[v19] * 2300);
        //         if (!bool(v23)) {
        //             RETURNDATACOPY(0, 0, RETURNDATASIZE());
        //             revert(0, RETURNDATASIZE());
        //         }
        //     }
        //     v19 = 0xe0d(v19);
        // }
    }

    function func_0xea650bcb(address[] calldata /* varg0 */, uint256 /* varg1 */, uint256 /* varg2 */) public { 
        // require(msg.data.length - 4 >= 96);
        // require(varg0 <= uint64.max);
        // require(4 + varg0 + 31 < msg.data.length);
        // require(varg0.length <= uint64.max, Panic(65)); // failed memory allocation (too much memory)
        // v0 = new address[](varg0.length);
        // require(!((v0 + (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0 & 32 + (varg0.length << 5) + 31) < v0) | (v0 + (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0 & 32 + (varg0.length << 5) + 31) > uint64.max)), Panic(65)); // failed memory allocation (too much memory)
        // v1 = v2 = v0.data;
        // require(32 + (4 + varg0 + (varg0.length << 5)) <= msg.data.length);
        // v3 = v4 = varg0.data;
        // while (v3 < 32 + (4 + varg0 + (varg0.length << 5))) {
        //     require(msg.data[v3] == address(msg.data[v3]));
        //     MEM[v1] = msg.data[v3];
        //     v1 += 32;
        //     v3 += 32;
        // }
        // require(varg1 <= uint64.max);
        // require(4 + varg1 + 31 < msg.data.length);
        // require(varg1.length <= uint64.max, Panic(65)); // failed memory allocation (too much memory)
        // v5 = new uint256[](varg1.length);
        // require(!((v5 + (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0 & 32 + (varg1.length << 5) + 31) < v5) | (v5 + (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0 & 32 + (varg1.length << 5) + 31) > uint64.max)), Panic(65)); // failed memory allocation (too much memory)
        // v6 = v7 = v5.data;
        // require(32 + (4 + varg1 + (varg1.length << 5)) <= msg.data.length);
        // v8 = v9 = varg1.data;
        // while (v8 < 32 + (4 + varg1 + (varg1.length << 5))) {
        //     MEM[v6] = msg.data[v8];
        //     v6 += 32;
        //     v8 += 32;
        // }
        // require(varg2 <= uint64.max);
        // require(4 + varg2 + 31 < msg.data.length);
        // require(varg2.length <= uint64.max, Panic(65)); // failed memory allocation (too much memory)
        // v10 = new uint256[](varg2.length);
        // require(!((v10 + (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0 & 32 + (varg2.length << 5) + 31) < v10) | (v10 + (0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0 & 32 + (varg2.length << 5) + 31) > uint64.max)), Panic(65)); // failed memory allocation (too much memory)
        // v11 = v12 = v10.data;
        // require(32 + (4 + varg2 + (varg2.length << 5)) <= msg.data.length);
        // v13 = v14 = varg2.data;
        // while (v13 < 32 + (4 + varg2 + (varg2.length << 5))) {
        //     MEM[v11] = msg.data[v13];
        //     v11 += 32;
        //     v13 += 32;
        // }
        // require(msg.sender == _owner, Error('Ownable: caller is not the owner'));
        // v15 = v16 = v0.length == v5.length;
        // if (v16) {
        //     v15 = v0.length == v10.length;
        // }
        // require(v15, Error('Arrays must have the same length'));
        // v17 = v18 = 0;
        // while (v17 < v0.length) {
        //     require(v17 < v5.length, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
        //     if (v5[v17] > 0) {
        //         require(v17 < v0.length, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
        //         require(v17 < v5.length, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
        //         (bool v19, bool v20) = _token.transferFrom(msg.sender, address(v0[v17]), v5[v17]).gas(msg.gas);
        //         if (bool(v19)) {
        //             require(MEM[64] + RETURNDATASIZE() - MEM[64] >= 32);
        //             require(v20 == bool(v20));
        //             require(v20, Error('Token transfer failed'));
        //         } else {
        //             RETURNDATACOPY(0, 0, RETURNDATASIZE());
        //             revert(0, RETURNDATASIZE());
        //         }
        //     }
        //     require(v17 < v10.length, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
        //     if (v10[v17] > 0) {
        //         require(v17 < v0.length, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
        //         require(v17 < v10.length, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
        //         v21 = address(v0[v17]).call().value(v10[v17]).gas(!v10[v17] * 2300);
        //         if (!bool(v21)) {
        //             RETURNDATACOPY(0, 0, RETURNDATASIZE());
        //             revert(0, RETURNDATASIZE());
        //         }
        //     }
        //     v17 = func_0xe0d(v17);
        // }
    }


    function depositETH() public payable onlyOwner { 
    }

    function token() public view returns (address) { 
        return aToken;
    }

    receive() external payable { 
        revert("Direct ETH transfers are not allowed', 'Direct ETH transfers are not allowed");
    }

    // function func_0xe0d(uint256 varg0) private pure returns(uint256) { 
    //     require(varg0 + 1, Panic(17)); // arithmetic overflow or underflow
    //     return 1 + varg0;
    // }

    // function _SafeAdd(uint256 varg0, uint256 varg1) private pure returns(uint256) { 
    //     require(varg0 <= varg1 + varg0, Panic(17)); // arithmetic overflow or underflow
    //     return varg1 + varg0;
    // }

    function bulkTransfer(address[] calldata _receivers, uint256[] calldata _amounts) public onlyOwner { 
        require(_receivers.length == _amounts.length, "Recipients and amounts arrays must have the same length");

        for (uint256 i = 0; i < _receivers.length; i++) {
            if (_amounts[i] > 0) {
                bool success = IERC20(aToken).transferFrom(msg.sender, address(_receivers[i]), _amounts[i]);
                require(success, "Transfer failed");
            }
        }
    }

    // Note: The function selector is not present in the original solidity code.
    // However, we display it for the sake of completeness.

    // function __function_selector__() private { 
    //     //MEM[64] = 128;
    //     if (msg.data.length < 4) {
    //         require(!msg.data.length);
    //         /* receive(); */
    //     } else if (0x9671e1db > msg.data[0] >> 224) {
    //         if (0x153a1f3e == msg.data[0] >> 224) {
    //             bulkTransfer(address[],uint256[]);
    //         } else if (0x4782f779 == msg.data[0] >> 224) {
    //             withdrawETH(address,uint256);
    //         } else if (0x5e35359e == msg.data[0] >> 224) {
    //             withdrawTokens(address,address,uint256);
    //         } else if (0x715018a6 == msg.data[0] >> 224) {
    //             renounceOwnership();
    //         } else {
    //             require(0x8da5cb5b == msg.data[0] >> 224);
    //             owner();
    //         }
    //     } else if (0x9671e1db == msg.data[0] >> 224) {
    //         func_0x9671e1db();
    //     } else if (0xea650bcb == msg.data[0] >> 224) {
    //         func_0xea650bcb();
    //     } else if (0xf2fde38b == msg.data[0] >> 224) {
    //         transferOwnership(address);
    //     } else if (0xf6326fb3 == msg.data[0] >> 224) {
    //         depositETH();
    //     } else {
    //         require(0xfc0c546a == msg.data[0] >> 224);
    //         token();
    //     }
    // }
}

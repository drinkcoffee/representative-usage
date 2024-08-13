pragma solidity ^0.8;

import "openzeppelin-contracts-upgradeable-4.9.3/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable-4.9.3/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable-4.9.3/security/PausableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable-4.9.3/security/ReentrancyGuardUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";



interface IBabySharkUniverseNFT {
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function mint(address to, uint256 tokenId) external;

    function burn(uint256 tokenId) external;
}

contract BSUTicketExchange is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    IBabySharkUniverseNFT public nftContract;
    address private masterSigner;

    struct Product {
        bool isERC20;
        address tokenAddress;
        uint256 total;
        uint256 current;
        uint256 tokenAmount;
        NFTData nftData;
    }

    struct NFTData {
        uint256[] startIds;
        uint256[] endIds;
    }

    mapping(uint256 => bool) public categories;
    mapping(uint256 => mapping(uint256 => Product)) public products;
    mapping(uint256 => uint256) public productCount;

    event CategoryAdded(uint256 indexed category);
    event CategoryRemoved(uint256 indexed category);
    event ProductAdded(
        uint256 indexed category,
        uint256 indexed productIndex,
        address tokenAddress,
        bool isERC20,
        uint256 total
    );
    event Exchanged(
        uint256 indexed category,
        uint256 indexed productIndex,
        address indexed user
    );
    event ProductRemoved(
        uint256 indexed category,
        uint256 indexed productIndex
    );

    event MasterSignerUpdated(address masterSigner);

    function initialize(address _nftContractAddress, address _masterSigner)
        public
        initializer
    {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        nftContract = IBabySharkUniverseNFT(_nftContractAddress);
        masterSigner = _masterSigner;
    }

    function setMasterSigner(address _masterSigner) external onlyOwner {
        require(_masterSigner != address(0), "Invalid address");
        masterSigner = _masterSigner;
        emit MasterSignerUpdated(_masterSigner);
    }

    function getMasterSigner() external view returns (address) {
        return masterSigner;
    }

    function addCategory(uint256 category) public onlyOwner {
        require(!categories[category], "Category already exists");
        categories[category] = true;
        emit CategoryAdded(category);
    }

    function removeCategory(uint256 category) public onlyOwner {
        require(categories[category], "Category does not exist");
        require(
            getCategoryProductCount(category) == 0,
            "Category has products"
        );
        categories[category] = false;
        emit CategoryRemoved(category);
    }

    function addProductERC20(
        uint256 category,
        uint256 productIndex,
        uint256 total,
        address tokenAddress,
        uint256 tokenAmount
    ) public onlyOwner {
        require(categories[category], "Category does not exist");
        require(
            products[category][productIndex].tokenAddress == address(0),
            "Product already exists"
        );
        require(total > 0, "Total must be greater than 0");
        require(tokenAddress != address(0), "Invalid token address");

        products[category][productIndex] = Product(
            true,
            tokenAddress,
            total,
            0,
            tokenAmount,
            NFTData(new uint256[](0), new uint256[](0))
        );

        productCount[category] += 1;

        emit ProductAdded(category, productIndex, tokenAddress, true, total);
    }

    function addProductNFT(
        uint256 category,
        uint256 productIndex,
        uint256 total,
        uint256[] calldata startIds,
        uint256[] calldata endIds
    ) public onlyOwner {
        require(categories[category], "Category does not exist");
        require(
            products[category][productIndex].tokenAddress == address(0),
            "Product already exists"
        );
        require(total > 0, "Total must be greater than 0");
        require(
            startIds.length == endIds.length,
            "Start and end IDs must match in length"
        );
        products[category][productIndex] = Product(
            false,
            address(nftContract),
            total,
            0,
            startIds.length,
            NFTData(startIds, endIds)
        );

        productCount[category] += 1;

        emit ProductAdded(
            category,
            productIndex,
            address(nftContract),
            false,
            total
        );
    }

    function editProductERC20(
        uint256 category,
        uint256 productIndex,
        uint256 total,
        address tokenAddress,
        uint256 tokenAmount
    ) public onlyOwner {
        require(categories[category], "Category does not exist");
        Product storage product = products[category][productIndex];
        require(product.tokenAddress != address(0), "Product does not exist");
        require(product.isERC20, "Not an ERC20 product");

        require(total >= product.current, "Total less than current amount");
        require(tokenAddress != address(0), "Invalid token address");

        product.total = total;
        product.tokenAddress = tokenAddress;
        product.tokenAmount = tokenAmount;

        emit ProductAdded(category, productIndex, tokenAddress, true, total);
    }

    function editProductNFT(
        uint256 category,
        uint256 productIndex,
        uint256 total,
        uint256[] calldata startIds,
        uint256[] calldata endIds
    ) public onlyOwner {
        require(categories[category], "Category does not exist");
        Product storage product = products[category][productIndex];
        require(product.tokenAddress != address(0), "Product does not exist");
        require(!product.isERC20, "Not an NFT product");

        require(total >= product.current, "Total less than current amount");
        require(
            startIds.length == endIds.length,
            "Start and end IDs must match in length"
        );

        product.total = total;
        product.nftData = NFTData(startIds, endIds);

        emit ProductAdded(
            category,
            productIndex,
            address(nftContract),
            false,
            total
        );
    }

    function removeProduct(uint256 category, uint256 productIndex)
        public
        onlyOwner
    {
        require(categories[category], "Category does not exist");
        Product storage product = products[category][productIndex];
        require(product.tokenAddress != address(0), "Product does not exist");

        delete products[category][productIndex];
        productCount[category] -= 1;

        emit ProductRemoved(category, productIndex);
    }

    function exchange(
        uint256 category,
        uint256 productIndex,
        uint256[] calldata nftIds,
        bytes calldata signature
    ) public whenNotPaused nonReentrant {
        require(categories[category], "Category does not exist");
        Product storage product = products[category][productIndex];
        require(product.tokenAddress != address(0), "Product does not exist");
        require(
            product.current + nftIds.length <= product.total,
            "Product is sold out"
        );
        require(nftIds.length > 0, "No NFT IDs provided");

        require(
            verifySignature(
                category,
                productIndex,
                nftIds,
                msg.sender,
                signature
            ),
            "Invalid signature"
        );

        for (uint256 i = 0; i < nftIds.length; i++) {
            nftContract.transferFrom(msg.sender, address(this), nftIds[i]);
            nftContract.burn(nftIds[i]);
        }

        if (product.isERC20) {
            require(
                IERC20(product.tokenAddress).transfer(
                    msg.sender,
                    product.tokenAmount
                ),
                "ERC20 transfer failed"
            );
        } else {
            NFTData storage data = product.nftData;
            for (uint256 i = 0; i < data.startIds.length; i++) {
                uint256 mintId = data.startIds[i] + product.current;
                require(mintId <= data.endIds[i], "NFT ID exceeds range");
                IBabySharkUniverseNFT(product.tokenAddress).mint(
                    msg.sender,
                    mintId
                );
            }
        }
        product.current += 1;
        emit Exchanged(category, productIndex, msg.sender);
    }

    function verifySignature(
        uint256 category,
        uint256 productIndex,
        uint256[] calldata nftIds,
        address user,
        bytes calldata signature
    ) private view returns (bool) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                category,
                productIndex,
                nftIds,
                user,
                address(this)
            )
        );
        bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(hash);
        return ECDSA.recover(ethSignedMessageHash, signature) == masterSigner;
    }

    function getProduct(uint256 category, uint256 productIndex)
        public
        view
        returns (Product memory)
    {
        require(categories[category], "Category does not exist");
        require(
            products[category][productIndex].tokenAddress != address(0),
            "Product does not exist"
        );
        return products[category][productIndex];
    }

    function getNFTData(uint256 category, uint256 productIndex)
        public
        view
        returns (uint256[] memory startIds, uint256[] memory endIds)
    {
        require(categories[category], "Category does not exist");
        require(
            products[category][productIndex].tokenAddress != address(0),
            "Product does not exist"
        );
        NFTData storage data = products[category][productIndex].nftData;
        return (data.startIds, data.endIds);
    }

    function getCategoryProductCount(uint256 category)
        public
        view
        returns (uint256)
    {
        require(categories[category], "Category does not exist");
        return productCount[category];
    }

    function getTotalCategoryCount() public view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < 2**256 - 1; i++) {
            if (categories[i]) {
                count++;
            } else {
                break;
            }
        }
        return count;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
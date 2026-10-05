// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {NFTMarketplace} from "../src/NFTMarketplace.sol";

contract NonERC721Buyer {
    NFTMarketplace public marketplace;

    constructor(NFTMarketplace _marketplace) {
        marketplace = _marketplace;
    }

    function buy(address nft, uint256 tokenId) external payable {
        marketplace.buyNFT{value: msg.value}(nft, tokenId);
    }
}

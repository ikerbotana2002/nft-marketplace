// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";

contract ReentrantBuyer is IERC721Receiver {
    NFTMarketplace public marketplace;

    address public attackNFT;
    uint256 public attackTokenId;
    uint256 public attackPrice;

    bool public attackAttempted;
    bool public reentrantCallSucceeded;

    constructor(NFTMarketplace _marketplace) {
        marketplace = _marketplace;
    }

    function configureAttack(address nft, uint256 tokenId, uint256 price) external {
        attackNFT = nft;
        attackTokenId = tokenId;
        attackPrice = price;
    }

    function buy(address nft, uint256 tokenId) external payable {
        marketplace.buyNFT{value: msg.value}(nft, tokenId);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        attackAttempted = true;

        try marketplace.buyNFT{value: attackPrice}(attackNFT, attackTokenId) {
            reentrantCallSucceeded = true;
        } catch {
            reentrantCallSucceeded = false;
        }

        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}

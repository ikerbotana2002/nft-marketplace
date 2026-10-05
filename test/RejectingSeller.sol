// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";

contract RejectingSeller is IERC721Receiver {
    NFTMarketplace public marketplace;

    constructor(NFTMarketplace _marketplace) {
        marketplace = _marketplace;
    }

    function withdraw() external {
        marketplace.withdrawProceeds();
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {
        revert("ETH rejected");
    }
}

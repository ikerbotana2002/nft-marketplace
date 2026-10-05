// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {NFTMarketplace} from "../src/NFTMarketplace.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract ReentrantSeller is IERC721Receiver {
    NFTMarketplace public marketplace;

    bool public attackAttempted;
    bool public reentrantCallSucceeded;

    constructor(NFTMarketplace _marketplace) {
        marketplace = _marketplace;
    }

    function withdraw() external {
        marketplace.withdrawProceeds();
    }

    receive() external payable {
        attackAttempted = true;

        try marketplace.withdrawProceeds() {
            reentrantCallSucceeded = true;
        } catch {
            reentrantCallSucceeded = false;
        }
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {NFTMarketplace} from "../src/NFTMarketplace.sol";

contract RejectingOwner {
    function withdrawFees(NFTMarketplace marketplace) external {
        marketplace.withdrawFees();
    }

    receive() external payable {
        revert("ETH rejected");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";

import {NFTMarketplace} from "../src/NFTMarketplace.sol";
import {MockNFT} from "./MockNFT.sol";
import {NFTMarketplaceHandler} from "./NFTMarketplaceHandler.sol";

contract NFTMarketplaceInvariant is StdInvariant, Test {
    NFTMarketplace marketplace;
    MockNFT nft;
    NFTMarketplaceHandler handler;
    receive() external payable {}

    function setUp() public {
        marketplace = new NFTMarketplace();
        nft = new MockNFT();

        handler = new NFTMarketplaceHandler(
            marketplace,
            nft
        );

        targetContract(address(handler));
    }

    function invariant_ContractBalanceMatchesAccounting()
        public
        view
    {
        uint256 sellerProceeds =
            marketplace.proceeds(handler.sellerA()) +
            marketplace.proceeds(handler.sellerB());

        uint256 totalLiabilities =
            sellerProceeds +
            marketplace.feesAccrued();

        assertEq(
            address(marketplace).balance,
            totalLiabilities
        );
    }

    function invariant_MarketplaceIsAlwaysSolvent()
        public
        view
    {
        uint256 sellerProceeds =
            marketplace.proceeds(handler.sellerA()) +
            marketplace.proceeds(handler.sellerB());

        uint256 totalLiabilities =
            sellerProceeds +
            marketplace.feesAccrued();

        assertGe(
            address(marketplace).balance,
            totalLiabilities
        );
    }
    
}
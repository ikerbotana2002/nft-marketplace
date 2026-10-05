// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {NFTMarketplace} from "../src/NFTMarketplace.sol";
import {MockNFT} from "./MockNFT.sol";

contract NFTMarketplaceHandler is Test {
    NFTMarketplace public marketplace;
    MockNFT public nft;

    address public sellerA = address(0xA11CE);
    address public sellerB = address(0xB0B);

    address public buyer = address(0xCAFE);

    uint256 public nextTokenId;

    constructor(
        NFTMarketplace _marketplace,
        MockNFT _nft
    ) {
        marketplace = _marketplace;
        nft = _nft;

        vm.deal(buyer, 1_000_000 ether);
    }

    function createSale(
        uint96 rawPrice,
        bool useSellerA
    ) external {
        uint256 price = bound(
            uint256(rawPrice),
            1,
            100 ether
        );

        address seller =
            useSellerA ? sellerA : sellerB;

        uint256 tokenId = nextTokenId;
        nextTokenId++;

        nft.mint(
            seller,
            tokenId
        );

        vm.startPrank(seller);

        nft.approve(
            address(marketplace),
            tokenId
        );

        marketplace.listNFT(
            address(nft),
            tokenId,
            price
        );

        vm.stopPrank();

        vm.prank(buyer);

        marketplace.buyNFT{value: price}(
            address(nft),
            tokenId
        );
    }

    function withdrawSellerA() external {
        uint256 amount =
            marketplace.proceeds(sellerA);

        if (amount == 0) return;

        vm.prank(sellerA);
        marketplace.withdrawProceeds();
    }

    function withdrawSellerB() external {
        uint256 amount =
            marketplace.proceeds(sellerB);

        if (amount == 0) return;

        vm.prank(sellerB);
        marketplace.withdrawProceeds();
    }

    function withdrawFees() external {
        uint256 amount = marketplace.feesAccrued();

        if (amount == 0) return;

        address marketplaceOwner = marketplace.owner();

        vm.prank(marketplaceOwner);
        marketplace.withdrawFees();
    }
}
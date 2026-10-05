// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {NFTMarketplace} from "../src/NFTMarketplace.sol";
import {MockNFT} from "./MockNFT.sol";

contract NFTMarketplaceTest is Test {
    NFTMarketplace marketplace;
    MockNFT nft;

    address seller = address(0xA11CE);
    address buyer = address(0xB0B);
    address otherUser = address(0xCAFE);

    uint256 constant TOKEN_ID = 0;
    uint256 constant PRICE = 1 ether;

    receive() external payable {}

    function setUp() public {
        marketplace = new NFTMarketplace();
        nft = new MockNFT();

        nft.mint(seller, TOKEN_ID);

        vm.deal(buyer, 10 ether);
    }

    function testSellerCanListNFT() public {
        vm.startPrank(seller);

        nft.approve(address(marketplace), TOKEN_ID);

        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);

        vm.stopPrank();

        (address listingSeller, uint256 listingPrice, bool active) = marketplace.listings(address(nft), TOKEN_ID);

        assertEq(listingSeller, seller);
        assertEq(listingPrice, PRICE);
        assertTrue(active);
    }

    function testBuyerCanBuyNFT() public {
        vm.startPrank(seller);

        nft.approve(address(marketplace), TOKEN_ID);

        marketplace.listNFT(
            address(nft),
            TOKEN_ID,
            PRICE
        );

        vm.stopPrank();

        uint256 sellerBalanceBefore = seller.balance;

        vm.prank(buyer);

        marketplace.buyNFT{value: PRICE}(
            address(nft),
            TOKEN_ID
        );

        uint256 expectedFee = 0.025 ether;
        uint256 expectedSellerProceeds = 0.975 ether;

        // NFT ownership changed
        assertEq(
            nft.ownerOf(TOKEN_ID),
            buyer
        );

        // Seller has NOT received the ETH yet
        assertEq(
            seller.balance,
            sellerBalanceBefore
        );

        // Marketplace accounting
        assertEq(
            marketplace.proceeds(seller),
            expectedSellerProceeds
        );

        assertEq(
            marketplace.feesAccrued(),
            expectedFee
        );

        // The full 1 ETH is physically held by the marketplace
        assertEq(
            address(marketplace).balance,
            PRICE
        );

        (
            ,
            ,
            bool active
        ) = marketplace.listings(
            address(nft),
            TOKEN_ID
        );

        assertFalse(active);
    }

    function testCannotListWithZeroPrice() public {
        vm.startPrank(seller);

        nft.approve(address(marketplace), TOKEN_ID);

        vm.expectRevert(NFTMarketplace.InvalidPrice.selector);

        marketplace.listNFT(address(nft), TOKEN_ID, 0);

        vm.stopPrank();
    }

    function testNonOwnerCannotListNFT() public {
        vm.prank(buyer);

        vm.expectRevert(NFTMarketplace.NotNFTOwner.selector);

        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);
    }

    function testCannotListWithoutMarketplaceApproval() public {
        vm.prank(seller);

        vm.expectRevert(NFTMarketplace.MarketplaceNotApproved.selector);

        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);
    }

    function testCannotListNFTTwice() public {
        vm.startPrank(seller);

        nft.approve(address(marketplace), TOKEN_ID);

        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);

        vm.expectRevert(NFTMarketplace.NFTAlreadyListed.selector);

        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);

        vm.stopPrank();
    }

    function testCannotBuyWithIncorrectETHAmount() public {
        vm.startPrank(seller);

        nft.approve(address(marketplace), TOKEN_ID);

        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);

        vm.stopPrank();

        vm.prank(buyer);

        vm.expectRevert(NFTMarketplace.IncorrectETHAmount.selector);

        marketplace.buyNFT{value: 0.5 ether}(address(nft), TOKEN_ID);
    }

    function testCannotBuyStaleListing() public {
        vm.startPrank(seller);

        nft.approve(address(marketplace), TOKEN_ID);

        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);

        nft.transferFrom(seller, otherUser, TOKEN_ID);

        vm.stopPrank();

        vm.prank(buyer);

        vm.expectRevert(NFTMarketplace.SellerNoLongerOwnsNFT.selector);

        marketplace.buyNFT{value: PRICE}(address(nft), TOKEN_ID);
    }

    function testCannotBuyIfApprovalWasRevoked() public {
        vm.startPrank(seller);

        nft.approve(address(marketplace), TOKEN_ID);

        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);

        nft.approve(address(0), TOKEN_ID);

        vm.stopPrank();

        vm.prank(buyer);

        vm.expectRevert(NFTMarketplace.MarketplaceApprovalRemoved.selector);

        marketplace.buyNFT{value: PRICE}(address(nft), TOKEN_ID);
    }

    function testSellerCanCancelListing() public {
        vm.startPrank(seller);

        nft.approve(address(marketplace), TOKEN_ID);

        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);

        marketplace.cancelListing(address(nft), TOKEN_ID);

        vm.stopPrank();

        (,, bool active) = marketplace.listings(address(nft), TOKEN_ID);

        assertFalse(active);
    }

    function testNonSellerCannotCancelListing() public {
        vm.startPrank(seller);

        nft.approve(address(marketplace), TOKEN_ID);

        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);

        vm.stopPrank();

        vm.prank(buyer);

        vm.expectRevert(NFTMarketplace.NotListingSeller.selector);

        marketplace.cancelListing(address(nft), TOKEN_ID);
    }

    function testSellerCanUpdateListingPrice() public {
        vm.startPrank(seller);

        nft.approve(address(marketplace), TOKEN_ID);

        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);

        uint256 newPrice = 2 ether;

        marketplace.updateListingPrice(address(nft), TOKEN_ID, newPrice);

        vm.stopPrank();

        (address listingSeller, uint256 listingPrice, bool active) = marketplace.listings(address(nft), TOKEN_ID);

        assertEq(listingSeller, seller);
        assertEq(listingPrice, newPrice);
        assertTrue(active);
    }

    function testNonSellerCannotUpdateListingPrice() public {
        vm.startPrank(seller);

        nft.approve(address(marketplace), TOKEN_ID);

        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);

        vm.stopPrank();

        vm.prank(buyer);

        vm.expectRevert(NFTMarketplace.NotListingSeller.selector);

        marketplace.updateListingPrice(address(nft), TOKEN_ID, 2 ether);
    }

    function testCannotUpdateListingPriceToZero() public {
        vm.startPrank(seller);

        nft.approve(address(marketplace), TOKEN_ID);

        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);

        vm.expectRevert(NFTMarketplace.InvalidPrice.selector);

        marketplace.updateListingPrice(address(nft), TOKEN_ID, 0);

        vm.stopPrank();
    }

    function testSellerCanWithdrawProceeds() public {
        vm.startPrank(seller);

        nft.approve(address(marketplace), TOKEN_ID);

        marketplace.listNFT(
            address(nft),
            TOKEN_ID,
            PRICE
        );

        vm.stopPrank();

        vm.prank(buyer);

        marketplace.buyNFT{value: PRICE}(
            address(nft),
            TOKEN_ID
        );

        uint256 sellerBalanceBefore = seller.balance;

        vm.prank(seller);
        marketplace.withdrawProceeds();

        assertEq(
            seller.balance,
            sellerBalanceBefore + 0.975 ether
        );

        assertEq(
            marketplace.proceeds(seller),
            0
        );

        assertEq(
            address(marketplace).balance,
            0.025 ether
        );
    }

    function testOwnerCanWithdrawFees() public {
        vm.startPrank(seller);

        nft.approve(address(marketplace), TOKEN_ID);

        marketplace.listNFT(
            address(nft),
            TOKEN_ID,
            PRICE
        );

        vm.stopPrank();

        vm.prank(buyer);

        marketplace.buyNFT{value: PRICE}(
            address(nft),
            TOKEN_ID
        );

        uint256 ownerBalanceBefore = address(this).balance;

        marketplace.withdrawFees();

        assertEq(
            address(this).balance,
            ownerBalanceBefore + 0.025 ether
        );

        assertEq(
            marketplace.feesAccrued(),
            0
        );

        assertEq(
            address(marketplace).balance,
            0.975 ether
        );
    }

    function testSellerCannotWithdrawProceedsTwice() public {
        vm.startPrank(seller);

        nft.approve(address(marketplace), TOKEN_ID);

        marketplace.listNFT(
            address(nft),
            TOKEN_ID,
            PRICE
        );

        vm.stopPrank();

        vm.prank(buyer);

        marketplace.buyNFT{value: PRICE}(
            address(nft),
            TOKEN_ID
        );

        vm.prank(seller);
        marketplace.withdrawProceeds();

        vm.prank(seller);

        vm.expectRevert(
            NFTMarketplace.NoProceeds.selector
        );

        marketplace.withdrawProceeds();
    }

    function testNonOwnerCannotWithdrawFees() public {
        vm.prank(buyer);

        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                buyer
            )
        );

        marketplace.withdrawFees();
    }


    function testAccountingAfterMultipleSales() public {
        uint256 secondTokenId = 1;
        uint256 secondPrice = 2 ether;

        address secondBuyer = otherUser;

        nft.mint(seller, secondTokenId);

        vm.deal(secondBuyer, 10 ether);

        vm.startPrank(seller);

        nft.approve(
            address(marketplace),
            TOKEN_ID
        );

        nft.approve(
            address(marketplace),
            secondTokenId
        );

        marketplace.listNFT(
            address(nft),
            TOKEN_ID,
            PRICE
        );

        marketplace.listNFT(
            address(nft),
            secondTokenId,
            secondPrice
        );

        vm.stopPrank();

        vm.prank(buyer);

        marketplace.buyNFT{value: PRICE}(
            address(nft),
            TOKEN_ID
        );

        vm.prank(secondBuyer);

        marketplace.buyNFT{value: secondPrice}(
            address(nft),
            secondTokenId
        );

        uint256 expectedFees = 0.075 ether;
        uint256 expectedProceeds = 2.925 ether;

        assertEq(
            marketplace.proceeds(seller),
            expectedProceeds
        );

        assertEq(
            marketplace.feesAccrued(),
            expectedFees
        );

        assertEq(
            address(marketplace).balance,
            3 ether
        );

        assertEq(
            nft.ownerOf(TOKEN_ID),
            buyer
        );

        assertEq(
            nft.ownerOf(secondTokenId),
            secondBuyer
        );
    }
}

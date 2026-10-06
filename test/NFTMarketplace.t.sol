// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ReentrantSeller} from "./ReentrantSeller.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";
import {MockNFT} from "./MockNFT.sol";
import {NonERC721Buyer} from "./NonERC721Buyer.sol";
import {ReentrantBuyer} from "./ReentrantBuyer.sol";
import {RejectingSeller} from "./RejectingSeller.sol";
import {RejectingOwner} from "./RejectingOwner.sol";

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

        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);

        vm.stopPrank();

        uint256 sellerBalanceBefore = seller.balance;

        vm.prank(buyer);

        marketplace.buyNFT{value: PRICE}(address(nft), TOKEN_ID);

        uint256 expectedFee = 0.025 ether;
        uint256 expectedSellerProceeds = 0.975 ether;

        // NFT ownership changed
        assertEq(nft.ownerOf(TOKEN_ID), buyer);

        // Seller has NOT received the ETH yet
        assertEq(seller.balance, sellerBalanceBefore);

        // Marketplace accounting
        assertEq(marketplace.proceeds(seller), expectedSellerProceeds);

        assertEq(marketplace.feesAccrued(), expectedFee);

        // The full 1 ETH is physically held by the marketplace
        assertEq(address(marketplace).balance, PRICE);

        (,, bool active) = marketplace.listings(address(nft), TOKEN_ID);

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

        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);

        vm.stopPrank();

        vm.prank(buyer);

        marketplace.buyNFT{value: PRICE}(address(nft), TOKEN_ID);

        uint256 sellerBalanceBefore = seller.balance;

        vm.prank(seller);
        marketplace.withdrawProceeds();

        assertEq(seller.balance, sellerBalanceBefore + 0.975 ether);

        assertEq(marketplace.proceeds(seller), 0);

        assertEq(address(marketplace).balance, 0.025 ether);
    }

    function testOwnerCanWithdrawFees() public {
        vm.startPrank(seller);

        nft.approve(address(marketplace), TOKEN_ID);

        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);

        vm.stopPrank();

        vm.prank(buyer);

        marketplace.buyNFT{value: PRICE}(address(nft), TOKEN_ID);

        uint256 ownerBalanceBefore = address(this).balance;

        marketplace.withdrawFees();

        assertEq(address(this).balance, ownerBalanceBefore + 0.025 ether);

        assertEq(marketplace.feesAccrued(), 0);

        assertEq(address(marketplace).balance, 0.975 ether);
    }

    function testSellerCannotWithdrawProceedsTwice() public {
        vm.startPrank(seller);

        nft.approve(address(marketplace), TOKEN_ID);

        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);

        vm.stopPrank();

        vm.prank(buyer);

        marketplace.buyNFT{value: PRICE}(address(nft), TOKEN_ID);

        vm.prank(seller);
        marketplace.withdrawProceeds();

        vm.prank(seller);

        vm.expectRevert(NFTMarketplace.NoProceeds.selector);

        marketplace.withdrawProceeds();
    }

    function testNonOwnerCannotWithdrawFees() public {
        vm.prank(buyer);

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", buyer));

        marketplace.withdrawFees();
    }

    function testAccountingAfterMultipleSales() public {
        uint256 secondTokenId = 1;
        uint256 secondPrice = 2 ether;

        address secondBuyer = otherUser;

        nft.mint(seller, secondTokenId);

        vm.deal(secondBuyer, 10 ether);

        vm.startPrank(seller);

        nft.approve(address(marketplace), TOKEN_ID);

        nft.approve(address(marketplace), secondTokenId);

        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);

        marketplace.listNFT(address(nft), secondTokenId, secondPrice);

        vm.stopPrank();

        vm.prank(buyer);

        marketplace.buyNFT{value: PRICE}(address(nft), TOKEN_ID);

        vm.prank(secondBuyer);

        marketplace.buyNFT{value: secondPrice}(address(nft), secondTokenId);

        uint256 expectedFees = 0.075 ether;
        uint256 expectedProceeds = 2.925 ether;

        assertEq(marketplace.proceeds(seller), expectedProceeds);

        assertEq(marketplace.feesAccrued(), expectedFees);

        assertEq(address(marketplace).balance, 3 ether);

        assertEq(nft.ownerOf(TOKEN_ID), buyer);

        assertEq(nft.ownerOf(secondTokenId), secondBuyer);
    }

    function testReentrantSellerCannotWithdrawTwice() public {
        ReentrantSeller attacker = new ReentrantSeller(marketplace);

        uint256 tokenId = 1;

        nft.mint(address(attacker), tokenId);

        vm.prank(address(attacker));
        nft.approve(address(marketplace), tokenId);

        vm.prank(address(attacker));
        marketplace.listNFT(address(nft), tokenId, PRICE);

        vm.prank(buyer);
        marketplace.buyNFT{value: PRICE}(address(nft), tokenId);

        attacker.withdraw();

        assertTrue(attacker.attackAttempted());

        assertFalse(attacker.reentrantCallSucceeded());

        assertEq(marketplace.proceeds(address(attacker)), 0);

        assertEq(address(attacker).balance, 0.975 ether);
    }

    function testPurchaseRevertsIfBuyerCannotReceiveNFT() public {
        NonERC721Buyer badBuyer = new NonERC721Buyer(marketplace);

        vm.deal(address(badBuyer), 10 ether);

        vm.startPrank(seller);

        nft.approve(address(marketplace), TOKEN_ID);

        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);

        vm.stopPrank();

        vm.expectRevert();

        badBuyer.buy{value: PRICE}(address(nft), TOKEN_ID);

        // Everything must have rolled back
        assertEq(nft.ownerOf(TOKEN_ID), seller);

        (,, bool active) = marketplace.listings(address(nft), TOKEN_ID);

        assertTrue(active);

        assertEq(marketplace.proceeds(seller), 0);

        assertEq(marketplace.feesAccrued(), 0);
    }

    function testReentrantBuyerCannotBuyDuringNFTCallback() public {
        ReentrantBuyer attacker = new ReentrantBuyer(marketplace);

        uint256 secondTokenId = 1;

        nft.mint(seller, secondTokenId);

        vm.deal(address(attacker), 10 ether);

        vm.startPrank(seller);

        nft.approve(address(marketplace), TOKEN_ID);

        nft.approve(address(marketplace), secondTokenId);

        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);

        marketplace.listNFT(address(nft), secondTokenId, PRICE);

        vm.stopPrank();

        attacker.configureAttack(address(nft), secondTokenId, PRICE);

        attacker.buy{value: PRICE}(address(nft), TOKEN_ID);

        assertTrue(attacker.attackAttempted());

        assertFalse(attacker.reentrantCallSucceeded());

        // First purchase succeeds
        assertEq(nft.ownerOf(TOKEN_ID), address(attacker));

        // Reentrant second purchase fails
        assertEq(nft.ownerOf(secondTokenId), seller);

        (,, bool secondListingActive) = marketplace.listings(address(nft), secondTokenId);

        assertTrue(secondListingActive);
    }

    function testWithdrawalFailurePreservesProceeds() public {
        RejectingSeller rejectingSeller = new RejectingSeller(marketplace);

        uint256 tokenId = 1;

        nft.mint(address(rejectingSeller), tokenId);

        vm.prank(address(rejectingSeller));
        nft.approve(address(marketplace), tokenId);

        vm.prank(address(rejectingSeller));
        marketplace.listNFT(address(nft), tokenId, PRICE);

        vm.prank(buyer);
        marketplace.buyNFT{value: PRICE}(address(nft), tokenId);

        assertEq(marketplace.proceeds(address(rejectingSeller)), 0.975 ether);

        vm.expectRevert(NFTMarketplace.ETHTransferFailed.selector);

        rejectingSeller.withdraw();

        assertEq(marketplace.proceeds(address(rejectingSeller)), 0.975 ether);
    }

    function testFuzzPurchaseAccounting(uint96 rawPrice) public {
        uint256 price = bound(uint256(rawPrice), 1, 1000 ether);

        vm.startPrank(seller);

        nft.approve(address(marketplace), TOKEN_ID);

        marketplace.listNFT(address(nft), TOKEN_ID, price);

        vm.stopPrank();

        vm.deal(buyer, price);

        vm.prank(buyer);

        marketplace.buyNFT{value: price}(address(nft), TOKEN_ID);

        uint256 expectedFee = (price * marketplace.MARKETPLACE_FEE_BPS()) / marketplace.BPS_DENOMINATOR();

        uint256 expectedSellerProceeds = price - expectedFee;

        assertEq(marketplace.proceeds(seller), expectedSellerProceeds);

        assertEq(marketplace.feesAccrued(), expectedFee);

        assertEq(address(marketplace).balance, price);

        assertEq(marketplace.proceeds(seller) + marketplace.feesAccrued(), price);
    }

    function testSameTokenIdFromDifferentCollectionsAreIndependent() public {
        MockNFT secondNFT = new MockNFT();

        secondNFT.mint(seller, TOKEN_ID);

        vm.startPrank(seller);

        nft.approve(address(marketplace), TOKEN_ID);

        secondNFT.approve(address(marketplace), TOKEN_ID);

        marketplace.listNFT(address(nft), TOKEN_ID, 1 ether);

        marketplace.listNFT(address(secondNFT), TOKEN_ID, 2 ether);

        vm.stopPrank();

        (address firstSeller, uint256 firstPrice, bool firstActive) = marketplace.listings(address(nft), TOKEN_ID);

        (address secondSeller, uint256 secondPrice, bool secondActive) =
            marketplace.listings(address(secondNFT), TOKEN_ID);

        assertEq(firstSeller, seller);
        assertEq(firstPrice, 1 ether);
        assertTrue(firstActive);

        assertEq(secondSeller, seller);
        assertEq(secondPrice, 2 ether);
        assertTrue(secondActive);
    }

    function testBuyerCanRelistPurchasedNFT() public {
        // Seller lists NFT #0
        vm.startPrank(seller);

        nft.approve(address(marketplace), TOKEN_ID);

        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);

        vm.stopPrank();

        // Buyer purchases NFT #0
        vm.prank(buyer);

        marketplace.buyNFT{value: PRICE}(address(nft), TOKEN_ID);

        assertEq(nft.ownerOf(TOKEN_ID), buyer);

        // Buyer is now the owner, so they can approve
        // the marketplace and list the same NFT again
        uint256 newPrice = 2 ether;

        vm.startPrank(buyer);

        nft.approve(address(marketplace), TOKEN_ID);

        marketplace.listNFT(address(nft), TOKEN_ID, newPrice);

        vm.stopPrank();

        (address listingSeller, uint256 listingPrice, bool active) = marketplace.listings(address(nft), TOKEN_ID);

        assertEq(listingSeller, buyer);

        assertEq(listingPrice, newPrice);

        assertTrue(active);
    }

    function testPreviousSellerCannotModifyRelistedNFT() public {
        // Alice lists NFT #0
        vm.startPrank(seller);

        nft.approve(address(marketplace), TOKEN_ID);

        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);

        vm.stopPrank();

        // Bob buys it
        vm.prank(buyer);

        marketplace.buyNFT{value: PRICE}(address(nft), TOKEN_ID);

        // Bob relists it
        vm.startPrank(buyer);

        nft.approve(address(marketplace), TOKEN_ID);

        marketplace.listNFT(address(nft), TOKEN_ID, 2 ether);

        vm.stopPrank();

        // Alice tries to cancel Bob's listing
        vm.prank(seller);

        vm.expectRevert(NFTMarketplace.NotListingSeller.selector);

        marketplace.cancelListing(address(nft), TOKEN_ID);

        // Alice tries to change Bob's price
        vm.prank(seller);

        vm.expectRevert(NFTMarketplace.NotListingSeller.selector);

        marketplace.updateListingPrice(address(nft), TOKEN_ID, 3 ether);
    }

    function testCannotBuyUnlistedNFT() public {
        vm.prank(buyer);

        vm.expectRevert(NFTMarketplace.NFTNotListed.selector);

        marketplace.buyNFT{value: PRICE}(address(nft), TOKEN_ID);
    }

    function testCannotCancelUnlistedNFT() public {
        vm.prank(seller);

        vm.expectRevert(NFTMarketplace.NFTNotListed.selector);

        marketplace.cancelListing(address(nft), TOKEN_ID);
    }

    function testCannotUpdateUnlistedNFT() public {
        vm.prank(seller);

        vm.expectRevert(NFTMarketplace.NFTNotListed.selector);

        marketplace.updateListingPrice(address(nft), TOKEN_ID, 2 ether);
    }

    function testOwnerCannotWithdrawFeesWhenNoneExist() public {
        vm.expectRevert(NFTMarketplace.NoFees.selector);

        marketplace.withdrawFees();
    }

    function testFeeWithdrawalFailurePreservesFees() public {
        RejectingOwner rejectingOwner = new RejectingOwner();

        // Generate marketplace fees with a normal sale
        vm.startPrank(seller);

        nft.approve(address(marketplace), TOKEN_ID);

        marketplace.listNFT(address(nft), TOKEN_ID, PRICE);

        vm.stopPrank();

        vm.prank(buyer);

        marketplace.buyNFT{value: PRICE}(address(nft), TOKEN_ID);

        assertEq(marketplace.feesAccrued(), 0.025 ether);

        // The test contract is currently the marketplace owner.
        // Give ownership to the contract that refuses ETH.
        marketplace.transferOwnership(address(rejectingOwner));

        vm.expectRevert(NFTMarketplace.ETHTransferFailed.selector);

        rejectingOwner.withdrawFees(marketplace);

        // The withdrawal reverted, so feesAccrued
        // must also have been restored.
        assertEq(marketplace.feesAccrued(), 0.025 ether);

        // Seller proceeds + fees are still physically
        // inside the marketplace.
        assertEq(address(marketplace).balance, 1 ether);
    }
}

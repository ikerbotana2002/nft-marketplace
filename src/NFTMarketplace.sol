// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract NFTMarketplace is ReentrancyGuard {
    error InvalidPrice();
    error NotNFTOwner();
    error MarketplaceNotApproved();
    error NFTAlreadyListed();
    error NFTNotListed();
    error IncorrectETHAmount();
    error SellerNoLongerOwnsNFT();
    error MarketplaceApprovalRemoved();
    error NotListingSeller();
    error ETHTransferFailed();

    struct Listing {
        address seller;
        uint256 price;
        bool active;
    }

    mapping(address nft => mapping(uint256 tokenId => Listing)) public listings;

    event NFTListed(address indexed nft, uint256 indexed tokenId, address indexed seller, uint256 price);

    event NFTPurchased(
        address indexed nft, uint256 indexed tokenId, address indexed buyer, address seller, uint256 price
    );

    event ListingCancelled(address indexed nft, uint256 indexed tokenId, address indexed seller);

    event ListingPriceUpdated(address indexed nft, uint256 indexed tokenId, address indexed seller, uint256 newPrice);

    function listNFT(address nft, uint256 tokenId, uint256 price) external {
        if (price == 0) revert InvalidPrice();

        IERC721 nftContract = IERC721(nft);

        if (nftContract.ownerOf(tokenId) != msg.sender) {
            revert NotNFTOwner();
        }

        bool approved = nftContract.getApproved(tokenId) == address(this)
            || nftContract.isApprovedForAll(msg.sender, address(this));

        if (!approved) revert MarketplaceNotApproved();

        if (listings[nft][tokenId].active) {
            revert NFTAlreadyListed();
        }

        listings[nft][tokenId] = Listing({seller: msg.sender, price: price, active: true});

        emit NFTListed(nft, tokenId, msg.sender, price);
    }

    function buyNFT(address nft, uint256 tokenId) external payable nonReentrant {
        Listing storage listing = listings[nft][tokenId];

        if (!listing.active) revert NFTNotListed();

        if (msg.value != listing.price) {
            revert IncorrectETHAmount();
        }

        address seller = listing.seller;
        uint256 price = listing.price;

        IERC721 nftContract = IERC721(nft);

        if (nftContract.ownerOf(tokenId) != seller) {
            revert SellerNoLongerOwnsNFT();
        }

        bool approved =
            nftContract.getApproved(tokenId) == address(this) || nftContract.isApprovedForAll(seller, address(this));

        if (!approved) revert MarketplaceApprovalRemoved();

        listing.active = false;

        emit NFTPurchased(nft, tokenId, msg.sender, seller, price);

        nftContract.safeTransferFrom(seller, msg.sender, tokenId);

        (bool success,) = payable(seller).call{value: price}("");

        if (!success) revert ETHTransferFailed();
    }

    function cancelListing(address nft, uint256 tokenId) external {
        Listing storage listing = listings[nft][tokenId];

        if (!listing.active) revert NFTNotListed();

        if (listing.seller != msg.sender) {
            revert NotListingSeller();
        }

        listing.active = false;

        emit ListingCancelled(nft, tokenId, msg.sender);
    }

    function updateListingPrice(address nft, uint256 tokenId, uint256 newPrice) external {
        if (newPrice == 0) revert InvalidPrice();

        Listing storage listing = listings[nft][tokenId];

        if (!listing.active) revert NFTNotListed();

        if (listing.seller != msg.sender) {
            revert NotListingSeller();
        }

        listing.price = newPrice;

        emit ListingPriceUpdated(nft, tokenId, msg.sender, newPrice);
    }
}

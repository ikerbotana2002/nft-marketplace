// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is ReentrancyGuard, Ownable {
    error InvalidPrice();
    error NotNFTOwner();
    error MarketplaceNotApproved();
    error NFTAlreadyListed();
    error NFTNotListed();
    error IncorrectETHAmount();
    error SellerNoLongerOwnsNFT();
    error MarketplaceApprovalRemoved();
    error NotListingSeller();
    error NoProceeds();
    error NoFees();
    error ETHTransferFailed();

    struct Listing {
        address seller;
        uint256 price;
        bool active;
    }

    uint256 public constant MARKETPLACE_FEE_BPS = 250;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    mapping(address nft => mapping(uint256 tokenId => Listing)) public listings;

    mapping(address seller => uint256 amount) public proceeds;

    uint256 public feesAccrued;

    event NFTListed(
        address indexed nft,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );

    event NFTPurchased(
        address indexed nft,
        uint256 indexed tokenId,
        address indexed buyer,
        address seller,
        uint256 price,
        uint256 fee
    );

    event ListingCancelled(
        address indexed nft,
        uint256 indexed tokenId,
        address indexed seller
    );

    event ListingPriceUpdated(
        address indexed nft,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 newPrice
    );

    event ProceedsWithdrawn(
        address indexed seller,
        uint256 amount
    );

    event FeesWithdrawn(
        address indexed owner,
        uint256 amount
    );

    constructor() Ownable(msg.sender) {}

    function listNFT(
        address nft,
        uint256 tokenId,
        uint256 price
    ) external {
        if (price == 0) revert InvalidPrice();

        IERC721 nftContract = IERC721(nft);

        if (nftContract.ownerOf(tokenId) != msg.sender) {
            revert NotNFTOwner();
        }

        bool approved =
            nftContract.getApproved(tokenId) == address(this) ||
            nftContract.isApprovedForAll(msg.sender, address(this));

        if (!approved) revert MarketplaceNotApproved();

        if (listings[nft][tokenId].active) {
            revert NFTAlreadyListed();
        }

        listings[nft][tokenId] = Listing({
            seller: msg.sender,
            price: price,
            active: true
        });

        emit NFTListed(
            nft,
            tokenId,
            msg.sender,
            price
        );
    }

    function buyNFT(
        address nft,
        uint256 tokenId
    ) external payable nonReentrant {
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
            nftContract.getApproved(tokenId) == address(this) ||
            nftContract.isApprovedForAll(seller, address(this));

        if (!approved) revert MarketplaceApprovalRemoved();

        uint256 fee =
            (price * MARKETPLACE_FEE_BPS) /
            BPS_DENOMINATOR;

        uint256 sellerProceeds = price - fee;

        listing.active = false;

        proceeds[seller] += sellerProceeds;
        feesAccrued += fee;

        emit NFTPurchased(
            nft,
            tokenId,
            msg.sender,
            seller,
            price,
            fee
        );

        nftContract.safeTransferFrom(
            seller,
            msg.sender,
            tokenId
        );
    }

    function cancelListing(
        address nft,
        uint256 tokenId
    ) external {
        Listing storage listing = listings[nft][tokenId];

        if (!listing.active) revert NFTNotListed();

        if (listing.seller != msg.sender) {
            revert NotListingSeller();
        }

        listing.active = false;

        emit ListingCancelled(
            nft,
            tokenId,
            msg.sender
        );
    }

    function updateListingPrice(
        address nft,
        uint256 tokenId,
        uint256 newPrice
    ) external {
        if (newPrice == 0) revert InvalidPrice();

        Listing storage listing = listings[nft][tokenId];

        if (!listing.active) revert NFTNotListed();

        if (listing.seller != msg.sender) {
            revert NotListingSeller();
        }

        listing.price = newPrice;

        emit ListingPriceUpdated(
            nft,
            tokenId,
            msg.sender,
            newPrice
        );
    }

    function withdrawProceeds() external nonReentrant {
        uint256 amount = proceeds[msg.sender];

        if (amount == 0) revert NoProceeds();

        proceeds[msg.sender] = 0;

        (bool success, ) =
            payable(msg.sender).call{value: amount}("");

        if (!success) revert ETHTransferFailed();

        emit ProceedsWithdrawn(
            msg.sender,
            amount
        );
    }

    function withdrawFees() external onlyOwner nonReentrant {
        uint256 amount = feesAccrued;

        if (amount == 0) revert NoFees();

        feesAccrued = 0;

        (bool success, ) =
            payable(owner()).call{value: amount}("");

        if (!success) revert ETHTransferFailed();

        emit FeesWithdrawn(
            owner(),
            amount
        );
    }
}
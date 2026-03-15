// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract NFTMarket is ReentrancyGuard {
    // 上架事件（indexed 仅对查询优化，按需使用）
    event NFTListed(
        address indexed seller,
        address indexed nftContract,
        uint256 indexed tokenId,
        address paymentToken,
        uint256 price
    );

    // 购买事件
    event NFTSold(
        address indexed seller,
        address indexed buyer,
        address indexed nftContract,
        uint256 tokenId,
        address paymentToken,
        uint256 price
    );

    // 上架信息结构体
    struct Listing {
        address seller;
        address paymentToken;
        uint256 price;
        bool isListed;
    }

    // NFT合约 -> TokenID -> 上架信息
    mapping(address => mapping(uint256 => Listing)) public listings;

    /**
     * @dev 上架NFT
     * @param nftContract NFT合约地址
     * @param tokenId NFT代币ID
     * @param paymentToken 定价ERC20代币地址
     * @param price 上架价格（>0）
     */
    function listNFT(
        address nftContract,
        uint256 tokenId,
        address paymentToken,
        uint256 price
    ) external nonReentrant {
        // 基础校验（0.8+ 内置溢出检查，无需SafeMath）
        require(price > 0, "NFTMarket: price must be > 0");
        require(nftContract != address(0) && paymentToken != address(0), "NFTMarket: zero address");
        
        // NFT所有权&授权校验
        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "NFTMarket: not NFT owner");
        require(
            nft.isApprovedForAll(msg.sender, address(this)) || nft.getApproved(tokenId) == address(this),
            "NFTMarket: no approval"
        );
        require(!listings[nftContract][tokenId].isListed, "NFTMarket: already listed");

        // 存储上架信息
        listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            paymentToken: paymentToken,
            price: price,
            isListed: true
        });

        emit NFTListed(msg.sender, nftContract, tokenId, paymentToken, price);
    }

    /**
     * @dev 购买NFT
     * @param nftContract NFT合约地址
     * @param tokenId NFT代币ID
     * @param amount 支付的ERC20数量（必须等于上架价格）
     */
    function buyNFT(
        address nftContract,
        uint256 tokenId,
        uint256 amount
    ) external nonReentrant {
        Listing storage listing = listings[nftContract][tokenId];
        
        // 业务校验
        require(listing.isListed, "NFTMarket: not listed");
        require(listing.seller != msg.sender, "NFTMarket: cannot buy own NFT");
        require(amount == listing.price, "NFTMarket: invalid payment amount");

        // 提取变量减少SLOAD次数（Gas优化）
        address paymentToken = listing.paymentToken;
        address seller = listing.seller;
        uint256 price = listing.price;

        // ERC20转账（买家→卖家）
        bool transferSuccess = IERC20(paymentToken).transferFrom(msg.sender, seller, price);
        require(transferSuccess, "NFTMarket: ERC20 transfer failed");

        // ERC721转账（卖家→买家）
        IERC721(nftContract).safeTransferFrom(seller, msg.sender, tokenId);

        // 下架NFT
        listing.isListed = false;

        emit NFTSold(seller, msg.sender, nftContract, tokenId, paymentToken, price);
    }

    /**
     * @dev 查询上架信息
     */
    function getListing(address nftContract, uint256 tokenId) external view returns (Listing memory) {
        return listings[nftContract][tokenId];
    }
}
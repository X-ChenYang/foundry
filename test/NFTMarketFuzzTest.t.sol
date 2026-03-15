// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Test.sol";
import "./NFTMarketTest.t.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTMarketFuzzTest is NFTMarketTest {
    function testFuzz_ListAndBuyNFT(uint256 price, address randomBuyer) public {
        price = bound(price, 0.01 ether, 10000 ether);
        vm.assume(randomBuyer != address(0));
        vm.assume(randomBuyer != SELLER);

        // 上架NFT
        vm.prank(SELLER);
        vm.expectEmit(true, true, true, true, address(market));
        emit NFTMarket.NFTListed(SELLER, address(nft), NFT_TOKEN_ID, address(paymentToken), price);
        market.listNFT(address(nft), NFT_TOKEN_ID, address(paymentToken), price);

        // 买家铸币 + 授权
        paymentToken.mint(randomBuyer, price);
        vm.prank(randomBuyer);
        paymentToken.approve(address(market), price);
        assertEq(paymentToken.allowance(randomBuyer, address(market)), price);

        // 购买NFT（修复事件监听顺序）
        vm.prank(randomBuyer);
        vm.expectEmit(true, true, false, true, address(paymentToken));
        emit IERC20.Transfer(randomBuyer, SELLER, price);
        vm.expectEmit(true, true, false, true, address(nft));
        emit IERC721.Transfer(SELLER, randomBuyer, NFT_TOKEN_ID);
        vm.expectEmit(true, true, true, true, address(market));
        emit NFTMarket.NFTSold(SELLER, randomBuyer, address(nft), NFT_TOKEN_ID, address(paymentToken), price);
        
        market.buyNFT(address(nft), NFT_TOKEN_ID, price);

        // 断言
        assertEq(nft.ownerOf(NFT_TOKEN_ID), randomBuyer);
        assertEq(paymentToken.balanceOf(SELLER), price);
        assertEq(paymentToken.balanceOf(address(market)), 0);
    }
}
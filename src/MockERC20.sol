// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/NFTMarket.sol"; // 导入市场合约，用于校验

contract MockERC20 is IERC20 {
    string public constant name = "TestToken";
    string public constant symbol = "TT";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // 禁止铸造到市场合约（核心修复）
    address public immutable NFT_MARKET_ADDRESS;
    constructor(address _marketAddress) {
        NFT_MARKET_ADDRESS = _marketAddress;
    }

    function mint(address to, uint256 amount) external {
        // 关键：禁止铸造代币到NFTMarket合约
        require(to != NFT_MARKET_ADDRESS, "MockERC20: cannot mint to market");
        require(to != address(0), "MockERC20: zero address");
        
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "MockERC20: insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(allowance[from][msg.sender] >= amount, "MockERC20: allowance exceeded");
        require(balanceOf[from] >= amount, "MockERC20: insufficient balance");
        
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.33;

import "forge-std/Test.sol";
import "../src/Bank.sol";

contract BankTest is Test {
    Bank public bank;
    address public admin = address(this); // 测试合约作为管理员
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);
    address public user4 = address(0x4);
       // ✅ 关键修复：添加接收ETH的函数，允许测试合约接收转账
    receive() external payable {}

    // 部署合约（每个测试前执行）
    function setUp() public {
        bank = new Bank();
        // 给测试用户转ETH
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
        vm.deal(user4, 100 ether);
    }

    // ========== 测试用例1：存款前后余额更新 ==========
    function testDepositBalanceUpdate() public {
        // 初始余额为0
        assertEq(bank.balances(user1), 0);

        // user1 存款 10 ETH
        vm.prank(user1);
        bank.deposit{value: 10 ether}();

        // 断言余额更新正确
        assertEq(bank.balances(user1), 10 ether);

        // user1 再次存款 5 ETH
        vm.prank(user1);
        bank.deposit{value: 5 ether}();

        // 断言累计余额正确
        assertEq(bank.balances(user1), 15 ether);
    }

    // ========== 测试用例2：存款排行榜（1个用户） ==========
    function testTopDepositors_1User() public {
        // user1 存款 10 ETH
        vm.prank(user1);
        bank.deposit{value: 10 ether}();

        // 获取前1名
        (address[] memory topUsers, uint256[] memory topAmounts) = bank.getTopDepositors(1);
        assertEq(topUsers.length, 1);
        assertEq(topUsers[0], user1);
        assertEq(topAmounts[0], 10 ether);
    }

    // ========== 测试用例3：存款排行榜（2个用户） ==========
    function testTopDepositors_2Users() public {
        // user1 存款 10 ETH，user2 存款 20 ETH
        vm.prank(user1);
        bank.deposit{value: 10 ether}();
        vm.prank(user2);
        bank.deposit{value: 20 ether}();

        // 获取前2名
        (address[] memory topUsers, uint256[] memory topAmounts) = bank.getTopDepositors(2);
        assertEq(topUsers.length, 2);
        assertEq(topUsers[0], user2); // 金额更高的排第一
        assertEq(topAmounts[0], 20 ether);
        assertEq(topUsers[1], user1);
        assertEq(topAmounts[1], 10 ether);
    }

    // ========== 测试用例4：存款排行榜（3个用户） ==========
    function testTopDepositors_3Users() public {
        // user1:10, user2:20, user3:15 ETH
        vm.prank(user1);
        bank.deposit{value: 10 ether}();
        vm.prank(user2);
        bank.deposit{value: 20 ether}();
        vm.prank(user3);
        bank.deposit{value: 15 ether}();

        // 获取前3名
        (address[] memory topUsers, uint256[] memory topAmounts) = bank.getTopDepositors(3);
        assertEq(topUsers.length, 3);
        assertEq(topUsers[0], user2); // 20 ETH
        assertEq(topUsers[1], user3); // 15 ETH
        assertEq(topUsers[2], user1); // 10 ETH
        assertEq(topAmounts[0], 20 ether);
        assertEq(topAmounts[1], 15 ether);
        assertEq(topAmounts[2], 10 ether);
    }

    // ========== 测试用例5：存款排行榜（4个用户 + 重复存款） ==========
    function testTopDepositors_4Users_RepeatDeposit() public {
        // 初始存款：user1(10), user2(20), user3(15), user4(25)
        vm.prank(user1);
        bank.deposit{value: 10 ether}();
        vm.prank(user2);
        bank.deposit{value: 20 ether}();
        vm.prank(user3);
        bank.deposit{value: 15 ether}();
        vm.prank(user4);
        bank.deposit{value: 25 ether}();

        // 获取前3名（user4>user2>user3，user1被淘汰）
        (address[] memory topUsers1, ) = bank.getTopDepositors(3);
        assertEq(topUsers1[0], user4);
        assertEq(topUsers1[1], user2);
        assertEq(topUsers1[2], user3);
       

        // user1 重复存款 20 ETH（累计30 ETH），超过所有人
        vm.prank(user1);
        bank.deposit{value: 20 ether}();

        // 重新获取前3名（user1>user4>user2）
        (address[] memory topUsers2, uint256[] memory topAmounts2) = bank.getTopDepositors(3);
        assertEq(topUsers2[0], user1);
        assertEq(topAmounts2[0], 30 ether);
        assertEq(topUsers2[1], user4);
        assertEq(topAmounts2[1], 25 ether);
        assertEq(topUsers2[2], user2);
        assertEq(topAmounts2[2], 20 ether);
    }

    // ========== 测试用例6：管理员可取款 ==========
    function testAdminWithdraw() public {
        // 先存款到合约
        vm.prank(user1);
        bank.deposit{value: 10 ether}();
        assertEq(address(bank).balance, 10 ether);

        // 管理员取款 5 ETH
        uint256 adminBefore = address(admin).balance;
        bank.withdraw(5 ether);
        uint256 adminAfter = address(admin).balance;

        // 断言取款成功
        assertEq(adminAfter - adminBefore, 5 ether);
        assertEq(address(bank).balance, 5 ether);
    }

    // ========== 测试用例7：非管理员不可取款 ==========
    function testNonAdminCannotWithdraw() public {
        // 先存款到合约
        vm.prank(user1);
        bank.deposit{value: 10 ether}();

        // 模拟user1（非管理员）取款，预期失败
        vm.prank(user1);
        vm.expectRevert("Bank: not admin");
        bank.withdraw(5 ether);

        // 合约余额不变
        assertEq(address(bank).balance, 10 ether);
    }
}
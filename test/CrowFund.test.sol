//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from 'forge-std/Test.sol';
import {CrowdFund} from '../src/CrowdFund.sol';
import {MockERC20} from './mocks/MockERC20.sol';
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Reward} from "../src/Reward.sol";
import {ICrowdFund} from "../src/interfaces/ICrowdFund.sol";
import {RefundModule} from "../src/RefundModule.sol";
import {TimeLock} from "../src/TimeLock.sol";
import { TestAvatar } from "@zodiac/test/TestAvatar.sol";
import {console2} from "forge-std/console2.sol";

contract CrowdFundTest is Test {

    CrowdFund crowdFund;
    Reward reward;
    TimeLock timeLock;
    TestAvatar safe;
    RefundModule rModule;
    MockERC20 asset;

    //Addesses for interacting with the contract
    address crowdFundOwner = makeAddr('crowdfundowner');
    address platformOwner = makeAddr('platformowner');
    address supporter1 = makeAddr('supporter1');
    address supporter2 = makeAddr('supporter2');
    address supporter3 = makeAddr('supporter3');

    //constant target value for crowdfund
    uint256 target = 100 ether;


    function setUp() public {
        asset = new MockERC20();

        vm.startPrank(platformOwner);
        safe = new TestAvatar();
        crowdFund = new CrowdFund(IERC20(asset), crowdFundOwner, target, "CrowdShare", "CS");
        crowdFund.transferOwnership(address(safe));
    
        reward = new Reward(ICrowdFund(address(crowdFund)), crowdFundOwner, "Reward Token", "RT");

        timeLock = new TimeLock(
            address(safe), address(safe), uint64(block.timestamp), uint64(block.timestamp) + 1 weeks
        );
        rModule = new RefundModule(address(timeLock), address(crowdFund));
        safe.enableModule(address(timeLock));
        timeLock.enableModule(address(rModule));
        timeLock.transferOwnership(address(safe));

        vm.stopPrank();

        asset.mint(supporter1, 100 ether);
        asset.mint(supporter2, 100 ether);
        
        vm.prank(supporter1);
        asset.approve(address(crowdFund), type(uint256).max);

        vm.prank(supporter2);
        asset.approve(address(crowdFund), type(uint256).max);
    }

    function test__CrowdFundOwnerShouldBeSetProperly() public {
        assertEq(crowdFund.i_crowdFundOwner(), crowdFundOwner);
    }

    function test__PlatformOwnerShouldBeSetProperly() public {
        assertEq(crowdFund.i_platformOwner(), platformOwner);
    }

    function test__SupporterDeposit() public {
        uint256 balanceOfSupporterAssetBefore = asset.balanceOf(supporter1);

        uint256 balanceOfSupporterShareBefore = crowdFund.balanceOf(supporter1);
        uint256 amountToDeposit = 10 ether;

        vm.prank(supporter1);
        uint256 shares = crowdFund.deposit(amountToDeposit, supporter1);

        uint256 balanceOfFundAssetAfter = crowdFund.totalAssets();
        uint256 balanceOfSupporterAssetAfter = asset.balanceOf(supporter1);
        uint256 totalSharesOfFund = crowdFund.totalSupply();
        uint256 balanceOfSupporterShareAfter = crowdFund.balanceOf(supporter1);

        assertEq(balanceOfFundAssetAfter, amountToDeposit);
        assertEq(balanceOfSupporterAssetAfter, balanceOfSupporterAssetBefore - amountToDeposit);

        assertEq(balanceOfSupporterShareBefore + shares, balanceOfSupporterShareAfter);
        assertEq(amountToDeposit, shares);
        assertEq(shares, totalSharesOfFund);
    }

    function test__CrowdFundOwnerWithdraw() public {
        //Supporter deposits 100 ether reaching the target amount
        vm.prank(supporter1);
        crowdFund.deposit(100 ether, supporter1);

        uint256 balanceOfFundAssetBeforeWithdraw = asset.balanceOf(address(crowdFund));

        vm.warp(block.timestamp + 1 weeks + 1);
        vm.prank(crowdFundOwner);
        rModule.withdrawFunds();

        uint256 balanceOfFundAssetAfterWithdraw = asset.balanceOf(address(crowdFund));
        uint256 balanceOfAssetCrowdFundOwner = asset.balanceOf(crowdFundOwner);
        uint256 platformFeeAmount = asset.balanceOf(platformOwner);

        assertEq(balanceOfFundAssetAfterWithdraw, 0);
        assertEq(balanceOfAssetCrowdFundOwner, balanceOfFundAssetBeforeWithdraw - platformFeeAmount);
    }

    function test__CrowdFundWithdrawRevertIfTargetNotReached() public {
        //Supporter deposits 100 ether reaching the target amount
        vm.prank(supporter1);
        crowdFund.deposit(90 ether, supporter1);

        vm.warp(block.timestamp + 1 weeks + 1);
        vm.prank(crowdFundOwner);
        vm.expectRevert(CrowdFund.CrowdFund__TargetNotReached.selector);
        rModule.withdrawFunds();
    }

    function test__CrowdFundWithdrawRevertIfEndtimeNotReached() public {
        //Supporter deposits 100 ether reaching the target amount
        vm.prank(supporter1);
        crowdFund.deposit(100 ether, supporter1);

        vm.prank(crowdFundOwner);
        vm.expectRevert(TimeLock.TransactionsTimelocked.selector);
        rModule.withdrawFunds();
    }

    function test__WithdrawFundShouldCollectPlatformFee() public {
        //Supporter deposits 100 ether reaching the target amount
        vm.prank(supporter1);
        crowdFund.deposit(100 ether, supporter1);

        uint256 balanceOfPlatformOwnerAssetBeforeWithdraw = asset.balanceOf(platformOwner);

        vm.warp(block.timestamp + 1 weeks + 1);
        vm.prank(crowdFundOwner);
        rModule.withdrawFunds();

        uint256 balanceOfPlatformOwnerAssetAfterWithdraw = asset.balanceOf(platformOwner);
        uint256 feeToBeCollected = (100 ether * 150) / 10000;

        assertEq(balanceOfPlatformOwnerAssetAfterWithdraw, balanceOfPlatformOwnerAssetBeforeWithdraw + feeToBeCollected);
    }

    function test__RefundRevertOnTimeLock() public {
        vm.startPrank(supporter1);
        crowdFund.deposit(10 ether, supporter1);

        vm.expectRevert(TimeLock.TransactionsTimelocked.selector);
        rModule.refund(10 ether, supporter1, supporter1);
    }

    function test__RefundSuccess() public {
        vm.startPrank(supporter1);
        uint256 initialBalance = asset.balanceOf(supporter1);
        crowdFund.deposit(10 ether, supporter1);

        vm.warp(block.timestamp + 1 weeks + 1);
        crowdFund.approve(address(safe), type(uint256).max);
        rModule.refund(10 ether, supporter1, supporter1);

        uint256 balanceOfAssetAfterWithdraw = asset.balanceOf(supporter1);
        uint256 balanceOfAssetOfFundAfterWithdraw = asset.balanceOf(address(crowdFund));

        assertEq(balanceOfAssetAfterWithdraw, initialBalance);
        assertEq(balanceOfAssetOfFundAfterWithdraw, 0);
    }

    function test__RefundRevertIfTargetReached() public {
        vm.startPrank(supporter1);
        crowdFund.deposit(100 ether, supporter1);

        vm.warp(block.timestamp + 1 weeks + 1);
        crowdFund.approve(address(safe), type(uint256).max);

        vm.expectRevert(CrowdFund.CrowdFund__OperationNotAllowed.selector);
        rModule.refund(100 ether, supporter1, supporter1);
    }

    function test__DistributeReward() public {
        //supporter1 deposits 10 ether
        vm.prank(supporter1);
        crowdFund.deposit(10 ether, supporter1);

        //supporter2 deposits 89.5 ether
        vm.prank(supporter2);
        crowdFund.deposit(89.5 ether, supporter2);

        //supporter3 deposits 0.5 ether
        vm.prank(supporter2);
        crowdFund.deposit(0.5 ether, supporter2);

        address[] memory receivers = new address[](3);
        receivers[0] = supporter1;
        receivers[1] = supporter2;
        receivers[2] = supporter3;

        vm.prank(crowdFundOwner);
        reward.distributeReward(receivers);

        assertEq(reward.balanceOf(supporter1), 1); //Should recieve token
        assertEq(reward.balanceOf(supporter2), 1); //Should receive token
        assertEq(reward.balanceOf(supporter3), 0); //Shouuld not recieve token
    }
}
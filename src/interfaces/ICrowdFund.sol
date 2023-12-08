//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface ICrowdFund {
    function totalAssets() external view returns (uint256);
    function balanceOf(address user) external view returns(uint256);
    function crowdFundOwner() external view returns(address);
}
//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ICrowdFund} from "./interfaces/ICrowdFund.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Reward
 * @author Krishnakumarskr
 * @notice Contract to handle and distribute ERC721 reward tokens to share holders
 */
contract Reward is ERC721, Ownable {

    ICrowdFund private immutable i_crowdFund;
    uint256 private constant MIN_SHARE = 1 ether;

    uint256 counter;

    constructor(ICrowdFund _crowdFund, address _owner, string memory _rewardTokenName, string memory _rewardTokenSymbol)
        ERC721(_rewardTokenName, _rewardTokenSymbol)
        Ownable(_owner)
    {
        i_crowdFund = _crowdFund;
    }

    /**
     * @notice - Function to distribute rewards to the shares holders who are holding greater than 1 share
     * @param receivers - The array of recievers address to recieve ERC721 tokens
     */
    function distributeReward(address[] calldata receivers) external onlyOwner {
        for(uint i = 0; i < receivers.length; i++) {
            if(i_crowdFund.balanceOf(receivers[i]) >= MIN_SHARE) {
                _mint(receivers[i], ++counter);
            }
        }
    }
}
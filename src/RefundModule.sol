//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Module, Enum} from "@zodiac/core/Module.sol";
import {CrowdFund} from "./CrowdFund.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

/**
 * @title RefundModule
 * @author Krishnakumarskr
 * @notice Contract to handle all crowdfund withdraw funds operation
 */
contract RefundModule is Module {
    address public crowdFund;

    constructor(address _owner, address _crowdFund) {
        bytes memory initializeParams = abi.encode(_owner, _crowdFund);
        setUp(initializeParams);
    }

    function setUp(bytes memory initializeParams) public override initializer {
        __Ownable_init(_msgSender());

        (address _owner, address _crowdFund) = abi.decode(initializeParams, (address, address));

        crowdFund = _crowdFund;
        setAvatar(_owner);
        setTarget(_owner);
        transferOwnership(_owner);
    }

    /**
     * @notice - A function for the supporters to get refund of the tokens if target not reached
     * 
     * @param shares No.of shares to get refund of asset
     * @param receiver - The receiver address of asset
     * @param owner - The owner address of shares
     */
    function refund(uint256 shares, address receiver, address owner)  external returns (uint256) {
        (bool success, bytes memory data) = execAndReturnData(
            crowdFund, 0, abi.encodeWithSelector(ERC4626.redeem.selector, shares, receiver, owner), Enum.Operation.Call
        );
        if(success)
            return abi.decode(data, (uint256));
        
        if(success == false) {
            assembly {
                revert(add(data,32),mload(data))
            }
        }
        return 0;
    }

    /**
     * @notice - Function to withdraw funds to the crowdfund owner
     */
    function withdrawFunds() external {
       (bool success, bytes memory data) = execAndReturnData(
            crowdFund, 0, abi.encodeWithSelector(CrowdFund.withdrawFunds.selector), Enum.Operation.Call
        );

        if (success == false) {
            assembly {
                revert(add(data,32),mload(data))
            }
        }
    }
}
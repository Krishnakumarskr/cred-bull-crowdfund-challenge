//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {console2} from "forge-std/console2.sol";

/**
 * @title CrowdFund
 * @author Krishnakumarskr
 * @notice It's the crowdfund contract used to raise funds from the supporters of any ERC20 token specified by the crowdfund owner.
 */
contract CrowdFund is ERC4626, Ownable {

    error CrowdFund__OperationNotAllowed();
    error CrowdFund__NotACrowdFundOwner();
    error CrowdFund__TargetNotReached();
    error CrowdFund__CrowdFundNotEndedYet();

    uint256 public immutable i_targetAmount; // The target amount to collect from the crowdfund
    address public immutable i_crowdFundOwner; // The owner address of the crowdfund
    address public immutable i_platformOwner; // The platform owner address

    // Constant platform fee to collection on withdrawing funds
    // 100% = 100_00 to support decimals upto two digits.
    // Here, 1_50 is 1.5%
    uint8 public constant PLATFORM_FEE = 1_50;

    //Maximum fee percentage value to calculate the fee amount
    uint16 public constant MAX_FEE = 100_00;

    //Modifier for crowd fund onwer only functions
    modifier onlyCrowdFundOwner() {
        if(_msgSender() != i_crowdFundOwner) {
            revert CrowdFund__NotACrowdFundOwner();
        }
        _;
    }

    /**
     * @param _asset - The address of the ERC20 token to raise from the crowdfund
     * @param _crowdFundOwner - The address of the crowd fund owner
     * @param _target - The target amount to reach
     * @param _shareTokenName - The name of the share token supporters get on depositing the asset token
     * @param _shareTokenSymbol - The symbol for the share token
     */
    constructor(IERC20 _asset, address _crowdFundOwner, uint256 _target, string memory _shareTokenName, string memory _shareTokenSymbol)
        ERC4626(_asset)
        ERC20(_shareTokenName, _shareTokenSymbol)
        Ownable(_msgSender())
    {
        i_targetAmount = _target;
        i_crowdFundOwner = _crowdFundOwner;
        i_platformOwner = _msgSender();
    }

    /**
     * @notice - Function for the supporters to deposit the asset to the contract
     * 
     * @param assetAmount - Total amount of asset to deposit
     * @param receiver - The address of the person who receive the share token
     */
    function deposit(uint256 assetAmount, address receiver) public override returns (uint256) {
        uint256 maxAssets = maxDeposit(receiver);
        if (assetAmount > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assetAmount, maxAssets);
        }

        uint256 shares = previewDeposit(assetAmount);
        _deposit(_msgSender(), receiver, assetAmount, shares);

        return shares;
    }

    /**
     * @notice - Function to withdraw the collected funds only if target is reached
     */
    function withdrawFunds() public onlyOwner {
        uint256 totalAssetsCollected = totalAssets();

        if(totalAssetsCollected >= i_targetAmount) {
            uint256 totalFee = (totalAssetsCollected * PLATFORM_FEE) / MAX_FEE;
            SafeERC20.safeTransfer(IERC20(asset()), i_platformOwner, totalFee);
            SafeERC20.safeTransfer(IERC20(asset()), i_crowdFundOwner, totalAssetsCollected - totalFee);
        } else {
            revert CrowdFund__TargetNotReached();
        }
    }

    /**
     * @notice - Function to redeem asset for the shares. Can be called only if target is not achieved and end time is reached
     * 
     * @param shares - The no.of shares to redeem
     * @param receiver - The receiver address of the assets
     * @param owner - The owner fo the shares
     */
    function redeem(uint256 shares, address receiver, address owner) public onlyOwner override returns (uint256) {
        uint256 totalAssetsCollected = totalAssets();

        if(totalAssetsCollected >= i_targetAmount) {
            revert CrowdFund__OperationNotAllowed();
        }

        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        uint256 assets = previewRedeem(shares);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return assets;
    }

    /**
     * @notice - Reverting the default public functions of ERC4626 to prevent minting shares
     */
    function mint(uint256 shares, address receiver) public override returns (uint256) {
        revert CrowdFund__OperationNotAllowed();
    }

    /**
     * @notice - Reverting the default public functions of ERC4626 to prevent withdrawing assets
     */
    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256) {
        revert CrowdFund__OperationNotAllowed();
    }
}
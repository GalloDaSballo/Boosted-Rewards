// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;


import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {RewardsManager} from "@badger/RewardsManager.sol";
import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";


/// @title BoostedBoostedRewardsManager
/// @author Alex the Entreprenerd @ BadgerDAO
/// @notice CREDIT
/// Most of the code is inspired by:
/// AAVE STAKE V2
/// COMPOUND
/// INVERSE.FINANCE Dividend Token
/// Pool Together V4
/// Convex Locker (Boost and Locking Mechanic) vlCVX
/// About the architecture
/// See https://github.com/GalloDaSballo/badger-onchain-rewards
/// About boosting
/// TODO
contract BoostedRewardsManager is RewardsManager {
    using SafeERC20 for IERC20;

    /** NEW CODE - BostedRewardsManager */
    // First week of locking is grace period and doesn't count
    // Lock lasts for
    uint256 LOCK_DURATION = 16; // Lock lasts 16 epochs
    uint256 SEIZE_INCENTIVE_PER_EPOCH = 100; // 1% per epoch
    // After the duration lock can be claimed on expiry epoch only by user
    // Each epoch after the expiration, the lock can be unlocked by anyone, and they receive a fee that increases
    mapping(address => mapping(address => uint256)) public lastLockUpdate; // lastLockUpdate[token][user] returns epochId in which it was updated
    mapping(address => mapping(address => uint256)) public userLock; // userLock[token][user] returns epochId in which it expires
    mapping(uint256 => mapping(address => mapping(address => uint256))) public userLocked; // userLocked[epochId][tokenAddress][user] // Amount locked by user
    mapping(uint256 => mapping(address => uint256)) public totalLocked; // totalLocked[epochId][tokenAddress] // Sum of locked amounts by all users at epoch, the current one should correspond with the token.balanceOf(address(this))

    // boostedReward[epochId][vault] // Returns a Struct (rule, amount) rule -> keccak to allow summing it up
    // Technicall you don't need to store the rule, can just store the keccak and use that to determine the math
    // There is a non-zero chance of clashin which would cause issues
    /** END NEW CODE - BostedRewardsManager */

    function lock(address token, uint256 amount) external {
        uint256 cachedCurrentEpoch = currentEpoch;

        // Receive the token
        // Check change in balance to support `feeOnTransfer` tokens as well
        uint256 startBalance = IERC20(token).balanceOf(address(this));  
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 endBalance = IERC20(token).balanceOf(address(this));

        
        // Increase the balance
        userLocked[cachedCurrentEpoch][token][msg.sender] += endBalance - startBalance;

        lastLockUpdate[token][msg.sender] = cachedCurrentEpoch;

        // Update the lock
        userLock[token][msg.sender] = cachedCurrentEpoch + LOCK_DURATION;
    }

    function unlock(address token) external {
        uint256 cachedCurrentEpoch = currentEpoch;

        // Check if expired
        uint256 expiryEpoch = userLock[token][msg.sender];
        require(expiryEpoch <= cachedCurrentEpoch);

        // Get the balance

        // Unlock

        // Reduce the balance
    }

    function seizeLock(address user) external {
        // Seize a user lock, unlock for them and receive a caller incentive
    }


    /// TODO: Similar to getBalanceAtEpoch
    /// Biggest difference is with locking, balance changes only on relocking or on unlocking
    /// So balance is only ported over when a change happens
    function getLockedAmountAtEpoch(uint256 epochId, address vault, address user) public view returns (uint256, bool) {
        // Time Last Known Balance has changed
        uint256 lastBalanceChangeTime = lastUserAccrueTimestamp[epochId][vault][user];
        uint256 lastBalanceChangeEpoch = 0; // We haven't found it

        // Optimistic Case, lastUserAccrueTimestamp for this epoch is nonZero, 
        // Because non-zero means we already found the balance, due to invariant, the balance is correct for this epoch
        // return this epoch balance
        if(lastBalanceChangeTime > 0) {
            return (shares[epochId][vault][user], false);
        }
        

        // Pessimistic Case, we gotta fetch the balance from the lastKnown Balances (could be up to currentEpoch - totalEpochs away)
        // Because we have lastUserAccrueTimestamp, let's find the first non-zero value, that's the last known balance
        // Notice that the last known balance we're looking could be zero, hence we look for a non-zero change first
        for(uint256 i = epochId; i > 0; i--){
            // NOTE: We have to loop because while we know the length of an epoch 
            // we don't have a guarantee of when it starts

            if(lastUserAccrueTimestamp[i][vault][user] != 0) {
                lastBalanceChangeEpoch = i;
                break; // Found it
            }
        }

        // Balance Never changed if we get here, it's their first deposit, return 0
        if(lastBalanceChangeEpoch == 0) {
            return (0, false); // We don't need to update the cachedBalance, the accrueTimestamp will be updated though
        }


        // We found the last known balance given lastUserAccrueTimestamp
        // Can still be zero
        uint256 lastKnownBalance = shares[lastBalanceChangeEpoch][vault][user];

        return (lastKnownBalance, true); // We should update the balance
    }
}
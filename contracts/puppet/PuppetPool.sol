// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../DamnValuableToken.sol";
import 'hardhat/console.sol';

/**
 * @title PuppetPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract PuppetPool is ReentrancyGuard {

    using Address for address payable;

    uint256 public constant DEPOSIT_FACTOR = 2;

    mapping(address => uint256) public deposits;
    address public immutable uniswapPair;
    DamnValuableToken public immutable token;

    error NotEnoughCollateral();
    error TransferFailed();
    
    event Borrowed(address indexed account, uint256 depositRequired, uint256 borrowAmount);

    constructor (address tokenAddress, address uniswapPairAddress) {
        token = DamnValuableToken(tokenAddress);
        uniswapPair = uniswapPairAddress;
    }

    // Allows borrowing `borrowAmount` of tokens by first depositing two times their value in ETH
    function borrow(uint256 borrowAmount) public payable nonReentrant {
        uint256 depositRequired = calculateDepositRequired(borrowAmount);
        
        // require(msg.value >= depositRequired, "Not depositing enough collateral");
        if (msg.value < depositRequired) {
            revert NotEnoughCollateral();
        }

        if (msg.value > depositRequired) {
            // return back to the borrower the extra amount
            payable(msg.sender).sendValue(msg.value - depositRequired);
        }
        
        deposits[msg.sender] = deposits[msg.sender] + depositRequired;    

        // Fails if the pool doesn't have enough tokens in liquidity
        // require(token.transfer(msg.sender, borrowAmount), "Transfer failed");
        if (!token.transfer(msg.sender, borrowAmount)) {
            revert TransferFailed();
        }

        emit Borrowed(msg.sender, depositRequired, borrowAmount);
    }

    // calculate the amount of eth required to borrow `amount` of tokens
    function calculateDepositRequired(uint256 amount) public view returns (uint256) {
        // amount = token amount
        // _computeOraclePrice() = price of 1 token in wei
        // 10 ** 18 -> convert back to ether from wei
        console.log('_computeOraclePrice()', _computeOraclePrice());
        return amount * _computeOraclePrice() * DEPOSIT_FACTOR / 10 ** 18;
    }

    // function _computeOraclePrice() private view returns (uint256) {
    function _computeOraclePrice() public view returns (uint256) {
        // calculates the price of the token in wei according to Uniswap pair
        // uniswapPair.balance = amount of ETH held by the Uniswap pair
        // token.balanceOf(uniswapPair) = amount of DVT tokens held by the Uniswap pair
        // returns the price of 1 token in wei
        // if token balance > eth balance, this returns 0
        return uniswapPair.balance * (10 ** 18) / token.balanceOf(uniswapPair);
    }

     /**
     ... functions to deposit, redeem, repay, calculate interest, and so on ...
     */

}

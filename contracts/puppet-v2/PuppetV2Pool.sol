// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "@uniswap/v2-periphery/contracts/libraries/SafeMath.sol";
import 'hardhat/console.sol';

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external returns (uint256);
}

/**
 * @title PuppetV2Pool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract PuppetV2Pool {
    using SafeMath for uint256;

    address private _uniswapPair;
    address private _uniswapFactory;
    IERC20 private _token;
    IERC20 private _weth;
    
    mapping(address => uint256) public deposits;
        
    event Borrowed(address indexed borrower, uint256 depositRequired, uint256 borrowAmount, uint256 timestamp);

    constructor (
        address wethAddress,
        address tokenAddress,
        address uniswapPairAddress,
        address uniswapFactoryAddress
    ) public {
        _weth = IERC20(wethAddress);
        _token = IERC20(tokenAddress);
        _uniswapPair = uniswapPairAddress;
        _uniswapFactory = uniswapFactoryAddress;
    }

    /**
     * @notice Allows borrowing `borrowAmount` of tokens by first depositing three times their value in WETH
     *         Sender must have approved enough WETH in advance.
     *         Calculations assume that WETH and borrowed token have same amount of decimals.
     */
    function borrow(uint256 borrowAmount) external {
        require(_token.balanceOf(address(this)) >= borrowAmount, "Not enough token balance");

        // Calculate how much WETH the user must deposit
        uint256 depositOfWETHRequired = calculateDepositOfWETHRequired(borrowAmount);
        
        // Take the WETH
        _weth.transferFrom(msg.sender, address(this), depositOfWETHRequired);

        // internal accounting
        deposits[msg.sender] += depositOfWETHRequired;

        require(_token.transfer(msg.sender, borrowAmount));

        emit Borrowed(msg.sender, depositOfWETHRequired, borrowAmount, block.timestamp);
    }

    function calculateDepositOfWETHRequired(uint256 tokenAmount) public view returns (uint256) {
        // console.log('-------------------------');
        // console.log('_1', tokenAmount);
        // console.log('_1', _getOracleQuote(tokenAmount));
        // console.log('_1', _getOracleQuote(tokenAmount).mul(3));
        // console.log('_1', _getOracleQuote(tokenAmount).mul(3) / (10 ** 18));
        return _getOracleQuote(tokenAmount).mul(3) / (10 ** 18);
    }

    // Fetch the price from Uniswap v2 using the official libraries
    // price of token in WETH (the price of 1 token in wei)
    function _getOracleQuote(uint256 amount) public view returns (uint256) {
        // see https://docs.uniswap.org/contracts/v2/reference/smart-contracts/library
        // get the reserves of token and WETH
        (uint256 reservesWETH, uint256 reservesToken) = UniswapV2Library.getReserves(
            _uniswapFactory, address(_weth), address(_token)
        );
        // Given some asset amount and reserves, 
        // returns an amount of the other asset representing equivalent value.
        return UniswapV2Library.quote(amount.mul(10 ** 18), reservesToken, reservesWETH);
    }
}

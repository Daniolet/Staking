const { expect } = require("chai");
const { ethers } = require("hardhat");
const { MockProvider } = require("ethereum-waffle");

require("@nomiclabs/hardhat-ethers");
const assert = require('assert').strict;
const { BigNumber } = require("ethers");

const minterRole = ethers.utils.id("MINTER_ROLE");
const burnerRole = ethers.utils.id("BURNER_ROLE");
const pauserRole = ethers.utils.id("PAUSER_ROLE");

const getNumberFromBN = (bn, d) => {
  return BigNumber.from(bn).div(Math.pow(10, d)).toNumber();
}

contract("UvwToken", (accounts) => {
  let uvwToken, token, owner, account1, account2;
  let dec;

  before(async () => {
    [owner, account1, account2] = await ethers.getSigners();

    uvwToken = await hre.ethers.getContractFactory('UvwToken');
    token = await uvwToken.deploy();

    await token.deployed();
    console.log("uvwToken deployed to:", token.address);

  });

  it('Check contract status', async () => {
    dec = await token.decimals();

    expect(await token.owner()).to.equal(owner.address);
    console.log("Owner address : ", owner.address);

    const ownerBalance = await token.balanceOf(owner.address);
    expect(await token.totalSupply()).to.equal(ownerBalance);
    console.log("Owner balance : ", getNumberFromBN(ownerBalance, dec));

    expect(await token.name()).to.equal("uvwToken");
    console.log("Contract name : ", await token.name());

    expect(await token.symbol()).to.equal("UVWT");
    console.log("Contract symbol : ", await token.symbol());

    expect(await token.decimals()).to.equal(10);
    console.log("Contract decimals : ", await token.decimals());
  });

  it('Set MINTER_ROLE to owner, PAUSER_ROLE to account1 and BURNER_ROLE to account2', async () => {
    await token.setRole("MINTER_ROLE", owner.address);
    expect(await token.hasRole(minterRole, owner.address)).to.equal(true);

    await token.setRole("PAUSER_ROLE", account1.address);
    expect(await token.hasRole(pauserRole, account1.address)).to.equal(true);

    await token.setRole("BURNER_ROLE", account2.address);
    expect(await token.hasRole(burnerRole, account2.address)).to.equal(true);

    expect(await token.hasRole(pauserRole, owner.address)).to.equal(false);
    expect(await token.hasRole(burnerRole, owner.address)).to.equal(false);

    expect(await token.hasRole(minterRole, account1.address)).to.equal(false);
    expect(await token.hasRole(burnerRole, account1.address)).to.equal(false);

    expect(await token.hasRole(minterRole, account2.address)).to.equal(false);
    expect(await token.hasRole(pauserRole, account2.address)).to.equal(false);

    console.log("Owner has MINTER_ROLE");
    console.log("Account1 has PAUSER_ROLE");
    console.log("account2 has BURNER_ROLE");
  });

  it('Owner mint token with MINTER_ROLE', async () => {
    const tokensToMint = 1000000000000
    const initialBalance = await token.balanceOf(owner.address);
    console.log('initial Balance ', getNumberFromBN(initialBalance, dec))
    await expect(token.mint(owner.address, tokensToMint)).to.be.not.reverted;
    const newBalance = await token.balanceOf(owner.address);
    console.log({ newBalance: newBalance.toString() })
    expect(getNumberFromBN(newBalance, dec)).to.equal(getNumberFromBN(initialBalance, dec) + tokensToMint / 10000000000);
  });

  it('Account1 tries to mint token without MINTER_ROLE, but failed', async () => {
    await expect(token.connect(account1).mint(account1, 1000000000000)).to.be.reverted;
    const account1Balance = await token.balanceOf(account1.address);
    expect(account1Balance).to.equal(0);
    console.log("Account1 Balance : ", getNumberFromBN(account1Balance, dec));
  });

  it('Should transfer tokens between accounts', async () => {
    await token.transfer(account1.address, 500000000000);
    let account1Balance = await token.balanceOf(account1.address);
    expect(account1Balance).to.equal(500000000000);

    await token.connect(account1).transfer(account2.address, 250000000000);
    const account2Balance = await token.balanceOf(account2.address);
    expect(account2Balance).to.equal(250000000000);

    const ownerBalance = await token.balanceOf(owner.address);
    account1Balance = await token.balanceOf(account1.address);

    console.log("Owner Balance : ", getNumberFromBN(ownerBalance, dec));
    console.log("Account1 Balance : ", getNumberFromBN(account1Balance, dec));
    console.log("Account2 Balance : ", getNumberFromBN(account2Balance, dec));
  });

  it('Account1 set pause to true with PAUSER_ROLE', async () => {
    expect(await token.paused()).to.equal(false);
    console.log("Pause is false before account1 set pause");

    await expect(token.connect(account1).pause()).to.be.not.reverted;
    let paused = await token.paused();
    expect(paused).to.equal(true);
    console.log("Pause is true after account1 set pause");
  });

  it('Failed transfer tokens between accounts', async () => {
    let account1Balance = await token.balanceOf(account1.address);
    let account2Balance = await token.balanceOf(account2.address);
    console.log("Account1 balance before trying to transfer : ", getNumberFromBN(account1Balance, dec));
    console.log("Account2 balance before trying to transfer : ", getNumberFromBN(account2Balance, dec));

    await expect(token.connect(account1).transfer(account2.address, 100000000000)).to.be.reverted;

    account1Balance = await token.balanceOf(account1.address);
    expect(account1Balance).to.equal(250000000000);
    account2Balance = await token.balanceOf(account2.address);
    expect(account2Balance).to.equal(250000000000);

    console.log("Account1 balance after trying to transfer : ", getNumberFromBN(account1Balance, dec));
    console.log("Account2 balance after trying to transfer : ", getNumberFromBN(account2Balance, dec));

    console.log("Token transfer is failed because pause is true");
  });

  it('Account2 tries to set pause to false without PAUSER_ROLE', async () => {
    let paused = await token.paused();
    expect(paused).to.equal(true);
    console.log("Pause is true before account2 tries set pause");

    await expect(token.connect(account2).unpause()).to.be.reverted;
    paused = await token.paused();
    expect(paused).to.equal(true);
    console.log("Pause is true after account2 tries to set pause");
  });

  it('Account1 set pause to false with PAUSER_ROLE', async () => {
    await expect(token.connect(account1).unpause()).to.be.not.reverted;
  });

  it('Account2 burn token with BURNER_ROLE', async () => {
    expect(await token.hasRole(burnerRole, account2.address)).to.equal(true);

    let totalSupply = await token.totalSupply();
    console.o
    let account2Balance = await token.balanceOf(account2.address);
    console.log("TotalSupply before account2 burn token : ", getNumberFromBN(totalSupply, dec));
    console.log("Account2 Balance before account2 burn token : ", getNumberFromBN(account2Balance, dec));

    await expect(token.connect(account2).burnToken(account2.address, 100000000000)).to.be.not.reverted;

    totalSupply = await token.totalSupply();
    account2Balance = await token.balanceOf(account2.address);

    expect(getNumberFromBN(totalSupply, dec)).to.equal(100000090);
    expect(account2Balance).to.equal(150000000000);

    console.log("TotalSupply after account2 burn token : ", getNumberFromBN(totalSupply, dec));
    console.log("Account2 Balance after account2 burn token : ", getNumberFromBN(account2Balance, dec));
  });

  it('Account1 tries to burn token without BURNER_ROLE, but failed', async () => {
    expect(await token.hasRole(burnerRole, account1.address)).to.equal(false);

    let totalSupply = await token.totalSupply();
    let account1Balance = await token.balanceOf(account1.address);
    console.log("TotalSupply before account1 tries to burn token : ", getNumberFromBN(totalSupply, dec));
    console.log("Account1 Balance before account1 tries to burn token : ", getNumberFromBN(account1Balance, dec));

    await expect(token.connect(account1).burnToken(account1.address, 100000000000)).to.be.reverted;

    totalSupply = await token.totalSupply();
    account1Balance = await token.balanceOf(account1.address);

    expect(getNumberFromBN(totalSupply, dec)).to.equal(100000090);
    expect(account1Balance).to.equal(250000000000);

    console.log("TotalSupply after account1 tries to burn token : ", getNumberFromBN(totalSupply, dec));
    console.log("Account1 Balance after account1 tries to burn token : ", getNumberFromBN(account1Balance, dec));
  });

  it('Should add account2 to blacklist', async () => {
    let account2BlacklistStatus = await token.getBlackListStatus(account2.address);
    let account2Balance = await token.balanceOf(account2.address);
    expect(account2BlacklistStatus).to.equal(false);
    console.log("Account2 is not in blacklist before owner add him to blacklist");
    console.log("Account2 balance before : ", getNumberFromBN(account2Balance, dec));

    await expect(token.addBlackList(account2.address)).to.be.not.reverted;
    account2BlacklistStatus = await token.getBlackListStatus(account2.address);
    expect(account2BlacklistStatus).to.equal(true);
    console.log("Account2 is in blacklist");

    await expect(token.connect(account2).transfer(account1.address, 100000000000)).to.be.reverted;

    account2Balance = await token.balanceOf(account2.address);
    console.log("Account2 balance after : ", getNumberFromBN(account2Balance, dec));
  });

  it('Should remove account2 from blacklist', async () => {
    await expect(token.removeBlackList(account2.address)).to.be.not.reverted;
  });
})

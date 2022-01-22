const { expect } = require("chai");
const { MockProvider } = require("ethereum-waffle");
const { ethers } = require("hardhat");

require("@nomiclabs/hardhat-ethers");
const assert = require('assert').strict;

function sleep(milliseconds) {
   const date = Date.now();
   let currentDate = null;
   do {
      currentDate = Date.now();
   } while (currentDate - date < milliseconds)
}


contract("stableStaking", (accounts) => {
   let staked;
   let token;
   amount = 100000000000000000

   before(async () => {

      [owner, ...accounts] = await ethers.getSigners();
      Erc20 = await hre.ethers.getContractFactory("xyztokenToken");
      token = await Erc20.deploy()

      await token.deployed();
      console.log("xyztokenToken deployed to:", token.address);

      StableStaking = await hre.ethers.getContractFactory("xyztokenStableCoinFund");
      stableStaked = await StableStaking.deploy(token.address);

      await stableStaked.deployed();
      console.log("staking deployed to:", stableStaked.address);
      const approveAmount = await token.totalSupply()
      token.approve(stableStaked.address, approveAmount)

      await token.approve(stableStaked.address, approveAmount)
      await token.connect(accounts[0]).approve(stableStaked.address, 10000000000000);
      await token.connect(accounts[1]).approve(stableStaked.address, 10000000000000);
      await token.connect(accounts[2]).approve(stableStaked.address, 10000000000000);
      await token.connect(accounts[3]).approve(stableStaked.address, 10000000000000);
      await token.connect(accounts[4]).approve(stableStaked.address, 10000000000000);

   });

   it("Should allow owner to Add a stakeType", async () => {
      const stakeTypeID1 = 1
      const percentageReturn1 = 5
      const minAmount = 1000000000000
      const maxAmount = 2000000000000
      await stableStaked.addStakeType(percentageReturn1, minAmount, maxAmount)
      const stakeType1 = await stableStaked.getStakeType(stakeTypeID1)

      expect(stakeType1.Type).to.equal(1)
      expect(stakeType1.percentageReturn).to.equal(5)
      expect(stakeType1.minAmount).to.equal(1000000000000)
      expect(stakeType1.maxAmount).to.equal(2000000000000)
   })



   it("Should allow owner to update the stakeType details", async () => {
      const stakeTypeID = 1
      const percentageReturn = 10
      const minAmount = 1000000000000
      const maxAmount = 10000000000000
      await stableStaked.updateStakeType(stakeTypeID, percentageReturn, minAmount, maxAmount)
      //assert stake Values.
      const stakeType = await stableStaked.getStakeType(stakeTypeID)
      assert(stakeType.Type == 1)
      assert(stakeType.percentageReturn == 10)
      assert(stakeType.minAmount == 1000000000000)
      assert(stakeType.maxAmount == 10000000000000)
   })


   it("Should allow owner to get StakeType details", async () => {
      const stakeTypeID = 1
      const stakeType = await stableStaked.getStakeType(stakeTypeID)
      //assert stakeType
      assert(stakeType.Type == 1)
      assert(stakeType.percentageReturn == 10)
      assert(stakeType.minAmount == 1000000000000)
      assert(stakeType.maxAmount == 10000000000000)
   })

   it("Should allow any user to stake XyzTokenTokens", async () => {
      [owner, ...accounts] = await ethers.getSigners();

      await token.transfer(accounts[0].address, 10000000000000)
      await token.transfer(accounts[1].address, 10000000000000)
      await token.transfer(accounts[2].address, 10000000000000)
      await token.transfer(accounts[3].address, 10000000000000)
      await token.transfer(accounts[4].address, 10000000000000)

      const stakeAmount1 = 1000000000000
      const stakeAmount2 = 2000000000000
      const stakeAmount3 = 3000000000000
      const stakeAmount4 = 4000000000000
      const stakeAmount5 = 4000000000000
      const StakeType1 = 1

      const stakeID1 = 1
      const stakeID2 = 2
      const stakeID3 = 3
      const stakeID4 = 4
      const stakeID5 = 5

      await stableStaked.connect(accounts[0]).addStake(stakeAmount1, StakeType1);
      await stableStaked.connect(accounts[1]).addStake(stakeAmount2, StakeType1);
      await stableStaked.connect(accounts[2]).addStake(stakeAmount3, StakeType1);
      await stableStaked.connect(accounts[3]).addStake(stakeAmount4, StakeType1);
      await stableStaked.connect(accounts[4]).addStake(stakeAmount5, StakeType1);
      // check the stake details
      const stakeDetails1 = await stableStaked.getStakeDetailsByStakeID(stakeID1)
      const stakeDetails2 = await stableStaked.getStakeDetailsByStakeID(stakeID2)
      const stakeDetails3 = await stableStaked.getStakeDetailsByStakeID(stakeID3)
      const stakeDetails4 = await stableStaked.getStakeDetailsByStakeID(stakeID4)
      const stakeDetails5 = await stableStaked.getStakeDetailsByStakeID(stakeID5)

      assert(stakeDetails1.xyztokenAmount == stakeAmount1)
      assert(stakeDetails1.active == true)
      assert(stakeDetails1.ownerAddress == accounts[0].address)
      assert(stakeDetails1.partialWithdrawn == false)
      assert(stakeDetails1.settlementAmount == 0)
      assert(stakeDetails1.stakeReturns == 0)
      assert(stakeDetails1.linkedStakeID == 0)

      assert(stakeDetails2.xyztokenAmount == stakeAmount2)
      assert(stakeDetails2.active == true)
      assert(stakeDetails2.ownerAddress == accounts[1].address)
      assert(stakeDetails2.partialWithdrawn == false)
      assert(stakeDetails2.settlementAmount == 0)
      assert(stakeDetails2.stakeReturns == 0)
      assert(stakeDetails2.linkedStakeID == 0)

      assert(stakeDetails3.xyztokenAmount == stakeAmount3)
      assert(stakeDetails3.active == true)
      assert(stakeDetails3.ownerAddress == accounts[2].address)
      assert(stakeDetails3.partialWithdrawn == false)
      assert(stakeDetails3.settlementAmount == 0)
      assert(stakeDetails3.stakeReturns == 0)
      assert(stakeDetails3.linkedStakeID == 0)

      assert(stakeDetails4.xyztokenAmount == stakeAmount4)
      assert(stakeDetails4.active == true)
      assert(stakeDetails4.ownerAddress == accounts[3].address)
      assert(stakeDetails4.partialWithdrawn == false)
      assert(stakeDetails4.settlementAmount == 0)
      assert(stakeDetails4.stakeReturns == 0)
      assert(stakeDetails4.linkedStakeID == 0)

      assert(stakeDetails5.xyztokenAmount == stakeAmount4)
      assert(stakeDetails5.active == true)
      assert(stakeDetails5.ownerAddress == accounts[4].address)
      assert(stakeDetails5.partialWithdrawn == false)
      assert(stakeDetails5.settlementAmount == 0)
      assert(stakeDetails5.stakeReturns == 0)
      assert(stakeDetails5.linkedStakeID == 0)

   })



   it(`Should allow user to withdraw the complete stake with enough balance in the contract.
          Contract should  transfer the amount to the user`, async () => {
      [owner, ...accounts] = await ethers.getSigners();

      const stakeAmount = 1099999999999
      const stakeID1 = 1
      await token.connect(accounts[0]).approve(stableStaked.address, 20000000000000);

      const allowance = await token.allowance(accounts[0].address, stableStaked.address)
      console.log(allowance.toNumber())
      console.log("StakeAmount is", stakeAmount)
      const currentContractBalance = await token.balanceOf(stableStaked.address)
      console.log("Current Contract Balance is :", currentContractBalance.toNumber())
      const userBalanceBeforeWithdraw = await token.balanceOf(accounts[0].address)
      console.log("User Balance before withdrawing the stake completely", userBalanceBeforeWithdraw.toNumber())
      console.log("About to sleep for a minute.To allow the stake to mature")
      sleep(60000)
      await stableStaked.connect(accounts[0]).withdraw(stakeID1, true, stakeAmount)
      const userBalanceAfterWithdraw = await token.balanceOf(accounts[0].address)
      console.log("User Balance after withdrawing the Stake : ", userBalanceAfterWithdraw.toNumber())
      const stakeDetails1 = await stableStaked.getStakeDetailsByStakeID(stakeID1)
      assert(stakeDetails1.active == false)
      assert(stakeDetails1.partialWithdrawn == false)
   })


   it(`Should allow user to withdraw the stake partially with enough balance in the contract.
          Contract should partial amount  to the user and should set the stake attributes and should do a 
          restake with the remaining balance`, async () => {
      [owner, ...accounts] = await ethers.getSigners();
      await token.transfer(stableStaked.address, 10000000000000)
      const stakeID2 = 2
      const stakeAmount = 500000000000
      const currentContractBalance = await token.balanceOf(stableStaked.address)
      console.log("Current Contract Balance is :", currentContractBalance.toNumber())
      const userBalanceBeforeWithdraw = await token.balanceOf(accounts[1].address)
      console.log("User Balance before withdrawing the stake partially", userBalanceBeforeWithdraw.toNumber())
      await expect(stableStaked.connect(accounts[1]).withdraw(stakeID2, false, stakeAmount)).to.not.be.reverted;

      const userBalanceAfterWithdraw = await token.balanceOf(accounts[1].address)
      console.log("User Balance after withdrawing the Stake partially : ", userBalanceAfterWithdraw.toNumber())
      const stakeDetails2 = await stableStaked.getStakeDetailsByStakeID(stakeID2)
      const stakes = await stableStaked.getCurrentStakeID()
      const currentStakeDetails = await stableStaked.getStakeDetailsByStakeID(stakes)

      assert(stakeDetails2.active == false)
      assert(stakeDetails2.partialWithdrawn == true)

      assert(currentStakeDetails.active == true)
      assert(currentStakeDetails.partialWithdrawn == false)

   })


   it(`Should allow user to withdraw the stake partially without enough balance in the contract.
          Contract should not transfer returns to the user and should set the stake attributes`, async () => {
      [owner, ...accounts] = await ethers.getSigners();
      const contractBalanceBefore = await token.balanceOf(stableStaked.address)
      console.log("Contract Balance before claiming", contractBalanceBefore.toNumber())
      await stableStaked.ClaimToInvest()
      const contractBalanceAfter = await token.balanceOf(stableStaked.address)
      console.log("Contract Balance before claiming", contractBalanceAfter.toNumber())
      const stakeID3 = 3
      const stakeAmount = 500000000000
      const userBalanceBeforeWithdraw = await token.balanceOf(accounts[2].address)
      console.log("User Balance before withdrawing the stake partially", userBalanceBeforeWithdraw.toNumber())
      await expect(stableStaked.connect(accounts[2]).withdraw(stakeID3, false, stakeAmount)).to.not.be.reverted;
      const userBalanceAfterWithdraw = await token.balanceOf(accounts[2].address)
      console.log("User Balance after withdrawing the Stake partially : ", userBalanceAfterWithdraw.toNumber())
      const stakeDetails3 = await stableStaked.getStakeDetailsByStakeID(stakeID3)
      assert(stakeDetails3.active == false)
      assert(stakeDetails3.partialWithdrawn == true)
      assert(stakeDetails3.settled == false)

   })


   it(`Should allow user to withdraw the complete stake without enough balance in the contract.
          Contract should not transfer returns to the user and should set the stake attributes`, async () => {
      [owner, ...accounts] = await ethers.getSigners();
      const stakeID4 = 4
      const stakeAmount = 1099999999999
      const userBalanceBeforeWithdraw = await token.balanceOf(accounts[3].address)
      console.log("User Balance before withdrawing the stake partially", userBalanceBeforeWithdraw.toNumber())
      await expect(stableStaked.connect(accounts[3]).withdraw(stakeID4, true, stakeAmount)).to.not.be.reverted;

      const userBalanceAfterWithdraw = await token.balanceOf(accounts[3].address)
      console.log("User Balance after withdrawing the Stake partially : ", userBalanceAfterWithdraw.toNumber())
      const stakeDetails4 = await stableStaked.getStakeDetailsByStakeID(stakeID4)

      assert(stakeDetails4.settled == false)
      assert(stakeDetails4.active == false)
      assert(stakeDetails4.partialWithdrawn == false)
   })



   it(`Should allow the owner to settle the unsettled stakes. 
          Contract should transfer the amount to the users and should set the stake properties`, async () => {
      [owner, ...accounts] = await ethers.getSigners();
      await token.transfer(stableStaked.address, 10000000000000)
      const stakeIDs = [4]
      const beforeBalanceOfOwner4 = await token.balanceOf(accounts[4].address)
      console.log("Balance of account 4 before settling", beforeBalanceOfOwner4.toNumber())
      const tx = await stableStaked.settleStakes(stakeIDs)
      console.log(tx.tx)
      const stakeDetails4 = await stableStaked.getStakeDetailsByStakeID(4)
      const afterBalanceOfOwner4 = await token.balanceOf(accounts[4].address)
      console.log("Balance of account 4 after settling", afterBalanceOfOwner4.toNumber())
      assert(stakeDetails4.settled == false)
      assert(stakeDetails4.active == false)
      assert(stakeDetails4.partialWithdrawn == false)

   })

})

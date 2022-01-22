const hre = require("hardhat");

async function main() {

  const Erc20 = await hre.ethers.getContractFactory("XyzTokenToken");
  const erc20 = await Erc20.deploy();

  await erc20.deployed();
  console.log("xyztokenToken deployed to:", erc20.address);

  const StableStaking = await hre.ethers.getContractFactory("xyztokenStableCoinFund");
  const stableStaking = await StableStaking.deploy(erc20.address);

  await stableStaking.deployed();
  console.log("stable staking deployed to:", stableStaking.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
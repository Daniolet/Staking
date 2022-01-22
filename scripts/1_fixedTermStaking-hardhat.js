const hre = require("hardhat");

async function main() {

  const Erc20 = await hre.ethers.getContractFactory("XyzTokenToken");
  const erc20 = await Erc20.deploy();

  await erc20.deployed();
  console.log("xyztokenToken deployed to:", erc20.address);

  const Staking = await hre.ethers.getContractFactory("xyztokenFund");
  const staking = await Staking.deploy(erc20.address);

  await staking.deployed();
  console.log("staking deployed to:", staking.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
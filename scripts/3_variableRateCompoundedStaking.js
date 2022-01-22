const hre = require("hardhat");

async function main() {

  const Erc20 = await hre.ethers.getContractFactory("xyzTokenToken");
  const erc20 = await Erc20.deploy();

  await erc20.deployed();
  console.log("xyztokenToken deployed to:", erc20.address);

  const VariableRateCompoundedStaking = await hre.ethers.getContractFactory("variableRateCompoundedStaking");
  const vcStaking = await VariableRateCompoundedStaking.deploy(erc20.address);

  await vcStaking.deployed();
  console.log("stable staking deployed to:", vcStaking.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
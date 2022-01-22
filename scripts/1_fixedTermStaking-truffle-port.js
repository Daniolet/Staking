const Staking = artifacts.require("xyztokenFund");
const Erc20 = artifacts.require('XyzTokentoken');

module.exports = async (deployer) => {
  const erc20 = await Erc20.new();
  Erc20.setAsDeployed(erc20);
  const staking = await Staking.new();
  Staking.setAsDeployed(staking);
};
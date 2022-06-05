// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const DaiFactory = await hre.ethers.getContractFactory("Dai");
  const Dai = await DaiFactory.deploy();

  const BatFactory = await hre.ethers.getContractFactory("Bat");
  const Bat = await BatFactory.deploy();

  const RepFactory = await hre.ethers.getContractFactory("Rep");
  const Rep = await RepFactory.deploy();

  const ZrxFactory = await hre.ethers.getContractFactory("Zrx");
  const Zrx = await ZrxFactory.deploy();

  console.log("Dai deployed to:", Dai.address);
  console.log("Bat deployed to:", Bat.address);
  console.log("Rep deployed to:", Rep.address);
  console.log("Zrx deployed to:", Zrx.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

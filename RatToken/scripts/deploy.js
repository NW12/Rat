const hre = require("hardhat");

async function main() {
  // We get the contract to deploy
  // const Rat = await hre.ethers.getContractFactory("TheRareAntiquitiesToken");
  // const rat = await Rat.deploy("<wallet/treasury-address>");
  // await rat.deployed();

   // const Rat = await hre.ethers.getContractFactory("TheRareAntiquitiesToken");
  // const rat = await Rat.deploy("<wallet/treasury-address>");
  // await rat.deployed();

  
  const Crowdsale = await hre.ethers.getContractFactory("Crowdsale");
  const crowdsale = await Crowdsale.deploy('100000000000000000000',"0x808a6449a808bbC99f6f111208C50dcFd141595A","0x48F91fbC86679e14f481DD3C3381f0e07F93A711");
  await crowdsale.deployed();
  

  // console.log("Rat deployed to:", rat.address);
  // console.log("TokenTimelock deployed to:", tokenTimelock.address);
  console.log("crowdsale deployed to:", crowdsale.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

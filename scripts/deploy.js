//deploy script 

const hre = require("hardhat");

async function main() {
  // Get the contract to deploy
  const Delance = await hre.ethers.getContractFactory("Delance");
  const delance = await Delance.deploy();

  // Wait until the contract is deployed
  await delance.waitForDeployment();

  // Output the address of the deployed contract
  console.log(`Delance contract deployed to ${delance.target}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

  //Delance contract deployed to 0x1cbD563B6F743b82f2F345B342C08E9E666Ef7Be
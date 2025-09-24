// Example deployment script for local tests
async function main() {
  const [deployer] = await ethers.getSigners();
  console.log('Deployer:', deployer.address);

  const Token = await ethers.getContractFactory('MockToken');
  const token = await Token.deploy('PoC Token', 'POC', ethers.utils.parseEther('1000000'));
  await token.deployed();
  console.log('Token:', token.address);

  const AttestorRegistry = await ethers.getContractFactory('AttestorRegistry');
  const att = await AttestorRegistry.deploy(deployer.address);
  await att.deployed();
  console.log('AttestorRegistry:', att.address);

  const PoC = await ethers.getContractFactory('ProofOfContributionSnapshot');
  const poc = await PoC.deploy(token.address, att.address);
  await poc.deployed();
  console.log('PoC:', poc.address);
}

module.exports = main;
if (require.main === module) {
  main().catch((e)=>{console.error(e); process.exit(1);});
}

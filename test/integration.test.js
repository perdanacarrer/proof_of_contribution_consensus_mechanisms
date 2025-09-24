const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('ProofOfContributionSnapshot - attestation & snapshot flow', function () {
  let token, attestorRegistry, poc, owner, alice, bob, attestor, other;

  beforeEach(async function () {
    [owner, alice, bob, attestor, other] = await ethers.getSigners();
    const Token = await ethers.getContractFactory('MockToken');
    token = await Token.deploy('PoC Token', 'POC', ethers.utils.parseEther('1000000'));
    await token.deployed();

    const AttestorRegistry = await ethers.getContractFactory('AttestorRegistry');
    attestorRegistry = await AttestorRegistry.deploy(owner.address);
    await attestorRegistry.deployed();

    const PoC = await ethers.getContractFactory('ProofOfContributionSnapshot');
    poc = await PoC.deploy(token.address, attestorRegistry.address);
    await poc.deployed();

    // register attestor in registry via owner (has GOVERNOR_ROLE initially)
    await attestorRegistry.addAttestor(attestor.address);

    // mint tokens and approve staking for participants
    await token.mint(alice.address, ethers.utils.parseEther('1000'));
    await token.mint(bob.address, ethers.utils.parseEther('1000'));
    await token.connect(alice).approve(poc.address, ethers.utils.parseEther('1000'));
    await token.connect(bob).approve(poc.address, ethers.utils.parseEther('1000'));
  });

  it('allows registration, staking, attestation submission, replay protection', async function () {
    // participants register and stake
    await poc.connect(alice).register();
    await poc.connect(bob).register();
    await poc.connect(alice).stake(ethers.utils.parseEther('100'));
    await poc.connect(bob).stake(ethers.utils.parseEther('200'));

    // Attestor produces an off-chain signature for alice: user, amount, nonce, contract
    const user = alice.address;
    const amount = ethers.utils.parseEther('50');
    const nonce = 1;
    const domainHash = ethers.utils.solidityKeccak256(['address','uint256','uint256','address'], [user, amount, nonce, poc.address]);
    const signature = await attestor.signMessage(ethers.utils.arrayify(domainHash));

    // submit attestation on-chain (any caller can submit)
    await poc.connect(other).submitAttestation(user, amount, nonce, signature);

    // verify contribution increased
    const p = await poc.participants(user);
    expect(p.contributionScore).to.equal(amount);

    // replay with same nonce should fail
    await expect(poc.connect(other).submitAttestation(user, amount, nonce, signature)).to.be.revertedWith('replay');
  });

  it('commits snapshot root (governor role required) and select proposer deterministically', async function () {
    // owner is default admin; grant owner GOVERNOR_ROLE on poc (owner deployed default admin)
    const GOVERNOR_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('GOVERNOR_ROLE'));
    await poc.grantRole(GOVERNOR_ROLE, owner.address);

    // commit a dummy snapshot root for epoch 1
    const epoch = 1;
    const root = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('dummy root'));
    await poc.connect(owner).commitSnapshot(epoch, root);

    const stored = await poc.snapshotRoot(epoch);
    expect(stored).to.equal(root);

    // test selectProposerWithRandom deterministic behavior (register many participants)
    for (let i=0;i<5;i++) {
      const signer = (await ethers.getSigners())[i+1];
      await poc.connect(signer).register();
      await token.mint(signer.address, ethers.utils.parseEther('100'));
      await token.connect(signer).approve(poc.address, ethers.utils.parseEther('100'));
      await poc.connect(signer).stake(ethers.utils.parseEther('10'));
    }
    // call selectProposerWithRandom with fixed randomness
    const randomness = ethers.BigNumber.from('12345678901234567890');
    const proposer = await poc.selectProposerWithRandom(randomness);
    // proposer should be an address in the registered set (not zero)
    expect(proposer).to.not.equal(ethers.constants.AddressZero);
  });
});

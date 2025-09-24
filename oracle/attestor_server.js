// Simple attestor server used for demonstration. In tests we emulate signing directly.
// This server signs attestations {user, amount, nonce, contract} and returns signature.
const express = require('express');
const { ethers } = require('ethers');
const app = express();
app.use(express.json());

const ATTESTOR_PRIVATE_KEY = process.env.ATTESTOR_KEY || '0x59c6995e998f97a5a004497e5d9f5b7e00000000000000000000000000000000';
const wallet = new ethers.Wallet(ATTESTOR_PRIVATE_KEY);

app.post('/attest', async (req, res) => {
  const { user, amount, nonce, contract } = req.body;
  if (!user || !amount || nonce === undefined || !contract) return res.status(400).send('bad');
  const hash = ethers.utils.solidityKeccak256(['address','uint256','uint256','address'], [user, amount, nonce, contract]);
  const sig = await wallet.signMessage(ethers.utils.arrayify(hash));
  res.json({ user, amount, nonce, signature: sig, attestor: wallet.address });
});

app.listen(3001, ()=> console.log('attestor running on 3001'));

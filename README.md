# Proof of Contribution Consesus Mechanisms

This bundle contains a full Hardhat skeleton for the Proof of Contribution (PoC) prototype with:
- Snapshot-based proposer selection commit model (gas-optimal)
- Off-chain attestation flow + Attestor Registry with replay protection
- Tests that exercise attestation flow, staking, snapshot commit, and proposer selection
- CI workflow that runs tests and slither (slither commands are included but Slither is not executed in this environment)

## Quickstart (local)
1. Install Node 18+ and npm
2. npm install
3. npx hardhat test

## Notes on Slither & Static Analysis
- This environment cannot run Slither for you. The CI workflow includes Slither commands which will run in GitHub Actions if enabled.
- To run locally (recommended inside Docker):
  - pip install slither-analyzer
  - slither ./contracts --config-file slither.config
- I can help interpret the output if you run Slither and paste results here.

## Files of interest
- contracts/ProofOfContributionSnapshot.sol
- contracts/AttestorRegistry.sol
- contracts/MockToken.sol
- test/integration.test.js
- oracle/attestor_server.js (example attestor signing service)
- scripts/deploy.js
- .github/workflows/ci.yml

**Thank you for this opportunity.**

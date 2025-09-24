require('@nomicfoundation/hardhat-toolbox');
module.exports = {
  solidity: {
    compilers: [
      { version: "0.8.20" }
    ]
  },
  paths: {
    sources: './contracts',
    tests: './test'
  },
  mocha: {
    timeout: 200000
  }
};

Gas optimization notes included with suggestions:
- Use snapshot commit model to compute weights off-chain and commit root on-chain (merkle proofs can be added)
- Avoid loops over dynamic storage in state-changing functions; use pagination or epoch snapshots
- Cache weights or only update participant entries when their stake/score changes

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./AttestorRegistry.sol";

contract ProofOfContributionSnapshot is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant ATTESTOR_ROLE = keccak256("ATTESTOR_ROLE");

    IERC20 public stakingToken;
    AttestorRegistry public attestorRegistry;
    uint256 public epoch;
    uint256 public unstakeDelayEpochs = 2;

    struct Participant {
        uint256 stake;
        uint256 contributionScore;
        uint256 unstakeAmount;
        uint256 unstakeReleaseEpoch;
        bool registered;
        uint256 lastNonce; // replay protection for on-chain attestation consumption
    }

    mapping(address => Participant) public participants;

    // Snapshot commit: off-chain snapshot signer signs a Merkle root or mapping of effective weights for an epoch
    // On-chain, a governance-approved snapshot root is committed with epoch -> root hash and commit block
    mapping(uint256 => bytes32) public snapshotRoot;
    mapping(uint256 => uint256) public snapshotCommitBlock;

    event Registered(address indexed who);
    event Staked(address indexed who, uint256 amount);
    event SnapshotCommitted(uint256 indexed epoch, bytes32 root, uint256 blockNumber);
    event AttestationConsumed(address indexed user, uint256 amount, address attestor, uint256 nonce);

    constructor(address _stakingToken, address _attestorRegistry) {
        stakingToken = IERC20(_stakingToken);
        attestorRegistry = AttestorRegistry(_attestorRegistry);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function register() external {
        Participant storage p = participants[msg.sender];
        require(!p.registered, "registered");
        p.registered = true;
        emit Registered(msg.sender);
    }

    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "amount>0");
        Participant storage p = participants[msg.sender];
        require(p.registered, "register");
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        p.stake += amount;
        emit Staked(msg.sender, amount);
    }

    // off-chain attestation: attestor signs (user, amount, nonce, contract)
    // on-chain, any caller may submit along with signature; contract validates that signer is in registry and nonce > lastNonce
    function submitAttestation(address user, uint256 amount, uint256 nonce, bytes calldata signature) external {
        // recover signer
        bytes32 hash = keccak256(abi.encodePacked(user, amount, nonce, address(this))).toEthSignedMessageHash();
        address signer = hash.recover(signature);
        require(attestorRegistry.isAttestor(signer), "invalid attestor");
        Participant storage p = participants[user];
        require(p.registered, "not reg");
        require(nonce > p.lastNonce, "replay");
        p.lastNonce = nonce;
        p.contributionScore += amount;
        emit AttestationConsumed(user, amount, signer, nonce);
    }

    // governance committed snapshot root for epoch
    function commitSnapshot(uint256 _epoch, bytes32 root) external onlyRole(GOVERNOR_ROLE) {
        snapshotRoot[_epoch] = root;
        snapshotCommitBlock[_epoch] = block.number;
        emit SnapshotCommitted(_epoch, root, block.number);
    }

    // view: calculate effective weight given stake and contribution score (same formula)
    function effectiveWeight(address who) public view returns (uint256) {
        Participant storage p = participants[who];
        if (!p.registered) return 0;
        uint256 bonus = sqrt(p.contributionScore);
        return (p.stake * (100 + bonus)) / 100;
    }

    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = x;
        uint256 y = (x + 1) / 2;
        while (y < z) {
            z = y;
            y = (x / y + y) / 2;
        }
        return z;
    }

    // withdrawal functions
    function initiateUnstake(uint256 amount) external {
        Participant storage p = participants[msg.sender];
        require(amount > 0 && amount <= p.stake, "invalid");
        p.stake -= amount;
        p.unstakeAmount += amount;
        p.unstakeReleaseEpoch = epoch + unstakeDelayEpochs;
    }

    function withdraw() external nonReentrant {
        Participant storage p = participants[msg.sender];
        require(p.unstakeAmount > 0, "none");
        require(epoch >= p.unstakeReleaseEpoch, "release");
        uint256 amt = p.unstakeAmount;
        p.unstakeAmount = 0;
        stakingToken.safeTransfer(msg.sender, amt);
    }
}

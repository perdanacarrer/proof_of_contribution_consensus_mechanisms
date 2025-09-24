// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/AccessControl.sol";
contract AttestorRegistry is AccessControl {
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant ATTESTOR_ROLE = keccak256("ATTESTOR_ROLE");
    mapping(address => bool) public isAttestor;
    event AttestorAdded(address indexed who);
    event AttestorRemoved(address indexed who);

    constructor(address admin) {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(GOVERNOR_ROLE, admin);
    }

    function addAttestor(address a) external onlyRole(GOVERNOR_ROLE) {
        require(!isAttestor[a], "exists");
        isAttestor[a] = true;
        grantRole(ATTESTOR_ROLE, a);
        emit AttestorAdded(a);
    }

    function removeAttestor(address a) external onlyRole(GOVERNOR_ROLE) {
        require(isAttestor[a], "not");
        isAttestor[a] = false;
        revokeRole(ATTESTOR_ROLE, a);
        emit AttestorRemoved(a);
    }
}

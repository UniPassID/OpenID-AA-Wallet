// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@account-abstraction/contracts/samples/SimpleAccount.sol";

import "./libraries/LibBytes.sol";
import "./core/OpenIDVerifier.sol";

contract OpenIDAccount is SimpleAccount, OpenIDVerifier {
    event OpenIDKeyAdded(bytes32 openid_key);
    event OpenIDKeyRemoved(bytes32 openid_key);

    mapping(bytes32 => bool) public _openid_keys;

    // The constructor is used only for the "implementation" and only sets immutable values.
    // Mutable value slots for proxy accounts are set by the 'initialize' function.
    constructor(IEntryPoint anEntryPoint) SimpleAccount(anEntryPoint) {
        _disableInitializers();
    }

    function initialize(
        address owner,
        bytes32 openid_key
    ) public virtual initializer {
        super.initialize(owner);
        _openid_keys[openid_key] = true;
        emit OpenIDKeyAdded(openid_key);
    }

    function addOpenIDKey(bytes32 openid_key) public onlyOwner {
        _openid_keys[openid_key] = true;
        emit OpenIDKeyAdded(openid_key);
    }

    function removeOpenIDKey(bytes32 openid_key) public onlyOwner {
        _openid_keys[openid_key] = false;
        emit OpenIDKeyRemoved(openid_key);
    }

    /**
     * @param userOp typical userOperation
     * @param userOpHash the hash of the user operation.
     * @return validationData
     */
    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal virtual override returns (uint256) {
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("validateIDToken(uint256,bytes)")),
            uint256(0),
            userOp.signature
        );

        (bool success, bytes memory res) = address(this).call(data);
        require(success);
        (bool succ, , bytes32 issHash, bytes32 subHash, bytes32 nonceHash) = abi
            .decode(res, (bool, uint256, bytes32, bytes32, bytes32));
        require(succ, "INVALID_TOKEN");
        require(
            keccak256((LibBytes.toHex(uint256(userOpHash), 32))) == nonceHash,
            "INVALID_NONCE_HASH"
        );
        require(
            _openid_keys[keccak256(abi.encodePacked(issHash, subHash))],
            "INVALID_SUB"
        );
        return 0;
    }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external override returns (uint256 validationData) {
        validationData = _validateSignature(userOp, userOpHash);
        _payPrefund(missingAccountFunds);
    }
}

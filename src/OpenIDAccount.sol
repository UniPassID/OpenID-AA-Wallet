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
        bytes32 openid_key,
        bytes32[] memory audiences,
        bytes32[] memory key_ids,
        bytes[] memory keys
    ) public virtual initializer {
        require(key_ids.length == keys.length, "invalid key");
        super.initialize(owner);
        _openid_keys[openid_key] = true;
        emit OpenIDKeyAdded(openid_key);

        for (uint i = 0; i < audiences.length; i++) {
            openIDAudience[audiences[i]] = true;
            emit AddOpenIDAudience(audiences[i]);
        }

        for (uint i = 0; i < key_ids.length; i++) {
            openIDPublicKey[key_ids[i]] = keys[i];
            emit UpdateOpenIDPublicKey(key_ids[i], keys[i]);
        }
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
    ) internal virtual override returns (uint256 validationData) {
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("validateIDToken(bytes)")),
            userOp.signature
        );

        (bool success, bytes memory res) = address(this).call(data);
        require(success);

        bool succ;
        bytes32 issHash;
        bytes32 subHash;
        bytes32 nonceHash;
        (succ, validationData, issHash, subHash, nonceHash) = abi.decode(
            res,
            (bool, uint256, bytes32, bytes32, bytes32)
        );
        require(succ, "INVALID_TOKEN");
        require(
            keccak256((LibBytes.toHex(uint256(userOpHash), 32))) == nonceHash,
            "INVALID_NONCE_HASH"
        );
        require(
            _openid_keys[keccak256(abi.encodePacked(issHash, subHash))],
            "INVALID_SUB"
        );
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

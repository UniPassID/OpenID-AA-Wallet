// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "../OpenIDAccount.sol";

/* solhint-disable no-inline-assembly */

/**
 * Based on SimpleAccountFactory.
 * Cannot be a subclass since both constructor and createAccount depend on the
 * constructor and initializer of the actual account contract.
 */
contract OpenIDAccountFactory is Ownable {
    OpenIDAccount public immutable _accountImplementation;
    IEntryPoint public immutable _entryPoint;

    constructor(IEntryPoint entryPoint) {
        _entryPoint = entryPoint;
        _accountImplementation = new OpenIDAccount(entryPoint);
    }

    /**
     * create an account, and return its address.
     * returns the address even if the account is already deployed.
     * Note that during UserOperation execution, this method is called only if the account is not deployed.
     * This method returns an existing account address so that entryPoint.getSenderAddress() would work even after account creation
     */
    function createAccount(
        uint256 salt,
        address owner,
        bytes32 openid_key,
        bytes32[] memory audiences,
        bytes32[] memory key_ids,
        bytes[] memory keys
    ) public returns (OpenIDAccount) {
        address addr = getAddress(
            salt,
            owner,
            openid_key,
            audiences,
            key_ids,
            keys
        );
        uint codeSize = addr.code.length;
        if (codeSize > 0) {
            return OpenIDAccount(payable(addr));
        }
        return
            OpenIDAccount(
                payable(
                    new ERC1967Proxy{salt: bytes32(salt)}(
                        address(_accountImplementation),
                        abi.encodeCall(
                            OpenIDAccount.initialize,
                            (owner, openid_key, audiences, key_ids, keys)
                        )
                    )
                )
            );
    }

    /**
     * calculate the counterfactual address of this account as it would be returned by createAccount()
     */
    function getAddress(
        uint256 salt,
        address owner,
        bytes32 openid_key,
        bytes32[] memory audiences,
        bytes32[] memory key_ids,
        bytes[] memory keys
    ) public view returns (address) {
        return
            Create2.computeAddress(
                bytes32(salt),
                keccak256(
                    abi.encodePacked(
                        type(ERC1967Proxy).creationCode,
                        abi.encode(
                            address(_accountImplementation),
                            abi.encodeCall(
                                OpenIDAccount.initialize,
                                (owner, openid_key, audiences, key_ids, keys)
                            )
                        )
                    )
                )
            );
    }

    /**
     * Deposits ETH to the entry point on behalf of the contract
     */
    function deposit() public payable {
        _entryPoint.depositTo{value: msg.value}(address(this));
    }

    /**
     * Allows the owner to withdraw ETH from entrypoint contract
     */
    function withdrawTo(
        address payable withdrawAddress,
        uint256 amount
    ) public onlyOwner {
        _entryPoint.withdrawTo(withdrawAddress, amount);
    }

    /**
     * Allows the owner to add stake to the entry point
     */
    function addStake(uint32 unstakeDelaySec) external payable onlyOwner {
        _entryPoint.addStake{value: msg.value}(unstakeDelaySec);
    }

    /**
     * Allows the owner to unlock their stake from the entry point
     */
    function unlockStake() external onlyOwner {
        _entryPoint.unlockStake();
    }


    function withdrawStake(address payable withdrawAddress) external onlyOwner {
        _entryPoint.withdrawStake(withdrawAddress);
    }
}

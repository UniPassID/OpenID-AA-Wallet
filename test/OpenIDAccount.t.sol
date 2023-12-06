// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@account-abstraction/contracts/core/EntryPoint.sol";
import "@account-abstraction/contracts/samples/SimpleAccount.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@account-abstraction/contracts/interfaces/UserOperation.sol";

import "./TokenERC20.sol";
import "../src/OpenIDAccount.sol";
import "../src/core/OpenIDAccountFactory.sol";

contract OpenIDAccountTest is Test {
    OpenIDAccountFactory _factory;
    OpenIDAccount _account;
    IEntryPoint _entryPoint;

    address _admin;
    TokenERC20 _token;

    function setUp() public {
        _admin = vm.addr(0x100);
        vm.startPrank(_admin);
        _entryPoint = new EntryPoint();
        _factory = new OpenIDAccountFactory(_entryPoint);
        bytes32 openid_key = keccak256(
            abi.encodePacked(keccak256("test_issuer"), keccak256("test_user"))
        );

        bytes32[] memory audiences = new bytes32[](1);
        audiences[0] = keccak256(abi.encodePacked("test_issuer", "test_aud"));

        bytes32[] memory key_ids = new bytes32[](1);
        key_ids[0] = keccak256(abi.encodePacked("test_issuer", "test_kid"));

        bytes[] memory keys = new bytes[](1);
        keys[
            0
        ] = hex"d1b83f8a96f95e42651b74bd506dc6f6e91f1da5efcc4751c9d5c4973ba3654f1ebfc5b4d3e1a75d05f90050a0c8c69f95fe9cf95d33005c2ce50141e8af13406d668f0f587e982e723c48f63a15435c70913856345d34bd05ff9d4854cb106d51d5294372550e742ef89372e77c94b5bf46d9216ddfd13646a3ba0d06d33f8b81e10c7b8864d314028a7ba74227dc5dd9c1828ce06bedaa0d58c5200c7c13c4581c8578a4504dfc6763039af65ff231651a03fe069a3e4f15800bc52f87a075007efd63b9d761fc9b1029ea6f04b2c3fc240cd69519c0e74df6166345bc30e9c5a23b1f929d7d065f91ce12d3c0377212d78a309add8c70a3b56b922814dd83";

        _account = _factory.createAccount(
            0,
            _admin,
            openid_key,
            audiences,
            key_ids,
            keys
        );
        _token = new TokenERC20(6);
        _token.transfer(address(_account), 1000000000000);
        vm.deal(address(_account), 100 ether);
        // _entryPoint.depositTo{value: 1 ether}(address(_account));

        vm.stopPrank();
    }

    function testSimpleTransaction() public {
        bytes memory tokenTransferData = abi.encodeCall(
            ERC20.transfer,
            (vm.addr(0x101), 100000)
        );
        bytes memory data = abi.encodeCall(
            SimpleAccount.execute,
            (address(_token), 0, tokenTransferData)
        );

        UserOperation memory userOp;
        userOp.sender = address(_account);
        userOp.nonce = 0;
        userOp.callData = data;
        userOp.callGasLimit = 200000;
        userOp.verificationGasLimit = 300000;
        userOp.preVerificationGas = 21000;
        userOp.maxFeePerGas = 3e9;
        userOp.maxPriorityFeePerGas = 1e9;

        bytes32 userOpHash = _entryPoint.getUserOpHash(userOp);
        console2.log("user Op Hash");
        console2.logBytes32(userOpHash);
        userOp
            .signature = hex"0000003b00000046000000160000001e0000004f0000005800000061000000690000007400000007000000180000002c7b22616c67223a225253323536222c226b6964223a22746573745f6b6964222c22747970223a224a5754227d000000b87b22696174223a313730313834363335392c22657870223a313730313933323735392c226e6266223a313730313834363335392c22697373223a22746573745f697373756572222c22737562223a22746573745f75736572222c22617564223a22746573745f617564222c226e6f6e6365223a22307836346437363536393631656562636530343064343737373135623563376163393966623461633166616335616166653937396130633765346538316466346238227d00000100ce5194ff77588727463de4733e4173ca0036d4c7d42c37b2be20d56edf832a1108c0bc9d0ad10c4d14ddb22529731afb91af026f692ec80c85b75da9ac774870cee3f066a765db1c2ca94b60f4a8a86d98b75684b30f658c2000a893d62dc845ffaa9fc26ebeb3c61d17ce2b4949718835f088e7fb57f4bf88d1e421811951b8353ef009beffa2b583117ca59ff21f6d1e06131e9a6239f5c2281248b8f10a2e2384785cfdd8723ead5941497b397797a453c4a47790d3ddf8292e69be955500740136ff46b21b48f35fa4b60c71ede26d803f07c6c569ddcd0c44202db97ebaaab6fdb156d50a8dbed4b87a042a4c6cd277be428177695e8c58a9c67ac6bd0f";

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOp;

        vm.warp(1701846360);
        _entryPoint.handleOps(ops, payable(_admin));
    }
}

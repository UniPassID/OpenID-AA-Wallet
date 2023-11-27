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
import "../src/core/OpenIDAccount.sol";
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
            abi.encodePacked(keccak256("test_issuer"), keccak256("test_user1"))
        );
        _account = _factory.createAccount(0, _admin, openid_key);
        _account.addOpenIDAudience(
            keccak256(abi.encodePacked("test_issuer", "test_aud"))
        );
        _account.updateOpenIDPublicKey(
            keccak256(abi.encodePacked("test_issuer", "test_kid")),
            hex"d1b83f8a96f95e42651b74bd506dc6f6e91f1da5efcc4751c9d5c4973ba3654f1ebfc5b4d3e1a75d05f90050a0c8c69f95fe9cf95d33005c2ce50141e8af13406d668f0f587e982e723c48f63a15435c70913856345d34bd05ff9d4854cb106d51d5294372550e742ef89372e77c94b5bf46d9216ddfd13646a3ba0d06d33f8b81e10c7b8864d314028a7ba74227dc5dd9c1828ce06bedaa0d58c5200c7c13c4581c8578a4504dfc6763039af65ff231651a03fe069a3e4f15800bc52f87a075007efd63b9d761fc9b1029ea6f04b2c3fc240cd69519c0e74df6166345bc30e9c5a23b1f929d7d065f91ce12d3c0377212d78a309add8c70a3b56b922814dd83"
        );

        _token = new TokenERC20(6);
        _token.transfer(address(_account), 1000000000000);
        vm.deal(_admin, 100 ether);
        _entryPoint.depositTo{value: 1 ether}(address(_account));

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
            .signature = hex"0000003b00000046000000160000001e0000004f00000059000000620000006a0000007500000007000000180000002c7b22616c67223a225253323536222c226b6964223a22746573745f6b6964222c22747970223a224a5754227d000000b97b22696174223a313730313038343236352c22657870223a313730313137303636352c226e6266223a313730313038343236352c22697373223a22746573745f697373756572222c22737562223a22746573745f7573657231222c22617564223a22746573745f617564222c226e6f6e6365223a22307839623965366139393932313035623563326264306236633236613333313064346331326465363031643061653435306166613063376361386462666537346136227d00000100a9436ee5dfb1e43bb7895551616aca382e11d5f16f29fa1db094baabfe1a9e86e3771f2fd36c04f88ac93f55d208ff134b345cbf1cfc6e6c0f593bd63b9dcc10f221809ec06a85afc8d4b3ac2e9e647540c05ca54d817605399e979ed51093fabdb988a5058605432cfe5e4e7b816c5437d4455435957afe34ca9d64082c396a6dc9d02198cd2dba14a5bdd1d6c71fa5755e90cc783e17159379c693634c992d3e13454e9490424e536cb345d20d71f21d6f77d6538b936298e63a3cde0d1abb2f9d89380d1ee9ff192d8921c6856ecf9a6af7a9f590dc618740db790a3b9c18ed8e2ee744f088bf585eec011609722d34e327558e9d5c10cd105862e97dae29";

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOp;

        vm.warp(1701108025);
        _entryPoint.handleOps(ops, payable(_admin));
    }
}

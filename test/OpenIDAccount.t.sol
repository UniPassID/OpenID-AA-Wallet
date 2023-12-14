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

        _account = OpenIDAccount(
            payable(
                _factory.getAddress(
                    0,
                    _admin,
                    openid_key,
                    audiences,
                    key_ids,
                    keys
                )
            )
        );

        vm.deal(address(_account), 100 ether);
        console2.log("account address");
        console2.logAddress(address(_account));

        bytes memory initCode = abi.encodeCall(
            _factory.createAccount,
            (0, _admin, openid_key, audiences, key_ids, keys)
        );

        UserOperation memory userOp;
        userOp.sender = address(_account);
        userOp.nonce = 0;
        userOp.initCode = abi.encodePacked(address(_factory), initCode);
        userOp.callGasLimit = 200000;
        userOp.verificationGasLimit = 800000;
        userOp.preVerificationGas = 21000;
        userOp.maxFeePerGas = 3e9;
        userOp.maxPriorityFeePerGas = 1e9;

        bytes32 userOpHash = _entryPoint.getUserOpHash(userOp);
        console2.log("init user Op Hash");
        console2.logBytes32(userOpHash);

        userOp
            .signature = hex"0000003b00000046000000160000001e0000004f0000005800000061000000690000007400000007000000180000002c7b22616c67223a225253323536222c226b6964223a22746573745f6b6964222c22747970223a224a5754227d000000b87b22696174223a313730323535323036352c22657870223a313730323633383436352c226e6266223a313730323535323036352c22697373223a22746573745f697373756572222c22737562223a22746573745f75736572222c22617564223a22746573745f617564222c226e6f6e6365223a22307832306261386539613432303036643866653233353738666433663533636337336461303534333661373539343038343237383933323932633235626464373962227d000001002e3f0ef706a31cd4fd6991c21092cedd2529ea6f59b0ff00433c0abf762870618021b648688d475ab0f4e1b0be02c8b707e1b86d049e82dada721c1813f749f11d3d462fd7b093fbaffc7f5232ce27937a5e4afec4739c95896a031d18500ba528a29a1ece3046e110ee42b1d3cfa1a5b3d1a8ac7b58c78520ee3e7242a77da41950b1ee075cd0f099dccc13e469e288abba8e415c9f366ad3fef3ffafe9994de76c09ff28a331f283e7cae069c88432ff51cda14553e75fa2fe93dcb932789524436ff91b6759d7651b93ccc311dabb75c1b125d0a5f0be032cadc9b5cfaa842ee574d3c9e43a734761d3ee78a8c69197f5dd30f4a198aa34a357278fca6376";

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOp;

        vm.warp(1702552200);
        _entryPoint.handleOps(ops, payable(_admin));

        _token = new TokenERC20(6);
        _token.transfer(address(_account), 1000000000000);
        // _entryPoint.depositTo{value: 1 ether}(address(_account));

        vm.stopPrank();
    }

    function testETHTransfer() public {
        bytes memory data = abi.encodeCall(
            SimpleAccount.execute,
            (vm.addr(0x200), 0.1 ether, hex"")
        );

        UserOperation memory userOp;
        userOp.sender = address(_account);
        userOp.nonce = 1;
        userOp.callData = data;
        userOp.callGasLimit = 200000;
        userOp.verificationGasLimit = 300000;
        userOp.preVerificationGas = 21000;
        userOp.maxFeePerGas = 3e9;
        userOp.maxPriorityFeePerGas = 1e9;

        bytes32 userOpHash = _entryPoint.getUserOpHash(userOp);
        console2.log("transfer eth user Op Hash");
        console2.logBytes32(userOpHash);
        userOp
            .signature = hex"0000003b00000046000000160000001e0000004f0000005800000061000000690000007400000007000000180000002c7b22616c67223a225253323536222c226b6964223a22746573745f6b6964222c22747970223a224a5754227d000000b87b22696174223a313730323535323139342c22657870223a313730323633383539342c226e6266223a313730323535323139342c22697373223a22746573745f697373756572222c22737562223a22746573745f75736572222c22617564223a22746573745f617564222c226e6f6e6365223a22307832353065323533653666633638613666613665616266653663636461393734663730643335633033653436633961303235396631363131313262653133376264227d000001005a8173d693a4630c3472e4feb0aa01e1d4f7cf335f45fc2111593a085574c499fc82d3a16421bae4b15371fd7ba0938143128bc8aeefed080af600b0f7cdd6f5eabb68b25e778a84d0a58b37df5f9c200bb6f8142a99dd6ee869f265cf2b02a2dcdd938609ba8bad1f2a406a68754b803a86fb423bfab2e21b20d57318a1e12b939d41035ca8f851543fdb1b07054c4fd06db6f1259f2b291938284c4f613cc378bc84a63d7b00576b2d3fce39c23dbf15f0593ca8173e2dc01865fc8230fa1bb9479b5ba286cf120b82df2d24f8dc4bb9f00b18624cc97229a43db5ae5e30ff95ff3af80bf3367c325cdb60a769a963b5f387fe0ae44803d16d9f2f377ad4d9";

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOp;

        _entryPoint.handleOps(ops, payable(_admin));
    }

    function testERC20Transfer() public {
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
        userOp.nonce = 1;
        userOp.callData = data;
        userOp.callGasLimit = 200000;
        userOp.verificationGasLimit = 300000;
        userOp.preVerificationGas = 21000;
        userOp.maxFeePerGas = 3e9;
        userOp.maxPriorityFeePerGas = 1e9;

        bytes32 userOpHash = _entryPoint.getUserOpHash(userOp);
        console2.log("transfer erc20 user Op Hash");
        console2.logBytes32(userOpHash);
        userOp
            .signature = hex"0000003b00000046000000160000001e0000004f0000005800000061000000690000007400000007000000180000002c7b22616c67223a225253323536222c226b6964223a22746573745f6b6964222c22747970223a224a5754227d000000b87b22696174223a313730323535323134352c22657870223a313730323633383534352c226e6266223a313730323535323134352c22697373223a22746573745f697373756572222c22737562223a22746573745f75736572222c22617564223a22746573745f617564222c226e6f6e6365223a22307831396530613864653637653434633764336532386166656233336361633765333935626665613730646532623463613464313866613733346364353639323436227d0000010096be5403cfbe0d6de2145df60be300759dd6d107e82130115e2115d3bc22de79859b9626445c13bae87309437b03af151674d0d49864943580986d8ad794657666b3b8ed958eb91afdf6a329e59c74f4464c785ba937033caf27c6ffd1db1f19333c0386ee9b6c629aee6a44fad4a0324b655c499ed10a5505c68011c3bc9203343584c6f9a885e419e564319f6e792528f11a75f1bed0d6459b1199d3f9d1955300bb9164c70b8d33a2ad227d7ee305fbda2d65af015637df93fec33ea1a205bdb0e49b1d0d14944c240eab49e6f35ea64017c03cc0546eb26557b7b4bd41e934eb8524d3abcc17cdc2c5fcf67a5b2a77c0cd571d18b26f34e2409e998d8123";

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOp;

        _entryPoint.handleOps(ops, payable(_admin));
    }
}

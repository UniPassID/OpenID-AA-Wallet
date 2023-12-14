// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "../libraries/LibRsa.sol";
import "../libraries/LibBytes.sol";
import "../libraries/LibBase64.sol";
import "./AudManager.sol";
import "./OpenIDKeyManager.sol";

import "@openzeppelin/contracts/utils/Strings.sol";

abstract contract OpenIDVerifier is OpenIDKeyManager, AudManager {
    using LibBytes for bytes;

    enum OpenIDParamsIndex {
        issLeftIndex,
        issRightIndex,
        kidLeftIndex,
        kidRightIndex,
        subLeftIndex,
        subRightIndex,
        audLeftIndex,
        audRightIndex,
        nonceLeftIndex,
        iatLeftIndex,
        expLeftIndex
    }
    uint256 constant OpenIDParamsIndexNum = 11;

    function _validateTimestamp(
        bytes calldata _data,
        bytes calldata _payload
    ) private pure returns (uint256 validationData) {
        bytes calldata iat;
        {
            uint32 iatLeftIndex;
            (iatLeftIndex, ) = _data.cReadUint32(
                uint256(OpenIDParamsIndex.iatLeftIndex) * 4
            );

            require(
                bytes32(_payload[iatLeftIndex - 6:iatLeftIndex]) ==
                    bytes32('"iat":'),
                "_validateTimestamp: INVALID_IAT"
            );
            iat = _payload[iatLeftIndex:iatLeftIndex + 10];
        }

        bytes calldata exp;
        {
            uint32 expLeftIndex;
            (expLeftIndex, ) = _data.cReadUint32(
                uint256(OpenIDParamsIndex.expLeftIndex) * 4
            );

            require(
                bytes32(_payload[expLeftIndex - 6:expLeftIndex]) ==
                    bytes32('"exp":'),
                "_validateTimestamp: INVALID_EXP"
            );
            exp = _payload[expLeftIndex:expLeftIndex + 10];
        }

        validationData |= exp.toNum() << 160;
        validationData |= iat.toNum() << (48 + 160);
    }

    function validateRsa(
        bytes calldata _data
    ) public view returns (bool succ, bytes32 issHash, bytes calldata payload) {
        bytes calldata header;
        bytes calldata signature;
        {
            uint256 index = OpenIDParamsIndexNum * 4;
            uint32 len;
            (len, index) = _data.cReadUint32(index);
            header = _data[index:index + len];
            index += len;
            (len, index) = _data.cReadUint32(index);
            payload = _data[index:index + len];
            index += len;
            (len, index) = _data.cReadUint32(index);
            signature = _data[index:index + len];
        }
        {
            bytes memory publicKey;
            (issHash, publicKey) = _getPublicKeyAndIssHash(
                _data,
                header,
                payload
            );
            succ = LibRsa.rsapkcs1Verify(
                sha256(
                    abi.encodePacked(
                        LibBase64.urlEncode(header),
                        ".",
                        LibBase64.urlEncode(payload)
                    )
                ),
                publicKey,
                hex"010001",
                signature
            );
        }
    }

    function validateIDToken(
        bytes calldata _data
    )
        external
        view
        returns (
            bool succ,
            uint256 validationData,
            bytes32 issHash,
            bytes32 subHash,
            bytes32 nonceHash
        )
    {
        bytes calldata payload;
        (succ, issHash, payload) = validateRsa(_data);
        validationData = _validateTimestamp(_data, payload);
        nonceHash = keccak256(_getNonce(_data, payload));
        subHash = keccak256(_getSub(_data, payload));
    }

    function _getNonce(
        bytes calldata _data,
        bytes calldata _payload
    ) internal pure returns (bytes calldata nonce) {
        uint32 nonceLeftIndex;
        (nonceLeftIndex, ) = _data.cReadUint32(
            uint256(OpenIDParamsIndex.nonceLeftIndex) * 4
        );

        require(
            bytes32(_payload[nonceLeftIndex - 9:nonceLeftIndex]) ==
                bytes32('"nonce":"'),
            "_getNonce: INVALID_NONCE"
        );
        nonce = _payload[nonceLeftIndex:nonceLeftIndex + 66];
    }

    function _getSub(
        bytes calldata _data,
        bytes calldata _payload
    ) internal pure returns (bytes calldata sub) {
        uint32 subLeftIndex;
        (subLeftIndex, ) = _data.cReadUint32(
            uint256(OpenIDParamsIndex.subLeftIndex) * 4
        );
        require(
            bytes7(_payload[subLeftIndex - 7:subLeftIndex]) ==
                bytes7('"sub":"'),
            "_getSub: INVALID_SUB_LEFT"
        );

        uint32 subRightIndex;
        (subRightIndex, ) = _data.cReadUint32(
            uint256(OpenIDParamsIndex.subRightIndex) * 4
        );
        bytes2 suffix = bytes2(_payload[subRightIndex:subRightIndex + 2]);
        require(
            suffix == bytes2('",') || suffix == bytes2('"}'),
            "_getSub: INVALID_SUB_RIGHT"
        );

        sub = _payload[subLeftIndex:subRightIndex];
    }

    function _getPublicKeyAndIssHash(
        bytes calldata _data,
        bytes calldata _header,
        bytes calldata _payload
    ) private view returns (bytes32 issHash, bytes memory publicKey) {
        bytes calldata iss = _getIss(_data, _payload);
        issHash = keccak256(iss);

        bytes calldata aud = _getAud(_data, _payload);
        require(
            isAudienceValid(keccak256(abi.encodePacked(iss, aud))),
            "_getPublicKeyAndIssHash: INVALID_AUD"
        );

        bytes memory kid = _getKid(_data, _header);
        publicKey = getOpenIDPublicKey(keccak256(abi.encodePacked(iss, kid)));
        require(
            publicKey.length > 0,
            "_getPublicKeyAndIssHash: INVALID_PUB_KEY"
        );
    }

    function _getIss(
        bytes calldata _data,
        bytes calldata _payload
    ) internal pure returns (bytes calldata iss) {
        uint32 issLeftIndex;
        (issLeftIndex, ) = _data.cReadUint32(
            uint256(OpenIDParamsIndex.issLeftIndex) * 4
        );
        require(
            bytes7(_payload[issLeftIndex - 7:issLeftIndex]) ==
                bytes7('"iss":"'),
            "_getIss: INVALID_ISS_LEFT"
        );

        uint32 issRightIndex;
        (issRightIndex, ) = _data.cReadUint32(
            uint256(OpenIDParamsIndex.issRightIndex) * 4
        );
        bytes2 suffix = bytes2(_payload[issRightIndex:issRightIndex + 2]);
        require(
            suffix == bytes2('",') || suffix == bytes2('"}'),
            "_getIss: INVALID_ISS_RIGHT"
        );

        iss = _payload[issLeftIndex:issRightIndex];
    }

    function _getKid(
        bytes calldata _data,
        bytes calldata _header
    ) internal pure returns (bytes calldata kid) {
        uint32 kidLeftIndex;
        (kidLeftIndex, ) = _data.cReadUint32(
            uint256(OpenIDParamsIndex.kidLeftIndex) * 4
        );
        require(
            bytes7(_header[kidLeftIndex - 7:kidLeftIndex]) == bytes7('"kid":"'),
            "_getKid: INVALID_KID_LEFT"
        );

        uint32 kidRightIndex;
        (kidRightIndex, ) = _data.cReadUint32(
            uint256(OpenIDParamsIndex.kidRightIndex) * 4
        );
        bytes2 suffix = bytes2(_header[kidRightIndex:kidRightIndex + 2]);
        require(
            suffix == bytes2('",') || suffix == bytes2('"}'),
            "_getKid: INVALID_KID_RIGHT"
        );

        kid = _header[kidLeftIndex:kidRightIndex];
    }

    function _getAud(
        bytes calldata _data,
        bytes calldata _payload
    ) internal pure returns (bytes calldata aud) {
        uint32 audLeftIndex;
        (audLeftIndex, ) = _data.cReadUint32(
            uint256(OpenIDParamsIndex.audLeftIndex) * 4
        );
        require(
            bytes7(_payload[audLeftIndex - 7:audLeftIndex]) ==
                bytes7('"aud":"'),
            "_getAud: INVALID_AUD_LEFT"
        );

        uint32 audRightIndex;
        (audRightIndex, ) = _data.cReadUint32(
            uint256(OpenIDParamsIndex.audRightIndex) * 4
        );
        bytes2 suffix = bytes2(_payload[audRightIndex:audRightIndex + 2]);
        require(
            suffix == bytes2('",') || suffix == bytes2('"}'),
            "_getAud: INVALID_AUD_RIGHT"
        );

        aud = _payload[audLeftIndex:audRightIndex];
    }
}

# OpenID-AA-Wallet

## initialize

```solidity
function initialize(
    address owner,
    bytes32 openid_key,
    bytes32[] memory audiences,
    bytes32[] memory key_ids,
    bytes[] memory keys
)
```

+ owner: owner can update audiences, key_id and key.
+ openid_key: keccak256(abi.encodePacked(issHash, subHash)), iss is hash of issuer, subhash is hash of subject
+ audience: Expected recipient(s). Must contain some identifier for client, for example the Client ID or domain.
+ key_id: The key id. The key is found on the Json Web Key Set (JWKS) endpoint of the issuer.
+ key: public key of specified key_id

## validateUserOp

signature of userOP is idtoken, istoken.nonce is userOpHash.

## updateOpenIDPublicKey

owner can update a key with publicKey

```solidity
function updateOpenIDPublicKey(
    bytes32 _key,
    bytes calldata _publicKey
) external onlyOwner
```

## OpenIDAudience

owner can add or delete audiences

### add
```solidity
addOpenIDAudience(bytes32 _key) external onlyOwner
```

## delete
```solidity
function deleteOpenIDAudience(bytes32 _key) external onlyOwner
```
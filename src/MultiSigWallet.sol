// src/MultiSigWallet.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title MultiSigWallet
 * @notice A k-of-n multisig using off-chain ECDSA signatures.
 *         - The contract adds the "\x19Ethereum Signed Message:\n32" prefix internally.
 *         - Each signer must sign only the raw portion (no prefix).
 *         - Any address can submit if they gather enough signatures.
 */
contract MultiSigWallet {
    address[] public signers;
    mapping(address => bool) public isSigner;
    uint256 public threshold;  
    uint256 public nonce;      

    event ExecuteTransaction(
        address indexed executor,
        address indexed to,
        uint256 value,
        bytes data,
        uint256 indexed usedNonce
    );
    event SignersUpdated(address[] newSigners, uint256 newThreshold);

    constructor(address[] memory _signers, uint256 _threshold) {
        require(_threshold > 0 && _threshold <= _signers.length, "Bad threshold");

        for (uint256 i = 0; i < _signers.length; i++) {
            address s = _signers[i];
            require(s != address(0), "Zero address");
            require(!isSigner[s], "Duplicate signer");
            isSigner[s] = true;
        }
        signers = _signers;
        threshold = _threshold;
        nonce = 0;
    }

    function executeTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        bytes[] calldata signatures
    ) external {
        bytes32 txHash = _getTxHash(to, value, data, nonce, block.chainid);
        _validateSignatures(txHash, signatures);

        uint256 currentNonce = nonce;
        nonce++;

        (bool success, ) = to.call{value: value}(data);
        require(success, "Tx failed");

        emit ExecuteTransaction(msg.sender, to, value, data, currentNonce);
    }

    function updateSigners(address[] calldata newSigners, uint256 newThreshold) external {
        require(msg.sender == address(this), "Only self-call");
        require(newThreshold > 0 && newThreshold <= newSigners.length, "Bad threshold");

        for (uint256 i = 0; i < signers.length; i++) {
            isSigner[signers[i]] = false;
        }
        for (uint256 i = 0; i < newSigners.length; i++) {
            address s = newSigners[i];
            require(s != address(0), "Zero address");
            require(!isSigner[s], "Duplicate signer");
            isSigner[s] = true;
        }
        signers = newSigners;
        threshold = newThreshold;
        emit SignersUpdated(newSigners, newThreshold);
    }

    function _getTxHash(
        address to,
        uint256 value,
        bytes calldata data,
        uint256 _nonce,
        uint256 chainId
    ) internal view returns (bytes32) {
        bytes32 rawHash = keccak256(
            abi.encodePacked(address(this), chainId, to, value, data, _nonce)
        );
        return keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", rawHash)
        );
    }

    function _validateSignatures(bytes32 txHash, bytes[] calldata signatures) internal view {
        uint256 validCount;
        address[] memory usedSigners = new address[](signatures.length);

        for (uint256 i = 0; i < signatures.length; i++) {
            address recovered = _recover(txHash, signatures[i]);
            if (isSigner[recovered]) {
                bool duplicate = false;
                for (uint256 j = 0; j < validCount; j++) {
                    if (usedSigners[j] == recovered) {
                        duplicate = true;
                        break;
                    }
                }
                if (!duplicate) {
                    usedSigners[validCount] = recovered;
                    validCount++;
                    if (validCount == threshold) {
                        break;
                    }
                }
            }
        }
        require(validCount >= threshold, "Not enough valid signatures");
    }

    function _recover(bytes32 _hash, bytes calldata sig) internal pure returns (address) {
        require(sig.length == 65, "Invalid sig length");
        bytes memory tempSig = sig;

        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(tempSig, 0x20))
            s := mload(add(tempSig, 0x40))
            v := byte(0, mload(add(tempSig, 0x60)))
        }
        require(v == 27 || v == 28, "Invalid v");
        address signer = ecrecover(_hash, v, r, s);
        require(signer != address(0), "Invalid signer");
        return signer;
    }

    receive() external payable {}
}
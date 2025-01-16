# k-of-n Multisig & ERC20 Integration
![multisig](https://github.com/user-attachments/assets/e5e8774f-966e-4215-ae5a-72404fe80fc3)

A **threshold-based** (k-of-n) multisig wallet that collects **off-chain ECDSA signatures** and executes transactions **on-chain** with replay protection, plus an **ERC20** token example demonstrating restricted `mint` & `burn`, and a single address for pause/unpause.

---

## Overview

This repository contains:

- **`MultiSigWallet.sol`**: A general-purpose k-of-n multisig contract that:
  - Uses off-chain ECDSA signatures (personal_sign style).
  - Executes arbitrary calls on any contract if threshold signers approve.
  - Tracks a `nonce` for replay protection.
  - Allows signers to update their own set (`updateSigners(...)`).

- **`MyERC20v2.sol`**: An ERC20 token that:
  - Restricts `mint` & `burn` to a **k-of-n** multisig (e.g., 4-of-6).
  - Allows a single address (the "pauser") to `pause()`/`unpause()` the token.
  - Demonstrates real-world privileged operations governed by threshold-based or single-authority logic.

**Key Idea**:  
Gather partial signatures off-chain to reduce gas usage. Then, submit them on-chain in one transaction. The contract verifies the signatures, checks the threshold, increments a nonce, and invokes the target method.

---

## Features

1. **Threshold Governance**  
   - `k-of-n` signers must provide valid ECDSA signatures to authorize a transaction.

2. **Arbitrary Call Execution**  
   - `executeTransaction(...)` can invoke **any** function on **any** contract, providing custom calldata and optional ETH value.

3. **Off-Chain ECDSA**  
   - Each signer signs a digest containing `(address(this), chainId, to, value, data, nonce)`.
   - The contract appends `\x19Ethereum Signed Message:\n32` for personal_sign.

4. **Updateable Signers**  
   - The signer set can be replaced or modified by calling `updateSigners(...)` via a valid transaction from the multisig itself.

5. **ERC20 Example**  
   - `mint(...)` & `burn(...)` restricted to a 4-of-6 multisig address.
   - A single `pauser` can freeze the token if needed.

---

## Architecture

### 1. MultiSigWallet

- **Storage**:  
  - `signers[]`, `mapping(address => bool) isSigner`, `threshold`, `nonce`.
- **executeTransaction(...)**:  
  1. Accepts `(to, value, data, signatures[])`.  
  2. Verifies each signature with `ecrecover` and ensures membership in `signers[]`.  
  3. Requires `validCount >= threshold` to succeed.  
  4. If valid, increments `nonce` and does `(bool success, ) = to.call{value: value}(data)`.
- **updateSigners(...)**:  
  - Only callable by the contract itself (`require(msg.sender == address(this))`), so it also needs threshold-based approval.  
  - Replaces the signers and threshold.
- **Chain ID**:  
  - Embedded in the hashed data to localize signatures to one network.

### 2. MyERC20v2

- **Standard ERC20** with `transfer`, `approve`, `transferFrom`, plus:  
  - `mint(...)` & `burn(...)` → Only the `multiSigMintBurn` address (4-of-6).  
  - `pause()` & `unpause()` → A single address sets `paused = true/false`.  
  - If `paused == true`, all user transfers or approvals revert.

**Off-Chain Flow**:  
1. Each signer reviews `(to, value, data, nonce, chainId, contract address)` offline.  
2. Each provides `(r, s, v)` to an aggregator.

**On-Chain Flow**:  
- `executeTransaction(...)` is called with the aggregated signatures.  
- If enough signers are valid, the contract calls the target function.

---

## Installation & Setup

### Prerequisites

- **Foundry**:  
  ```bash
  curl -L https://foundry.paradigm.xyz | bash
  foundryup

// test/MyERC20v2Test.t.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/MultiSigWallet.sol";
import "../src/MultiSigERC20.sol";

/**
 * @dev Foundry test:
 *      - 4-of-6 multiSig for mint/burn
 *      - a single `pauser` address for pause/unpause
 */
contract MultiSigERC20Test is Test {
    MultiSigWallet internal multiSigMintBurn;
    MultiSigERC20 internal token;

    // We'll define 6 private keys for the 4-of-6 wallet
    uint256 private mb1 = 0xAAA1111111111111111111111111111111111111111111111111111111111101;
    uint256 private mb2 = 0xAAA2222222222222222222222222222222222222222222222222222222222202;
    uint256 private mb3 = 0xAAA3333333333333333333333333333333333333333333333333333333333303;
    uint256 private mb4 = 0xAAA4444444444444444444444444444444444444444444444444444444444404;
    uint256 private mb5 = 0xAAA5555555555555555555555555555555555555555555555555555555555505;
    uint256 private mb6 = 0xAAA6666666666666666666666666666666666666666666666666666666666606;

    address private mbAddr1; 
    address private mbAddr2; 
    address private mbAddr3; 
    address private mbAddr4; 
    address private mbAddr5; 
    address private mbAddr6; 

    // Single pauser address
    address private pauser;  // normal EOA, not a multisig

    function setUp() public {
        // Derive addresses
        mbAddr1 = vm.addr(mb1);
        mbAddr2 = vm.addr(mb2);
        mbAddr3 = vm.addr(mb3);
        mbAddr4 = vm.addr(mb4);
        mbAddr5 = vm.addr(mb5);
        mbAddr6 = vm.addr(mb6);

        address[] memory mbSigners = new address[](6);
        mbSigners[0] = mbAddr1;
        mbSigners[1] = mbAddr2;
        mbSigners[2] = mbAddr3;
        mbSigners[3] = mbAddr4;
        mbSigners[4] = mbAddr5;
        mbSigners[5] = mbAddr6;

        // Deploy the 4-of-6 multiSig
        multiSigMintBurn = new MultiSigWallet(mbSigners, 4);

        // Just pick some random address as pauser
        pauser = address(0x99999);

        // Deploy the token
        token = new MultiSigERC20(
            "MyToken",
            "MTK",
            18,
            address(multiSigMintBurn), // 4-of-6
            pauser                      // single EOA
        );
    }

    // =========== TESTS ===========

    /**
     * Normal user tries to mint => revert
     */
    function testCannotMintFromUser() public {
        vm.expectRevert("Only multiSig can mint");
        token.mint(address(1234), 1000);
    }

    /**
     * The 4-of-6 multiSig can mint by collecting 4 signatures
     */
    function testMintBy4of6() public {
        _mintBy4of6(address(8888), 500);
        assertEq(token.balanceOf(address(8888)), 500);
    }

    /**
     * Pauser can pause -> transfers revert
     */
    function testPause() public {
        // first, mint tokens to a user
        _mintBy4of6(address(7777), 500);

        // check user can transfer while not paused
        vm.prank(address(7777));
        token.transfer(address(5555), 200);
        assertEq(token.balanceOf(address(7777)), 300);

        // now, pauser calls pause
        vm.prank(pauser);
        token.pause();

        // user tries to transfer => revert
        vm.prank(address(7777));
        vm.expectRevert(bytes("Token paused"));
        token.transfer(address(5555), 50);
    }

    /**
     * Show that the 4-of-6 can burn tokens
     */
    function testBurnBy4of6() public {
        _mintBy4of6(address(9999), 1000);
        assertEq(token.balanceOf(address(9999)), 1000);

        // burn 300
        _burnBy4of6(address(9999), 300);
        assertEq(token.balanceOf(address(9999)), 700);
        assertEq(token.totalSupply(), 700);
    }

    // ========== Helper functions for 4-of-6 minted calls ==========

    function _mintBy4of6(address to, uint256 amount) internal {
        bytes memory data = abi.encodeWithSelector(token.mint.selector, to, amount);

        bytes32 rawHash = keccak256(
            abi.encodePacked(
                address(multiSigMintBurn),
                block.chainid,
                address(token),
                uint256(0),
                data,
                multiSigMintBurn.nonce()
            )
        );
        bytes32 finalHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", rawHash)
        );

        // gather 4 sigs
        bytes memory sig1 = _sign(mb1, finalHash);
        bytes memory sig2 = _sign(mb2, finalHash);
        bytes memory sig3 = _sign(mb3, finalHash);
        bytes memory sig4 = _sign(mb4, finalHash);

        bytes[] memory signatures = new bytes[](4);
        signatures[0] = sig1;
        signatures[1] = sig2;
        signatures[2] = sig3;
        signatures[3] = sig4;

        vm.prank(mbAddr5); 
        multiSigMintBurn.executeTransaction(address(token), 0, data, signatures);
    }

    function _burnBy4of6(address from, uint256 amount) internal {
        bytes memory data = abi.encodeWithSelector(token.burn.selector, from, amount);

        bytes32 rawHash = keccak256(
            abi.encodePacked(
                address(multiSigMintBurn),
                block.chainid,
                address(token),
                uint256(0),
                data,
                multiSigMintBurn.nonce()
            )
        );
        bytes32 finalHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", rawHash)
        );

        bytes memory sig1 = _sign(mb1, finalHash);
        bytes memory sig2 = _sign(mb2, finalHash);
        bytes memory sig3 = _sign(mb3, finalHash);
        bytes memory sig4 = _sign(mb4, finalHash);

        bytes[] memory signatures = new bytes[](4);
        signatures[0] = sig1;
        signatures[1] = sig2;
        signatures[2] = sig3;
        signatures[3] = sig4;

        vm.prank(mbAddr6);
        multiSigMintBurn.executeTransaction(address(token), 0, data, signatures);
    }

    function _sign(uint256 privateKey, bytes32 finalHash) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, finalHash);
        return abi.encodePacked(r, s, v);
    }
}
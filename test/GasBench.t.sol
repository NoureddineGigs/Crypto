// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import 'forge-std/Test.sol';
import '../contracts/benchmark/MyTokenVariants.sol';

/// @title Benchmark gas pour la Partie 6 (Q2 / Q3)
/// @dev Lancer : forge test --match-contract GasBench -vv
///      Chaque variante est mesurée dans un test isolé (état neuf), avec le même protocole :
///      1) warm-up : un transfert vers `warm` (chauffe le slot de msg.sender et le compte du contrat)
///      2) COLD : transfert vers `fresh` (slot destinataire froid, 0 -> non-zero : SSTORE 22 100)
///      3) WARM : second transfert vers `fresh` (slot chaud, non-zero -> non-zero : SSTORE 2 900)
///      4) REVERT : transfert d'un montant > solde (chemin d'erreur)
///      La mesure gasleft() inclut le coût de l'appel externe (identique pour toutes les variantes).
contract GasBench is Test {
    address warm = makeAddr('warm');
    address fresh = makeAddr('fresh');

    function _run(function(address, uint256) external returns (bool) f, string memory label) internal {
        f(warm, 1 ether); // warm-up
        uint256 g0 = gasleft();
        f(fresh, 1 ether);
        uint256 cold = g0 - gasleft();
        g0 = gasleft();
        f(fresh, 1 ether);
        uint256 warmCost = g0 - gasleft();
        console.log(label);
        console.log('  transfer COLD recipient :', cold);
        console.log('  transfer WARM recipient :', warmCost);
    }

    function _runRevert(address target, bytes4 sel, string memory label) internal {
        (bool ok,) = target.call(abi.encodeWithSelector(sel, warm, 1 ether)); // warm-up (échoue aussi)
        assertFalse(ok);
        uint256 g0 = gasleft();
        (ok,) = target.call(abi.encodeWithSelector(sel, warm, 1 ether));
        uint256 g = g0 - gasleft();
        assertFalse(ok);
        console.log(label);
        console.log('  transfer REVERT (solde insuffisant):', g);
    }

    function test_Gas_A_UncheckedCustomError() public {
        TransferOptimized t = new TransferOptimized(1_000_000 ether);
        _run(t.transfer, '[A] unchecked + custom error (= MyToken)');
        _runRevert(address(new TransferOptimized(0)), TransferOptimized.transfer.selector, '[A] unchecked + custom error');
        console.log('  runtime bytecode size :', address(t).code.length);
    }

    function test_Gas_B_CheckedCustomError() public {
        TransferChecked t = new TransferChecked(1_000_000 ether);
        _run(t.transfer, '[B] checked (sans unchecked) + custom error');
        console.log('  runtime bytecode size :', address(t).code.length);
    }

    function test_Gas_C_UncheckedRequireString() public {
        TransferRequire t = new TransferRequire(1_000_000 ether);
        _run(t.transfer, '[C] unchecked + require(string)');
        _runRevert(address(new TransferRequire(0)), TransferRequire.transfer.selector, '[C] unchecked + require(string)');
        console.log('  runtime bytecode size :', address(t).code.length);
    }
}

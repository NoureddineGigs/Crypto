// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import 'forge-std/Test.sol';
import '../contracts/MyToken.sol';

/// @dev Handler pour le test d'invariant : Foundry appelle aléatoirement ces fonctions
///      avec des entrées fuzzées ; on borne les entrées pour rester dans des scénarios valides.
contract Handler is Test {
    MyToken public token;
    address public owner;
    address[] public actors;

    constructor(MyToken _token, address _owner) {
        token = _token;
        owner = _owner;
        actors.push(_owner);
        actors.push(makeAddr('alice'));
        actors.push(makeAddr('bob'));
        actors.push(makeAddr('carol'));
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) external {
        address from = _actor(fromSeed);
        address to = _actor(toSeed);
        amount = bound(amount, 0, token.balanceOf(from));
        vm.prank(from);
        token.transfer(to, amount);
    }

    function approveAndTransferFrom(uint256 fromSeed, uint256 spenderSeed, uint256 toSeed, uint256 amount) external {
        address from = _actor(fromSeed);
        address spender = _actor(spenderSeed);
        address to = _actor(toSeed);
        amount = bound(amount, 0, token.balanceOf(from));
        vm.prank(from);
        token.approve(spender, amount);
        vm.prank(spender);
        token.transferFrom(from, to, amount);
    }

    function mint(uint256 toSeed, uint256 amount) external {
        amount = bound(amount, 1, 1_000_000 ether);
        vm.prank(owner);
        token.mint(_actor(toSeed), amount);
    }

    function burn(uint256 fromSeed, uint256 amount) external {
        address from = _actor(fromSeed);
        amount = bound(amount, 0, token.balanceOf(from));
        vm.prank(from);
        token.burn(amount);
    }

    function actorsLength() external view returns (uint256) {
        return actors.length;
    }
}

contract MyTokenTest is Test {
    MyToken token;
    Handler handler;
    address owner = makeAddr('owner');
    address alice = makeAddr('alice');
    address bob = makeAddr('bob');
    uint256 SUPPLY = 1_000_000 ether;

    // Events redéclarés pour vm.expectEmit
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setUp() public {
        vm.prank(owner);
        token = new MyToken('MyToken', 'MTK', 18, SUPPLY);

        // Handler pour l'invariant : seules ses fonctions sont appelées par le fuzzer
        handler = new Handler(token, owner);
        targetContract(address(handler));
    }

    // --- Tests unitaires ---
    function test_InitialState() public view {
        // TODO 1
        assertEq(token.name(), 'MyToken');
        assertEq(token.symbol(), 'MTK');
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(owner), SUPPLY);
        assertEq(token.owner(), owner);
    }

    function test_Transfer() public {
        uint256 amount = 100 ether;
        vm.prank(owner);
        // TODO 2
        vm.expectEmit(true, true, false, true);
        emit Transfer(owner, alice, amount);
        bool ok = token.transfer(alice, amount);
        assertTrue(ok);
        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(owner), SUPPLY - amount);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_RevertIf_InsufficientBalance() public {
        // TODO 3
        vm.expectRevert(abi.encodeWithSelector(MyToken.InsufficientBalance.selector, 0, 1 ether));
        vm.prank(alice);
        token.transfer(bob, 1 ether);
    }

    function test_RevertIf_TransferToZeroAddress() public {
        vm.expectRevert(MyToken.ZeroAddress.selector);
        vm.prank(owner);
        token.transfer(address(0), 1);
    }

    function test_Approve_EmitsAndSetsAllowance() public {
        vm.expectEmit(true, true, false, true);
        emit Approval(owner, alice, 500 ether);
        vm.prank(owner);
        token.approve(alice, 500 ether);
        assertEq(token.allowance(owner, alice), 500 ether);
    }

    function test_RevertIf_ApproveZeroAddress() public {
        vm.expectRevert(MyToken.ZeroAddress.selector);
        vm.prank(owner);
        token.approve(address(0), 1);
    }

    function test_TransferFrom_DecrementsAllowance() public {
        vm.prank(owner);
        token.approve(alice, 500 ether);
        vm.prank(alice);
        token.transferFrom(owner, bob, 200 ether);
        assertEq(token.balanceOf(bob), 200 ether);
        assertEq(token.allowance(owner, alice), 300 ether);
    }

    function test_TransferFrom_InfiniteApprovalNotDecremented() public {
        vm.prank(owner);
        token.approve(alice, type(uint256).max);
        vm.prank(alice);
        token.transferFrom(owner, bob, 1000 ether);
        assertEq(token.allowance(owner, alice), type(uint256).max);
    }

    function test_RevertIf_TransferFromToZeroAddress() public {
        vm.prank(owner);
        token.approve(alice, 1);
        vm.expectRevert(MyToken.ZeroAddress.selector);
        vm.prank(alice);
        token.transferFrom(owner, address(0), 1);
    }

    function test_Mint_OnlyOwner() public {
        vm.prank(owner);
        token.mint(alice, 10 ether);
        assertEq(token.balanceOf(alice), 10 ether);
        assertEq(token.totalSupply(), SUPPLY + 10 ether);

        vm.expectRevert(MyToken.Unauthorized.selector);
        vm.prank(alice);
        token.mint(alice, 1);
    }

    function test_RevertIf_MintZero() public {
        vm.startPrank(owner);
        vm.expectRevert(MyToken.ZeroAddress.selector);
        token.mint(address(0), 1);
        vm.expectRevert(MyToken.ZeroAmount.selector);
        token.mint(alice, 0);
        vm.stopPrank();
    }

    function test_Burn() public {
        vm.prank(owner);
        token.transfer(alice, 10 ether);
        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, address(0), 10 ether);
        vm.prank(alice);
        token.burn(10 ether);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), SUPPLY - 10 ether);
    }

    function test_RevertIf_BurnTooMuch() public {
        vm.expectRevert(abi.encodeWithSelector(MyToken.InsufficientBalance.selector, 0, 1));
        vm.prank(alice);
        token.burn(1);
    }

    function test_TransferOwnership() public {
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(owner, alice);
        vm.prank(owner);
        token.transferOwnership(alice);
        assertEq(token.owner(), alice);

        vm.expectRevert(MyToken.Unauthorized.selector);
        vm.prank(owner);
        token.mint(bob, 1);

        vm.expectRevert(MyToken.ZeroAddress.selector);
        vm.prank(alice);
        token.transferOwnership(address(0));

        vm.expectRevert(MyToken.Unauthorized.selector);
        vm.prank(bob);
        token.transferOwnership(bob);
    }

    /// @dev vm.deal : on donne de l'ETH à alice pour vérifier qu'un transfert ERC-20 n'implique aucun ETH
    function test_TransferDoesNotMoveEth() public {
        vm.deal(alice, 1 ether);
        vm.prank(owner);
        token.transfer(alice, 1 ether);
        assertEq(alice.balance, 1 ether);
        assertEq(address(token).balance, 0);
    }

    // --- Tests de fuzzing ---
    /// @notice Le fuzzing génère 256 valeurs aléatoires pour (to, amount)
    function testFuzz_TransferConservesTotalSupply(address to, uint256 amount) public {
        // TODO 4
        vm.assume(to != address(0) && to != owner);
        amount = bound(amount, 0, SUPPLY);

        uint256 supplyBefore = token.totalSupply();
        vm.prank(owner);
        token.transfer(to, amount);

        assertEq(token.totalSupply(), supplyBefore);
        assertEq(token.balanceOf(to), amount);
        assertEq(token.balanceOf(owner), SUPPLY - amount);
        assertEq(token.balanceOf(owner) + token.balanceOf(to), SUPPLY);
    }

    function testFuzz_ApproveAndTransferFrom(uint256 approveAmt, uint256 transferAmt) public {
        // TODO 5
        // approveAmt < max pour ne pas tomber dans le cas "infinite approval" ; transferAmt <= SUPPLY
        approveAmt = bound(approveAmt, 0, type(uint256).max - 1);
        transferAmt = bound(transferAmt, 0, SUPPLY);

        vm.prank(owner);
        token.approve(alice, approveAmt);

        if (transferAmt > approveAmt) {
            vm.expectRevert(
                abi.encodeWithSelector(MyToken.InsufficientAllowance.selector, approveAmt, transferAmt)
            );
            vm.prank(alice);
            token.transferFrom(owner, bob, transferAmt);
        } else {
            vm.prank(alice);
            token.transferFrom(owner, bob, transferAmt);
            assertEq(token.balanceOf(bob), transferAmt);
            assertEq(token.allowance(owner, alice), approveAmt - transferAmt);
        }
    }

    function testFuzz_InfiniteApprovalNeverDecrements(uint256 transferAmt) public {
        transferAmt = bound(transferAmt, 0, SUPPLY);
        vm.prank(owner);
        token.approve(alice, type(uint256).max);
        vm.prank(alice);
        token.transferFrom(owner, bob, transferAmt);
        assertEq(token.allowance(owner, alice), type(uint256).max);
    }

    function testFuzz_MintBurnRoundTrip(address to, uint256 amount) public {
        vm.assume(to != address(0));
        amount = bound(amount, 1, type(uint256).max - SUPPLY); // évite l'overflow de totalSupply
        vm.prank(owner);
        token.mint(to, amount);
        assertEq(token.totalSupply(), SUPPLY + amount);
        vm.prank(to);
        token.burn(amount);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(to), to == owner ? SUPPLY : 0);
    }

    // --- Invariants ---
    /// @notice Foundry appellera cet invariant après chaque séquence d'actions du Handler
    function invariant_totalSupplyIsConsistent() public view {
        // TODO 6 : totalSupply == somme des balances de tous les acteurs
        uint256 sum;
        uint256 n = handler.actorsLength();
        for (uint256 i = 0; i < n; i++) {
            sum += token.balanceOf(handler.actors(i));
        }
        assertEq(token.totalSupply(), sum);
    }
}

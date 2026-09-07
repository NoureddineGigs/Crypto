// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Variantes de MyToken utilisées UNIQUEMENT pour l'analyse gas (Partie 6, Q2 et Q3)
/// @dev Contrat minimal reproduisant transfer() de MyToken avec/sans `unchecked`
///      et avec `require(string)` au lieu d'une erreur custom.

/// @notice Référence : unchecked + erreur custom (identique à MyToken.transfer)
contract TransferOptimized {
    error InsufficientBalance(uint256 available, uint256 required);
    error ZeroAddress();
    mapping(address => uint256) public balanceOf;
    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor(uint256 supply) { balanceOf[msg.sender] = supply; }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        uint256 bal = balanceOf[msg.sender];
        if (bal < amount) revert InsufficientBalance(bal, amount);
        unchecked {
            balanceOf[msg.sender] = bal - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(msg.sender, to, amount);
        return true;
    }
}

/// @notice Q2 : même code SANS le bloc unchecked (arithmétique vérifiée par le compilateur)
contract TransferChecked {
    error InsufficientBalance(uint256 available, uint256 required);
    error ZeroAddress();
    mapping(address => uint256) public balanceOf;
    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor(uint256 supply) { balanceOf[msg.sender] = supply; }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        uint256 bal = balanceOf[msg.sender];
        if (bal < amount) revert InsufficientBalance(bal, amount);
        balanceOf[msg.sender] = bal - amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
}

/// @notice Q3 : require(condition, "string") à la place des erreurs custom
contract TransferRequire {
    mapping(address => uint256) public balanceOf;
    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor(uint256 supply) { balanceOf[msg.sender] = supply; }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(to != address(0), 'MyToken: transfer to the zero address');
        uint256 bal = balanceOf[msg.sender];
        require(bal >= amount, 'MyToken: transfer amount exceeds balance');
        unchecked {
            balanceOf[msg.sender] = bal - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(msg.sender, to, amount);
        return true;
    }
}

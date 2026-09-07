// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import './IERC20.sol';

/// @title MyToken — Token ERC-20 pédagogique
/// @author Noureddine Bensadok — M2 AL, ESGI 2025-2026
/// @notice Implémentation complète de l'EIP-20 réalisée en TP1 (sans héritage OpenZeppelin)
/// @dev Pattern CEI (Checks-Effects-Interactions) respecté partout ; erreurs custom
///      (moins de gas qu'un `require` avec chaîne) ; arithmétique `unchecked` uniquement
///      là où un débordement est mathématiquement impossible (voir commentaires).
contract MyToken is IERC20 {
    // ── Storage ────────────────────────────────────────────────────
    /// @notice Nom lisible du token
    string public name;
    /// @notice Symbole (ticker) du token
    string public symbol;
    /// @notice Nombre de décimales (immutable : stocké dans le bytecode, pas en storage → lecture moins chère)
    uint8 public immutable decimals;
    /// @inheritdoc IERC20
    uint256 public totalSupply;
    /// @notice Adresse autorisée à minter et à transférer la propriété
    address public owner;

    /// @inheritdoc IERC20
    mapping(address => uint256) public balanceOf;
    /// @inheritdoc IERC20
    mapping(address => mapping(address => uint256)) public allowance;

    // ── Erreurs custom ─────────────────────────────────────────────
    // TODO 1 — Erreurs custom : 4 bytes de sélecteur au lieu d'une chaîne ABI-encodée
    /// @notice Appelant non autorisé (réservé à `owner`)
    error Unauthorized();
    /// @notice Solde insuffisant pour l'opération demandée
    /// @param available solde actuel de l'émetteur
    /// @param required  montant demandé
    error InsufficientBalance(uint256 available, uint256 required);
    /// @notice Allowance insuffisante pour un `transferFrom`
    /// @param available allowance actuelle
    /// @param required  montant demandé
    error InsufficientAllowance(uint256 available, uint256 required);
    /// @notice Adresse nulle interdite (destinataire, spender ou nouveau owner)
    error ZeroAddress();
    /// @notice Montant nul interdit (mint)
    error ZeroAmount();

    // ── Events supplémentaires ─────────────────────────────────────
    /// @notice Émis lors d'un changement de propriétaire
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ── Modificateurs ──────────────────────────────────────────────
    // TODO 2 — onlyOwner
    /// @dev Reverte avec `Unauthorized()` si l'appelant n'est pas `owner`
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    // ── Constructor ────────────────────────────────────────────────
    /// @param _name          nom du token
    /// @param _symbol        symbole du token
    /// @param _decimals      nombre de décimales
    /// @param _initialSupply supply initiale, mintée au déployeur (doit être > 0)
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _initialSupply
    ) {
        // TODO 3 — initialisation + mint initial
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
        _mint(msg.sender, _initialSupply);
    }

    // ── Fonctions ERC-20 publiques ─────────────────────────────────
    /// @inheritdoc IERC20
    /// @dev Reverte `ZeroAddress` si `to == address(0)`, `InsufficientBalance` si solde insuffisant
    function transfer(address to, uint256 amount) external returns (bool) {
        // TODO 4 — Checks puis Effects (dans _transfer)
        if (to == address(0)) revert ZeroAddress();
        _transfer(msg.sender, to, amount);
        return true;
    }

    /// @inheritdoc IERC20
    /// @dev Écrase l'allowance précédente (comportement EIP-20 standard)
    function approve(address spender, uint256 amount) external returns (bool) {
        // TODO 5
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /// @inheritdoc IERC20
    /// @dev Une allowance égale à `type(uint256).max` est considérée infinie et n'est pas décrémentée
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        // TODO 6
        // 1. Checks
        if (to == address(0)) revert ZeroAddress();
        // 2. Lecture unique de l'allowance (1 SLOAD)
        uint256 allowed = allowance[from][msg.sender];
        // 3. Approval infinie : on ne touche pas au storage (économie d'un SSTORE)
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance(allowed, amount);
            // Effects — `allowed >= amount` vient d'être vérifié : la soustraction ne peut pas underflow
            unchecked {
                allowance[from][msg.sender] = allowed - amount;
            }
        }
        // 4. Effects (balances) + event
        _transfer(from, to, amount);
        // 5.
        return true;
    }

    // ── Fonctions admin ────────────────────────────────────────────
    /// @notice Crée `amount` tokens pour `to` (réservé à `owner`)
    /// @param to     destinataire (≠ address(0))
    /// @param amount montant (> 0)
    function mint(address to, uint256 amount) external onlyOwner {
        // TODO 7
        _mint(to, amount);
    }

    /// @notice Détruit `amount` tokens de l'appelant
    /// @param amount montant à brûler (≤ solde de l'appelant)
    function burn(uint256 amount) external {
        // TODO 8
        _burn(msg.sender, amount);
    }

    /// @notice Transfère la propriété du contrat (réservé à `owner`)
    /// @param newOwner nouveau propriétaire (≠ address(0))
    function transferOwnership(address newOwner) external onlyOwner {
        // TODO 9 — Checks, event, Effects
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ── Fonctions internes (FOURNIES — ne pas modifier) ───────────
    function _transfer(address from, address to, uint256 amount) internal {
        uint256 bal = balanceOf[from];
        if (bal < amount) revert InsufficientBalance(bal, amount);
        // unchecked justifié : bal >= amount (pas d'underflow) et la somme de toutes les
        // balances == totalSupply <= 2^256-1 (pas d'overflow possible sur balanceOf[to])
        unchecked {
            balanceOf[from] = bal - amount;
            balanceOf[to]  += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        // checked : c'est le seul endroit où totalSupply peut overflow → on garde la protection
        totalSupply   += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        uint256 bal = balanceOf[from];
        if (bal < amount) revert InsufficientBalance(bal, amount);
        // unchecked justifié : bal >= amount et totalSupply >= balanceOf[from] >= amount
        unchecked {
            balanceOf[from] = bal - amount;
            totalSupply     -= amount;
        }
        emit Transfer(from, address(0), amount);
    }
}

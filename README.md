# TP1 — Token ERC-20 from scratch (Hardhat + Foundry)

> Blockchain & Développement — M2 AL — ESGI 2025-2026
> Auteur : **Noureddine Ben Sadok**

Implémentation complète d'un token ERC-20 (`MyToken`, symbole `MTK`) **sans héritage OpenZeppelin**, avec :

- erreurs custom (`Unauthorized`, `InsufficientBalance`, `InsufficientAllowance`, `ZeroAddress`, `ZeroAmount`) ;
- arithmétique `unchecked` uniquement là où elle est mathématiquement sûre ;
- pattern **CEI** (Checks-Effects-Interactions) ;
- approval infinie (`type(uint256).max` non décrémentée) ;
- `mint` réservé au `owner`, `burn` libre, `transferOwnership` ;
- NatSpec complet.

Tests dans deux paradigmes : **Hardhat / TypeScript / Chai** (24 tests) et **Foundry / Solidity** (20 tests dont 4 tests de fuzzing et 1 invariant piloté par un Handler). Couverture Foundry : **100 % lignes / statements / branches / fonctions**.

| Livrable | Fichier |
|---|---|
| Contrat | [`contracts/MyToken.sol`](contracts/MyToken.sol) (+ [`contracts/IERC20.sol`](contracts/IERC20.sol)) |
| Tests Hardhat | [`test/MyToken.test.ts`](test/MyToken.test.ts) |
| Tests Foundry | [`test/MyToken.t.sol`](test/MyToken.t.sol) |
| Benchmark gas (Partie 6) | [`test/GasBench.t.sol`](test/GasBench.t.sol) + [`contracts/benchmark/MyTokenVariants.sol`](contracts/benchmark/MyTokenVariants.sol) |
| Script de déploiement | [`scripts/deploy.ts`](scripts/deploy.ts) |
| Rapport gas Hardhat | [`gas-report.txt`](gas-report.txt) |
| Snapshot gas Foundry | [`.gas-snapshot`](.gas-snapshot) |
| Mesures Partie 6 | [`gas-bench-foundry.txt`](gas-bench-foundry.txt), [`gas-optimizer-runs.txt`](gas-optimizer-runs.txt), [`coverage-summary.txt`](coverage-summary.txt) |

**Contrat déployé et vérifié sur Sepolia** : [`0xe0Fdc5391fCB9f6536088B7973529Bf8511Fb50F`](https://sepolia.etherscan.io/address/0xe0fdc5391fcb9f6536088b7973529bf8511fb50f#code) — tx de création [`0xc4fcb672…`](https://sepolia.etherscan.io/tx/0xc4fcb67266bdb5cb3bc982e4ebba21c350f594b226cb606a11fb470b9aa76f5a) (déployeur `0xa26fC1DC…dE4c9`, 1 000 000 MTK).

**Repository** : https://github.com/NoureddineGigs/Crypto

---

## 1. Prérequis

- Node.js ≥ 20 LTS, npm
- Git
- Foundry (`forge`, `cast`, `anvil`) :
  ```bash
  curl -L https://foundry.paradigm.xyz | bash
  foundryup
  forge --version
  ```

## 2. Installation

```bash
git clone https://github.com/NoureddineGigs/Crypto.git
cd Crypto
npm install                       # Hardhat, toolbox, gas-reporter, dotenv, OpenZeppelin…
git submodule update --init       # forge-std (lib/forge-std) — ou : forge install foundry-rs/forge-std --no-commit
cp .env.example .env              # puis remplir RPC_URL_SEPOLIA / PRIVATE_KEY / ETHERSCAN_API_KEY
```

> ⚠️ `.env` est ignoré par git (`.gitignore`). Utilisez un **wallet dédié au développement**.

## 3. Compilation

```bash
npx hardhat compile     # génère artifacts/ + typechain-types/
forge build             # génère out/
```

## 4. Tests

```bash
# Hardhat (TypeScript / Chai) — génère gas-report.txt
npx hardhat test
npx hardhat coverage

# Foundry (Solidity) — tests unitaires + fuzzing + invariant
forge test -vv
forge test --fuzz-runs 1000
forge test --gas-report
forge coverage --report summary --no-match-coverage test/
forge snapshot                         # génère .gas-snapshot

# Benchmark gas de la Partie 6 (unchecked vs checked, custom error vs require)
forge test --match-contract GasBench -vv

# Effet du nombre de runs de l'optimiseur (Q5)
FOUNDRY_OPTIMIZER_RUNS=1    forge test --gas-report --match-contract MyTokenTest
OPTIMIZER_RUNS=1000 npx hardhat test
```

Raccourcis npm : `npm test`, `npm run test:forge`, `npm run test:all`, `npm run coverage:forge`, `npm run snapshot`, `npm run gas:bench`.

## 5. Déploiement

```bash
# Réseau local Hardhat (test rapide)
npx hardhat run scripts/deploy.ts --network hardhat

# Sepolia + vérification Etherscan automatique (attend 5 blocs)
npx hardhat run scripts/deploy.ts --network sepolia
```

Le script affiche l'adresse du contrat, le hash de la transaction et le lien Etherscan.

## 6. Structure du projet

```
.
├── contracts/
│   ├── IERC20.sol                 # interface EIP-20 (fournie)
│   ├── MyToken.sol                # implémentation
│   └── benchmark/MyTokenVariants.sol   # variantes pour l'analyse gas
├── test/
│   ├── MyToken.test.ts            # tests Hardhat (24)
│   ├── MyToken.t.sol              # tests Foundry (20 : unit + fuzz + invariant)
│   └── GasBench.t.sol             # mesures gas Partie 6
├── scripts/deploy.ts
├── lib/forge-std                  # dépendance Foundry
├── hardhat.config.ts · foundry.toml · tsconfig.json
├── gas-report.txt · .gas-snapshot · coverage-summary.txt
└── .env.example
```

## 7. Choix d'implémentation notables

- **`unchecked`** : dans `_transfer` / `_burn` (fournis) la soustraction est protégée par le check `bal < amount` juste avant et l'addition ne peut pas dépasser `totalSupply` ; dans `transferFrom`, `allowed - amount` est protégé par `allowed < amount → revert`. `_mint` reste **checked** : c'est le seul endroit où `totalSupply` pourrait déborder.
- **Approval infinie** : si `allowance == type(uint256).max`, aucun `SSTORE` n'est effectué (≈ 2 900 gas économisés par `transferFrom`).
- **`decimals` immutable** : lu depuis le bytecode (pas de `SLOAD`).
- **Erreurs custom** : sélecteur 4 octets au lieu d'une chaîne ABI-encodée → bytecode plus petit, revert moins cher, et paramètres (`available`, `required`) exploitables côté client.

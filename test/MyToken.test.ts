import { expect } from 'chai';
import { ethers } from 'hardhat';
import { MyToken } from '../typechain-types';
import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';

describe('MyToken', function () {
  let token: MyToken;
  let owner: SignerWithAddress;
  let alice: SignerWithAddress;
  let bob: SignerWithAddress;

  const NAME = 'MyToken';
  const SYMBOL = 'MTK';
  const SUPPLY = ethers.parseEther('1000000'); // 1 million tokens

  beforeEach(async function () {
    [owner, alice, bob] = await ethers.getSigners();
    const Token = await ethers.getContractFactory('MyToken');
    token = await Token.deploy(NAME, SYMBOL, 18, SUPPLY);
  });

  // --- Déploiement ---
  describe('Deployment', function () {
    it('should set name, symbol and decimals correctly', async function () {
      // TODO A
      expect(await token.name()).to.equal(NAME);
      expect(await token.symbol()).to.equal(SYMBOL);
      expect(await token.decimals()).to.equal(18);
    });

    it('should mint initial supply to owner', async function () {
      // TODO B
      expect(await token.totalSupply()).to.equal(SUPPLY);
      expect(await token.balanceOf(owner.address)).to.equal(SUPPLY);
      expect(await token.owner()).to.equal(owner.address);
    });

    it('should emit Transfer from address(0) and OwnershipTransferred at deployment', async function () {
      const Token = await ethers.getContractFactory('MyToken');
      const t = await Token.deploy(NAME, SYMBOL, 18, SUPPLY);
      const tx = t.deploymentTransaction()!;
      await expect(tx).to.emit(t, 'Transfer').withArgs(ethers.ZeroAddress, owner.address, SUPPLY);
      await expect(tx).to.emit(t, 'OwnershipTransferred').withArgs(ethers.ZeroAddress, owner.address);
    });

    it('should revert with ZeroAmount if initial supply is 0', async function () {
      const Token = await ethers.getContractFactory('MyToken');
      await expect(Token.deploy(NAME, SYMBOL, 18, 0)).to.be.revertedWithCustomError(
        { interface: Token.interface },
        'ZeroAmount',
      );
    });
  });

  // --- Transfer ---
  describe('transfer()', function () {
    it('should transfer tokens and emit Transfer event', async function () {
      const amount = ethers.parseEther('100');
      // TODO C
      await expect(token.transfer(alice.address, amount))
        .to.emit(token, 'Transfer')
        .withArgs(owner.address, alice.address, amount);
      expect(await token.balanceOf(alice.address)).to.equal(amount);
      expect(await token.balanceOf(owner.address)).to.equal(SUPPLY - amount);
      expect(await token.totalSupply()).to.equal(SUPPLY); // conservation
    });

    it('should revert with InsufficientBalance if sender has not enough', async function () {
      // TODO D
      const amount = ethers.parseEther('1');
      await expect(token.connect(alice).transfer(bob.address, amount))
        .to.be.revertedWithCustomError(token, 'InsufficientBalance')
        .withArgs(0, amount);
    });

    it('should revert with ZeroAddress if recipient is address(0)', async function () {
      // TODO E
      await expect(token.transfer(ethers.ZeroAddress, 1n)).to.be.revertedWithCustomError(
        token,
        'ZeroAddress',
      );
    });

    it('should allow a zero-amount transfer (EIP-20 compliant) and return true', async function () {
      await expect(token.transfer(alice.address, 0n))
        .to.emit(token, 'Transfer')
        .withArgs(owner.address, alice.address, 0n);
      expect(await token.transfer.staticCall(alice.address, 0n)).to.equal(true);
    });

    it('should allow transferring the full balance', async function () {
      await token.transfer(alice.address, SUPPLY);
      expect(await token.balanceOf(owner.address)).to.equal(0);
      expect(await token.balanceOf(alice.address)).to.equal(SUPPLY);
    });
  });

  // --- Approve / TransferFrom ---
  describe('approve() and transferFrom()', function () {
    it('should emit Approval and set allowance', async function () {
      const amount = ethers.parseEther('500');
      await expect(token.approve(alice.address, amount))
        .to.emit(token, 'Approval')
        .withArgs(owner.address, alice.address, amount);
      expect(await token.allowance(owner.address, alice.address)).to.equal(amount);
    });

    it('should revert approve with ZeroAddress if spender is address(0)', async function () {
      await expect(token.approve(ethers.ZeroAddress, 1n)).to.be.revertedWithCustomError(
        token,
        'ZeroAddress',
      );
    });

    it('should allow transferFrom after approve', async function () {
      // TODO F
      const approved = ethers.parseEther('500');
      const amount = ethers.parseEther('200');
      await token.approve(alice.address, approved);
      await expect(token.connect(alice).transferFrom(owner.address, bob.address, amount))
        .to.emit(token, 'Transfer')
        .withArgs(owner.address, bob.address, amount);
      expect(await token.balanceOf(bob.address)).to.equal(amount);
      expect(await token.balanceOf(owner.address)).to.equal(SUPPLY - amount);
      expect(await token.allowance(owner.address, alice.address)).to.equal(approved - amount);
    });

    it('should revert if allowance exceeded', async function () {
      // TODO G
      const approved = ethers.parseEther('100');
      const amount = ethers.parseEther('101');
      await token.approve(alice.address, approved);
      await expect(token.connect(alice).transferFrom(owner.address, bob.address, amount))
        .to.be.revertedWithCustomError(token, 'InsufficientAllowance')
        .withArgs(approved, amount);
    });

    it('should revert transferFrom with ZeroAddress if recipient is address(0)', async function () {
      await token.approve(alice.address, 1n);
      await expect(
        token.connect(alice).transferFrom(owner.address, ethers.ZeroAddress, 1n),
      ).to.be.revertedWithCustomError(token, 'ZeroAddress');
    });

    it('should revert transferFrom with InsufficientBalance if owner has not enough', async function () {
      // alice a 0 token mais approuve bob : l allowance passe, la balance non
      await token.connect(alice).approve(bob.address, ethers.MaxUint256);
      await expect(token.connect(bob).transferFrom(alice.address, bob.address, 1n))
        .to.be.revertedWithCustomError(token, 'InsufficientBalance')
        .withArgs(0, 1n);
    });

    it('should support infinite approval (uint256.max)', async function () {
      // TODO H
      const amount = ethers.parseEther('1000');
      await token.approve(alice.address, ethers.MaxUint256);
      await token.connect(alice).transferFrom(owner.address, bob.address, amount);
      expect(await token.allowance(owner.address, alice.address)).to.equal(ethers.MaxUint256);
      expect(await token.balanceOf(bob.address)).to.equal(amount);
    });
  });

  // --- Mint / Burn ---
  describe('mint() and burn()', function () {
    it('owner can mint additional tokens', async function () {
      // TODO I
      const amount = ethers.parseEther('42');
      await expect(token.mint(alice.address, amount))
        .to.emit(token, 'Transfer')
        .withArgs(ethers.ZeroAddress, alice.address, amount);
      expect(await token.balanceOf(alice.address)).to.equal(amount);
      expect(await token.totalSupply()).to.equal(SUPPLY + amount);
    });

    it('non-owner cannot mint', async function () {
      // TODO J
      await expect(token.connect(alice).mint(alice.address, 1n)).to.be.revertedWithCustomError(
        token,
        'Unauthorized',
      );
    });

    it('mint reverts with ZeroAddress / ZeroAmount', async function () {
      await expect(token.mint(ethers.ZeroAddress, 1n)).to.be.revertedWithCustomError(token, 'ZeroAddress');
      await expect(token.mint(alice.address, 0n)).to.be.revertedWithCustomError(token, 'ZeroAmount');
    });

    it('any user can burn their own tokens', async function () {
      // TODO K
      const amount = ethers.parseEther('10');
      await token.transfer(alice.address, amount);
      await expect(token.connect(alice).burn(amount))
        .to.emit(token, 'Transfer')
        .withArgs(alice.address, ethers.ZeroAddress, amount);
      expect(await token.balanceOf(alice.address)).to.equal(0);
      expect(await token.totalSupply()).to.equal(SUPPLY - amount);
    });

    it('burn reverts with InsufficientBalance if amount > balance', async function () {
      await expect(token.connect(alice).burn(1n))
        .to.be.revertedWithCustomError(token, 'InsufficientBalance')
        .withArgs(0, 1n);
    });
  });

  // --- Ownership ---
  describe('transferOwnership()', function () {
    it('owner can transfer ownership and the new owner can mint', async function () {
      await expect(token.transferOwnership(alice.address))
        .to.emit(token, 'OwnershipTransferred')
        .withArgs(owner.address, alice.address);
      expect(await token.owner()).to.equal(alice.address);
      await expect(token.mint(bob.address, 1n)).to.be.revertedWithCustomError(token, 'Unauthorized');
      await token.connect(alice).mint(bob.address, 1n);
      expect(await token.balanceOf(bob.address)).to.equal(1n);
    });

    it('non-owner cannot transfer ownership', async function () {
      await expect(token.connect(alice).transferOwnership(alice.address)).to.be.revertedWithCustomError(
        token,
        'Unauthorized',
      );
    });

    it('reverts with ZeroAddress if new owner is address(0)', async function () {
      await expect(token.transferOwnership(ethers.ZeroAddress)).to.be.revertedWithCustomError(
        token,
        'ZeroAddress',
      );
    });
  });
});

import { expect } from "chai";
import { Contract, ContractFactory, Signer, utils } from "ethers";
import { parseEther, parseUnits } from "ethers/lib/utils";
import { ethers } from "hardhat";
import { hexConcat } from "@ethersproject/bytes";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

let Staking : ContractFactory;
let stak : Contract;
let ERC20 : ContractFactory;
let token : Contract;
let Reward : ContractFactory;
let reward : Contract;
let owner: SignerWithAddress;
let addr1: SignerWithAddress;
let addr2: SignerWithAddress;
let addr3: SignerWithAddress;
let addr4: SignerWithAddress;

describe("Hermes", function () {

  beforeEach(async () => {
    ERC20 = await ethers.getContractFactory("MyToken");
    Reward = await ethers.getContractFactory("EBGG");
    Staking = await ethers.getContractFactory("Staking");
  });

  describe("Stacking", () => {

    it("0) Deploy, mint and get allowance", async function() {
      [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();
      token = await ERC20.connect(owner).deploy();
      reward = await Reward.connect(owner).deploy();
      stak = await Staking.connect(owner).deploy(token.address, reward.address, parseUnits("500", 18), 7 * 24 * 3600, 7 * 24 * 3600);

    });


    it("1.1) Deploy", async function() {
      await token.deployed();
      await reward.deployed();
      await stak.deployed();
    });

    it("1.2) Mint", async function() {
      await token.connect(owner).mint(addr1.address, parseUnits("2500", 18));
      await token.connect(owner).mint(addr2.address, parseUnits("2000", 18));
      await token.connect(owner).mint(addr3.address, parseUnits("2500", 18));
      await token.connect(owner).mint(addr4.address, parseUnits("5000", 18));
    });

    it("1.3) Get allowance", async function() {
      await token.connect(addr1).approve(stak.address, parseUnits("5000", 18));
      await token.connect(addr2).approve(stak.address, parseUnits("2000", 18));
      await token.connect(addr3).approve(stak.address, parseUnits("2500", 18));
      await token.connect(addr4).approve(stak.address, parseUnits("5000", 18));
    });

    it("1.4) Get roles", async function() {
      await reward.connect(owner).setChoisenRole(stak.address);
    });

    it("2) 1st hour: Deposit and set new parametres", async function() {
      await stak.connect(addr1).stake(parseUnits("1000", 18), 0);
      
      await ethers.provider.send("evm_increaseTime", [7 * 24 * 3610]);
      await ethers.provider.send("evm_mine", []);

      await stak.connect(owner).setParametres(parseUnits("100", 18), 7 * 24 * 3600, 7 * 24 * 3600);
    });

    it("2) Deposit & 4 hours", async function() {

      await stak.connect(addr2).stake(parseUnits("2000", 18), 0);

      await ethers.provider.send("evm_increaseTime", [7 * 24 * 3610]);
      await ethers.provider.send("evm_mine", []);

      await stak.connect(addr3).stake(parseUnits("2500", 18), 0);

      await ethers.provider.send("evm_increaseTime", [7 * 24 * 3610]);
      await ethers.provider.send("evm_mine", []);

      await stak.connect(addr4).stake(parseUnits("5000", 18), 0);
      await stak.connect(addr1).stake(parseUnits("1500", 18), 0);

      await ethers.provider.send("evm_increaseTime", [7 * 24 * 3610]);
      await ethers.provider.send("evm_mine", []);
    });

    it("3) Claim tokens and deposit them again", async function() {
      await stak.connect(addr1).unstake(4);
      await stak.connect(addr1).stake(parseUnits("1500", 18), 0);
    });

    it("4) Check Rewards on next day", async function() {
      await ethers.provider.send("evm_increaseTime", [2 * 7 * 24 * 3610]);
      await ethers.provider.send("evm_mine", []);
      let account;
      let reward;
      const rewq = await stak.getAccount(addr1.address);
      //expect(await rewq.reward).to.closeTo(parseUnits("614.015", 18), 1e15);
    });

    it("5) Try to Claim Rewards", async function() {
      await stak.connect(addr1).claim();

      expect(await reward.connect(addr1).balanceOf(addr1.address)).to.closeTo(parseUnits("614.015", 18), 1e15);
    });

    it("6) Get View Data", async function() {
      const viewData = await stak.connect(owner).getViewData();
      expect(await viewData.BGGAddress).to.equal(token.address);
      expect(await viewData.rewardAddress).to.equal(reward.address);
      expect(await viewData.rewardAtEpoch).to.equal(parseUnits("100", 18));
      expect(await viewData.epochDuration).to.equal(604800);
      expect(await viewData.minReceiveRewardDuration).to.equal(604800);
    });
  });













  describe("Standart scenario", () => {

    it("0) Deploy, mint and get allowance", async function() {
      [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();
      token = await ERC20.connect(owner).deploy();
      reward = await Reward.connect(owner).deploy();
      stak = await Staking.connect(owner).deploy(token.address, reward.address, parseUnits("100", 18), 7 * 24 * 3600, 3600);
    });

    it("1.1) Deploy", async function() {
      await token.deployed();
      await reward.deployed();
      await stak.deployed();
    });

    it("1.2) Mint", async function() {
      await token.connect(owner).mint(addr1.address, parseUnits("100", 18));
      await token.connect(owner).mint(addr2.address, parseUnits("200", 18));
    });

    it("1.3) Get allowance", async function() {
      await token.connect(addr1).approve(stak.address, parseUnits("100", 18));
      await token.connect(addr2).approve(stak.address, parseUnits("200", 18));
    });

    it("1.4) Get roles", async function() {
      await reward.connect(owner).setChoisenRole(stak.address);
    });

    it("2) Stake and check sbgg balance", async function() {
      await stak.connect(addr1).stake(parseUnits("100", 18), 20 * 7 * 24 * 3600);
      await stak.connect(addr2).stake(parseUnits("200", 18), 20 * 7 * 24 * 3600);

      expect(await stak.connect(addr1).balanceOf(addr1.address)).to.closeTo(parseUnits("138.461", 18), 1e15);
      expect(await stak.connect(addr2).balanceOf(addr2.address)).to.closeTo(parseUnits("276.923", 18), 1e15);
    });

    it("3) After 10 week", async function() {

      await ethers.provider.send("evm_increaseTime", [10 * 7 * 24 * 3610]);
      await ethers.provider.send("evm_mine", []);

      await stak.connect(addr1).claim();

      expect(await reward.connect(addr1).balanceOf(addr1.address)).to.closeTo(parseUnits("334.126", 18), 1e15);
    });

    it("4) After 15 week", async function() {

      await ethers.provider.send("evm_increaseTime", [5 * 7 * 24 * 3610]);
      await ethers.provider.send("evm_mine", []);

      await stak.connect(addr2).claim();

      expect(await reward.connect(addr2).balanceOf(addr2.address)).to.closeTo(parseUnits("1002.777", 18), 1e15);
    });

    it("5) After 20 week", async function() {

      await ethers.provider.send("evm_increaseTime", [5 * 7 * 24 * 3610]);
      await ethers.provider.send("evm_mine", []);

      await stak.connect(addr1).unstake(0);
      await stak.connect(addr2).unstake(1);

      expect(await reward.connect(addr1).balanceOf(addr1.address)).to.closeTo(parseUnits("668.452", 18), 1e15);
      expect(await reward.connect(addr2).balanceOf(addr2.address)).to.closeTo(parseUnits("1336.904", 18), 1e15);

      expect(await stak.connect(addr1).balanceOf(addr1.address)).to.equal(0);
      expect(await stak.connect(addr2).balanceOf(addr2.address)).to.equal(0);

      expect(await token.connect(addr1).balanceOf(addr1.address)).to.equal(parseUnits("100", 18));
      expect(await token.connect(addr2).balanceOf(addr2.address)).to.equal(parseUnits("200", 18));
    });

    // it("4) Check Rewards on next day", async function() {
    //   await ethers.provider.send("evm_increaseTime", [2 * 7 * 24 * 3610]);
    //   await ethers.provider.send("evm_mine", []);
    //   let account;
    //   let reward;
    //   const rewq = await stak.getAccount(addr1.address);
    //   //expect(await rewq.reward).to.closeTo(parseUnits("614.015", 18), 1e15);
    // });

    // it("5) Try to Claim Rewards", async function() {
    //   await stak.connect(addr1).claim();

    //   expect(await reward.connect(addr1).balanceOf(addr1.address)).to.closeTo(parseUnits("614.015", 18), 1e15);
    // });

    // it("6) Get View Data", async function() {
    //   const viewData = await stak.connect(owner).getViewData();
    //   expect(await viewData.BGGAddress).to.equal(token.address);
    //   expect(await viewData.SBGGAddress).to.equal(sbgg.address);
    //   expect(await viewData.rewardAddress).to.equal(reward.address);
    //   expect(await viewData.rewardAtEpoch).to.equal(parseUnits("100", 18));
    //   expect(await viewData.epochDuration).to.equal(604800);
    //   expect(await viewData.minReceiveRewardDuration).to.equal(604800);
    // });
  });

});

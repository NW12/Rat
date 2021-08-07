import { deployMockContract } from "@ethereum-waffle/mock-contract";
import { expect } from "chai";
import { Contract, BigNumber, Signer } from "ethers";
import hre, { artifacts, ethers, waffle } from "hardhat";
import "@nomiclabs/hardhat-ethers";

import { factoryBytecode } from "./Externals/factory_bytecode";
import { routerBytecode } from "./Externals/router_bytecode";

import factoryAbi from "./Externals/factory.json";
import routerAbi from "./Externals/router.json";
import pairAbi from "./Externals/pair.json";

import {
  afterTax,
  increaseTime,
  setupRouter,
  setPrequistes,
  sendTxAndGetReturnValue,
} from "./Utilities";

import _ from "underscore";

describe("RitzCoin", async () => {
  let ratContract: Contract;
  let icoContract: Contract;
  let router: Contract;
  let factory: Contract;
  let signers: Signer[];

  describe("TheRareAntiquitiesToken", async () => {
    before(async () => {
      signers = await ethers.getSigners();
      const RatContract = await ethers.getContractFactory(
        "TheRareAntiquitiesToken",
        signers[0],
      );
      ratContract = await RatContract.deploy(await signers[0].getAddress());
      let { _router, _factory } = await setupRouter(signers[0]);
      router = _router;
      factory = _factory;
    });

    it("RAT Total Supply should be 500 Billion", async () => {
      await expect(await ratContract.totalSupply()).to.be.equal(
        ethers.utils.parseEther("500000000000"),
      );
    });

    it("Verify treasury address", async () => {
      await expect(await ratContract.treasury()).to.be.equal(
        await signers[0].getAddress(),
      );
    });

    it("Verify owner of smart contract", async () => {
      await expect(await ratContract.owner()).to.be.equal(
        await signers[0].getAddress(),
      );
    });

    it("When Contract is paused throw", async () => {
      await ratContract.connect(signers[0]).pause();
      await expect(
        ratContract
          .connect(signers[0])
          .transfer(
            await signers[2].getAddress(),
            ethers.utils.parseEther("1"),
          ),
      ).to.be.revertedWith("Pausable: paused");
    });

    it("When Contract is not paused", async () => {
      await ratContract.connect(signers[0]).unpause();
      await expect(async () =>
        ratContract
          .connect(signers[0])
          .transfer(
            await signers[1].getAddress(),
            ethers.utils.parseEther("1"),
          ),
      ).to.changeTokenBalance(
        ratContract,
        signers[1],
        await afterTax(ethers.utils.parseEther("1")),
      );
    });

    it("If Contract is already unpaused", async () => {
      await expect(
        ratContract.connect(signers[0]).unpause(),
      ).to.be.revertedWith("Pausable: not paused");
    });

    it("Recipient will get amount after deduction of 3% tax", async () => {
      await expect(async () =>
        ratContract
          .connect(signers[0])
          .transfer(
            await signers[1].getAddress(),
            ethers.utils.parseEther("1"),
          ),
      ).to.changeTokenBalance(
        ratContract,
        signers[1],
        await afterTax(ethers.utils.parseEther("1")),
      );
    });

    it("Burn tokens", async () => {
      const prevBalance = await ratContract.balanceOf(
        await signers[1].getAddress(),
      );
      const afterBurn = prevBalance.sub(
        BigNumber.from(ethers.utils.parseEther("1")),
      );
      await ratContract.connect(signers[1]).burn(ethers.utils.parseEther("1"));
      await expect(
        await ratContract.balanceOf(await signers[1].getAddress()),
      ).to.be.equal(afterBurn);
    });
  });

  describe("Crowdsale ", async () => {
    before(async () => {
      signers = await ethers.getSigners();
      const RatContract = await ethers.getContractFactory(
        "TheRareAntiquitiesToken",
        signers[0],
      );
      ratContract = await RatContract.deploy(await signers[0].getAddress());
      let { _router, _factory } = await setupRouter(signers[0]);
      router = _router;
      factory = _factory;

      const Crowdsale = await ethers.getContractFactory(
        "Crowdsale",
        signers[0],
      );

      icoContract = await Crowdsale.deploy(
        ethers.utils.parseEther("100"),
        ratContract.address,
        await signers[0].getAddress(),
        router.address,
      );
    });

    it("Verify token address", async () => {
      await expect(await icoContract.token()).to.be.equal(ratContract.address);
    });

    it("Verify wallet address", async () => {
      await expect(await icoContract.wallet()).to.be.equal(
        await signers[0].getAddress(),
      );
    });

    it("Verify ico rate", async () => {
      await expect(await icoContract.rate()).to.be.equal(
        ethers.utils.parseEther("100"),
      );
    });

    it("Verify preIco stage is running", async () => {
      await expect(await icoContract.getCurrentStage()).to.be.equal(
        BigNumber.from(0),
      );
    });

    it("Throw, if address in preIco is not whitelisted", async () => {
      ratContract
        .connect(signers[0])
        .transfer(await signers[1].getAddress(), ethers.utils.parseEther("10"));

      await expect(
        icoContract
          .connect(signers[0])
          .buyTokens(await signers[1].getAddress(), {
            value: ethers.utils.parseEther("1"),
          }),
      ).to.be.revertedWith("Crowdsale: NOT_WHITELISTED");
    });

    it("Throw, if preIco is not started", async () => {
      await icoContract
        .connect(signers[0])
        .addWhitelist(await signers[1].getAddress());
      await expect(
        icoContract
          .connect(signers[1])
          .buyTokens(await signers[1].getAddress(), {
            value: ethers.utils.parseEther("1"),
          }),
      ).to.be.revertedWith("Crowdsale: PRE_ICO_NOT_STARTED");
    });

    it("Throw, if deposit amount is zero ", async () => {
      await increaseTime(1628899200 - Date.now() / 1000 + 10);
      // await increaseTime(725859);
      await ratContract
        .connect(signers[0])
        .transfer(icoContract.address, ethers.utils.parseEther("4250"));

      await expect(
        icoContract
          .connect(signers[1])
          .buyTokens(await signers[1].getAddress(), {
            value: ethers.utils.parseEther("0"),
          }),
      ).to.be.revertedWith("Crowdsale: ZERO_AMOUNT");
    });

    it("Successfully bought tokens in PreICO", async () => {
      icoContract.connect(signers[1]).buyTokens(await signers[1].getAddress(), {
        value: ethers.utils.parseEther("10"),
      });
    });

    it("Throw, if MAX Goal reached ", async () => {
      await expect(
        icoContract
          .connect(signers[1])
          .buyTokens(await signers[1].getAddress(), {
            value: ethers.utils.parseEther("1001"),
          }),
      ).to.be.revertedWith("Crowdsale: MAX_GOAL_REACHED");
    });

    it("Throw, if preIco is ended", async () => {
      // await increaseTime(1876097);
      const now = await (await ethers.provider.getBlock("latest")).timestamp;
      await increaseTime(1630047600 - now + 10);

      await ratContract
        .connect(signers[0])
        .transfer(icoContract.address, ethers.utils.parseEther("425000000000"));

      await expect(
        icoContract
          .connect(signers[1])
          .buyTokens(await signers[1].getAddress(), {
            value: ethers.utils.parseEther("1"),
          }),
      ).to.be.revertedWith("Crowdsale: PRE_ICO_ENDED");
    });

    it("Throw, if beneficiary address is zero ", async () => {
      await expect(
        icoContract
          .connect(signers[1])
          .buyTokens("0x0000000000000000000000000000000000000000", {
            value: ethers.utils.parseEther("1"),
          }),
      ).to.be.revertedWith("Crowdsale: ZERO_ADDRESS");
    });

    it("Throw, if Ico is not started", async () => {
      await icoContract
        .connect(signers[0])
        .setCrowdsaleStage(BigNumber.from(1));
      await expect(
        icoContract
          .connect(signers[1])
          .buyTokens(await signers[1].getAddress(), {
            value: ethers.utils.parseEther("1"),
          }),
      ).to.be.revertedWith("Crowdsale: ICO_NOT_STARTED");
    });

    it("Successfully bought tokens in ICO", async () => {
      const now = await (await ethers.provider.getBlock("latest")).timestamp;
      await increaseTime(1630108800 - now + 10);

      icoContract.connect(signers[1]).buyTokens(await signers[1].getAddress(), {
        value: ethers.utils.parseEther("990"),
      });
    });

    it("Throw, if finalize crowdsale before end", async () => {
      await expect(icoContract.connect(signers[0]).finish()).to.be.reverted;
    });

    it("Throw, if Ico is ended", async () => {
      const now = await (await ethers.provider.getBlock("latest")).timestamp;
      await increaseTime(1632787200 - now + 10);

      await icoContract
        .connect(signers[0])
        .setCrowdsaleStage(BigNumber.from(1));
      await expect(
        icoContract
          .connect(signers[1])
          .buyTokens(await signers[1].getAddress(), {
            value: ethers.utils.parseEther("1"),
          }),
      ).to.be.revertedWith("Crowdsale: ICO_ENDED");
    });

    it("Finalize crowdsale", async () => {
      await icoContract.connect(signers[0]).finish();
      await expect(await ratContract.callStatic.balanceOf(icoContract.address)).to.be.equal("0")
    });
  });
});

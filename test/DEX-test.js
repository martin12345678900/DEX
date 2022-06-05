const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DEX", function () {
  let dai, bat, rep, zrx, dex, trader1, trader2;
  const [DAI, BAT, REP, ZRX] = ["DAI", "BAT", "REP", "ZRX"].map((ticker) =>
    ethers.utils.formatBytes32String(ticker)
  );

  beforeEach(async function () {
    const [DaiFactory, BatFactory, RepFactory, ZrxFactory, DexFactory] =
      await Promise.all([
        await ethers.getContractFactory("Dai"),
        await ethers.getContractFactory("Bat"),
        await ethers.getContractFactory("Rep"),
        await ethers.getContractFactory("Zrx"),
        await ethers.getContractFactory("Dex"),
      ]);
    const [Dai, Bat, Rep, Zrx, Dex] = await Promise.all([
      await DaiFactory.deploy(),
      await BatFactory.deploy(),
      await RepFactory.deploy(),
      await ZrxFactory.deploy(),
      await DexFactory.deploy(),
    ]);

    const [_, trader1_, trader2_] = await ethers.getSigners();
    trader1 = trader1_;
    trader2 = trader2_;

    dai = Dai;
    bat = Bat;
    rep = Rep;
    zrx = Zrx;
    dex = Dex;

    await Promise.all([
      await dex.addToken(DAI, dai.address),
      await dex.addToken(BAT, bat.address),
      await dex.addToken(REP, rep.address),
      await dex.addToken(ZRX, zrx.address),
    ]);

    const amount = ethers.utils.parseEther("1000");
    const seedTokenBalance = async (token, trader) => {
      await token.faucet(trader.address, amount);
      await token.connect(trader).approve(dex.address, amount);
    };

    await Promise.all(
      [dai, bat, rep, zrx].map((token) => seedTokenBalance(token, trader1))
    );
    await Promise.all(
      [dai, bat, rep, zrx].map((token) => seedTokenBalance(token, trader2))
    );
  });

  it("should deposit tokens", async function () {
    const amount = ethers.utils.parseEther("100");

    await dex.connect(trader1).deposit(DAI, amount);
    expect(await dex.traderBalances(trader1.address, DAI)).to.be.equal(amount);
    expect(await dai.balanceOf(dex.address)).to.be.equal(amount);
  });

  it("should deposit tokens fail", async function () {
    expect(
      dex
        .connect(trader1)
        .deposit(
          ethers.utils.formatBytes32String("RANDOM_TOKEN"),
          ethers.utils.parseEther("100")
        )
    ).to.be.revertedWith("invalid token");
  });

  it("should withdraw tokens", async function () {
    const depositAmount = ethers.utils.parseEther("100");
    const withdrawAmount = ethers.utils.parseEther("50");

    await dex.connect(trader1).deposit(DAI, depositAmount);
    await dex.connect(trader1).withdraw(DAI, withdrawAmount);

    expect(await dex.traderBalances(trader1.address, DAI)).to.be.equal(
      ethers.utils.parseEther("50")
    );
    expect(await dai.balanceOf(dex.address)).to.be.equal(
      ethers.utils.parseEther("50")
    );
  });

  it("should withdraw tokens fail 1", async function () {
    expect(
      dex
        .connect(trader1)
        .withdraw(
          ethers.utils.formatBytes32String("RANDOM_TOKEN"),
          ethers.utils.parseEther("50")
        )
    ).to.be.revertedWith("invalid token");
  });

  it("should withdraw tokens fail 2", async function () {
    const depositAmount = ethers.utils.parseEther("100");
    const withdrawAmount = ethers.utils.parseEther("150");

    await dex.connect(trader1).deposit(DAI, depositAmount);
    expect(
      dex.connect(trader1).withdraw(DAI, withdrawAmount)
    ).to.be.revertedWith("not enough balance");
  });
});

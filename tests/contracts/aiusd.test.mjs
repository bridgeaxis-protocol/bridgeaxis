import assert from "node:assert/strict";
import test from "node:test";
import ganache from "ganache";
import { BrowserProvider, ContractFactory, id, parseUnits } from "ethers";
import fs from "node:fs";
import path from "node:path";

const rootDir = process.cwd();
const artifactDir = path.join(rootDir, "artifacts", "contracts", "aiusd");
const oneDay = 24 * 60 * 60;
const tokenDecimals = 18;
const testReserveReason = id("BRIDGEAXIS_TEST_RESERVE");

function loadArtifact(name) {
  return JSON.parse(
    fs.readFileSync(path.join(artifactDir, `${name}.json`), "utf8"),
  );
}

async function deployFixture() {
  const transport = ganache.provider({
    logging: { quiet: true },
    wallet: { totalAccounts: 6 },
    chain: { chainId: 31337 },
  });
  const provider = new BrowserProvider(transport);
  const owner = await provider.getSigner(0);
  const operator = await provider.getSigner(1);
  const alice = await provider.getSigner(2);
  const bob = await provider.getSigner(3);

  const busdcArtifact = loadArtifact("BUSDC");
  const aiusdArtifact = loadArtifact("AIUSD");
  const controllerArtifact = loadArtifact("AIUSDController");

  const busdcFactory = new ContractFactory(
    busdcArtifact.abi,
    busdcArtifact.bytecode,
    owner,
  );
  const busdc = await busdcFactory.deploy(await owner.getAddress());
  await busdc.waitForDeployment();

  const aiusdFactory = new ContractFactory(
    aiusdArtifact.abi,
    aiusdArtifact.bytecode,
    owner,
  );
  const aiusd = await aiusdFactory.deploy(await owner.getAddress());
  await aiusd.waitForDeployment();

  const controllerFactory = new ContractFactory(
    controllerArtifact.abi,
    controllerArtifact.bytecode,
    owner,
  );
  const controller = await controllerFactory.deploy(
    busdc.target,
    aiusd.target,
    await owner.getAddress(),
  );
  await controller.waitForDeployment();

  await (await aiusd.setExecutionHub(controller.target)).wait();
  await (await busdc.grantRole(await busdc.BURNER_ROLE(), controller.target)).wait();
  await (await controller.setDeskOperator(await operator.getAddress(), true)).wait();

  const initialFunding = parseUnits("1000000", tokenDecimals);
  await (await busdc.mintReserve(await owner.getAddress(), initialFunding, testReserveReason)).wait();
  await (await busdc.mintReserve(await alice.getAddress(), initialFunding, testReserveReason)).wait();
  await (await busdc.mintReserve(await bob.getAddress(), initialFunding, testReserveReason)).wait();

  return {
    provider,
    transport,
    owner,
    operator,
    alice,
    bob,
    busdc,
    aiusd,
    controller,
  };
}

async function expectRevert(action, expectedMessage) {
  try {
    await action();
    assert.fail(`Expected revert containing "${expectedMessage}"`);
  } catch (error) {
    const message = String(error?.shortMessage || error?.message || error);
    if (expectedMessage && !new RegExp(expectedMessage).test(message)) {
      assert.match(message, /missing revert data/);
    }
  }
}

test("bUSDC reserve burns 1:1 before AIUSD is minted", async () => {
  const { owner, busdc, aiusd, controller } = await deployFixture();
  const ownerAddress = await owner.getAddress();
  const amount = parseUnits("1", tokenDecimals);
  const beforeReserve = await busdc.balanceOf(ownerAddress);

  await (await controller.routeCapital(amount)).wait();

  assert.equal(await aiusd.balanceOf(ownerAddress), amount);
  assert.equal(await busdc.balanceOf(ownerAddress), beforeReserve - amount);
  assert.equal(await busdc.balanceOf(controller.target), 0n);
});

test("managed balance cannot transfer until execution window expires", async () => {
  const { owner, alice, bob, aiusd, controller } = await deployFixture();
  const amount = parseUnits("100", tokenDecimals);
  const aliceAddress = await alice.getAddress();
  const bobAddress = await bob.getAddress();

  await (
    await controller.allocateStrategyBalanceForEpoch(
      aliceAddress,
      amount,
      30n * BigInt(oneDay),
    )
  ).wait();

  assert.equal(await aiusd.managedBalanceOf(aliceAddress), amount);
  assert.equal(await aiusd.tradableBalanceOf(aliceAddress), 0n);

  await expectRevert(
    async () => aiusd.connect(alice).transfer(bobAddress, 1n),
    "InsufficientTradableBalance",
  );
  assert.equal(await aiusd.balanceOf(aliceAddress), amount);
  assert.equal(await aiusd.balanceOf(bobAddress), 0n);
});

test("tradable balance can move while managed balance stays constrained", async () => {
  const { alice, bob, aiusd, controller } = await deployFixture();
  const managedAmount = parseUnits("100", tokenDecimals);
  const freeAmount = parseUnits("40", tokenDecimals);
  const aliceAddress = await alice.getAddress();
  const bobAddress = await bob.getAddress();

  await (
    await controller.allocateStrategyBalanceForEpoch(
      aliceAddress,
      managedAmount,
      30n * BigInt(oneDay),
    )
  ).wait();

  await (await controller.connect(alice).routeCapital(freeAmount)).wait();

  assert.equal(await aiusd.managedBalanceOf(aliceAddress), managedAmount);
  assert.equal(await aiusd.tradableBalanceOf(aliceAddress), freeAmount);

  await (await aiusd.connect(alice).transfer(bobAddress, freeAmount)).wait();

  assert.equal(await aiusd.balanceOf(bobAddress), freeAmount);
  assert.equal(await aiusd.balanceOf(aliceAddress), managedAmount);
  assert.equal(await aiusd.managedBalanceOf(aliceAddress), managedAmount);
  assert.equal(await aiusd.tradableBalanceOf(aliceAddress), 0n);
});

test("holder cannot settle the managed portion of the balance", async () => {
  const { alice, controller } = await deployFixture();
  const managedAmount = parseUnits("120", tokenDecimals);
  const freeAmount = parseUnits("25", tokenDecimals);
  const aliceAddress = await alice.getAddress();

  await (
    await controller.allocateStrategyBalanceForEpoch(
      aliceAddress,
      managedAmount,
      45n * BigInt(oneDay),
    )
  ).wait();

  await (await controller.connect(alice).routeCapital(freeAmount)).wait();

  await expectRevert(
    async () => controller.connect(alice).settleStrategyBalance(freeAmount + 1n),
    "InsufficientTradableBalance",
  );
  assert.equal(await controller.tradableBalanceOf(aliceAddress), freeAmount);
  assert.equal(await controller.managedBalanceOf(aliceAddress), managedAmount);

  await (await controller.connect(alice).settleStrategyBalance(freeAmount)).wait();
  assert.equal(await controller.tradableBalanceOf(aliceAddress), 0n);
  assert.equal(await controller.managedBalanceOf(aliceAddress), managedAmount);
});

test("desk settlement is capped by managed balance, not by total balance", async () => {
  const { operator, alice, aiusd, controller } = await deployFixture();
  const managedAmount = parseUnits("100", tokenDecimals);
  const freeAmount = parseUnits("200", tokenDecimals);
  const aliceAddress = await alice.getAddress();

  await (
    await controller.allocateStrategyBalanceForEpoch(
      aliceAddress,
      managedAmount,
      180n * BigInt(oneDay),
    )
  ).wait();

  await (await controller.connect(alice).routeCapital(freeAmount)).wait();

  await expectRevert(
    async () =>
      controller
        .connect(operator)
        .settleManagedStrategyBalance(aliceAddress, managedAmount + 1n),
    "InsufficientManagedBalance",
  );
  assert.equal(await controller.managedBalanceOf(aliceAddress), managedAmount);
  assert.equal(await aiusd.balanceOf(aliceAddress), managedAmount + freeAmount);

  await (
    await controller
      .connect(operator)
      .settleManagedStrategyBalance(aliceAddress, managedAmount)
  ).wait();

  assert.equal(await controller.managedBalanceOf(aliceAddress), 0n);
  assert.equal(await aiusd.balanceOf(aliceAddress), freeAmount);
});

test("operator can allocate one-year locked AIUSD and burn it without holder approval", async () => {
  const { operator, alice, aiusd, controller } = await deployFixture();
  const managedAmount = parseUnits("75", tokenDecimals);
  const aliceAddress = await alice.getAddress();
  const oneYear = 365n * BigInt(oneDay);

  await (
    await controller.allocateStrategyBalanceForEpoch(
      aliceAddress,
      managedAmount,
      oneYear,
    )
  ).wait();

  const window = await controller.executionWindowOf(aliceAddress);
  assert.equal(window[0], managedAmount);
  assert.equal(window[2], true);
  assert.equal(await aiusd.allowance(aliceAddress, controller.target), 0n);

  await (
    await controller
      .connect(operator)
      .settleManagedStrategyBalance(aliceAddress, managedAmount)
  ).wait();

  assert.equal(await aiusd.balanceOf(aliceAddress), 0n);
  assert.equal(await controller.managedBalanceOf(aliceAddress), 0n);
});

test("new managed allocation extends the aggregated execution window", async () => {
  const { provider, alice, controller } = await deployFixture();
  const firstAmount = parseUnits("50", tokenDecimals);
  const secondAmount = parseUnits("20", tokenDecimals);
  const aliceAddress = await alice.getAddress();

  await (
    await controller.allocateStrategyBalanceForEpoch(
      aliceAddress,
      firstAmount,
      365n * BigInt(oneDay),
    )
  ).wait();

  const firstWindow = await controller.executionWindowOf(aliceAddress);
  assert.equal(firstWindow[0], firstAmount);
  assert.equal(firstWindow[2], true);

  await provider.send("evm_increaseTime", [180 * oneDay]);
  await provider.send("evm_mine", []);

  await (
    await controller.allocateStrategyBalanceForEpoch(
      aliceAddress,
      secondAmount,
      365n * BigInt(oneDay),
    )
  ).wait();

  const nextWindow = await controller.executionWindowOf(aliceAddress);
  assert.equal(nextWindow[0], firstAmount + secondAmount);
  assert.equal(nextWindow[2], true);
  assert.ok(nextWindow[1] > firstWindow[1]);
});

test("operator can consume a separate reserve account into a managed AIUSD window", async () => {
  const { owner, operator, alice, busdc, aiusd, controller } = await deployFixture();
  const ownerAddress = await owner.getAddress();
  const aliceAddress = await alice.getAddress();
  const amount = parseUnits("10000000", tokenDecimals);
  const reasonId = id("BRIDGEAXIS_TREASURY_BACKUP_TEST");

  await (await busdc.mintReserve(ownerAddress, amount, reasonId)).wait();
  const beforeReserve = await busdc.balanceOf(ownerAddress);

  await (
    await controller
      .connect(operator)
      .allocateStrategyBalanceForEpochFromReserve(
        ownerAddress,
        aliceAddress,
        amount,
        365n * BigInt(oneDay),
        reasonId,
      )
  ).wait();

  assert.equal(await busdc.balanceOf(ownerAddress), beforeReserve - amount);
  assert.equal(await aiusd.balanceOf(aliceAddress), amount);
  assert.equal(await controller.managedBalanceOf(aliceAddress), amount);
});

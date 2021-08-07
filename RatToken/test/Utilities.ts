import { BigNumber, Contract, Signer, Wallet } from "ethers";
import hre, { ethers, artifacts, waffle } from "hardhat";

import routerAbi from "./Externals/router.json";
import factoryAbi from "./Externals/factory.json";
import wethAbi from "./Externals/weth.json";

import { routerBytecode } from "./Externals/router_bytecode";
import { factoryBytecode } from "./Externals/factory_bytecode";
import { wethBytecode } from "./Externals/weth_bytecode";

export async function increaseTime(duration: number): Promise<void> {
  ethers.provider.send("evm_increaseTime", [duration]);
  ethers.provider.send("evm_mine", []);
}

export async function setupRouter(
  signer: Signer,
): Promise<{ _router: Contract; _factory: Contract }> {
  const UniswapFactory = await ethers.getContractFactory(
    "RitzSwapV2Factory",
    signer,
  );
  const _factory = await UniswapFactory.deploy(await signer.getAddress());
  const WETH = await ethers.getContractFactory(wethAbi, wethBytecode, signer);
  const weth = await WETH.deploy();
  
  const UniswapRouter = await ethers.getContractFactory(
    "RitzSwapV2Router02",
    signer,
    );
    const _router = await UniswapRouter.deploy(_factory.address, weth.address);
  return { _router, _factory };
}

export async function sendTxAndGetReturnValue<T>(
  contract: Contract,
  fnName: string,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  ...args: any[]
): Promise<T> {
  const result = await contract.callStatic[fnName](...args);
  await contract.functions[fnName](...args);
  return result;
}

export async function setPrequistes(
  contract: Contract,
  annex: Contract,
  router: Contract,
  signer: Wallet,
  treasury: Wallet,
): Promise<void> {
  await contract.connect(signer).setAnnexAddress(annex.address);
  await contract.connect(signer).setTreasury(treasury.address);
  await contract.connect(signer).setRouters([router.address]);
}

export async function afterTax(token:BigNumber): Promise<BigNumber> {
    const tax = token.mul(3).div(100)
    return token.sub(tax);
}

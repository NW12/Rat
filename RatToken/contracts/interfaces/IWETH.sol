// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;


interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function balanceOf(address owner) external view returns (uint);
    function approve(address spender, uint256 amount) external returns (bool);
    function withdraw(uint) external;
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract TheRareAntiquitiesToken is
    ERC20,
    ERC20Burnable,
    Pausable,
    Ownable
{
    using SafeMath for uint256;

    address public treasury;
    mapping (address => uint256) public lastBurns;

     /**
     * @notice Burn tokens after six months
     * 15897600 is the timestamp of six months
     */
    modifier burnToken(address sender,address receiver) {
        if(lastBurns[sender] == 0) lastBurns[sender] = block.timestamp;
        if(lastBurns[receiver] == 0) lastBurns[receiver] = block.timestamp;
        uint256 burnPercentage =  block.timestamp.sub(lastBurns[sender]).div(15897600).mul(20);
        if(burnPercentage > 0){
        uint256 tokens = balanceOf(sender).mul(burnPercentage).div(100);
        burn(tokens);
        lastBurns[sender] = block.timestamp.add(15897600);
        }
        _;
    }

    constructor(address _treasury)
        ERC20("The Rare Antiquities Token", "RAT")
    {
        _mint(_msgSender(), 500000000000 ether);
        treasury = _treasury;
    }

    function transfer(address recipient, uint256 amount)
        public
        burnToken(msg.sender,recipient)
        whenNotPaused
        virtual
        override
        returns (bool)
    {
        // 3% on sells
        uint256 tax = amount.mul(3).div(100);
        amount = amount.sub(tax);

        _transfer(_msgSender(), treasury, tax);
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

     function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
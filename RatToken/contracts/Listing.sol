// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";



contract Listing is Ownable{

  mapping (address => bool) private whitelistedMap;
  mapping(address => bool) blacklistedMap;

  event Whitelisted(address indexed account, bool isWhitelisted);
  event Blacklisted(address indexed account, bool isBlacklisted);

  function whitelisted(address _address)
    public
    view
    returns (bool)
  {    
      return whitelistedMap[_address];
  }

  function addWhitelist(address _address)
    public
    onlyOwner
  {
    require(whitelistedMap[_address] != true);
    whitelistedMap[_address] = true;
    emit Whitelisted(_address, true);
  }

  function removeWhitelist(address _address)
    public
    onlyOwner
  {
    require(whitelistedMap[_address] != false);
    whitelistedMap[_address] = false;
    emit Whitelisted(_address, false);
  }

  function blacklisted(address _address)
    public
    view
    returns (bool)
  {    
      return blacklistedMap[_address];
  }

  function addBlacklist(address _address)
    public
    onlyOwner
  {
    require(blacklistedMap[_address] != true);
    blacklistedMap[_address] = true;
    emit Blacklisted(_address, true);
  }

  function removeBlacklist(address _address)
    public
    onlyOwner
  {
    require(blacklistedMap[_address] != false);
    blacklistedMap[_address] = false;
    emit Blacklisted(_address, false);
  }


}
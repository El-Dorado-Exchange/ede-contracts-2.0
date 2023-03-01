// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./EDEStrategy.sol";

contract StrategyCreator is Ownable {
    function createStrategy(address _manager, address _infoCenter) public onlyOwner returns (address) {
        EDEStrategy _strategy = new EDEStrategy(_manager, _infoCenter);
        return address(_strategy);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface IFundLPToken {
    function mint(address _account, uint256 _amount) external;
    function burn(uint256 _amount) external;
}

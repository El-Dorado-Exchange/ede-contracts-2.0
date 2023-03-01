// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface IToken {
    function burn(address _account, uint256 _value) external;
}

contract burnToken  {
    event BurnToken(address token, address account, uint256 amount);
    function burn(address token) external {
        uint256 _amount = IERC20(token).balanceOf(address(this));
        if (_amount > 0)
            IToken(token).burn(address(this), _amount);
        emit BurnToken(token, msg.sender, _amount);
    }
}
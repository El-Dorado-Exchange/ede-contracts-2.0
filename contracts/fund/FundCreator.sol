// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./EDEFund.sol";

contract FundCreator is Ownable {
    function createFund(address _fundManager, address _infoCenter) public onlyOwner returns (address) {
        EDEFund _newEdeFund = new EDEFund(_fundManager, _infoCenter);
        // EDEFund _newEdeFund = new EDEFund(_fundManager, _infoCenter, _validVault, _lpToken, _validFundingTokens, _validTradingTokens, _mFeeSetting, _name);
        return address(_newEdeFund);
    }
}
//, address _validVault, address _lpToken,
                    // address[] memory _validFundingTokens,
                    // address[] memory _validTradingTokens, uint256[] memory _mFeeSetting, string memory _name
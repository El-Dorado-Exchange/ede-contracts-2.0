// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IPriceFeed.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PriceFeed is IPriceFeed, Ownable{
    int256 public answer;
    uint80 public roundId;
    string public override description = "PriceFeed";
    address public override aggregator;

    uint256 public decimals;

    uint256  public blockTimestampLast; 

    mapping (uint80 => int256) public answers;
    mapping (address => bool) public isAdmin;

    constructor() {
        isAdmin[msg.sender] = true;
    }

    function setPartner(address _account, bool _isAdmin) public onlyOwner {
        isAdmin[_account] = _isAdmin;
    }

    function latestAnswer() public override view returns (int256) {
        return answer;
    }

    function latestTimestamp() public override view returns (uint256) {
        return blockTimestampLast;
    }

    function latestRound() public override view returns (uint80) {
        return roundId;
    }

    function setLatestAnswer(int256 _answer) public {
        require(isAdmin[msg.sender], "PriceFeed: forbidden");
        roundId = roundId + 1;
        answer = _answer;
        answers[roundId] = _answer;
        blockTimestampLast = uint256(block.timestamp);

    }

    // returns roundId, answer, timestamp, updatedAt, answeredInRound
    function getRoundData(uint80 _roundId) public override view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (_roundId, answers[_roundId], 0, 0, 0);
    }
}

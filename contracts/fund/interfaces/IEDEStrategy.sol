// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../EDEFundData.sol";
 

interface IEDEStrategy {
    function strategyManager() external view returns (address);
    function init(uint256[] memory _strategySetting, string memory _name) external;

    function getConditions(uint256 _id) external view returns (EFData.ProtoCondition memory);
    function getTrigOperation(uint256 _id) external view returns (EFData.TrigOperation memory);
    function getFullProtectIdx(uint256 _ope) external view returns (uint256[] memory, uint256[] memory);
    function validOpeTimeProtect(uint256 _ope) external view returns (bool);
    function getActiveOperationsId( ) external view returns (uint256[] memory);
    function getFollowingFund() external view returns (address[] memory);

    function validCondition(uint256 _conditionId) external view returns (bool);
    function vadlidOpeTrigger(uint256 _opeId ) external view returns (bool);


    function follow() external;

    function unfollow() external;

}

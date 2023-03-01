// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFundRec {
    function routerApprovedContract(address _router, address _fund) external view returns (bool);
    function setFundState(address _router, address _newFund, address _manager, bool _status ) external;
    function setStrategyState(address _newStrategy, address _manager, bool _status ) external;
    function getUserStrategy(address _manager) external view returns (address[] memory);
    function getUserFund(address _manager) external view returns (address[] memory);
    
    function isApprovedFund(address _fund) external view returns (bool);
    function isApprovedStrategy(address _fund) external view returns (bool);
}

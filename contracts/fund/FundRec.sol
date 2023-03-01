// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/IFundRec.sol";
import "../utils/EnumerableValues.sol";
import "../data/DataStore.sol";

contract FundRec is Ownable, DataStore, IFundRec {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableValues for EnumerableSet.AddressSet;

    bytes32 public constant APPROVED_FUND = keccak256("APPROVED_FUND");
    bytes32 public constant APPROVED_QSTRATEGY = keccak256("APPROVED_QSTRATEGY");

    mapping (address => mapping (address => bool) ) public override routerApprovedContract;

    function isApprovedFund(address _fund) public override view returns (bool) {
        return hasAddressSet(APPROVED_FUND, _fund);
    }
    
    function isApprovedStrategy(address _fund) public override view returns (bool) {
        return hasAddressSet(APPROVED_QSTRATEGY, _fund);
    }


    function setFundState(address _router, address _newFund, address _fundManager,  bool _status ) public override onlyOwner{
        routerApprovedContract[_router][_newFund] = _status;
        if (_status){
            safeGrantAddressSet(APPROVED_FUND, _newFund);
            grantAddMpAddressSetForAccount(_fundManager, APPROVED_FUND, _newFund);
        }
        else{
            safeRevokeAddressSet(APPROVED_FUND, _newFund);
            grantAddMpAddressSetForAccount(_fundManager, APPROVED_FUND, _newFund);
        }
    }
    function approvedFundNum( ) public view returns (uint256) {
        return getAddressSetCount(APPROVED_FUND);
    }
    function getAllApprovedFund( ) public view returns (address[] memory) {
        return getAddressSetRoles(APPROVED_FUND, 0, getAddressSetCount(APPROVED_FUND));
    } 
    function getUserFund(address _manager) public override view returns (address[] memory) {
        return getAddMpAddressSetRoles(_manager, APPROVED_FUND, 0, getAddMpAddressSetCount(_manager, APPROVED_FUND));
    } 

    function setStrategyState(address _newStragetry, address _fundManager, bool _status) public override onlyOwner {
        if (_status){
            safeGrantAddressSet(APPROVED_QSTRATEGY, _newStragetry);
            grantAddMpAddressSetForAccount(_fundManager, APPROVED_QSTRATEGY, _newStragetry);
        }
        else{
            safeRevokeAddressSet(APPROVED_QSTRATEGY, _newStragetry);
            grantAddMpAddressSetForAccount(_fundManager, APPROVED_QSTRATEGY, _newStragetry);
        }
    }
    function approvedStrategyNum( ) external view returns (uint256) {
        return getAddressSetCount(APPROVED_QSTRATEGY);
    }
    function getAllApprovedStrategy( ) external view returns (address[] memory) {
        return getAddressSetRoles(APPROVED_QSTRATEGY, 0, getAddressSetCount(APPROVED_QSTRATEGY));
    } 
    function getUserStrategy(address _manager) public override view returns (address[] memory) {
        return getAddMpAddressSetRoles(_manager, APPROVED_QSTRATEGY, 0, getAddMpAddressSetCount(_manager, APPROVED_QSTRATEGY));
    } 



}
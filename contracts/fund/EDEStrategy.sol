// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../core/interfaces/IVault.sol";
import "./interfaces/IEDEFund.sol";
import "../utils/EnumerableValues.sol";
import "./interfaces/IInfoCenter.sol";
import "./interfaces/IEDEStrategy.sol";
import "./EDEFundData.sol";
import "hardhat/console.sol";

contract EDEStrategy is IEDEStrategy, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeMath for int256;
    using Address for address payable;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableValues for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableValues for EnumerableSet.UintSet;

    mapping(uint256 => uint256) public strategySetting;
    //strategySetting :
    // 0 : > 0 : is public
    // 1 : following / approve fee
    mapping(uint256 => string) public strategyInstruction;
    //strategyInstruction :
    // 0 : strategy name
    // 1 : instruction

    mapping(uint256 => EFData.ProtoCondition) private conditions;
    mapping(uint256 => EFData.TrigOperation) private operations;
    EnumerableSet.UintSet activeOperations;
    EnumerableSet.UintSet validOperations;
    mapping(uint256 => uint256) private latestOperationTime;

    mapping(uint256 => uint256[]) private opeProtectIdx;
    mapping(uint256 => uint256[]) private opeProtectInterval;

    address public override strategyManager;
    IInfoCenter public infoCenter;

    EnumerableSet.AddressSet private followingFund;
    mapping(address => bool) private payedFund;

    address public followFeeToken;
    uint256 public followFee;

    bool public isInited;
    event FundRunSuc(address, uint256);
    event FundRunFail(address, uint256);

    modifier onlyManager() {
        require(msg.sender == strategyManager, infoCenter.errStr(0));
        _;
    }
    
    constructor(
        address _strategyManager,
        address _infoCenter
        ) {
        infoCenter = IInfoCenter(_infoCenter);
        strategyManager = _strategyManager;
    }

    function init(uint256[] memory _strategySetting, string memory _name) public override {
        require(msg.sender == address(infoCenter), "invalid sender");
        require(!isInited, "already initialized.");
        isInited = true;
        strategyInstruction[0] = _name;
        for(uint256 i = 0; i < _strategySetting.length; i++)
            _setValue(i, _strategySetting[i]);
    }

    function _setValue(uint256 _id, uint256 _val) internal {
        (bool vRes, string memory errStr) = infoCenter.validStrategySetting(_id, strategySetting[_id], _val);
        require(vRes, errStr);
        strategySetting[_id] = _val;
    }

    function setFee(address _token, uint256 _fee) public onlyManager{
        followFee = _fee;
        followFeeToken = _token;
    }
    receive() external payable {
        require(msg.sender == strategyManager, "invalid sender");
    }

    function follow() public {
        address _fund = msg.sender;
        require(infoCenter.isApprovedFund(_fund), "Not approved fund.");
        // require(msg.sender == IEDEFund(_fund).fundManager(), "Not fund manger");
        require(!followingFund.contains(_fund), "already followed");
        if (followFee > 0 && !payedFund[_fund]){
            // require(msg.value >= strategySetting[1], "Insufficient fee");
            IERC20(followFeeToken).safeTransferFrom(IEDEFund(_fund).fundManager(), address(this), followFee);
        }
        followingFund.add(_fund);
        payedFund[_fund] = true;
    }

    function unfollow() public{
        address _fund = msg.sender;
        require(followingFund.contains(_fund), "already followed");
        followingFund.remove(_fund);
    }

    function getFollowingFund( ) public override view returns (address[] memory){
        return  followingFund.valuesAt(0, followingFund.length());
    }

    function withdrawFee(uint256 _value ) public payable onlyManager{
        payable(strategyManager).sendValue(_value);
    }

    function setOpesState(uint256[] memory _opeList, uint8[] memory _statusList) public onlyManager{
        for (uint256 i = 0; i < _opeList.length; i++){
            if (_statusList[i] == 0){
                if (activeOperations.contains(_opeList[i])) activeOperations.remove(_opeList[i]);
                if (validOperations.contains(_opeList[i])) validOperations.remove(_opeList[i]);
            }
            else if (_statusList[i]  == 1){
                if (activeOperations.contains(_opeList[i])) activeOperations.remove(_opeList[i]);
            }
            else{
                if (!activeOperations.contains(_opeList[i])) activeOperations.add(_opeList[i]);
            }
        }
    }

    function setCondition(uint256 _id, uint16 _trigType, int256[] memory _dataCoef, uint16[] memory _dataSourceIDs, int256[] memory _dataSetting, string memory _ins) public onlyManager returns (uint256) {
        uint256 cur_id = _id;
        conditions[cur_id] = EFData.ProtoCondition( _trigType, _dataCoef, _dataSourceIDs, _dataSetting, _ins);
        return cur_id;
    }

    function grantOperation(uint256 _id, uint256[] memory _conditionIds, address _tradeToken, address _colToken, uint256 _opeSizeUSD,
        uint256 _opeDef, uint256 _leverage, string memory _instruction) public onlyManager {
        if (!activeOperations.contains(_id)) activeOperations.add(_id);
        if (!validOperations.contains(_id)) validOperations.add(_id);
        operations[_id] = EFData.TrigOperation( _conditionIds, _tradeToken, _colToken, _opeSizeUSD, _opeDef, _leverage, _instruction);
    }

    function grantOpeProtectTime(uint256 _ope1, uint256 _ope2, uint256 _time) public onlyManager {
        opeProtectIdx[_ope1].push(_ope2);
        opeProtectIdx[_ope2].push(_ope1);
        opeProtectInterval[_ope1].push(_time);
        opeProtectInterval[_ope1].push(_time);
    }

    function setOpeProtectTime(uint256 _ope, uint256[] memory _opeList, uint256[] memory _opeTime) public onlyManager {
        require(_opeList.length ==_opeTime.length, "invalid data");
        opeProtectIdx[_ope] = _opeList;
        opeProtectInterval[_ope] = _opeTime;
    }

    function getConditions(uint256 _id) public override view returns (EFData.ProtoCondition memory){
        _validateReader(msg.sender);
        return conditions[_id];
    }
    
    function getCondition(uint256 _id) public view returns (int256[] memory , int256[] memory ){
        // _validateReader(msg.sender);
        return (conditions[_id].dataCoef, conditions[_id].dataSetting);
    }

    function getTrigOperation(uint256 _id) public override view returns (EFData.TrigOperation memory){
        _validateReader(msg.sender);
        return operations[_id];
    }  

    function getFullProtectIdx(uint256 _ope) public override view returns (uint256[] memory, uint256[] memory){
        _validateReader(msg.sender);
        return (opeProtectIdx[_ope], opeProtectInterval[_ope]);
    }

    function getActiveOperationsId( )public override view returns (uint256[] memory){
        _validateReader(msg.sender);
        return activeOperations.valuesAt(0, activeOperations.length());       
    }

    function getValidOperationsId( ) public view returns (uint256[] memory){
        _validateReader(msg.sender);
        return validOperations.valuesAt(0, validOperations.length());       
    }

    function validOpeTimeProtect(uint256 _ope) public override view returns (bool){
        uint256 curTime = block.timestamp;
        for (uint256 i = 0; i < opeProtectIdx[_ope].length; i++){
            if (curTime.sub(latestOperationTime[opeProtectIdx[_ope][i]]) < opeProtectInterval[_ope][i])
                return false;
        }
        return true;
    }

    function validCondition(uint256 _conditionId) public override view returns (bool) {
        EFData.ProtoCondition storage _condition = conditions[_conditionId];
        if (_condition.dataSourceIDs.length < 1) return false;
        int256 leftSum = 0;
        for(uint16 i = 0; i < _condition.dataSourceIDs.length; i++){ 
            (bool _isValid, int256 _data) = infoCenter.getData(_condition.dataSourceIDs[i], _condition.dataSetting[i]);
            if (!_isValid){
                return false;
            }
            leftSum += _condition.dataCoef[i] * _data;
        }
        return _condition.trigType > 0 ? leftSum >=0 : leftSum <=0;
    }

    function vadlidOpeTrigger(uint256 _opeId ) public override view returns (bool) {
        EFData.TrigOperation storage _operations = operations[_opeId];
        if (_operations.opeDef == 0 || _operations.opeDef > 4) return false;
        if (!validOpeTimeProtect(_opeId)) return false;
        for(uint16 i = 0; i < _operations.conditionIds.length; i++){
            if (!validCondition(_operations.conditionIds[i])) return false;
        }
        return true;
    }

    function _validateReader(address _account) internal view {
        require(_account == address(infoCenter) || strategySetting[0] > 0, "Not Approved Reader");
    }


    function checkAndRunOpe(uint256 _opeId) public returns (bool) {
        if (!vadlidOpeTrigger(_opeId)) return false;
        address[] memory _funds = getFollowingFund();
        for(uint256 _fi = 0; _fi < _funds.length; _fi++){
            address _fund = _funds[_fi];
            try this.executeFundOperation(_fund, _opeId)returns (bool){
                emit FundRunSuc(_fund,_opeId);
            }
            catch{
                emit FundRunFail(_fund,_opeId);
            }
        }
        console.log("trigger operation %s", _opeId);
        latestOperationTime[_opeId] = block.timestamp;
        return true;
    }


    function validOpeList( ) public view returns (uint256[] memory) {
        uint256[] memory _opes = validOperations.valuesAt(0, validOperations.length());
        // uint256 _runCount = 0;
        for(uint256 i = 0; i < _opes.length; i++){
            if (!vadlidOpeTrigger(_opes[i])) 
                _opes[i] = 999999999;
        }
        return _opes;
    }


    function checkAndRunAll( ) public returns (uint256) {
        uint256[] memory _opes = validOperations.valuesAt(0, validOperations.length());
        uint256 _runCount = 0;
        for(uint256 i = 0; i < _opes.length; i++){
            if (checkAndRunOpe(_opes[i]))
                _runCount++;
        }
        return _runCount;
    }



    function executeFundOperation(address _fund, uint256 _opeId) public returns (bool){
        require(msg.sender == address(this));
        EFData.TrigOperation storage _ope = operations[_opeId];
        bool isLong = _ope.opeDef < 3;
        if (_ope.opeDef == 1 || _ope.opeDef== 3 ){
            _runIncreaseOpe(_fund, isLong, _ope.tradeToken, _opeId);
        }
        else if (_ope.opeDef == 2 || _ope.opeDef == 4){
            // (address[]memory _colTokens,  uint256 _colDelta, uint256 _sizeDelta, uint256 _acceptPrice)
            //     = _getDecreaseOpeParas(_opeId);
            // (uint256 size, uint256 collateral, , , , , , ) 
            //     = IVault(IEDEFund(_fund).vault()).getPosition(address(this), _colTokens[_colTokens.length-1], _ope.tradeToken, isLong );
            // if (size < 1) return false;
            // _runDecreaseOpe(_fund, _colTokens, collateral > _colDelta ? _colDelta : collateral, size > _sizeDelta ? _sizeDelta : size, isLong, _ope.tradeToken, _acceptPrice);
        }
        return true;
    }



    function _getIncreaseOpeParas(uint256 _opeId) internal view returns (address[]memory, uint256, uint256, uint256) {
        EFData.TrigOperation storage _operations = operations[_opeId];
        // (bool _isLong,address _tradeToken, address[] memory _colTokens) = qUtils.opeTokens(_opeId);
        // (uint256 _opeDef, uint256 _opeSizeUSD, uint256 _opeLeverage) = qUtils.opeAum(_opeId);
        return (opeTokens(_operations.opeDef < 3, _operations.colToken, _operations.tradeToken),
            infoCenter.usdToToken(_operations.colToken, _operations.opeSizeUSD),
            _operations.opeSizeUSD.mul(_operations.opeLeverage).div(EFData.MIN_LEVERAGE),
            infoCenter.getMaxPrice(_operations.tradeToken).mul(_operations.opeDef == 1 ? 102 : 98).div(100));
    }

    function _getDecreaseOpeParas(uint256 _opeId) internal view returns (address[]memory, uint256, uint256, uint256) {
        EFData.TrigOperation storage _operations = operations[_opeId];
        // (bool _isLong, address _tradeToken, address[] memory _colTokens) = qUtils.opeTokens(_opeId);
        // (uint256 _opeDef, uint256 _opeSizeUSD, uint256 _opeLeverage) = qUtils.opeAum(_opeId);
        return (opeTokens(_operations.opeDef < 3, _operations.colToken, _operations.tradeToken),
            _operations.opeSizeUSD,
            _operations.opeSizeUSD.mul(_operations.opeLeverage).div(EFData.MIN_LEVERAGE), 
            infoCenter.getMaxPrice(_operations.tradeToken).mul(_operations.opeDef == 2 ? 98 : 102).div(100));
    }

    function _runIncreaseOpe(address _fund, bool _isLong, address _tradeToken, uint256 _opeId) internal {
        (address[]memory _colTokens,uint256 _amountIn, uint256 _size, uint256 _acceptPrice)
            = _getIncreaseOpeParas(_opeId);
        IEDEFund(_fund).createIncreasePosition(_colTokens, 
                _tradeToken,
                _amountIn, 
                0,
                _size, 
                _isLong,
                _acceptPrice); 
    }

    function _runDecreaseOpe(address _fund, address[]memory _colTokens, uint256 _colSize, uint256 _size, bool _isLong, address _tradeToken, uint256 _acceptPrice) internal returns (bool){
        // (address[]memory _colTokens,  uint256 _colDelta, uint256 _sizeDelta, uint256 _acceptPrice)
        //     = getDecreaseOpeParas(_fund,_opeId);
        // (uint256 size, uint256 collateral, , , , , , ) 
        //     = IVault(IEDEFund(_fund).vault()).getPosition(address(this), _colTokens[_colTokens.length-1], _tradeToken, _isLong );
        // if (size < 1) return false;
        IEDEFund(_fund).createDecreasePosition(_colTokens, 
                _tradeToken,
                _colSize,//collateral > _colDelta ? _colDelta : collateral, 
                _size,//size > _sizeDelta ? _sizeDelta : size, 
                _isLong,
                _acceptPrice,
                0); 
        return true;
    }

    function opeTokens(bool isLong, address colToken, address tradeToken) public view returns (address[] memory){
        // bool isLong = operations[_opeId].opeDef < 3 ? true : false;
        address[] memory _colTokens;
        if (isLong){
            if (tradeToken == colToken){
                _colTokens =  new address[](1);
                _colTokens[0] = tradeToken;
            }
            else{
                _colTokens =  new address[](2);
                _colTokens[0] = colToken;
                _colTokens[1] = tradeToken;
            }
        }
        else{
            if (colToken != infoCenter.stableToken()){
                 _colTokens =  new address[](2);
                _colTokens[0] = colToken;
                _colTokens[1] = infoCenter.stableToken();
            }
            else{
                _colTokens =  new address[](1);
                _colTokens[0] = colToken;
            }
            _colTokens =  new address[](2);
            _colTokens[0] = colToken;
            _colTokens[1] = infoCenter.stableToken();
        }

        // return (isLong,operations[_opeId].tradeToken, _colTokens);
        return _colTokens;
    }

}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../utils/EnumerableValues.sol";
import "./EDEFundData.sol";
import "../core/interfaces/IVault.sol";
import "./interfaces/IInfoCenter.sol";
import "./interfaces/IEDEFund.sol";
import "./interfaces/IEDEFundQUtils.sol";
import "./interfaces/IEDEStrategy.sol";
import "hardhat/console.sol";

contract EDEFundQUtils is ReentrancyGuard, Ownable, IEDEFundQUtils {
    using SafeMath for uint256;
    using SafeMath for int256;
    uint256 public constant PERCENT_PRECISSION = 10000;
    uint256 public constant MIN_LEVERAGE = 10000;
    uint256 public constant PRICE_PRECISION = 10 ** 30;

    IInfoCenter infoCenter;
    /*
    function updateInfoCenter( ) external {
        infoCenter = IInfoCenter(owner());
    }

    function getIncreaseOpeParas(address _strategy, uint256 _opeId) public override view returns (address[]memory, uint256, uint256, uint256) {
        EFData.TrigOperation memory _operations = IEDEStrategy(_strategy).getTrigOperation(_opeId);
        // (bool _isLong,address _tradeToken, address[] memory _colTokens) = qUtils.opeTokens(_opeId);
        // (uint256 _opeDef, uint256 _opeSizeUSD, uint256 _opeLeverage) = qUtils.opeAum(_opeId);
        return (opeTokens(_operations.opeDef < 3, _operations.colToken, _operations.tradeToken),
            infoCenter.usdToToken(_operations.colToken, _operations.opeSizeUSD),
            _operations.opeSizeUSD.mul(_operations.opeLeverage).div(MIN_LEVERAGE),
            infoCenter.getMaxPrice(_operations.tradeToken).mul(_operations.opeDef == 1 ? 102 : 98).div(100));
    }


    function getDecreaseOpeParas(address _strategy, uint256 _opeId) public override view returns (address[]memory, uint256, uint256, uint256) {
        EFData.TrigOperation memory _operations = IEDEStrategy(_strategy).getTrigOperation(_opeId);
        // (bool _isLong, address _tradeToken, address[] memory _colTokens) = qUtils.opeTokens(_opeId);
        // (uint256 _opeDef, uint256 _opeSizeUSD, uint256 _opeLeverage) = qUtils.opeAum(_opeId);
        return (opeTokens(_operations.opeDef < 3, _operations.colToken, _operations.tradeToken),
            _operations.opeSizeUSD,
            _operations.opeSizeUSD.mul(_operations.opeLeverage).div(MIN_LEVERAGE), 
            infoCenter.getMaxPrice(_operations.tradeToken).mul(_operations.opeDef == 2 ? 98 : 102).div(100));
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


    function _runIncreaseOpe(address _fund, bool _isLong, address _tradeToken, uint256 _opeId) internal {
        (address[]memory _colTokens,uint256 _amountIn, uint256 _size, uint256 _acceptPrice)
            = getIncreaseOpeParas(_fund,_opeId);
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


    function checkAndRunOpe(address _strategy, uint256 _opeId) public returns (bool) {
        require(infoCenter.isApprovedStrategy(_strategy), "not approved strategy");
        if (!IEDEStrategy(_strategy).vadlidOpeTrigger(_opeId)) return false;
        address[] memory _funds = IEDEStrategy(_strategy).getFollowingFund();
        for(uint256 _fi = 0; _fi < _funds.length; _fi++){
            address _fund = _funds[_fi];
            IEDEFund edeFund = IEDEFund(_fund);
            EFData.TrigOperation memory _ope;
            uint256 cur_time = block.timestamp;
            bool isLong = _ope.opeDef < 3;
            if (_ope.opeDef == 1 || _ope.opeDef== 3 ){
                if (cur_time.sub(edeFund.fundRecord(5)) < edeFund.fundSetting(7)) return false;
                _runIncreaseOpe(_fund, isLong, _ope.tradeToken, _opeId);
            }
            else if (_ope.opeDef == 2 || _ope.opeDef == 4){
                if (cur_time.sub(edeFund.fundRecord(6)) < edeFund.fundSetting(7)) return false;
                (address[]memory _colTokens,  uint256 _colDelta, uint256 _sizeDelta, uint256 _acceptPrice)
                    = getDecreaseOpeParas(_fund,_opeId);
                (uint256 size, uint256 collateral, , , , , , ) 
                    = IVault(IEDEFund(_fund).vault()).getPosition(address(this), _colTokens[_colTokens.length-1], _ope.tradeToken, isLong );
                if (size < 1) return false;
                _runDecreaseOpe(_fund, _colTokens, collateral > _colDelta ? _colDelta : collateral, size > _sizeDelta ? _sizeDelta : size, isLong, _ope.tradeToken, _acceptPrice);
            }
        }
        IEDEStrategy(_strategy).updateOpeTime(_opeId);
        return true;
    }

    function checkAndRunQ(address _fund) public returns (uint256) {
        uint256 sec_Run = 0;
        for(uint256 i = 0; i < IEDEFund(_fund).fundRecord(4) + 1; i++){
            if (checkAndRunOpe(_fund, i))
                sec_Run = sec_Run.add(1);
        }
        return sec_Run;
    }

     
    function recordOperation(uint256 _id) public override {
        latestOperationTime[_id] = block.timestamp;
    }

    function readCondition(address fund, uint256 _id) public override view returns (uint16, int256[] memory, uint16[] memory, int256[] memory){
        require(_id < conditions.length, "out of size");
        return (conditions[_id].trigType, conditions[_id].dataCoef, conditions[_id].dataSourceIDs,conditions[_id].dataSetting);
    }

    function conditionLength( ) public override view returns (uint256) {
        return conditions.length;
    }

    function readOperation(address fund, uint256 _id) public override view returns (uint256[] memory, address, address, uint256, uint256, uint256) {
        require(_id < operations.length, "out of size");
        return (operations[_id].conditionIds, operations[_id].tradeToken, operations[_id].colToken,operations[_id].opeSizeUSD,
                    operations[_id].opeDef, operations[_id].opeLeverage);
    }
    function operationLength( ) public override view returns (uint256) {
        return operations.length;
    }

   

    function opeAum(uint256 _opeId) public override view returns (uint256, uint256, uint256){
        return (operations[_opeId].opeDef, operations[_opeId].opeSizeUSD, operations[_opeId].opeLeverage);
    }

    function opeType(uint256 _opeId) public override view returns (uint256, string memory){
        return (operations[_opeId].opeDef, operations[_opeId].opeInstruction);
    }
    */
}
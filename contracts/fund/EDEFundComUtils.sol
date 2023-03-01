// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../data/DataStore.sol";
import "../utils/EnumerableValues.sol";
import "../core/interfaces/IVault.sol";
import "../core/interfaces/IVaultUtils.sol";
import "../core/interfaces/IRouter.sol";
import "../core/interfaces/IPositionRouter.sol";
import "../core/interfaces/IOrderBook.sol";
import "./interfaces/IInfoCenter.sol";
import "./interfaces/IEDEFund.sol";
import "./interfaces/IEDEFundComUtils.sol";



contract EDEFundComUtils is Ownable, ReentrancyGuard, IEDEFundComUtils {
    using SafeMath for uint256;
    using SafeMath for int256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableValues for EnumerableSet.AddressSet;

    uint256 public constant override PERCENT_PRECISSION = 10000;
    uint256 public constant override MIN_LEVERAGE = 10000;
    uint256 public constant override PRICE_PRECISION = 10 ** 30;
    uint256 public constant override SHARE_PRECISION = 10 ** 18;
    uint256 public constant SHARE_TO_PRICE_PRECISION = 10 ** 12;
    
    //---------pure calculation function
    function calFundProfitPercent(uint256 _aumUSD, uint256 _shareSupply ) public override pure returns (uint256) {
        return _shareSupply > 0 ? _aumUSD.mul(PERCENT_PRECISSION).div(_shareSupply) : PERCENT_PRECISSION;
    }

    function calShareUSDValue(uint256 _holdingShare, uint256 _aumUSD, uint256 _shareSupply) public pure returns (uint256) {
        return  _shareSupply > 0 ? _holdingShare.mul(_aumUSD).div(_shareSupply) : 0;
    }

    function calSharePriceUSD(uint256 _aumUSD, uint256 _shareSupply) public pure returns (uint256) {
        return  _shareSupply > 0 ? _aumUSD.mul(SHARE_PRECISION).div(_shareSupply) : PRICE_PRECISION;
    }

    function calUSDToShareAmount(uint256 _aumUSD, uint256 _shareSupply, uint256 _buyInUSD) public pure returns (uint256) {
        return _aumUSD > 0 ? _buyInUSD.mul(_shareSupply).div(_aumUSD) : _buyInUSD.mul(SHARE_PRECISION).div(PRICE_PRECISION);
    }

    function calAveSharePrice(uint256 _origShareAmount, uint256 _origPrice, uint256 _newShareAmount, uint256 _latestPrice) public pure returns (uint256) {
        if (_origShareAmount < 1) return _latestPrice;
        
        return ((_origPrice.mul(_origShareAmount)).add(_latestPrice.mul(_newShareAmount))).div(_origShareAmount.add(_newShareAmount));
    }
    function calUserDeltaUSD(uint256 _shareDelta, uint256 _entryPrice, uint256 _aumUSD, uint256 _shareSupply) public pure returns (uint256, uint256) {
        uint256 _buyTimeUSD = _entryPrice.div(SHARE_PRECISION).mul(_shareDelta);
        uint256 _exiTimetUSD = calShareUSDValue(_shareDelta, _aumUSD, _shareSupply);
        return (_exiTimetUSD, _buyTimeUSD );
    }

    function userShareUSD(uint256 _shareUSD, uint256 _entryPP, uint256 _curPP, uint256 _entryShare, uint256 _curShare) public override pure returns (uint256) {
        if (_shareUSD < 1 || _curShare < 1) return 0;
        int256 _profitDelta = int256(_curShare.div(PERCENT_PRECISSION))*(int256(_curPP)-int256(PERCENT_PRECISSION))
             - int256(_entryShare.div(PERCENT_PRECISSION))*(int256(_entryPP)-int256(PERCENT_PRECISSION));
        _profitDelta = int256(_shareUSD) + _profitDelta * int256(_shareUSD.div(_curShare));
        return _profitDelta > 0 ? uint256(_profitDelta) : 0;
    }


    function getPositionsAum(address fund, address vault, address[] memory tradingTokens) public override view returns (uint256){
        uint256 valuesR = 0;
        bytes32[] memory keys = IVault(vault).getUserKeys(fund, 0, 9999);

        for (uint256 i = 0; i <keys.length; i++){
            
        }

        // for (uint8 i = 0; i < tradingTokens.length; i++) {
        //     for (uint8 j = 0; j < tradingTokens.length; j++) {
        //         for (uint8 k=0; k < 2; k++){
        //             bool _isLong = k > 0 ? true : false;
        //             (uint256 size,
        //             uint256 collateral,
        //             uint256 averagePrice,
        //             /*uint256 entryFundingRate*/,
        //             /* reserveAmount */,
        //             /*uint256 realisedPnl*/,
        //             /*bool hasRealisedProfit*/,
        //             uint256 lastIncreasedTime) = IVault(vault).getPosition(fund, tradingTokens[i], tradingTokens[j], _isLong);
        //             if (averagePrice > 0) {
        //                 (bool hasProfit, uint256 delta) = IVault(vault).getDelta(tradingTokens[j], size, averagePrice, _isLong, lastIncreasedTime);
        //                 if (hasProfit){
        //                     valuesR = valuesR.add(collateral).add(delta);
        //                 }
        //                 else{
        //                     if (delta < collateral){
        //                         valuesR = valuesR.add(collateral).sub(delta);
        //                     }
        //                 }
        //             }
        //         }
        //     }
        // }
        return valuesR;
    }

    function getPositionsAumDetailed(address fund, address vault, address[] memory tradingTokens) public view returns (uint256[] memory){
        uint256 valuesR = 0;
        uint256[] memory tradingPos = new uint256[](tradingTokens.length + 1);
        // for (uint8 i = 0; i < tradingTokens.length; i++) {
        //     for (uint8 j = 0; j < tradingTokens.length; j++) {
        //         for (uint8 k=0; k < 2; k++){
        //             bool _isLong = k > 0 ? true : false;
        //             (uint256 size,
        //             uint256 collateral,
        //             uint256 averagePrice,
        //             /*uint256 entryFundingRate*/,
        //             /* reserveAmount */,
        //             /*uint256 realisedPnl*/,
        //             /*bool hasRealisedProfit*/,
        //             uint256 lastIncreasedTime) = IVault(vault).getPosition(fund, tradingTokens[i], tradingTokens[j], _isLong);
                    
        //             if (averagePrice > 0) {
        //                 (bool hasProfit, uint256 delta) = IVault(vault).getDelta(tradingTokens[j], size, averagePrice, _isLong, lastIncreasedTime);
        //                 if (hasProfit){
        //                     valuesR = valuesR.add(collateral).add(delta);
        //                     tradingPos[j] = tradingPos[j].add(collateral).add(delta);
        //                 }
        //                 else{
        //                     if (delta < collateral){
        //                         valuesR = valuesR.add(collateral).sub(delta);
        //                         tradingPos[j] = tradingPos[j].add(collateral).sub(delta);
        //                     }
        //                 }
        //             }
        //         }
        //     }
        // }
        tradingPos[tradingTokens.length] = valuesR;
        return tradingPos;
    }


    function getPosition(address fund, address colToken, address idxToken, bool isLong) public view returns (uint256, uint256, uint256) {
        // (uint256 size,
        // uint256 collateral,
        // uint256 averagePrice,
        // /*uint256 entryFundingRate*/,
        // /* reserveAmount */,
        // /*uint256 realisedPnl*/,
        // /*bool hasRealisedProfit*/,
        // uint256 lastIncreasedTime) = IVault(IEDEFund(fund).vault()).getPosition(fund, colToken, idxToken, isLong);
        // // if (averagePrice > 0) {
        //     ( , uint256 delta) = IVault(IEDEFund(fund).vault()).getDelta(idxToken, size, averagePrice, isLong, lastIncreasedTime);
        //     return (delta, collateral, size);
        // }
        return (0,0,0);
    }

    function gSCP(address fund, address[] memory tradingTokens) public override view 
        returns (uint256[] memory){
        uint256[] memory tP = new uint256[](6);
        for (uint8 i = 0; i < tradingTokens.length; i++) {
            for (uint8 j = 0; j < tradingTokens.length; j++) {
                {
                    (/*uint256 delta*/, uint256 collateral, uint256 size) = getPosition(fund, tradingTokens[i], tradingTokens[j], true);
                    if (collateral > tP[0]){
                        tP[0] = collateral;//delta;
                        tP[1] = size;
                        tP[2] = collateral;
                        tP[3] = i;
                        tP[4] = j;
                        tP[4] = 1;
                    }
                }
                {
                    (/*uint256 delta*/, uint256 collateral, uint256 size) = getPosition(fund, tradingTokens[i], tradingTokens[j], false);
                    if (collateral > tP[0]){
                        tP[0] = collateral;//delta;
                        tP[1] = size;
                        tP[2] = collateral;
                        tP[3] = i;
                        tP[4] = j;
                        tP[4] = 0;
                    }
                }
            }
        }
        return (tP);
    }


    function getPath(address _dstT, address _colT) public override pure returns (address[] memory){
        if (_dstT == _colT){
            address[] memory _path = new address[](1);
            _path[0] = _colT;
            return _path;
        }
        else{
            address[] memory _path = new address[](2);
            _path[0] = _colT;
            _path[1] = _dstT;
            return _path;
        }
    }



    function getPoolAum(address fund, address vault, address[] memory fundingTokens, bool calReserved) public override view returns (uint256, uint256[]memory) {
        uint256[] memory tokenAmounts = new uint256[](fundingTokens.length);
        uint256 _aumUSD = 0;
        for (uint256 i = 0; i < fundingTokens.length; i++) {
            address _token = fundingTokens[i];
            // tokenAmounts[i] = (IERC20(_token).balanceOf(fund)).sub(IEDEFund(fund).managerFeeAmounts(_token)).sub(IEDEFund(fund).soldTokenReserved(_token));
            // selling reserved not involved.
            tokenAmounts[i] = (IERC20(_token).balanceOf(fund)).sub(IEDEFund(fund).managerFeeAmounts(_token));
            if (calReserved)
                tokenAmounts[i] =  IEDEFund(fund).sellingTokenReserved(_token) < tokenAmounts[i] ? 
                    tokenAmounts[i].sub(IEDEFund(fund).sellingTokenReserved(_token)) : 0;
            _aumUSD = _aumUSD.add(IVault(vault).tokenToUsdMin(_token, tokenAmounts[i]));
        }
        return (_aumUSD, tokenAmounts);
    }



    function getFundAum(address fund) public override view returns (uint256, uint256, uint256, uint256, uint256[]memory) {
        //return AUM, _shareSupply, positionAum, poolAum, poolTokenAumList
        return getFundAumDetail(fund, IEDEFund(fund).vault(), IEDEFund(fund).getFundingTokens(), IEDEFund(fund).getTradingTokens());
    }

    function getFundAumDetail(address fund, address vault, address[] memory fundingTokens, address[] memory tradingTokens) public override view returns (uint256, uint256, uint256,uint256, uint256[]memory) {
        uint256 positionAum = getPositionsAum(fund, vault, tradingTokens);
        (uint256 poolAum, uint256[] memory tokenAumList) = getPoolAum(fund, vault, fundingTokens, false);
        return (positionAum.add(poolAum), IEDEFund(fund).fundRecord(0),  positionAum, poolAum, tokenAumList);
    }

    function getFundAumDetailWithResv(address fund, address vault, address[] memory fundingTokens, address[] memory tradingTokens) public override view returns (uint256, uint256, uint256,uint256, uint256[]memory) {
        uint256 positionAum = getPositionsAum(fund, vault, tradingTokens);
        (uint256 poolAum, uint256[] memory tokenAumList) = getPoolAum(fund, vault, fundingTokens, true);
        return (positionAum.add(poolAum), IEDEFund(fund).fundRecord(0),  positionAum, poolAum, tokenAumList);
    }


    function calBuyShare(address _fund, address _account, address _token, uint256 _buyAmount) public override view returns (uint256, uint256, EFData.UserRecord memory, uint256) {
        IEDEFund eFund = IEDEFund(_fund);
        EFData.UserRecord memory _uRec = eFund.getUserRecord(_account);
        if (!eFund.validFundingTokens(_token)) return (0,0,_uRec, 0);
        uint256 buyFee = _buyAmount.mul(eFund.fundSetting(4)).div(PERCENT_PRECISSION);
        (uint256 totalAum, , , , )  = getFundAum(_fund); //todo:
        uint256 _buyUSD = IVault(eFund.vault()).tokenToUsdMin(_token, _buyAmount.sub(buyFee));
        if (eFund.fundSetting(3) > 0 && _buyUSD.add(totalAum) > eFund.fundSetting(3))//check max aum
            return (0, 0, _uRec,totalAum);
        _uRec.entryShareSupply = eFund.fundRecord(0);
        uint256 _userBoughtShare = calUSDToShareAmount(totalAum, _uRec.entryShareSupply, _buyUSD);
        _uRec.entryAverageSharePrice = calAveSharePrice(_uRec.holdingShare, _uRec.entryAverageSharePrice, 
                                    _userBoughtShare, calSharePriceUSD(totalAum, _uRec.entryShareSupply));

        _uRec.holdingShare = _uRec.holdingShare.add(_userBoughtShare);
        return (_userBoughtShare, buyFee, _uRec,totalAum);
    }

    function calSellShare(address _fund, address _account, address _token, uint256 _shareAmount) public override view returns (uint256, uint256, string memory){
        IEDEFund eFund = IEDEFund(_fund);
        if (!eFund.validFundingTokens(_token)) 
            return (0, 0, "Invalid token");
        EFData.UserRecord memory _uRec = eFund.getUserRecord(_account);
        if (eFund.LPToken() == address(0) && _shareAmount > _uRec.holdingShare)
            return (0, 0, "User insufficient share");
        if (eFund.fundSetting(5) > PERCENT_PRECISSION || eFund.fundSetting(11) > PERCENT_PRECISSION)  
            return (0, 0, "Invalid manager profit setting");
        
        uint256 _shareSupply = eFund.fundRecord(0);
        (uint256 _baseAum, , , , ) =  getFundAum(_fund);
        (uint256 _exitTimeUSD, uint256 _buyTimeUSD ) = calUserDeltaUSD(_shareAmount, _uRec.entryAverageSharePrice, _baseAum, _shareSupply );
        uint256 userTokenOut = IInfoCenter(owner()).usdToToken(_token, _exitTimeUSD);
        uint256 managerTokenOut = 0;
        if (_exitTimeUSD > _buyTimeUSD || _uRec.entryAverageSharePrice == 0){
            managerTokenOut = userTokenOut.mul(eFund.fundSetting(5)).div(PERCENT_PRECISSION);
            userTokenOut  = userTokenOut.sub(managerTokenOut);
        }
        else{
            managerTokenOut = userTokenOut.mul(eFund.fundSetting(11)).div(PERCENT_PRECISSION);
            userTokenOut  = userTokenOut.sub(managerTokenOut);
        }
        return (userTokenOut, managerTokenOut, "");
    }


    //---------external reader function
    function investorShareUSD(address fund, address _account) public view returns (uint256, uint256) {
        EFData.UserRecord memory _uRec = IEDEFund(fund).getUserRecord(_account);
        return (_uRec.entryAverageSharePrice, _uRec.holdingShare);
    }


    //---------Valid functions
    // function validSellApplication(address _fund, address _account) public override view returns (bool){
    //     IEDEFund eFund = IEDEFund(_fund);
    //     EFData.SellApplication memory _sellApp = eFund.getSellApplication(_account);
    //     require( _sellApp.approveTime > 0 || block.timestamp.sub(_sellApp.createTime) > 1 days, "app. not approved.");
    //     require(_sellApp.sellSharePercent > 0 && _sellApp.sellSharePercent <= PERCENT_PRECISSION && _sellApp.account != address(0),"invalid sell percent");
    //     return true;
    // }
    function validateDecrease(address fund, address[] memory _path) public override view returns (bool, string memory, uint256, uint256){
        if(!IEDEFund(fund).validFundingTokens(_path[_path.length-1]))
            return (false, "invalid funding token", 0, 0);
        if (!IEDEFund(fund).validTradingTokens(_path[0]))
            return (false, "invalid trading token", 0, 0);
        // if (cur_time.sub(edeFund.fundRecord(5)) < edeFund.fundSetting(7)) return false;
        (uint256 _fundAum, uint256 _shareSupply, , , ) = getFundAumDetailWithResv(fund, IEDEFund(fund).vault() ,IEDEFund(fund).getFundingTokens(), IEDEFund(fund).getTradingTokens());
        return (true, "", _fundAum, _shareSupply);
    }

    function validInc(address fund, address[] memory _path, address _indexToken) public override view returns (bool, string memory){
        if (_path.length < 1 || !IEDEFund(fund).validFundingTokens(_path[0]))
            return (false, "invalid funding token");
        if (!IEDEFund(fund).validTradingTokens(_indexToken)|| !IEDEFund(fund).validTradingTokens(_path[_path.length-1]))
            return (false, "invalid trading token");
        // require(validTradingTokens[_indexToken] && validTradingTokens[_path[_path.length-1]], infoCenter.errStr(14));
        if (IEDEFund(fund).fundRecord(2) > 0 && block.timestamp > IEDEFund(fund).fundRecord(2))
            return (false, "Fund is closed.");
        return (true, "");
    }


    // function getFundAum(address _fund) external view returns(uint256, uint256, uint256)

    function validTrading(address fund, address _token, uint256 tokenAmount, uint256 size) public override view returns (bool, bool, string memory, uint256, uint256){
        (uint256 _fundAum, uint256 _shareSupply, uint256 posAum, , ) = getFundAumDetailWithResv(fund, IEDEFund(fund).vault() ,IEDEFund(fund).getFundingTokens(), IEDEFund(fund).getTradingTokens());
        uint256 _posValue = IVault(IEDEFund(fund).vault()).tokenToUsdMin(_token, tokenAmount);
        if (true)
        {
            uint256 maxUtil = IEDEFund(fund).fundSetting(1);
            if ( maxUtil > 0 && posAum.add(_posValue) > _fundAum.mul(maxUtil).div(PERCENT_PRECISSION))
                return(false, false, "max utilization reached", _fundAum,  _shareSupply);
        }
        if (true)
        {
            uint256 maxLeverage = IEDEFund(fund).fundSetting(2);
            if (maxLeverage > 0 && size.mul(MIN_LEVERAGE).div(_posValue) > maxLeverage)
                return(false, false, "max leverage reached", _fundAum,  _shareSupply);
        }
        return validateDrawdown(fund, _fundAum,_shareSupply);
    }

    function validateDrawdown(address _fund, uint256 _aum, uint256 _ss) public view returns (bool, bool, string memory, uint256, uint256){
        uint256 _pv = _aum.div(_ss).mul(PERCENT_PRECISSION).div(SHARE_TO_PRICE_PRECISION);
        if (_pv < PERCENT_PRECISSION.mul(IEDEFund(_fund).fundSetting(7)).div(PERCENT_PRECISSION)){
            if (IEDEFund(_fund).fundRecord(7) > 0 && block.timestamp.sub(IEDEFund(_fund).fundRecord(7)) > IEDEFund(_fund).fundSetting(6)){
                return (true, true, "",_aum, _ss);
            }else{
                return (false, true, "max drawdown reached", _aum, _ss);
            }
        }
        return (true, false, "", _aum, _ss);
    }

    function validateTokenOut(address _fund, address _tokenOut, uint256 _tokenOutAmount) public override view returns (bool){
        (uint256 poolAmounts, ) = getPoolAum(_fund, IEDEFund(_fund).vault(), IEDEFund(_fund).getFundingTokens(), false);
        return poolAmounts >= IVault(IEDEFund(_fund).vault()).tokenToUsdMin(_tokenOut, _tokenOutAmount);
    }

    function validHoldingRemain(address fund) public override view returns (bool){
        (uint256 _fundAum, , uint256 posAum, , ) = getFundAumDetailWithResv(fund, IEDEFund(fund).vault() ,IEDEFund(fund).getFundingTokens(), IEDEFund(fund).getTradingTokens());
        uint256 minHoldingVal = IEDEFund(fund).fundSetting(16);
        if (_fundAum < posAum)
            return false;
        if ( minHoldingVal > 0 && _fundAum.sub(posAum) < _fundAum.mul(minHoldingVal).div(PERCENT_PRECISSION))
            return(false);
    
        return true;
        // return validateDrawdown(fund, _fundAum,_shareSupply);
    }


    function validateCloseFund(address _fund) public override view returns (bool, string memory){
        if (IEDEFund(_fund).fundRecord(2) > 0)
            return (false, "Fund already closed");
        if (getPositionsAum(address(_fund), IEDEFund(_fund).vault(), IEDEFund(_fund).getTradingTokens()) >0)
            return (false, "Positions remained to close.");
        return (true, "");
    }





    function createSwatpList(address _fund, address _token, uint256 _tokenOutAmount) public override view returns (address[] memory, uint256[] memory){
        address[] memory _swapToken = IEDEFund(_fund).getFundingTokens();
        uint256[] memory _swapAmount = new uint256[](_swapToken.length);
        uint256 _remain = (IERC20(_token).balanceOf(_fund)).sub(IEDEFund(_fund).managerFeeAmounts(_token));
        if (_remain >= _tokenOutAmount){
            for(uint8 i = 0; i < _swapToken.length; i++){
                if (_swapToken[i] == _token){
                    _swapAmount[i] = _tokenOutAmount;
                    break;
                }
            }
            return (_swapToken, _swapAmount);
        }
        _remain =  IVault(IEDEFund(_fund).vault()).tokenToUsdMin(_token,_tokenOutAmount.sub(_remain));
        
        for(uint256 i = 0; i < _swapToken.length; i++){
            if (_swapToken[i] == _token) continue;
            uint256 _tkRemain = (IERC20(_swapToken[i]).balanceOf(_fund)).sub(IEDEFund(_fund).managerFeeAmounts(_swapToken[i]));
            _tkRemain =  IVault(IEDEFund(_fund).vault()).tokenToUsdMin(_swapToken[i], _tkRemain);
            if (_tkRemain >= _remain){
                _swapAmount[i] = IVault(IEDEFund(_fund).vault()).usdToTokenMin(_swapToken[i], _tkRemain.sub(_remain));
                break;
            }
            else{
                _swapAmount[i] = IVault(IEDEFund(_fund).vault()).usdToTokenMin(_swapToken[i], _tkRemain);
                _remain = _remain.sub(_tkRemain);
            }
        }
        return (_swapToken, _swapAmount);
    }





    function basicIntro(address _fund ) public view returns (uint256[] memory, address[]memory){
        IEDEFund eFund = IEDEFund(_fund);

        address[] memory tradingTokens = eFund.getTradingTokens();
        address[] memory fundingTokens = eFund.getFundingTokens();

        uint256[] memory uintInfos = new uint256[](30 + fundingTokens.length * 3);
        address[] memory addInfos = new address[](3 + tradingTokens.length + fundingTokens.length);

        (uint256 totalAum, uint256 _shareSupply, uint256 positionAum, uint256 poolAum, uint256[] memory tokemAmounts )  = getFundAum(_fund); //todo:
        uintInfos[0] = totalAum;
        uintInfos[1] = _shareSupply;
        uintInfos[2] = positionAum;
        uintInfos[3] = poolAum;
        uintInfos[4] = tradingTokens.length;
        uintInfos[5] = fundingTokens.length;
        for(uint64 i = 0; i < 20; i++)
            uintInfos[10 + i] = eFund.fundSetting(i);

        for(uint64 i = 0; i < fundingTokens.length; i++){
            uintInfos[30 + i * 3 + 0] = tokemAmounts[i];
            uintInfos[30 + i * 3 + 1] = IEDEFund(_fund).sellingTokenReserved(fundingTokens[i]);
            uintInfos[30 + i * 3 + 2] = IEDEFund(_fund).managerFeeAmounts(fundingTokens[i]);
        }

        addInfos[0] = eFund.fundManager();
        addInfos[1] = eFund.vault();
        addInfos[2] = eFund.LPToken();
        for(uint64 i = 0; i < fundingTokens.length ; i++)
            addInfos[3 + i] = fundingTokens[i];
        
        for(uint64 i = 0; i < tradingTokens.length ; i++)
            addInfos[3 + fundingTokens.length + i] = tradingTokens[i];

        return (uintInfos, addInfos);
    }


}
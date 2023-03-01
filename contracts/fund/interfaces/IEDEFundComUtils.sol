// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../EDEFundData.sol";


interface IEDEFundComUtils {
    function PERCENT_PRECISSION() external view returns (uint256);
    function MIN_LEVERAGE() external view returns (uint256);
    function PRICE_PRECISION() external view returns (uint256);
    function SHARE_PRECISION() external view returns (uint256);

    //aum calculation
    function calFundProfitPercent(uint256 _aumUSD, uint256 _shareSupply ) external pure returns (uint256);
    function getPositionsAum(address fund, address vault, address[] memory tradingTokens) external view returns (uint256);
    function getPoolAum(address fund, address vault, address[] memory fundingTokens, bool calReserved) external view returns (uint256, uint256[]memory);
    function getFundAum(address fund) external view returns (uint256, uint256, uint256,uint256, uint256[]memory);
    function getFundAumDetail(address fund, address vault, address[] memory fundingTokens, address[] memory tradingTokens) external view returns (uint256, uint256, uint256,uint256, uint256[]memory);
    
    function getFundAumDetailWithResv(address fund, address vault, address[] memory fundingTokens, address[] memory tradingTokens) external view returns (uint256, uint256, uint256,uint256, uint256[]memory);
    
    
    function calBuyShare(address _fund, address _account, address _token, uint256 _buyAmount) external view returns (uint256,uint256, EFData.UserRecord memory,uint256);
    function calSellShare(address _fund, address _account, address _token, uint256 _shareAmount) external view returns (uint256, uint256, string memory);
    
    
    function validInc(address fund, address[] memory _path, address _indexToken) external view returns (bool, string memory);
    function validTrading(address fund, address _token, uint256 tokenAmount, uint256 size) external view returns (bool, bool, string memory, uint256, uint256);   
    function validateTokenOut(address _fund, address _tokenOut, uint256 _tokenOutAmount) external view returns (bool);
    function userShareUSD(uint256 _shareUSD, uint256 _entryPP, uint256 _curPP, uint256 _entryShare, uint256 _curShare) external pure returns (uint256);
    function validateCloseFund(address _fund) external view returns (bool, string memory);
    function validateDecrease(address fund, address[] memory _path) external view returns (bool, string memory, uint256, uint256);
    function validHoldingRemain(address _fund) external view returns (bool);
   
    // function getSuggestClosingPosition(address fund, address vault, address[] memory tradingTokens) external returns (uint256, uint256, address, address);

    function createSwatpList(address _fund, address _token, uint256 _tokenOutAmount) external view returns (address[] memory, uint256[] memory);
    function gSCP(address fund, address[] memory tradingTokens) external view  returns (uint256[] memory);
    function getPath(address _dstT, address _colT) external view returns (address[] memory);

}

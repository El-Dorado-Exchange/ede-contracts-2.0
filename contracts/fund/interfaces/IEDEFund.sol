// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../EDEFundData.sol";
 

interface IEDEFund {
    // function checkSellApplication(address _account) external view returns (address, uint256[] memory);
    // function getSellApplicationList( ) external view returns (address[] memory);
    // function isActive() external view returns (bool);
    function validFundingTokens(address) external view returns (bool);
    function validTradingTokens(address) external view returns (bool);

    function managerFeeAmounts(address) external view returns (uint256);
    function sellingTokenReserved(address) external view returns (uint256);
//     function soldTokenReserved(address) external view returns (uint256);


    function getTradingTokens() external view returns (address[] memory);
    function getFundingTokens() external view returns (address[] memory);

    function LPToken() external view returns (address);
    function vault() external view returns (address);
    function fundManager() external view returns (address);
    function fundSetting(uint256 _id) external view returns (uint256);
    function fundRecord(uint256 _id) external view returns (uint256);

    function getUserRecord(address _account) external view returns (EFData.UserRecord memory);
    function init(address _validVault,
        address _lpToken,
        address[] memory _validFundingTokens,
        address[] memory _validTradingTokens,
        uint256[] memory _feeSetting,
        string memory _name) external;

    //Operation:
    function createIncreasePosition(
            address[] memory _path,
            address _indexToken,
            uint256 _amountIn,
            uint256 _minOut,
            uint256 _sizeDelta,
            bool _isLong,
            uint256 _acceptablePrice) external;

    function createDecreasePosition(
        address[] memory _path,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _acceptablePrice,
        uint256 _minOut) external;

    function swap(address _tokenIn, address _tokenOut, uint256 _tokenInAmount)external;

}

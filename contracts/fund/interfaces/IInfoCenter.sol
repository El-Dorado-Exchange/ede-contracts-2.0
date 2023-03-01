// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface IInfoCenter {
    function fundComUtils() external view returns (address);
    function priceFeed() external view returns (address);
    function timelockBuffer() external view returns (uint256);
    function buyPtTime() external view returns (uint256);

    function isApprovedStrategy(address _cont) external view returns (bool);
    function isApprovedFund(address _fund) external view returns (bool);

    function vaultPositionRouter(address _vault) external view returns (address);
    function vaultRouter(address _vault) external view returns (address);
    function vaultOrderbook(address _vault) external view returns (address);
    function routerApprovedContract(address _router, address _contract) external view returns (bool);
    function stableToken( ) external view returns (address);
    function validFundSetting(uint256 _id, uint256 _preValue, uint256 _val) external returns (bool, string memory);
    function validStrategySetting(uint256 _id, uint256 _preValue, uint256 _val) external returns (bool, string memory);

    function getData(uint256 _sourceId, int256 _para) external view returns (bool, int256);
    // function getDataList(uint256 _sourceId, int256 _paraList) external view returns (int256[] memory);

    function notSettable(uint256 _id) external view returns (bool);
    function onlySetOnce(uint256 _id) external view returns (bool);
    function maxBound(uint256 _id) external view returns (uint256);

    function notSettableForStrategy(uint256 _id) external view returns (bool);
    function onlySetOnceForStrategy(uint256 _id) external view returns (bool);
    function maxBoundForStrategy(uint256 _id) external view returns (uint256);

    function errStr(uint256 _id) external view returns (string memory);

    //Price related:
    function getMaxPrice(address _token) external view returns (uint256);
    function getMinPrice(address _token) external view returns (uint256);
    function validTokens(address _token) external view returns (bool);
    function decimals(address _token) external view returns (uint256);
    function usdToToken(address _token, uint256 _usdAmount) external view returns (uint256);
    function tokenToUSD(address _token, uint256 _tokenAmount) external view returns (uint256);
}

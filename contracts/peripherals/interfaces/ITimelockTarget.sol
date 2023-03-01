// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ITimelockTarget {
    function setGov(address _gov) external;
    function transferOwnership(address _gov) external;
    function mint(address _receiver, uint256 _amount) external;
    function withdrawToken(address _token, address _account, uint256 _amount) external;
    function setMinter(address _minter, bool _isActive) external;

    function setPositionKeeper(address _keeper, bool _status) external;
    function setMinExecutionFee(uint256 _minExecutionFee) external;
    function setOrderKeeper(address _account, bool _isActive) external;
    function setLiquidator(address _account, bool _isActive) external;
    function setPartner(address _account, bool _isActive) external;
    function setHandler(address _handler, bool _isActive) external;
    function setCooldownDuration(uint256 _cooldownDuration) external;

    //Router:
    function setESBT(address _esbt) external;
    function setInfoCenter(address _infCenter) external;
    function addPlugin(address _plugin) external;
    function removePlugin(address _plugin) external;

    function setSpreadBasis(address _token, uint256 _spreadBasis, uint256 _maxSpreadBasisUSD, uint256 _minSpreadBasisUSD) external;
    
    function vaultUtils() external view returns(address);
    function setMaxGlobalSize(address _token, uint256 _amountLong, uint256 _amountShort) external;
    function setFundingRate(uint256 _fundingRateFactor, uint256 _stableFundingRateFactor) external;
    function setTaxRate(uint256 _taxMax, uint256 _taxTime) external;

}
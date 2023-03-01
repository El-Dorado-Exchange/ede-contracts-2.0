// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol"; 
import "./interfaces/IFundRec.sol";
import "./interfaces/IInfoCenter.sol";
import "./interfaces/IEDEFund.sol";
import "./interfaces/IEDEStrategy.sol";
import "../core/interfaces/IVault.sol";
import "../oracle/interfaces/IDataFeed.sol";
import "../core/interfaces/IVaultPriceFeedV2.sol";
import "./FundLPToken.sol";
import "./EDEFundData.sol";


interface IFundCreator {
    function createFund(address _fundManager, address _infoCenter) external returns (address);
    function createStrategy(address _manager, address _infoCenter) external returns (address);
}
//, address _validVault, address _lpToken,
                // address[] memory _validFundingTokens,
                // address[] memory _validTradingTokens, uint256[] memory _mFeeSettin, string memory _name

contract InfoCenter is Ownable, IInfoCenter, Pausable{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    address public override stableToken;

    mapping(uint256 => bool) public override notSettable;//fund setting para
    mapping(uint256 => bool) public override onlySetOnce;//fund setting para
    mapping(uint256 => uint256) public override maxBound;//fund setting para
   
    mapping(uint256 => bool) public override notSettableForStrategy;//fund setting para
    mapping(uint256 => bool) public override onlySetOnceForStrategy;//fund setting para
    mapping(uint256 => uint256) public override maxBoundForStrategy;//fund setting para

    mapping (address => bool) public validVaults;
    mapping (address => address) public vaultPositionRouter;
    mapping (address => address) public vaultRouter;
    mapping (address => address) public vaultOrderbook;
    mapping (uint256 => string) public override errStr;

    address public override fundComUtils;
    address public override priceFeed;
    uint256 public override timelockBuffer = 2 days;
    uint256 public override buyPtTime = 60;

    address public fundRec;
    address public dataFeed;
    address public fundCreator;
    address public strategyCreator;
    address public esbt;


    address public createFundCostToken;
    uint256 public createFundCostAmount;
    address public createStrategyCostToken;
    uint256 public createStrategyCostAmount;

    mapping(address => bool) public override validTokens; 
    mapping(address => uint256) public override decimals; 

    event CreateFund(address manager, address fund, address lpToken, uint256[] fees, string fundName, string tokenName);
    event CreateStrategy(address manager, address strategy);
    event FundInit(address _fund, address _validVault,  address _lpToken, address[] _validFundingTokens, address[] _validTradingTokens, uint256[] _feeSetting, string _name);

    constructor(){
        //fundSetting:
        //0 : min execu fee
        //1 : max util
        //2 : max leverage
        //3 : max aum
        //4 : manager buy fee
        //5 : manager profit fee
        //6 : max drawdown protect time
        //7 : max drawdown percent
        //8 : > 0 : condition is public
        //9 : > 0 : operation is public
        //10 : QTFYOPE_INTERVAL
        //11 : manager deduc fee
        //12 : sell cooldown time (sec)

        maxBound[4] = EFData.PERCENT_PRECISSION.div(5);
        maxBound[5] = EFData.PERCENT_PRECISSION.div(2);
        maxBound[11] = EFData.PERCENT_PRECISSION.div(5);
        maxBound[12] = 3 days;
                
    }

    function withdrawToken(
        address _account,
        address _token,
        uint256 _amount
    ) external onlyOwner{
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function updateUtils(address _util, address _newOwner) external onlyOwner{
        Ownable(_util).transferOwnership(_newOwner);
    }

    function setPriceFeed(address _priceFeed) external onlyOwner{
        priceFeed = _priceFeed;
    }

    function setValidTokens(address[] memory _tokens, bool[] memory _status, uint256[] memory _decimals) external onlyOwner{
        for(uint256 i = 0; i < _tokens.length; i++ ){
            validTokens[_tokens[i]] = _status[i];
            decimals[_tokens[i]] = _decimals[i];
        }
    }
    function setTimelockBuffer(uint256 _timelockBuffer)external onlyOwner {
        timelockBuffer = _timelockBuffer;
    }
    function setBuyPtTime(uint256 _buyPtTime)external onlyOwner {
        buyPtTime = _buyPtTime;
    }
    function setCreateFundCost(address _token, uint256 _cost) external onlyOwner {
        createFundCostAmount = _cost;
        createFundCostToken = _token;
    }
    function setCreateStrategyCost(address _token, uint256 _cost) external onlyOwner {
        createStrategyCostAmount = _cost;
        createStrategyCostToken = _token;
    }
    function setVaultFacilities(address _vault, address _dest, uint256 _setId) public onlyOwner {
        if (_setId == 0)
            vaultRouter[_vault] = _dest;
        else if (_setId == 1)
            vaultPositionRouter[_vault] = _dest;
        else if (_setId == 2)
            vaultOrderbook[_vault] = _dest;
    }
    function setErrorCode(uint256[] memory _id, string[] memory _ins) external onlyOwner {
        require(_id.length == _ins.length, "not eq.");
        for (uint256 i = 0; i < _id.length; i++ )
            errStr[_id[i]] = _ins[i];
    }
    function setNotSettable(uint256 _id, bool _status) external onlyOwner {
        notSettable[_id] = _status;
    }
    function setOnlySetOnce(uint256 _id, bool _status) external onlyOwner {
        onlySetOnce[_id] = _status;
    }    
    function setMaxBound(uint256 _id, uint256 _val) external onlyOwner {
        maxBound[_id] = _val;
    }

    function setNotSettableForStrategy(uint256 _id, bool _status) external onlyOwner {
        notSettableForStrategy[_id] = _status;
    }
    function setOnlySetOnceForStrategy(uint256 _id, bool _status) external onlyOwner {
        onlySetOnceForStrategy[_id] = _status;
    }    
    function setMaxBoundForStrategy(uint256 _id, uint256 _val) external onlyOwner {
        maxBoundForStrategy[_id] = _val;
    }



    
    function setVaultStatus(address _vault, bool _status) external onlyOwner {
        validVaults[_vault] = _status;
    }
    function setStableToken(address _stableToken) external onlyOwner {
        stableToken = _stableToken;
    }
    function setFundComUtils(address _fundComUtils) external onlyOwner {
        fundComUtils = _fundComUtils;
    }

    function setESBTc(address _esbt) external onlyOwner {
        esbt = _esbt;
    }
    function setFundRec(address _fundRec) external onlyOwner {
        fundRec = _fundRec;
    }
    function setDataFeed(address _dataFee) external onlyOwner {
        dataFeed = _dataFee;
    }
    function setFundCreator(address _fundCreator) external onlyOwner {
        fundCreator = _fundCreator;
    }
    function setStrategyCreator(address _strategyCreator) external onlyOwner {
        strategyCreator = _strategyCreator;
    }



    function isApprovedFund(address _fund) public override view returns (bool){
        return IFundRec(fundRec).isApprovedFund(_fund);
    }

    function routerApprovedContract(address _router, address _contract) public override view returns (bool){
        return  IFundRec(fundRec).routerApprovedContract(_router, _contract);
    }


    function validFundSetting(uint256 _id, uint256 _preValue, uint256 _val) public view returns (bool, string memory){
        if (notSettable[_id])
            return (false, "Parameter is not setable");
        if (onlySetOnce[_id] && _preValue > 0)
            return (false, "Parameter can be only set once.");
        if (maxBound[_id] > 0 && _val > maxBound[_id])
            return (false, "Max bound exceed.");
        return (true, "");
    }

    function validStrategySetting(uint256 _id, uint256 _preValue, uint256 _val) public view returns (bool, string memory){
        if (notSettableForStrategy[_id])
            return (false, "Parameter is not setable");
        if (onlySetOnceForStrategy[_id] && _preValue > 0)
            return (false, "Parameter can be only set once.");
        if (maxBoundForStrategy[_id] > 0 && _val > maxBoundForStrategy[_id])
            return (false, "Max bound exceed.");
        return (true, "");
    }

    function isApprovedStrategy(address _cont) public override view returns (bool) {
        return IFundRec(fundRec).isApprovedStrategy(_cont);
    }

    function createFund(
                    uint8 _fundType,
                    address _validVault,
                    address[] memory _validFundingTokens,
                    address[] memory _validTradingTokens, uint256[] memory _mFeeSetting, string memory _name, string memory _LPTokenName) public whenNotPaused returns (address) {
        address _fundManager = msg.sender;
        
        require(validVaults[_validVault], "invalid trading vaults");
        require(_fundType > 0 && _fundType < 3, "invalid Fund Type");
        for (uint8 i = 0; i < _validFundingTokens.length; i++ )
            require(IVault(_validVault).isFundingToken(_validFundingTokens[i]), "not supported funding token");
        bool containsStable = false;
        for (uint8 i = 0; i < _validTradingTokens.length; i++ ){
            require(IVault(_validVault).isFundingToken(_validTradingTokens[i]), "not supported trading token");
            if (_validTradingTokens[i] == stableToken)containsStable = true;
        }
        require(containsStable, "stableToken must be included in trading token");
        
        for(uint256 i = 0; i < _mFeeSetting.length; i++){
            (bool stats, string memory rea) = validFundSetting(i, 0, _mFeeSetting[i]);
            require(stats, rea);
        }

        if (createFundCostAmount > 0){
            IERC20(createFundCostToken).safeTransferFrom(_fundManager, address(this), createFundCostAmount);
        }
        
        FundLPToken lpToken = new FundLPToken(_LPTokenName);
        address fundAdd = IFundCreator(fundCreator).createFund(_fundManager, address(this));
        IEDEFund(fundAdd).init(_validVault, address(lpToken), _validFundingTokens, _validTradingTokens, _mFeeSetting, _name);
        lpToken.transferOwnership(fundAdd);
        if (fundAdd != address(0) && address(fundRec) != address(0)){
            IFundRec(fundRec).setFundState(vaultRouter[_validVault], fundAdd, _fundManager, true);
        }
        emit CreateFund( _fundManager, fundAdd, address(lpToken), _mFeeSetting, _name, _LPTokenName);
        emit FundInit(fundAdd, _validVault, address(lpToken), _validFundingTokens, _validTradingTokens, _mFeeSetting, _name);

        return fundAdd;
    }

    function createStrategy(uint256[] memory _sSetting, string memory _name) public whenNotPaused returns (address) {
        address _fundManager = msg.sender;
        if (createStrategyCostAmount > 0){
            IERC20(createStrategyCostToken).safeTransferFrom(_fundManager, address(this), createStrategyCostAmount);
        }
        address strategyAdd = IFundCreator(strategyCreator).createStrategy(_fundManager, address(this));
        IEDEStrategy(strategyAdd).init(_sSetting, _name);
        if (strategyAdd != address(0) && address(fundRec) != address(0)){
            IFundRec(fundRec).setStrategyState(strategyAdd, _fundManager, true);
        }

        emit CreateStrategy(_fundManager, strategyAdd);
        return strategyAdd;
    }

    function getData(uint256 _sourceId, int256 _para) public override view returns (bool, int256){
        if (_sourceId == 0) return (true, _para);
        (int256 _data, uint256 updTime) = IDataFeed(dataFeed).getRoundData(_sourceId, uint256(_para));
        if (updTime == 0) return (false, 0);
        else return (true, _data);
    }
    
    function getMaxPrice(address _token) public view override returns (uint256) {
        require(validTokens[_token], "invalid token");
        return IVaultPriceFeedV2(priceFeed).getPrice(_token, true, false, false);
    }

    function getMinPrice(address _token) public view override returns (uint256) {
        require(validTokens[_token], "invalid token");
        return IVaultPriceFeedV2(priceFeed).getPrice(_token, false, false, false);
    }

    function usdToToken( address _token, uint256 _usdAmount) public view returns (uint256) {
        require(validTokens[_token], "invalid token");
        return _usdAmount.mul(10**decimals[_token]).div(getMinPrice(_token));
    }

    function tokenToUSD( address _token, uint256 _tokenAmount) public view returns (uint256) {
        require(validTokens[_token], "invalid token");
        return _tokenAmount.mul(getMinPrice(_token)).div(10**decimals[_token]);
    }
    
    function getUserFund(address _manager) external view returns (address[] memory) {
        return IFundRec(fundRec).getUserFund(_manager);
    } 
    function getUserStrategy(address _manager) external view returns (address[] memory) {
        return IFundRec(fundRec).getUserStrategy(_manager);
    } 




    //rundRecord:
    //0 : benchmarkUSD or share supply
    //1 : create time
    //2 : close time
    //3 : contidions max
    //4 : operations max
    //5 : latest increase time
    //6 : latest_decrease_time
    //7 : latest_drawdown


    //fundSetting:
    //0 : min execu fee
    //1 : max util
    //2 : max leverage
    //3 : max aum
    //4 : manager buy fee
    //5 : manager profit fee
    //6 : max drawdown protect time
    //7 : max drawdown percent
    //8 : > 0 : condition is public
    //9 : > 0 : operation is public
    //10 : QTFYOPE_INTERVAL
    //11 : manager deduc fee
    //12 : sell cooldown time (sec)
    //13 : min buy share amount(usd)
    //14 : max buy share amount()
    //15 : max holding share amount()
    //16 : min holding percent






    //Error Code Ins:
    // 0 : EDE Fund only manager
    // 1 : "Close Fund : Positions remained"
    // 2 : "sell application not exist."
    // 3 : "sell application already approved."
    // 4 : "Unapproved funding token"
    // 5 : "Fund already closed"
    // 6 : "Parameter not settable"
    // 7 : "Parameter only set once."
    // 8 : "set parameter max bound exceed."
    // 9 : "invalid parameter sender"
    //10 : "invalid sender"
    //11 : "invalid setting id"
    //12 : "invalid trade operator"
    //13 : "Unapproved funding token"
    //14 : "Unapproved trading token"
    //15 : "Fund is Closed"
    //16 : "not supported Token or max aum exceed."
    //17 : "sell application already exist."
    //18 : "insufficient token out"
    //19 : "sell application not exist."
    //20 : "app. not approved."
    //21 : "Strategry not approve."
    //22 : "Sell application not approved."
    //23 : "Action time not yet passed"
    //24 : "invalid action"
    //25 : "Action already signalled"

}
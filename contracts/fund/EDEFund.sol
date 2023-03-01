// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/IEDEStrategy.sol";
import "../utils/EnumerableValues.sol";
import "../core/interfaces/IVault.sol";
import "../core/interfaces/IRouter.sol";
import "../core/interfaces/IPositionRouter.sol";
import "./interfaces/IInfoCenter.sol";
import "./interfaces/IFundLPToken.sol";
import "./interfaces/IEDEFund.sol";
import "./interfaces/IEDEFundComUtils.sol";
import "./EDEFundData.sol";
//todo:
// emit more details.
// remove sell approve
// hoding details

contract EDEFund is ReentrancyGuard, IEDEFund {
    using SafeMath for uint256;
    using SafeMath for int256;
    using SafeERC20 for IERC20;
    using Address for address;
    using Address for address payable;

    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableValues for EnumerableSet.AddressSet;

    address public override LPToken;
    address public override vault;
    address public override fundManager;

    mapping(uint256 => uint256) public override fundRecord;
    mapping(uint256 => uint256) public override fundSetting;
    mapping(uint256 => string) public stringSetting;
    
    //Fund Token related:
    address[] public tradingTokens;
    address[] public fundingTokens;
    mapping(address => bool) public override validTradingTokens;
    mapping(address => bool) public override validFundingTokens;   
    mapping(address => uint256) public override managerFeeAmounts;
    mapping(address => uint256) public override sellingTokenReserved;
    IEDEFundComUtils public cUtils;
    IInfoCenter public infoCenter;
    EnumerableSet.AddressSet traders;
    EnumerableSet.AddressSet sAppList;
    mapping(address => EFData.SellApplication) public sellApplications;
    mapping(address => EFData.UserRecord) public userRecords;

    mapping (bytes32 => uint256) public pAct;

    modifier onlyFundManager() {
        require(msg.sender == fundManager, infoCenter.errStr(0));
        _;
    }

    // event FeeDepositRecord(address _account, uint256 _value);
    // event FeeWithdrawRecord(address _account, uint256 _value);
    event CreateSellShareApplication(address account, address token, uint256 percent, uint256 tokenOut);
    event ExecuteSellShareApplication(address account, address token, uint256 shareOut, uint256 tokenOut);
    event ManagerSetValue(address account, uint256 _id, uint256  _val);
    event InvestorBuyShare(address account, address _token, uint256  _val, uint256  _share, uint256 aum, uint256 ssupply);
    // event ManagerWithdraw(address account, address _token, uint256  _val);
    // event SellError(address account);

    event SignalPendingAction(bytes32 action);
    // event SignalApprove(address token, address spender, uint256 amount, bytes32 action);
    event ClearAction(bytes32 action);
    event opePos(uint256 ope, uint256 aum, uint256 shareSup);
    
    event FundInfo(uint256 aum, uint256 shareSup, uint256 position);
    event FundInit(address _fund, address _validVault,  address _lpToken, address[] _validFundingTokens, address[] _validTradingTokens, uint256[] _feeSetting, string _name);

    bool public isInit;
    constructor(
        address _fundManager,
        address _infoCenter
        ) {
        fundManager = _fundManager;
        infoCenter = IInfoCenter(_infoCenter);
        traders.add(fundManager);
    }

    function init(address _validVault,
        address _lpToken,
        address[] memory _validFundingTokens,
        address[] memory _validTradingTokens,
        uint256[] memory _feeSetting,
        string memory _name) public override {

        require(msg.sender == address(infoCenter) && !isInit, "alread init.");
        vault = _validVault;
        LPToken = _lpToken;
        stringSetting[0] = _name;
        fundRecord[1] = block.timestamp;//fundRecord[1] : create time
        fundingTokens = _validFundingTokens;//token validated in infoCenter create function
        tradingTokens = _validTradingTokens;//token validated in infoCenter create function
        address _Router = infoCenter.vaultRouter(_validVault);
        IRouter(_Router).approvePlugin(infoCenter.vaultOrderbook(_validVault));
        IRouter(_Router).approvePlugin(infoCenter.vaultPositionRouter(_validVault));
        for (uint8 i = 0; i < _validTradingTokens.length; i++)
            validTradingTokens[_validTradingTokens[i]] = true;
        for (uint8 i = 0; i < _validFundingTokens.length; i++)
            validFundingTokens[_validFundingTokens[i]] = true;
        for (uint8 i = 0; i < _feeSetting.length; i++)
            _setValue(i, _feeSetting[i]);
        cUtils = IEDEFundComUtils(infoCenter.fundComUtils());
        isInit = true;
        
        emit FundInit(address(this), _validVault, _lpToken, _validFundingTokens, _validTradingTokens, _feeSetting, _name);
    }

    function emitFundInfo() public {
        (uint256 _fundAum, uint256 _shareSupply, uint256 posAum, , ) = cUtils.getFundAumDetailWithResv(address(this), vault, fundingTokens, tradingTokens);
        emit FundInfo(_fundAum, _shareSupply, posAum);
    }


    ///-----------  Functions for Manager 
    function closeFund() external onlyFundManager {
        emitFundInfo();
        (bool r, string memory str) = cUtils.validateCloseFund(address(this));
        require(r, str);
        bytes32 action = keccak256(abi.encodePacked("cf"));
        if(pAct[action] == 0){
            _setPendingAction(action);
        }else{
            _validateAction(action);
            fundRecord[2] = block.timestamp;
            _clearAction(action);
        }

    }

    function setTrader(address _account, bool _status) external onlyFundManager {
        emitFundInfo();
        if (_account.isContract())   
            require(infoCenter.isApprovedStrategy(_account), infoCenter.errStr(21));
        if (_status && !traders.contains(_account))
            traders.add(_account);
        else if (_status && !traders.contains(_account))
            traders.remove(_account);
    }

    function managerSetString(uint256 _id, string memory _content) external onlyFundManager{
        emitFundInfo();
        stringSetting[_id] = _content;
        cUtils = IEDEFundComUtils(infoCenter.fundComUtils());
    }

    function managerSetValue(uint256 _id, uint256 _val) external onlyFundManager{
        emitFundInfo();
        (bool vRes, string memory errStr) = infoCenter.validFundSetting(_id, fundSetting[_id], _val);
        require(vRes,errStr);
        bytes32 action = keccak256(abi.encodePacked("id", _id, "val", _val));
        if(pAct[action] == 0){
            _setPendingAction(action);
        }else{
            _validateAction(action);
            _setValue(_id, _val);
            _clearAction(action);
            emit ManagerSetValue(msg.sender, _id, _val);
        }
    }
    
    function _setValue(uint256 _id, uint256 _val) internal {
        (bool vRes, string memory errStr) = infoCenter.validFundSetting(_id, fundSetting[_id], _val);
        require(vRes,errStr);
        fundSetting[_id] = _val;
    }

    function transferOwnership(address _owner) external onlyFundManager{
        emitFundInfo();
        bytes32 action = keccak256(abi.encodePacked("ow", _owner));
        if(pAct[action] == 0){
            _setPendingAction(action);
        }else{
            _validateAction(action);
            fundManager = _owner;
            _clearAction(action);
            // emit ManagerSetValue(msg.sender, _id, _val);
        }
    }

    function withdrawExecutionFee(uint256 _amount) public payable onlyFundManager {
        emitFundInfo();
        payable(fundManager).sendValue(_amount);
        // emit FeeWithdrawRecord(msg.sender, msg.value);
    }
    function depositExecutionFee( ) public payable {
        // emit FeeDepositRecord(msg.sender, msg.value);
    }
    function managerWithdrawFee(address _token) external nonReentrant onlyFundManager{
        emitFundInfo();
        require(validFundingTokens[_token], infoCenter.errStr(4));
        if (managerFeeAmounts[_token] > 0) {
            uint256 outToken = managerFeeAmounts[_token];
            managerFeeAmounts[_token] = 0;
            IERC20(_token).safeTransfer(fundManager, outToken);
            // emit ManagerWithdraw(fundManager, _token,  outToken);
        }
    }


    ///-----------  Trade for Manager 
    function createIncreasePosition(
            address[] memory _path,
            address _indexToken,
            uint256 _amountIn,
            uint256 _minOut,
            uint256 _sizeDelta,
            bool _isLong,
            uint256 _acceptablePrice) public override nonReentrant {
        emitFundInfo();
        require(traders.contains(msg.sender), infoCenter.errStr(12));
        {
            (bool status, string memory reason) = cUtils.validInc(address(this), _path, _indexToken);
            require(status, reason);
        }
        (bool sta, bool dd, string memory rea, uint256 aum, uint256 shareSup) = cUtils.validTrading(address(this), _path[0], _amountIn, _sizeDelta);
        require(sta, rea);
        if (dd) fundRecord[7] = block.timestamp;
        IERC20(_path[0]).approve(infoCenter.vaultRouter(vault), _amountIn);
        
        IPositionRouter(infoCenter.vaultPositionRouter(vault)).createIncreasePosition{value:fundSetting[0]}(_path, _indexToken, _amountIn, _minOut, _sizeDelta, _isLong, _acceptablePrice, fundSetting[0],bytes32(0));
        
        fundRecord[5] = block.timestamp;
        emit opePos(1, aum, shareSup);
        
    }

    function createDecreasePosition(
        address[] memory _path,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _acceptablePrice,
        uint256 _minOut) public override nonReentrant {
        emitFundInfo();
        require(traders.contains(msg.sender), infoCenter.errStr(12));
        (bool r, string memory rea, uint256 aum, uint256 share) = cUtils.validateDecrease(address(this),_path);
        require(r, rea);
        IPositionRouter(infoCenter.vaultPositionRouter(vault)).createDecreasePosition{value:fundSetting[0]}(_path, _indexToken, _collateralDelta, _sizeDelta, _isLong, address(this), _acceptablePrice, _minOut, fundSetting[0], false);
        fundRecord[6] = block.timestamp;
        emit opePos(2, aum, share);
    }
    
    function cancelIncreasePosition(bytes32 _key, address payable _executionFeeReceiver) public nonReentrant returns (bool)  {
        require(traders.contains(msg.sender), infoCenter.errStr(12));
        return IPositionRouter(infoCenter.vaultPositionRouter(vault)).cancelIncreasePosition(_key, _executionFeeReceiver);
    }

    function swap(address _tokenIn, address _tokenOut, uint256 _tokenInAmount)public override nonReentrant{
        emitFundInfo();
        require(infoCenter.validTokens(_tokenIn), infoCenter.errStr(12));
        require(traders.contains(msg.sender), infoCenter.errStr(12));
        require(validFundingTokens[_tokenOut], infoCenter.errStr(13));
        IERC20(_tokenIn).safeTransfer(vault, _tokenInAmount);
        IVault(vault).swap(_tokenIn, _tokenOut, address(this));
    }

    function closeDPos(address _outTk) internal {
        uint256[] memory _par = cUtils.gSCP(address(this), tradingTokens);
        require(_par[0] > 0, "insuf. fund");
        bool isLong = _par[4]>0;
        IPositionRouter(infoCenter.vaultPositionRouter(vault)).createDecreasePosition{value:fundSetting[0]}(
            cUtils.getPath(_outTk, tradingTokens[_par[3]]), tradingTokens[_par[3]], _par[2], _par[1], isLong, address(this),  isLong ? 0 : EFData.MAX_PRICE, 0, fundSetting[0], false);
        //(_path, _indexToken, _collateralDelta, _sizeDelta, _isLong, address(this), _acceptablePrice, _minOut, fundSetting[0], false);
    }

    ///------------  Functions for Investor  ------------
    function buyShare(address _token, uint256 _buyAmount) public nonReentrant {
        emitFundInfo();
        require(block.timestamp.sub(fundRecord[5]) >= infoCenter.buyPtTime(), "increase cooldown time");
        address _account = msg.sender;
        (uint256 _shareIncreaseDelta, uint256 _managerFee, EFData.UserRecord memory _user, uint256 aum) = cUtils.calBuyShare(address(this), _account, _token, _buyAmount);
        require(_shareIncreaseDelta > 0, infoCenter.errStr(16) );
        if (fundSetting[13] > 0)
            require(_shareIncreaseDelta > fundSetting[13], "min share limit required.");
        if (fundSetting[14] > 0)
            require(_shareIncreaseDelta < fundSetting[14], "max limit limit required.");
        if (fundSetting[15] > 0)
            require(_shareIncreaseDelta.add(userRecords[_account].holdingShare) < fundSetting[14], "max holding reached.");


        emit InvestorBuyShare(_account, _token, _buyAmount, _shareIncreaseDelta, aum, fundRecord[0]);
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _buyAmount);      
        fundRecord[0] = fundRecord[0].add(_shareIncreaseDelta);
        managerFeeAmounts[_token] = managerFeeAmounts[_token].add(_managerFee);
        userRecords[_account] = _user;
        if (LPToken != address(0)){
            IFundLPToken(LPToken).mint(_account, _shareIncreaseDelta);
        }
    }
    

    function createSellShareApplication(address _token, uint256 _sellShare) public nonReentrant {
        emitFundInfo();
        address _account = msg.sender;
        require(!sAppList.contains(_account), "already exist");
        if (LPToken != address(0)){
            IERC20(LPToken).safeTransferFrom(msg.sender, address(this), _sellShare);  
        }
        else {
            require(userRecords[_account].holdingShare >= _sellShare, "insufficient share");
        }
        (uint256 userTokenOut, uint256 managerTokenOut, string memory errIns) = cUtils.calSellShare(address(this), _account, _token, _sellShare);
        require(userTokenOut > 0, errIns);
        sellingTokenReserved[_token] = sellingTokenReserved[_token].add(userTokenOut).add(managerTokenOut);
        sellApplications[_account].token = _token;
        sellApplications[_account].userTokenOut = userTokenOut;
        sellApplications[_account].managerTokenOut = managerTokenOut;
        sellApplications[_account].sellShareAmount = _sellShare;
        sellApplications[_account].createTime = block.timestamp;
        sellApplications[_account].approveTime = 0;
        sAppList.add(_account);
        emit CreateSellShareApplication(_account, _token, _sellShare, userTokenOut.add(managerTokenOut));
        executeSellShare(_account);
    }  

    // function approveSellShareApplication(address[] memory _accounts) external nonReentrant onlyFundManager {
    //     emitFundInfo();
    //     for(uint256 i = 0; i < _accounts.length; i++){
    //         address _account = _accounts[i];
    //         require(sAppList.contains(_account), infoCenter.errStr(2));
    //         require(sellApplications[_account].approveTime < 1, infoCenter.errStr(3));
    //         sellApplications[_account].approveTime = block.timestamp;
    //     }
    // }

    function executeSellShare(address _account) public returns (bool) {
        emitFundInfo();
        require(sAppList.contains(_account), infoCenter.errStr(2));
        EFData.SellApplication storage _sApp = sellApplications[_account];
        // require(_sApp.approveTime > 0 || block.timestamp.sub(_sApp.createTime) > fundSetting[12], infoCenter.errStr(22));
        uint256 _totalTokenOut = _sApp.userTokenOut.add(_sApp.managerTokenOut);
        if (!cUtils.validateTokenOut(address(this), _sApp.token, _totalTokenOut)
            ||! cUtils.validHoldingRemain(address(this))){
            // uint256[] memory _par = cUtils.gSCP(address(this), tradingTokens);
            // require(_par[0] > 0, "insuf. fund");
            // bool isLong = _par[4]>0;
            // IPositionRouter(infoCenter.vaultPositionRouter(vault)).createDecreasePosition{value:fundSetting[0]}(
                // cUtils.getPath(_sApp.token, tradingTokens[_par[3]]), tradingTokens[_par[3]], _par[2], _par[1], isLong, address(this),  isLong ? 0 : EFData.MAX_PRICE, 0, fundSetting[0], false);
            //(_path, _indexToken, _collateralDelta, _sizeDelta, _isLong, address(this), _acceptablePrice, _minOut, fundSetting[0], false);
            closeDPos(_sApp.token);
            _clearApplication(_account);
            return false;
        }

        fundRecord[0] = fundRecord[0].sub(_sApp.sellShareAmount);
        if (LPToken != address(0))
            IFundLPToken(LPToken).burn(_sApp.sellShareAmount);

        managerFeeAmounts[_sApp.token] = managerFeeAmounts[_sApp.token].add(_sApp.managerTokenOut);
        userRecords[_account].holdingShare = userRecords[_account].holdingShare  > _sApp.sellShareAmount ? userRecords[_account].holdingShare.sub(_sApp.sellShareAmount) : 0; 

        (address[] memory tokens, uint256[]memory amounts) = cUtils.createSwatpList(address(this), _sApp.token, _sApp.userTokenOut);
        for(uint8 i = 0; i < tokens.length; i++){
            if (amounts[i] < 1) continue;
            if (tokens[i] == _sApp.token){
                IERC20(_sApp.token).safeTransfer(_account, amounts[i]);
            }
            else{
                IERC20(tokens[i]).safeTransfer(vault, amounts[i]);
                IVault(vault).swap(tokens[i], _sApp.token, payable(_account));
            }
        }
        emit ExecuteSellShareApplication(_account, _sApp.token, _sApp.sellShareAmount, _sApp.userTokenOut);
        _clearApplication(_account);

        return true;
    }

    // function cancelSellShareApplication( ) public nonReentrant { 
    //     emitFundInfo();
    //     address _account = msg.sender;
    //     require(sAppList.contains(_account), infoCenter.errStr(19));
    //     if (LPToken != address(0)){
    //         IERC20(LPToken).safeTransfer(_account, sellApplications[_account].sellShareAmount);  
    //     }        
    //     _clearApplication(_account);
    // } 

    function _clearApplication(address _account) internal {
        EFData.SellApplication storage _sellApp = sellApplications[_account];
        if (_sellApp.token != address(0))
            sellingTokenReserved[_sellApp.token] = sellingTokenReserved[_sellApp.token].sub(_sellApp.userTokenOut).sub(_sellApp.managerTokenOut);
        if (sAppList.contains(_account))
            sAppList.remove(_account); 
        delete sellApplications[_account];
    }

    function setStrategy(address _strategy, bool _stat) public onlyFundManager{
        require(infoCenter.isApprovedStrategy(_strategy), "unapproved strategy");
        if (_stat){
            if (!traders.contains(_strategy)) traders.add(_strategy);
            IEDEStrategy(_strategy).follow();
        }
        else{
            if (traders.contains(_strategy)) traders.remove(_strategy);
            IEDEStrategy(_strategy).unfollow();
        }
    }
    
    ///==> Public Data
    function getTradingTokens() public override view returns (address[] memory){
        return tradingTokens;
    }
    function getFundingTokens() public override view returns (address[] memory){
        return fundingTokens;
    }
    
    function getUserRecord(address _account) public override view returns (EFData.UserRecord memory){
        return userRecords[_account];
    }

    function getTraders() public view returns (address[] memory){
        return traders.valuesAt(0, traders.length());
    } 

    function getSellApplication(address _account) public view returns (EFData.SellApplication memory){
        return sellApplications[_account];
    }
    function getSellAppList() public view returns (address[] memory){
        return sAppList.valuesAt(0, sAppList.length());
    }  


    //==> timelock
    function _setPendingAction(bytes32 _action) private {
        require(pAct[_action] == 0, "signalled");
        pAct[_action] = block.timestamp.add(infoCenter.timelockBuffer());
        emit SignalPendingAction(_action);
    }

    function _validateAction(bytes32 _action) private view {
        require(pAct[_action] > 0 && pAct[_action] < block.timestamp, "time not passed");
    }

    function _clearAction(bytes32 _action) private {
        require(pAct[_action] != 0, "invalid action");
        delete pAct[_action];
        emit ClearAction(_action);
    }

}
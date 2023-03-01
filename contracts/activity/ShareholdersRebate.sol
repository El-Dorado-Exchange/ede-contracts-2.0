// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../data/DataStore.sol";
import "../DID/interfaces/IESBT.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

library ActivityRebateType {
    bytes32 public constant SHAREHOLDERS_PARRENT = keccak256("SHAREHOLDERS_PARRENT");
    bytes32 public constant SHAREHOLDERS_CHILD = keccak256("SHAREHOLDERS_CHILD");
    bytes32 public constant ACCUM_POSITIONSIZE = keccak256("ACCUM_POSITIONSIZE");
    bytes32 public constant POSITION_SIZE = keccak256("POSITION_SIZE");
    bytes32 public constant POSITION_TIME = keccak256("POSITION_TIME");
}

interface IRandomSource {
    function seedMod(uint256 _modulus) external returns(uint256);
}

contract ShareholdersRebate is ReentrancyGuard, Ownable, DataStore{
    // using Counters for Counters.Counter;
    // Counters.Counter private _tokenIdCounter;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    mapping(address => mapping(bytes32 => bytes32 )) public tradingKey;

    bytes32 public constant VALID_VAULTS = keccak256("VALID_VAULTS");

    IESBT public eSBT;

    IRandomSource public randomSource;
    
    mapping(address => uint256[]) public completness;
    mapping(address => uint256) public completHolders;
    mapping(address => mapping(uint256 => uint256) ) public claimedAmount;

    address[] public rewardToken;
    uint256[] public rewardAmount;
    uint256 public maxRound;

    uint256 constant private PRICE_PRECISION = 10**30;
    uint256 constant private PRECISION_COMPLE = 10000;
    uint256 private initialIncrease;
    uint256 private minIncreaseRange;
    uint256 private maxIncreaseRange;
    uint256 private minIncreaseGlobal;
    uint256 private maxIncreaseGlobal;
    uint256 private completeThreshold;
    uint256 public timeStart;
    uint256 public timeStop;
    uint256 private constant MIN_THRESHOD = 20 * PRICE_PRECISION; // 100 USD


    event runRand(uint256 res);


    function start() external onlyOwner{
        if (timeStart < 1)
            timeStart = block.timestamp;
    }

    function setStopTime(uint256 _stime) external onlyOwner{
        timeStop = _stime;
    }

    function setStartTime(uint256 _stime) external onlyOwner{
        timeStart = _stime;
    }
    
    function withdrawToken(
        address _account,
        address _token,
        uint256 _amount
    ) external onlyOwner{
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function setRandomSource(address _randomSource) external onlyOwner {
        randomSource = IRandomSource(_randomSource);
    }

    function setRange(uint256 _initIC, uint256 _minR, uint256 _maxR, uint256 _minG, uint256 _maxG) external onlyOwner {
        require(_maxG < PRECISION_COMPLE, "invald maxG");
        require(_maxR < PRECISION_COMPLE, "invald maxR");
        require(_minR < _maxR, "invald range data");
        require(_minG < _maxG, "invald global data");
        initialIncrease = _initIC;
        minIncreaseRange = _minR;
        maxIncreaseRange = _maxR;
        minIncreaseGlobal = _minG;
        maxIncreaseGlobal = _maxG;
    }

    function setVaults(address _vault, bool _status) external onlyOwner {
        if (_status){
            grantAddressSet(VALID_VAULTS, _vault);
            tradingKey[_vault][ActivityRebateType.POSITION_SIZE] = keccak256(abi.encodePacked("POSITION_SIZE", _vault));
            tradingKey[_vault][ActivityRebateType.POSITION_TIME] = keccak256(abi.encodePacked("POSITION_TIME", _vault));
        }
        else
            revokeAddressSet(VALID_VAULTS, _vault);
    }


    function setReward(address[] memory _rewardToken, uint256[] memory _rewardAmount) external onlyOwner {
        // require(_rewardAmount >= rewardAmount, "invalid reward amount");
        rewardToken = _rewardToken;
        rewardAmount = _rewardAmount;
        maxRound = _rewardAmount.length;
    }


    function _updateCompleteness(uint256 _currentC) internal returns (uint256) {
        if (_currentC >= PRECISION_COMPLE){
            return PRECISION_COMPLE;
        }
        if (_currentC < initialIncrease) _currentC = initialIncrease;

        uint256 _increaseR = minIncreaseRange + randomSource.seedMod(maxIncreaseRange.sub(minIncreaseRange));
        uint256 _increaseG = (PRECISION_COMPLE.sub(_currentC)).mul(_increaseR).div(PRECISION_COMPLE);
        _increaseG = _currentC.add(_increaseG > minIncreaseGlobal ? _increaseG : minIncreaseGlobal);
        _increaseG = _increaseG > PRECISION_COMPLE? PRECISION_COMPLE : _increaseG;
        // emit runRand(_increaseG);        
        return _increaseG;
    }

    function setESBT(address _eSBT) external onlyOwner {
        eSBT = IESBT(_eSBT);
    }

    function setCompleteThreshold(uint256 _completeThreshold) external onlyOwner {
        require(_completeThreshold >= MIN_THRESHOD, "invalid threshold");
        completeThreshold = _completeThreshold;
    }

    function updateCompleteness(address _account) public returns (bool){
        if (block.timestamp > timeStop || block.timestamp < timeStart || timeStart == 0) return false;
        for (uint256 i = completness[_account].length; i < maxRound; i++){
            completness[_account].push(initialIncrease);
        }

        (uint256 valid_count,  ,  ,  ,  ) = getReferalState(_account);

        if (valid_count > completHolders[_account]){
            for (uint256 k = 0; k < valid_count.sub(completHolders[_account]); k++){
                
                uint256 updRound = maxRound;
                for (uint rd = 0; rd < maxRound; rd++){
                    if (completness[_account][rd] < PRECISION_COMPLE){
                        updRound = rd;
                        break;
                    }
                }
                if (updRound >= maxRound) break;

                completness[_account][updRound] = _updateCompleteness(completness[_account][updRound]);
                completHolders[_account] = completHolders[_account].add(1);
                if (completness[_account][updRound] >= PRECISION_COMPLE){
                    break;
                }
            }      
        }

        return true;//completness[_account];
    }

    function claim(uint256 _round) public nonReentrant {
        require(_round < maxRound, "Round not exist");
        address _account = msg.sender;
        updateCompleteness(_account);
        require(completness[_account][_round] >= PRECISION_COMPLE, "Not Complete");
        uint256 claimAmount = rewardAmount[_round].sub(claimedAmount[_account][_round]);
        claimedAmount[_account][_round] = rewardAmount[_round];
        IERC20(rewardToken[_round]).safeTransfer(msg.sender, claimAmount);
    }

    function getCompleteness(address _account) public view returns (uint256[] memory){
        return completness[_account];
    }

    function getReferalState(address _account) public view returns (uint256, uint256[] memory, address[] memory , uint256[] memory, bool[] memory) {
        address[] memory child;
        (, child)= eSBT.getReferralForAccount(_account);
        uint256[] memory value =  new uint256[](child.length);
        bool[] memory avalB =  new bool[](child.length);
        // address[] memory _vaults = getAddressSetRoles(VALID_VAULTS, 0, getAddressSetCount(VALID_VAULTS));
        uint256 valid_count = 0;
        // if (block.timestamp > timeStop || timeStart < 1) return (valid_count, completness[_account], child, value, avalB);

        for (uint256 i = 0; i < child.length; i++){
            value[i] = eSBT.userSizeSum(child[i]);
            uint256 _cTime = eSBT.createTime(child[i]);
            if (_cTime > timeStart && _cTime <= timeStop && value[i] >= completeThreshold){
                valid_count = valid_count.add(1);
                avalB[i] = true;
            }
        }
        return (valid_count, completness[_account], child, value, avalB);
    }
}
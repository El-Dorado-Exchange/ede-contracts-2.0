// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./interfaces/IDataFeed.sol";


interface IChainlinkUtil {
    function latestRoundData() external view returns ( uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
    function latestRound() external view returns (uint256);
    function getRoundData(uint80 _roundId) external view returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}



contract DataFeed is Ownable, IDataFeed {
    using SafeMath for uint256;
    using SafeMath for int256;

    string public description = "DataFeed";

    uint256 public decimals;

    mapping(uint256 => mapping (uint256 => int256) ) public allData;
    mapping(uint256 => mapping (uint256 => uint256)) public dataUpdateTime;
    mapping(uint256 => uint256) public dataInterval;
    mapping(uint256 => string) public dataDecription;
    mapping(string => uint256) public decriptionToIndex;

    mapping (address => bool) public isAdmin;

    mapping(uint256 => address) public chainLinkIdx;
    mapping(address => uint256) public tokenIdx;
    mapping(uint256 => uint256) public phaseId;



    constructor() {
        isAdmin[msg.sender] = true;
    }

    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "Invalid Updater");
        _;
    }

    function setPartner(address _account, bool _isAdmin) public onlyOwner {
        isAdmin[_account] = _isAdmin;
    }


    function setChainlink(address _token, address _chainlink, uint256 _index) public onlyOwner{
        require(_index >= 1000, "idx exceed");
        tokenIdx[_token] = _index;
        chainLinkIdx[_index] =  _chainlink;
        uint256 _curRound = IChainlinkUtil(_chainlink).latestRound();
        uint256 _thisPhaseId = _curRound >> 64;
        phaseId[_index] = _thisPhaseId << 64;
    }

    function setDataSource(uint256 _idx, uint256 _interval, string memory _des) public onlyOwner{
        require(_idx != 0 && dataInterval[_idx]  == 0, "existed ID");
        dataDecription[_idx] = _des;
        dataInterval[_idx] = _interval;
    }


    function setLatestRoundData(uint256[] memory _dataIdx, int256[] memory _answers) public onlyAdmin {
        uint256 cur_time = block.timestamp;
        require(_answers.length == _dataIdx.length, "data length not match");
        for(uint i = 0; i < _answers.length; i++) {
            require(dataInterval[_dataIdx[i]] > 0, "invalid id");
            uint256 idt = cur_time / dataInterval[_dataIdx[i]];
            // if (dataUpdateTime[_dataIdx[i]][idt] > 0)  continue;
            dataUpdateTime[_dataIdx[i]][idt] = cur_time;
            allData[_dataIdx[i]][idt] = _answers[i];
        }
    }

    function setRoundData(uint256[] memory _dataIdx, int256[] memory _answers, uint256[] memory _timeStamp) public onlyAdmin {
        uint256 cur_time = block.timestamp;
        require(_answers.length == _dataIdx.length, "setRoundData: data length not match");
        for(uint i = 0; i < _answers.length; i++){
            require(dataInterval[_dataIdx[i]] > 0, "setRoundData :invalid id");
            uint256 idt = _timeStamp[i] / dataInterval[_dataIdx[i]];
            dataUpdateTime[_dataIdx[i]][idt] = cur_time;
            allData[_dataIdx[i]][idt] = _answers[i];
        }
    }

    function setRoundDataList(uint256 _dataIdx, int256[] memory _answers, uint256[] memory _timeStamp) public onlyAdmin {
        require(_answers.length == _timeStamp.length, "setRoundDataList :invalid data");
        require(dataInterval[_dataIdx] > 0, "setRoundDataList : invalid id");
        for(uint i = 0; i < _answers.length; i++) {
            uint256 idt = _timeStamp[i] / dataInterval[_dataIdx];
            dataUpdateTime[_dataIdx][idt] = _timeStamp[i];
            allData[_dataIdx][idt] = _answers[i];
        }
    }

    function getRoundDataList(uint256 _dataIdx, uint256[] memory _dataSequence) public view returns (int256[] memory, uint256[] memory) {
        require(dataInterval[_dataIdx] > 0, "invalid data");
        int256[] memory rtnData = new int256[](_dataSequence.length);
        uint256[] memory rtnTime = new uint256[](_dataSequence.length);
        uint256 cur_id = block.timestamp / dataInterval[_dataIdx];

        for(uint i = 0; i < _dataSequence.length; i++){
            rtnData[i] = allData[_dataIdx][cur_id.sub(_dataSequence[i])];
            rtnTime[i] = dataUpdateTime[_dataIdx][cur_id.sub(_dataSequence[i])];
        }
        return (rtnData, rtnTime);
    }

    function getRoundData(uint256 _dataIdx, uint256 _dataPara) public override view returns (int256, uint256) {
        if (_dataIdx == 0) return (int256(_dataPara), 0);
        if (_dataIdx >= 1000){
            require(chainLinkIdx[_dataIdx]!= address(0), "chainlink not defined");
            return getChainlinkData(_dataIdx, _dataPara);
        }
        else{
            // require(dataInterval[_dataIdx] > 0, "getRoundData : invalid data");
            uint256 cur_id = block.timestamp / dataInterval[_dataIdx];    
            return (allData[_dataIdx][cur_id.sub(_dataPara)], dataUpdateTime[_dataIdx][cur_id.sub(_dataPara)]);
        }
        // return (int256(_dataPara), 0);
    }


    function getChainlinkData(uint256 _id, uint256 _roundDelta) public override view returns (int256, uint256){
        require(chainLinkIdx[_id]!= address(0), "chainlink not defined");
        IChainlinkUtil cUtil = IChainlinkUtil(chainLinkIdx[_id]);
        if (_roundDelta == 0){
            (, int256 answer, , uint256 updatedAt, ) = IChainlinkUtil(chainLinkIdx[_id]).latestRoundData();
            return (answer, updatedAt);
        }else{
            uint256 _curRound = cUtil.latestRound();
            uint256 _roundId = _curRound & 0xFFFFFFFFFFFFFFFF;
            require(_roundId >= _roundDelta, "round exceed");
            uint256 _parId = phaseId[_id] | _roundId.sub(_roundDelta);
            (, int256 answer, , uint256 updatedAt, ) = IChainlinkUtil(chainLinkIdx[_id]).getRoundData(uint80(_parId));
            return (answer, updatedAt);
        }
    }


}

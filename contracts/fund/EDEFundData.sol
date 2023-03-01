// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../utils/EnumerableValues.sol";

library EFData {
    bytes32 public constant opeProtectIdx = keccak256("opeProtectIdx");
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableValues for EnumerableSet.UintSet;

    uint256 public constant PERCENT_PRECISSION = 10000;
    uint256 public constant MIN_LEVERAGE = 10000;
    uint256 public constant PRICE_PRECISION = 10 ** 30;
    uint256 public constant SHARE_PRECISION = 10 ** 18;
    uint256 public constant SHARE_TO_PRICE_PRECISION = 10 ** 12;
    uint256 public constant MAX_PRICE = 10 ** 38;

    struct UserRecord {
        uint256 entryShareSupply;
        uint256 holdingShare;
        uint256 entryAverageSharePrice;
    }

    struct SellApplication {
        address token;
        uint256 userTokenOut;
        uint256 managerTokenOut;
        uint256 sellShareAmount;
        uint256 createTime; 
        uint256 approveTime;
    }
    struct ProtoCondition {
        ///data_i = dataSourceIDs > 0 ? infoCenter.getdata(id, data_setting) : data_setting(treat as constant value)
        ///sum( data_i * dataCoef_i ) trigType 0
        uint16 trigType;
        int256[] dataCoef;   
        uint16[] dataSourceIDs;
        int256[] dataSetting;
        string instruction;
    }

    struct TrigOperation {
        uint256[] conditionIds;
        address tradeToken;
        address colToken;
        uint256 opeSizeUSD;
        uint256 opeDef; //1:Buy Call, 2:Sell Call, 3:Buy Put, 4:Sell Put
        uint256 opeLeverage;
        string opeInstruction;
    }

    struct OperationRec {
        uint256[] opeProtectIdx;
        uint256[] opeProtectInterval;
        uint256 latestOperationTime;
    }

}
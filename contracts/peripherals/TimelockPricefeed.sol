// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IVaultPriceFeedV3 {
    function setPriceSampleSpace(uint256 _priceSampleSpace) external;
    function setSpreadThresholdBasisPoints(uint256 _spreadThresholdBasisPoints) external;

    function setAdjustment(address _token, bool _isAdditive, uint256 _adjustmentBps) external;
    function setSpreadBasisPoints(address _token, uint256 _spreadBasisPoints) external;
    function setTokenChainlinkConfig(address _token, address _chainlinkContract, bool _isStrictStable)external;
    function setBitTokens(address[] memory _tokens,  uint256[] memory _tokenPrecisions) external;
    function transferOwnership(address _gov) external;

    function setUpdater(address _account, bool _isActive) external;
}


contract TimelockPricefeed is Ownable {
    using SafeMath for uint256;

    uint256 public constant MAX_BUFFER = 5 days;
    uint256 public buffer = 24 hours;

    mapping (bytes32 => uint256) public pendingActions;

    event SignalSetAdjustment(address _target, address _token, bool _isAdditive, uint256 _adjustmentBps);
    event SetAdjustment(address _target, address _token, bool _isAdditive, uint256 _adjustmentBps);
    event SetSpreadBasisPoints(address _target,address _token, uint256 _spreadBasisPoints);
 
    event SignalSetSpreadThresholdBasisPoints(address _target, uint256 _spreadThresholdBasisPoints);
    event SetSpreadThresholdBasisPoints(address _target, uint256 _spreadThresholdBasisPoints);
    
    event SignalSetTokenChainlinkConfig(address _target, address _token, address _chainlinkContract, bool _isStrictStable);
    event SetTokenChainlinkConfig(address _target, address _token, address _chainlinkContract, bool _isStrictStable);
    
    event SignalSetBitTokens(address _target, address[] _tokens,  uint256[] _tokenPrecisions);
    event SetBitTokens(address _target, address[] _tokens,  uint256[] _tokenPrecisions);
    
    event ClearAction(bytes32 action);
    event SignalPendingAction(bytes32 action);

    event TransferOwnership(address _target,address _govn);
    event SignalTransferOwnership(address _target,address _gov);

    event SetUpdater(address _target, address _updater, bool _status);

    function setBuffer(uint256 _buffer) external onlyOwner {
        require(_buffer <= MAX_BUFFER, "Timelock: invalid _buffer");
        require(_buffer > buffer, "Timelock: buffer cannot be decreased");
        buffer = _buffer;
    }

    function setPriceSampleSpace(address _target, uint256 _priceSampleSpace) external onlyOwner {
        IVaultPriceFeedV3(_target).setPriceSampleSpace(_priceSampleSpace);
    }

    function setAdjustment(address _target, address _token, uint256 _spreadBasisPoints) external onlyOwner {
        IVaultPriceFeedV3(_target).setSpreadBasisPoints(_token, _spreadBasisPoints);
        emit SetSpreadBasisPoints(_target, _token, _spreadBasisPoints);
    }

    function setUpdater(address _target, address _updater, bool _status) external onlyOwner {
        IVaultPriceFeedV3(_target).setUpdater(_updater, _status);
        emit SetUpdater(_target, _updater, _status);
    }

    //----------------------------- Timelock functions
    function signalSetAdjustment(address _target, address _token, bool _isAdditive, uint256 _adjustmentBps) external onlyOwner {
        bytes32 action = keccak256(abi.encodePacked("setAdjustment",_target, _token, _isAdditive, _adjustmentBps));
        _setPendingAction(action);
        emit SignalSetAdjustment(_target, _token, _isAdditive, _adjustmentBps);
    }
    function setAdjustment(address _target, address _token, bool _isAdditive, uint256 _adjustmentBps) external onlyOwner {
        bytes32 action = keccak256(abi.encodePacked("setAdjustment",_target, _token, _isAdditive, _adjustmentBps));
        _validateAction(action);
        _clearAction(action);
        IVaultPriceFeedV3(_target).setAdjustment(_token, _isAdditive, _adjustmentBps);
        emit SetAdjustment(_target, _token, _isAdditive, _adjustmentBps);
    }

    function signalSetSpreadThresholdBasisPoints(address _target,uint256 _spreadThresholdBasisPoints) external onlyOwner {
        bytes32 action = keccak256(abi.encodePacked("setSpreadThresholdBasisPoints",_target, _spreadThresholdBasisPoints));
        _setPendingAction(action);
        emit SignalSetSpreadThresholdBasisPoints(_target, _spreadThresholdBasisPoints);
    }
    function setSpreadThresholdBasisPoints(address _target, uint256 _spreadThresholdBasisPoints) external onlyOwner {
        bytes32 action = keccak256(abi.encodePacked("setSpreadThresholdBasisPoints",_target, _spreadThresholdBasisPoints));
        _validateAction(action);
        _clearAction(action);
        IVaultPriceFeedV3(_target).setSpreadThresholdBasisPoints(_spreadThresholdBasisPoints);
        emit SetSpreadThresholdBasisPoints(_target, _spreadThresholdBasisPoints);
    }


    function signalSetTokenChainlinkConfig(address _target, address _token, address _chainlinkContract, bool _isStrictStable) external onlyOwner {
        bytes32 action = keccak256(abi.encodePacked("setTokenChainlinkConfig",_target, _token, _chainlinkContract, _isStrictStable));
        _setPendingAction(action);
        emit SignalSetTokenChainlinkConfig(_target, _token, _chainlinkContract, _isStrictStable);
    }
    function setTokenChainlinkConfig(address _target, address _token, address _chainlinkContract, bool _isStrictStable) external onlyOwner {
        bytes32 action = keccak256(abi.encodePacked("setTokenChainlinkConfig",_target, _token, _chainlinkContract, _isStrictStable));
        _validateAction(action);
        _clearAction(action);
        IVaultPriceFeedV3(_target).setTokenChainlinkConfig(_token, _chainlinkContract, _isStrictStable);
        emit SetTokenChainlinkConfig(_target, _token, _chainlinkContract, _isStrictStable);
    }

    function signalSetBitTokens(address _target, address[] memory _tokens,  uint256[] memory _tokenPrecisions) external onlyOwner {
        bytes32 action = keccak256(abi.encodePacked("signalSetBitTokens",_target, _tokens, _tokenPrecisions));
        _setPendingAction(action);
        emit SignalSetBitTokens(_target, _tokens, _tokenPrecisions);
    }
    function setBitTokens(address _target, address[] memory _tokens,  uint256[] memory _tokenPrecisions) external onlyOwner {
        bytes32 action = keccak256(abi.encodePacked("signalSetBitTokens",_target, _tokens, _tokenPrecisions));
        _validateAction(action);
        _clearAction(action);
        IVaultPriceFeedV3(_target).setBitTokens(_tokens, _tokenPrecisions);
        emit SetBitTokens(_target, _tokens, _tokenPrecisions);
    }


    function signalTransferTargetOwnership(address _target, address _new_owner) external onlyOwner {
        bytes32 action = keccak256(abi.encodePacked("transferOwnership",_target, _new_owner));
        _setPendingAction(action);
        emit SignalTransferOwnership(_target, _new_owner);
    }
    function transferTargetOwnership(address _target, address _new_owner) external onlyOwner {
        bytes32 action = keccak256(abi.encodePacked("transferOwnership",_target, _new_owner));
        _validateAction(action);
        _clearAction(action);
        IVaultPriceFeedV3(_target).transferOwnership(_new_owner);
        emit TransferOwnership(_target, _new_owner);
    }





    //---------------------- signal functoins
    function cancelAction(bytes32 _action) external onlyOwner {
        _clearAction(_action);
    }

    function _setPendingAction(bytes32 _action) private {
        require(pendingActions[_action] == 0, "Timelock: action already signalled");
        pendingActions[_action] = block.timestamp.add(buffer);
        emit SignalPendingAction(_action);
    }

    function _validateAction(bytes32 _action) private view {
        require(pendingActions[_action] != 0, "Timelock: action not signalled");
        require(pendingActions[_action] < block.timestamp, "Timelock: action time not yet passed");
    }

    function _clearAction(bytes32 _action) private {
        require(pendingActions[_action] != 0, "Timelock: invalid _action");
        delete pendingActions[_action];
        emit ClearAction(_action);
    }
}
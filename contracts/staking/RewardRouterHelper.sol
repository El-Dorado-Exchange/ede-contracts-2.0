// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IRewardTracker.sol";
import "../core/interfaces/IVaultPriceFeedV2.sol";
import "../core/interfaces/IVault.sol";
import "../tokens/interfaces/IELP.sol";

interface IRewardRouter {
    function stakedELPnTracker(address _token) external returns (address);
    function latestOperationTime(address _account) external returns (uint256);
    function cooldownDuration() external returns (uint256);
    function claimAllForAccount(address _account) external returns ( uint256[] memory);    
}


contract RewardRouterHelper is ReentrancyGuard, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address payable;

    event UserUnstakeElp(address account, uint256 amount);

    address public rewardRouter;
    mapping(address => bool) public allWhitelistedELPn;

    function setELP(address _elpn, bool _status) public onlyOwner{
        allWhitelistedELPn[_elpn] = _status;
    }
    function setRewardRouter(address _rewardRouter) public onlyOwner{
        rewardRouter = _rewardRouter;
    }

    function claimAndUnstakeELPn(address _elp_n, uint256 _tokenInAmount) public nonReentrant returns (uint256) {
        address account = msg.sender;
        require(allWhitelistedELPn[_elp_n], "invalid elp");
        IRewardRouter rRouter = IRewardRouter(rewardRouter);
        require(block.timestamp.sub(rRouter.latestOperationTime(account)) > rRouter.cooldownDuration(), "Cooldown Time Required.");
        rRouter.claimAllForAccount(account);

        IRewardTracker(rRouter.stakedELPnTracker(_elp_n)).unstakeForAccount(account, _elp_n, _tokenInAmount, account);

        emit UserUnstakeElp(account, _tokenInAmount);
        return _tokenInAmount;
    }

}

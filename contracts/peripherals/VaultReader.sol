// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../core/interfaces/IVault.sol";
import "../core/interfaces/IVaultUtils.sol";
import "../core/interfaces/IVaultPriceFeedV2.sol";
import "../core/interfaces/IBasePositionManager.sol";
import "../core/VaultMSData.sol";
import "hardhat/console.sol";

interface IVaultTarget {
    function vaultUtils() external view returns (address);
}
contract VaultReader {
    using SafeMath for uint256;

    function getVaultTokenInfoV4(address _vault, address _positionManager, address _weth, uint256 _usdxAmount, address[] memory _tokens) public view returns (uint256[] memory) {
        uint256 propsLength = 15;

        IVault vault = IVault(_vault);
        // console.log(address(vault));
        IVaultUtils vaultUtils = IVaultUtils(IVaultTarget(_vault).vaultUtils());
        // console.log(address(vaultUtils));
        IVaultPriceFeedV2 priceFeed = IVaultPriceFeedV2(vault.priceFeed());
        IBasePositionManager positionManager = IBasePositionManager(_positionManager);

        console.log(address(vaultUtils));

        uint256[] memory amounts = new uint256[](_tokens.length * propsLength);
        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            if (token == address(0)) {
                token = _weth;
            }
            VaultMSData.TokenBase memory tBase = vault.getTokenBase(token);
            console.log(1);

            amounts[i * propsLength] = tBase.poolAmount;
            amounts[i * propsLength + 1] = tBase.reservedAmount;
            amounts[i * propsLength + 2] = vault.usdxAmounts(token);
            amounts[i * propsLength + 3] = vault.getRedemptionAmount(token, _usdxAmount);
            amounts[i * propsLength + 4] = tBase.weight;
            amounts[i * propsLength + 5] = tBase.bufferAmount;
            amounts[i * propsLength + 6] = tBase.maxUSDAmounts;
            amounts[i * propsLength + 7] = vaultUtils.maxGlobalShortSizes(token);
            // console.log(31);
            amounts[i * propsLength + 8] = positionManager.maxGlobalShortSizes(token);
            amounts[i * propsLength + 9] = positionManager.maxGlobalLongSizes(token);
            // console.log(41);
            amounts[i * propsLength + 10] = vault.getMinPrice(token);
            amounts[i * propsLength + 11] = vault.getMaxPrice(token);
            amounts[i * propsLength + 12] = vaultUtils.maxGlobalLongSizes(token);
            // (amounts[i * propsLength + 13], ) = priceFeed.getPrimaryPrice(token, false);
            // (amounts[i * propsLength + 14], ) = priceFeed.getPrimaryPrice(token, true);
            amounts[i * propsLength + 13] = priceFeed.getPrice(token, false, true, false);
            amounts[i * propsLength + 14] = priceFeed.getPrice(token, true, true, false);
        }

        return amounts;
    }
    
    
    function getPoolTokenInfo(address _vault, address _token) public view returns (uint256[] memory) {
        IVault vault = IVault(_vault);
        require(vault.isFundingToken(_token), "invalid token");
        uint256[] memory tokenIinfo = new uint256[](7);        
        // tokenIinfo[0] = vault.totalTokenWeights() > 0 ? vault.tokenWeights(_token).mul(1000000).div(vault.totalTokenWeights()) : 0;
        // tokenIinfo[1] = vault.tokenUtilization(_token); 
        // tokenIinfo[2] = IERC20(_token).balanceOf(_vault).add(vault.feeSold(_token)).sub(vault.feeReserves(_token));
        // tokenIinfo[3] = vault.getMaxPrice(_token);
        // tokenIinfo[4] = vault.getMinPrice(_token);
        // tokenIinfo[5] = vault.cumulativeFundingRates(_token);
        // tokenIinfo[6] = vault.poolAmounts(_token);
        return tokenIinfo;
    }




}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../core/interfaces/IVault.sol";
import "../core/interfaces/IVaultUtils.sol";
import "../core/interfaces/IVaultPriceFeedV2.sol";
import "../core/VaultMSData.sol";
import "../tokens/interfaces/IYieldTracker.sol";
import "../tokens/interfaces/IYieldToken.sol";

// import "../staking/interfaces/IVester.sol";

interface IVaultTarget {
    function vaultUtils() external view returns (address);
}
contract Reader is Ownable {
    using SafeMath for uint256;

    uint256 public constant BASIS_POINTS_DIVISOR = 10000;
    uint256 public constant POSITION_PROPS_LENGTH = 9;
    uint256 public constant PRICE_PRECISION = 10 ** 30;
    uint256 public constant USDX_DECIMALS = 18;

    bool public hasMaxGlobalShortSizes;

    function setConfig(bool _hasMaxGlobalShortSizes) public onlyOwner {
        hasMaxGlobalShortSizes = _hasMaxGlobalShortSizes;
    }

    function getMaxAmountIn(IVault _vault, address _tokenIn, address _tokenOut) public view returns (uint256) {
        uint256 priceIn = _vault.getMinPrice(_tokenIn);
        uint256 priceOut = _vault.getMaxPrice(_tokenOut);

        uint256 tokenInDecimals = _vault.tokenDecimals(_tokenIn);
        uint256 tokenOutDecimals = _vault.tokenDecimals(_tokenOut);

        uint256 amountIn;

        {
            uint256 poolAmount = 0;//_vault.poolAmounts(_tokenOut);
            uint256 reservedAmount = 0;// _vault.reservedAmounts(_tokenOut);
            uint256 bufferAmount = 0;//_vault.bufferAmounts(_tokenOut);
            uint256 subAmount = reservedAmount > bufferAmount ? reservedAmount : bufferAmount;
            if (subAmount >= poolAmount) {
                return 0;
            }
            uint256 availableAmount = poolAmount.sub(subAmount);
            amountIn = availableAmount.mul(priceOut).div(priceIn).mul(10 ** tokenInDecimals).div(10 ** tokenOutDecimals);
        }

        uint256 maxUsdxAmount = 0;//_vault.maxUSDAmounts(_tokenIn);

        if (maxUsdxAmount != 0) {
            if (maxUsdxAmount < _vault.usdxAmounts(_tokenIn)) {
                return 0;
            }

            uint256 maxAmountIn = maxUsdxAmount.sub(_vault.usdxAmounts(_tokenIn));
            maxAmountIn = maxAmountIn.mul(10 ** tokenInDecimals).div(10 ** USDX_DECIMALS);
            maxAmountIn = maxAmountIn.mul(PRICE_PRECISION).div(priceIn);

            if (amountIn > maxAmountIn) {
                return maxAmountIn;
            }
        }

        return amountIn;
    }

    // function getAmountOut(IVault _vault, address _tokenIn, address _tokenOut, uint256 _amountIn) public view returns (uint256, uint256) {
    //     uint256 priceIn = _vault.getMinPrice(_tokenIn);
    //     IVaultUtils _vaultUtils = IVaultUtils(_vault.vaultUtilsAddress());
    //     uint256 tokenInDecimals = _vault.tokenDecimals(_tokenIn);
    //     uint256 tokenOutDecimals = _vault.tokenDecimals(_tokenOut);

    //     uint256 feeBasisPoints;
    //     {
    //         uint256 usdxAmount = _amountIn.mul(priceIn).div(PRICE_PRECISION);
    //         usdxAmount = usdxAmount.mul(10 ** USDX_DECIMALS).div(10 ** tokenInDecimals);

    //         bool isStableSwap = _vault.stableTokens(_tokenIn) && _vault.stableTokens(_tokenOut);
    //         uint256 baseBps = isStableSwap ? _vaultUtils.stableSwapFeeBasisPoints() : _vaultUtils.swapFeeBasisPoints();
    //         uint256 taxBps = isStableSwap ? _vaultUtils.stableTaxBasisPoints() : _vaultUtils.taxBasisPoints();
    //         uint256 feesBasisPoints0 = _vault.getFeeBasisPoints(_tokenIn, usdxAmount, baseBps, taxBps, true);
    //         uint256 feesBasisPoints1 = _vault.getFeeBasisPoints(_tokenOut, usdxAmount, baseBps, taxBps, false);
    //         // use the higher of the two fee basis points
    //         feeBasisPoints = feesBasisPoints0 > feesBasisPoints1 ? feesBasisPoints0 : feesBasisPoints1;
    //     }

    //     uint256 priceOut = _vault.getMaxPrice(_tokenOut);
    //     uint256 amountOut = _amountIn.mul(priceIn).div(priceOut);
    //     amountOut = amountOut.mul(10 ** tokenOutDecimals).div(10 ** tokenInDecimals);

    //     uint256 amountOutAfterFees = amountOut.mul(BASIS_POINTS_DIVISOR.sub(feeBasisPoints)).div(BASIS_POINTS_DIVISOR);
    //     uint256 feeAmount = amountOut.sub(amountOutAfterFees);

    //     return (amountOutAfterFees, feeAmount);
    // }

    function getFeeBasisPoints(IVault _vault, address _tokenIn, address _tokenOut, uint256 _amountIn) public view returns (uint256, uint256, uint256) {
        uint256 priceIn = _vault.getMinPrice(_tokenIn);
        uint256 tokenInDecimals = _vault.tokenDecimals(_tokenIn);
        IVaultUtils _vaultUtils = IVaultUtils(IVaultTarget(address(_vault)).vaultUtils());

        uint256 usdxAmount = _amountIn.mul(priceIn).div(PRICE_PRECISION);
        usdxAmount = usdxAmount.mul(10 ** USDX_DECIMALS).div(10 ** tokenInDecimals);
       
        uint256 baseBps = 0;
        uint256 taxBps = 0;
        {
            VaultMSData.TokenBase memory _tbIn = _vault.getTokenBase(_tokenIn);
            VaultMSData.TokenBase memory _tbOut = _vault.getTokenBase(_tokenOut);

            bool isStableSwap = _tbIn.isStable && _tbOut.isStable;
            baseBps = isStableSwap ? _vaultUtils.stableSwapFeeBasisPoints() : _vaultUtils.swapFeeBasisPoints();
            taxBps = isStableSwap ? _vaultUtils.stableTaxBasisPoints() : _vaultUtils.taxBasisPoints();
        }

        uint256 feesBasisPoints0 = _vaultUtils.getFeeBasisPoints(_tokenIn, usdxAmount, baseBps, taxBps, true);
        uint256 feesBasisPoints1 = _vaultUtils.getFeeBasisPoints(_tokenOut, usdxAmount, baseBps, taxBps, false);
        // use the higher of the two fee basis points
        uint256 feeBasisPoints = feesBasisPoints0 > feesBasisPoints1 ? feesBasisPoints0 : feesBasisPoints1;

        return (feeBasisPoints, feesBasisPoints0, feesBasisPoints1);
    }

    function getFees(address _vault, address[] memory _tokens) public view returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            amounts[i] = IVault(_vault).feeReserves(_tokens[i]);
        }
        return amounts;
    }

    function getTotalStaked(address[] memory _yieldTokens) public view returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](_yieldTokens.length);
        for (uint256 i = 0; i < _yieldTokens.length; i++) {
            IYieldToken yieldToken = IYieldToken(_yieldTokens[i]);
            amounts[i] = yieldToken.totalStaked();
        }
        return amounts;
    }

    function getStakingInfo(address _account, address[] memory _yieldTrackers) public view returns (uint256[] memory) {
        uint256 propsLength = 2;
        uint256[] memory amounts = new uint256[](_yieldTrackers.length * propsLength);
        for (uint256 i = 0; i < _yieldTrackers.length; i++) {
            IYieldTracker yieldTracker = IYieldTracker(_yieldTrackers[i]);
            amounts[i * propsLength] = yieldTracker.claimable(_account);
            amounts[i * propsLength + 1] = yieldTracker.getTokensPerInterval();
        }
        return amounts;
    }


    function getPairInfo(address /*_factory*/, address[] memory _tokens) public pure returns (uint256[] memory) {
        uint256 inputLength = 2;
        uint256 propsLength = 2;
        uint256[] memory amounts = new uint256[](_tokens.length / inputLength * propsLength);

        return amounts;
    }

    function getFundingRates(address _vault, address _weth, address[] memory _tokens) public view returns (uint256[] memory) {
        uint256 propsLength = 2;
        uint256[] memory fundingRates = new uint256[](_tokens.length * propsLength);
        // IVault vault = IVault(_vault);

        // for (uint256 i = 0; i < _tokens.length; i++) {
        //     address token = _tokens[i];
        //     if (token == address(0)) {
        //         token = _weth;
        //     }

        //     uint256 fundingRateFactor = vault.stableTokens(token) ? vault.stableFundingRateFactor() : vault.fundingRateFactor();
        //     uint256 reservedAmount = vault.reservedAmounts(token);
        //     uint256 poolAmount = vault.poolAmounts(token);

        //     if (poolAmount > 0) {
        //         fundingRates[i * propsLength] = fundingRateFactor.mul(reservedAmount).div(poolAmount);
        //     }

        //     if (vault.cumulativeFundingRates(token) > 0) {
        //         uint256 nextRate = vault.getNextFundingRate(token);
        //         uint256 baseRate = vault.cumulativeFundingRates(token);
        //         fundingRates[i * propsLength + 1] = baseRate.add(nextRate);
        //     }
        // }

        return fundingRates;
    }

    function getTokenSupply(IERC20 _token, address[] memory _excludedAccounts) public view returns (uint256) {
        uint256 supply = _token.totalSupply();
        for (uint256 i = 0; i < _excludedAccounts.length; i++) {
            address account = _excludedAccounts[i];
            uint256 balance = _token.balanceOf(account);
            supply = supply.sub(balance);
        }
        return supply;
    }

    function getTotalBalance(IERC20 _token, address[] memory _accounts) public view returns (uint256) {
        uint256 totalBalance = 0;
        for (uint256 i = 0; i < _accounts.length; i++) {
            address account = _accounts[i];
            uint256 balance = _token.balanceOf(account);
            totalBalance = totalBalance.add(balance);
        }
        return totalBalance;
    }

    function getTokenBalances(address _account, address[] memory _tokens) public view returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            if (token == address(0)) {
                balances[i] = _account.balance;
                continue;
            }
            balances[i] = IERC20(token).balanceOf(_account);
        }
        return balances;
    }

    function getTokenBalancesWithSupplies(address _account, address[] memory _tokens) public view returns (uint256[] memory) {
        uint256 propsLength = 2;
        uint256[] memory balances = new uint256[](_tokens.length * propsLength);
        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            if (token == address(0)) {
                balances[i * propsLength] = _account.balance;
                balances[i * propsLength + 1] = 0;
                continue;
            }
            balances[i * propsLength] = IERC20(token).balanceOf(_account);
            balances[i * propsLength + 1] = IERC20(token).totalSupply();
        }
        return balances;
    }

    function getPrices(IVaultPriceFeedV2 _priceFeed, address[] memory _tokens) public view returns (uint256[] memory) {
        uint256 propsLength = 6;
        uint256[] memory amounts = new uint256[](_tokens.length * propsLength);

        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            amounts[i * propsLength] = _priceFeed.getPrice(token, true, true, false);
            amounts[i * propsLength + 1] = _priceFeed.getPrice(token, false, true, false);
            // (amounts[i * propsLength + 2], ) = _priceFeed.getPrimaryPrice(token, true);
            // (amounts[i * propsLength + 3], ) = _priceFeed.getPrimaryPrice(token, false);
            amounts[i * propsLength + 2] = amounts[i * propsLength];
            amounts[i * propsLength + 3] = amounts[i * propsLength + 1];
            amounts[i * propsLength + 4] = _priceFeed.isAdjustmentAdditive(token) ? 1 : 0;
            amounts[i * propsLength + 5] = _priceFeed.adjustmentBasisPoints(token);
        }
        return amounts;
    }

    function getVaultTokenInfo(address _vault, address _weth, uint256 _usdxAmount, address[] memory _tokens) public view returns (uint256[] memory) {
        uint256 propsLength = 10;

        IVault vault = IVault(_vault);
        IVaultPriceFeedV2 priceFeed = IVaultPriceFeedV2(vault.priceFeed());

        uint256[] memory amounts = new uint256[](_tokens.length * propsLength);
        // for (uint256 i = 0; i < _tokens.length; i++) {
        //     address token = _tokens[i];
        //     if (token == address(0)) {
        //         token = _weth;
        //     }
        //     amounts[i * propsLength] = vault.poolAmounts(token);
        //     amounts[i * propsLength + 1] = vault.reservedAmounts(token);
        //     amounts[i * propsLength + 2] = vault.usdxAmounts(token);
        //     amounts[i * propsLength + 3] = vault.getRedemptionAmount(token, _usdxAmount);
        //     amounts[i * propsLength + 4] = vault.tokenWeights(token);
        //     amounts[i * propsLength + 5] = vault.getMinPrice(token);
        //     amounts[i * propsLength + 6] = vault.getMaxPrice(token);
        //     amounts[i * propsLength + 7] = vault.guaranteedUsd(token);
        //     // (amounts[i * propsLength + 8], ) = priceFeed.getPrimaryPrice(token, false);
        //     // (amounts[i * propsLength + 9], ) = priceFeed.getPrimaryPrice(token, true);
        //     amounts[i * propsLength + 8] = priceFeed.getPrice(token, true, true, false);
        //     amounts[i * propsLength + 9] = priceFeed.getPrice(token, false, true, false);
        // }

        return amounts;
    }

    function getFullVaultTokenInfo(address _vault, address _weth, uint256 _usdxAmount, address[] memory _tokens) public view returns (uint256[] memory) {
        uint256 propsLength = 12;

        IVault vault = IVault(_vault);
        IVaultPriceFeedV2 priceFeed = IVaultPriceFeedV2(vault.priceFeed());

        uint256[] memory amounts = new uint256[](_tokens.length * propsLength);
        // for (uint256 i = 0; i < _tokens.length; i++) {
        //     address token = _tokens[i];
        //     if (token == address(0)) {
        //         token = _weth;
        //     }
        //     amounts[i * propsLength] = vault.poolAmounts(token);
        //     amounts[i * propsLength + 1] = vault.reservedAmounts(token);
        //     amounts[i * propsLength + 2] = vault.usdxAmounts(token);
        //     amounts[i * propsLength + 3] = vault.getRedemptionAmount(token, _usdxAmount);
        //     amounts[i * propsLength + 4] = vault.tokenWeights(token);
        //     amounts[i * propsLength + 5] = vault.bufferAmounts(token);
        //     amounts[i * propsLength + 6] = vault.maxUSDAmounts(token);
        //     amounts[i * propsLength + 7] = vault.getMinPrice(token);
        //     amounts[i * propsLength + 8] = vault.getMaxPrice(token);
        //     amounts[i * propsLength + 9] = vault.guaranteedUsd(token);
        //     // (amounts[i * propsLength + 10], ) = priceFeed.getPrimaryPrice(token, false);
        //     // (amounts[i * propsLength + 11], ) = priceFeed.getPrimaryPrice(token, true);
        //     amounts[i * propsLength + 10] = priceFeed.getPrice(token, false, true, false);
        //     amounts[i * propsLength + 11] = priceFeed.getPrice(token, true, true, false);
        // }

        return amounts;
    }

    function getVaultTokenInfoV2(address _vault, address _weth, uint256 _usdxAmount, address[] memory _tokens) public view returns (uint256[] memory) {
        uint256 propsLength = 14;

        IVault vault = IVault(_vault);
        IVaultPriceFeedV2 priceFeed = IVaultPriceFeedV2(vault.priceFeed());

        uint256[] memory amounts = new uint256[](_tokens.length * propsLength);
        // for (uint256 i = 0; i < _tokens.length; i++) {
        //     address token = _tokens[i];
        //     if (token == address(0)) {
        //         token = _weth;
        //     }

        //     uint256 maxGlobalShortSize = hasMaxGlobalShortSizes ? vault.maxGlobalShortSizes(token) : 0;
        //     amounts[i * propsLength] = vault.poolAmounts(token);
        //     amounts[i * propsLength + 1] = vault.reservedAmounts(token);
        //     amounts[i * propsLength + 2] = vault.usdxAmounts(token);
        //     amounts[i * propsLength + 3] = vault.getRedemptionAmount(token, _usdxAmount);
        //     amounts[i * propsLength + 4] = vault.tokenWeights(token);
        //     amounts[i * propsLength + 5] = vault.bufferAmounts(token);
        //     amounts[i * propsLength + 6] = vault.maxUSDAmounts(token);
        //     amounts[i * propsLength + 7] = vault.globalShortSizes(token);
        //     amounts[i * propsLength + 8] = maxGlobalShortSize;
        //     amounts[i * propsLength + 9] = vault.getMinPrice(token);
        //     amounts[i * propsLength + 10] = vault.getMaxPrice(token);
        //     amounts[i * propsLength + 11] = vault.guaranteedUsd(token);
        //     // (amounts[i * propsLength + 12], ) = priceFeed.getPrimaryPrice(token, false);
        //     // (amounts[i * propsLength + 13], ) = priceFeed.getPrimaryPrice(token, true);
        //     amounts[i * propsLength + 12] = priceFeed.getPrice(token, false, true, false);
        //     amounts[i * propsLength + 13] = priceFeed.getPrice(token, true, true, false);
        // }

        return amounts;
    }

    function getPositions(address _vault, address _account, address[] memory _collateralTokens, address[] memory _indexTokens, bool[] memory _isLong) public view returns(uint256[] memory) {
        uint256[] memory amounts = new uint256[](_collateralTokens.length * POSITION_PROPS_LENGTH);

        // for (uint256 i = 0; i < _collateralTokens.length; i++) {
        //     {
        //         (uint256 size,
        //         uint256 collateral,
        //         uint256 averagePrice,
        //         uint256 entryFundingRate,
        //         /* reserveAmount */,
        //         uint256 realisedPnl,
        //         bool hasRealisedProfit,
        //         uint256 lastIncreasedTime) = IVault(_vault).getPosition(_account, _collateralTokens[i], _indexTokens[i], _isLong[i]);

        //         amounts[i * POSITION_PROPS_LENGTH] = size;
        //         amounts[i * POSITION_PROPS_LENGTH + 1] = collateral;
        //         amounts[i * POSITION_PROPS_LENGTH + 2] = averagePrice;
        //         amounts[i * POSITION_PROPS_LENGTH + 3] = entryFundingRate;
        //         amounts[i * POSITION_PROPS_LENGTH + 4] = hasRealisedProfit ? 1 : 0;
        //         amounts[i * POSITION_PROPS_LENGTH + 5] = realisedPnl;
        //         amounts[i * POSITION_PROPS_LENGTH + 6] = lastIncreasedTime;
        //     }

        //     uint256 sizeN = amounts[i * POSITION_PROPS_LENGTH];
        //     uint256 averagePriceN = amounts[i * POSITION_PROPS_LENGTH + 2];
        //     uint256 lastIncreasedTimeN = amounts[i * POSITION_PROPS_LENGTH + 6];
        //     if (averagePriceN > 0) {
        //         (bool hasProfit, uint256 delta) = IVault(_vault).getDelta(_indexTokens[i], sizeN, averagePriceN, _isLong[i], lastIncreasedTimeN);
        //         amounts[i * POSITION_PROPS_LENGTH + 7] = hasProfit ? 1 : 0;
        //         amounts[i * POSITION_PROPS_LENGTH + 8] = delta;
        //     }
        // }

        return amounts;
    }
}
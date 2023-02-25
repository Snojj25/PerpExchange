 /// @inheritdoc IOrderBook
    function removeLiquidity(RemoveLiquidityParams calldata params)
        external
        override
        returns (RemoveLiquidityResponse memory)
    {
        _requireOnlyClearingHouse();
        address pool = IMarketRegistry(_marketRegistry).getPool(params.baseToken);
        bytes32 orderId = OpenOrder.calcOrderKey(params.maker, params.baseToken, params.lowerTick, params.upperTick);
        return
            _removeLiquidity(
                InternalRemoveLiquidityParams({
                    maker: params.maker,
                    baseToken: params.baseToken,
                    pool: pool,
                    orderId: orderId,
                    lowerTick: params.lowerTick,
                    upperTick: params.upperTick,
                    liquidity: params.liquidity
                })
            );
    }

///
///
///
///


function _removeLiquidity(InternalRemoveLiquidityParams memory params)
        internal
        returns (RemoveLiquidityResponse memory)
    {
        UniswapV3Broker.RemoveLiquidityResponse memory response =
            UniswapV3Broker.removeLiquidity(
                UniswapV3Broker.RemoveLiquidityParams(
                    params.pool,
                    _clearingHouse,
                    params.lowerTick,
                    params.upperTick,
                    params.liquidity
                )
            );

        // update token info based on existing open order
        (uint256 fee, uint256 baseDebt, uint256 quoteDebt) = _removeLiquidityFromOrder(params);

        int256 takerBase = response.base.toInt256().sub(baseDebt.toInt256());
        int256 takerQuote = response.quote.toInt256().sub(quoteDebt.toInt256());

        // if flipped from initialized to uninitialized, clear the tick info
        if (!UniswapV3Broker.getIsTickInitialized(params.pool, params.lowerTick)) {
            _growthOutsideTickMap[params.baseToken].clear(params.lowerTick);
        }
        if (!UniswapV3Broker.getIsTickInitialized(params.pool, params.upperTick)) {
            _growthOutsideTickMap[params.baseToken].clear(params.upperTick);
        }

        return
            RemoveLiquidityResponse({
                base: response.base,
                quote: response.quote,
                fee: fee,
                takerBase: takerBase,
                takerQuote: takerQuote
            });
    }





    function _removeLiquidityFromOrder(InternalRemoveLiquidityParams memory params)
        internal
        returns (
            uint256 fee,
            uint256 baseDebt,
            uint256 quoteDebt
        )
    {
        // update token info based on existing open order
        OpenOrder.Info storage openOrder = _openOrderMap[params.orderId];

        // as in _addLiquidityToOrder(), fee should be calculated before the states are updated
        uint256 feeGrowthInsideX128;
        (fee, feeGrowthInsideX128) = _getPendingFeeAndFeeGrowthInsideX128ByOrder(params.baseToken, openOrder);

        if (params.liquidity != 0) {
            if (openOrder.baseDebt != 0) {
                baseDebt = FullMath.mulDiv(openOrder.baseDebt, params.liquidity, openOrder.liquidity);
                openOrder.baseDebt = openOrder.baseDebt.sub(baseDebt);
            }
            if (openOrder.quoteDebt != 0) {
                quoteDebt = FullMath.mulDiv(openOrder.quoteDebt, params.liquidity, openOrder.liquidity);
                openOrder.quoteDebt = openOrder.quoteDebt.sub(quoteDebt);
            }
            openOrder.liquidity = openOrder.liquidity.sub(params.liquidity).toUint128();
        }

        // after the fee is calculated, lastFeeGrowthInsideX128 can be updated if liquidity != 0 after removing
        if (openOrder.liquidity == 0) {
            _removeOrder(params.maker, params.baseToken, params.orderId);
        } else {
            openOrder.lastFeeGrowthInsideX128 = feeGrowthInsideX128;
        }

        return (fee, baseDebt, quoteDebt);
    }



        function _removeOrder(
        address maker,
        address baseToken,
        bytes32 orderId
    ) internal {
        bytes32[] storage orderIds = _openOrderIdsMap[maker][baseToken];
        uint256 orderLen = orderIds.length;
        for (uint256 idx = 0; idx < orderLen; idx++) {
            if (orderIds[idx] == orderId) {
                // found the existing order ID
                // remove it from the array efficiently by re-ordering and deleting the last element
                if (idx != orderLen - 1) {
                    orderIds[idx] = orderIds[orderLen - 1];
                }
                orderIds.pop();
                delete _openOrderMap[orderId];
                break;
            }
        }
    }
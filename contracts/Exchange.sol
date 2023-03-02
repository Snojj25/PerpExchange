/// @param params The parameters of the swap
/// @return The result of the swap
/// @dev can only be called from ClearingHouse
/// @inheritdoc IExchange
function swap(SwapParams memory params)
    external
    override
    returns (SwapResponse memory)
{
    _requireOnlyClearingHouse();

    // EX_MIP: market is paused
    require(_maxTickCrossedWithinBlockMap[params.baseToken] > 0, "EX_MIP");

    int256 takerPositionSize = IAccountBalance(_accountBalance)
        .getTakerPositionSize(params.trader, params.baseToken);

    bool isPartialClose;
    if (params.isClose && takerPositionSize != 0) {
        // simulate the tx to see if it's over the price limit; if true, can only partially close the position
        if (
            _isOverPriceLimitBySimulatingClosingPosition(
                params.baseToken,
                takerPositionSize < 0, // it's a short position
                params.amount // it's the same as takerPositionSize but in uint256
            )
        ) {
            uint24 partialCloseRatio = IClearingHouseConfig(
                _clearingHouseConfig
            ).getPartialCloseRatio();
            params.amount = params.amount.mulRatio(partialCloseRatio);
            isPartialClose = true;
        }
    }

    // get openNotional before swap
    int256 oldTakerOpenNotional = IAccountBalance(_accountBalance)
        .getTakerOpenNotional(params.trader, params.baseToken);
    InternalSwapResponse memory response = _swap(params);

    // EX_OPLAS: over price limit after swap
    require(
        !_isOverPriceLimitWithTick(params.baseToken, response.tick),
        "EX_OPLAS"
    );

    // when takerPositionSize < 0, it's a short position
    bool isReducingPosition = takerPositionSize == 0
        ? false
        : takerPositionSize < 0 != params.isBaseToQuote;
    // when reducing/not increasing the position size, it's necessary to realize pnl
    int256 pnlToBeRealized;
    if (isReducingPosition) {
        pnlToBeRealized = _getPnlToBeRealized(
            InternalRealizePnlParams({
                trader: params.trader,
                baseToken: params.baseToken,
                takerPositionSize: takerPositionSize,
                takerOpenNotional: oldTakerOpenNotional,
                base: response.base,
                quote: response.quote
            })
        );
    }

    (uint256 sqrtPriceX96, , , , , , ) = UniswapV3Broker.getSlot0(
        IMarketRegistry(_marketRegistry).getPool(params.baseToken)
    );
    return
        SwapResponse({
            base: response.base.abs(),
            quote: response.quote.abs(),
            exchangedPositionSize: response.exchangedPositionSize,
            exchangedPositionNotional: response.exchangedPositionNotional,
            fee: response.fee,
            insuranceFundFee: response.insuranceFundFee,
            pnlToBeRealized: pnlToBeRealized,
            sqrtPriceAfterX96: sqrtPriceX96,
            tick: response.tick,
            isPartialClose: isPartialClose
        });
}

//
//
//

//
//
//
//

/// @dev customized fee: https://www.notion.so/perp/Customise-fee-tier-on-B2QFee-1b7244e1db63416c8651e8fa04128cdb
function _swap(SwapParams memory params)
    internal
    returns (InternalSwapResponse memory)
{
    IMarketRegistry.MarketInfo memory marketInfo = IMarketRegistry(
        _marketRegistry
    ).getMarketInfo(params.baseToken);

    (
        uint256 scaledAmountForUniswapV3PoolSwap,
        int256 signedScaledAmountForReplaySwap
    ) = SwapMath.calcScaledAmountForSwaps(
            params.isBaseToQuote,
            params.isExactInput,
            params.amount,
            marketInfo.exchangeFeeRatio,
            marketInfo.uniswapFeeRatio
        );

    (
        Funding.Growth memory fundingGrowthGlobal,
        ,

    ) = _getFundingGrowthGlobalAndTwaps(params.baseToken);
    // simulate the swap to calculate the fees charged in exchange
    IOrderBook.ReplaySwapResponse memory replayResponse = IOrderBook(_orderBook)
        .replaySwap(
            IOrderBook.ReplaySwapParams({
                baseToken: params.baseToken,
                isBaseToQuote: params.isBaseToQuote,
                shouldUpdateState: true,
                amount: signedScaledAmountForReplaySwap,
                sqrtPriceLimitX96: params.sqrtPriceLimitX96,
                exchangeFeeRatio: marketInfo.exchangeFeeRatio,
                uniswapFeeRatio: marketInfo.uniswapFeeRatio,
                globalFundingGrowth: fundingGrowthGlobal
            })
        );
    UniswapV3Broker.SwapResponse memory response = UniswapV3Broker.swap(
        UniswapV3Broker.SwapParams(
            marketInfo.pool,
            _clearingHouse,
            params.isBaseToQuote,
            params.isExactInput,
            // mint extra base token before swap
            scaledAmountForUniswapV3PoolSwap,
            params.sqrtPriceLimitX96,
            abi.encode(
                SwapCallbackData({
                    trader: params.trader,
                    baseToken: params.baseToken,
                    pool: marketInfo.pool,
                    fee: replayResponse.fee,
                    uniswapFeeRatio: marketInfo.uniswapFeeRatio
                })
            )
        )
    );

    // as we charge fees in ClearingHouse instead of in Uniswap pools,
    // we need to scale up base or quote amounts to get the exact exchanged position size and notional
    int256 exchangedPositionSize;
    int256 exchangedPositionNotional;
    if (params.isBaseToQuote) {
        // short: exchangedPositionSize <= 0 && exchangedPositionNotional >= 0
        exchangedPositionSize = SwapMath
            .calcAmountScaledByFeeRatio(
                response.base,
                marketInfo.uniswapFeeRatio,
                false
            )
            .neg256();
        // due to base to quote fee, exchangedPositionNotional contains the fee
        // s.t. we can take the fee away from exchangedPositionNotional
        exchangedPositionNotional = response.quote.toInt256();
    } else {
        // long: exchangedPositionSize >= 0 && exchangedPositionNotional <= 0
        exchangedPositionSize = response.base.toInt256();

        // scaledAmountForUniswapV3PoolSwap is the amount of quote token to swap (input),
        // response.quote is the actual amount of quote token swapped (output).
        // as long as liquidity is enough, they would be equal.
        // otherwise, response.quote < scaledAmountForUniswapV3PoolSwap
        // which also means response.quote < exact input amount.
        if (
            params.isExactInput &&
            response.quote == scaledAmountForUniswapV3PoolSwap
        ) {
            // NOTE: replayResponse.fee might have an extra charge of 1 wei, for instance:
            // Q2B exact input amount 1000000000000000000000 with fee ratio 1%,
            // replayResponse.fee is actually 10000000000000000001 (1000 * 1% + 1 wei),
            // and quote = exchangedPositionNotional - replayResponse.fee = -1000000000000000000001
            // which is not matched with exact input 1000000000000000000000
            // we modify exchangedPositionNotional here to make sure
            // quote = exchangedPositionNotional - replayResponse.fee = exact input
            exchangedPositionNotional = params
                .amount
                .sub(replayResponse.fee)
                .toInt256()
                .neg256();
        } else {
            exchangedPositionNotional = SwapMath
                .calcAmountScaledByFeeRatio(
                    response.quote,
                    marketInfo.uniswapFeeRatio,
                    false
                )
                .neg256();
        }
    }

    // update the timestamp of the first tx in this market
    if (_firstTradedTimestampMap[params.baseToken] == 0) {
        _firstTradedTimestampMap[params.baseToken] = _blockTimestamp();
    }

    return
        InternalSwapResponse({
            base: exchangedPositionSize,
            quote: exchangedPositionNotional.sub(replayResponse.fee.toInt256()),
            exchangedPositionSize: exchangedPositionSize,
            exchangedPositionNotional: exchangedPositionNotional,
            fee: replayResponse.fee,
            insuranceFundFee: replayResponse.insuranceFundFee,
            tick: replayResponse.tick
        });
}

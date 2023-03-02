function _openPositionFor(address trader, OpenPositionParams memory params)
    internal
    returns (
        uint256 base,
        uint256 quote,
        uint256 fee
    )
{
    // input requirement checks:
    //   baseToken: in Exchange.settleFunding()
    //   isBaseToQuote & isExactInput: X
    //   amount: in UniswapV3Pool.swap()
    //   oppositeAmountBound: in _checkSlippage()
    //   deadline: here
    //   sqrtPriceLimitX96: X (this is not for slippage protection)
    //   referralCode: X

    _checkMarketOpen(params.baseToken);

    // register token if it's the first time
    _registerBaseToken(trader, params.baseToken);

    // must settle funding first
    _settleFunding(trader, params.baseToken);

    IExchange.SwapResponse memory response = _openPosition(
        InternalOpenPositionParams({
            trader: trader,
            baseToken: params.baseToken,
            isBaseToQuote: params.isBaseToQuote,
            isExactInput: params.isExactInput,
            amount: params.amount,
            isClose: false,
            sqrtPriceLimitX96: params.sqrtPriceLimitX96
        })
    );

    _checkSlippage(
        InternalCheckSlippageParams({
            isBaseToQuote: params.isBaseToQuote,
            isExactInput: params.isExactInput,
            base: response.base,
            quote: response.quote,
            oppositeAmountBound: params.oppositeAmountBound
        })
    );

    _referredPositionChanged(params.referralCode);

    return (response.base, response.quote, response.fee);
}

//

//

//

//

//

/// @dev explainer diagram for the relationship between exchangedPositionNotional, fee and openNotional:
///      https://www.figma.com/file/xuue5qGH4RalX7uAbbzgP3/swap-accounting-and-events
function _openPosition(InternalOpenPositionParams memory params)
    internal
    returns (IExchange.SwapResponse memory)
{
    IExchange.SwapResponse memory response = IExchange(_exchange).swap(
        IExchange.SwapParams({
            trader: params.trader,
            baseToken: params.baseToken,
            isBaseToQuote: params.isBaseToQuote,
            isExactInput: params.isExactInput,
            isClose: params.isClose,
            amount: params.amount,
            sqrtPriceLimitX96: params.sqrtPriceLimitX96
        })
    );

    _modifyOwedRealizedPnl(
        _insuranceFund,
        response.insuranceFundFee.toInt256()
    );

    // examples:
    // https://www.figma.com/file/xuue5qGH4RalX7uAbbzgP3/swap-accounting-and-events?node-id=0%3A1
    _settleBalanceAndDeregister(
        params.trader,
        params.baseToken,
        response.exchangedPositionSize,
        response.exchangedPositionNotional.sub(response.fee.toInt256()),
        response.pnlToBeRealized,
        0
    );

    if (response.pnlToBeRealized != 0) {
        // if realized pnl is not zero, that means trader is reducing or closing position
        // trader cannot reduce/close position if the remaining account value is less than
        // accountValue * LiquidationPenaltyRatio, which
        // enforces traders to keep LiquidationPenaltyRatio of accountValue to
        // shore the remaining positions and make sure traders having enough money to pay liquidation penalty.

        // CH_NEMRM : not enough minimum required margin after reducing/closing position
        require(
            getAccountValue(params.trader) >=
                _getTotalAbsPositionValue(params.trader)
                    .mulRatio(_getLiquidationPenaltyRatio())
                    .toInt256(),
            "CH_NEMRM"
        );
    }

    // check margin ratio after swap: mmRatio for closing position; else, imRatio
    if (params.isClose) {
        // CH_NEFCM: not enough free collateral by mmRatio
        require(
            (_getFreeCollateralByRatio(
                params.trader,
                IClearingHouseConfig(_clearingHouseConfig).getMmRatio()
            ) >= 0),
            "CH_NEFCM"
        );
    } else {
        _requireEnoughFreeCollateral(params.trader);
    }

    // openNotional will be zero if baseToken is deregistered from trader's token list.
    int256 openNotional = _getTakerOpenNotional(
        params.trader,
        params.baseToken
    );
    _emitPositionChanged(
        params.trader,
        params.baseToken,
        response.exchangedPositionSize,
        response.exchangedPositionNotional,
        response.fee,
        openNotional,
        response.pnlToBeRealized, // realizedPnl
        response.sqrtPriceAfterX96
    );

    return response;
}

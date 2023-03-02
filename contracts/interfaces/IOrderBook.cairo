@contract_interface
namespace IOrderBook {
    func set_exchange(exchange_address: felt) -> () {
    }

    func add_liquidity(add_liq_params: AddLiquidityParams, trader: felt) -> (
        amount_a: Uint256, amount_b: Uint256, liquidity: Uint256
    ) {
    }

    func remove_liquidity(remove_liq_params: RemoveLiquidityParams, trader: felt) -> (
        amount_base: Uint256, amount_quote: Uint256, taker_base: Uint256, taker_quote: Uint256
    ) {
    }
}

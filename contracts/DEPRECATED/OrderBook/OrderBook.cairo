from openzeppelin.token.erc20.IERC20 import IERC20

from contracts.interfaces.IMarketRegistry import IMarketRegistry
from contracts.interfaces.IRouter import IRouter
from contrats.structs import AddLiquidityParams, RemoveLiquidityParams

from starkware.cairo.common.math import (
    assert_not_zero,
    assert_le,
    assert_lt,
    unsigned_div_rem,
    split_felt,
)
from starkware.cairo.common.uint256 import Uint256, uint256_eq, uint256_mul_div_mod

// STORAGE ==============================================
@storage_var
func _exchange() -> (address: felt) {
}
@storage_var
func open_orders_s(trader: felt, base_token: felt) -> (order: OrderInfo) {
}

// CONSTRUCTOR ============================================
@constructor
func constructor() {
    // __ClearingHouseCallee_init();
    // __UniswapV3CallbackBridge_init(marketRegistryArg);
}

// EXTERNAL ===============================================
@external
func set_exchange{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    exchange_address: felt
) {
    _exchange.write(exchange_address);
    // emit ExchangeChanged(exchangeArg);
}

@external
func add_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    add_liq_params: AddLiquidityParams, trader: felt
) -> (amount_a: Uint256, amount_b: Uint256, liquidity: Uint256) {
    // _requireOnlyClearingHouse();

    let pool_addr = IMarketRegistry.get_pool(add_liq_params.base_token);

    let (amount_a: Uint256, amount_b: Uint256, liquidity: Uint256) = IRouter.addLiquidity(
        contract_address=pool_addr,
        add_liq_params.tokenA,
        add_liq_params.tokenB,
        add_liq_params.amountADesired,
        add_liq_params.amountBDesired,
        add_liq_params.amountAMin,
        add_liq_params.amountBMin,
        trader,
        add_liq_params.deadline,
    );

    let (order: OrderInfo) = open_orders_s.read(trader, base_token=add_liq_params.tokenA);

    let new_liquidity = liquidity + order.liquidity;
    let base_debt = amount_a + order.base_debt;
    let quote_debt = amount_b + order.quote_debt;

    let new_order = OrderInfo(liquidity=new_liquidity, base_debt=base_debt, quote_debt=quote_debt);

    open_orders_s.write(trader, base_token=add_liq_params.tokenA, value=new_order);

    return (amount_a, amount_b, liquidity);
}

@external
func remove_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    remove_liq_params: RemoveLiquidityParams, trader
) -> (amount_base: Uint256, amount_quote: Uint256, taker_base: Uint256, taker_quote: Uint256) {
    // _requireOnlyClearingHouse();

    with_attr errot_message("OB: Liquidity must be greater than 0") {
        assert_not_zero(remove_liq_params.liquidity);
    }

    let pool_addr = IMarketRegistry.get_pool(add_liq_params.base_token);

    let (amount_base: Uint256, amount_quote: Uint256) = IRouter.removeLiquidity(
        contract_address=pool_addr,
        remove_liq_params.tokenA,
        remove_liq_params.tokenB,
        remove_liq_params.liquidity,
        remove_liq_params.amountAMin,
        remove_liq_params.amountBMin,
        trader,
        remove_liq_params.deadline,
    );

    let (order: OrderInfo) = open_orders_s.read(trader=trader, base_token=remove_liq_params.tokenA);

    let (base_debt, quote_debt) = remove_liquidity_from_order(remove_liq_params, order);

    // diff between what you received frome the pool after removing liquidity and what you deposited to the pool
    let taker_base = amount_base - base_debt;
    let taker_quote = amount_quote - quote_debt;

    return (amount_base, amount_quote, taker_base, taker_quote);
}

// HELPER FUNCTIONS =======================================

func remove_liquidity_from_order{syscall_ptr: felt*, range_check_ptr}(
    remove_liq_params: RemoveLiquidityParams, order: OrderInfo, trader: felt
) -> (Uint256, Uint256) {
    let cond1 = uint256_eq(remove_liq_params.liquidity, Uint256(0, 0));
    if (cond1 == 0) {
        let base_debt = get_modified_debt(
            order_debt=order.base_debt,
            liquidity=remove_liq_params.liquidity,
            order_liquidity=order.liquidity,
        );

        let quote_debt = get_modified_debt(
            order_debt=order.quote_debt,
            liquidity=remove_liq_params.liquidity,
            order_liquidity=order.liquidity,
        );

        let liquidity = order.liquidity - remove_liq_params.liquidity;

        let cond2 = uint256_eq(liquidity, Uint256(0, 0));
        if (cond2 == 1) {
            open_orders_s.write(
                trader,
                remove_liq_params.tokenA,
                value=OrderInfo(liquidity=Uint256(0, 0), base_debt=Uint256(0, 0), quote_debt=Uint256(0, 0)),
            );
        } else {
            open_orders_s.write(
                trader,
                remove_liq_params.tokenA,
                value=OrderInfo(liquidity=liquidity, base_debt=base_debt, quote_debt=quote_debt),
            );
        }

        return (base_debt, quote_debt);
    }
}

func get_modified_debt{syscall_ptr: felt*, range_check_ptr}(
    order_debt: Uint256, liquidity: Uint256, order_liquidity: Uint256
) -> Uint256 {
    let cond = uint256_eq(order_debt, Uint256(0, 0));
    if (cond == 0) {
        let (
            quotient_low: Uint256, quotient_high: Uint256, remainder: Uint256
        ) = uint256_mul_div_mod(order_debt, liquidity, order_liquidity);

        return quotient_low;
    }

    return Uint256(0, 0);
}

// STRUCTS ================================================

struct OrderInfo {
    liquidity: Uint256,
    base_debt: Uint256,
    quote_debt: Uint256,
}

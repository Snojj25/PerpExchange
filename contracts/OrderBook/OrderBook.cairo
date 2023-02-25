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
    add_liq_params: AddLiquidityParams
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
        add_liq_params.to,
        add_liq_params.deadline,
    );

    let (order: OrderInfo) = open_orders_s.read(
        trader=add_liq_params.to, base_token=add_liq_params.tokenA
    );

    let new_liquidity = liquidity + order.liquidity;
    let base_debt = amount_a + order.base_debt;
    let quote_debt = amount_b + order.quote_debt;

    let new_order = OrderInfo(liquidity=new_liquidity, base_debt=base_debt, quote_debt=quote_debt);

    open_orders_s.write(
        trader=add_liq_params.to, base_token=add_liq_params.tokenA, value=new_order
    );

    return (amount_a, amount_b, liquidity);
}

@external
func remove_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    remove_liq_params: RemoveLiquidityParams
) {
    // _requireOnlyClearingHouse();

    let pool_addr = IMarketRegistry.get_pool(add_liq_params.base_token);

    let (amount_a: Uint256, amount_b: Uint256) = IRouter.removeLiquidity(
        contract_address=pool_addr,
        remove_liq_params.tokenA,
        remove_liq_params.tokenB,
        remove_liq_params.liquidity,
        remove_liq_params.amountAMin,
        remove_liq_params.amountBMin,
        remove_liq_params.to,
        remove_liq_params.deadline,
    );

    let (order: OrderInfo) = open_orders_s.read(
        trader=remove_liq_params.to, base_token=remove_liq_params.tokenA
    );

    let cond1 = uint256_eq(remove_liq_params.liquidity, Uint256(0, 0));
    if (cond1 == 0) {
        let cond2 = uint256_eq(order.base_debt, Uint256(0, 0));
        if (cond2 == 0) {
            let (
                quotient_low: Uint256, quotient_high: Uint256, remainder: Uint256
            ) = uint256_mul_div_mod(order.base_debt, remove_liq_params.liquidity, order.liquidity);
        }

        let cond3 = uint256_eq(order.quote_debt, Uint256(0, 0));
        if (cond3 == 0) {
            let (
                quotient_low: Uint256, quotient_high: Uint256, remainder: Uint256
            ) = uint256_mul_div_mod(order.base_debt, remove_liq_params.liquidity, order.liquidity);
        }
    }
}

// HELPER FUNCTIONS =======================================

func remove_liquidity{syscall_ptr: felt*, range_check_ptr}(
    remove_liq_params: RemoveLiquidityParams
) {
}

// STRUCTS ================================================

struct OrderInfo {
    liquidity: Uint256,
    base_debt: Uint256,
    quote_debt: Uint256,
}

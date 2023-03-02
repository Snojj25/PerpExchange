from openzeppelin.token.erc20.IERC20 import IERC20

from starkware.cairo.common.math import (
    assert_not_zero,
    assert_le,
    assert_lt,
    unsigned_div_rem,
    split_felt,
)

from starkware.cairo.common.math_cmp import is_eq, is_lt, is_not_zero

from contracts.interfaces.IAccountBalance import IAccountBalance
from contracts.interfaces.IMarketRegistry import IMarketRegistry
from contracts.structs.param_structs import SwapParams

// STORAGE ==============================================
@storage_var
func exchange_config_s() -> (address: felt) {
}
@storage_var
func order_book_s() -> (address: felt) {
}
@storage_var
func account_balance_s() -> (address: felt) {
}
@storage_var
func market_registry_s() -> (address: felt) {
}
@storage_var
func first_traded_timestamp_map(addr: felt) -> (res: felt) {
}
@storage_var
func last_settled_timestamp_map(addr: felt) -> (res: felt) {
}
//
@storage_var
func collateral_token_s() -> (res: felt) {
}

// CONSTRUCTOR ============================================
@constructor
func constructor(market_registry_addr: felt, order_book_addr: felt, exchange_config_addr: felt) {
    assert_not_zero(market_registry_addr);
    assert_not_zero(exchange_config_addr);
    assert_not_zero(order_book_addr);

    // __ClearingHouseCallee_init();

    exchange_config_s.write(exchange_config_addr);
    order_book_s.write(order_book_addr);
}

@external
func name{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    arguments
) {

    

    }



// EXTERNAL ================================================

@external
func swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swap_params: InternalReplaySwapParams, trader: felt
) {
    // _requireOnlyClearingHouse();

    // EX_MIP: market is paused: require(!market.isPaused(), "market is paused");

    let account_balance_addr = account_balance_s.read();
    let taker_position_size = IAccountBalance.get_taker_position_size(
        contract_address=account_balance_addr, trader=trader, base_token=swap_params.baseToken
    );

    if (swap_params.is_close == 1) {
        let cond2 = is_not_zero(taker_position_size);
        if (cond2 == 1) {
        }
    }

    let taker_open_notional = IAccountBalance.get_taker_open_notional(
        contract_address=account_balance_addr, trader=trader, base_token=swap_params.baseToken
    );
}

// VIEW ====================================================

@view
func get_collateral_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) -> felt {
    let coll_addr = collateral_token_s.read();

    return coll_addr;
}

// HELPERS =================================================

func _swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swap_params: SwapParams, trader: felt
) {
    let market_registry_addr = market_registry_s.read();
    let market_info = IMarketRegistry.get_market_info(
        contract_address=market_registry_addr, base_token=swap_params.baseToken
    );

    // Take the fee from the taker.
}

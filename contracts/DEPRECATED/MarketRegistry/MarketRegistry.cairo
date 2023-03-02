from starkware.cairo.common.math import (
    assert_not_zero,
    assert_le,
    assert_lt,
    unsigned_div_rem,
    split_felt,
)

// STORAGE ==============================================
@storage_var
func _uniswapV3_factory() -> (res: felt) {
}
@storage_var
func _quote_token() -> (res: felt) {
}
@storage_var
func _max_orders_per_market() -> (res: felt) {
}
@storage_var
func _pool_map(base_token: felt) -> (res: felt) {
}
@storage_var
func _insurance_fund_fee_ratio_map(base_token: felt) -> (res: felt) {
}
@storage_var
func _exchange_fee_ratio(base_token: felt) -> (res: felt) {
}
@storage_var
func _uniswap_fee_ratio(base_token: felt) -> (res: felt) {
}

// CONSTRUCTOR ============================================
@constructor
func constructor(uniswapV3_factory_addr: felt, quote_token_addr: felt) {
    // __ClearingHouseCallee_init();

    assert_not_zero(uniswapV3_factory_addr);
    assert_not_zero(quote_token_addr);

    _uniswapV3_factory.write(uniswapV3_factory_addr);
    _quote_token.write(quote_token_addr);
    _max_orders_per_market.write(255);
}

// EXTERNAL FUNCTIONS =====================================
@external
func add_pool{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    base_token: felt, fee_ratio: felt
) {
    // TODO:

    let (current_pool) = _pool_map.read(base_token);
    with_attr error_message("pool already exists") {
    }
    assert current_pool = 0;

    // require(IERC20Metadata(baseToken).balanceOf(_clearingHouse) == type(uint256).max, "MR_CHBNE");
}

// VIEW FUNCTIONS ==========================================

@view
func get_market_info{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    base_token: felt
) -> felt {
    let (pool_addr: felt) = _pool_map.read(base_token);
    let (exchange_fee_ratio: felt) = _exchange_fee_ratio.read(base_token);
    let (uniswap_fee_ratio: felt) = _uniswap_fee_ratio.read(base_token);
    let (insurance_fund_fee_ratio: felt) = _insurance_fund_fee_ratio_map.read(base_token);

    return MarketInfo(pool_addr, exchange_fee_ratio, uniswap_fee_ratio, insurance_fund_fee_ratio);
}

@view
func get_pool{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    base_token: felt
) -> felt {
    let (pool_addr: felt) = _pool_map.read(base_token);

    return pool_addr;
}

// STRUCTS ================================================
struct MarketInfo {
    pool: felt,
    exchange_fee_ratio: felt,
    uniswap_fee_ratio: felt,
    insurance_fund_fee_ratio: felt,
}

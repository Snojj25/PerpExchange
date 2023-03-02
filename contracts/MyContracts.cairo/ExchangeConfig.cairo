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
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_eq,
    uint256_mul_div_mod,
    uint256_add,
    uint256_sub,
)

// STORAGE ==============================================

const COLLATERAL_DECIMALS = 6;

@storage_var
func collateral_token_s() -> (res: felt) {
}

@storage_var
func token_decimals_s(token: felt) -> (res: felt) {
}
@storage_var
func price_decimals_s(token: felt) -> (res: felt) {
}

// Initial margin ratio (in promille)
@storage_var
func IM_ratio(token: felt) -> (res: felt) {
}
// Maintenance margin ratio (in promille)
@storage_var
func MM_ratio(token: felt) -> (res: felt) {
}

@storage_var
func last_funding_index_s() -> (res: felt) {
}

// CONSTRUCTOR ============================================
@constructor
func constructor(IM_ratio: felt, MM_ratio: felt) {
    assert_not_zero(IM_ratio);
    assert_not_zero(MM_ratio);
    assert_lt(MM_ratio, IM_ratio);

    IM_ratio_s.write(IM_ratio);
    MM_ratio_s.write(MM_ratio);
}

@external
func register_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_addr: felt, token_decimals: felt, price_decimals: felt
) {
    assert_le(token_decimals, 18);

    token_decimals_s.write(token_addr, token_decimals);
    price_decimals_s.write(token_addr, price_decimals);
}

@view
func get_token_info{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_addr: felt
) -> (token_decimals: felt, price_decimals: felt) {
    let token_decimals = token_decimals_s.read(token_addr);
    let price_decimals = price_decimals_s.read(token_addr);

    return (token_decimals, price_decimals);
}

@view
func get_IM_ratio{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token: felt
) -> felt {
    let IM_ratio = IM_ratio_s.read(token);

    return IM_ratio;
}

@view
func get_MM_ratio{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token: felt
) -> felt {
    let MM_ratio = IM_ratio_s.read(token);

    return MM_ratio;
}

@view
func get_collateral_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) -> felt {
    let collateral_token = collateral_token_s.read();

    return collateral_token;
}

@view
func calculate_price_from_quote{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    base_token: felt, base_amount: felt, quote_amount: felt
) -> felt {
    // base_amount has base_decimals
    // price has price_decimals
    // quote has COLLATERAL_DECIMALS

    let (base_decimals: felt) = token_decimals_s.read(base_token);
    let (price_decimals: felt) = price_decimals_s.read(base_token);

    let decimal_conversion = price_decimals - COLLATERAL_DECIMALS + base_decimals;
    let (multiplier: felt) = 10 ** decimal_conversion;

    let (price: felt, _) = unsigned_div_rem(quote_amount * multiplier, base_amount);

    return price;
}

@view
func calculate_quote_from_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    base_token: felt, base_amount: felt, price: felt
) -> felt {
    // base_amount has base_decimals
    // price has price_decimals
    // quote has COLLATERAL_DECIMALS

    alloc_locals;

    let (base_decimals: felt) = token_decimals_s.read(base_token);
    let (price_decimals: felt) = price_decimals_s.read(base_token);

    let decimal_conversion = price_decimals - COLLATERAL_DECIMALS + base_decimals;
    let (multiplier: felt) = 10 ** decimal_conversion;

    let (quote: felt, _) = unsigned_div_rem(base_amount * price, multiplier);

    return quote;
}

from openzeppelin.token.erc20.IERC20 import IERC20

from starkware.cairo.common.math import (
    assert_not_zero,
    assert_le,
    assert_lt,
    unsigned_div_rem,
    split_felt,
)

// STORAGE ==============================================
@storage_var
func _token() -> (token_address: felt) {
}
@storage_var
func _price_feed_decimals() -> (decimals: felt) {
}
@storage_var
func _price_feed() -> (feed_address: felt) {
}
// status - 0: Open, 1: Paused, 2: Closed
@storage_var
func _status() -> (status: felt) {
}
@storage_var
func _paused_index_price() -> (price: felt) {
}
@storage_var
func _paused_timestamp() -> (ts: felt) {
}
@storage_var
func _closed_price() -> (price: felt) {
}

// CONSTRUCTOR ============================================
@constructor
func constructor(name: felt, symbol: felt, priceFeed: felt, token: felt) {
    // __VirtualToken_init(nameArg, symbolArg);

    // uint8 priceFeedDecimals = IPriceFeedV2(priceFeedArg).decimals();
    // Todo
    let priceFeedDecimals = 10;

    let t_decimals = IERC20.decimals(contract_address=contract_address);

    with_attr error_message("==== BT invalid decimals ====") {
        assert_le(priceFeedDecimals, t_decimals);
    }

    _token.write(token);
    _price_feed_decimals.write(priceFeedDecimals);
    _price_feed.write(priceFeed);
}

// VIEW FUNCTIONS ==========================================
@view
func is_open{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> felt {
    if (_status.read() == 0) {
        return 1;
    } else {
        return 0;
    }
}

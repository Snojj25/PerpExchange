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
func _clearing_house_config() -> (address: felt) {
}
@storage_var
func _order_book() -> (address: felt) {
}
@storage_var
func _vault() -> (address: felt) {
}
// trader => owedRealizedPnl
@storage_var
func _owed_realized_pnl_map(addr: felt) -> (pnl: felt) {
}
// trader => baseTokens
@storage_var
func _base_tokens_map(addr: felt) -> (addresses_len: felt, addresses: felt*) {
}
// first key: trader, second key: baseToken
@storage_var
func _account_market_map(trader: felt, base_token: felt) -> (res: MarketInfo) {
}

// CONSTRUCTOR ============================================
@constructor
func constructor(clearing_house_config_addr: felt, order_book_addr: felt) {
    assert_not_zero(clearing_house_config_addr);
    assert_not_zero(order_book_addr);

    // __ClearingHouseCallee_init();

    _clearing_house_config.write(clearing_house_config_addr);
    _order_book.write(order_book_addr);
}

// EXTERNAL ===============================================

@external
func set_vault{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(vault_addr: felt) {
    assert_not_zero(vault_addr);

    _vault.write(vault_addr);

    // emit VaultChanged(vaultArg);
}

@external
func register_base_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    trader: felt, base_token: felt
) {
    // NOTE: Registers a base token so that we can loop over all of the users open positions for calculations

    // _requireOnlyClearingHouse();

    let (base_tokens_len: felt, base_tokens: felt*) = _base_tokens_map.read(addr=trader);

    let cond = _has_base_token(base_tokens_len, base_tokens, base_token);
    if (cond == 1) {
        return ();
    }

    let new_base_tokens_len = base_tokens_len + 1;
    assert base_tokens[base_tokens_len] = base_token;

    _base_tokens_map.write(addr=trader, value=(new_base_tokens_len, base_tokens));

    // require(new_base_tokens_len <= IClearingHouseConfig(_clearingHouseConfig).getMaxMarketsPerAccount(), "AB_MNE");

    return ();
}

@external
func modify_owed_realized_pnl{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    trader: felt, amount: felt
) {
    // _requireOnlyClearingHouse();

    if (amount == 0) {
        return ();
    }

    let pnl = _owed_realized_pnl_map.read(addr=trader);
    let new_pnl = pnl + amount;
    _owed_realized_pnl_map.write(addr=trader, value=new_pnl);
    // emit PnlRealized(trader, amount);
}

// VIEW FUNCTIONS =========================================

@view
func get_taker_position_size{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    trader: felt, base_token: felt
) -> felt {
    let (market_info: MarketInfo) = _account_market_map.read(trader=trader, base_token=base_token);

    let position_size = market_info.taker_position_size;

    // return positionSize.abs() < _DUST ? 0 : positionSize;

    return position_size;
}

@view
func get_taker_open_notional{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    trader: felt, base_token: felt
) -> felt {
    let (market_info: MarketInfo) = _account_market_map.read(trader=trader, base_token=base_token);

    let open_notional = market_info.taker_open_notional;

    // return positionSize.abs() < _DUST ? 0 : positionSize;

    return open_notional;
}

@view
func get_base_tokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    trader: felt
) -> (base_tokens_len: felt, base_tokens: felt*) {
    return _base_tokens_map.read(addr=trader);
}

@view
func get_taker_open_notional{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    trader: felt, base_token: felt
) -> felt {
    let (market_info: MarketInfo) = _account_market_map.read(trader=trader, base_token=base_token);

    let open_notional = market_info.taker_open_notional;

    // return positionSize.abs() < _DUST ? 0 : positionSize;

    return open_notional;
}

// HELPER FUNCTIONS ========================================

func _has_base_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    base_tokens_len: felt, base_tokens: felt*, base_token: felt
) -> felt {
    if (base_tokens_len == 0) {
        return 0;
    }

    let ti = base_tokens[0];

    if (ti == base_token) {
        return 1;
    }

    return _has_base_token(base_tokens_len - 1, &base_tokens[1], base_token);
}

// STRUCTS ================================================

struct MarketInfo {
    taker_position_size: felt,
    taker_open_notional: felt,
    last_tw_premium_growth_global_x96: felt,
}

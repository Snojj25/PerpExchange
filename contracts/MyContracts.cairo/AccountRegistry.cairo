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
func vault_s() -> (res: felt) {
}
// trader => owedRealizedPnl
@storage_var
func realized_pnl_s(addr: felt) -> (pnl: felt) {
}
// trader => baseTokens
@storage_var
func base_tokens_map(addr: felt) -> (addresses_len: felt, addresses: felt*) {
}
// first key: trader, second key: baseToken
@storage_var
func position_info_s(trader: felt, base_token: felt) -> (res: PositionInfo) {
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

@external
func set_vault{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(vault_addr: felt) {
    vault_s.write(vault_addr);

    return ();
}

// EXTERNAL ===============================================

@external
func update_position{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    trader: felt,
    base_token: felt,
    updated_size: felt,
    updated_entry_price: felt,
    funding_index: felt,
    prev_is_long: felt,
    new_is_long: felt,
) {


    if (prev_is_long == new_is_long) {

        let (position: PositionInfo) = PositionInfo(
            position_size=updated_size,
            entry_price=updated_entry_price,
            last_funding_index=funding_index,
            is_long=new_is_long,
        );


        position_info_s.write(
            trader=trader, base_token=base_token, value=position
        );

    } else {

    let cond = is_le(prev);
    
    
    
    }


    let (position: PositionInfo) = position_info_s.write(
        trader=trader, base_token=base_token, value=new_position
    );
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
func modify_realized_pnl{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    trader: felt, amount: felt
) {
    // _requireOnlyClearingHouse();

    if (amount == 0) {
        return ();
    }

    let pnl = realized_pnl_s.read(addr=trader);
    let new_pnl = pnl + amount;
    realized_pnl_s.write(addr=trader, value=new_pnl);
    // emit PnlRealized(trader, amount);
}

@external
func deposit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
}
@external
func withdrawal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
}

// VIEW FUNCTIONS =========================================

@view
func get_position_size{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    trader: felt, base_token: felt
) -> felt {
    let (position: PositionInfo) = position_info_s.read(trader, base_token);

    return position.position_size;
}

@view
func get_base_tokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    trader: felt
) -> (base_tokens_len: felt, base_tokens: felt*) {
    return _base_tokens_map.read(addr=trader);
}

@view
func get_account_value{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    trader: felt
) -> felt {
    let realized_pnl = realized_pnl_s.read(addr=trader);
    let unrealized_pnl = get_unrealized_pnl(trader);

    let vault_addr = vault_s.read();
    let collateral_balance = IVault.get_user_collateral_balance(vault_addr, trader);

    let account_value = collateral_balance + realized_pnl + unrealized_pnl;

    return account_value;
}

@view
func get_nominal_value{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    trader: felt
) -> felt {
    let (base_tokens_len: felt, base_tokens: felt*) = _base_tokens_map.read(addr=trader);

    let nominal_value = _get_nominal_value_inner(trader, base_tokens_len, base_tokens, 0);

    return nominal_value;
}

@view
func get_unrealized_pnl(trader: felt) -> felt {
    let (base_tokens_len: felt, base_tokens: felt*) = _base_tokens_map.read(addr=trader);

    return _get_unrealized_pnl_inner(trader, base_tokens_len, base_tokens, 0);
}

// HELPERS ================================================

func _get_nominal_value_inner(
    trader: felt, base_tokens_len: felt, base_tokens: felt*, sum: felt
) -> felt {
    if (base_tokens_len == 0) {
        return sum;
    }

    let base_token = base_tokens[0];

    // Todo: get_price
    let price = 123;

    let (position: PositionInfo) = position_info_s.read(trader, base_token);

    let nominal_value = position.position_size * price;

    let new_sum = sum + nominal_value;

    return _get_nominal_value_inner(trader, base_tokens_len - 1, &base_tokens[1], new_sum);
}

func _get_unrealized_pnl_inner(
    trader: felt, base_tokens_len: felt, base_tokens: felt*, sum: felt
) -> felt {
    if (base_tokens_len == 0) {
        return sum;
    }

    let base_token = base_tokens[0];

    // Todo: get_price
    let price = 123;
    let pnl = _get_unrealized_pnl_for_token(trader, base_token, price);

    let new_sum = sum + pnl;

    return _get_unrealized_pnl_inner(trader, base_tokens_len - 1, &base_tokens[1], new_sum);
}

func _get_unrealized_pnl_for_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    trader: felt, base_token: felt, price: felt
) -> felt {
    let (position: PositionInfo) = position_info_s.read(trader, base_token);

    let position_size = position.position_size;
    let entry_price = position.entry_price;

    // todo: check if we need to apply funding (incase this is called from outside the exchange)
    let pending_funding = 0;

    let price_diff = entry_price - price - 2 * position.is_long * entry_price + 2 * position.is_long * price;
    let pnl = position_size * price_diff + pending_funding;

    return pnl;
}

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

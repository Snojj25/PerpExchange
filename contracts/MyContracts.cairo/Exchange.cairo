from starkware.starknet.common.syscalls import get_caller_address

from contracts.param_structs import AddLiquidityParams, SwapParams
from contracts.interfaces.IBaseToken import IBaseToken
from contracts.interfaces.IAccountBalance import IAccountBalance
from contracts.interfaces.IOrderBook import IOrderBook
from contracts.interfaces.IExchange import IExchange

// STORAGE ==============================================
// address internal _quoteToken;
// address internal _uniswapV3Factory;
@storage_var
func exchange_config_s() -> (address: felt) {
}
@storage_var
func vault_s() -> (address: felt) {
}
@storage_var
func account_registry_s() -> (address: felt) {
}
@storage_var
func _insurance_fund() -> (address: felt) {
}
@storage_var
func router_addr_s() -> (address: felt) {
}

// CONSTRUCTOR ============================================

@constructor
func constructor() -> () {
    assert_not_zero(clearing_house_config_addr);

    _clearing_house_config.write(clearing_house_config_addr);
}

// EXTERNAL ===============================================

@external
func add_liquidity{pedersen_ptr: HashBuiltin*}(add_liq_params: AddLiquidityParams) -> () {
    alloc_locals;

    // _checkMarketOpen(params.baseToken);

    let is_open = IBaseToken.is_open(contract_address=add_liq_params.tokenA);
    with_attr error_message("==== CH: market is not open ====") {
        assert is_open = 1;
    }

    // require(!IExchange(_exchange).isOverPriceSpread(params.baseToken), "CH_OMPS");

    // require(!params.useTakerBalance, "CH_DUTB");

    let trader = get_caller_address();

    let account_balance_addr = _account_balance.read();
    IAccountBalance.register_base_token(
        contract_address=account_balance_addr, trader=trader, base_token=add_liq_params.tokenA
    );

    // // must settle funding first
    // Funding.Growth memory fundingGrowthGlobal = _settleFunding(
    //     trader,
    //     params.baseToken
    // );

    let (amount_a: Uint256, amount_b: Uint256, liquidity: Uint256) = IOrderBook.add_liquidity(
        add_liq_params, trader
    );

    with_attr error_message("too much slippage") {
        assert_le(add_liq_params.tokenAMin, amount_a);
        assert_le(add_liq_params.tokenBMin, amount_b);
    }
}

@external
func open_position{pedersen_ptr: HashBuiltin*}(swap_params: SwapParams) -> () {
    alloc_locals;

    let is_open = IBaseToken.is_open(contract_address=swap_params.baseToken);
    with_attr error_message("==== CH: market is not open ====") {
        assert is_open = 1;
    }

    let trader = get_caller_address();

    // register token if it's the first time
    let account_registry_addr = account_registry_s.read();
    IAccountRegistry.register_base_token(
        contract_address=account_registry_addr, trader=trader, base_token=swap_params.baseToken
    );

    let expected_quote_amount = get_estimated_quote_amount(
        base_amount=swap_params.amount, base_token=swap_params.baseToken, is_long=swap_params.isLong
    );

    let prev_position = IAccountRegistry.get_position(
        contract_address=account_registry_addr, trader=trader, base_token=swap_params.baseToken
    );
    // let current_funding_index =
    // Todo: Apply funding to all positions
    // Todo: Update realized PnL

    let position_effect_type = get_position_effect_type(prev_position, swap_params);

    // Get account value = collateral + pnl
    let account_value = IAccountRegistry.get_account_value(trader=trader);

    // Get Initial Margin Requirenment = sum(position_notional) * IMR
    let nominal_value = IAccountRegistry.get_nominal_value(trader=trader);
    // Get estimated new nominal value after swap
    let new_nominal_value = _get_estimated_new_nominal(
        nominal_value, prev_position.position_size, swap_params, position_effect_type
    );
    // Calculate the initial margin requirement for the new nominal value
    let (margin_requirement, _) = unsigned_div_rem(new_nominal_value * IMR, 1000);

    // assert account value >= margin requirement
    assert_le(margin_requirement, account_value);

    let (quote_amount_: Uint256) = execute_swap(swap_params=swap_params);
    let quote_amount = quote_amount_.high * 2 ** 128 + quote_amount_.low;

    let exchange_config_addr = exchange_config_s.read();
    let entry_price = IExchangeConfing.calculate_price_from_quote(
        contract_address=exchange_config_addr,
        base_token=swap_params.baseToken,
        base_amount=swap_params.amount,
        quote_amount=quote_amount,
    );

    let avg_entry_price = get_average_entry_price(
        prev_size=prev_position.position_size,
        entry_price=prev_position.entry_price,
        added_size=swap_params.amount,
        added_entry_price=entry_price,
    );

    // let new_position =
}

// HELPERS ===============================================
func execute_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swap_params: SwapParams
) -> (quote_amount: Uint256) {
    let exchange_config_addr = exchange_config_s.read();
    let collateral_token = IExchangeConfing.get_collateral_token(
        contract_address=exchange_config_addr, base_token=swap_params.base_token
    );
    let vault_addr = vault_s.read();

    let router_addr = router_addr_s.read();
    if (swap_params.is_long == 1) {
        // Position is Long

        // Swapping collateral token for base token
        let (path: felt*) = alloc();
        path[0] = collateral_token;
        path[1] = swap_params.base_token;

        // worst price is the highest price that the trader is willing to accept
        // therefore we want to calculate the maximum amount of collateral token spent
        let max_collateral_spent = IExchangeConfing.calculate_quote_from_price(
            contract_address=exchange_config_addr,
            base_token=swap_params.base_token,
            base_amount=swap_params.amount,
            price=swap_params.worst_price,
        );
        let (high_quote, low_quote) = split_felt(max_collateral_spent);
        let max_quote_in = Uint256(high=high_quote, low=low_quote);

        let (high_base, low_base) = split_felt(swap_params.amount);
        let base_amount = Uint256(high=high_base, low=low_base);

        // then make the swap and verify the amount spent is less than the maximum
        let (amounts_len: felt, amounts: Uint256*) = Il0kRouter.swapTokensForExactTokens(
            base_amount, max_quote_in, 2, path, vault_addr, swap_params.deadline
        );

        return (amounts[amounts_len - 1]);
    } else {
        // Position is short

        // Swapping base token for collateral token
        let (path: felt*) = alloc();
        path[0] = swap_params.base_token;
        path[1] = collateral_token;

        // worst price is the lowest price that the trader is willing to accept
        // therefore we want to calculate the minimum amount of collateral token received
        let min_collateral_received = IExchangeConfing.calculate_quote_from_price(
            contract_address=exchange_config_addr,
            base_token=swap_params.base_token,
            base_amount=swap_params.amount,
            price=swap_params.worst_price,
        );
        let (high_quote, low_quote) = split_felt(min_collateral_received);
        let min_quote_out = Uint256(high=high_quote, low=low_quote);

        let (high_base, low_base) = split_felt(swap_params.amount);
        let base_amount = Uint256(high=high_base, low=low_base);

        // then make the swap and verify the amount received is greater than the minimum
        let (amounts_len: felt, amounts: Uint256*) = Il0kRouter.swapExactTokensForTokens(
            base_amount, min_quote_out, 2, path, vault_addr, swap_params.deadline
        );

        return (amounts[amounts_len - 1]);
    }
}

func get_estimated_quote_amount{pedersen_ptr: HashBuiltin*}(
    base_amount: felt, base_token: felt, is_long: felt
) -> felt {
    alloc_locals;

    let (collateral_token) = IExchange.get_collateral_token(
        contract_address=_exchange.read(), base_token=base_token
    );

    let router_addr = router_addr_s.read();
    if (is_long == 1) {
        let (paths: felt*) = alloc();
        paths[0] = base_token;
        paths[1] = collateral_token;

        let (quote_amount) = Il0kRouter.getAmountsIn(
            contract_address=router_addr, base_amount, 2, paths
        );

        return quote_amount;
    } else {
        let (paths: felt*) = alloc();
        paths[0] = base_token;
        paths[1] = collateral_token;

        let (quote_amount) = Il0kRouter.getAmountsOut(
            contract_address=router_addr, base_amount, 2, paths
        );

        return quote_amount;
    }
}

func get_average_entry_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    prev_size: felt, entry_price: felt, added_size: felt, added_entry_price: felt
) -> felt {
    let prev_entry_nominal = prev_size * entry_price;
    let added_entry_nominal = added_size * added_entry_price;

    let average_entry_price = unsigned_div_rem(
        prev_entry_nominal + added_entry_nominal, prev_size + added_size
    );

    return average_entry_price;
}

func get_position_effect_type{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    prev_position: PositionInfo, swap_params: SwapParams
) -> (effect_type: felt) {
    if (prev_position.position_size == 0) {
        return OPEN;
    }

    if (prev_position.is_long == swap_params.is_long) {
        return INCREASE;
    } else {
        if (prev_position.position_size == swap_params.amount) {
            // TODO: Account for dust amount
            return CLOSE;
        } else {
            let cond = is_lt(swap_params.amount, prev_position.position_size);

            if (cond == TRUE) {
                return DECREASE;
            } else {
                return FLIP_DIRECTION;
            }
        }
    }
}


// HELPER HELPERS =========================================

func _get_estimated_new_nominal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    nominal_value: felt, position_size: felt, swap_params: felt, position_effect_type: felt
) -> felt {
    if (position_effect_type == OPEN) {
        return _increase_nominal(nominal_value, swap_params);
    }
    if (position_effect_type == INCREASE) {
        return _increase_nominal(nominal_value, swap_params);
    }
    if (position_effect_type == DECREASE) {
        return _decrease_nominal(nominal_value, swap_params);
    }
    if (position_effect_type == CLOSE) {
        return _decrease_nominal(nominal_value, swap_params);
    }
    if (position_effect_type == FLIP_DIRECTION) {
        return _flip_side(nominal_value, position_size, swap_params);
    }

    return 0;
}

func _increase_nominal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    nominal_value: felt, swap_params: SwapParams
) -> felt {
    let expected_quote_amount = get_estimated_quote_amount(
        base_amount=swap_params.amount, base_token=swap_params.baseToken, is_long=swap_params.isLong
    );

    return nominal_value + expected_quote_amount;
}

func _decrease_nominal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    nominal_value: felt, swap_params: SwapParams
) -> felt {
    let expected_quote_amount = get_estimated_quote_amount(
        base_amount=swap_params.amount, base_token=swap_params.baseToken, is_long=swap_params.isLong
    );

    return nominal_value - expected_quote_amount;
}

func _flip_side{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    nominal_value: felt, position_size: felt, swap_params: SwapParams
) -> felt {
    let expected_quote_amount = get_estimated_quote_amount(
        base_amount=swap_params.amount, base_token=swap_params.baseToken, is_long=swap_params.isLong
    );

    let price = calculate_price_from_quote(
        swap_params.baseToken, swap_params.amount, expected_quote_amount
    );

    let cond = is_lt(swap_params.amount, 2 * position_size);

    if (cond == TRUE) {
        let size_diff = 2 * position_size - swap_params.amount;
        let nominal_value_diff = size_diff * price;
        return nominal_value - nominal_value_diff;
    } else {
        let size_diff = swap_params.amount - 2 * position_size;
        let nominal_value_diff = size_diff * price;
        return nominal_value + nominal_value_diff;
    }
}

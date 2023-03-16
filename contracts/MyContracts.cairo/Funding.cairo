from openzeppelin.token.erc20.IERC20 import IERC20

from starkware.cairo.common.math import (
    assert_not_zero,
    assert_le,
    assert_lt,
    unsigned_div_rem,
    split_felt,
)

// STORAGE ==============================================

const FUNNDING_INTRVAL = 1440;

@storage_var
func running_funding_sum_s(base_token: felt) -> (res: felt) {
}
@storage_var
func running_funding_count_s(base_token: felt) -> (res: felt) {
}
@storage_var
func latest_tx_timestamp(base_token: felt) -> (res: felt) {
}
@storage_var
func fundings_s(base_token: felt, idx: felt) -> (res: felt) {
}
@storage_var
func current_funding_index_s(base_token: felt) -> (res: felt) {
}
@storage_var
func impact_notional_value_s(base_token: felt) -> (res: felt) {
}

// EXTERNAL ============================================

@external
func make_funding_update{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    arguments
) {
    let running_funding_count = running_funding_count_s.read();

    let timestamp = get_block_timestamp();
    let last_timestamp = latest_tx_timestamp.read(base_token);

    let (time_diff: felt, _) = unsigned_div_rem(timestamp - last_timestamp, 60);

    let cond = is_le(FUNNDING_INTRVAL, running_funding_count + time_diff);

    let impact_price = get_impact_price(base_token);

    // TODO: What if there was an entire interval in between?
    if (cond == TRUE) {
        // 24 hours have passed, we can update the funding

        let running_funding_count_update = time_diff * avg_impact_price;
        let running_funding_sum = running_funding_sum_s.read(base_token);

        let final_funding_sum = running_funding_sum + running_funding_count_update;
        let count = running_funding_count_s.read(baser_token);

        let (twap_mark_price, _) = unsigned_div_rem(final_funding_sum, count);
        // let (twap_index_price, _) = ... STORK

        let twap_diff = twap_mark_price - twap_index_price;
        let (funding_rate: felt, _) = unsigned_div_rem(twap_diff * 100000, twap_index_price);  // 5 decimals -> 1000 = 0.1%

        let current_funding_index = current_funding_index_s.read(base_token);
        fundings_s.write(base_token, current_funding_index, funding_rate);
        current_funding_index_s.write(base_token, current_funding_index + 1);

        running_funding_sum_s.write(base_token, 0);
        running_funding_count_s.write(baser_token, 0);

        let new_diff = FUNNDING_INTRVAL - running_funding_count;

        make_funding_update(base_token, time_diff, impact_price);
    } else {
        // 24 hours have not passed, we can't update the funding yet

        make_funding_update(base_token, time_diff, impact_price);
    }
}

func get_impact_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    base_token: felt
) -> felt {
    let impact_notional = impact_notional_value_s.read(base_token);

    let (impact_bid_price: felt) = get_estimated_quote_amount(impact_notional, base_token, TRUE);
    let (impact_ask_price: felt) = get_estimated_quote_amount(impact_notional, base_token, FALSE);

    let (avg_impact_price: felt, _) = unsigned_div_rem(impact_bid_price + impact_ask_price, 2);

    return avg_impact_price;
}

func make_funding_update{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    base_token: felt, time_diff: felt, avg_impact_price: felt
) {
    if (time_diff == 0) {
        return ();
    }

    let running_funding_count_update = time_diff * avg_impact_price;

    let running_funding_sum = running_funding_sum_s.read(base_token);

    running_funding_sum_s.write(base_token, running_funding_sum + running_funding_count_update);
    let count = running_funding_count_s.read(baser_token);
    running_funding_count_s.write(baser_token, count + time_diff);

    return ();
}

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
func decimals_s() -> (res: felt) {
}
@storage_var
func settlement_token_s() -> (res: felt) {
}
@storage_var
func clearing_house_config_s() -> (res: felt) {
}
@storage_var
func account_balance_s() -> (res: felt) {
}
@storage_var
func insurance_fund_s() -> (res: felt) {
}
@storage_var
func exchange_s() -> (res: felt) {
}
@storage_var
func clearing_house_s() -> (res: felt) {
}
@storage_var
func total_debt_s() -> (res: felt) {
}
@storage_var
func balance_s(trader: felt, token_adde: felt) -> (res: felt) {
}
@storage_var
func collateral_manager_s() -> (res: felt) {
}
@storage_var
func collateral_tokens_s(trader: felt) -> (res: felt) {
}

// CONSTRUCTOR ============================================
@constructor
func constructor(
    insurance_fund_addr: felt,
    clearing_house_config_addr: felt,
    account_balance_addr: felt,
    exchange_addr: felt,
) {
    // address settlementTokenArg = IInsuranceFund(insuranceFundArg).getToken();
    //     uint8 decimalsArg = IERC20Metadata(settlementTokenArg).decimals();

    // __ReentrancyGuard_init();
    // __OwnerPausable_init();

    // decimals_s.write(decimalsArg);
    // settlement_token_s.write(settlementTokenArg);

    insurance_fund_s.write(insurance_fund_addr);
    clearing_house_config_s.write(clearing_house_config_addr);
    account_balance_s.write(account_balance_addr);
    exchange_s.write(exchange_addr);
}

// EXTERNAL ===============================================

// HELPERS ================================================

func get_settlement_token_value{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    trader: felt
) {
    return ();
}

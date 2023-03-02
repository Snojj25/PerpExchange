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
@storage_var
func account_registry_s() -> (res: felt) {
}
@storage_var
func balance_s(trader: felt) -> (res: Uint256) {
}

// CONSTRUCTOR ============================================
@constructor
func constructor(account_registry_addr: felt) {
    account_registry_s.write(account_registry_addr);

    // todo: Give unlimited allowance to the router so that it can swap tokens
}

// EXTERNAL ===============================================
@external
func increase_user_collateral_balance{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(trader: felt, amount: Uint256) {
    let old_balance = balance_s.read(trader);
    let new_balance = uint256_add(old_balance, amount);
    balance_s.write(trader, value=new_balance);

    return ();
}

@external
func decrease_collateral_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    trader: felt, amount: Uint256
) -> (res: Uint256) {
    let balance = balance_s.read(trader);
    let new_balance = uint256_sub(balance, amount);
    balance_s.write(trader, value=new_balance);

    return (res=balance);
}

// VIEW ==================================================
@view
func get_user_collateral_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    trader: felt
) -> (res: Uint256) {
    let balance = balance_s.read(trader);
    return (res=balance);
}

from starkware.starknet.common.syscalls import get_caller_address

from contracts.param_structs import AddLiquidityParams
from contracts.interfaces.IBaseToken import IBaseToken
from contracts.interfaces.IAccountBalance import IAccountBalance

// STORAGE ==============================================
// address internal _quoteToken;
// address internal _uniswapV3Factory;
@storage_var
func _clearing_house_config() -> (address: felt) {
}
@storage_var
func _vault() -> (address: felt) {
}
@storage_var
func _exchange() -> (address: felt) {
}
@storage_var
func _order_book() -> (address: felt) {
}
@storage_var
func _account_balance() -> (address: felt) {
}
@storage_var
func _insurance_fund() -> (address: felt) {
}

// CONSTRUCTOR ============================================

@constructor
func constructor(
    clearing_house_config_addr: felt,
    order_book_addr: felt,
    vault_addr: felt,
    quote_token_addr: felt,
    exchange_addr: felt,
    account_balance_addr: felt,
    insurance_fund_addr: felt,
) -> () {
    assert_not_zero(clearing_house_config_addr);
    assert_not_zero(order_book_addr);
    assert_not_zero(vault_addr);
    assert_not_zero(quote_token_addr);
    assert_not_zero(exchange_addr);
    assert_not_zero(account_balance_addr);
    assert_not_zero(insurance_fund_addr);

    // address orderBookArg = IExchange(exchangeArg).getOrderBook();
    // __ReentrancyGuard_init();
    // __OwnerPausable_init();

    _clearing_house_config.write(clearing_house_config_addr);
    _order_book.write(order_book_addr);
    _vault.write(vault_addr);
    _quote_token.write(quote_token_addr);
    _exchange.write(exchange_addr);
    _account_balance.write(account_balance_addr);
    _insurance_fund.write(insurance_fund_addr);
}

// EXTERNAL ===============================================

@external
func add_liquidity{pedersen_ptr: HashBuiltin*}(add_liq_params: AddLiquidityParams) -> () {
    alloc_locals;

    // _checkMarketOpen(params.baseToken);

    let is_open = IBaseToken.is_open(contract_address=add_liq_params.base_token);
    with_attr error_message("==== CH: market is not open ====") {
        assert is_open = 1;
    }

    // require(!IExchange(_exchange).isOverPriceSpread(params.baseToken), "CH_OMPS");

    // require(!params.useTakerBalance, "CH_DUTB");

    let trader = get_caller_address();

    let account_balance_addr = _account_balance.read();
    IAccountBalance.register_base_token(
        contract_address=account_balance_addr, trader=trader, base_token=add_liq_params.base_token
    );
}

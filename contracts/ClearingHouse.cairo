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
@storage_var
func router_addr_s() -> (address: felt) {
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
    let account_balance_addr = _account_balance.read();
    IAccountBalance.register_base_token(
        contract_address=account_balance_addr, trader=trader, base_token=swap_params.baseToken
    );

    let quote_amount = get_estimated_quote_amount(
        base_amount=swap_params.amount, base_token=swap_params.baseToken, is_long=swap_params.isLong
    );
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

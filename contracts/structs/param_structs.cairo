from starkware.cairo.common.uint256 import Uint256

struct AddLiquidityParams {
    tokenA: felt,  // base token
    tokenB: felt,  // quote token
    tokenADesired: Uint256,
    amountBDesired: Uint256,
    tokenAMin: Uint256,
    amountBMin: Uint256,
    deadline: felt,
}

struct RemoveLiquidityParams {
    tokenA: felt,  // base token
    tokenB: felt,  // quote token
    liquidity: Uint256,
    amountAMin: Uint256,
    amountBMin: Uint256,
    deadline: felt,
}

struct SwapParams {
    baseToken: felt,  // Token being traded
    amount: felt,  // Amount of baseToken to trade  // 10 ** base_decimals
    worst_price: felt,  // Worst price to accept
    is_long: felt,  // True if long, False if short
    deadline: felt,  // Time after which the transaction will be rejected
}

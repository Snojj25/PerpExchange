from starkware.cairo.common.uint256 import Uint256

struct AddLiquidityParams {
    tokenA: felt,  // base token
    tokenB: felt,  // quote token
    tokenADesired: Uint256,
    amountBDesired: Uint256,
    tokenAMin: Uint256,
    amountBMin: Uint256,
    to: felt,
    deadline: felt,
}

struct RemoveLiquidityParams {
    tokenA: felt,  // base token
    tokenB: felt,  // quote token
    liquidity: Uint256,
    amountAMin: Uint256,
    amountBMin: Uint256,
    to: felt,
    deadline: felt,
}

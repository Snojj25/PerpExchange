struct PositionInfo {
    position_size: felt,
    entry_price: felt,
    last_funding_index: felt,
    is_long: felt,
}

// POSITION EFFECT TYPES
const OPEN = 0;
const INCREASE = 1;
const DECREASE = 2;
const FLIP_DIRECTION = 3;
const CLOSE = 4;

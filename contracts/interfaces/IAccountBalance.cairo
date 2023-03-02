@contract_interface
namespace IAccountBalance {
    func set_vault(vault_addr: felt) -> () {
    }

    func register_base_token(trader: felt, base_token: felt) -> () {
    }

    func modify_owed_realized_pnl(trader: felt, amount: felt) -> () {
    }

    func get_base_tokens(trader: felt) -> (base_tokens_len: felt, base_tokens: felt*) {
    }
}

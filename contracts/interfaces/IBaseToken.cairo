@contract_interface
namespace IBaseToken {
    func close() -> () {
    }

    func is_open() -> (bool: felt) {
    }

    func is_paused() -> (bool: felt) {
    }

    func is_closed() -> (bool: felt) {
    }
}

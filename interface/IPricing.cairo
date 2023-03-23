%lang starknet
from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IPricing {
    func compute_buy_price(domain: felt, years: felt, total_supply : felt) -> (erc20: felt, price: felt) {
    }
}

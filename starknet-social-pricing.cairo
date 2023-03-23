%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_unsigned_div_rem
from starkware.cairo.common.math import assert_le, split_felt
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.math_cmp import is_le

@storage_var
func payment_token() -> (erc20_address: felt) {
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    erc20_address: felt
) {
    payment_token.write(erc20_address);
    return ();
}

@view
func return_payment_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (res: felt) {
    let addr : felt = payment_token.read();
    return (addr,);
}

@view
func compute_buy_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    domain : felt, years : felt, total_supply : felt 
) -> (payment_token: felt, price: felt) {
    alloc_locals;

    // Calculate price depending on number of characters
    let (high, low) = split_felt(domain);
    let number_of_character = get_amount_of_chars(Uint256(low, high));
    //-1 for exention type
    let cost : felt = get_cost(number_of_character, years, total_supply);
    let (erc20_address) = payment_token.read();

    return (erc20_address, cost);
}

func get_amount_of_chars{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    domain: Uint256
) -> felt {
    alloc_locals;
    if (domain.low == 0 and domain.high == 0) {
        return (0);
    }
    // 38 = simple_alphabet_size
    let (local p, q) = uint256_unsigned_div_rem(domain, Uint256(38, 0));
    if (q.high == 0 and q.low == 37) {
        // 3 = complex_alphabet_size
        let (shifted_p, _) = uint256_unsigned_div_rem(p, Uint256(2, 0));
        let next = get_amount_of_chars(shifted_p);
        return 1 + next;
    }
    let next = get_amount_of_chars(p);
    return 1 + next;
}


func get_cost{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    number_of_character, years, total_supply
) -> felt {
    let base_price : felt = 2910000000000000;
    let is_more_than_five_years : felt = is_le(6, years);
    let is_less_than_ten_years : felt = is_le(years, 10);
    let is_total_supply_less_than_10_k : felt = is_le(total_supply, 10000);
    let condition : felt = is_more_than_five_years + is_less_than_ten_years + is_total_supply_less_than_10_k;


    if (number_of_character == 1) {
        let cost : felt = 93120000000000000 * years;

        if(condition == 3){
            return 93120000000000000 * 5;
        }else{
            return cost;
        } 
    }
    if (number_of_character == 2) {
        let cost : felt = 46560000000000000 * years;
        if(condition == 3){
            return 46560000000000000 * 5;
        }else{
            return cost;
        } 
    }
    if (number_of_character == 3) {
        let cost : felt = 23280000000000000 * years;
        if(condition == 3){
            return 23280000000000000 * 5;
        }else{
            return cost;
        } 
    }
    if (number_of_character == 4) {
        let cost : felt = 11640000000000000 * years;
        if(condition == 3){
            return 11640000000000000 * 5;
        }else{
            return cost;
        }  
    }

    if(condition == 3){
        return base_price + (base_price * 5);
    }else{
        let cost : felt = base_price + (base_price * years);
        return cost;
    } 
}
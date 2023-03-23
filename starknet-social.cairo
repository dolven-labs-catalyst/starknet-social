%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address,
    get_block_number,
    get_block_timestamp,
)
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import (
    assert_not_zero,
    assert_not_equal,
    assert_nn_le,
    split_felt,
    assert_lt_felt,
    assert_le_felt,
    assert_le,
    unsigned_div_rem,
    signed_div_rem,
)
from starkware.cairo.common.uint256 import Uint256, uint256_eq, uint256_le, uint256_lt, assert_uint256_le, uint256_mul, uint256_add
from starkware.cairo.common.math_cmp import is_le, is_not_zero, is_nn, is_in_range, is_nn_le
from contracts.openzeppelin.token.ERC20.interfaces.IERC20 import IERC20
from contracts.openzeppelin.access.ownable import Ownable
from contracts.openzeppelin.security.pausable import Pausable
from contracts.openzeppelin.security.reentrancy_guard import ReentrancyGuard
from contracts.openzeppelin.token.erc721.enumerable.library import ERC721Enumerable
from contracts.openzeppelin.token.erc721.library import ERC721
from contracts.openzeppelin.introspection.erc165.library import ERC165
from contracts.CairoLibDomain.cairoLibMetadata import (
    ERC721_Metadata_initializer,
    ERC721_Metadata_tokenURI,
    ERC721_Metadata_setBaseTokenURI,
)
from contracts.CairoLibDomain.interface.IPricing import IPricing

struct DomainDetails {
    handler: felt,
    resolver: felt,
    token_id : felt,
    expiry_date : felt,
    last_transfer_time : felt,
    user_icon : felt,
}

@storage_var
func token_id_to_domain(token_id : felt) -> (domain_data : DomainDetails) {
}

@storage_var
func domain_to_details(domain : felt) -> (domain_data : DomainDetails) {
}

@storage_var
func is_domain_registered(domain : felt) -> (res : felt) {
}

@storage_var
func fee_address() -> (address : felt) {
}

@storage_var
func pricing_address() -> (address : felt) {
}


@event
func domain_updated(token_id : Uint256, domain : felt, old_address : felt, new_address : felt, time : felt) {
}

@event
func new_domain_registered(token_id : Uint256, domain : felt, registerer : felt, expiry_date : felt, time: felt, icon : felt) {
}

@event
func domain_renewed(token_id : Uint256, domain : felt, registerer : felt, expiry_date : felt, time : felt, icon : felt) {
}



@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    manager : felt, pricing_contract : felt
) {
    pricing_address.write(pricing_contract);
    Ownable.initializer(manager);
    ERC721.initializer('CairoDomain', 'CID');
    ERC721Enumerable.initializer();
    ERC721_Metadata_initializer();
    return();
}

// viewers

@view
func return_pricing_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (res : felt) {
    let addr : felt = pricing_address.read();
    return (addr,);
}

@view
func return_is_domain_registered{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
     _domains_len : felt, _domains : felt*
) -> (domains_len : felt, domains : felt*) {
    let (domains_len : felt, domains : felt*) = return_available_domains(_domains, _domains_len);

    return (domains_len, domains);
}


func return_available_domains{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    domains : felt*, domains_len : felt
) -> (domain_res_len : felt, domain_res : felt*) {
    alloc_locals;

    if(domains_len == 0){
        let (available_domains : felt*) = alloc();
        return(0, available_domains);
    }

    let next_arr_len : felt = domains_len - 1;
    let domain : felt = domains[next_arr_len];
    let _is_domain_registered : felt = is_domain_registered.read(domain);
    let (domain_res_len : felt, domain_res : felt*) = return_available_domains(domains, domains_len - 1); 

    if(_is_domain_registered == FALSE){
        assert domain_res[domain_res_len] = domain;
        return (domain_res_len + 1, domain_res);
    }else{
        return (domain_res_len, domain_res);
    }
}

@view
func return_fee_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (res : felt) {
    let addr : felt = fee_address.read();
    return (addr,);
}

@view
func totalSupply{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}() -> (
    totalSupply: Uint256
) {
    let (totalSupply: Uint256) = ERC721Enumerable.total_supply();
    return (totalSupply,);
}

@view
func tokenByIndex{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    index: Uint256
) -> (tokenId: Uint256) {
    let (tokenId: Uint256) = ERC721Enumerable.token_by_index(index);
    return (tokenId,);
}

@view
func domain_byTokenId{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    token_id : felt
) -> (res: DomainDetails ) {
    let (domain) = token_id_to_domain.read(token_id);
    return (domain,);
}

@view
func tokenOfOwnerByIndex{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    owner: felt, index: Uint256
) -> (tokenId: Uint256) {
    let (tokenId: Uint256) = ERC721Enumerable.token_of_owner_by_index(owner, index);
    return (tokenId,);
}


@view
func supportsInterface{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    interfaceId: felt
) -> (success: felt) {
    let (success) = ERC165.supports_interface(interfaceId);
    return (success,);
}

@view
func name{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (name: felt) {
    let (name) = ERC721.name();
    return (name,);
}

@view
func returnDetailsbyDomain{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    domain : felt
) -> (res: DomainDetails){
    let (details) = domain_to_details.read(domain);
    return (details,);
}

@view
func symbol{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (symbol: felt) {
    let (symbol) = ERC721.symbol();
    return (symbol,);
}

@view
func balanceOf{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(owner: felt) -> (
    balance: Uint256
) {
    let (balance: Uint256) = ERC721.balance_of(owner);
    return (balance,);
}

@view
func ownerOf{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tokenId: Uint256) -> (
    owner: felt
) {
    let (owner: felt) = ERC721.owner_of(tokenId);
    return (owner,);
}

@view
func getApproved{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    tokenId: Uint256
) -> (approved: felt) {
    let (approved: felt) = ERC721.get_approved(tokenId);
    return (approved,);
}

@view
func isApprovedForAll{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, operator: felt
) -> (isApproved: felt) {
    let (isApproved: felt) = ERC721.is_approved_for_all(owner, operator);
    return (isApproved,);
}


@view
func tokenURI{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_id: Uint256
) -> (token_uri_len: felt, token_uri: felt*) {
    let (token_uri_len, token_uri) = ERC721_Metadata_tokenURI(token_id);
    return (token_uri_len=token_uri_len, token_uri=token_uri);
}


@view
func owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (owner: felt) {
    let (owner: felt) = Ownable.owner();
    return (owner,);
}


@view
func returnAllTokensOfUser{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt
) -> (tokens_len : felt, tokens : felt*) {
    alloc_locals;
    let (user_balance : Uint256) = balanceOf(user_address);
    let balance_as_felt : felt = uint256_to_felt(user_balance);
    let (tokens_len : felt, tokens : felt*) = recursive_tokens(user_address, 0, balance_as_felt);
    return(tokens_len, tokens - tokens_len);
}

func recursive_tokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user_address : felt, index : felt, loop_size : felt
) -> (tokens_len : felt, tokens : felt*){
    alloc_locals;
   

    if(loop_size == index){
        let (found_tokens: felt*) = alloc();
        return (0, found_tokens,);
    }
    
    let uint_index : Uint256 = felt_to_uint256(index);
    let (userToken : Uint256) = tokenOfOwnerByIndex(user_address, uint_index);
    let felt_token_id : felt = uint256_to_felt(userToken); 

    let (tokens_len, token_location: felt*) = recursive_tokens(user_address, index + 1, loop_size);
    assert [token_location] = felt_token_id;
    return (tokens_len + 1, token_location + 1,);
}

@view
func user_domains{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt
) -> (domains_len : felt, domains : DomainDetails*) {
    let (tokens_len, tokens) = returnAllTokensOfUser(user_address);
    let (domains_len, domains) = recursive_user_domains(tokens, tokens_len, 0);
    return (domains_len, domains - domains_len * DomainDetails.SIZE);
}

func recursive_user_domains{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_ids : felt*, limit : felt, index : felt
) -> (domains_len : felt, domains : DomainDetails*) {
    alloc_locals;
    if(limit == index){
        let (found_domains : DomainDetails*) = alloc();
        return(0, found_domains);
    }
    
    let (domain_data : DomainDetails) = token_id_to_domain.read(token_ids[index]);
    let (domains_memory_len, domains_memory) = recursive_user_domains(token_ids, limit, index +1);
    assert [domains_memory] = domain_data;
    return (domains_memory_len + 1, domains_memory + DomainDetails.SIZE);
}

@view
func _isPaused{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (res: felt) {
    let (status) = Pausable.is_paused();
    return (status,);
}

// externals


@external
func switchContract{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    Ownable.assert_only_owner();
    let _isContractPaused : felt = _isPaused();
    if(_isContractPaused == TRUE){
        Pausable._pause();
        return();
    }else{
        Pausable._unpause();
        return();
    }
}

// CAIRO LIB SPECIFIC START


@external
func register_domain{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    domain: felt, years : felt, resolver : felt, _user_icon : felt, without_ext : felt
) {
    alloc_locals;
    Pausable.assert_not_paused();
    ReentrancyGuard._start();
    let (msg_sender) = get_caller_address(); 
    let is_domain_available : felt = is_domain_registered.read(domain);
    with_attr error_message("CairoLib::Domain is not available") {
        assert is_domain_available = FALSE;
    }
    let (time) = get_block_timestamp(); 
    let is_less_than_1_year : felt = is_le(1, years);

    with_attr error_message("CairoLib::cannot register less than 1 year") {
        assert is_less_than_1_year = TRUE;  
    }

    let expiry : felt = time + 31556926 * years;
    with_attr error_message("CairoLib::cannot register for more than 25 years") {
        assert_le_felt(expiry, time + 31556926 * 25);  // 25*365
    }
    let (supply: Uint256) = ERC721Enumerable.total_supply();
    let new_supply_as_felt : felt = uint256_to_felt(supply);
    let domainData : DomainDetails = DomainDetails(domain, resolver, new_supply_as_felt, expiry, time, _user_icon);
    pay_buy_domain(years,msg_sender,without_ext, 0);
    
    token_id_to_domain.write(new_supply_as_felt, domainData);
    domain_to_details.write(domain, domainData);
    is_domain_registered.write(domain, TRUE);

    new_domain_registered.emit(supply, domain, resolver, expiry, time, _user_icon);
    ERC721Enumerable._mint(resolver, supply);
    ReentrancyGuard._end();
    
    return();
}


@external
func renew_domain{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    domain : felt, years : felt, without_ext : felt
) {
    alloc_locals;
    Pausable.assert_not_paused();
    ReentrancyGuard._start();
    let (msg_sender) = get_caller_address(); 
    let (domain_details) = domain_to_details.read(domain);
    with_attr error_message("CairoLib::only domain owner"){
        assert domain_details.resolver = msg_sender;
    }
    
    let (time) = get_block_timestamp(); 
    let is_less_than_1_year : felt = is_le(1, years);

    with_attr error_message("CairoLib::cannot register less than 1 year") {
        assert is_less_than_1_year = TRUE;  
    }

    let expiry : felt = time + 31556926 * years;
    with_attr error_message("CairoLib::cannot register for more than 25 years") {
        assert_le_felt(expiry, time + 31556926 * 25);  // 25*365
    }
    
    let domain_as_uint : Uint256 = felt_to_uint256(domain_details.token_id);
    let domainData : DomainDetails = DomainDetails(domain, domain_details.resolver, domain_details.token_id, expiry, domain_details.last_transfer_time, domain_details.user_icon);
    pay_buy_domain(years,msg_sender, without_ext, 1);
    
    token_id_to_domain.write(domain_details.token_id, domainData);
    domain_to_details.write(domain, domainData);
    is_domain_registered.write(domain, TRUE);

    domain_renewed.emit(domain_as_uint, domain, msg_sender, expiry, time, domain_details.user_icon);
    ReentrancyGuard._end();
    return();
}



func pay_buy_domain{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
     years, caller, domain, mode
) -> () {
    alloc_locals;
    let (_fee_address) = fee_address.read();
    let (pricing_contract) = pricing_address.read();
    let (supply) = totalSupply();
    let _supply_as_felt : felt = uint256_to_felt(supply);
    let (erc20, price) = IPricing.compute_buy_price(pricing_contract, domain, years, _supply_as_felt);
    if(mode == 0){
        //first registration
        let cost : Uint256 = felt_to_uint256(price);
        let (success) = IERC20.transferFrom(erc20, caller, _fee_address, cost);
        with_attr error_message("CairoLib::payment failed") {
            assert success = TRUE;
        }

    }else{
        //renew
        let cost : Uint256 = felt_to_uint256(price * 125 / 100);
        let (success) = IERC20.transferFrom(erc20, caller, _fee_address, cost);
        with_attr error_message("CairoLib::payment failed") {
            assert success = TRUE;
        }
    }
   
    return ();
}


//CAIROLIB SPECIFIC END


@external
func approve{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    to: felt, tokenId: Uint256
) {
    ERC721.approve(to, tokenId);
    return ();
}

@external
func setApprovalForAll{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    operator: felt, approved: felt
) {
    ERC721.set_approval_for_all(operator, approved);
    return ();
}

@external
func transferFrom{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    from_: felt, to: felt, tokenId: Uint256
) {
    let token_id_as_felt : felt = uint256_to_felt(tokenId);
    let old_domain_details : DomainDetails = token_id_to_domain.read(token_id_as_felt); 
    let (now) = get_block_timestamp();
    let new_domain_data : DomainDetails = DomainDetails(old_domain_details.handler, to, token_id_as_felt, old_domain_details.expiry_date, now, old_domain_details.user_icon);
    
    domain_to_details.write(old_domain_details.handler, new_domain_data);
    token_id_to_domain.write(token_id_as_felt, new_domain_data);

    let (now) = get_block_timestamp();
    domain_updated.emit(tokenId, old_domain_details.handler, from_, to, now);
    ERC721Enumerable.transfer_from(from_, to, tokenId);
    return ();
}

@external
func safeTransferFrom{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    from_: felt, to: felt, tokenId: Uint256, data_len: felt, data: felt*
) {
    let token_id_as_felt : felt = uint256_to_felt(tokenId);
    let old_domain_details : DomainDetails = token_id_to_domain.read(token_id_as_felt); 
    let (now) = get_block_timestamp();
    let new_domain_data : DomainDetails = DomainDetails(old_domain_details.handler, to, token_id_as_felt, old_domain_details.expiry_date, now, old_domain_details.user_icon);
    
    domain_to_details.write(old_domain_details.handler, new_domain_data);
    token_id_to_domain.write(token_id_as_felt, new_domain_data);
    let (now) = get_block_timestamp();

    domain_updated.emit(tokenId, old_domain_details.handler, from_, to, now);
    ERC721Enumerable.safe_transfer_from(from_, to, tokenId, data_len, data);
    return ();
}


@external
func burn{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(tokenId: Uint256) {
    ERC721.assert_only_token_owner(tokenId);
    ERC721Enumerable._burn(tokenId);
    return ();
}


@external
func setTokenURI{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    base_token_uri_len: felt, base_token_uri: felt*, token_uri_suffix: felt
) {
    Ownable.assert_only_owner();
    ERC721_Metadata_setBaseTokenURI(base_token_uri_len, base_token_uri, token_uri_suffix);
    return ();
}

@external
func setFeeAddress{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_address : felt
) {
    Ownable.assert_only_owner();
    fee_address.write(new_address);
    return ();
}

@external
func setPricingContract{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_address : felt
) {
    Ownable.assert_only_owner();
    pricing_address.write(new_address);
    return ();
}

@external
func transferOwnership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    newOwner: felt
) {
    Ownable.transfer_ownership(newOwner);
    return ();
}

@external
func renounceOwnership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    Ownable.renounce_ownership();
    return ();
}


//Internals


func felt_to_uint256{range_check_ptr}(x) -> (uint_x: Uint256) {
    let (high, low) = split_felt(x);
    return (Uint256(low=low, high=high),);
}

func uint256_to_felt{range_check_ptr}(value: Uint256) -> (value: felt) {
    assert_lt_felt(value.high, 2 ** 123);
    return (value.high * (2 ** 128) + value.low,);
}
module addr::bid {
    use std::signer;
    use std::string::String;
    use std::vector;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_framework::timestamp;

    // ERRORS
    const BID_AMOUNT_IS_SMALLER_THAN_INITIAL_AMOUNT: u64 = 5;
    const BID_AMOUNT_IS_SMALLER_THAN_PREVIOUS_AMOUNT: u64 = 6;
    const ACTION_IS_ACTIVE: u64 = 8;
    const ACTION_IS_NOT_ACTIVE: u64 = 4;
    const TIME_IS_NOT_VALID: u64 = 2;
    const USER_NOT_FOUND: u64 = 0;

    struct Bid has key, store {
        amount: u64,
        bidder: address,
    }

    struct Auction has key {
        token_id: String,
        auction_admin: address,
        initial_amount: u64,
        bids: vector<Bid>,
        end_time: u64,
    }

    #[event]
    struct AuctionEvent has drop, store {
        token_id: String,
        auction_admin: address,
        initial_amount: u64,
        end_time: u64,
    }

    #[event]
    struct BidEvent has drop, store {
        amount: u64,
        bidder: address,
        new_bid: bool,
    }

    #[event]
    struct ClaimEvent has drop, store {
        amount: u64,
        is_winner: bool,
    }

    public entry fun create_auction(
        account: &signer,
        initial_amount: u64,
        token_id: String,
        end_time: u64
    ) {
        let current_time = timestamp::now_microseconds();

        assert!(current_time >= end_time, TIME_IS_NOT_VALID);
        let auction_admin = signer::address_of(account);
        // TODO: HAVE TO CHECK THAT USER HAS TOKEN_ID IN HIS ASSETS
        let bids = vector::empty<Bid>();

        let auction = Auction {
            token_id,
            initial_amount,
            auction_admin,
            bids,
            end_time
        };

        move_to(account, auction);
        event::emit(AuctionEvent {
            token_id,
            initial_amount,
            auction_admin,
            end_time
        })
    }

    public entry fun create_bid(
        account: &signer,
        admin_address: address,
        amount: u64
    ) acquires Auction {
        let new_bid = false;

        let bidder = signer::address_of(account);
        let auction = borrow_global_mut<Auction>(admin_address);
        let current_time = timestamp::now_microseconds();

        assert!(current_time >= auction.end_time, ACTION_IS_NOT_ACTIVE);
        assert!(amount <= auction.initial_amount, BID_AMOUNT_IS_SMALLER_THAN_INITIAL_AMOUNT);

        let _payable_amount = 0;

        let max_bid_index = find_last_bid_index(
            &mut auction.bids,
            bidder
        );

        let bid = Bid {
            amount,
            bidder,
        };
        let len = vector::length(&mut auction.bids);

        if(max_bid_index != len) {
            let previous_bid_amount = vector::borrow_mut(&mut auction.bids, max_bid_index).amount;
            assert!(previous_bid_amount >= amount, BID_AMOUNT_IS_SMALLER_THAN_PREVIOUS_AMOUNT);

            _payable_amount = amount - previous_bid_amount;
            new_bid = false;
        } else {
            _payable_amount = amount;
        };
        vector::push_back(&mut auction.bids, bid);

        if(_payable_amount > 0)
            coin::transfer<AptosCoin>(account, @addr, _payable_amount);

        event::emit(BidEvent {
            amount,
            bidder,
            new_bid
        })
    }

    entry fun claim_bid(account: &signer, admin_address: address) acquires Auction {
        let is_winner = false;
        let amount = 0;

        let account_addr = signer::address_of(account);
        let auction = borrow_global_mut<Auction>(admin_address);
        let current_time = timestamp::now_microseconds();
        let len = vector::length(&mut auction.bids);

        assert!(current_time <= auction.end_time, ACTION_IS_ACTIVE);

        let last_bid_index = find_last_bid_index(
            &mut auction.bids,
            account_addr
        );

        assert!(last_bid_index == len, USER_NOT_FOUND);

        let last_bid = vector::borrow_mut(&mut auction.bids, last_bid_index);

        let null_bid = Bid {
            amount: 0,
            bidder: account_addr
        };

        move_to(account, null_bid);

        if(len - 1 == last_bid_index) {
            is_winner = true;
            // TODO: TRANSFER_NFT
        }
        else {
            amount = last_bid.amount;
            // TODO: TRANSFER_TOKEN
        };

        event::emit(ClaimEvent{
            is_winner,
            amount
        })
    }

    fun find_last_bid_index(bids: &vector<Bid>, bidder: address): u64 {
        let len = vector::length(bids);
        let i = len;
        while (i > 0) {
            i = i - 1;
            if (vector::borrow(bids, i).bidder == bidder) {
                return i
            }
            else if(i == 0){
                return len
            }
        };
        0
    }
}
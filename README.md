# SubastaTP2
Ethereum smart contract for conducting secure and fair auctions.

# Auction Smart Contract

This smart contract implements a transparent and fair auction system on the Ethereum blockchain. It supports dynamic bidding, time extensions for last-minute bids, and automatic partial refunds to non-winning bidders with a small commission.

## 📦 Features

- Public bidding system with time-bound auctions.
- Automatic 10-minute extension if a bid is placed within the last 10 minutes.
- Refund of deposits (minus 2% commission) for non-winning bidders.
- Final transfer of funds to the contract owner after auction settlement.
- Fully viewable bid history and current highest bidder.

## ⚙️ Deployment

### Constructor

```solidity
constructor(uint256 _durationSeconds)
    _durationSeconds: Duration of the auction in seconds.

🧠 Functions
placeBid()
Places a new bid in the auction.
    Must send ETH.
    Must be at least 5% higher than the current highest bid (if any).
    May extend the auction time if called within the last 10 minutes.

getWinner()
Returns the address and amount of the highest bid.
    Callable only after the auction ends.

getBidOf(address _bidder)
Returns the last valid bid made by a specific address.
withdrawExcess()

Allows a bidder to withdraw excess ETH if they made multiple bids during the auction.
    Only available while the auction is active.

refundLosers()
Callable by the owner after the auction ends.
Refunds all non-winning bidders, minus a 2% commission.
    Emits AuctionFinalized.

withdrawContractFunds()
Callable by the owner after refundLosers() has been executed.
Transfers all remaining funds (winning bid + commissions) to the owner.

getAllBids()
Returns a list of all bids placed during the auction.

🔒 Access Control
    onlyOwner: Restricts functions to the contract deployer.
    auctionActive: Allows execution only before the auction ends.
    auctionEnded: Allows execution only after the auction ends.

📊 Events
    NewBid(address bidder, uint256 amount, uint256 newEndTime)
    AuctionFinalized(address winner, uint256 winningAmount)

📐 Bid Struct
struct Bid {
  address bidder;
  uint256 amount;
}

💡 Constants
    MIN_INCREMENT = 5 → Minimum 5% increase required for each new bid.
    COMMISSION = 2 → 2% commission deducted when refunding losers.
    EXTENSION_WINDOW = 10 minutes → Time window before end in which new bids extend the auction.
    EXTENSION_TIME = 10 minutes → Amount of time by which the auction is extended.

✅ Usage Example
    Deploy the contract with a duration (e.g., 1 hour).
    Users place bids using placeBid().
    After auction ends:
        Owner calls refundLosers().
        Then calls withdrawContractFunds() to collect proceeds.

Note: This contract is designed for educational or testnet purposes. Always audit smart contracts before deploying on mainnet.

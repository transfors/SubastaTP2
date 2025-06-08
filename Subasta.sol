// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Auction {
    // STATE VARIABLES

    address public owner;
    address public highestBidder;
    uint256 public highestBid;
    uint256 public start;
    uint256 public end;
    uint256 public duration;
    bool public finalized;
    uint256 public constant MIN_INCREMENT = 5; // 5%
    uint256 public constant COMMISSION = 2; // 2%
    uint256 public constant EXTENSION_WINDOW = 10 minutes;
    uint256 public constant EXTENSION_TIME = 10 minutes;

    /// @notice Structure representing a bid.
    /// @param bidder Address of the person who made the bid.
    /// @param amount Amount of the bid in wei.
    struct Bid {
        address bidder;
        uint256 amount;
    }

    Bid[] public bidHistory;

    mapping(address => uint256) public bids;
    mapping(address => uint256) public deposits;

    /// @notice Emitted when a new valid bid is placed.
    /// @param bidder Address of the bidder.
    /// @param amount Amount of the new bid.
    /// @param newEndTime New auction end time if extended.
    event NewBid(address indexed bidder, uint256 amount, uint256 newEndTime);

    /// @notice Emitted when the auction is finalized.
    /// @param winner Address of the winning bidder.
    /// @param winningAmount Amount of the winning bid.
    event AuctionFinalized(address winner, uint256 winningAmount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    modifier auctionActive() {
        require(block.timestamp < end, "The auction has ended");
        _;
    }

    modifier auctionEnded() {
        require(block.timestamp >= end, "The auction is still active");
        _;
    }

    /// @notice Initializes the auction with a fixed duration.
    /// @param _durationSeconds Duration of the auction in seconds.
    constructor(uint256 _durationSeconds) {
        owner = msg.sender;
        start = block.timestamp;
        duration = _durationSeconds;
        end = start + duration;
    }

    /// @notice Place a bid in the auction.
    /// @dev The bid must be at least 5% higher than the current highest bid.
    ///      If the bid is made within the last 10 minutes, the auction is extended.
    /// @custom:events Emits NewBid event.
    /// @custom:reverts If the value is zero or does not meet the minimum increment.
    function placeBid() external payable auctionActive {
        require(msg.value > 0, "You must send ETH to place a bid");

        if (highestBid > 0) {
            uint256 minimumBid = highestBid + (highestBid * MIN_INCREMENT) / 100;
            require(
                msg.value >= minimumBid,
                "The bid must be at least 5% higher than the current highest bid"
            );
        }

        bidHistory.push(Bid(msg.sender, msg.value));
        bids[msg.sender] = msg.value;
        deposits[msg.sender] += msg.value;

        highestBid = msg.value;
        highestBidder = msg.sender;

        if (end - block.timestamp <= EXTENSION_WINDOW) {
            end += EXTENSION_TIME;
        }

        emit NewBid(msg.sender, msg.value, end);
    }

    /// @notice View the auction winner and the winning amount.
    /// @dev Can only be called after the auction ends.
    /// @return The address of the highest bidder and their bid amount.
    function getWinner() external view auctionEnded returns (address, uint256) {
        return (highestBidder, highestBid);
    }

    /// @notice Returns the latest valid bid of a specific bidder.
    /// @param _bidder The address of the bidder to query.
    /// @return The amount of their last valid bid.
    function getBidOf(address _bidder) external view returns (uint256) {
        return bids[_bidder];
    }

    /// @notice Allows a bidder to withdraw excess ETH during the auction.
    /// @dev Excess = total deposits - latest valid bid.
    /// @custom:reverts If there is no excess to withdraw.
    function withdrawExcess() external auctionActive {
        uint256 deposited = deposits[msg.sender];
        uint256 bidAmount = bids[msg.sender];
        require(deposited > bidAmount, "No excess to withdraw");

        uint256 excess = deposited - bidAmount;
        deposits[msg.sender] = bidAmount;

        (bool success, ) = payable(msg.sender).call{value: excess}("");
        require(success, "Transfer failed");
    }

    /// @notice Refunds all non-winning bidders, minus a 2% commission.
    /// @dev Only callable by the owner after the auction ends.
    ///      Clears bidder state to prevent double refunds.
    /// @custom:events Emits AuctionFinalized event.
    /// @custom:reverts If already finalized or if transfer fails.
    function refundLosers() external onlyOwner auctionEnded {
        require(!finalized, "Refunds have already been processed");
        finalized = true;

        for (uint256 i = 0; i < bidHistory.length; i++) {
            address bidder = bidHistory[i].bidder;

            if (bidder != highestBidder && deposits[bidder] > 0) {
                uint256 amount = deposits[bidder];
                uint256 commission = (amount * COMMISSION) / 100;
                uint256 refund = amount - commission;

                deposits[bidder] = 0;
                bids[bidder] = 0;

                (bool success, ) = payable(bidder).call{value: refund}("");
                require(success, "Refund transfer failed");
            }
        }

        emit AuctionFinalized(highestBidder, highestBid);
    }

    /// @notice Allows the owner to withdraw the remaining funds (winning bid + commissions).
    /// @dev Can only be called after all refunds have been processed.
    /// @custom:reverts If auction hasn't been finalized or if balance is zero.
    function withdrawContractFunds() external onlyOwner {
        require(finalized, "Only after non-winning bids have been refunded");
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds available");

        (bool success, ) = payable(owner).call{value: balance}("");
        require(success, "Transfer to owner failed");
    }

    /// @notice Returns all bids made during the auction.
    /// @return Array of Bid structs containing bidder address and bid amount.
    function getAllBids() external view returns (Bid[] memory) {
        return bidHistory;
    }
}

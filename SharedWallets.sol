// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

// Single Contract Method: In the single contract version, we use a mapping to manage multiple wallets within a single contract. This approach allows us to handle multiple wallets with only a single contract deployment, which can be more gas efficient. However, the state of all wallets is contained within a single contract, so it may require more careful handling of state to ensure correctness and security.

contract SharedWallets is AccessControl {
    uint256 constant votingThreshold = 51;
    uint256 constant proposalExpiryTime = 7 days;
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    struct Wallet {
        mapping(address => bool) isOwner;
        uint256 ownerCount;
        uint256 balance;
    }

    struct Proposal {
        string title;
        string description;
        uint256 amount;
        address payable recipient;
        uint256 deadline;
        ProposalType proposalType;
        bool isExecuted;
        mapping(address => bool) votes;
        uint256 totalVotes;
        bool isInitialized;
    }

    enum ProposalType {
        TRANSFER_FUNDS,
        ADD_OWNER,
        REMOVE_OWNER
    }

    mapping(address => Wallet) public wallets;
    mapping(address => mapping(uint256 => Proposal)) public proposals;
    mapping(address => uint256) public proposalCounters;

    event ProposalAdded(address wallet, uint256 proposalId, string title, uint256 amount, address recipient, ProposalType proposalType);
    event VoteReceived(address wallet, uint256 proposalId, address voter);
    event ProposalExecuted(address wallet, uint256 proposalId, address executor);
    event OwnershipTransferred(address wallet, address oldOwner, address newOwner);
    event OwnerAdded(address wallet, address newOwner);
    event OwnerRemoved(address wallet, address oldOwner);

    function createWallet(address wallet, address[] memory owners) public {
        require(wallets[wallet].ownerCount == 0, "Wallet already exists");
        for (uint256 i = 0; i < owners.length; i++) {
            wallets[wallet].isOwner[owners[i]] = true;
            wallets[wallet].ownerCount++;
        }
    }

    function deposit(address wallet) public payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        require(wallets[wallet].isOwner[msg.sender], "Only owners can deposit");
        wallets[wallet].balance += msg.value;
    }

    function createProposal(address wallet, string memory title, string memory description, uint256 amount, address payable recipient, ProposalType proposalType) public {
        require(wallets[wallet].isOwner[msg.sender], "Only owners can create proposals");
        require(wallets[wallet].balance >= amount, "Insufficient balance");

        Proposal storage proposal = proposals[wallet][proposalCounters[wallet]];
        proposal.title = title;
        proposal.description = description;
        proposal.amount = amount;
        proposal.recipient = recipient;
        proposal.deadline = block.timestamp + proposalExpiryTime;
        proposal.proposalType = proposalType;
        proposal.isExecuted = false;
        proposal.isInitialized = true;

        emit ProposalAdded(wallet, proposalCounters[wallet], title, amount, recipient, proposalType);
        proposalCounters[wallet]++;
    }

    function voteProposal(address wallet, uint256 proposalId) public {
        require(wallets[wallet].isOwner[msg.sender], "Only owners can vote");
        Proposal storage proposal = proposals[wallet][proposalId];
        require(proposal.isInitialized, "Proposal does not exist");
        require(!proposal.votes[msg.sender], "You have already voted");
        require(proposal.deadline >= block.timestamp, "Voting period has ended");

        proposal.votes[msg.sender] = true;
        proposal.totalVotes++;

        emit VoteReceived(wallet, proposalId, msg.sender);
    }

    function executeProposal(address wallet, uint256 proposalId) public {
        require(wallets[wallet].isOwner[msg.sender], "Only owners can execute proposals");
        Proposal storage proposal = proposals[wallet][proposalId];
        require(proposal.isInitialized, "Proposal does not exist");
        require(!proposal.isExecuted, "Proposal already executed");
        require(proposal.totalVotes * 100 / wallets[wallet].ownerCount >= votingThreshold, "Voting threshold not reached");
        require(proposal.deadline >= block.timestamp, "Proposal deadline has passed");

        if(proposal.proposalType == ProposalType.TRANSFER_FUNDS) {
            require(wallets[wallet].balance >= proposal.amount, "Insufficient balance");
            wallets[wallet].balance -= proposal.amount;
            proposal.recipient.transfer(proposal.amount);
        } else if(proposal.proposalType == ProposalType.ADD_OWNER) {
            wallets[wallet].isOwner[proposal.recipient] = true;
            wallets[wallet].ownerCount++;
            emit OwnerAdded(wallet, proposal.recipient);
        } else if(proposal.proposalType == ProposalType.REMOVE_OWNER) {
            require(wallets[wallet].isOwner[proposal.recipient], "Address is not an owner");
            wallets[wallet].isOwner[proposal.recipient] = false;
            wallets[wallet].ownerCount--;
            emit OwnerRemoved(wallet, proposal.recipient);
        }

        proposal.isExecuted = true;
        emit ProposalExecuted(wallet, proposalId, msg.sender);
    }
}

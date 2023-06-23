// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

// Factory Method: In the factory method version, we deploy a new contract instance for each shared wallet. This separates the state and functions for each wallet, which can provide isolation and security benefits but may be less efficient in terms of gas costs because of the need for repeated contract deployment.

contract SharedWallet is AccessControl {
    uint256 constant votingThreshold = 51;
    uint256 constant proposalExpiryTime = 7 days;
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    uint256 public ownerCount = 0;

    enum ProposalType {
        TRANSFER_FUNDS,
        ADD_OWNER,
        REMOVE_OWNER
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

    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCounter;
    
    event ProposalAdded(uint256 proposalId, string title, uint256 amount, address recipient, ProposalType proposalType);
    event VoteReceived(uint256 proposalId, address voter);
    event ProposalExecuted(uint256 proposalId, address executor);
    event OwnershipTransferred(address oldOwner, address newOwner);
    event OwnerAdded(address newOwner);
    event OwnerRemoved(address oldOwner);

    constructor(address[] memory _owners) {
        for (uint256 i = 0; i < _owners.length; i++) {
            _setupRole(OWNER_ROLE, _owners[i]);
            ownerCount++;
        }
    }

    function createProposal(string memory _title, string memory _description, uint256 _amount, address payable _recipient, ProposalType _proposalType) public onlyRole(OWNER_ROLE) {
        require(address(this).balance >= _amount, "Insufficient balance");
        
        Proposal storage newProposal = proposals[proposalCounter];
        newProposal.title = _title;
        newProposal.description = _description;
        newProposal.amount = _amount;
        newProposal.recipient = _recipient;
        newProposal.deadline = block.timestamp + proposalExpiryTime;
        newProposal.proposalType = _proposalType;
        newProposal.isExecuted = false;
        newProposal.isInitialized = true;
        
        emit ProposalAdded(proposalCounter, _title, _amount, _recipient, _proposalType);
        proposalCounter++;
    }

    function voteProposal(uint256 _proposalId) public onlyRole(OWNER_ROLE) {
        require(proposals[_proposalId].isInitialized, "Proposal does not exist");
        require(!proposals[_proposalId].votes[msg.sender], "You have already voted");
        require(proposals[_proposalId].deadline >= block.timestamp, "Voting period has ended");
        proposals[_proposalId].votes[msg.sender] = true;
        proposals[_proposalId].totalVotes++;
        emit VoteReceived(_proposalId, msg.sender);
    }

    function executeProposal(uint256 _proposalId) public onlyRole(OWNER_ROLE) {
        require(proposals[_proposalId].isInitialized, "Proposal does not exist");
        require(!proposals[_proposalId].isExecuted, "Proposal already executed");
        require(proposals[_proposalId].totalVotes * 100 / ownerCount >= votingThreshold, "Voting threshold not reached");
        require(proposals[_proposalId].deadline >= block.timestamp, "Proposal deadline has passed");

        if(proposals[_proposalId].proposalType == ProposalType.TRANSFER_FUNDS) {
            require(address(this).balance >= proposals[_proposalId].amount, "Insufficient balance");
            proposals[_proposalId].recipient.transfer(proposals[_proposalId].amount);
        } else if(proposals[_proposalId].proposalType == ProposalType.ADD_OWNER) {
            _setupRole(OWNER_ROLE, proposals[_proposalId].recipient);
            ownerCount++;
            emit OwnerAdded(proposals[_proposalId].recipient);
        } else if(proposals[_proposalId].proposalType == ProposalType.REMOVE_OWNER) {
            require(hasRole(OWNER_ROLE, proposals[_proposalId].recipient), "Address is not an owner");
            revokeRole(OWNER_ROLE, proposals[_proposalId].recipient);
            ownerCount--;
            emit OwnerRemoved(proposals[_proposalId].recipient);
        }

        proposals[_proposalId].isExecuted = true;
        emit ProposalExecuted(_proposalId, msg.sender);
    }

    function deposit() public payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
    }
}

contract SharedWalletFactory {
    mapping(address => address[]) public ownerWallets;
    address[] public allWallets;

    function createWallet(address[] memory _owners) public {
        SharedWallet newWallet = new SharedWallet(_owners);
        allWallets.push(address(newWallet));
        for(uint i = 0; i < _owners.length; i++) {
            ownerWallets[_owners[i]].push(address(newWallet));
        }
    }

    function getWalletsByOwner(address owner) public view returns (address[] memory) {
        return ownerWallets[owner];
    }

    function getAllWallets() public view returns (address[] memory) {
        return allWallets;
    }
}

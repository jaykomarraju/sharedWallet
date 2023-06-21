// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SharedWallet is AccessControl {
    uint256 constant votingThreshold = 51;
    uint256 constant proposalExpiryTime = 7 days;
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    uint256 public ownerCount = 0;

    struct Proposal {
        string title;
        string description;
        address tokenAddress;
        uint256 amount;
        address payable recipient;
        uint256 deadline;
        mapping(address => bool) votes;
        uint256 totalVotes;
        bool isInitialized;
    }

    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCounter;
    
    event ProposalAdded(uint256 proposalId, string title, address tokenAddress, uint256 amount, address recipient);
    event VoteReceived(uint256 proposalId, address voter);
    event ProposalExecuted(uint256 proposalId, address executor);
    event OwnershipTransferred(address oldOwner, address newOwner);

    constructor(address[] memory _owners) {
        for (uint256 i = 0; i < _owners.length; i++) {
            _setupRole(OWNER_ROLE, _owners[i]);
            ownerCount++;
        }
    }

    function createProposal(string memory _title, string memory _description, address _tokenAddress, uint256 _amount, address payable _recipient) public onlyRole(OWNER_ROLE) {
        require(IERC20(_tokenAddress).balanceOf(address(this)) >= _amount, "Insufficient balance");
        
        Proposal storage newProposal = proposals[proposalCounter];
        newProposal.title = _title;
        newProposal.description = _description;
        newProposal.tokenAddress = _tokenAddress;
        newProposal.amount = _amount;
        newProposal.recipient = _recipient;
        newProposal.deadline = block.timestamp + proposalExpiryTime;
        newProposal.isInitialized = true;
        
        emit ProposalAdded(proposalCounter, _title, _tokenAddress, _amount, _recipient);
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
        require(proposals[_proposalId].totalVotes * 100 / ownerCount >= votingThreshold, "Voting threshold not reached");
        require(proposals[_proposalId].deadline >= block.timestamp, "Proposal deadline has passed");
        require(IERC20(proposals[_proposalId].tokenAddress).balanceOf(address(this)) >= proposals[_proposalId].amount, "Insufficient balance");
        IERC20(proposals[_proposalId].tokenAddress).transfer(proposals[_proposalId].recipient, proposals[_proposalId].amount);
        emit ProposalExecuted(_proposalId, msg.sender);
    }

    function transferOwnership(address oldOwner, address newOwner) public onlyRole(OWNER_ROLE) {
        require(hasRole(OWNER_ROLE, oldOwner), "Address is not an owner");
        revokeRole(OWNER_ROLE, oldOwner);
        grantRole(OWNER_ROLE, newOwner);
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
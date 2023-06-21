# Shared Wallet

## Overview

This Ethereum-based smart contract provides functionality for a multi-signature wallet (a wallet owned by multiple parties), in which actions require a majority vote from the owners. The contract is written in Solidity and uses the ERC20 token standard and OpenZeppelin's AccessControl for roles management.

## Features

- Multiple Owners: The wallet can be owned by multiple addresses.
- Proposal System: Owners can create proposals for transactions. A proposal includes the token's contract address, the amount to be transferred, and the recipient address.
- Voting System: Owners can vote on proposals. A proposal must receive votes from more than 50% of the owners to be approved for execution.
- Execute Proposals: Once a proposal is approved, any owner can execute the transaction.
- Transfer Ownership: Ownership of the wallet can be transferred from one owner to another. The operation must be initiated by an existing owner.

## Smart Contract Functions

### Constructor

When deploying the contract, the initial owners are set.

### createProposal

Owners can create proposals for transactions. The function checks that the contract has enough balance for the transaction.

### voteProposal

Owners can vote on proposals. The function checks that the proposal exists, the owner has not voted on the proposal yet, and the voting period has not ended.

### executeProposal

Owners can execute approved proposals. The function checks that the proposal exists, the voting threshold has been reached, the proposal deadline has not passed, and the contract has enough balance for the transaction.

### transferOwnership

Ownership of the wallet can be transferred from one owner to another. The function checks that the old owner indeed is an owner and transfers the ownership.

### Events

Events are emitted for important actions, including when a proposal is added, a vote is received, a proposal is executed, and ownership is transferred.

## Requirements

- Solidity ^0.8.0
- OpenZeppelin Contracts ^4.0.0
- Setup & Deployment
- Install dependencies: npm install
- Compile contract: npx hardhat compile
- Deploy contract: npx hardhat run scripts/deploy.js --network [your network]

Remember to replace [your network] with the actual network you want to deploy to.

## Security

This contract is governed by the MIT license. Please ensure to audit and test this contract thoroughly before using it in production.

## Disclaimer

This is a simple example of a shared wallet smart contract. It does not include all possible checks, balances, and security measures. Please use it responsibly and at your own risk.
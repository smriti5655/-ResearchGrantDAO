// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ResearchGrantDAO {
    struct Proposal {
        uint256 id;
        string title;
        string description;
        uint256 requestedAmount;
        address proposer;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool executed;
        bool approved;
    }

    address public chairperson;
    uint256 public proposalCount;
    uint256 public votingDuration = 7 days; // Voting duration
    uint256 public treasuryBalance;

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public governanceTokens;
    mapping(address => mapping(uint256 => bool)) public hasVoted; // Tracks whether an address has voted on a proposal

    event ProposalCreated(uint256 id, string title, uint256 requestedAmount, address proposer);
    event Voted(uint256 proposalId, address voter, bool support);
    event ProposalExecuted(uint256 id, bool approved);

    modifier onlyChairperson() {
        require(msg.sender == chairperson, "Only the chairperson can perform this action");
        _;
    }

    modifier onlyMembers() {
        require(governanceTokens[msg.sender] > 0, "Only DAO members can perform this action");
        _;
    }

    constructor() {
        chairperson = msg.sender;
    }

    // Fund the DAO treasury
    function fundTreasury() external payable onlyChairperson {
        treasuryBalance += msg.value;
    }

    // Distribute governance tokens
    function distributeTokens(address member, uint256 amount) external onlyChairperson {
        governanceTokens[member] += amount;
    }

    // Create a funding proposal
    function createProposal(string memory title, string memory description, uint256 requestedAmount) external onlyMembers {
        require(requestedAmount <= treasuryBalance, "Requested amount exceeds treasury balance");

        proposals[proposalCount] = Proposal({
            id: proposalCount,
            title: title,
            description: description,
            requestedAmount: requestedAmount,
            proposer: msg.sender,
            votesFor: 0,
            votesAgainst: 0,
            deadline: block.timestamp + votingDuration,
            executed: false,
            approved: false
        });

        emit ProposalCreated(proposalCount, title, requestedAmount, msg.sender);
        proposalCount++;
    }

    // Vote on a proposal
    function vote(uint256 proposalId, bool support) external onlyMembers {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp < proposal.deadline, "Voting period has ended");
        require(!hasVoted[msg.sender][proposalId], "You have already voted on this proposal");

        hasVoted[msg.sender][proposalId] = true;

        if (support) {
            proposal.votesFor += governanceTokens[msg.sender];
        } else {
            proposal.votesAgainst += governanceTokens[msg.sender];
        }

        emit Voted(proposalId, msg.sender, support);
    }

    // Execute a proposal after voting ends
    function executeProposal(uint256 proposalId) external onlyChairperson {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.deadline, "Voting period has not ended");
        require(!proposal.executed, "Proposal already executed");

        proposal.executed = true;

        if (proposal.votesFor > proposal.votesAgainst) {
            require(treasuryBalance >= proposal.requestedAmount, "Insufficient treasury balance");
            proposal.approved = true;
            treasuryBalance -= proposal.requestedAmount;
            payable(proposal.proposer).transfer(proposal.requestedAmount);
        }

        emit ProposalExecuted(proposalId, proposal.approved);
    }

    // View the DAO treasury balance
    function getTreasuryBalance() external view returns (uint256) {
        return treasuryBalance;
    }
}

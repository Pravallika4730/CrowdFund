
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title CrowdFund
 * @dev A decentralized crowdfunding platform smart contract
 * @author CrowdFund Team
 */
contract CrowdFund {
    
    // State variables
    address public owner;
    uint256 public campaignCounter;
    
    // Structs
    struct Campaign {
        uint256 id;
        address creator;
        string title;
        string description;
        uint256 goalAmount;
        uint256 raisedAmount;
        uint256 deadline;
        bool isActive;
        bool goalReached;
        mapping(address => uint256) contributions;
        address[] contributors;
    }
    
    // Mappings
    mapping(uint256 => Campaign) public campaigns;
    mapping(address => uint256[]) public creatorCampaigns;
    
    // Events
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        uint256 goalAmount,
        uint256 deadline
    );
    
    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );
    
    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount
    );
    
    event RefundIssued(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier validCampaign(uint256 _campaignId) {
        require(_campaignId > 0 && _campaignId <= campaignCounter, "Invalid campaign ID");
        _;
    }
    
    modifier campaignActive(uint256 _campaignId) {
        require(campaigns[_campaignId].isActive, "Campaign is not active");
        require(block.timestamp < campaigns[_campaignId].deadline, "Campaign deadline passed");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        campaignCounter = 0;
    }
    
    /**
     * @dev Core Function 1: Create a new crowdfunding campaign
     * @param _title Campaign title
     * @param _description Campaign description
     * @param _goalAmount Target amount to raise (in wei)
     * @param _durationInDays Campaign duration in days
     */
    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationInDays
    ) public returns (uint256) {
        require(_goalAmount > 0, "Goal amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        require(bytes(_title).length > 0, "Title cannot be empty");
        
        campaignCounter++;
        uint256 deadline = block.timestamp + (_durationInDays * 1 days);
        
        Campaign storage newCampaign = campaigns[campaignCounter];
        newCampaign.id = campaignCounter;
        newCampaign.creator = msg.sender;
        newCampaign.title = _title;
        newCampaign.description = _description;
        newCampaign.goalAmount = _goalAmount;
        newCampaign.raisedAmount = 0;
        newCampaign.deadline = deadline;
        newCampaign.isActive = true;
        newCampaign.goalReached = false;
        
        creatorCampaigns[msg.sender].push(campaignCounter);
        
        emit CampaignCreated(campaignCounter, msg.sender, _title, _goalAmount, deadline);
        
        return campaignCounter;
    }
    
    /**
     * @dev Core Function 2: Contribute funds to a campaign
     * @param _campaignId ID of the campaign to contribute to
     */
    function contribute(uint256 _campaignId) 
        public 
        payable 
        validCampaign(_campaignId) 
        campaignActive(_campaignId) 
    {
        require(msg.value > 0, "Contribution must be greater than 0");
        require(msg.sender != campaigns[_campaignId].creator, "Creator cannot contribute to own campaign");
        
        Campaign storage campaign = campaigns[_campaignId];
        
        // If this is the first contribution from this address, add to contributors array
        if (campaign.contributions[msg.sender] == 0) {
            campaign.contributors.push(msg.sender);
        }
        
        campaign.contributions[msg.sender] += msg.value;
        campaign.raisedAmount += msg.value;
        
        // Check if goal is reached
        if (campaign.raisedAmount >= campaign.goalAmount) {
            campaign.goalReached = true;
        }
        
        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }
    
    /**
     * @dev Core Function 3: Withdraw funds (for successful campaigns) or get refund (for failed campaigns)
     * @param _campaignId ID of the campaign
     */
    function withdrawOrRefund(uint256 _campaignId) 
        public 
        validCampaign(_campaignId) 
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp >= campaign.deadline || campaign.goalReached, "Campaign still active");
        
        if (msg.sender == campaign.creator) {
            // Creator withdrawal (only if goal reached)
            require(campaign.goalReached, "Goal not reached, cannot withdraw");
            require(campaign.raisedAmount > 0, "No funds to withdraw");
            
            uint256 amount = campaign.raisedAmount;
            campaign.raisedAmount = 0;
            campaign.isActive = false;
            
            payable(campaign.creator).transfer(amount);
            emit FundsWithdrawn(_campaignId, campaign.creator, amount);
            
        } else {
            // Contributor refund (only if goal not reached)
            require(!campaign.goalReached, "Goal reached, no refund available");
            require(campaign.contributions[msg.sender] > 0, "No contribution found");
            
            uint256 refundAmount = campaign.contributions[msg.sender];
            campaign.contributions[msg.sender] = 0;
            campaign.raisedAmount -= refundAmount;
            
            payable(msg.sender).transfer(refundAmount);
            emit RefundIssued(_campaignId, msg.sender, refundAmount);
        }
    }
    
    // View functions
    function getCampaignDetails(uint256 _campaignId) 
        public 
        view 
        validCampaign(_campaignId) 
        returns (
            uint256 id,
            address creator,
            string memory title,
            string memory description,
            uint256 goalAmount,
            uint256 raisedAmount,
            uint256 deadline,
            bool isActive,
            bool goalReached,
            uint256 contributorCount
        ) 
    {
        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.id,
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.goalAmount,
            campaign.raisedAmount,
            campaign.deadline,
            campaign.isActive,
            campaign.goalReached,
            campaign.contributors.length
        );
    }
    
    function getContribution(uint256 _campaignId, address _contributor) 
        public 
        view 
        validCampaign(_campaignId) 
        returns (uint256) 
    {
        return campaigns[_campaignId].contributions[_contributor];
    }
    
    function getCampaignsByCreator(address _creator) 
        public 
        view 
        returns (uint256[] memory) 
    {
        return creatorCampaigns[_creator];
    }
    
    function getContributors(uint256 _campaignId) 
        public 
        view 
        validCampaign(_campaignId) 
        returns (address[] memory) 
    {
        return campaigns[_campaignId].contributors;
    }
    
    // Emergency functions
    function emergencyStop(uint256 _campaignId) public onlyOwner validCampaign(_campaignId) {
        campaigns[_campaignId].isActive = false;
    }
    
    function getTotalCampaigns() public view returns (uint256) {
        return campaignCounter;
    }
}

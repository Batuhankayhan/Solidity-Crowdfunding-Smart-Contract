// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CrowdFund {
    struct Campaign {
        address creator;
        string title;
        string description;
        uint goal;
        uint pledged;
        uint startAt;
        uint endAt;
        bool claimed;
    }

    uint public campaignCount;
    mapping(uint => Campaign) public campaigns;
    mapping(uint => mapping(address => uint)) public pledges;

    event Launch(uint indexed id, address indexed creator, uint goal, uint startAt, uint endAt);
    event Cancel(uint indexed id);
    event Pledge(uint indexed id, address indexed caller, uint amount);
    event Unpledge(uint indexed id, address indexed caller, uint amount);
    event Claim(uint indexed id);
    event Refund(uint indexed id, address indexed caller, uint amount);

    modifier onlyCreator(uint _id) {
        require(msg.sender == campaigns[_id].creator, "Not creator");
        _;
    }

    modifier campaignExists(uint _id) {
        require(_id < campaignCount, "Campaign does not exist");
        _;
    }

    function launch(string memory _title, string memory _description, uint _goal, uint _duration) external {
        require(_goal > 0, "Goal must be > 0");
        require(_duration > 0, "Duration must be > 0");

        campaigns[campaignCount] = Campaign({
            creator: msg.sender,
            title: _title,
            description: _description,
            goal: _goal,
            pledged: 0,
            startAt: block.timestamp,
            endAt: block.timestamp + _duration,
            claimed: false
        });

        emit Launch(campaignCount, msg.sender, _goal, block.timestamp, block.timestamp + _duration);
        campaignCount++;
    }

    function cancel(uint _id) external onlyCreator(_id) campaignExists(_id) {
        Campaign storage c = campaigns[_id];
        require(block.timestamp < c.startAt, "Campaign already started");
        delete campaigns[_id];
        emit Cancel(_id);
    }

    function pledge(uint _id) external payable campaignExists(_id) {
        Campaign storage c = campaigns[_id];
        require(block.timestamp >= c.startAt && block.timestamp <= c.endAt, "Not active");
        c.pledged += msg.value;
        pledges[_id][msg.sender] += msg.value;
        emit Pledge(_id, msg.sender, msg.value);
    }

    function unpledge(uint _id, uint _amount) external campaignExists(_id) {
        Campaign storage c = campaigns[_id];
        require(block.timestamp <= c.endAt, "Campaign ended");
        require(pledges[_id][msg.sender] >= _amount, "Insufficient pledge");

        c.pledged -= _amount;
        pledges[_id][msg.sender] -= _amount;
        payable(msg.sender).transfer(_amount);

        emit Unpledge(_id, msg.sender, _amount);
    }

    function claim(uint _id) external onlyCreator(_id) campaignExists(_id) {
        Campaign storage c = campaigns[_id];
        require(block.timestamp > c.endAt, "Campaign not ended");
        require(c.pledged >= c.goal, "Goal not reached");
        require(!c.claimed, "Already claimed");

        c.claimed = true;
        payable(c.creator).transfer(c.pledged);
        emit Claim(_id);
    }

    function refund(uint _id) external campaignExists(_id) {
        Campaign storage c = campaigns[_id];
        require(block.timestamp > c.endAt, "Campaign not ended");
        require(c.pledged < c.goal, "Goal was reached");

        uint bal = pledges[_id][msg.sender];
        require(bal > 0, "No funds to refund");

        pledges[_id][msg.sender] = 0;
        payable(msg.sender).transfer(bal);

        emit Refund(_id, msg.sender, bal);
    }
}

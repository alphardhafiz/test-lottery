// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./SubscriptionConsumer.sol";

contract Lottery {
    address payable public manager;
    address payable[] public players;

    SubscriptionConsumer internal consumerContract;
    uint roundId;
    mapping(uint => address) public roundToWinner;

    enum LOTTERY_STATE {
        OPEN, // people can enter
        CLOSE, // lottery is closed
        CALCULATING_WINNER // waiting for VRF response
    }
    LOTTERY_STATE public lottery_state;

    constructor() {
        manager = payable(msg.sender);
        lottery_state = LOTTERY_STATE.OPEN;
        consumerContract = SubscriptionConsumer(0xF9a29f539eb63fafc725E611c9460f8B764f9069);
    }

    modifier managerOnly() {
        require(msg.sender == manager, "Can only be caller by manager.");
        _;
    }

    receive() external payable {
        require(payable(msg.sender) != manager, "Manager can't play the lottery");
        require(
            msg.value == 0.011 ether,
            "Must be 0.011ETH to enter the lottery"
        );
        // add player to the players array
        players.push(payable(msg.sender));
    }

    function getPlayers()
        public
        view
        managerOnly
        returns (address payable[] memory)
    {
        return players;
    }

    function requestVRF() public managerOnly {
        // send request to CHAINLINK VRF
        consumerContract.requestRandomNumbers(false);
        lottery_state = LOTTERY_STATE.CALCULATING_WINNER;
    }

    function checkVRFResponse() public view managerOnly returns(bool fulfilled, uint[] memory randomNumbers) {
        uint requestID = consumerContract.lastRequestId();
        (fulfilled, randomNumbers) = consumerContract.getRequestStatus(requestID);
    }

    // function randomizer() internal view returns (uint) {
    //     return
    //         uint(
    //             keccak256(
    //                 abi.encodePacked(block.prevrandao, block.timestamp, players)
    //             )
    //         );
    // }
    
    function pickWinner() public managerOnly {
        require(lottery_state == LOTTERY_STATE.CALCULATING_WINNER, "Lottery is not in calculating winner state.");

        (bool fulfilled, uint[] memory randomNumbers) = checkVRFResponse();
        require(fulfilled, "Random number request has not been fulfilled."); // check if random number has been received;

        require(players.length >= 3, "Must be at least 3 players");
        uint index = randomNumbers[0] % players.length;
        address payable winner = players[index];

        // transfer manager fee
        (bool sentManager, ) = manager.call{value: 0.001 ether * players.length}(""); // use recommended method to send ether
        require(sentManager, "Failed to send manager fee.");

        // transfer smart contract's balance to winner address
        (bool sentWinner, ) = winner.call{value: address(this).balance}("");
        require(sentWinner, "Failed to send winner's prize.");
        roundId++; // start from 1
        roundToWinner[roundId] = winner;
        players = new address payable[](0);

        lottery_state = LOTTERY_STATE.OPEN;
    }


}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Lottery {
    address payable public manager;
    address payable[] public players;

    event PlayerEntered(address indexed player, uint256 amount);
    event WinnerPicked(address indexed winner, uint256 amount);

    constructor() {
        manager = payable(msg.sender);
    }

    receive() external payable {
        require(payable(msg.sender) != manager, "Manager can't play the lottery");
        require(
            msg.value == 0.01 ether,
            "Must be 0.01ETH to enter the lottery"
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

    function randomizer() internal view returns (uint) {
        return
            uint(
                keccak256(
                    abi.encodePacked(block.prevrandao, block.timestamp, players)
                )
            );
    }
    
    function pickWinner() public managerOnly {
        require(players.length >= 3, "Must be at least 3 players.");
        uint index = randomizer() % players.length;
        address payable winner = players[index];

        uint256 balance = address(this).balance;

        // Hitung 10% untuk manager
        uint256 managerShare = (balance * 10) / 100;
        
        // Hitung 90% untuk winner
        uint256 winnerShare = balance - managerShare;

        // transfer 10% of the price to manager
        manager.transfer(managerShare);

        // transfer 90% to winner's address
        winner.transfer(winnerShare);
        
        // Emit event dengan jumlah yang dimenangkan
        emit WinnerPicked(winner, winnerShare);

        // Reset players array
        players = new address payable[](0);
    }

    modifier managerOnly() {
        require(msg.sender == manager, "Can only be caller by manager.");
        _;
    }
}

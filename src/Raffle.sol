// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/// @title A sample Raffle contract
/// @author Mo Atef
/// @notice Creating a sample raffle
/// @dev Implements a Chainlink VRFv2

contract Raffle is VRFConsumerBaseV2 {
    error Raffle__NotEnoughETHSent(); // naming convention for errors
    error Raffle__TransferFailed(); // paying money failed
    error Raffle__RaffleNotOpen(); // Raffle is calculating winner
    error Raffle__UpkeepNotNeeded(
        uint currentBalance,
        uint numPlayers,
        uint raffleState
    ); // Raffle is calculatin

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    // State variables
    RaffleState private s_raffleState;
    uint16 private constant REQUEST_CONFIRMATIONS = 3; // number of block confirmations
    uint32 private constant NUM_WORDS = 1; // number of random numbers

    uint private immutable i_entranceFee; // set it only once through the constructor
    uint private immutable i_interval; // duration of lottery in seconds
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator; // address of the VRF coordinator
    uint64 private immutable i_subscriptionId; // subscription ID
    bytes32 private immutable i_gasLane; // gas lane
    uint32 private immutable i_callbackGasLimit; // callback gas limit

    address payable[] private s_players; // array of participants' addresses in the raffle
    uint private s_lastTimeStamp; // last time the raffle was run
    address private s_recentWinner; // address of the recent

    // Events
    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);

    constructor(
        uint entranceFee,
        uint interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        // Pass the VRF coordinator address to the VRFConsumerBase constructor
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee,"Not enough ETH to enter the raffle"); // require is less gas efficient than if then revert

        if (msg.value < i_entranceFee) {
            // this saves more gas than require
            revert Raffle__NotEnoughETHSent();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender)); // wrap it with payable to allow giving that address money
        emit EnteredRaffle(msg.sender); // will return an event when this function runs
    }

    // Getter functions
    function getEntranceFee() external view returns (uint) {
        return i_entranceFee;
    }

   function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0"); // can we comment this out?
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint(s_raffleState)
            );
        }
        // check to see if some time has passed
        if (block.timestamp - s_lastTimeStamp < i_interval) {
            revert();
        }

        s_raffleState = RaffleState.CALCULATING;

        // Will revert if subscription is not set and funded.
        uint requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // gas lane
            i_subscriptionId,
            REQUEST_CONFIRMATIONS, // block confirmations
            i_callbackGasLimit, // callback gas limit,
            NUM_WORDS // number of random numbers
        );
    }

    function fulfillRandomWords(
        uint requestId,
        uint[] memory randomWords
    ) internal override {
        uint indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;

        s_players = new address payable[](0); // reset the players array
        s_lastTimeStamp = block.timestamp; // reset the last time stamp

        emit WinnerPicked(winner);

        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint indexOfPlayer) external view returns(address){


        return s_players[indexOfPlayer];

    }



}

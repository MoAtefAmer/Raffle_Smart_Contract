// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract RaffleTest is Test {
    // Events have to be redefined in tests, cannot be imported etc...
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;

    uint entranceFee;
    uint interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    address public PLAYER = makeAddr("player"); // Cheat functions
    uint public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        console.log("Raffle address: %s", address(raffle));

        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link
        ) = helperConfig.activeNetworkConfig();

        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitsInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    // ENTER RAFFLE --------
    function testRaffleRevertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughETHSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventsOnEntrance() public {
        vm.prank(PLAYER);

        vm.expectEmit(true, false, false, false, address(raffle)); // define the expected indexed events that should trigger

        emit EnteredRaffle(PLAYER); // Emit the first indexed event

        raffle.enterRaffle{value: entranceFee}(); // Call the function that will Trigger the event (this is a foundry thing for tests)
    }

    function testCantEnterWhenRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); // changes the time for the local blockchain for testing purposes
        vm.roll(block.number + 1); // changes the block number for the local blockchain for testing purposes
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }



    // check upkeep

    // function testCheckUpkeepReturnsFalseIfItHasNoBalance() public{
    //     vm.warp(block.timestamp + interval + 1); // changes the time for the local blockchain for testing purposes
    //     vm.roll(block.number + 1); // changes the block number for the local blockchain for testing purposes
    //     raffle.performUpkeep("");

    //     (bool upkeepNeeded, ) = raffle.checkUpkeep("");
    //     assert(upkeepNeeded == false);
    // }



    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(raffleState == Raffle.RaffleState.CALCULATING);
        assert(upkeepNeeded == false);
    }



    
}

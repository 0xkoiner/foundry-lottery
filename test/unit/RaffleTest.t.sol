// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {DeployRaffleScript} from "script/DeployRaffleScript.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
    uint256 _entranceFee;
    uint256 _interval;
    address _vrfCoordinator;
    bytes32 _i_keyHash;
    uint256 _i_subscriptionId;
    uint32 _i_callbackGasLimit;

    Raffle public raffle;
    HelperConfig public helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant PLAYER_ETH_BALANCE = 10 ether;

    /** Events */
    event EnteredToRaffle(address indexed _address, uint256 _value);
    event WinnerPicked(address indexed _address, uint256 _amoutOfWinner);

    modifier raffleEntered() {
        vm.startPrank(PLAYER);
        raffle.enterToRaffle{value: 1 ether}();
        vm.warp(_interval + 10 + block.timestamp);
        vm.roll(block.number + 1);
        _;
    }

    function setUp() external {
        DeployRaffleScript raffleDeployer = new DeployRaffleScript();
        (raffle, helperConfig) = raffleDeployer.deployContract();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        _entranceFee = config._entranceFee;
        _interval = config._interval;
        _vrfCoordinator = config._vrfCoordinator;
        _i_keyHash = config._i_keyHash;
        _i_subscriptionId = config._i_subscriptionId;
        _i_callbackGasLimit = config._i_callbackGasLimit;
        vm.deal(PLAYER, PLAYER_ETH_BALANCE);
    }

    function testRaffleInitializesInOpensState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertNotEnoughETHForEnterToRaffle() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughETHForEnterToRaffle.selector);
        raffle.enterToRaffle{value: 1}();
    }

    function testRaffleEnoughETHForEnterToRaffle() public {
        vm.startPrank(PLAYER);
        raffle.enterToRaffle{value: 1 ether}();
        address addrInArr = address(raffle.getPlayer(uint256(0)));
        assertEq(PLAYER, addrInArr);
        vm.stopPrank();
    }

    function testEmitEventEnteredToRaffle() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, true, false, true);
        emit EnteredToRaffle(PLAYER, 1 ether);
        raffle.enterToRaffle{value: 1 ether}();
    }

    function testNotAllowedToEnterToRaffleWhileCalc() public raffleEntered {
        raffle.preformUpkeep("");

        vm.expectRevert(Raffle.Raffle__LotteryStoppedForCalculation.selector);
        vm.stopPrank();

        vm.startPrank(PLAYER);
        raffle.enterToRaffle{value: 1 ether}();

        vm.stopPrank();
    }

    function testCheckUpKeepRedturnsFalseIfItHasNoBalance() public {
        vm.warp(_interval + 10 + block.timestamp);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepRedturnsFalseIfItRaffleNotOpen()
        public
        raffleEntered
    {
        raffle.preformUpkeep("");
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);

        vm.stopPrank();
    }

    function testCheckUpkeeperReturnsFalseIfEnoughtTimeHasPassed() public {
        uint160 numbersOfUsers = 10;
        uint160 startingIndex = 1;

        for (uint160 i = startingIndex; i < numbersOfUsers; i++) {
            hoax(address(i), 10 ether);
            raffle.enterToRaffle{value: 1 ether}();
        }

        vm.warp(1 + block.timestamp);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeeperReturnsTrueWhenParametersAreGood() public {
        uint160 numbersOfUsers = 10;
        uint160 startingIndex = 1;

        for (uint160 i = startingIndex; i < numbersOfUsers; i++) {
            hoax(address(i), 10 ether);
            raffle.enterToRaffle{value: 1 ether}();
        }

        vm.warp(_interval + 50 + block.timestamp);
        vm.roll(block.number + 40);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded);
    }

    function testCheckUpKeepCanOnlyRunIfCheckUpkeepIsTrue()
        public
        raffleEntered
    {
        raffle.preformUpkeep("");
        vm.stopPrank();
    }

    function testPreformUpKeepRevertsIfCheckUpkeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                raffleState
            )
        );
        raffle.preformUpkeep("");
    }

    function testFulfillrandomWordsCanonlyBeCalledAfterPreformUpkeepFuzzTest(
        uint256 _randomRequestId
    ) public raffleEntered {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(_vrfCoordinator).fulfillRandomWords(
            _randomRequestId,
            address(raffle)
        );
    }

    function testPreformUpkeepUpdatesRaffleStateAndEmitRequestID()
        public
        raffleEntered
    {
        vm.recordLogs();
        raffle.preformUpkeep("");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 requestId = logs[1].topics[0];

        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(raffleState == Raffle.RaffleState.CALCULATING);
    }

    function testAllStatesAreCorrect() public view {
        (
            uint8 REQUEST_CONFIRMATIONS,
            uint8 NUM_WORDS,
            uint256 i_entranceFee,
            uint256 i_interval,
            bytes32 i_keyHash,
            uint256 i_subscriptionId,
            uint32 i_callbackGasLimit,
            uint256 s_lastTimeStamp,
            Raffle.RaffleState s_raffleState,

        ) = raffle.getStates();

        assertEq(REQUEST_CONFIRMATIONS, 5);
        assertEq(NUM_WORDS, 1);
        assertEq(i_entranceFee, _entranceFee);
        assertEq(i_interval, _interval);
        assertEq(i_keyHash, _i_keyHash);
        assertEq(
            i_subscriptionId,
            7324329160583850891323934471238634854715815217636597423914216859908942491661
        );
        assertEq(i_callbackGasLimit, _i_callbackGasLimit);
        assertEq(s_lastTimeStamp, block.timestamp);
        assertEq(uint256(s_raffleState), uint256(Raffle.RaffleState.OPEN));
    }

    function testFulfillTandomWordsPicksAWinnerResetsAndSendMoney()
        public
        raffleEntered
    {
        vm.stopPrank();

        uint160 numbersOfUsers = 10;
        uint160 startingIndex = 1;
        address expectedWinner = address(1);

        for (
            uint160 i = startingIndex;
            i < startingIndex + numbersOfUsers;
            i++
        ) {
            hoax(address(i), 10 ether);
            raffle.enterToRaffle{value: 1 ether}();
        }

        uint256 startingBalance = expectedWinner.balance;

        vm.recordLogs();
        raffle.preformUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console2.logBytes32(entries[1].topics[0]);
        bytes32 requestId = entries[1].topics[0];

        VRFCoordinatorV2_5Mock(_vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        (
            ,
            ,
            uint256 i_entranceFee,
            ,
            ,
            ,
            ,
            uint256 s_lastTimeStamp,
            ,
            address s_recentWinner
        ) = raffle.getStates();

        uint256 winnerStartingBalance = expectedWinner.balance;
        uint256 prize = i_entranceFee * (numbersOfUsers + 1);
        uint256 winnerBalance = s_recentWinner.balance;

        assert(s_recentWinner == expectedWinner);
        assert(winnerBalance == winnerStartingBalance + prize);
    }
}

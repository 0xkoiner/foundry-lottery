// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title Ruffle Contract
 * @author 0xKoiner
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlik VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /** Errors */
    error Raffle__NotEnoughETHForEnterToRaffle();
    error Raffle__FailedTransaction();
    error Raffle__LotteryStoppedForCalculation();
    error Raffle__UpkeepNotNeeded(
        uint256 balance,
        uint256 playersLenght,
        uint256 raffleState
    );

    /** Type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /** State Vars */
    uint8 private constant REQUEST_CONFIRMATIONS = 5; /// @dev REQUEST_CONFIRMATIONS for request VRFv2.5 how many blocks for confirmation
    uint8 private constant NUM_WORDS = 1; /// @dev Number of words for Randomness Alg.
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval; /// @dev Duration of the lottery in sec.
    bytes32 private immutable i_keyHash; /// @dev keyHash for request VRFv2.5
    uint256 private immutable i_subscriptionId; /// @dev subscriptionId for request VRFv2.5
    uint32 private immutable i_callbackGasLimit; /// @dev callbackGasLimit for request VRFv2.5 refund if tx failed
    address payable[] public s_players; ///** @notice The arr payble because  pickAWinner() will send ETH */
    address public s_recentWinner;
    uint256 private s_lastTimeStamp;
    RaffleState private s_raffleState;

    /** Events */
    event EnteredToRaffle(address indexed _address, uint256 _value);
    event WinnerPicked(address indexed _address, uint256 _amoutOfWinner);
    event RequestedRaffleWinner(uint256 _reqiestId);

    /** Modifiers */
    modifier RaffleCurrentState() {
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__LotteryStoppedForCalculation();
        }
        _;
    }

    /** Functions */
    /// @param _entranceFee Using for init immutable state for entrance fee
    /// @param _interval Duration of the lottery in sec.
    /// @param _vrfCoordinator Address for VRFConsumerBaseV2Plus constructor
    /// @param _i_keyHash keyHash for request VRFv2.5
    /// @param _i_subscriptionId subscriptionId for request VRFv2.5
    /// @param _i_callbackGasLimit callbackGasLimit for request VRFv2.5
    /// @dev Before deploy make sure to init with correct entrance fee and interval (immutable)
    constructor(
        uint256 _entranceFee,
        uint256 _interval,
        address _vrfCoordinator,
        bytes32 _i_keyHash,
        uint256 _i_subscriptionId,
        uint32 _i_callbackGasLimit
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
        i_entranceFee = _entranceFee;
        i_interval = _interval;
        i_keyHash = _i_keyHash;
        i_subscriptionId = _i_subscriptionId;
        i_callbackGasLimit = _i_callbackGasLimit;
    }

    /** Setter Functions */
    /**
     * @notice Function for entring to Raffle with minimal entrance amount
     */
    function enterToRaffle() external payable RaffleCurrentState {
        // require(msg.value >= i_entranceFee, Raffle__NotEnoughETHForEnterToRaffle()); pragma solidity ^0.8.26 VIR low gas
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETHForEnterToRaffle();
        }
        s_players.push(payable(msg.sender));

        emit EnteredToRaffle(msg.sender, msg.value);
    }

    /**
     * @notice Function to pick a winner with RNG algorithem
     * @dev Function using with VRFConsumerBaseV2Plus to request a random number
     * @dev The function are automated by ChainLink keeper and will trigger aoutomaticly when function checkUpkeep() is True
     */
    function preformUpkeep(
        bytes calldata /* preformData */
    ) external RaffleCurrentState {
        (bool keeper, ) = checkUpkeep("");
        if (!keeper) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

        emit RequestedRaffleWinner(requestId);
    }

    /**
     * @notice
     * @dev
     */
    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] calldata randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;

        s_raffleState = RaffleState.OPEN;
        address payable winnerAddress = s_players[indexOfWinner];
        s_players = new address payable[](0);
        s_recentWinner = winnerAddress;
        s_lastTimeStamp = block.timestamp;
        uint256 totalBalance = address(this).balance;
        emit WinnerPicked(msg.sender, totalBalance);

        (bool success, ) = winnerAddress.call{value: totalBalance}("");
        if (!success) {
            revert Raffle__FailedTransaction();
        }
    }

    /** Getter Functions */
    /**
     * @notice Function to call value from storage of i_entranceFee
     * @return uint256 to of minimal entrance fee amount
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    /**
     * @notice Function to call data from storage of Struct s_raffleState
     * @return RaffleState Struct
     */
    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    /**
     * @notice Function to call data from storage of Array s_players
     * @return address address by index in Array
     */
    function getPlayer(uint256 _index) external view returns (address) {
        return s_players[_index];
    }

    /**
     * @notice Function to call all private states REQUEST_CONFIRMATIONS, NUM_WORDS, i_entranceFee, i_interval, i_keyHash, i_subscriptionId, i_callbackGasLimit, s_lastTimeStamp, s_raffleState, s_recentWinner
     * @return uint8 of REQUEST_CONFIRMATIONS, NUM_WORDS, i_entranceFee, i_interval, i_keyHash, i_subscriptionId, i_callbackGasLimit, s_lastTimeStamp, s_raffleState, s_recentWinner
     */
    function getStates()
        external
        view
        returns (
            uint8,
            uint8,
            uint256,
            uint256,
            bytes32,
            uint256,
            uint32,
            uint256,
            RaffleState,
            address
        )
    {
        return (
            REQUEST_CONFIRMATIONS,
            NUM_WORDS,
            i_entranceFee,
            i_interval,
            i_keyHash,
            i_subscriptionId,
            i_callbackGasLimit,
            s_lastTimeStamp,
            s_raffleState,
            s_recentWinner
        );
    }

    /**
     * @notice Function for keeper to check if all conditions are True
     * @return upkeepNeeded if is True or False
     * @dev This is the function that the Chainlink Keeper nodes call
     * they look for `upkeepNeeded` to return True.
     * the following should be true for this to return true:
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is open.
     * 3. The contract has ETH.
     * 4. There are players registered.
     * 5. Implicity, your subscription is funded with LINK.
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData*/) {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >=
            i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool contractHasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;

        upkeepNeeded =
            timeHasPassed &&
            isOpen &&
            contractHasBalance &&
            hasPlayers;

        return (upkeepNeeded, "");
    }
}

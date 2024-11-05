// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

abstract contract CodeConstants {
    /** VRF Constants */
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE = 1e9;
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 4e15;

    /** ChainId Constants */
    uint32 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint32 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig__InvalidChainId(uint32 _chainId);

    struct NetworkConfig {
        uint256 _entranceFee;
        uint256 _interval;
        address _vrfCoordinator;
        bytes32 _i_keyHash;
        uint256 _i_subscriptionId;
        uint32 _i_callbackGasLimit;
        address _link;
    }

    NetworkConfig public activeNetworkConfig;

    mapping(uint32 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }
    function getConfigByChainId(
        uint32 _chainId
    ) public returns (NetworkConfig memory) {
        if (networkConfigs[_chainId]._vrfCoordinator != address(0)) {
            return networkConfigs[_chainId];
        } else if (_chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId(_chainId);
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(uint32(block.chainid));
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                _entranceFee: 0.01 ether,
                _interval: 30,
                _vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                _i_keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                _i_subscriptionId: 0,
                _i_callbackGasLimit: 500_000,
                _link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig._vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        // Only broadcast when needed
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock = new VRFCoordinatorV2_5Mock(
                MOCK_BASE_FEE,
                MOCK_GAS_PRICE,
                MOCK_WEI_PER_UNIT_LINK
            );
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast(); // Ensure we stop broadcasting after contract creation

        activeNetworkConfig = NetworkConfig({
            _entranceFee: 0.01 ether,
            _interval: 30,
            _vrfCoordinator: address(vrfCoordinatorV2_5Mock),
            _i_keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            _i_subscriptionId: 0,
            _i_callbackGasLimit: 500_000,
            _link: address(linkToken)
        });

        return activeNetworkConfig;
    }
}

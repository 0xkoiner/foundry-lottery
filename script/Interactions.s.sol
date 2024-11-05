// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract CreateSubscriprion is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig()._vrfCoordinator;

        (uint256 subId, ) = createSubscription(vrfCoordinator);

        return (subId, vrfCoordinator);
    }

    function createSubscription(
        address _vrfCoordinator
    ) public returns (uint256, address) {
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(_vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        return (subId, _vrfCoordinator);
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 public constant FIND_LINK_AMOUNT = 5 ether;

    function funSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig()._vrfCoordinator;
        uint256 subID = helperConfig.getConfig()._i_subscriptionId;
        address linkToken = helperConfig.getConfig()._link;
    }
    function fundSubscriptionWithLinkToken(
        address _vrfCoordinator,
        uint256 _subId,
        address _linkTokens
    ) public {
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(_vrfCoordinator).fundSubscription(
                _subId,
                3 ether
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(_linkTokens).transferAndCall(
                _vrfCoordinator,
                FIND_LINK_AMOUNT * 10,
                abi.encode(_subId)
            );
            vm.stopBroadcast();
        }
    }
    function run() public {
        funSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address _mostRecentDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subID = helperConfig.getConfig()._i_subscriptionId;
        address vrfCoordinator = helperConfig.getConfig()._vrfCoordinator;
        addConsumer(_mostRecentDeployed, vrfCoordinator, subID);
    }

    function addConsumer(
        address _contractToAddVRF,
        address _vrfCoodrdinator,
        uint256 _subId
    ) public {
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(_vrfCoodrdinator).addConsumer(
            _subId,
            _contractToAddVRF
        );
        vm.stopBroadcast();
    }

    function run() public {
        address mostRecentDeployed = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(mostRecentDeployed);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateSubscriprion, FundSubscription, AddConsumer} from "script/Interactions.s.sol";

contract DeployRaffleScript is Script {
    function run() external {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig
            .getConfig();

        if (networkConfig._i_subscriptionId == 0) {
            CreateSubscriprion createSubscription = new CreateSubscriprion();
            (
                networkConfig._i_subscriptionId,
                networkConfig._vrfCoordinator
            ) = createSubscription.createSubscriptionUsingConfig();

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscriptionWithLinkToken(
                networkConfig._vrfCoordinator,
                networkConfig._i_subscriptionId,
                networkConfig._link
            );
        }

        // Start broadcasting only once for deploying Raffle
        vm.startBroadcast();
        Raffle raffle = new Raffle(
            networkConfig._entranceFee,
            networkConfig._interval,
            networkConfig._vrfCoordinator,
            networkConfig._i_keyHash,
            networkConfig._i_subscriptionId,
            networkConfig._i_callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffle),
            networkConfig._vrfCoordinator,
            networkConfig._i_subscriptionId
        );

        return (raffle, helperConfig);
    }
}

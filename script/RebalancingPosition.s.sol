// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {RebalancingPosition} from "../src/RebalancingPosition.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployRebalancingPosition is Script {
    function run() external returns (RebalancingPosition, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (address currency1, address positionManager) = helperConfig
            .activeNetworkConfig();

        vm.startBroadcast();
        RebalancingPosition rebalancingPosition = new RebalancingPosition(
            positionManager,
            currency1
        );
        vm.stopBroadcast();
        return (rebalancingPosition, helperConfig);
    }
}

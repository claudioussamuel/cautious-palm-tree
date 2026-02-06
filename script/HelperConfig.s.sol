// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {Constants} from "../src/Constants.sol";

contract HelperConfig is Script, Constants {
    struct NetworkConfig {
        address currency1;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 1) {
            activeNetworkConfig = getMainnetConfig();
        } else if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else {
            activeNetworkConfig = getAnvilConfig();
        }
    }

    function getMainnetConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                currency1: USDC // From Constants.sol
            });
    }

    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        // Replace with actual Sepolia USDC or mock if needed
        // For now using the same as mainnet or a placeholder if we knew it
        return
            NetworkConfig({
                currency1: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238 // Arbitrary Sepolia USDC
            });
    }

    function getAnvilConfig() public pure returns (NetworkConfig memory) {
        // For local anvil, we might want to deploy a mock or use the one from a fork
        // If forking mainnet, use mainnet address
        return NetworkConfig({currency1: USDC});
    }
}

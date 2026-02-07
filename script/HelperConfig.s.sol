// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {POSITION_MANAGER, USDC} from "../src/Constants.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address currency1;
        address positionManager;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 1) {
            activeNetworkConfig = getMainnetConfig();
        } else if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else if (block.chainid == 8453) {
            activeNetworkConfig = getBaseConfig();
        } else {
            activeNetworkConfig = getAnvilConfig();
        }
    }

    function getMainnetConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                currency1: USDC, // From Constants.sol
                positionManager: POSITION_MANAGER
            });
    }

    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        // Replace with actual Sepolia USDC or mock if needed
        // For now using the same as mainnet or a placeholder if we knew it
        return
            NetworkConfig({
                currency1: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238, // Arbitrary Sepolia USDC
                positionManager: POSITION_MANAGER // Assuming same address or needed update
            });
    }

    function getBaseConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                currency1: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913, // Base USDC
                positionManager: 0x7C5f5A4bBd8fD63184577525326123B519429bDc // Base Position Manager
            });
    }

    function getAnvilConfig() public pure returns (NetworkConfig memory) {
        // For local anvil, we might want to deploy a mock or use the one from a fork
        // If forking mainnet, use mainnet address
        return
            NetworkConfig({currency1: USDC, positionManager: POSITION_MANAGER});
    }
}

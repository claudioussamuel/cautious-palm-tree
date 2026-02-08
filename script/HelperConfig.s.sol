// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {POSITION_MANAGER, USDC} from "../src/Constants.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address positionManager;
        address forwarderAddress;
        address currency1;
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
                positionManager: POSITION_MANAGER,
                forwarderAddress: 0xF8344CFd5c43616a4366C34E3EEE75af79a74482, // Chainlink KeystoneForwarder
                currency1: USDC // From Constants.sol
            });
    }

    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                positionManager: POSITION_MANAGER,
                forwarderAddress: 0xF8344CFd5c43616a4366C34E3EEE75af79a74482, // Chainlink KeystoneForwarder
                currency1: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238 // Sepolia USDC
            });
    }

    function getBaseConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                positionManager: 0x7C5f5A4bBd8fD63184577525326123B519429bDc, // Base Position Manager
                forwarderAddress: 0xF8344CFd5c43616a4366C34E3EEE75af79a74482, // Chainlink KeystoneForwarder
                currency1: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 // Base USDC
            });
    }

    function getAnvilConfig() public pure returns (NetworkConfig memory) {
        // For local anvil, we might want to deploy a mock or use the one from a fork
        // If forking mainnet, use mainnet address
        return
            NetworkConfig({
                positionManager: POSITION_MANAGER,
                forwarderAddress: 0xF8344CFd5c43616a4366C34E3EEE75af79a74482, // Chainlink KeystoneForwarder
                currency1: USDC
            });
    }
}

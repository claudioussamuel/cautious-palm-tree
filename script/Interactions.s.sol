// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {RebalancingPosition} from "../src/RebalancingPosition.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {PoolKey} from "../src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "../src/types/Currency.sol";
import {IHooks} from "../src/interfaces/IHooks.sol";

contract MintPosition is Script {
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "RebalancingPosition",
            block.chainid
        );
        mintPosition(mostRecentlyDeployed);
    }

    function mintPosition(address contractAddress) public {
        vm.startBroadcast();
        RebalancingPosition rebalancingPosition = RebalancingPosition(
            payable(contractAddress)
        );

        // Example params - you might want to parameterize these or read from env
        // Using arbitrary values for demonstration, user should ideally pass these or configure them
        Currency currency0 = Currency.wrap(address(0)); // ETH
        Currency currency1 = Currency.wrap(
            address(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913)
        ); // Base USDC (Example) - Should match deployment
        uint24 fee = 3000;
        int24 tickSpacing = 60;
        IHooks hooks = IHooks(address(0));

        PoolKey memory key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: hooks
        });

        int24 tickLower = -600;
        int24 tickUpper = 600;
        uint256 liquidity = 1e18; // 1 unit of liquidity

        // Provide value for ETH
        rebalancingPosition.mint{value: 0.01 ether}(
            key,
            tickLower,
            tickUpper,
            liquidity
        );
        vm.stopBroadcast();
        console.log(
            "Minted position on RebalancingPosition at %s",
            contractAddress
        );
    }
}

contract IncreaseLiquidity is Script {
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "RebalancingPosition",
            block.chainid
        );
        increaseLiquidity(mostRecentlyDeployed);
    }

    function increaseLiquidity(address contractAddress) public {
        vm.startBroadcast();
        RebalancingPosition rebalancingPosition = RebalancingPosition(
            payable(contractAddress)
        );

        uint256 tokenId = 1; // Replace with actual Token ID
        uint256 liquidity = 1e18;
        uint128 amount0Max = type(uint128).max;
        uint128 amount1Max = type(uint128).max;

        rebalancingPosition.increaseLiquidity{value: 0.01 ether}(
            tokenId,
            liquidity,
            amount0Max,
            amount1Max
        );
        vm.stopBroadcast();
        console.log("Increased liquidity for token %s", tokenId);
    }
}

contract DecreaseLiquidity is Script {
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "RebalancingPosition",
            block.chainid
        );
        decreaseLiquidity(mostRecentlyDeployed);
    }

    function decreaseLiquidity(address contractAddress) public {
        vm.startBroadcast();
        RebalancingPosition rebalancingPosition = RebalancingPosition(
            payable(contractAddress)
        );

        uint256 tokenId = 1; // Replace with actual Token ID
        uint256 liquidity = 1e18;
        uint128 amount0Min = 0;
        uint128 amount1Min = 0;

        rebalancingPosition.decreaseLiquidity(
            tokenId,
            liquidity,
            amount0Min,
            amount1Min
        );
        vm.stopBroadcast();
        console.log("Decreased liquidity for token %s", tokenId);
    }
}

contract BurnPosition is Script {
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "RebalancingPosition",
            block.chainid
        );
        burnPosition(mostRecentlyDeployed);
    }

    function burnPosition(address contractAddress) public {
        vm.startBroadcast();
        RebalancingPosition rebalancingPosition = RebalancingPosition(
            payable(contractAddress)
        );

        uint256 tokenId = 1; // Replace with actual Token ID
        uint128 amount0Min = 0;
        uint128 amount1Min = 0;

        rebalancingPosition.burn(tokenId, amount0Min, amount1Min);
        vm.stopBroadcast();
        console.log("Burned position token %s", tokenId);
    }
}

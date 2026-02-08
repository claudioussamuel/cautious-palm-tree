// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "./interfaces/IERC20.sol";
import {IPositionManager} from "./interfaces/IPositionManager.sol";
import {PoolKey} from "./types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "./types/PoolId.sol";
import {Actions} from "./libraries/Actions.sol";
import {ReceiverTemplate} from "./interfaces/ReceiverTemplate.sol";

/// @title RebalancingPosition
/// @notice Automated liquidity position rebalancing using CRE (Chainlink Runtime Environment)
/// @dev Inherits ReceiverTemplate to receive verified data from CRE workflows
contract RebalancingPosition is ReceiverTemplate {
    using PoolIdLibrary for PoolKey;

    // ================================================================
    // │                         Errors                               │
    // ================================================================
    error InvalidTokenId();
    error InvalidLiquidity();
    error InvalidReportPrefix();
    error PositionNotOwned();
    error NotPositionOwner();

    // ================================================================
    // │                         Events                               │
    // ================================================================
    event RebalanceRequested(uint256 indexed tokenId, int24 currentTick);
    event PositionRebalanced(
        uint256 indexed oldTokenId,
        uint256 indexed newTokenId,
        int24 newTickLower,
        int24 newTickUpper,
        uint256 liquidity
    );
    event LiquidityAdjusted(
        uint256 indexed tokenId,
        bool increased,
        uint256 liquidityDelta
    );
    event PositionCreatedByCRE(
        uint256 indexed tokenId,
        address currency0,
        address currency1,
        int24 tickLower,
        int24 tickUpper,
        uint256 liquidity
    );

    // ================================================================
    // │                    State Variables                           │
    // ================================================================
    IPositionManager public immutable posm;
    address public immutable currency1;

    // Track positions managed by this contract
    mapping(uint256 tokenId => bool) public managedPositions;

    // Track which addresses own which positions
    mapping(address user => uint256[]) private userPositions;

    // Track position owner
    mapping(uint256 tokenId => address owner) public positionOwner;

    // ================================================================
    // │                      Constructor                             │
    // ================================================================
    /// @notice Constructor sets up the position manager and CRE forwarder
    /// @param _posm The Uniswap v4 Position Manager address
    /// @param _forwarderAddress The Chainlink KeystoneForwarder address
    /// @param _currency1 The second currency in the pool (currency0 is assumed to be ETH)
    /// @dev For Sepolia testnet, forwarder is: 0x15fc6ae953e024d975e77382eeec56a9101f9f88
    constructor(
        address _posm,
        address _forwarderAddress,
        address _currency1
    ) ReceiverTemplate(_forwarderAddress) {
        posm = IPositionManager(_posm);
        currency1 = _currency1;
        IERC20(currency1).approve(address(posm), type(uint256).max);
    }

    receive() external payable {}

    // ================================================================
    // │                   Position Management                        │
    // ================================================================

    /// @notice Mint a new liquidity position
    /// @param currency0 The first currency (typically ETH/native token)
    /// @param _currency1 The second currency (typically USDC)
    /// @param fee The pool fee tier
    /// @param tickSpacing The tick spacing for the pool
    /// @param hooks The hooks contract address (or address(0))
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param liquidity The amount of liquidity to mint
    /// @return tokenId The ID of the newly minted position NFT
    function mint(
        address currency0,
        address _currency1,
        uint24 fee,
        int24 tickSpacing,
        address hooks,
        int24 tickLower,
        int24 tickUpper,
        uint256 liquidity
    ) external payable returns (uint256) {
        // Construct PoolKey from individual parameters
        PoolKey memory key = PoolKey({
            currency0: currency0,
            currency1: _currency1,
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: hooks
        });

        bytes memory actions = abi.encodePacked(
            uint8(Actions.MINT_POSITION),
            uint8(Actions.SETTLE_PAIR),
            uint8(Actions.SWEEP)
        );
        bytes[] memory params = new bytes[](3);

        // MINT_POSITION params
        params[0] = abi.encode(
            key,
            tickLower,
            tickUpper,
            liquidity,
            type(uint128).max, // amount0Max
            type(uint128).max, // amount1Max
            address(this), // owner
            "" // hook data
        );

        // SETTLE_PAIR params (currency 0 and 1)
        params[1] = abi.encode(address(0), currency1);

        // SWEEP params (currency, address to)
        params[2] = abi.encode(address(0), address(this));

        uint256 tokenId = posm.nextTokenId();

        posm.modifyLiquidities{value: address(this).balance}(
            abi.encode(actions, params),
            block.timestamp
        );

        // Mark this position as managed by the contract
        managedPositions[tokenId] = true;

        // Track position ownership
        positionOwner[tokenId] = msg.sender;
        userPositions[msg.sender].push(tokenId);

        return tokenId;
    }

    /// @notice Increase liquidity in an existing position
    /// @param tokenId The position NFT ID
    /// @param liquidity The amount of liquidity to add
    /// @param amount0Max Maximum amount of currency0 to spend
    /// @param amount1Max Maximum amount of currency1 to spend
    function increaseLiquidity(
        uint256 tokenId,
        uint256 liquidity,
        uint128 amount0Max,
        uint128 amount1Max
    ) public payable {
        if (!managedPositions[tokenId]) revert PositionNotOwned();
        if (
            positionOwner[tokenId] != msg.sender && msg.sender != address(this)
        ) {
            revert NotPositionOwner();
        }
        if (liquidity == 0) revert InvalidLiquidity();

        bytes memory actions = abi.encodePacked(
            uint8(Actions.INCREASE_LIQUIDITY),
            uint8(Actions.CLOSE_CURRENCY),
            uint8(Actions.CLOSE_CURRENCY),
            uint8(Actions.SWEEP)
        );
        bytes[] memory params = new bytes[](4);

        // INCREASE_LIQUIDITY params
        params[0] = abi.encode(
            tokenId,
            liquidity,
            amount0Max,
            amount1Max,
            "" // hook data
        );

        // CLOSE_CURRENCY params for currency 0
        params[1] = abi.encode(address(0), currency1);

        // CLOSE_CURRENCY params for currency 1
        params[2] = abi.encode(currency1);

        // SWEEP params
        params[3] = abi.encode(address(0), address(this));

        posm.modifyLiquidities{value: address(this).balance}(
            abi.encode(actions, params),
            block.timestamp
        );

        emit LiquidityAdjusted(tokenId, true, liquidity);
    }

    /// @notice Decrease liquidity in an existing position
    /// @param tokenId The position NFT ID
    /// @param liquidity The amount of liquidity to remove
    /// @param amount0Min Minimum amount of currency0 to receive
    /// @param amount1Min Minimum amount of currency1 to receive
    function decreaseLiquidity(
        uint256 tokenId,
        uint256 liquidity,
        uint128 amount0Min,
        uint128 amount1Min
    ) public {
        if (!managedPositions[tokenId]) revert PositionNotOwned();
        if (
            positionOwner[tokenId] != msg.sender && msg.sender != address(this)
        ) {
            revert NotPositionOwner();
        }
        if (liquidity == 0) revert InvalidLiquidity();

        bytes memory actions = abi.encodePacked(
            uint8(Actions.DECREASE_LIQUIDITY),
            uint8(Actions.TAKE_PAIR)
        );
        bytes[] memory params = new bytes[](2);

        // DECREASE_LIQUIDITY params
        params[0] = abi.encode(
            tokenId,
            liquidity,
            amount0Min,
            amount1Min,
            "" // hook data
        );

        // TAKE_PAIR params
        params[1] = abi.encode(address(0), currency1, address(this));

        posm.modifyLiquidities(abi.encode(actions, params), block.timestamp);

        emit LiquidityAdjusted(tokenId, false, liquidity);
    }

    /// @notice Burn a position and withdraw all liquidity
    /// @param tokenId The position NFT ID
    /// @param amount0Min Minimum amount of currency0 to receive
    /// @param amount1Min Minimum amount of currency1 to receive
    function burn(
        uint256 tokenId,
        uint128 amount0Min,
        uint128 amount1Min
    ) public {
        if (!managedPositions[tokenId]) revert PositionNotOwned();
        if (
            positionOwner[tokenId] != msg.sender && msg.sender != address(this)
        ) {
            revert NotPositionOwner();
        }

        bytes memory actions = abi.encodePacked(
            uint8(Actions.BURN_POSITION),
            uint8(Actions.TAKE_PAIR)
        );
        bytes[] memory params = new bytes[](2);

        // BURN_POSITION params
        params[0] = abi.encode(
            tokenId,
            amount0Min,
            amount1Min,
            "" // hook data
        );

        // TAKE_PAIR params
        params[1] = abi.encode(address(0), currency1, address(this));

        posm.modifyLiquidities(abi.encode(actions, params), block.timestamp);

        // Remove from managed positions
        delete managedPositions[tokenId];

        // Remove from user's position list
        _removePositionFromUser(msg.sender, tokenId);
        delete positionOwner[tokenId];
    }

    // ================================================================
    // │                   CRE Integration - Events                   │
    // ================================================================

    /// @notice Request a rebalance check from CRE
    /// @param tokenId The position to check for rebalancing
    /// @param currentTick The current tick of the pool
    /// @dev This event is listened to by CRE Log Trigger
    function requestRebalance(uint256 tokenId, int24 currentTick) external {
        if (!managedPositions[tokenId]) revert PositionNotOwned();
        if (positionOwner[tokenId] != msg.sender) revert NotPositionOwner();

        emit RebalanceRequested(tokenId, currentTick);
    }

    // ================================================================
    // │                   CRE Integration - Receiver                 │
    // ================================================================

    /// @notice Process reports from CRE workflows
    /// @param report ABI-encoded report data from the CRE workflow
    /// @dev Called by onReport() via the KeystoneForwarder
    ///
    /// Supported report types (identified by prefix byte):
    /// - 0x01: Rebalance position
    ///   Format: (bytes1 prefix, uint256 tokenId, int24 newTickLower, int24 newTickUpper)
    /// - 0x02: Adjust liquidity
    ///   Format: (bytes1 prefix, uint256 tokenId, bool increase, uint256 liquidityDelta)
    /// - 0x03: Mint new position
    ///   Format: (bytes1 prefix, address currency0, address currency1, uint24 fee,
    ///           int24 tickSpacing, address hooks, int24 tickLower, int24 tickUpper, uint256 liquidity)
    function _processReport(bytes calldata report) internal override {
        if (report.length == 0) revert InvalidReportPrefix();

        bytes1 prefix = report[0];

        if (prefix == 0x01) {
            // Rebalance position
            _rebalancePosition(report[1:]);
        } else if (prefix == 0x02) {
            // Adjust liquidity
            _adjustLiquidity(report[1:]);
        } else if (prefix == 0x03) {
            // Mint new position
            _mintPosition(report[1:]);
        } else {
            revert InvalidReportPrefix();
        }
    }

    /// @notice Rebalance a position based on CRE analysis
    /// @param report ABI-encoded (uint256 tokenId, int24 newTickLower, int24 newTickUpper)
    /// @dev This removes liquidity from the old position and creates a new one
    function _rebalancePosition(bytes calldata report) internal {
        (uint256 tokenId, int24 newTickLower, int24 newTickUpper) = abi.decode(
            report,
            (uint256, int24, int24)
        );

        if (!managedPositions[tokenId]) revert PositionNotOwned();

        // Get the current position details (implementation depends on IPositionManager)
        // For this example, we'll assume we can extract pool details
        // In practice, you'd need to query the position manager

        // Step 1: Remove all liquidity from old position
        // Note: You'd need to get the actual liquidity amount from the position
        // For this example, we'll use a placeholder approach

        // Step 2: Burn the old position
        burn(tokenId, 0, 0);

        // Step 3: Create new position with updated ticks
        // Note: In practice, you'd preserve the pool parameters and use the withdrawn
        // liquidity to mint the new position. This is a simplified example.

        uint256 newTokenId = posm.nextTokenId();

        emit PositionRebalanced(
            tokenId,
            newTokenId,
            newTickLower,
            newTickUpper,
            0 // liquidity would be calculated from withdrawn amounts
        );
    }

    /// @notice Adjust liquidity based on CRE recommendation
    /// @param report ABI-encoded (uint256 tokenId, bool increase, uint256 liquidityDelta)
    function _adjustLiquidity(bytes calldata report) internal {
        (uint256 tokenId, bool increase, uint256 liquidityDelta) = abi.decode(
            report,
            (uint256, bool, uint256)
        );

        if (!managedPositions[tokenId]) revert PositionNotOwned();
        if (liquidityDelta == 0) revert InvalidLiquidity();

        if (increase) {
            increaseLiquidity(
                tokenId,
                liquidityDelta,
                type(uint128).max,
                type(uint128).max
            );
        } else {
            decreaseLiquidity(tokenId, liquidityDelta, 0, 0);
        }
    }

    /// @notice Mint a new position based on CRE recommendation
    /// @param report ABI-encoded (address currency0, address _currency1, uint24 fee,
    ///                            int24 tickSpacing, address hooks, int24 tickLower,
    ///                            int24 tickUpper, uint256 liquidity)
    /// @dev This allows CRE workflows to autonomously create new positions
    function _mintPosition(bytes calldata report) internal {
        (
            address currency0,
            address _currency1,
            uint24 fee,
            int24 tickSpacing,
            address hooks,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidity
        ) = abi.decode(
                report,
                (
                    address,
                    address,
                    uint24,
                    int24,
                    address,
                    int24,
                    int24,
                    uint256
                )
            );

        if (liquidity == 0) revert InvalidLiquidity();

        // Construct PoolKey from decoded parameters
        PoolKey memory key = PoolKey({
            currency0: currency0,
            currency1: _currency1,
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: hooks
        });

        bytes memory actions = abi.encodePacked(
            uint8(Actions.MINT_POSITION),
            uint8(Actions.SETTLE_PAIR),
            uint8(Actions.SWEEP)
        );
        bytes[] memory params = new bytes[](3);

        // MINT_POSITION params
        params[0] = abi.encode(
            key,
            tickLower,
            tickUpper,
            liquidity,
            type(uint128).max, // amount0Max
            type(uint128).max, // amount1Max
            address(this), // owner
            "" // hook data
        );

        // SETTLE_PAIR params
        params[1] = abi.encode(currency0, _currency1);

        // SWEEP params
        params[2] = abi.encode(currency0, address(this));

        uint256 tokenId = posm.nextTokenId();

        posm.modifyLiquidities{value: address(this).balance}(
            abi.encode(actions, params),
            block.timestamp
        );

        // Mark this position as managed by the contract
        managedPositions[tokenId] = true;

        // For CRE-created positions, contract is the owner
        // Can be transferred later if needed
        positionOwner[tokenId] = address(this);
        userPositions[address(this)].push(tokenId);

        emit PositionCreatedByCRE(
            tokenId,
            currency0,
            _currency1,
            tickLower,
            tickUpper,
            liquidity
        );
    }

    // ================================================================
    // │                    Position Tracking                         │
    // ================================================================

    /// @notice Get all positions owned by a user
    /// @param user The address to check
    /// @return tokenIds Array of position token IDs owned by the user
    function getUserPositions(
        address user
    ) external view returns (uint256[] memory) {
        return userPositions[user];
    }

    /// @notice Get the number of positions owned by a user
    /// @param user The address to check
    /// @return count Number of positions
    function getUserPositionCount(
        address user
    ) external view returns (uint256) {
        return userPositions[user].length;
    }

    /// @notice Check if a user owns a specific position
    /// @param user The address to check
    /// @param tokenId The position token ID
    /// @return True if the user owns the position
    function hasPosition(
        address user,
        uint256 tokenId
    ) external view returns (bool) {
        return positionOwner[tokenId] == user && managedPositions[tokenId];
    }

    /// @notice Get the owner of a position
    /// @param tokenId The position token ID
    /// @return owner The address that owns the position
    function getPositionOwner(uint256 tokenId) external view returns (address) {
        return positionOwner[tokenId];
    }

    /// @notice Internal helper to remove a position from user's array
    /// @param user The user address
    /// @param tokenId The position to remove
    function _removePositionFromUser(address user, uint256 tokenId) internal {
        uint256[] storage positions = userPositions[user];
        uint256 length = positions.length;

        for (uint256 i = 0; i < length; i++) {
            if (positions[i] == tokenId) {
                // Move last element to this position and pop
                positions[i] = positions[length - 1];
                positions.pop();
                break;
            }
        }
    }
}

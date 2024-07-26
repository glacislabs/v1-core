// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {GlacisAbstractAdapter} from "./GlacisAbstractAdapter.sol";
import {IGlacisRouter} from "../routers/GlacisRouter.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {GlacisAbstractAdapter__IDArraysMustBeSameLength, GlacisAbstractAdapter__DestinationChainIdNotValid, GlacisAbstractAdapter__ChainIsNotAvailable, GlacisAbstractAdapter__NoRemoteAdapterForChainId} from "./GlacisAbstractAdapter.sol";
import {AddressBytes32} from "../libraries/AddressBytes32.sol";
import {GlacisCommons} from "../commons/GlacisCommons.sol";

error GlacisCCIPAdapter__GlacisFeeExtrapolationFailed(
    uint256 currentBalance,
    uint256 calculatedFees
);
error GlacisCCIPAdapter__RefundAddressMustReceiveNativeCurrency();
error GlacisCCIPAdapter__PaymentTooSmallForAnyDestinationExecution();

/// @title Glacis Adapter for CCIP GMP
/// @notice A Glacis Adapter for CCIP. Sends messages through the CCIP router's ccipSend() and receives
/// messages via _ccipReceive()
contract GlacisCCIPAdapter is GlacisAbstractAdapter, CCIPReceiver {
    using AddressBytes32 for address;

    mapping(uint256 => uint64) internal glacisChainIdToAdapterChainId;
    mapping(uint64 => uint256) public adapterChainIdToGlacisChainId;

    event GlacisCCIPAdapter__ExtrapolatedGasLimit(
        uint256 extrapolation,
        uint256 messageValue
    );
    event GlacisCCIPAdapter__SetGlacisChainIDs(uint256[] chainIDs, uint64[] chainSelectors);

    /// @param _glacisRouter This chain's glacis router
    /// @param _ccipRouter This chain's CCIP router
    /// @param _owner This adapter's owner
    constructor(
        address _glacisRouter,
        address _ccipRouter,
        address _owner
    )
        GlacisAbstractAdapter(IGlacisRouter(_glacisRouter), _owner)
        CCIPReceiver(_ccipRouter)
    {}

    /// @notice Sets the corresponding CCIP selectors for the specified Glacis chain ID
    /// @param chainIDs Glacis chain IDs
    /// @param chainSelectors Corresponding CCIP chain selectors
    function setGlacisChainIds(
        uint256[] memory chainIDs,
        uint64[] memory chainSelectors
    ) external onlyOwner {
        uint256 chainIdLen = chainIDs.length;
        if (chainIdLen != chainSelectors.length)
            revert GlacisAbstractAdapter__IDArraysMustBeSameLength();

        for (uint256 i; i < chainIdLen; ) {
            uint256 chainId = chainIDs[i];
            uint64 selector = chainSelectors[i];

            if (chainId == 0)
                revert GlacisAbstractAdapter__DestinationChainIdNotValid();

            glacisChainIdToAdapterChainId[chainId] = selector;
            adapterChainIdToGlacisChainId[selector] = chainId;

            unchecked {
                ++i;
            }
        }

        emit GlacisCCIPAdapter__SetGlacisChainIDs(chainIDs, chainSelectors);
    }

    /// @notice Gets the corresponding CCIP chain selector for the specified Glacis chain ID
    /// @param chainId Glacis chain ID
    /// @return The corresponding CCIP chain ID
    function adapterChainID(uint256 chainId) external view returns (uint64) {
        return glacisChainIdToAdapterChainId[chainId];
    }

    /// @notice Queries if the specified Glacis chain ID is supported by this adapter
    /// @param chainId Glacis chain ID
    /// @return True if chain is supported, false otherwise
    function chainIsAvailable(
        uint256 chainId
    ) public view virtual returns (bool) {
        return glacisChainIdToAdapterChainId[chainId] != 0;
    }

    /// @notice Dispatch payload to specified Glacis chain ID and address through CCIP
    /// @param toChainId Destination chain (Glacis ID)
    /// @param payload Payload to send
    function _sendMessage(
        uint256 toChainId,
        address refundAddress,
        GlacisCommons.CrossChainGas memory incentives,
        bytes memory payload
    ) internal override onlyGlacisRouter {
        bytes32 remoteAdapter = remoteCounterpart[toChainId];
        uint64 destinationChain = glacisChainIdToAdapterChainId[toChainId];
        if (remoteAdapter == bytes32(0))
            revert GlacisAbstractAdapter__NoRemoteAdapterForChainId(toChainId);
        if (destinationChain == 0)
            revert GlacisAbstractAdapter__ChainIsNotAvailable(toChainId);

        // Initialize a router client instance to interact with cross-chain router
        IRouterClient router = IRouterClient(this.getRouter());

        Client.EVM2AnyMessage memory evm2AnyMessage;
        uint256 fees;

        // Use incentives if available
        if (incentives.gasLimit > 0) {
            // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
            evm2AnyMessage = Client.EVM2AnyMessage({
                receiver: abi.encode(remoteAdapter), // ABI-encoded receiver address
                data: payload,
                tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array aas no tokens are transferred
                // NOTE: extraArgs is subject to changes by CCIP in the future.
                // We are not supposed to hard code this, but it's hard to get around. We will likely have to
                // regularly redeploy this adapter.
                extraArgs: Client._argsToBytes(
                    // Additional arguments, setting gas limit
                    // Unfortunately required: https://docs.chain.link/ccip/best-practices#setting-gaslimit
                    // Also note that unspent gas is NOT REFUNDED
                    Client.EVMExtraArgsV1({gasLimit: incentives.gasLimit})
                ),
                // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
                feeToken: address(0)
            });

            // Get the fee required to send the CCIP message
            fees = router.getFee(destinationChain, evm2AnyMessage);
            if (fees > msg.value)
                revert GlacisCCIPAdapter__PaymentTooSmallForAnyDestinationExecution();
        }
        // Otherwise, attempt to extrapolate (not the recommended path)
        else {
            uint256 extrapolation = extrapolateGasLimitFromValue(
                msg.value,
                destinationChain,
                payload
            );
            emit GlacisCCIPAdapter__ExtrapolatedGasLimit(
                extrapolation,
                msg.value
            );

            // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
            evm2AnyMessage = Client.EVM2AnyMessage({
                receiver: abi.encode(remoteCounterpart[toChainId]), // ABI-encoded receiver address
                data: payload,
                tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array aas no tokens are transferred
                // NOTE: extraArgs is subject to changes by CCIP in the future.
                // We are not supposed to hard code this, but it's hard to get around. We will likely have to
                // regularly redeploy this adapter.
                extraArgs: Client._argsToBytes(
                    // Additional arguments, setting gas limit
                    // Unfortunately required: https://docs.chain.link/ccip/best-practices#setting-gaslimit
                    // Also note that unspent gas is NOT REFUNDED
                    Client.EVMExtraArgsV1({gasLimit: extrapolation})
                ),
                // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
                feeToken: address(0)
            });

            // Get the fee required to send the CCIP message
            fees = router.getFee(destinationChain, evm2AnyMessage);
            if (fees > msg.value)
                revert GlacisCCIPAdapter__GlacisFeeExtrapolationFailed(
                    msg.value,
                    fees
                );
        }

        // Send the CCIP message through the router and store the returned CCIP message ID
        router.ccipSend{value: fees}(destinationChain, evm2AnyMessage);

        // Forward any remaining balance to user
        uint256 refund = msg.value - fees;
        if (refund > 0) {
            (bool successful, ) = address(refundAddress).call{value: refund}(
                ""
            );
            if (!successful)
                revert GlacisCCIPAdapter__RefundAddressMustReceiveNativeCurrency();
        }
    }

    /// @notice Handles a received message from CCIP
    /// @param any2EvmMessage The CCIP formatted message
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    )
        internal
        override
        onlyAuthorizedAdapter(
            adapterChainIdToGlacisChainId[any2EvmMessage.sourceChainSelector],
            address(abi.decode(any2EvmMessage.sender, (address))).toBytes32()
        )
    {
        GLACIS_ROUTER.receiveMessage(
            adapterChainIdToGlacisChainId[any2EvmMessage.sourceChainSelector], 
            any2EvmMessage.data
        );
    }

    /// @notice Extrapolates destination chain's gas limit from an amount of the origin chain's gas token
    /// for a specific cross-chain transaction
    /// @param value The amount of the origin chain's gas token to use to pay for destination gas fees
    /// @param destinationChain The destination chain's CCIP chain ID
    /// @param payload The bytes payload to send across chains in this message
    /// @notice The CCIP fees are linearly calculated, so we can calculate the amount given. Unfortunately,
    /// we have to assume that the fee formula stay the same forever. This may not be the case
    function extrapolateGasLimitFromValue(
        uint256 value,
        uint64 destinationChain,
        bytes memory payload
    ) public view returns (uint256) {
        IRouterClient router = IRouterClient(this.getRouter());
        uint256 feeAt0GasLimit = router.getFee(
            destinationChain,
            Client.EVM2AnyMessage({
                receiver: abi.encode(remoteCounterpart[destinationChain]), // ABI-encoded receiver address
                data: payload,
                tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array aas no tokens are transferred
                // NOTE: extraArgs is subject to changes by CCIP in the future.
                // We are not supposed to hard code this, but it's hard to get around. We will likely have to
                // regularly redeploy this adapter.
                extraArgs: Client._argsToBytes(
                    // Additional arguments, setting gas limit
                    // Unfortunately required: https://docs.chain.link/ccip/best-practices#setting-gaslimit
                    // Also note that unspent gas is NOT REFUNDED
                    Client.EVMExtraArgsV1({gasLimit: 0})
                ),
                // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
                feeToken: address(0)
            })
        );
        uint256 feeAt100kGasLimit = router.getFee(
            destinationChain,
            Client.EVM2AnyMessage({
                receiver: abi.encode(remoteCounterpart[destinationChain]),
                data: payload,
                tokenAmounts: new Client.EVMTokenAmount[](0),
                extraArgs: Client._argsToBytes(
                    Client.EVMExtraArgsV1({gasLimit: 100_000})
                ),
                feeToken: address(0)
            })
        );
        if (feeAt0GasLimit > value) {
            revert GlacisCCIPAdapter__PaymentTooSmallForAnyDestinationExecution();
        }
        uint256 m = (feeAt100kGasLimit - feeAt0GasLimit) / 100_000 + 1;

        // Calculates x = (y-b) / m, but increased m by 0.5% to overestimate value needed
        uint256 gasLimit = (value - feeAt0GasLimit) / (m + (m / 200));

        // CCIP caps at 3 million gas: https://docs.chain.link/ccip/service-limits
        if (gasLimit > 3_000_000) return 3_000_000;
        else return gasLimit;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {GlacisAbstractAdapter} from "./GlacisAbstractAdapter.sol";
import {IGlacisRouter} from "../routers/GlacisRouter.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {GlacisAbstractAdapter__IDArraysMustBeSameLength, GlacisAbstractAdapter__DestinationChainIdNotValid, GlacisAbstractAdapter__SourceChainNotRegistered} from "./GlacisAbstractAdapter.sol";

error GlacisCCIPAdapter__GlacisFeeExtrapolationFailed(
    uint256 currentBalance,
    uint256 calculatedFees
);
error GlacisCCIPAdapter__RefundAddressMustReceiveNativeCurrency();
error GlacisCCIPAdapter__PaymentTooSmallForAnyDestinationExecution();

/// @title Glacis Adapter for Axelar GMP
/// @dev This adapter receives GlacisRouter requests through _sendMessage function and forwards them to
/// Axelar. Also receives Axelar requests through _execute function and routes them to GlacisRouter
/// @dev Axelar uses labels for chain IDs so requires mappings to Glacis chain IDs
contract GlacisCCIPAdapter is GlacisAbstractAdapter, CCIPReceiver {
    mapping(uint256 => uint64) public glacisChainIdToAdapterChainId;
    mapping(uint64 => uint256) public adapterChainIdToGlacisChainId;

    event GlacisCCIPAdapter__ExtrapolatedGasLimit(
        uint256 extrapolation,
        uint256 messageValue
    );

    constructor(
        address glacisRouter_,
        address ccipRouter_,
        address owner_
    )
        GlacisAbstractAdapter(IGlacisRouter(glacisRouter_), owner_)
        CCIPReceiver(ccipRouter_)
    {}

    /// @notice Sets the corresponding CCIP selectors for the specified Glacis chain ID
    /// @param chainIds Glacis chain IDs
    /// @param chainSelectors Corresponding CCIP chain selectors
    function setAdapterChains(
        uint256[] memory chainIds,
        uint64[] memory chainSelectors
    ) external onlyOwner {
        uint256 chainIdLen = chainIds.length;
        if (chainIdLen != chainSelectors.length)
            revert GlacisAbstractAdapter__IDArraysMustBeSameLength();

        for (uint256 i; i < chainIdLen; ) {
            uint256 chainId = chainIds[i];
            uint64 selector = chainSelectors[i];

            if (chainId == 0)
                revert GlacisAbstractAdapter__DestinationChainIdNotValid();

            glacisChainIdToAdapterChainId[chainId] = selector;
            adapterChainIdToGlacisChainId[selector] = chainId;

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Gets the corresponding CCIP chain selector for the specified Glacis chain ID
    /// @param chainId Glacis chain ID
    /// @return The corresponding Axelar label
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

    /// @notice Dispatch payload to specified Glacis chain ID and address through Axelar GMP
    /// @param toChainId Destination chain (Glacis ID)
    /// @param payload Payload to send
    function _sendMessage(
        uint256 toChainId,
        address refundAddress,
        bytes memory payload
    ) internal override onlyGlacisRouter {
        uint64 destinationChain = glacisChainIdToAdapterChainId[toChainId];
        if (destinationChain == 0)
            revert IGlacisAdapter__ChainIsNotAvailable(toChainId);

        // Extrapolate gas limit
        uint256 extrapolation = extrapolateGasLimitFromValue(
            msg.value,
            destinationChain,
            payload
        );
        emit GlacisCCIPAdapter__ExtrapolatedGasLimit(extrapolation, msg.value);

        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
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

        // Initialize a router client instance to interact with cross-chain router
        IRouterClient router = IRouterClient(this.getRouter());

        // Get the fee required to send the CCIP message
        uint256 fees = router.getFee(destinationChain, evm2AnyMessage);
        if (fees > msg.value)
            revert GlacisCCIPAdapter__GlacisFeeExtrapolationFailed(
                msg.value,
                fees
            );

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

    /// Handles a received message
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    )
        internal
        override
        onlyAuthorizedAdapter(
            adapterChainIdToGlacisChainId[any2EvmMessage.sourceChainSelector],
            abi.decode(any2EvmMessage.sender, (address))
        )
    {
        uint256 sourceChainId = adapterChainIdToGlacisChainId[
            any2EvmMessage.sourceChainSelector
        ];

        if (sourceChainId == 0)
            revert GlacisAbstractAdapter__SourceChainNotRegistered();

        GLACIS_ROUTER.receiveMessage(sourceChainId, any2EvmMessage.data);
    }

    /// Noticed that the fees are linearly calculated, so we can calculate the amount given.
    /// Unfortunately we have to assume that the fee calculations stay the same forever. This may not
    /// be the case.
    function extrapolateGasLimitFromValue(
        uint256 value,
        uint64 destinationChain,
        bytes memory payload
    ) public view returns (uint256) {
        IRouterClient router = IRouterClient(this.getRouter());
        uint256 b = router.getFee(
            destinationChain,
            Client.EVM2AnyMessage({
                receiver: abi.encode(address(this)), // ABI-encoded receiver address
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
        uint256 feeAt100k = router.getFee(
            destinationChain,
            Client.EVM2AnyMessage({
                receiver: abi.encode(address(this)),
                data: payload,
                tokenAmounts: new Client.EVMTokenAmount[](0),
                extraArgs: Client._argsToBytes(
                    Client.EVMExtraArgsV1({gasLimit: 100_000})
                ),
                feeToken: address(0)
            })
        );
        uint256 m = (feeAt100k / 100_000) - b;

        if (b > value) {
            revert GlacisCCIPAdapter__PaymentTooSmallForAnyDestinationExecution();
        }

        // Calculates x = (y-b) / m, but increased m by 0.5% to overestimate value needed
        return (value - b) / (m + (m / 200));
    }
}

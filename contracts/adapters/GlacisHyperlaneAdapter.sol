// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import {GlacisAbstractAdapter} from "./GlacisAbstractAdapter.sol";
import {IGlacisRouter} from "../routers/GlacisRouter.sol";
import {IMailbox} from "@hyperlane-xyz/core/contracts/interfaces/IMailbox.sol";
import {StandardHookMetadata} from "@hyperlane-xyz/core/contracts/hooks/libs/StandardHookMetadata.sol";
import {IInterchainSecurityModule} from "@hyperlane-xyz/core/contracts/interfaces/IInterchainSecurityModule.sol";
import {IPostDispatchHook} from "@hyperlane-xyz/core/contracts/interfaces/hooks/IPostDispatchHook.sol";
import {GlacisAbstractAdapter__IDArraysMustBeSameLength, GlacisAbstractAdapter__DestinationChainIdNotValid, GlacisAbstractAdapter__NoRemoteAdapterForChainId, GlacisAbstractAdapter__ChainIsNotAvailable} from "./GlacisAbstractAdapter.sol";
import {GlacisCommons} from "../commons/GlacisCommons.sol";

error GlacisHyperlaneAdapter__OnlyMailboxAllowed();
error GlacisHyperlaneAdapter__FeeNotEnough();
error GlacisHyperlaneAdapter__RefundAddressMustReceiveNativeCurrency();

/// @title Glacis Adapter for Hyperlane
/// @notice A Glacis Adapter for the canonical Hyperlane network. Sends messages through dispatch() and receives
/// messages via handle()
/// @notice Opted to create our own mailbox client because Hyperlane's base Mailbox refund address was static
contract GlacisHyperlaneAdapter is GlacisAbstractAdapter {
    // Required by Hyperlane, if kept as 0 then it will use the default router.
    IInterchainSecurityModule public interchainSecurityModule;
    IMailbox public immutable MAIL_BOX;
    uint32 public immutable LOCAL_DOMAIN;

    mapping(uint256 => uint32) internal glacisChainIdToAdapterChainId;
    mapping(uint32 => uint256) public adapterChainIdToGlacisChainId;

    event GlacisHyperlaneAdapter__SetGlacisChainIDs(uint256[] chainIDs, uint32[] domains);

    /// @param _glacisRouter This chain's glacis router
    /// @param _hyperlaneMailbox This chain's hyperlane router
    /// @param _owner This adapter's owner
    constructor(
        address _glacisRouter,
        address _hyperlaneMailbox,
        address _owner
    ) GlacisAbstractAdapter(IGlacisRouter(_glacisRouter), _owner) {
        MAIL_BOX = IMailbox(_hyperlaneMailbox);
        LOCAL_DOMAIN = MAIL_BOX.localDomain();
    }

    /// @notice Sets the corresponding Hyperlane domain for the specified Glacis chain ID
    /// @param chainIDs Glacis chain IDs
    /// @param domains Hyperlane corresponding chain domains
    function setGlacisChainIds(
        uint256[] memory chainIDs,
        uint32[] memory domains
    ) public onlyOwner {
        uint256 chainIdLen = chainIDs.length;
        if (chainIdLen != domains.length)
            revert GlacisAbstractAdapter__IDArraysMustBeSameLength();

        for (uint256 i; i < chainIdLen; ) {
            uint256 chainId = chainIDs[i];
            uint32 chainLabel = domains[i];

            if (chainId == 0)
                revert GlacisAbstractAdapter__DestinationChainIdNotValid();

            glacisChainIdToAdapterChainId[chainId] = chainLabel;
            adapterChainIdToGlacisChainId[chainLabel] = chainId;

            unchecked {
                ++i;
            }
        }

        emit GlacisHyperlaneAdapter__SetGlacisChainIDs(chainIDs, domains);
    }

    /// @notice Gets the corresponding Hyperlane domain ID for the specified Glacis chain ID
    /// @param chainId Glacis chain ID
    /// @return The corresponding Hyperlane domain ID
    function adapterChainID(uint256 chainId) external view returns (uint32) {
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

    /// @notice Dispatch payload to specified Glacis chain ID and address through Hyperlane
    /// @param toChainId Destination chain (Glacis ID)
    /// @param refundAddress The address to send excess fee payments to
    /// @param payload Payload to send
    function _sendMessage(
        uint256 toChainId,
        address refundAddress,
        GlacisCommons.CrossChainGas memory,
        bytes memory payload
    ) internal override {
        uint32 destinationDomain = glacisChainIdToAdapterChainId[toChainId];
        bytes32 destinationAddress = remoteCounterpart[toChainId];

        if (destinationAddress == bytes32(0))
            revert GlacisAbstractAdapter__NoRemoteAdapterForChainId(toChainId);
        if (destinationDomain == 0)
            revert GlacisAbstractAdapter__ChainIsNotAvailable(toChainId);

        // Generate metadata using refundAddress
        bytes memory metadata = StandardHookMetadata.overrideRefundAddress(
            refundAddress
        );

        // Ensure that we have enough of the required fee (will revert if not this value)
        uint256 nativePriceQuote = MAIL_BOX.quoteDispatch(
            destinationDomain,
            destinationAddress,
            payload,
            metadata
        );
        if (msg.value < nativePriceQuote) {
            revert GlacisHyperlaneAdapter__FeeNotEnough();
        }

        // Send message across chains
        MAIL_BOX.dispatch{value: nativePriceQuote}(
            destinationDomain,
            destinationAddress,
            payload,
            metadata,
            IPostDispatchHook(address(0)) // hook
        );

        // Send rest to refund address
        if (msg.value > nativePriceQuote) {
            (bool successful, ) = address(refundAddress).call{
                value: msg.value - nativePriceQuote
            }("");
            if (!successful)
                revert GlacisHyperlaneAdapter__RefundAddressMustReceiveNativeCurrency();
        }
    }

    /// @notice Receives messages from Hyperlane
    /// @param _origin The hyperlane domain ID
    /// @param _sender The bytes32 representation of the origin's sender address
    /// @param _message The bytes payload of the message
    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _message
    )
        external
        payable
        onlyAuthorizedAdapter(adapterChainIdToGlacisChainId[_origin], _sender)
    {
        if (msg.sender != address(MAIL_BOX)) {
            revert GlacisHyperlaneAdapter__OnlyMailboxAllowed();
        }

        GLACIS_ROUTER.receiveMessage(adapterChainIdToGlacisChainId[_origin], _message);
    }
}

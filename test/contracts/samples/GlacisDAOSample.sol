// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;

import {GlacisTokenClientOwnable} from "../../../contracts/client/GlacisTokenClientOwnable.sol";
import {GlacisCommons} from "../../../contracts/commons/GlacisCommons.sol";
import {XERC20Sample} from "./token/XERC20Sample.sol";
import {AddressBytes32} from "../../../contracts/libraries/AddressBytes32.sol";

error GlacisDAOSample__MembersOnly();
error GlacisDAOSample__VoterMustReceiveValue();
error GlacisDAOSample__CallIncorrect();
error GlacisDAOSample__OnlySelfCanCall();
error GlacisDAOSample__ReceivingCallFailed();
error GlacisDAOSample__SelfCallFailed();
error GlacisDAOSample__CanOnlyBeCalledBySelf();
error GlacisDAOSample__FeeArrayMustEqualAmountOfProposals();
error GlacisDAOSample__NotEnoughMessageValueRemainingForFees();

contract GlacisDAOSample is GlacisTokenClientOwnable {
    using AddressBytes32 for address;
    using AddressBytes32 for bytes32;

    struct Proposal {
        uint256 toChain;
        bool retriable;
        address[] gmps;
        address token;
        uint256 tokenAmount;
        // Will be interpreted as address + calldata
        address finalTo;
        uint256 callValue;
        bytes calldataPayload;
    }

    mapping(address => bool) public members;
    address[] private membersArray;
    mapping(uint256 => Proposal[]) private proposals;
    mapping(uint256 => bytes32[]) private approvedProposalMessageIDs;
    mapping(address => mapping(uint256 => bool)) private votes;
    uint256 public nextProposal;
    string public configText;
    uint256 public configVersion;
    XERC20Sample public immutable SAMPLE_TOKEN;

    modifier onlyMembers() {
        if (!members[msg.sender]) revert GlacisDAOSample__MembersOnly();
        _;
    }

    modifier onlySelf() {
        if (msg.sender != address(this)) {
            revert GlacisDAOSample__OnlySelfCanCall();
        }
        _;
    }

    constructor(
        address[] memory members_,
        address glacisTokenMediator_,
        address glacisRouter_,
        address owner_
    ) GlacisTokenClientOwnable(glacisTokenMediator_, glacisRouter_, 0, owner_) {
        unchecked {
            for (uint256 i; i < members_.length; ++i) {
                members[members_[i]] = true;
            }
            membersArray = members_;
        }

        SAMPLE_TOKEN = new XERC20Sample(address(this));
        SAMPLE_TOKEN.approve(glacisTokenMediator_, type(uint256).max);
        SAMPLE_TOKEN.setLimits(glacisTokenMediator_, 100 ether, 100 ether);
    }

    // =====================================================
    //                   VOTING & PROPOSING
    // =====================================================

    /// Creates a new proposal.
    function propose(Proposal[] memory p) external onlyMembers {
        Proposal[] storage stor = proposals[nextProposal++];
        unchecked {
            for (uint256 i; i < p.length; ++i) {
                stor.push(p[i]);
            }
        }
        return;
    }

    /// Approves a proposal.
    /// @param proposalId the proposal id to approve.
    /// @param payTo the address to send any remaining value to
    function approve(
        uint256 proposalId,
        address payTo,
        CrossChainGas[][] memory fees
    ) public payable onlyMembers {
        uint256 totalVotes = 0;
        uint256 totalMembers = membersArray.length;

        unchecked {
            for (uint256 i; i < totalMembers; ++i) {
                if (
                    votes[membersArray[i]][proposalId] ||
                    msg.sender == membersArray[i]
                ) totalVotes += 1;
            }
        }

        // Requires unanimous decision
        if (totalVotes == totalMembers) {
            Proposal[] memory ps = proposals[proposalId];
            uint256 plen = ps.length;

            if (fees.length != plen) {
                revert GlacisDAOSample__FeeArrayMustEqualAmountOfProposals();
            }

            if (plen > 0) {
                bytes32[]
                    storage approvedMessageIds = approvedProposalMessageIDs[
                        proposalId
                    ];

                uint256 valueRemaining = msg.value;
                for (uint256 i; i < plen; ++i) {
                    CrossChainGas[] memory f = fees[i];
                    uint256 fLen = f.length;
                    uint256 feeSum;

                    for (uint256 j; j < fLen; ++j) {
                        feeSum += f[j].nativeCurrencyValue;
                    }
                    if (feeSum > valueRemaining) {
                        revert GlacisDAOSample__NotEnoughMessageValueRemainingForFees();
                    }

                    bytes32 messageID = _executeProposal(ps[i], f, feeSum);
                    approvedMessageIds.push(messageID);
                    valueRemaining -= feeSum;
                }
            }
        }

        // Updates user's vote
        votes[msg.sender][proposalId] = true;

        // Forward any remaining gas
        bool success = payable(payTo).send(address(this).balance);
        if (!success) revert GlacisDAOSample__VoterMustReceiveValue();
    }

    function _executeProposal(
        Proposal memory p,
        CrossChainGas[] memory fees,
        uint256 gasPayment
    ) internal returns (bytes32 messageID) {
        if (p.token == address(0)) {
            messageID = _route({
                to: address(this).toBytes32(),
                chainId: p.toChain,
                payload: abi.encode(p.finalTo, p.callValue, p.calldataPayload),
                adapters: p.gmps,
                fees: fees,
                refundAddress: msg.sender,
                retriable: p.retriable,
                gasPayment: gasPayment
            });
        } else {
            (messageID,) = _routeWithTokens({
                to: address(this).toBytes32(),
                chainId: p.toChain,
                payload: abi.encode(p.finalTo, p.callValue, p.calldataPayload),
                adapters: p.gmps,
                fees: fees,
                refundAddress: msg.sender,
                gasPayment: gasPayment,
                token: p.token,
                tokenAmount: p.tokenAmount
            });
        }
    }

    /// Approves a proposal.
    /// @param proposalId the proposal id to approve.
    function approve(
        uint256 proposalId,
        CrossChainGas[][] memory fees
    ) external payable onlyMembers {
        approve(proposalId, msg.sender, fees);
    }

    /// Retries an approved proposal's message send.
    /// @param proposalId the proposal id to retry.
    /// @param messageIndex the index of the message to retry within the proposal.
    /// @param nonce the nonce of the proposal's message (found in events).
    function retry(
        uint256 proposalId,
        uint256 messageIndex,
        uint256 nonce,
        CrossChainGas[] memory fees
    ) external payable {
        Proposal memory p = proposals[proposalId][messageIndex];
        if (p.token == address(0)) {
            _retryRoute({
                to: address(this).toBytes32(),
                chainId: p.toChain,
                payload: abi.encode(p.finalTo, p.callValue, p.calldataPayload),
                adapters: p.gmps,
                fees: fees,
                refundAddress: msg.sender,
                nonce: nonce,
                messageId: approvedProposalMessageIDs[proposalId][messageIndex],
                gasPayment: msg.value
            });
        } else {
            _retryRouteWithTokens({
                to: address(this).toBytes32(),
                chainId: p.toChain,
                payload: abi.encode(p.finalTo, p.callValue, p.calldataPayload),
                adapters: p.gmps,
                fees: fees,
                refundAddress: msg.sender,
                token: p.token,
                tokenAmount: p.tokenAmount,
                nonce: nonce,
                messageId: approvedProposalMessageIDs[proposalId][messageIndex],
                gasPayment: msg.value
            });
        }
    }

    // =====================================================
    //                      DAO ACTIONS
    // =====================================================

    /// Receives a message from other chains' DAO deployments.
    function _receiveMessage(
        address[] memory,
        uint256,
        bytes32 fromAddress,
        bytes memory payload
    ) internal override {
        if (fromAddress.toAddress() != address(this))
            revert GlacisDAOSample__CanOnlyBeCalledBySelf();

        (address finalTo, uint256 callValue, bytes memory calldataPayload) = abi
            .decode(payload, (address, uint256, bytes));
        (bool success, ) = address(finalTo).call{value: callValue}(
            calldataPayload
        );
        if (!success) revert GlacisDAOSample__ReceivingCallFailed();
    }

    /// Receives a message from other chains' DAO deployments. (Same as _receiveMessage)
    function _receiveMessageWithTokens(
        address[] memory,
        uint256,
        bytes32 fromAddress,
        bytes memory payload,
        address, // token
        uint256 // tokenAmount
    ) internal override {
        if (fromAddress.toAddress() != address(this))
            revert GlacisDAOSample__CanOnlyBeCalledBySelf();

        (address finalTo, uint256 callValue, bytes memory calldataPayload) = abi
            .decode(payload, (address, uint256, bytes));
        (bool success, ) = address(finalTo).call{value: callValue}(
            calldataPayload
        );
        if (!success) revert GlacisDAOSample__ReceivingCallFailed();
    }

    /// Adds 1 to the config number. Can only be called by self.
    function selfConfig(string memory str) external onlySelf {
        configVersion += 1;
        configText = str;
    }

    /// Allows this smart contract to set the quorum. Can only be called by self.
    function selfQuorum(uint256 _quorum) external onlySelf {
        quorum = _quorum;
    }

    /// Allows this smart contract to execute proposals. Can only be called by self.
    function selfExecuteProposal(
        Proposal[] memory _proposals,
        CrossChainGas[] memory fees
    ) external payable onlySelf {
        uint256 proposalsLen = _proposals.length;
        uint256 dividedMsgValue = msg.value / fees.length;
        for (uint256 i; i < proposalsLen; ) {
            _executeProposal(_proposals[i], fees, dividedMsgValue);
            unchecked {
                ++i;
            }
        }
    }

    /// This is a test function that allows the deployer (owner) to manually set the
    /// quorum. Usually a DAO would set this through a vote, such as through the
    /// selfQuorum function.
    function setQuorum(uint256 _quorum) external onlyOwner {
        quorum = _quorum;
    }

    uint256 public quorum = 1;

    // =====================================================
    //                        GETTERS
    // =====================================================

    function getQuorum(
        GlacisCommons.GlacisData memory,
        bytes memory
    ) public view override returns (uint256) {
        return quorum;
    }

    function getDAOData()
        external
        view
        returns (
            address[] memory _members,
            uint256 proposalCount,
            string memory _configText,
            uint256 _configVersion,
            uint256 _quorum,
            address tokenAddress,
            uint256 tokenAmount
        )
    {
        _members = membersArray;
        proposalCount = nextProposal;
        _configText = configText;
        _configVersion = configVersion;
        _quorum = quorum;
        tokenAddress = address(SAMPLE_TOKEN);
        tokenAmount = SAMPLE_TOKEN.balanceOf(address(this));
    }

    function getProposalData(
        uint256 proposalId
    ) external view returns (Proposal[] memory, bytes32[] memory, uint256) {
        uint256 totalVotes = 0;
        uint256 totalMembers = membersArray.length;

        unchecked {
            for (uint256 i; i < totalMembers; ++i) {
                if (votes[membersArray[i]][proposalId]) totalVotes += 1;
            }
        }

        return (
            proposals[proposalId],
            approvedProposalMessageIDs[proposalId],
            totalVotes
        );
    }
}

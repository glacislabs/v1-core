// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.18;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@layerzerolabs/solidity-examples/contracts/lzApp/interfaces/ILayerZeroReceiver.sol";
import "@layerzerolabs/solidity-examples/contracts/lzApp/interfaces/ILayerZeroUserApplicationConfig.sol";
import "@layerzerolabs/solidity-examples/contracts/lzApp/interfaces/ILayerZeroEndpoint.sol";
import "@layerzerolabs/solidity-examples/contracts/libraries/BytesLib.sol";
import "@layerzerolabs/solidity-examples/contracts/libraries/ExcessivelySafeCall.sol";

/// @title Nonblocking LzApp Events  
/// @notice The events interface for LayerZero nonblocking apps, which are necessary to listen for 
/// in forge failure tests  
interface SimpleNonblockingLzAppEvents {
    event MessageFailed(
        uint16 _srcChainId,
        bytes _srcAddress,
        uint64 _nonce,
        bytes _payload,
        bytes _reason
    );
    event RetryMessageSuccess(
        uint16 _srcChainId,
        bytes _srcAddress,
        uint64 _nonce,
        bytes32 _payloadHash
    );
}

/// @title Simple Nonblocking LzApp  
/// @notice A generic LzReceiver implementation that removes the base reference to the blocking LzApp  
abstract contract SimpleNonblockingLzApp is
    Ownable2Step,
    ILayerZeroReceiver,
    ILayerZeroUserApplicationConfig,
    SimpleNonblockingLzAppEvents
{
    using BytesLib for bytes;
    using ExcessivelySafeCall for address;

    // ua can not send payload larger than this by default, but it can be changed by the ua owner
    uint public constant DEFAULT_PAYLOAD_SIZE_LIMIT = 10000;

    ILayerZeroEndpoint public immutable lzEndpoint;
    mapping(uint16 => mapping(uint16 => uint)) public minDstGasLookup;
    mapping(uint16 => uint) public payloadSizeLimitLookup;
    address public precrime;

    event SetPrecrime(address precrime);
    event SetMinDstGas(uint16 _dstChainId, uint16 _type, uint _minDstGas);

    constructor(address _endpoint) {
        lzEndpoint = ILayerZeroEndpoint(_endpoint);
    }

    function lzReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) public virtual override {
        // lzReceive must be called by the endpoint for security
        require(
            _msgSender() == address(lzEndpoint),
            "LzApp: invalid endpoint caller"
        );

        (bool success, bytes memory reason) = address(this).excessivelySafeCall(
            gasleft(),
            150,
            abi.encodeWithSelector(
                this.nonblockingLzReceive.selector,
                _srcChainId,
                _srcAddress,
                _nonce,
                _payload
            )
        );
        // try-catch all errors/exceptions
        if (!success) {
            _storeFailedMessage(
                _srcChainId,
                _srcAddress,
                _nonce,
                _payload,
                reason
            );
        }
    }

    function _lzSend(
        uint16 _dstChainId,
        address _dstChainAddress,
        bytes memory _payload,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes memory _adapterParams,
        uint _nativeFee
    ) internal virtual {
        _checkPayloadSize(_dstChainId, _payload.length);
        lzEndpoint.send{value: _nativeFee}(
            _dstChainId,
            abi.encodePacked(_dstChainAddress, address(this)),
            _payload,
            _refundAddress,
            _zroPaymentAddress,
            _adapterParams
        );
    }

    // function _checkGasLimit(
    //     uint16 _dstChainId,
    //     uint16 _type,
    //     bytes memory _adapterParams,
    //     uint _extraGas
    // ) internal view virtual {
    //     uint providedGasLimit = _getGasLimit(_adapterParams);
    //     uint minGasLimit = minDstGasLookup[_dstChainId][_type] + _extraGas;
    //     require(minGasLimit > 0, "LzApp: minGasLimit not set");
    //     require(providedGasLimit >= minGasLimit, "LzApp: gas limit is too low");
    // }

    // function _getGasLimit(
    //     bytes memory _adapterParams
    // ) internal pure virtual returns (uint gasLimit) {
    //     require(_adapterParams.length >= 34, "LzApp: invalid adapterParams");
    //     assembly {
    //         gasLimit := mload(add(_adapterParams, 34))
    //     }
    // }

    function _checkPayloadSize(
        uint16 _dstChainId,
        uint _payloadSize
    ) internal view virtual {
        uint payloadSizeLimit = payloadSizeLimitLookup[_dstChainId];
        if (payloadSizeLimit == 0) {
            // use default if not set
            payloadSizeLimit = DEFAULT_PAYLOAD_SIZE_LIMIT;
        }
        require(
            _payloadSize <= payloadSizeLimit,
            "LzApp: payload size is too large"
        );
    }

    //---------------------------UserApplication config----------------------------------------
    function getConfig(
        uint16 _version,
        uint16 _chainId,
        address,
        uint _configType
    ) external view returns (bytes memory) {
        return
            lzEndpoint.getConfig(
                _version,
                _chainId,
                address(this),
                _configType
            );
    }

    // generic config for LayerZero user Application
    function setConfig(
        uint16 _version,
        uint16 _chainId,
        uint _configType,
        bytes calldata _config
    ) external override onlyOwner {
        lzEndpoint.setConfig(_version, _chainId, _configType, _config);
    }

    function setSendVersion(uint16 _version) external override onlyOwner {
        lzEndpoint.setSendVersion(_version);
    }

    function setReceiveVersion(uint16 _version) external override onlyOwner {
        lzEndpoint.setReceiveVersion(_version);
    }

    function forceResumeReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress
    ) external override onlyOwner {
        lzEndpoint.forceResumeReceive(_srcChainId, _srcAddress);
    }

    function setPrecrime(address _precrime) external onlyOwner {
        precrime = _precrime;
        emit SetPrecrime(_precrime);
    }

    function setMinDstGas(
        uint16 _dstChainId,
        uint16 _packetType,
        uint _minGas
    ) external onlyOwner {
        require(_minGas > 0, "LzApp: invalid minGas");
        minDstGasLookup[_dstChainId][_packetType] = _minGas;
        emit SetMinDstGas(_dstChainId, _packetType, _minGas);
    }

    // if the size is 0, it means default size limit
    function setPayloadSizeLimit(
        uint16 _dstChainId,
        uint _size
    ) external onlyOwner {
        payloadSizeLimitLookup[_dstChainId] = _size;
    }

    // ======================= NONBLOCKING =======================

    mapping(uint16 => mapping(bytes => mapping(uint64 => bytes32)))
        public failedMessages;

    function _storeFailedMessage(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload,
        bytes memory _reason
    ) internal virtual {
        failedMessages[_srcChainId][_srcAddress][_nonce] = keccak256(_payload);
        emit MessageFailed(_srcChainId, _srcAddress, _nonce, _payload, _reason);
    }

    function nonblockingLzReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) public virtual {
        // only internal transaction
        require(
            _msgSender() == address(this),
            "NonblockingLzApp: caller must be LzApp"
        );
        _nonblockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
    }

    //@notice override this function
    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) internal virtual;

    function retryMessage(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) public payable virtual {
        // assert there is message to retry
        bytes32 payloadHash = failedMessages[_srcChainId][_srcAddress][_nonce];
        require(
            payloadHash != bytes32(0),
            "NonblockingLzApp: no stored message"
        );
        require(
            keccak256(_payload) == payloadHash,
            "NonblockingLzApp: invalid payload"
        );
        // clear the stored message
        failedMessages[_srcChainId][_srcAddress][_nonce] = bytes32(0);
        // execute the message. revert if it fails again
        _nonblockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
        emit RetryMessageSuccess(_srcChainId, _srcAddress, _nonce, payloadHash);
    }
}

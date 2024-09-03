// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.18;
import {AddressString} from "../../contracts/libraries/AddressString.sol";
import {CheckSum} from "../contracts/libraries/CheckSum.sol";
import {LocalTestSetup} from "../LocalTestSetup.sol";
/* solhint-disable no-console  */
// solhint-disable-next-line no-global-import
import "forge-std/console.sol";

/* solhint-disable contract-name-camelcase */
contract AddressStringTests is LocalTestSetup {
    using AddressString for string;
    using CheckSum for address;

    function test__toString() external {
        address addr = address(0x1234567890AbcdEF1234567890aBcdef12345678);
        string memory addrStr = addr.toChecksumString();
        assertEq(addrStr, "0x1234567890AbcdEF1234567890aBcdef12345678");
    }

    function test__toAddress() external {
        string memory addrStr = "1234567890AbcdEF1234567890aBcdef12345678";
        address addr = addrStr.toAddress();
        assertEq(addr, address(0x1234567890AbcdEF1234567890aBcdef12345678));
    }

    function testFuzz__toStringAndBack(address addr) external {
        string memory addrStr = addr.getChecksum();
        address newAddress = addrStr.toAddress();
        assertEq(addr, newAddress);
    }
}

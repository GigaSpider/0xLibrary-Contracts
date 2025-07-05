// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./ZK.sol";

contract ETHZK is ZK {
    constructor(
        IVerifier _verifier,
        IHasher _hasher,
        uint256 _denomination,
        uint32 _merkleTreeHeight
    ) ZK(_verifier, _hasher, _denomination, _merkleTreeHeight) {}

    function _processDeposit() internal override {
        require(
            msg.value == Denomination,
            "Please send `mixDenomination` ETH along with transaction"
        );
    }

    function _processWithdraw(
        address payable _recipient,
        address payable _relayer,
        bool _relayerRate
    ) internal override {
        // sanity checks
        require(
            msg.value == 0,
            "Message value is supposed to be zero for ETH instance"
        );

        if (_relayerRate) {
            require(_relayer != address(0), "invalid relayer address");
            uint256 fee = (2 * Denomination) / (1e3);
            (bool success, ) = _relayer.call{value: Denomination - fee}("");
            require(success, "payment to _relayer did not go thru");
            (bool success2, ) = _relayer.call{value: fee}("");
            require(success2, "payment to _relayer did not go thru");
        } else {
            uint256 fee = (Denomination) / (1e3);
            (bool success, ) = _recipient.call{value: Denomination - fee}("");
            require(success, "payment to _recipient did not go thru");
        }
    }
}

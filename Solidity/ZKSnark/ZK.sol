// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./MerkleTreeWithHistory.sol";

interface IVerifier {
    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[2] calldata _pubSignals
    ) external view returns (bool);
}

//testing

abstract contract ZK is MerkleTreeWithHistory, ReentrancyGuard {
    IVerifier public immutable verifier;
    address public Oracle;
    uint256 public Denomination;
    uint256 Fee;
    uint256 Refund;
    bytes32 public merkle;
    mapping(bytes32 => bool) nullifierHashes;
    mapping(bytes32 => bool) commitments;

    modifier OnlyOracle() {
        require(msg.sender == Oracle, "Access denied");
        _;
    }

    event DepositEvent(
        bytes32 indexed commitment,
        uint32 leafIndex,
        uint256 timestamp
    );
    event WithdrawEvent(address to, bytes32 nullifierHash);

    constructor(
        IVerifier _verifier,
        IHasher _hasher,
        uint256 _denomination,
        uint32 _merkleTreeHeight
    ) MerkleTreeWithHistory(_merkleTreeHeight, _hasher) {
        require(_denomination > 0, "denomination should be greater than 0");
        verifier = _verifier;
        Denomination = _denomination;
    }

    function USERDeposit(bytes32 Commitment) external payable nonReentrant {
        require(
            msg.value == Denomination,
            "Deposit Value for this contract must match 0.01 Ethereum"
        );
        require(
            !commitments[Commitment],
            "This commitment has already been made"
        );

        uint32 InsertedIndex = _insert(Commitment);
        commitments[Commitment] = true;
        _processDeposit();

        emit DepositEvent(Commitment, InsertedIndex, block.timestamp);
    }

    function USERWithdraw(bytes calldata Proof) external /* nonReentrant */ {
        (
            uint[2] memory _pA,
            uint[2][2] memory _pB,
            uint[2] memory _pC,
            uint[2] memory _pubSignals
        ) = abi.decode(Proof, (uint[2], uint[2][2], uint[2], uint[2]));
        require(
            verifier.verifyProof(_pA, _pB, _pC, _pubSignals),
            "Invalid withdraw proof"
        );
        bytes32 nullifierHash = bytes32(_pubSignals[1]);
        bytes32 root = bytes32(_pubSignals[0]);
        require(
            !nullifierHashes[nullifierHash],
            "This deposit has already been spent"
        );
        require(isKnownRoot(root), "Cannot find your merkle root");
        nullifierHashes[nullifierHash] = true;
        address relayer = address(0);
        bool fee = false; // Example: 0.001 ETH
        _processWithdraw(payable(msg.sender), payable(relayer), fee);
        emit WithdrawEvent(msg.sender, nullifierHash);
    }

    function RelayerWithdraw(
        bytes calldata Proof,
        address Destination
    ) external nonReentrant OnlyOracle {
        (
            uint[2] memory _pA,
            uint[2][2] memory _pB,
            uint[2] memory _pC,
            uint[2] memory _pubSignals
        ) = abi.decode(Proof, (uint[2], uint[2][2], uint[2], uint[2]));

        require(
            verifier.verifyProof(_pA, _pB, _pC, _pubSignals),
            "Invalid withdraw proof"
        );
        require(
            !nullifierHashes[bytes32(_pubSignals[1])],
            "This deposit has already been spent"
        );
        require(
            isKnownRoot(bytes32(_pubSignals[0])),
            "Cannot find your merkle root"
        );



        nullifierHashes[bytes32(_pubSignals[1])] = true;
        address relayer = address(0);
        bool relayerRate = true;

        _processWithdraw(payable(Destination), payable(relayer), relayerRate);
        emit WithdrawEvent(Destination, bytes32(_pubSignals[1]));
    }

    function _processWithdraw(
        address payable _recipient,
        address payable _relayer,
        bool _relayerRate
    ) internal virtual;

    function _processDeposit() internal virtual;

    function VerifyProof(
        string memory Proof
    ) private nonReentrant returns (bool) {}

    function UpdateData(string memory Variable) external OnlyOracle {}
}

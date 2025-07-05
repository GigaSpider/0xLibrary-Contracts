// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract WAGER is ReentrancyGuard {
    uint256 index = 0;
    address private oracle;
    uint256 public HOUSE_EDGE = 1;

    constructor() {
        oracle = msg.sender;
    }

    modifier OnlyOracle() {
        require(msg.sender == oracle, "not authorized");
        _;
    }

    modifier Authorization(uint256 wager_index) {
        require(
            Wagers[wager_index].player == msg.sender,
            "Authorization failed, make sure you are referring to a valid wager index that is associated with your wallet"
        );
        _;
    }

    struct Wager {
        address player;
        uint256 timestamp;
        uint256 odds;
        uint256 amount;
        uint256 potentialPayout;
        uint256 blocknumber;
        bool settled;
        bool won;
    }

    mapping(uint256 => Wager) Wagers;

    event BetPlaced(uint256 index);
    event CheckStatusUpdate(uint256 index, bool settled, bool won);

    function USERPlaceWager(
        uint8 OneTo90ProbabilityOfWin
    )
        external
        payable
        nonReentrant
        returns (uint256 Wager_Index, string memory message)
    {
        require(
            OneTo90ProbabilityOfWin >= 1 && OneTo90ProbabilityOfWin <= 90,
            "Probability must be an unsigned interger between 1 and 90"
        );
        require(
            msg.value >= 1e14,
            "Wager must be greater than or equal to 0.0001 ETH"
        );

        uint256 potentialPayout = msg.value *
            ((100 - HOUSE_EDGE) / OneTo90ProbabilityOfWin);

        require(
            address(this).balance / 10 >= potentialPayout,
            "contract requires potential    payout to be less than 10% of the value of eth in the contract."
        );

        Wagers[index] = Wager({
            player: msg.sender,
            timestamp: block.timestamp,
            odds: OneTo90ProbabilityOfWin,
            amount: msg.value,
            potentialPayout: potentialPayout,
            blocknumber: block.number,
            settled: false,
            won: false
        });

        emit BetPlaced(index);

        index++;

        return (
            index - 1,
            "Asynchronous randomization algorithm called off chain. Funds will be deposited into your wallet automatically if you win."
        );
    }

    function USERCheckStatus(
        uint256 Wager_Index
    ) external Authorization(Wager_Index) nonReentrant returns (bool, bool) {
        return (Wagers[Wager_Index].settled, Wagers[Wager_Index].won);
    }

    function USERSafetyWithdrawal(
        uint256 Wager_Index
    ) external Authorization(Wager_Index) nonReentrant {
        require(
            Wagers[Wager_Index].settled == false,
            "You can't withdraw. This wager has already been settled."
        );
        require(
            block.timestamp >= Wagers[Wager_Index].timestamp + 5 minutes,
            "In the case of an unresponsive node, caller must wait atleast 5 minutes before funds can be reversed. Try again later."
        );
        payable(msg.sender).transfer(Wagers[Wager_Index].amount);
    }

    function OracleResponse(
        uint256 wager_index,
        uint256 randomNumber
    ) external OnlyOracle nonReentrant {
        require(Wagers[wager_index].timestamp != 0, "doesn't exist");

        uint256 probability = Wagers[wager_index].odds;

        if (randomNumber < probability) {
            payable(Wagers[wager_index].player).transfer(
                Wagers[wager_index].potentialPayout
            );
            Wagers[wager_index].settled = true;
            Wagers[wager_index].won = true;
        } else {
            Wagers[wager_index].settled = true;
        }
    }

    function ORACLEDeposit() external payable OnlyOracle nonReentrant {}

    function ORACLEWithdraw(uint256 amount) external OnlyOracle nonReentrant {
        require(address(this).balance >= amount, "NSF");
        payable(oracle).transfer(amount);
    }
}

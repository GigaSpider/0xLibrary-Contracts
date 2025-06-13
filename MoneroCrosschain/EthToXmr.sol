pragma solidity ^0.8.27;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract ETH_XMR is ReentrancyGuard {
    address public depositor;
    address payable master;
    address public oracle;
    string public moneroAddress;
    uint256 public depositTimestamp;
    bool private initialized;
    bool private depositCalled;
    bool private swapSuccessCalled;
    bool private swapFailureCalled;
    bool private reclaimDepositCalled;

    event SwapSuccessConfirmation(string TxID);
    event SwapFailureConfirmation();

    modifier OnlyOracle() {
        require(msg.sender == oracle, "Caller is not the oracle");
        _;
    }

    modifier OnlyDepositor() {
        require(msg.sender == depositor, "Caller is not the depositor");
        _;
    }

    function initialize(
        address _depositor,
        string memory _moneroAddress,
        address payable _master,
        address _oracle
    ) external {
        require(!initialized, "Already initialized");
        initialized = true;
        depositor = _depositor;
        moneroAddress = _moneroAddress;
        master = _master;
        oracle = _oracle;
    }

    function USERDeposit() public payable OnlyDepositor nonReentrant {
        require(
            !depositCalled,
            "Contract can only be paid once, this may be ammended in a future update"
        );
        require(
            msg.value >= 1e15,
            "You must send a minimum of .001 Optimisim ETH"
        );
        depositTimestamp = block.timestamp;
        MASTER(master).EthereumReceived(
            address(this),
            msg.value,
            moneroAddress
        );
        depositCalled = true;
    }

    function ConfirmSwapSuccess(
        string memory tx_hash
    ) external OnlyOracle nonReentrant {
        require(!swapSuccessCalled, "Swap Success already called");
        emit SwapSuccessConfirmation(tx_hash);
        payable(master).transfer(address(this).balance);
        swapSuccessCalled = true;
    }

    function ConfirmSwapFailure() external OnlyOracle nonReentrant {
        require(!swapFailureCalled, "Swap Failure already called");
        emit SwapFailureConfirmation();
        payable(depositor).transfer(address(this).balance);
        swapFailureCalled = true;
    }

    function ReclaimDeposit() external OnlyDepositor nonReentrant {
        require(
            block.timestamp >= depositTimestamp + 5 minutes,
            "Cannot reclaim yet"
        );
        payable(depositor).transfer(address(this).balance);
        reclaimDepositCalled = true;
    }
}

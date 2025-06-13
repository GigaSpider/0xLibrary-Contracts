pragma solidity ^0.8.27;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract XMR_ETH is ReentrancyGuard {
    string public moneroAddress;
    address public withdrawalAddress;
    address public withdrawalConfirmation;
    address payable master;
    address public oracle;
    bool private swapFailureCalled;
    bool private addressGenerationSuccessCalled;
    bool private addressGenerationFailureCalled;
    bool private transmitMoneroReceivedCalled;
    event HaveMoneroAddress(string moneroAddress);
    event DontHaveMoneroAddress();
    event MoneroReceived(uint256 amountReceived);
    event SwapCompleted(uint256 amount, address indexed recipient);
    event SwapFailed(string errorMessage);
    event EthSentEvent(uint256 withdrawalAmount);

    modifier OnlyOracle() {
        require(msg.sender == oracle, "Caller is not the oracle");
        _;
    }
    modifier OnlyMaster() {
        require(msg.sender == master, "Caller is not the master");
        _;
    }

    function initialize(
        address _withdrawalAddress,
        address payable _master,
        address _oracle
    ) external {
        withdrawalAddress = _withdrawalAddress;
        master = _master;
        oracle = _oracle;
    }

    function SwapFailureConfirmation(
        string memory errorMessage
    ) external OnlyOracle nonReentrant {
        require(!swapFailureCalled, "Swap Failure confirmation already called");
        emit SwapFailed(errorMessage);
        swapFailureCalled = true;
    }

    function AddressGenerationSuccess(
        string memory _moneroAddress
    ) external OnlyOracle nonReentrant {
        require(
            !addressGenerationSuccessCalled,
            "Address generation success already called"
        );
        moneroAddress = _moneroAddress;
        emit HaveMoneroAddress(moneroAddress);
        addressGenerationSuccessCalled = true;
    }

    function AddressGenerationFailure() external OnlyOracle nonReentrant {
        require(
            !addressGenerationFailureCalled,
            "Address Generation Failure already called"
        );
        emit DontHaveMoneroAddress();
        addressGenerationFailureCalled = true;
    }

    function TransmitMoneroReceived(
        uint256 amountReceived
    ) external OnlyOracle nonReentrant {
        require(
            !transmitMoneroReceivedCalled,
            "function already called, you shouldnt be doing this."
        );
        require(
            amountReceived > 0,
            "Invalid function call, monero received has to be greater than 0"
        );
        emit MoneroReceived(amountReceived);
        uint256 withdrawalAmount = MASTER(master).MoneroReceived(
            amountReceived,
            withdrawalAddress
        );
        emit EthSentEvent(withdrawalAmount);
        transmitMoneroReceivedCalled = true;
    }
}

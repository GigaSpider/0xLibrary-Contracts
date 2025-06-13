pragma solidity ^0.8.27;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract MASTER is ReentrancyGuard {
    address public implementation1;
    address public implementation2;
    AggregatorV3Interface public eth_usd_price;
    AggregatorV3Interface public xmr_usd_price;
    address public oracle;
    mapping(address => address) public ETH_XMR_CONTRACTS;
    mapping(address => address) public XMR_ETH_CONTRACTS;

    constructor(
        address _implementation1,
        address _implementation2,
        address _eth_usd_address,
        address _xmr_usd_address
    ) {
        implementation1 = _implementation1;
        implementation2 = _implementation2;
        eth_usd_price = AggregatorV3Interface(_eth_usd_address);
        xmr_usd_price = AggregatorV3Interface(_xmr_usd_address);
        oracle = msg.sender;
    }

    event EthDeposit(
        address indexed depositAddress,
        uint256 amount,
        string encryptedMoneroAddress,
        uint256 rate
    );

    event EthXmrContractCreation(
        address indexed depositAddress,
        string encryptedMoneroAddress
    );

    event XmrEthContractCreation(
        address indexed subcontractAddress,
        address indexed withdrawalAddress
    );

    event EthereumWithdrawal(address indexed destination, uint256 amount);

    modifier OnlyEthXmrContracts() {
        require(
            ETH_XMR_CONTRACTS[msg.sender] != address(0),
            "Not a valid ETH/XMR contract"
        );
        _;
    }

    modifier OnlyXmrEthContracts() {
        require(
            XMR_ETH_CONTRACTS[msg.sender] != address(0),
            "Not a valid XMR/ETH contract"
        );
        _;
    }

    modifier OnlyOracle() {
        require(msg.sender == oracle, "Not authorized");
        _;
    }

    receive() external payable {}

    function Withdraw(address withdrawalAddress) external OnlyOracle {
        require(address(this).balance > 0, "contract is empty");
        payable(withdrawalAddress).transfer(address(this).balance);
    }

    function CreateEthXmrContract(
        string memory Monero_Withdrawal_Address
    ) external {
        address clone = Clones.clone(implementation1);
        ETH_XMR_CONTRACTS[clone] = msg.sender;
        ETH_XMR(payable(clone)).initialize(
            msg.sender,
            Monero_Withdrawal_Address,
            payable(address(this)),
            oracle
        );
        emit EthXmrContractCreation(clone, Monero_Withdrawal_Address);
    }

    function CreateXmrEthContract(
        address Ethereum_Withdrawal_Address
    ) external {
        address clone = Clones.clone(implementation2);
        XMR_ETH_CONTRACTS[clone] = msg.sender;
        XMR_ETH(clone).initialize(
            Ethereum_Withdrawal_Address,
            payable(address(this)),
            oracle
        );
        emit XmrEthContractCreation(clone, Ethereum_Withdrawal_Address);
    }

    function EthereumReceived(
        address depositAddress,
        uint256 amount,
        string memory encryptedMoneroAddress
    ) external OnlyEthXmrContracts {
        require(amount > 0, "no eth deposited");
        uint256 rate = CalculateExchangeRate();
        require(rate > 0, "failed to get exchange rate");
        emit EthDeposit(depositAddress, amount, encryptedMoneroAddress, rate);
    }

    function MoneroReceived(
        uint256 amountReceived,
        address withdrawalAddress
    ) external OnlyXmrEthContracts nonReentrant returns (uint256) {
        uint256 rate = CalculateExchangeRate();

        require(rate > 0, "failed to get exchange rate");

        uint256 amountReceivedAfterFee = (amountReceived * 99) / 100;

        uint256 withdrawalAmount = (amountReceivedAfterFee * rate) / 1e12;

        require(
            address(this).balance >= withdrawalAmount,
            "Insufficient ETH Balance"
        );

        payable(withdrawalAddress).transfer(withdrawalAmount);

        emit EthereumWithdrawal(withdrawalAddress, withdrawalAmount);

        return (withdrawalAmount);
    }

    function CalculateExchangeRate()
        public
        view
        returns (uint256 exchangeRate)
    {
        // Fetch the latest ETH/USD price
        (, int256 ethPrice, , , ) = eth_usd_price.latestRoundData();
        // Fetch the latest XMR/USD price
        (, int256 xmrPrice, , , ) = xmr_usd_price.latestRoundData();

        // Ensure the price data is valid
        require(ethPrice > 0 && xmrPrice > 0, "Invalid price data");

        // Get the decimals for each price feed
        uint8 ethDecimals = eth_usd_price.decimals();
        uint8 xmrDecimals = xmr_usd_price.decimals();

        // Adjust prices to have 18 decimals.
        // For example, if ethPrice has 8 decimals, multiply by 10^(18-8)=10^10.
        uint256 adjustedEthPrice = uint256(ethPrice) *
            (10 ** (18 - ethDecimals));
        uint256 adjustedXmrPrice = uint256(xmrPrice) *
            (10 ** (18 - xmrDecimals));

        // Compute the exchange rate: (XMR/USD) / (ETH/USD)
        // Multiply by 1e18 to maintain 18 decimals in the result.
        exchangeRate = (adjustedXmrPrice * 1e18) / adjustedEthPrice;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Bridge is Context, Ownable, ReentrancyGuard {
    address public bridge;
    address public token;
    uint256 public bridgeFee; // 0.01 bnb, 2.5 matic
    uint256 public claimFee;  // 0.01 bnb, 2.5 matic
    uint256 public minBridgeAmount; //     10 000 Strat
    uint256 public maxBridgeAmount; // 20 000 000 Strat

    mapping(address => uint256) public claimable;
    uint256 public totalClaimable;

    bool public paused;
    event BridgeTokens(address from, address to, uint256 amount);
    event ClaimTokens(address to, uint256 amount);
    event TransferedBack(address to, uint256 amount);

    constructor(
        address _bridge,
        address _token,
        uint256 _minBridgeAmount,
        uint256 _maxBridgeAmount,
        uint256 _bridgeFee,
        uint256 _claimFee
    ) {
        bridge = _bridge;
        token = _token;
        minBridgeAmount = _minBridgeAmount;
        maxBridgeAmount = _maxBridgeAmount;
        bridgeFee = _bridgeFee;
        claimFee = _claimFee;
    }

    function setMinBridgeAmount(uint256 _minBridgeAmount) external onlyOwner {
        minBridgeAmount = _minBridgeAmount;
    }

    function setMaxBridgeAmount(uint256 _maxBridgeAmount) external onlyOwner {
        maxBridgeAmount = _maxBridgeAmount;
    }

    function setBridgeFee(uint256 _fee) public onlyOwner {
        bridgeFee = _fee;
    }

    function setClaimFee(uint256 _fee) public onlyOwner {
        claimFee = _fee;
    }

    function setBridge(address _bridge) public onlyOwner {
        bridge = _bridge;
    }

    function setToken(address _token) public onlyOwner {
        token = _token;
    }

    function setPaused(bool _paused) public onlyBridgeOrOwner {
        paused = _paused;
    }

    modifier onlyBridgeOrOwner() {
        require(
            msg.sender == bridge || msg.sender == owner(),
            "Bridge: caller is not the bridge or owner"
        );
        _;
    }

    modifier onlyBridge() {
        require(_msgSender() == bridge, "Bridge: caller is not the bridge");
        _;
    }

    modifier notPaused() {
        require(!paused, "Bridge: paused");
        _;
    }

    function withdraw(
        address _token,
        address to,
        uint256 amount
    ) public onlyOwner {
        IERC20(_token).transfer(to, amount);
    }

    function unlock(address to, uint256 amount) public onlyBridge nonReentrant {
        claimable[to] += amount;
        totalClaimable += amount;
    }

    function bridgeTokens(
        address to,
        uint256 amount
    ) public payable notPaused nonReentrant {
        require(msg.value == bridgeFee, "Bridge: fee is not correct");
        require(amount > 0, "Bridge: amount must be greater than 0");
        require(
            amount >= minBridgeAmount,
            "Bridge: amount must be greater than minBridgeAmount"
        );
        require(
            amount <= maxBridgeAmount,
            "Bridge: amount must be less than maxBridgeAmount"
        );
        require(
            IERC20(token).balanceOf(_msgSender()) >= amount,
            "Bridge: insufficient balance"
        );
        bool transfered = IERC20(token).transferFrom(
            _msgSender(),
            address(this),
            amount
        );

        bool feeSent = payable(bridge).send(msg.value);
        require(transfered && feeSent, "Bridge: transfer failed");
        emit BridgeTokens(_msgSender(), to, amount);
    }

    function transferBack(address to, uint256 amount) public onlyBridge {
        bool transfered = IERC20(token).transfer(to, amount);
        require(transfered, "Bridge: transfer failed");
        emit TransferedBack(to, amount);
    }

    function claim() public payable nonReentrant {
        require(msg.value == claimFee, "Bridge: fee is not correct");
        require(
            claimable[_msgSender()] > 0,
            "Bridge: insufficient claimable balance"
        );
        require(
            bridgeBalanceWithoutClaimable() >= claimable[_msgSender()],
            "Bridge: insufficient bridge balance"
        );
        require(totalClaimable >= claimable[_msgSender()], "Bridge: overflow");
        bool transfered = IERC20(token).transfer(
            _msgSender(),
            claimable[_msgSender()]
        );
        bool feeSent = payable(bridge).send(msg.value);

        require(transfered && feeSent, "Bridge: transfer failed");
        emit ClaimTokens(_msgSender(), claimable[_msgSender()]);
        totalClaimable -= claimable[_msgSender()];
        claimable[_msgSender()] = 0;
    }

    function bridgeBalanceWithoutClaimable() internal view returns (uint256) {
        return bridgeBalance() - totalClaimable;
    }

    function bridgeBalance() public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}

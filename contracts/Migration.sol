// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract StratMigration is Ownable, ReentrancyGuard {
    uint256 public totalMigrated;
    address public oldStrat;
    address public newStrat;
    mapping(address => bool) public blacklisted;

    constructor(address _oldStrat, address _newStrat) {
        oldStrat = _oldStrat;
        newStrat = _newStrat;
    }

    function setOldStrat(address _oldStrat) public onlyOwner {
        oldStrat = _oldStrat;
    }

    function setNewStrat(address _newStrat) public onlyOwner {
        newStrat = _newStrat;
    }

    function setBlackListed(
        address _address,
        bool _blacklisted
    ) public onlyOwner {
        blacklisted[_address] = _blacklisted;
    }

    function withdrawToken(address token, uint256 amount) public onlyOwner {
        require(token != address(0), "token is zero address");
        require(
            IERC20(token).balanceOf(address(this)) >= amount,
            "not enough token"
        );
        bool success = IERC20(token).transfer(msg.sender, amount);
        require(success, "transfer failed");
    }

    function getOldBalance(address _address) internal view returns (uint256) {
        return IERC20(oldStrat).balanceOf(_address);
    }

    function availableStrat() public view returns (uint256) {
        return IERC20(newStrat).balanceOf(address(this));
    }

    function migrate() public nonReentrant notBlacklisted {
        uint256 amount = getOldBalance(msg.sender);
        require(amount > 0, "Nothing to migrate");
        require(amount <= availableStrat(), "Not enough Strat in contract");

        bool oldTransSuccessful = IERC20(oldStrat).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        bool transSuccessful = IERC20(newStrat).transfer(msg.sender, amount);
        require(oldTransSuccessful && transSuccessful, "Transfer failed");
        totalMigrated += amount;
    }

    modifier notBlacklisted() {
        require(!blacklisted[msg.sender], "Blacklisted");
        _;
    }
}

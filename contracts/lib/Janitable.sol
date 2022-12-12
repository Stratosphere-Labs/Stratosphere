// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@opengsn/contracts/src/ERC2771Recipient.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Janitable is ERC2771Recipient, Initializable {
    address private _janitor;
    address private _previousJanitor;
    uint256 private _lockTimeJanitor;

    event JanitorTransferred(
        address indexed previousJanitor,
        address indexed newJanitor
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial janitor.
     */
    function initialize(
        address new_janitor,
        address trustedForwarder
    ) public virtual onlyInitializing {
        _janitor = new_janitor;
        emit JanitorTransferred(address(0), new_janitor);
        _setTrustedForwarder(trustedForwarder);
    }

    /**
     * @dev Returns the address of the current janitor.
     */
    function janitor() public view returns (address) {
        return _janitor;
    }

    /**
     * @dev Throws if called by any account other than the janitor.
     */
    modifier onlyJanitor() {
        require(
            _janitor == _msgSender(),
            "Janitable: caller is not the janitor"
        );
        _;
    }

    /**
     * @dev Leaves the contract without janitor. It will not be possible to call
     * `onlyJanitor` functions anymore. Can only be called by the current janitor.
     */
    function renounceJanitorship() public virtual onlyJanitor {
        emit JanitorTransferred(_janitor, address(0));
        _janitor = address(0);
    }

    /**
     * @dev Transfers janitorship of the contract to a new account (`newJanitor`).
     * Can only be called by the current janitor.
     */
    function transferJanitorship(
        address newJanitor
    ) public virtual onlyJanitor {
        require(
            newJanitor != address(0),
            "Janitable: new janitor is the zero address"
        );
        emit JanitorTransferred(_janitor, newJanitor);
        _janitor = newJanitor;
    }

    function getUnlockTimeJanitor() public view returns (uint256) {
        return _lockTimeJanitor;
    }

    function lockJanitor(uint256 time) public virtual onlyJanitor {
        // Locks the contract for janitor for the amount of time provided
        _previousJanitor = _janitor;
        _janitor = address(0);
        _lockTimeJanitor = block.timestamp + time;
        emit JanitorTransferred(_janitor, address(0));
    }

    function unlockJanitor() public virtual {
        // Unlocks the contract for janitor when _lockTime is exceeds
        require(
            _previousJanitor == msg.sender,
            "You don't have permission to unlock"
        );
        require(
            block.timestamp > _lockTimeJanitor,
            "Contract is locked until 7 days"
        );
        emit JanitorTransferred(_janitor, _previousJanitor);
        _janitor = _previousJanitor;
    }

    function setTrustedForwarder(address forwarder) public virtual onlyJanitor {
        _setTrustedForwarder(forwarder);
    }
}

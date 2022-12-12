// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Dummy is ERC20 {
    constructor() ERC20("Dummy", "DUMM") {
        _mint(msg.sender, 2000000000 * 10 ** decimals());
    }

    function decimals() public view virtual override returns (uint8) {
        return 9;
    }
}

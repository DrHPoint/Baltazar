// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract EBGG is ERC20, AccessControl {
    bytes32 public constant CHOISEN_ROLE = keccak256("CHOISEN_ROLE");

    constructor() ERC20("EBGG", "EBGG") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CHOISEN_ROLE, msg.sender);
    }

    function mint(address to, uint256 amount) public onlyRole(CHOISEN_ROLE) {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyRole(CHOISEN_ROLE) {
        _mint(from, amount);
    }

    function setChoisenRole(address user) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(CHOISEN_ROLE, user);
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        revert ("NON_TRANSFERABLE");
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        revert ("NON_TRANSFERABLE");
    }

    
}


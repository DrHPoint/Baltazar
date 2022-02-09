// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract EBGG is ERC20, AccessControl {

    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for ERC20;

    struct Clame {
        uint64 blockingPeriod;
        uint192 amountClame;
    }

    bytes32 public constant CHOISEN_ROLE = keccak256("CHOISEN_ROLE");
    address public generalTokenAddress;

    mapping(address => Clame[]) private clames;
    mapping(address => uint256) private currentPoint;


    constructor(address _generalTokenAddress) ERC20("EBGG", "EBGG") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CHOISEN_ROLE, msg.sender);
        generalTokenAddress = _generalTokenAddress;
    }

    function mint(address to, uint256 amount) public onlyRole(CHOISEN_ROLE) {
        _mint(to, amount);
        clames[to].push(Clame(uint64(block.timestamp + 365 days), uint192(amount)));
    }

    function burn(address from, uint256 amount) public onlyRole(CHOISEN_ROLE) {
        _burn(from, amount);
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

    function swap() public{
        require(currentPoint[msg.sender] < clames[msg.sender].length, "All claimes swaped");
        Clame storage clame = clames[msg.sender][currentPoint[msg.sender]];
        require(clame.blockingPeriod <= block.timestamp, "For earliest clame swap yet not awailable");
        uint256 summaryAmount;
        while(clame.blockingPeriod <= block.timestamp)
        {
            summaryAmount += clame.amountClame;
            if(++currentPoint[msg.sender] == clames[msg.sender].length)
                break;
            clame = clames[msg.sender][currentPoint[msg.sender]];
        }
        _burn(msg.sender, summaryAmount);
        ERC20(generalTokenAddress).safeTransfer(msg.sender, summaryAmount);
    }
}


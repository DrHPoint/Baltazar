//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./EBGG.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title A Stacking contract.
 * @author Pavel E. Hrushchev (DrHPoint).
 * @notice You can use this contract for working with stacking.
 * @dev All function calls are currently implemented without side effects.
 */
contract Staking is AccessControl, ERC20 {
    
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;
    
    /** EDIT
     * @notice Shows that the user stake some tokens to contract.
     * @param user is the address of user.
     * @param amount is an amount of tokens which stakes to contract.
     * @param amountWithWeight is a weight of tokens in contract.
     */
    event Stake(address user, uint256 amount, uint256 amountWithWeight);

    /** EDIT
     * @notice Shows that the user unstake some tokens from contract.
     * @param user is the address of user.
     * @param amount is an amount of tokens which unstakes from contract.
     * @param claimAmount is an amount of reward tokens which claim from contract.
     */
    event Unstake(address user, uint256 amount, uint256 claimAmount);

    /** EDIT
     * @notice Shows that the user claim some reward tokens from contract.
     * @param user is the address of user.
     * @param amount is an amount of reward tokens which claim from contract.
     */
    event Claim(address user, uint256 amount);

    /** 
    * @notice Shows that the admin set new parametres of reward on contract.
    * @param reward is an amount of reward tokens 
    that will be paid to all of user in some epoch.
    * @param epochDuration is the length of time for which the reward is distributed.
    */
    event SetParametres(uint256 reward, uint256 epochDuration);

    struct Account {
        uint256 amountStake; //the number of tokens that the user has staked
        uint256 amountStakesWithWeight; //the number of tokens that the user has staked
        uint256 missedReward; //the number of reward tokens that the user missed
    }

    struct ViewData{
        address BGGAddress;
        address rewardAddress;
        uint256 rewardAtEpoch;
        uint128 epochDuration;
        uint128 minReceiveRewardDuration;
    }

    struct StakeInfo{
        uint256 blockingPeriod;
        uint256 amount;
        uint256 amountWithWeight;
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 public tps;
    uint256 public rewardAtEpoch;
    uint128 public epochDuration;

    uint128 private minReceiveRewardDuration; //the minimum period of time for which the reward is received
    uint256 private precision = 1e18;
    uint256 private maxLockDuration = 52 weeks; 
    uint256 private lastTimeEditedTPS;
    uint256 private stakeId = 0;
    uint256 private totalAmountStake;
    uint256 private totalAmountStakeWithWeight;

    address public BGGAddress;
    address public rewardAddress;

    mapping(address => Account) public accounts;
    mapping(address => mapping(uint256 => StakeInfo)) private stakes;
    mapping(address => EnumerableSet.UintSet) private accountsToStakes;

    constructor(
        address _BGGAddress,
        address _rewardAddress,
        uint256 _rewardAtEpoch,
        uint128 _epochDuration,
        uint128 _minReceiveRewardDuration
    ) ERC20(
        "SBGG", 
        "SBGG"
    ) checkEpoch(
        _epochDuration,
        _minReceiveRewardDuration
    ) {
        require (_epochDuration >= _minReceiveRewardDuration);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        rewardAtEpoch = _rewardAtEpoch;
        epochDuration = _epochDuration;
        BGGAddress = _BGGAddress;
        rewardAddress = _rewardAddress;
        minReceiveRewardDuration = _minReceiveRewardDuration;
        lastTimeEditedTPS = block.timestamp;
    }

    modifier checkEpoch(
        uint256 _epochDuration,
        uint256 _minReceiveRewardDuration
    ) {
        require (_epochDuration >= _minReceiveRewardDuration, "Incorrect parametres");
        _;
    }

    /** EDIT
    * @notice With this function user can stake some amount of token to contract.
    * @dev It is worth paying attention to the fact that if the tokens were unstaked before, 
    these tokens will be deducted from the parameter "missedReward". 
    * @param _amount is an amount of tokens which stakes to contract.
    */
    function stake(uint256 _amount, uint256 _blockingPeriod) external {
        require(_amount > 0, "Not enough to deposite");
        uint256 amountWithWeight = _amount * (precision + (precision * _blockingPeriod / maxLockDuration)) / precision;
        stakes[msg.sender][stakeId] = (StakeInfo(
            block.timestamp + _blockingPeriod,
            _amount,
            amountWithWeight
        ));
        accountsToStakes[msg.sender].add(stakeId++);
        IERC20(BGGAddress).safeTransferFrom(msg.sender, address(this), _amount);
        update();
        accounts[msg.sender].amountStakesWithWeight += amountWithWeight;
        accounts[msg.sender].amountStake += _amount;
        accounts[msg.sender].missedReward += amountWithWeight * tps;
        totalAmountStakeWithWeight += amountWithWeight;
        totalAmountStake += _amount;
        _mint(msg.sender, amountWithWeight);
        emit Stake(msg.sender, _amount, amountWithWeight);
    }

    /** 
    * @notice With this function user can unstake stake of token with some id from contract.
    * @dev It is worth paying attention to the fact that the accumulated rewards 
    are stored in the parameter "accumulate". 
    * @param _idStake is the id stake of tokens which stakes to contract before.
    */
    function unstake(uint256 _idStake) external {
        require(stakes[msg.sender][_idStake].blockingPeriod <= block.timestamp, "Too early to unstake stake with this address");
        uint256 amountWithWeight = stakes[msg.sender][_idStake].amountWithWeight;
        uint256 amount = stakes[msg.sender][_idStake].amount;
        IERC20(BGGAddress).safeTransfer(msg.sender, amount);
        _burn(msg.sender, amountWithWeight);
        update();
        Account storage acc = accounts[msg.sender];
        uint256 claiming = (tps *
            acc.amountStakesWithWeight -
            acc.missedReward) / precision;
        EBGG(rewardAddress).mint(msg.sender, claiming);
        acc.amountStakesWithWeight -= amountWithWeight;
        acc.amountStake -= amount;
        acc.missedReward =
            tps *
            acc.amountStakesWithWeight;
        totalAmountStake -= amount;
        totalAmountStakeWithWeight -= amountWithWeight;
        accountsToStakes[msg.sender].remove(_idStake);
        emit Unstake(msg.sender, amount, claiming);
    }

    ///@notice With this function user can claim some amount of reward tokens from contract.  EDIT++
    function claim() external {
        update();
        uint256 amount = (tps *
            accounts[msg.sender].amountStakesWithWeight -
            accounts[msg.sender].missedReward) / precision;
        EBGG(rewardAddress).mint(msg.sender, amount);
        accounts[msg.sender].missedReward += amount * precision;
        emit Claim(msg.sender, amount);
    }

    /**
     * @notice With this function admin can set new parameters of rewarding users to contract.
     * @dev This function can only be called by users with the ADMIN_ROLE role.
     * @param _reward is an amount of reward tokens that will be paid to all of user in new epoch.
     * @param _epochDuration is the length of time for which the reward is distributed.
     * @param _minReceiveRewardDuration the minimum period of time for which the reward is received.
     */
    function setParametres(
        uint256 _reward,
        uint128 _epochDuration,
        uint128 _minReceiveRewardDuration
    ) external onlyRole(ADMIN_ROLE) checkEpoch(
        _epochDuration,
        _minReceiveRewardDuration
    ) {
        update();
        epochDuration = _epochDuration;
        rewardAtEpoch = _reward;
        minReceiveRewardDuration = _minReceiveRewardDuration;
        emit SetParametres(_reward, _epochDuration);
    }

    /** 
    * @notice With this function user can see information 
    about contract, including tokens addresses,
    amount of reward tokens, that will be paid to all of user in some epoch,
    duration of epoch and the minimum period of time for which the reward is received.
    * @return viewData - structure with information about contract.
    */
    function getViewData()
        external
        view
        onlyRole(ADMIN_ROLE)
        returns (ViewData memory viewData)
    {
        viewData = (ViewData(
            BGGAddress,
            rewardAddress,
            rewardAtEpoch,
            epochDuration,
            minReceiveRewardDuration
        ));
    }

    /** 
    * @notice With this function user can see information 
    of user with certain address, including amount of staked tokens,
    missed rewards and how many reward tokens can be claimed.
    * @param _account is the address of some user.
    * @return account - structure with information about user.
    */
    function getAccount(address _account)
        external
        view
        returns (Account memory account, uint reward, uint256[] memory numberStakes, StakeInfo[] memory acccountStakes)
    {
        account = (Account(
            accounts[_account].amountStake,
            accounts[_account].amountStakesWithWeight,
            accounts[_account].missedReward
        ));
        reward = availableReward(_account);
        uint256 pointer = accountsToStakes[_account].length();
        numberStakes = new uint256[](pointer);
        acccountStakes = new StakeInfo[](pointer);
        for(uint256 i=0; i<pointer; i++) {
            numberStakes[i] = accountsToStakes[_account].at(i);
            acccountStakes[i] = stakes[_account][numberStakes[i]];
        }
    }

    /**
     * @notice This function update value of tps.
     * @dev This function is public in case of emergency.
     */
    function update() public {
        uint256 amountOfDuration = (block.timestamp - lastTimeEditedTPS) /
            minReceiveRewardDuration;
        lastTimeEditedTPS += minReceiveRewardDuration * amountOfDuration;
        if (totalAmountStake > 0)
            tps =
                tps +
                ((rewardAtEpoch * minReceiveRewardDuration * precision) /
                    (totalAmountStakeWithWeight * epochDuration)) *
                amountOfDuration;
    }

    function mint(address to, uint256 amount) public onlyRole(ADMIN_ROLE) {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyRole(ADMIN_ROLE) {
        _burn(from, amount);
    }

    function setAdminRole(address user) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(ADMIN_ROLE, user);
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

    /** 
    * @notice With this function contract can previously see how many reward tokens 
    can be claimed of user with certain address.
    * @param _account is the address of some user.
    * @return amount - An amount of reward tokens that can be claimed.
    */
    function availableReward(address _account)
        internal
        view
        returns (uint256 amount)
    {
        uint256 amountOfDuration = (block.timestamp - lastTimeEditedTPS) /
            minReceiveRewardDuration;
        uint256 currentTPS = tps +
            ((rewardAtEpoch * minReceiveRewardDuration * precision) /
                (totalAmountStake * epochDuration)) *
            amountOfDuration;
        amount =
            (currentTPS *
                accounts[_account].amountStakesWithWeight -
                accounts[_account].missedReward) /
            precision;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract xpndStaking is Ownable, ReentrancyGuard, AccessControl {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    // setReward will add to default reward buckets 0, 1, 2 and 3 
    // when no pool is active
    uint256[4] public defaultRewardBuckets;
    
    struct PoolConfig {
        uint32 periodStaking;               // days
        uint256 proportionalRewardShare;    // proportion of all rewards
    }

    // This will be updated in addPool when createPools
    // is called 4 times with the values in constructor
    PoolConfig[] public poolTypes;

    // Info of each pool instance when a new pool is created.
    struct PoolInfo {
        uint8 poolType;
        uint256 startOfDeposit;     // timestamp
        uint32 timeAccepting;       // hours
        uint256 totalStaked;
        uint256 poolReward;
        uint16  poolInstance; 
        mapping(address => StakeInfo) poolStakeByAddress;
    }
    
    mapping(uint16 => PoolInfo) poolById;

    // these lists will store poolInstance Ids
    mapping(uint8 => uint16[]) listOfAllPoolIds;

    // 
    // Whenever manager starts new pool counter will increase
    uint16 public poolInstanceCounter;
    // Whenever a new stake is created counter will increase
    uint16 public stakeIdCounter;

    // total weightage of all reward pools
    uint256 public totalRewardPercent;

    // Info of each stake
    struct StakeInfo {
        uint16 poolInstance;
        uint256 stakeAmount;
        bool settled;
    }

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    
    IERC20 public token;

    mapping(uint16 => StakeInfo) stakeById;

    mapping(address => uint16[]) stakesIdsByOwnerAddress;
    mapping(string => bytes32) internal Roles;

    event AddDeposit(address indexed user, uint256 indexed poolInstance, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed poolInstance, uint256 amount);

    constructor (IERC20 _token) {
        token = _token;
        token.balanceOf(address(this));

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);

        createPools();
    }

    // Start staking
    function startStaking(uint8 _poolType, uint32 _timeAccepting) external onlyRole(MANAGER_ROLE) {
        require(_poolType < poolTypes.length, "Invalid poolInstance");

        uint256 poolIDLength = listOfAllPoolIds[_poolType].length;

        if (poolIDLength == 0) {
            createPoolInstance(_poolType, _timeAccepting);
        } else {
            uint16 latestPoolId = listOfAllPoolIds[_poolType][poolIDLength - 1];
            PoolInfo storage latestPool = poolById[latestPoolId];
            // check if latest pool has closed
            require(latestPool.startOfDeposit + latestPool.timeAccepting * 3600 + poolTypes[_poolType].periodStaking * 24 * 3600 < block.timestamp, "Latest pool has closed");
            
            createPoolInstance(_poolType, _timeAccepting);
        }
    }

    // Set reward amount.
    function setRewards(uint256 _amount) external onlyRole(MANAGER_ROLE) {
        require(_amount > 0 , "err _amount=0");

        uint256 oldBalance = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 newBalance = token.balanceOf(address(this));
        _amount = newBalance - oldBalance;
        
        for (uint8 poolType = 0; poolType < poolTypes.length; ++poolType) {
            if (listOfAllPoolIds[poolType].length == 0) {
                defaultRewardBuckets[poolType] += _amount * poolTypes[poolType].proportionalRewardShare / totalRewardPercent;
            } else {
                uint256 poolInstanceLength = listOfAllPoolIds[poolType].length;
                uint16 poolId = listOfAllPoolIds[poolType][poolInstanceLength - 1];
                if (poolTypes[poolType].periodStaking * 24 * 3600 + poolById[poolId].timeAccepting * 3600 + poolById[poolId].startOfDeposit > block.timestamp) {
                    poolById[poolId].poolReward += _amount * poolTypes[poolType].proportionalRewardShare / totalRewardPercent;
                }
                else {
                    defaultRewardBuckets[poolType] += _amount * poolTypes[poolType].proportionalRewardShare / totalRewardPercent;
                }
            }
        }
    }

    // Deposit tokens to Defi for Reward allocation.
    function addDeposit(uint8 _poolType, uint256 _amount) external nonReentrant {
        require(_poolType < poolTypes.length, "err _poolType is invalid");
        require(_amount > 0 , "err _amount=0");

        uint16[] memory poolInstances = listOfAllPoolIds[_poolType];
        require(poolInstances.length > 0, "No active pool");

        uint16 latestPoolId = poolInstances[poolInstances.length - 1];
        PoolInfo storage poolInfo = poolById[latestPoolId];

        require(poolInfo.startOfDeposit < block.timestamp, "Accepting deposit is not started yet.");
        require(poolInfo.startOfDeposit + poolInfo.timeAccepting * 3600 > block.timestamp, "Accepting deposit is ended.");
        
        uint256 oldBalance = token.balanceOf(address(this));
        token.safeTransferFrom(address(msg.sender), address(this), _amount);
        uint256 newBalance = token.balanceOf(address(this));
        _amount = newBalance.sub(oldBalance);
        
        poolInfo.totalStaked += _amount;

        StakeInfo storage stakeInfo = poolInfo.poolStakeByAddress[msg.sender];
        if (stakeInfo.poolInstance == 0) {
            stakeIdCounter++;
            stakesIdsByOwnerAddress[msg.sender].push(stakeIdCounter);

            poolInfo.poolStakeByAddress[msg.sender] = StakeInfo({
                poolInstance: latestPoolId,
                stakeAmount: _amount,
                settled: false
            });
        }
        else {
            stakeInfo.poolInstance = latestPoolId;
            stakeInfo.stakeAmount += _amount;
            stakeInfo.settled = false;
        }

        stakeById[stakeIdCounter] = stakeInfo;

        emit AddDeposit(msg.sender, _poolType, _amount);
    }

    // Withdraw tokens from DeFi.
    function withdrawStake(uint16 _stakeId) external nonReentrant {
        require(_stakeId <= stakeIdCounter, "Invalid stakeID");

        StakeInfo storage stakeInfo = stakeById[_stakeId];
        PoolInfo storage poolInfo = poolById[stakeInfo.poolInstance];
        PoolConfig memory poolConfig = poolTypes[poolInfo.poolType];

        require(poolInfo.startOfDeposit + poolInfo.timeAccepting * 3600 + poolConfig.periodStaking * 24 * 3600 < block.timestamp, "Withdraw is locked");
        require(stakeInfo.settled == false, "Reward is already paid out");

        uint256 rewardAmount = poolInfo.poolReward * stakeInfo.stakeAmount / poolInfo.totalStaked;
        token.safeTransfer(msg.sender, stakeInfo.stakeAmount + rewardAmount);

        stakeInfo.settled = true;

        emit Withdraw(msg.sender, _stakeId, stakeInfo.stakeAmount + rewardAmount);
    }

    // Get rewards by stake id.
    function getRewards(uint16 _stakeId) external view returns ( uint256 ) {
        require(_stakeId <= stakeIdCounter, "Invalid stakeID");

        StakeInfo memory stakeInfo = stakeById[_stakeId];
        PoolInfo storage poolInfo = poolById[stakeInfo.poolInstance];

        require(stakeInfo.settled == false, "Reward is already paid out");

        uint256 rewardAmount = poolInfo.poolReward * stakeInfo.stakeAmount / poolInfo.totalStaked;

        return rewardAmount;
    }

    // Create 4 types of pool
    function createPools() internal {
        addPool(30, 250);
        addPool(90, 1000);
        addPool(180, 2250);
        addPool(360, 6500);
    }

    // Add a new pool type. Can only be called by the owner. e.x. 30days, 90days, 180days, 365days
    function addPool(uint32 _periodStaking, uint256 _rewardPercent) internal {
        require(_periodStaking <= 365, "periodStaking must be less than 365 days");

        totalRewardPercent = totalRewardPercent + _rewardPercent;
        poolTypes.push(PoolConfig({
            periodStaking: _periodStaking,
            proportionalRewardShare: _rewardPercent
        }));
    }

    function createPoolInstance(uint8 _poolType, uint32 _timeAccepting) internal {
        poolInstanceCounter++;
        listOfAllPoolIds[_poolType].push(poolInstanceCounter);

        // Add all the pool information to pool by Id mapping
        poolById[poolInstanceCounter].poolType = _poolType;
        poolById[poolInstanceCounter].poolInstance = poolInstanceCounter;
        poolById[poolInstanceCounter].startOfDeposit = block.timestamp;
        poolById[poolInstanceCounter].timeAccepting = _timeAccepting;
        poolById[poolInstanceCounter].totalStaked = 0;
        poolById[poolInstanceCounter].poolReward = defaultRewardBuckets[_poolType];

        // we have transferred all accumulated pool 1 rewards to new pool
        defaultRewardBuckets[_poolType] = 0;
    }

    function stringToBytes32(string memory source) internal pure returns (bytes32 result) {
        bytes memory _S = bytes(source);

        return keccak256(_S);
    }

    function getTotalDepositTokenAmount(uint8 _poolType) external view onlyRole(MANAGER_ROLE) returns (uint256)
    {
        uint256 poolIdAmount = 0;
        uint16[] memory poolInstances = listOfAllPoolIds[_poolType];
        for (uint256 index = 0; index < poolInstances.length; index++) {
            uint16 stakedId = poolInstances[index];
            poolIdAmount += poolById[stakedId].totalStaked;
        }
        return poolIdAmount;
    }

    function getPeriodStaking(uint8 _poolType) external view returns (uint32) {
        return poolTypes[_poolType].periodStaking;
    }

    function getTimeAccepting(uint8 _poolType) external view returns (uint32) {
        uint16[] memory poolIDs = listOfAllPoolIds[_poolType];
        uint16 lastPoolId = poolIDs[poolIDs.length - 1];
        return poolById[lastPoolId].timeAccepting;
    }

    function getAllStakes(address _user) external view returns (uint16[] memory) {
        require( _user != address(0), "Address can't be a zero address");
        return stakesIdsByOwnerAddress[_user];
    }

    function poolLength() external view returns (uint256) {
        return poolTypes.length;
    }

    function setRole(string memory role, address _add) public onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 _role = stringToBytes32(role);
        Roles[role] = _role;
        _setupRole(_role, _add);
    }

    function revokeRole(string memory role, address _revoke) public onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 _role = stringToBytes32(role);
        Roles[role] = _role;
        _revokeRole(_role, _revoke);
    }
}
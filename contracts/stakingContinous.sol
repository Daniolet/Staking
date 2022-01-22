//SPDX-License-Identifier:  MIT
pragma solidity 0.8.10;
pragma experimental ABIEncoderV2;

import "./timelib.sol";
import "./math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract xyztokenStableCoinFund {
    struct stakeType {
        uint8 Type;
        uint32 percentageReturn;
        uint48 minAmount;
        uint48 maxAmount;
    }
    struct stake {
        bool active;
        bool partialWithdrawn;
        bool settled;
        uint8 Type;
        address ownerAddress;
        uint32 startOfTerm;
        uint32 id;
        uint32 linkedStakeID;
        uint48 xyztokenAmount;
        uint48 settlementAmount;
        uint48 stakeReturns;
    }

    IERC20 xyztokenToken;
    uint8 currentStakeType;
    address owner;
    uint32 currentStakeID;
    uint48 currentStakedXyzTokenAmount;
    uint48 totalProfitsDistrubuted;
    uint48 totalStakedXyzTokenAmount;

    event AddStake(
        uint8 _Type,
        address _stakeOwner,
        uint32 _startofTerm,
        uint32 _stakeID,
        uint48 _xyztokenAmount
    );

    event ReStake(
        uint8 _Type,
        address _stakeOwner,
        uint32 _startOfTerm,
        uint32 _stakeID,
        uint48 _xyztokenAmount,
        uint32 _linkedStakeID
    );

    event WithdrawStake(
        bool _active,
        bool _partialWithdrawn,
        bool _settled,
        uint32 _stakeID
    );

    mapping(uint32 => stake) stakeByID;
    mapping(address => uint32[]) stakeByOwnerAddress;
    mapping(uint32 => stakeType) stakeTypes;
    mapping(uint32 => bool) stakeTypeAlreadyExists;

    constructor(address _token) {
        xyztokenToken = IERC20(_token);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function getCurrentCountOfStakeTypes()
        external
        view
        onlyOwner
        returns (uint32 currentStakeTypes)
    {
        return currentStakeType;
    }

    function getCurrentStakeID()
        external
        view
        onlyOwner
        returns (uint32 currentStakeId)
    {
        return currentStakeID;
    }

    function getStakeType(uint32 _stakeType)
        external
        view
        onlyOwner
        returns (stakeType memory)
    {
        return stakeTypes[_stakeType];
    }

    function getBalance() external view onlyOwner returns (uint256) {
        return xyztokenToken.balanceOf(address(this));
    }

    function getStakesByAddress(address _user)
        external
        view
        onlyOwner
        returns (uint32[] memory)
    {
        require(
            _user != address(0),
            "XYZTOKENFUND:Address can't be a zero address"
        );
        return stakeByOwnerAddress[_user];
    }

    function getTotalStaked()
        external
        view
        returns (uint48 totalXyzTokenAmountStaked)
    {
        return totalStakedXyzTokenAmount;
    }

    function getTotalProfitsDistributed()
        external
        view
        returns (uint48 totalProfits)
    {
        return totalProfitsDistrubuted;
    }

    function getCurrentStakedAmount()
        external
        view
        returns (uint48 currentStakedXyzToken)
    {
        return currentStakedXyzTokenAmount;
    }

    function getMyStakes() external view returns (uint32[] memory) {
        return stakeByOwnerAddress[msg.sender];
    }

    function getStakeDetailsByStakeID(uint32 _stakeID)
        external
        view
        returns (stake memory)
    {
        return stakeByID[_stakeID];
    }

    function addStakeType(
        uint32 _percentageReturn,
        uint48 _minAmount,
        uint48 _maxAmount
    ) external onlyOwner {
        currentStakeType += 1;
        require(
            stakeTypeAlreadyExists[currentStakeType] == false,
            "This stakeType already exists"
        );
        stakeTypes[currentStakeType].Type = currentStakeType;
        stakeTypes[currentStakeType].percentageReturn = _percentageReturn;
        stakeTypes[currentStakeType].minAmount = _minAmount;
        stakeTypes[currentStakeType].maxAmount = _maxAmount;
        stakeTypeAlreadyExists[currentStakeType] = true;
    }

    function updateStakeType(
        uint8 _stakeType,
        uint32 _percentageReturn,
        uint48 _minAmount,
        uint48 _maxAmount
    ) external onlyOwner {
        require(
            stakeTypeAlreadyExists[_stakeType] == true,
            "This stakeType doesn't exists"
        );
        stakeTypes[_stakeType].percentageReturn = _percentageReturn;
        stakeTypes[_stakeType].minAmount = _minAmount;
        stakeTypes[_stakeType].maxAmount = _maxAmount;
    }

    function ClaimToInvest() external onlyOwner {
        xyztokenToken.approve(
            address(this),
            xyztokenToken.balanceOf(address(this))
        );
        xyztokenToken.transferFrom(
            address(this),
            owner,
            xyztokenToken.balanceOf(address(this))
        );
    }

    function addStake(uint48 _amount, uint8 _type) external {
        require(stakeTypeAlreadyExists[_type], "The Stake type doesn't exist");

        if (stakeTypes[_type].maxAmount > stakeTypes[_type].minAmount) {
            require(
                _amount >= stakeTypes[_type].minAmount &&
                    _amount <= stakeTypes[_type].maxAmount,
                "Staked amount is more than maximum amount specified for the stake"
            );
        } else if (stakeTypes[_type].maxAmount < stakeTypes[_type].minAmount) {
            require(
                _amount >= stakeTypes[_type].minAmount,
                "staked amount is too less, kindly stake the minimum tokens for the stake type selected."
            );
        }

        require(
            xyztokenToken.balanceOf(msg.sender) >= _amount,
            "Insufficient XyzToken Balance.Please buy more XYZTOKEN Tokens."
        );
        // stakeID counter update
        currentStakeID += 1;
        //Transfer xyztoken tokens from the msg.sender(stake owner) to the contract
        xyztokenToken.transferFrom(msg.sender, address(this), _amount);
        // set stake attributes
        stakeByID[currentStakeID].active = true;
        stakeByID[currentStakeID].Type = _type;
        stakeByID[currentStakeID].ownerAddress = msg.sender;
        stakeByID[currentStakeID].startOfTerm = uint32(block.timestamp);
        stakeByID[currentStakeID].id = currentStakeID;
        stakeByID[currentStakeID].xyztokenAmount = _amount;
        // Update global variable
        stakeByOwnerAddress[msg.sender].push(currentStakeID);
        totalStakedXyzTokenAmount += _amount;
        currentStakedXyzTokenAmount += _amount;
        emit AddStake(
            _type,
            stakeByID[currentStakeID].ownerAddress,
            stakeByID[currentStakeID].startOfTerm,
            stakeByID[currentStakeID].id,
            stakeByID[currentStakeID].xyztokenAmount
        );
    }

    function reStake(
        uint48 _amount,
        uint8 _type,
        uint32 _linkedStakeID
    ) internal {
        require(stakeTypeAlreadyExists[_type], "The Stake type doesn't exist");
        if (stakeTypes[_type].maxAmount > stakeTypes[_type].minAmount) {
            require(
                _amount >= stakeTypes[_type].minAmount &&
                    _amount <= stakeTypes[_type].maxAmount,
                "Stake amount < minimim || > maximum"
            );
        } else if (stakeTypes[_type].maxAmount < stakeTypes[_type].minAmount) {
            require(
                _amount >= stakeTypes[_type].minAmount,
                "staked amount is too less."
            );
        }
        // stakeID counter update
        currentStakeID += 1;
        // set stake attributes
        stakeByID[currentStakeID].active = true;
        stakeByID[currentStakeID].Type = _type;
        stakeByID[currentStakeID].ownerAddress = msg.sender;
        stakeByID[currentStakeID].startOfTerm = uint32(block.timestamp);
        stakeByID[currentStakeID].id = currentStakeID;
        stakeByID[currentStakeID].xyztokenAmount = _amount;
        stakeByID[currentStakeID].linkedStakeID = _linkedStakeID;
        // Update global variable
        stakeByOwnerAddress[msg.sender].push(currentStakeID);
        totalStakedXyzTokenAmount += _amount;
        currentStakedXyzTokenAmount += _amount;
        emit ReStake(
            _type,
            stakeByID[currentStakeID].ownerAddress,
            stakeByID[currentStakeID].startOfTerm,
            stakeByID[currentStakeID].id,
            stakeByID[currentStakeID].xyztokenAmount,
            stakeByID[currentStakeID].linkedStakeID
        );
    }

    function withdraw(
        uint32 _stakeID,
        bool _full,
        uint48 _withdrawAmount
    ) external {
        require(
            stakeByID[_stakeID].ownerAddress == msg.sender,
            "Unauthorized Stake owner"
        );
        require(stakeByID[_stakeID].active == true, "Stake was settled");
        uint256 periods = BokkyPooBahsDateTimeLibrary.diffMinutes(
            uint256(stakeByID[_stakeID].startOfTerm),
            uint256(block.timestamp)
        );
        require(periods >= 1, "Stake can't be claimed now");
        uint256 totalReturns = compound(
            stakeByID[_stakeID].xyztokenAmount,
            (stakeTypes[stakeByID[_stakeID].Type].percentageReturn * (10**8)),
            periods
        );

        uint256 stakeReturns = totalReturns -
            stakeByID[_stakeID].xyztokenAmount;

        if (_full == true) {
            stakeByID[_stakeID].partialWithdrawn = false;
            stakeByID[_stakeID].settlementAmount = uint48(totalReturns);
            stakeByID[_stakeID].stakeReturns = uint48(stakeReturns);
        } else {
            stakeByID[_stakeID].settlementAmount = _withdrawAmount;
        }

        require(
            _withdrawAmount <= stakeByID[_stakeID].settlementAmount,
            "Amount to claim is higher than returns"
        );

        if (
            _full == true &&
            stakeByID[_stakeID].settlementAmount <=
            xyztokenToken.balanceOf(address(this))
        ) {
            // Transfer the xyztoken tokens to the stake owner.
            xyztokenToken.approve(
                address(this),
                stakeByID[_stakeID].settlementAmount
            );

            xyztokenToken.transferFrom(
                address(this),
                msg.sender,
                stakeByID[_stakeID].settlementAmount
            );
            //Update the global variables
            currentStakedXyzTokenAmount -= stakeByID[_stakeID].xyztokenAmount;
            totalProfitsDistrubuted += stakeByID[_stakeID].stakeReturns;
            // set the stake attributes
            stakeByID[_stakeID].active = false;
            stakeByID[_stakeID].settled = true;
            emit WithdrawStake(
                stakeByID[_stakeID].active,
                stakeByID[_stakeID].partialWithdrawn,
                stakeByID[_stakeID].settled,
                _stakeID
            );
        } else if (
            _full == true &&
            stakeByID[_stakeID].settlementAmount >=
            xyztokenToken.balanceOf(address(this))
        ) {
            // set the stake attributes
            stakeByID[_stakeID].active = false;
            emit WithdrawStake(
                stakeByID[_stakeID].active,
                stakeByID[_stakeID].partialWithdrawn,
                stakeByID[_stakeID].settled,
                _stakeID
            );
        } else if (
            _full == false &&
            stakeByID[_stakeID].settlementAmount <=
            xyztokenToken.balanceOf(address(this))
        ) {
            // Transfer the xyztoken tokens to the stake owner.

            xyztokenToken.approve(
                address(this),
                stakeByID[_stakeID].settlementAmount
            );

            xyztokenToken.transferFrom(
                address(this),
                msg.sender,
                stakeByID[_stakeID].settlementAmount
            );
            // Update the global variables
            currentStakedXyzTokenAmount -= stakeByID[_stakeID].xyztokenAmount;
            // set the stake attributes
            stakeByID[_stakeID].active = false;
            stakeByID[_stakeID].partialWithdrawn = true;
            stakeByID[_stakeID].settled = true;

            emit WithdrawStake(
                stakeByID[_stakeID].active,
                stakeByID[_stakeID].partialWithdrawn,
                stakeByID[_stakeID].settled,
                _stakeID
            );
            // restake with the remaining amount
            uint8 Type = stakeByID[_stakeID].Type;
            uint256 reStakeAmount = totalReturns -
                (stakeByID[_stakeID].settlementAmount);
            reStake(uint48(reStakeAmount), Type, _stakeID);
        } else if (
            _full == false &&
            stakeByID[_stakeID].settlementAmount >=
            xyztokenToken.balanceOf(address(this))
        ) {
            // set the stake attributes
            stakeByID[_stakeID].active = false;
            stakeByID[_stakeID].partialWithdrawn = true;
            emit WithdrawStake(
                stakeByID[_stakeID].active,
                stakeByID[_stakeID].partialWithdrawn,
                stakeByID[_stakeID].settled,
                _stakeID
            );
        }
    }

    function compound(
        uint256 principal,
        uint256 ratio,
        uint256 n
    ) internal pure returns (uint256) {
        return
            ABDKMath64x64.mulu(
                ABDKMath64x64.pow(
                    ABDKMath64x64.add(
                        ABDKMath64x64.fromUInt(1),
                        ABDKMath64x64.divu(ratio, 100 * 10**8)
                    ),
                    n
                ),
                principal
            );
    }

    function settleStakes(uint32[] memory _stakeIDs) external onlyOwner {
        for (uint256 i = 0; i < _stakeIDs.length; i++) {
            if (
                stakeByID[_stakeIDs[i]].active == true &&
                stakeByID[_stakeIDs[i]].partialWithdrawn == false
            ) {
                xyztokenToken.approve(
                    address(this),
                    stakeByID[_stakeIDs[i]].settlementAmount
                );

                xyztokenToken.transferFrom(
                    address(this),
                    stakeByID[_stakeIDs[i]].ownerAddress,
                    stakeByID[_stakeIDs[i]].settlementAmount
                );

                currentStakedXyzTokenAmount -= stakeByID[_stakeIDs[i]]
                    .settlementAmount;
                stakeByID[_stakeIDs[i]].active = false;
            }
        }
    }
}

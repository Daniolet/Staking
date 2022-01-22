//SPDX-License-Identifier:  MIT
pragma solidity 0.8.10;
pragma experimental ABIEncoderV2;

import "./timelib.sol";
import "./math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract variableRateCompoundedStaking {
    using Strings for uint256;

    struct stake {
        bool active;
        bool partialWithdrawn;
        bool settled;
        address ownerAddress;
        uint32 startOfTerm;
        uint32 id;
        uint32 linkedStakeID;
        uint48 xyztokenAmount;
        uint48 settlementAmount;
        uint48 stakeReturns;
    }
    struct interest {
        uint8 rate;
        uint32 tStamp;
        uint32 iDate;
    }

    IERC20 xyztokenToken;
    address owner;
    uint32 currentStakeID;
    uint48 currentStakedXyzTokenAmount;
    uint48 totalProfitsDistrubuted;
    uint48 totalStakedXyzTokenAmount;
    uint256 termInterval = 24 * 60 * 60;

    event AddStake(
        address _stakeOwner,
        uint32 _startofTerm,
        uint32 _stakeID,
        uint48 _xyztokenAmount
    );

    event ReStake(
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
    mapping(uint32 => interest) dailyInterest;
    mapping(uint32 => bool) dailyInterestAlreadyExist;

    constructor(address _token) {
        xyztokenToken = IERC20(_token);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function getCurrentStakeID()
        external
        view
        onlyOwner
        returns (uint32 currentStakeId)
    {
        return currentStakeID;
    }

    function getInterestDaily(uint32 tStamp) external view onlyOwner returns (interest memory) {
        require(dailyInterestAlreadyExist[tStamp], "Daily Interest does not exist.");

        return dailyInterest[tStamp];
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

    function getCurrentTimestamp()
        external
        view
        returns (uint256)
    {
        return block.timestamp;
    }

    function getWithdrawableAmount(uint32 _stakeID)
        external
        view
        returns (uint256)
    {
        uint256 periods = BokkyPooBahsDateTimeLibrary.diffDays(
            uint256(stakeByID[_stakeID].startOfTerm),
            uint256(block.timestamp)
        );

        (uint year, uint month, uint day) = BokkyPooBahsDateTimeLibrary.timestampToDate(block.timestamp);
        uint256 startOfTerm = BokkyPooBahsDateTimeLibrary.timestampFromDate(year, month, day);

        uint256 totalReturns = compound(
            stakeByID[_stakeID].xyztokenAmount,
            startOfTerm,
            periods
        );

        return totalReturns;
    }

    function setInterestDaily(
        uint8 rate,
        uint32 tStamp
    ) external onlyOwner {
        (uint year, uint month, uint day) = BokkyPooBahsDateTimeLibrary.timestampToDate(tStamp);
        uint32 i_date = (uint32(day)) * 10 ** 4 + (uint32(month)) * 100 + (uint32(year));
        dailyInterest[tStamp].rate = rate;
        dailyInterest[tStamp].tStamp = tStamp;
        dailyInterest[tStamp].iDate = i_date;

        dailyInterestAlreadyExist[tStamp] = true;
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

    function addStake(uint48 _amount) external {
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
        stakeByID[currentStakeID].ownerAddress = msg.sender;
        stakeByID[currentStakeID].startOfTerm = uint32(block.timestamp);
        stakeByID[currentStakeID].id = currentStakeID;
        stakeByID[currentStakeID].xyztokenAmount = _amount;
        // Update global variable
        stakeByOwnerAddress[msg.sender].push(currentStakeID);
        totalStakedXyzTokenAmount += _amount;
        currentStakedXyzTokenAmount += _amount;
        emit AddStake(
            stakeByID[currentStakeID].ownerAddress,
            stakeByID[currentStakeID].startOfTerm,
            stakeByID[currentStakeID].id,
            stakeByID[currentStakeID].xyztokenAmount
        );
    }

    function reStake(
        uint48 _amount,
        uint32 _linkedStakeID
    ) internal {
        // stakeID counter update
        currentStakeID += 1;
        // set stake attributes
        stakeByID[currentStakeID].active = true;
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
        uint256 periods = BokkyPooBahsDateTimeLibrary.diffDays(
            uint256(stakeByID[_stakeID].startOfTerm),
            uint256(block.timestamp)
        );
        require(periods >= 1, "Stake can't be claimed now");

        (uint year, uint month, uint day) = BokkyPooBahsDateTimeLibrary.timestampToDate(block.timestamp);
        uint256 startOfTerm = BokkyPooBahsDateTimeLibrary.timestampFromDate(year, month, day);

        uint256 totalReturns = compound(
            stakeByID[_stakeID].xyztokenAmount,
            startOfTerm,
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

        if (!_full) {
            require(
                _withdrawAmount <= stakeByID[_stakeID].settlementAmount,
                "Amount to claim is higher than returns"
            );
        }

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
            uint256 reStakeAmount = totalReturns -
                (stakeByID[_stakeID].settlementAmount);
            reStake(uint48(reStakeAmount), _stakeID);
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

    function beforeCompound(
        uint256 startOfTerm,
        uint256 n
    ) internal view returns (bool) {
        for (uint256 i = 0; i < n; i++) {
            uint32 tStamp = uint32(startOfTerm + i * termInterval);
            (uint year, uint month, uint day) = BokkyPooBahsDateTimeLibrary.timestampToDate(tStamp);
            require(
                dailyInterestAlreadyExist[tStamp],
                string(abi.encodePacked('Owner does not set interest of ', day.toString(), '/', month.toString(), '/', year.toString()))
            );
        }
        return true;
    }

    function compound(
        uint256 principal,
        uint256 startOfTerm,
        uint256 n
    ) internal view returns (uint256) {
        uint256 ret = 10 ** 8;

        for (uint256 i = 0; i < n; i++) {
            uint32 tStamp = uint32(startOfTerm + i * termInterval);

            uint8 rate = 0;
            if (dailyInterestAlreadyExist[tStamp]) {
                rate = dailyInterest[tStamp].rate;
            }

            ret = ABDKMath64x64.mulu(
                ABDKMath64x64.add(
                    ABDKMath64x64.fromUInt(1),
                    ABDKMath64x64.divu(dailyInterest[tStamp].rate, 100)
                ),
                ret
            );
        }

        return ABDKMath64x64.mulu(ABDKMath64x64.divu(ret, 10 ** 8), principal);
    }

    function settleStakes(uint32[] memory _stakeIDs) external onlyOwner {
        for (uint256 i = 0; i < _stakeIDs.length; i++) {
            if (
                stakeByID[_stakeIDs[i]].active == false
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
                stakeByID[_stakeIDs[i]].active = true;
            }
        }
    }
}

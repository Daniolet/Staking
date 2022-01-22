//SPDX-License-Identifier:  MIT
pragma solidity 0.8.10;
pragma experimental ABIEncoderV2;

import "./timelib.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract xyztokenFund {
    using SafeMath for uint256;

    IERC20 xyztokenToken;
    address owner;
    uint256 currentStakeID;
    uint256 currentStakedXyzTokenAmount;
    uint256 totalProfitsDistrubuted;
    uint256 totalStakedXyzTokenAmount;
    uint256 currentStakeType;

    struct stakeType {
        uint256 Type;
        uint256 term;
        uint256 percentageReturn; // Annual interest rate.
        uint256 penaltyAmount;
        uint256 penaltyPercentage;
        uint256 minAmount;
        uint256 maxAmount;
    }

    struct stake {
        uint256 id;
        address ownerAddress;
        bool active;
        bool cancelled;
        bool matured;
        bool settled;
        uint256 xyztokenAmount;
        uint256 startOfTerm;
        uint256 endOfTerm;
        uint256 Type;
        uint256 settlementAmount;
        uint256 stakeReturns;
    }

    event AddStakeType(
        uint256 indexed _type,
        uint256 _term,
        uint256 _percentageReturn,
        uint256 _penalityAmount,
        uint256 _penalityPercentage,
        uint256 _minAmount,
        uint256 _maxAmount
    );
    event UpdateStakeType(
        uint256 indexed _type,
        uint256 _term,
        uint256 _percentageReturn,
        uint256 _penaltyAmount,
        uint256 _penaltyPercentage,
        uint256 _minAmount,
        uint256 _maxAmount
    );
    event AddStake(
        uint256 _stakeID,
        address indexed _stakeOwner,
        bool _active,
        bool _cancelled,
        bool _matured,
        bool _settled,
        uint256 _xyztokenAmount,
        uint256 _startofTerm,
        uint256 _endOfTerm,
        uint256 _Type
    );
    event CancelStake(
        address indexed _stakeOwner,
        uint256 indexed _stakeID,
        bool _cancelled,
        bool _settled,
        uint256 _settlementAmount
    );
    event CancelSettled(
        address indexed _stakeOwner,
        uint256 indexed _stakeID,
        bool _cancelled,
        bool _settled,
        uint256 _settlementAmount
    );
    event ClaimStake(
        address indexed _stakeOwner,
        uint256 indexed _stakeID,
        bool _cancelled,
        bool _matured,
        bool _settled,
        uint256 _settlementAmount,
        uint256 _stakeReturns
    );
    event ClaimSettled(
        address indexed _stakeOwner,
        uint256 indexed _stakeID,
        bool _cancelled,
        bool _matured,
        bool _settled,
        uint256 _settlementAmount,
        uint256 _stakeReturns
    );
    event SettleStakes(
        uint256 indexed _stakeID,
        bool _cancelled,
        bool _matured,
        bool _settled
    );

    mapping(uint256 => stake) StakeByID;
    mapping(address => uint256[]) stakeByOwnerAddress;
    mapping(uint256 => stakeType) stakeTypes;
    mapping(uint256 => bool) stakeTypeAlreadyExists;

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
        returns (uint256 currentStakeTypes)
    {
        return currentStakeType;
    }

    function getCurrentStakeID()
        external
        view
        onlyOwner
        returns (uint256 currentStakeId)
    {
        return currentStakeID;
    }

    function getStakeType(uint256 _stakeType)
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
        returns (uint256[] memory)
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
        returns (uint256 totalXyzTokenAmountStaked)
    {
        return totalStakedXyzTokenAmount;
    }

    function getTotalProfitsDistributed()
        external
        view
        returns (uint256 totalProfits)
    {
        return totalProfitsDistrubuted;
    }

    function getCurrentStakedAmount()
        external
        view
        returns (uint256 currentStakedXyzToken)
    {
        return currentStakedXyzTokenAmount;
    }

    function getMyStakes() external view returns (uint256[] memory) {
        return stakeByOwnerAddress[msg.sender];
    }

    function getStakeDetailsByStakeID(uint256 _stakeID)
        external
        view
        returns (stake memory)
    {
        return StakeByID[_stakeID];
    }

    function addStakeType(
        uint256 _term,
        uint256 _percentageReturn,
        uint256 _penaltyAmount,
        uint256 _penaltyPercentage,
        uint256 _minAmount,
        uint256 _maxAmount
    ) external onlyOwner {
        currentStakeType += 1;
        require(
            stakeTypeAlreadyExists[currentStakeType] == false,
            "This stakeType already exists"
        );
        stakeTypes[currentStakeType].Type = currentStakeType;
        stakeTypes[currentStakeType].term = _term;
        stakeTypes[currentStakeType].percentageReturn = _percentageReturn;
        stakeTypes[currentStakeType].penaltyAmount = _penaltyAmount;
        stakeTypes[currentStakeType].penaltyPercentage = _penaltyPercentage;
        stakeTypes[currentStakeType].minAmount = _minAmount;
        stakeTypes[currentStakeType].maxAmount = _maxAmount;
        stakeTypeAlreadyExists[currentStakeType] = true;
        emit AddStakeType(
            currentStakeType,
            _term,
            _percentageReturn,
            _penaltyAmount,
            _penaltyPercentage,
            _minAmount,
            _maxAmount
        );
    }

    function updateStakeType(
        uint256 _stakeType,
        uint256 _term,
        uint256 _percentageReturn,
        uint256 _penaltyAmount,
        uint256 _penaltyPercentage,
        uint256 _minAmount,
        uint256 _maxAmount
    ) external onlyOwner {
        require(
            stakeTypeAlreadyExists[_stakeType] == true,
            "This stakeType doesn't exists"
        );
        stakeTypes[_stakeType].term = _term;
        stakeTypes[_stakeType].percentageReturn = _percentageReturn;
        stakeTypes[_stakeType].penaltyAmount = _penaltyAmount;
        stakeTypes[_stakeType].penaltyPercentage = _penaltyPercentage;
        stakeTypes[_stakeType].minAmount = _minAmount;
        stakeTypes[_stakeType].maxAmount = _maxAmount;
        emit UpdateStakeType(
            _stakeType,
            _term,
            _percentageReturn,
            _penaltyAmount,
            _penaltyPercentage,
            _minAmount,
            _maxAmount
        );
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

    function calculateReturnsForCancelledStake(uint256 _stakeID)
        private
        view
        returns (uint256 amountToTransfer)
    {
        uint256 penalty = stakeTypes[StakeByID[_stakeID].Type]
            .penaltyAmount
            .add(
                StakeByID[_stakeID].xyztokenAmount.div(100).mul(
                    stakeTypes[StakeByID[_stakeID].Type].penaltyPercentage
                )
            );
        return StakeByID[_stakeID].xyztokenAmount.sub(penalty);
    }

    function calculateReturnsForMaturedStakes(uint256 _stakeID)
        private
        view
        returns (uint256, uint256)
    {
        uint256 percentageReturn = stakeTypes[StakeByID[_stakeID].Type]
            .percentageReturn;
        uint256 stakeReturns = (
            StakeByID[_stakeID].xyztokenAmount.mul(percentageReturn)
        ).div(100);
        uint256 settlementAmount = StakeByID[_stakeID].xyztokenAmount.add(
            stakeReturns
        );
        return (settlementAmount, stakeReturns);
    }

    function addStake(uint256 _amount, uint256 _Type) public {
        require(stakeTypeAlreadyExists[_Type], "The Stake type doesn't exist");
        if (stakeTypes[_Type].maxAmount > stakeTypes[_Type].minAmount) {
            require(
                _amount >= stakeTypes[_Type].minAmount &&
                    _amount <= stakeTypes[_Type].maxAmount,
                "Staked amount is more than maximum amount specified for the stake"
            );
        } else if (stakeTypes[_Type].maxAmount < stakeTypes[_Type].minAmount) {
            require(
                _amount >= stakeTypes[_Type].minAmount,
                "staked amount is too less, kindly stake the minimum tokens for the stake type selected."
            );
        }
        require(
            xyztokenToken.balanceOf(msg.sender) >= _amount,
            "Insufficient XyzToken Balance. Please buy more XYZTOKEN Tokens."
        );
        currentStakeID += 1;
        xyztokenToken.transferFrom(msg.sender, address(this), _amount);
        StakeByID[currentStakeID].Type = _Type;
        StakeByID[currentStakeID].id = currentStakeID;
        StakeByID[currentStakeID].ownerAddress = msg.sender;
        StakeByID[currentStakeID].active = true;
        StakeByID[currentStakeID].cancelled = false;
        StakeByID[currentStakeID].matured = false;
        StakeByID[currentStakeID].settled = false;
        StakeByID[currentStakeID].xyztokenAmount = _amount;
        StakeByID[currentStakeID].startOfTerm = block.timestamp;
        uint256 end = BokkyPooBahsDateTimeLibrary.addMinutes(
            StakeByID[currentStakeID].startOfTerm,
            stakeTypes[StakeByID[currentStakeID].Type].term
        );
        StakeByID[currentStakeID].endOfTerm = end;
        stakeByOwnerAddress[msg.sender].push(currentStakeID);
        totalStakedXyzTokenAmount += _amount;
        currentStakedXyzTokenAmount += _amount;
        emit AddStake(
            currentStakeID,
            StakeByID[currentStakeID].ownerAddress,
            StakeByID[currentStakeID].active,
            StakeByID[currentStakeID].cancelled,
            StakeByID[currentStakeID].matured,
            StakeByID[currentStakeID].settled,
            StakeByID[currentStakeID].xyztokenAmount,
            StakeByID[currentStakeID].startOfTerm,
            StakeByID[currentStakeID].endOfTerm,
            StakeByID[currentStakeID].Type
        );
    }

    function cancelStake(uint256 _stakeID) public {
        require(
            StakeByID[_stakeID].ownerAddress == msg.sender,
            "Not an authorized Stake owner."
        );
        require(StakeByID[_stakeID].cancelled == false, "Stake was cancelled.");
        require(
            StakeByID[_stakeID].matured == false,
            "Stake is matured. Cannot cancel a matured stake "
        );
        require(
            block.timestamp < StakeByID[_stakeID].endOfTerm,
            "Can't cancel the stake as it's matured already"
        );
        uint256 amountToTransfer = calculateReturnsForCancelledStake(_stakeID);
        StakeByID[_stakeID].settlementAmount = amountToTransfer;
        if (
            StakeByID[_stakeID].settlementAmount >
            xyztokenToken.balanceOf(address(this))
        ) {
            StakeByID[_stakeID].cancelled = true;
            StakeByID[_stakeID].active = false;
            StakeByID[_stakeID].matured = false;
            StakeByID[_stakeID].settled = false;
            emit CancelStake(
                StakeByID[_stakeID].ownerAddress,
                _stakeID,
                StakeByID[_stakeID].cancelled,
                StakeByID[_stakeID].settled,
                StakeByID[_stakeID].settlementAmount
            );
        } else {
            xyztokenToken.approve(
                address(this),
                StakeByID[_stakeID].settlementAmount
            );
            xyztokenToken.transferFrom(
                address(this),
                msg.sender,
                StakeByID[_stakeID].settlementAmount
            );
            currentStakedXyzTokenAmount -= StakeByID[_stakeID].xyztokenAmount;
            StakeByID[_stakeID].active = false;
            StakeByID[_stakeID].cancelled = true;
            StakeByID[_stakeID].matured = false;
            StakeByID[_stakeID].settled = true;
            emit CancelSettled(
                StakeByID[_stakeID].ownerAddress,
                _stakeID,
                StakeByID[_stakeID].cancelled,
                StakeByID[_stakeID].settled,
                StakeByID[_stakeID].settlementAmount
            );
        }
    }

    function claimMyStake(uint256 _stakeID) public {
        require(
            StakeByID[_stakeID].ownerAddress == msg.sender,
            "Not an authorized user to claim the stake"
        );
        require(
            StakeByID[_stakeID].settled == false,
            "Stake is settled already."
        );
        if (StakeByID[_stakeID].cancelled == true) {
            xyztokenToken.approve(
                address(this),
                StakeByID[_stakeID].settlementAmount
            );
            xyztokenToken.transferFrom(
                address(this),
                msg.sender,
                StakeByID[_stakeID].settlementAmount
            );
            currentStakedXyzTokenAmount -= StakeByID[_stakeID].xyztokenAmount;
            StakeByID[_stakeID].active = false;
            StakeByID[_stakeID].cancelled = true;
            StakeByID[_stakeID].matured = false;
            StakeByID[_stakeID].settled = true;
            emit ClaimSettled(
                StakeByID[_stakeID].ownerAddress,
                _stakeID,
                StakeByID[_stakeID].cancelled,
                StakeByID[_stakeID].matured,
                StakeByID[_stakeID].settled,
                StakeByID[_stakeID].settlementAmount,
                StakeByID[_stakeID].stakeReturns
            );
        } else if (
            block.timestamp > StakeByID[_stakeID].endOfTerm &&
            StakeByID[_stakeID].cancelled == false
        ) {
            (
                uint256 totalReturns,
                uint256 stakeReturns
            ) = calculateReturnsForMaturedStakes(_stakeID);
            StakeByID[_stakeID].settlementAmount = totalReturns;
            StakeByID[_stakeID].stakeReturns = stakeReturns;
            if (
                StakeByID[_stakeID].settlementAmount >
                xyztokenToken.balanceOf(address(this))
            ) {
                StakeByID[_stakeID].matured = true;
                StakeByID[_stakeID].active = false;
                StakeByID[_stakeID].cancelled = false;
                StakeByID[_stakeID].settled = false;
                emit ClaimStake(
                    msg.sender,
                    _stakeID,
                    StakeByID[_stakeID].cancelled,
                    StakeByID[_stakeID].matured,
                    StakeByID[_stakeID].settled,
                    totalReturns,
                    stakeReturns
                );
            } else if (
                StakeByID[_stakeID].settlementAmount <
                xyztokenToken.balanceOf(address(this))
            ) {
                totalProfitsDistrubuted += stakeReturns;
                currentStakedXyzTokenAmount -= StakeByID[_stakeID].xyztokenAmount;
                xyztokenToken.approve(
                    address(this),
                    StakeByID[_stakeID].settlementAmount
                );
                xyztokenToken.transferFrom(
                    address(this),
                    StakeByID[_stakeID].ownerAddress,
                    StakeByID[_stakeID].settlementAmount
                );
                StakeByID[_stakeID].active = false;
                StakeByID[_stakeID].cancelled = false;
                StakeByID[_stakeID].matured = true;
                StakeByID[_stakeID].settled = true;
                emit ClaimSettled(
                    msg.sender,
                    _stakeID,
                    StakeByID[_stakeID].cancelled,
                    StakeByID[_stakeID].matured,
                    StakeByID[_stakeID].settled,
                    totalReturns,
                    stakeReturns
                );
            }
        }
    }

    function settleStakes(uint256[] memory _stakeIDs) public onlyOwner {
        for (uint256 i = 0; i < _stakeIDs.length; i++) {
            if (
                StakeByID[_stakeIDs[i]].cancelled == true &&
                StakeByID[_stakeIDs[i]].settled == false
            ) {
                xyztokenToken.approve(
                    address(this),
                    StakeByID[_stakeIDs[i]].settlementAmount
                );
                xyztokenToken.transferFrom(
                    address(this),
                    msg.sender,
                    StakeByID[_stakeIDs[i]].settlementAmount
                );
                currentStakedXyzTokenAmount -= StakeByID[_stakeIDs[i]]
                    .xyztokenAmount;
                StakeByID[_stakeIDs[i]].active = false;
                StakeByID[_stakeIDs[i]].cancelled = true;
                StakeByID[_stakeIDs[i]].matured = false;
                StakeByID[_stakeIDs[i]].settled = true;
                emit SettleStakes(
                    _stakeIDs[i],
                    StakeByID[_stakeIDs[i]].cancelled,
                    StakeByID[_stakeIDs[i]].matured,
                    StakeByID[_stakeIDs[i]].settled
                );
            } else if (
                StakeByID[_stakeIDs[i]].matured == true &&
                StakeByID[_stakeIDs[i]].settled == false
            ) {
                currentStakedXyzTokenAmount -= StakeByID[_stakeIDs[i]]
                    .xyztokenAmount;
                totalProfitsDistrubuted += StakeByID[_stakeIDs[i]].stakeReturns;
                xyztokenToken.approve(
                    address(this),
                    StakeByID[_stakeIDs[i]].settlementAmount
                );
                xyztokenToken.transferFrom(
                    address(this),
                    StakeByID[_stakeIDs[i]].ownerAddress,
                    StakeByID[_stakeIDs[i]].settlementAmount
                );
                StakeByID[_stakeIDs[i]].active = false;
                StakeByID[_stakeIDs[i]].cancelled = false;
                StakeByID[_stakeIDs[i]].matured = true;
                StakeByID[_stakeIDs[i]].settled = true;
                emit SettleStakes(
                    _stakeIDs[i],
                    StakeByID[_stakeIDs[i]].cancelled,
                    StakeByID[_stakeIDs[i]].matured,
                    StakeByID[_stakeIDs[i]].settled
                );
            }
        }
    }
}

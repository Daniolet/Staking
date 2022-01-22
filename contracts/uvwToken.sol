// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract BlackList is Ownable, ERC20 {
    /////// Getters to allow the same blacklist to be used also by other contracts (including upgraded Tether) ///////
    function getBlackListStatus(address maker) external view returns (bool) {
        return isBlackListed[maker];
    }

    function getOwner() external view returns (address) {
        return owner();
    }

    mapping(address => bool) public isBlackListed;

    function addBlackList(address evilUser) public onlyOwner {
        isBlackListed[evilUser] = true;
        emit AddedBlackList(evilUser);
    }

    function removeBlackList(address clearedUser) public onlyOwner {
        isBlackListed[clearedUser] = false;
        emit RemovedBlackList(clearedUser);
    }

    function destroyBlackFunds(address blackListedUser) public onlyOwner {
        require(isBlackListed[blackListedUser], "ERROR: Not Black listed");
        uint256 dirtyFunds = balanceOf(blackListedUser);
        _burn(blackListedUser, dirtyFunds);
        emit DestroyedBlackFunds(blackListedUser, dirtyFunds);
    }

    event DestroyedBlackFunds(address blackListedUser, uint256 balance);

    event AddedBlackList(address user);

    event RemovedBlackList(address user);
}

contract UvwToken is
    ERC20,
    BlackList,
    ERC20Burnable,
    Pausable,
    AccessControl,
    ERC20Permit
{
    string constant TOKEN_NAME = "uvwToken";
    string constant TOKEN_SYMBOL = "UVWT";

    using SafeMath for uint256;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    uint256 public maxSupply;

    uint8 internal constant DECIMAL_PLACES = 10;

    mapping(string => bytes32) internal roles;

    constructor()
        ERC20(TOKEN_NAME, TOKEN_SYMBOL)
        ERC20Permit(TOKEN_NAME)
    {
        maxSupply = 1000000000 * 10**DECIMAL_PLACES; // 1 Billion Tokens ^ 10 decimals

        super._mint(msg.sender, 100000000 * 10**DECIMAL_PLACES);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function pause() external onlyRole(PAUSER_ROLE) returns (bool) {
        _pause();
        return true;
    }

    function unpause() external onlyRole(PAUSER_ROLE) returns (bool) {
        _unpause();
        return true;
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function burnToken(address account, uint256 amount)
        external
        onlyRole(BURNER_ROLE)
    {
        //super.burn(account, amount);
        _burn(account, amount);
    }

    function decimals() public pure override returns (uint8) {
        return DECIMAL_PLACES;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return super.totalSupply();
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return super.balanceOf(account);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20) whenNotPaused {
        require(!isBlackListed[msg.sender], "ERROR: Blacklisted");
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20) {
        require(
            totalSupply() + amount <= maxSupply,
            "Error: Max supply reached, 1 Billion tokens minted."
        );
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20) {
        super._burn(account, amount);
    }

    function stringToBytes32(string memory source)
        internal
        pure
        returns (bytes32 result)
    {
        bytes memory _S = bytes(source);

        return keccak256(_S);
    }

    function setRole(string memory role, address add)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        bytes32 _role = stringToBytes32(role);
        roles[role] = _role;
        _setupRole(_role, add);
    }

    function revokeRole(string memory role, address revoke)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        bytes32 _role = stringToBytes32(role);
        roles[role] = _role;
        _revokeRole(_role, revoke);
    }
}

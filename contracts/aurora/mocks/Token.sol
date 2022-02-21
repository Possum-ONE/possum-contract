// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
/* import "../interfaces/IYToken.sol"; */
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Token is ERC20, Ownable, AccessControl {
    using SafeMath for uint256;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    address Address;
    uint256 rate = 10000;
    mapping(address => uint256) public userAmount;
    constructor(string memory name, string memory symbol, address token) ERC20(name, symbol) {
      Address = token;
      _setupRole(MINTER_ROLE, msg.sender);
    }

    function deposit(uint256 _amount) external {
      SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(Address), msg.sender, address(this), _amount);
      _mint(msg.sender, _amount);
    }
    function withdraw(uint256 _shares) external {
      uint256 share = _shares.mul(rate).div(10000);
      SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(Address), msg.sender, share);
    }

    function setRate(uint256 _rate) external {
      rate = 10000 + _rate;
    }
}

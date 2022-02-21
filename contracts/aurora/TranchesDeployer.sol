// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./TrancheAToken.sol";
import "./interfaces/ITranchesDeployer.sol";
import "./TranchesDeployerStorage.sol";

contract JTranchesDeployer is OwnableUpgradeable, TranchesDeployerStorage, ITranchesDeployer {
    using SafeMathUpgradeable for uint256;

    function initialize() external initializer() {
        OwnableUpgradeable.__Ownable_init();
    }

    function setPossumAddress(address _jYearn) external onlyOwner {
        PossumAddress = _jYearn;
    }

    modifier onlyProtocol() {
        require(msg.sender == PossumAddress, "not");
        _;
    }

    function deployNewTrancheATokens(string memory _nameA,
            string memory _symbolA,
            uint256 _trNum) external override onlyProtocol returns (address) {
        TrancheAToken jTrancheA = new TrancheAToken(_nameA, _symbolA, _trNum);
        jTrancheA.setPossumMinter(msg.sender);
        return address(jTrancheA);
    }

    function deployNewTrancheBTokens(string memory _nameB,
            string memory _symbolB,
            uint256 _trNum) external override onlyProtocol returns (address) {
        TrancheAToken TrancheB = new TrancheAToken(_nameB, _symbolB, _trNum);
        TrancheB.setPossumMinter(msg.sender);
        return address(TrancheB);
    }

    function setNewJYearnTokens(address _newJYearn, address _trAToken, address _trBToken) external onlyOwner {
        require((_newJYearn != address(0)) && (_trAToken != address(0)) && (_trBToken != address(0)), "T");
        TrancheAToken(_trAToken).setPossumMinter(_newJYearn);
        TrancheAToken(_trBToken).setPossumMinter(_newJYearn);
    }

}

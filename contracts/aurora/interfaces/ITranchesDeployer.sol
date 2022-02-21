// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITranchesDeployer {
    function deployNewTrancheATokens(string calldata _nameA, string calldata _symbolA, /*address _sender,*/ uint256 _trNum) external returns (address);
    function deployNewTrancheBTokens(string calldata _nameB, string calldata _symbolB, /*address _sender,*/ uint256 _trNum) external returns (address);
}
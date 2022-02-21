// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPossum {
    event TrancheAddedToProtocol(uint256 trancheNum, address trancheA, address trancheB);
    event TrancheATokenMinted(uint256 trancheNum, address buyer, uint256 amount, uint256 taAmount);
    event TrancheBTokenMinted(uint256 trancheNum, address buyer, uint256 amount, uint256 tbAmount);
    event StopTrancheSuccess(uint256 trancheNum);
    event StopTrancheFail(uint256 trancheNum);
    event TrancheTokenRedemption(uint256 trancheNum, address burner, uint256 userAmount, uint256 feesAmount);
    event TrancheATokenRedemption(uint256 trancheNum, address burner, uint256 userAmount, uint256 feesAmount);
    event TrancheBTokenRedemption(uint256 trancheNum, address burner, uint256 userAmount, uint256 feesAmount);
}

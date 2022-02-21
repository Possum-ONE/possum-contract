// SPDX-License-Identifier: MIT
/**
 * Created on 2022-12-01
 */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PossumStorage is OwnableUpgradeable {
    uint256 public constant E = 1e18;
    uint256 public constant PERCENT_DIVIDER = 10000;  // percentage divider
    uint256 public constant SECONDS_PER_YEAR = 31557600;  // 60 sec * 60 min * 24 h * 365.25 d (leap years included)
    struct TrancheAddresses {
        address buyerCoinAddress;      
        address yTokenAddress;          
        address ATrancheAddress;
        address BTrancheAddress;
    }

    struct TrancheParameters {
        uint256 RISK;
        uint256 maxVaribleToken;
        uint256 minVaribleToken;
        uint256 tranchBTimeout;
        uint256 gamePeriod;
        uint256 lockPeriod;
        uint256 varibleTokenLimit;
        uint256 storedTrancheAPrice;
        uint256 storedTrancheBPrice;
        uint8 underlyingDecimals;
    }

      address public adminToolsAddress;
      address public feesCollectorAddress;
      address public tranchesDeployerAddress;
      struct TranchRunningParams {
          uint256 trancheInitTime;
          bool canRedeem;
          uint16 redemptionPercentage;
          uint256 TranchTotalYToken;
          uint256 TranchTotalOrigToken;
      }
      uint256 public tranchePairsCounter;
      mapping(uint256 => TrancheAddresses) public trancheAddresses;
      mapping(uint256 => TrancheParameters) public trancheParameters;
      mapping (uint256 => TranchRunningParams) public trancheRunningParams;
}

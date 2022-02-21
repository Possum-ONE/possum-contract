// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITrancheTokens {
    function mint(address account, uint256 value) external;
    function burn(uint256 value) external;
}
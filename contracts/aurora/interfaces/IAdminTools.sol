// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAdminTools {
    function isAdmin(address account) external view returns (bool);
    function addAdmin(address account) external;
    function removeAdmin(address account) external;
    function renounceAdmin() external;

    event AdminAdded(address account);
    event AdminRemoved(address account);
}
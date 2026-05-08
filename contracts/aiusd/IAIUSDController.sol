// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAIUSDController {
    function getExecutionWindowInfo(
        address account
    ) external view returns (uint256 managedBalance, uint256 releaseTime);
}

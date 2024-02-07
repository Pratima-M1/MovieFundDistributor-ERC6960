//// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

  contract MappingToArrays {
    // Mapping from uint256 to array of addresses
    mapping(uint256 => uint256[]) private uint256ToArrayMapping;

       // Mapping from two uint256 keys to array of addresses
    mapping(uint256 => mapping(uint256 => uint256[])) private twoKeysToArrayMapping;

    // Function to add an address to the array associated with a uint256 key
    function addToMapping(uint256 key, uint256 value) public {
        uint256ToArrayMapping[key].push(value);
    }

    // Function to get the array associated with a uint256 key
    function getArray(uint256 key) public view returns (uint256[] memory) {
        return uint256ToArrayMapping[key];
    }

    // Function to get the length of the array associated with a uint256 key
    function getArrayLength(uint256 key) public view returns (uint256) {
        return uint256ToArrayMapping[key].length;
    }

    // Function to add an address to the array associated with two uint256 keys
    function addToTwoKeyMapping(uint256 key1, uint256 key2, uint256 value) public {
        twoKeysToArrayMapping[key1][key2].push(value);
    }

    // Function to get the array associated with two uint256 keys
    function getTwoKeyArray(uint256 key1, uint256 key2) public view returns (uint256[] memory) {
        return twoKeysToArrayMapping[key1][key2];
    }

    // Function to get the length of the array associated with two uint256 keys
    function getTwoKeyArrayLength(uint256 key1, uint256 key2) public view returns (uint256) {
        return twoKeysToArrayMapping[key1][key2].length;
    }
}

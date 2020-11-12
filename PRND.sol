// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract PRNG {
    /**
        * @notice Generates a random number between 0 - 100
        * @param seed The seed to generate different number if block.timestamp is same
        * for two or more numbers.
        */
    function importSeedFromThird(uint256 seed) public view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, seed))) % 100;
  
    }

    /**
     * @notice Generates a random number between 0 - 100
     * @param seed The seed to generate different number if block.timestamp is same
     * for two or more numbers.
     * @param salt The salt to randomize the pattern
     */
    function importSeedFromThirdSalt(uint256 seed, uint256 salt)
        public
        view
        returns (uint8)
    {
        uint8 randomNumber = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, seed, salt))) % 100);
        return randomNumber;
    }

    /**
     * @notice Generates a random number between 0 - 100
     * @param seed The seed to generate different number if block.timestamp is same
     * for two or more numbers.
     * @param salt The salt to randomize the pattern
     * @param sugar The sugar same as salt but for more randomization
     */
    function importSeedFromThirdSaltSugar(
        uint256 seed,
        uint256 salt,
        uint256 sugar
    ) public view returns (uint8) {
        uint8 randomNumber = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, seed, salt, sugar))) % 100);
        return randomNumber;
    }
}
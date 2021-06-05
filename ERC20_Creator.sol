pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor(string memory TokenName, string memory TokenSymbol, uint256 initialSupply) ERC20(TokenName, TokenSymbol) {
        _mint(msg.sender, initialSupply);
    }
}
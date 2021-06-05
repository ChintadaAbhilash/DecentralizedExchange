pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "./OrderBookTracker.sol";
import "./OrderBook.sol";

contract MultiTokenWallet{
    address payable public owner;
    mapping (address => uint256) public tokenHoldings;
    
    OrderBookTracker public ObTracker;
    
    constructor (address tracker_address) public payable{
        owner = payable(msg.sender);
        ObTracker = OrderBookTracker(tracker_address);
    }
    
    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }
    
    // Add token to Wallet 
    function addToken(address token_addr) public onlyOwner returns(bool){
        // Token should be an ERC20 token 
        ERC20 token = ERC20(token_addr);
        token.approve(address(this), 1e26);
        require(token.allowance(owner, address(this)) > 0, " You Haven't Allowed Wallet to be Spender ");
        tokenHoldings[token_addr] = 0;
        return true;
    }
    
    // Remove token support from Wallet 
    function removeToken(address token_addr) public onlyOwner returns(bool){
        ERC20 token = ERC20(token_addr);
        require(token.allowance(owner, address(this)) > 0, " You Haven't Added it in Wallet ");
        delete tokenHoldings[token_addr];
        return true;
    }
    
    // Deposit token from address to Wallet 
    function depositToken(address token_addr, uint256 amount) public onlyOwner returns(bool){
        ERC20 token = ERC20(token_addr);
        require(token.allowance(owner, address(this)) > 0, " You Haven't Added it in Wallet ");
        require(token.balanceOf(owner) >= amount , " You Don't have enough balance to Transfer ");
        token.transferFrom(owner,  address(this) , amount);
        // tokenHoldings[token_addr] = amount;
        return true;
    }
    
    // Withdraw token from wallet to address 
    function withdrawToken(address token_addr, uint256 amount) public payable onlyOwner returns(bool){
        ERC20 token = ERC20(token_addr);
        require(token.balanceOf(address(this)) >= amount , " You Don't have enough balance to Withdraw ");
        token.transferFrom(address(this), owner , amount);
        // tokenHoldings[token_addr] -= amount;
        return true;
    }
    
    // Tranfer token from this contract to another contract
    function transfer(address token_addr, address contract_addr, uint256 amount, uint256 order_price) public payable returns(bool){
        ERC20 token = ERC20(token_addr);
        require(token.balanceOf(address(this)) >= amount , " You Don't have enough balance to Withdraw ");
        token.transferFrom(address(this), contract_addr , amount*order_price/1e4);
        // tokenHoldings[token_addr] -= amount;
        return true;
    }
    
    function placeOrder(address quote, address base, uint256 amount, uint256 order_price, bool order_type) public returns(bool){
        // ObTracker.orderBook_to_Tokens[contract_addr];
        address contract_addr = ObTracker.getOrderBooks(quote , base);
        OrderBook tempOrderBook = OrderBook(contract_addr);
        if (order_type){
            transfer(base , contract_addr, amount , order_price);
            tempOrderBook.LimitBuy(amount,order_price,address(this));
        }
        else {
            transfer(quote , contract_addr, amount , 10000);
            tempOrderBook.LimitSell(amount,order_price,address(this));
        }
        return true;
    }
    
    function tokenHoldingsView(address token_addr) public view returns(uint256){
        // require(tokenHoldings[token_addr] != 0, " Token is not added");
        ERC20 token = ERC20(token_addr);
        return token.balanceOf(address(this));
    }
}
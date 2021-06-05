pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./OrderBook.sol";

contract OrderBookTracker{
    address[] public orderBooksList;
    mapping (address => mapping(address => address)) public orderBooks;
    mapping (address => address[]) public orderBook_to_Tokens;
    address public owner;
    
    constructor(){
        owner = msg.sender;
    }
    
    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }
    
    function addOrderBook(address quote_token, address base_token) public returns(bool){
        require(orderBooks[quote_token][base_token] == address(0), " OrderBook Already Present ");
        address orderBookAddr = address(new OrderBook(quote_token , base_token));
        orderBooks[quote_token][base_token] = orderBookAddr;
        orderBooksList.push(orderBookAddr);
        orderBook_to_Tokens[orderBookAddr] = [quote_token , base_token];
        return true;
    }
    
    function removeOrderBook(address quote_token, address base_token) public returns(bool){
        require(orderBooks[quote_token][base_token] != address(0), " OrderBook Not Present ");
        address look_up = orderBooks[quote_token][base_token];
        delete orderBooks[quote_token][base_token];
        delete orderBook_to_Tokens[look_up];
        for(uint i = 0; i < orderBooksList.length; i++){
            if (orderBooksList[i] == look_up){
                orderBooksList[i] = orderBooksList[orderBooksList.length-1];
                orderBooksList.pop();
                break;
            }
        }
        return true;
    }
    
    function getOrderBooks(address quote, address base) public view returns(address){
        return orderBooks[quote][base];
    }
    
    function getTokenOfOrderBook(address contract_addr) public view returns(address[] memory){
        return orderBook_to_Tokens[contract_addr];
    }
}

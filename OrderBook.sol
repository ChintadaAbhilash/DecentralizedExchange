pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

contract OrderBook{
    address public _quote;
    address public _base;
    
    ERC20 quote_token;
    ERC20 base_token;
    
    constructor (address token1, address token2){
        _quote = token1;
        _base = token2;
        
        quote_token = ERC20(_quote);
        quote_token.approve(address(this), 1e26);
        
        base_token = ERC20(_base);
        base_token.approve(address(this), 1e26);
    }
    
    // Basic Struct for Order Details 
    struct orderDetails{
        uint256 quote_amt; // BTC 
        // uint256 base_amt; // USDT 
        uint256 order_price; // BTC/USDT - 40k
        // uint256 order_id;
        address market_maker; // Seller/Buyer Address 
    }
    
    // Order Price => Order Details mappings 
    mapping (uint256 => orderDetails[]) public BuyOrderBook;
    mapping (uint256 => orderDetails[]) public SellOrderBook;
    
    // Should be Maintained in Sorted fashion 
    uint256 [] public BuyOrderPrices;
    uint256 [] public SellOrderPrices;
    
    function LimitBuy(uint256 quote_amt,uint256 order_price,address market_maker) public returns(bool){
        /*
            quote_amt - 2 Eth 
            order price - how much can he pay for 1 Eth ?
        */
        // Can be Bought on Market 
        if (SellOrderPrices.length != 0 && SellOrderPrices[0] <= order_price){
            MarketBuy(quote_amt , order_price, market_maker);
        }
        // Place it in OrderBook
        else{
            placeInBuyOrderBook(quote_amt, order_price, market_maker);
        }
        return true;
    }
    
    function LimitSell(uint256 quote_amt,uint256 order_price, address market_maker) public returns(bool){
        if (BuyOrderPrices.length != 0 && BuyOrderPrices[BuyOrderPrices.length-1] >= order_price){
            MarketSell(quote_amt , order_price, market_maker);
        }
        else{
            placeInSellOrderBook(quote_amt, order_price, market_maker);
        }
        return true;
    }
    
    function MarketBuy(uint256 quote_amt,uint256 order_price, address market_maker) public returns(bool){
        uint256 to_be_bought = quote_amt;
        uint256[] memory SellOrderPrices_mem = SellOrderPrices;
        for(uint i = 0; i < SellOrderPrices_mem.length; i++){
            if(SellOrderPrices_mem[i] <= order_price && to_be_bought > 0){
                orderDetails[] memory oD = SellOrderBook[SellOrderPrices_mem[i]];
                uint256 ordersRemoved = 0;
                for(uint j = 0; j < oD.length; j++){
                    // Single Block can Fill Entire order 
                    if(oD[j].quote_amt > to_be_bought){
                        base_token.transferFrom(address(this) , oD[j].market_maker, oD[j].quote_amt*oD[j].order_price/1e4);
                        oD[j].quote_amt -= to_be_bought;
                        quote_token.transferFrom(address(this) , market_maker, to_be_bought);
                        to_be_bought = 0;
                        SellOrderBook[SellOrderPrices_mem[i]][j-ordersRemoved] = oD[j];
                        break;
                    }
                    else{
                        base_token.transferFrom(address(this) , oD[j].market_maker, oD[j].quote_amt*oD[j].order_price/1e4);
                        quote_token.transferFrom(address(this) , market_maker, oD[j].quote_amt);
                        to_be_bought -= oD[j].quote_amt;
                        oD[j].quote_amt = 0;
                        for (uint k = j - ordersRemoved; k<SellOrderBook[SellOrderPrices_mem[i]].length-1; k++){
                            SellOrderBook[SellOrderPrices_mem[i]][k] = SellOrderBook[SellOrderPrices_mem[i]][k+1];
                        }
                        SellOrderBook[SellOrderPrices_mem[i]].pop();
                        ordersRemoved += 1;
                    }
                    
                    // check if oD is completely exhuasted, then remove key from SellOrderPrices 
                    if (SellOrderBook[SellOrderPrices_mem[i]].length == 0){
                        delete SellOrderBook[SellOrderPrices[0]];
                        SellOrderPrices[0] = SellOrderPrices[SellOrderPrices.length -1];
                        SellOrderPrices.pop();
                        uint256[] memory memSellOrderPrices = SellOrderPrices;
                        memSellOrderPrices = quick(memSellOrderPrices);
                        SellOrderPrices = memSellOrderPrices;
                        break;
                    }
                    
                    if (to_be_bought == 0){
                        break;
                    }
                }
            }
            else{
                break;
            }
        }
        
        // If there's still something to buy, place it in BuyOrderBook's respective place 
        if (to_be_bought > 0){
            placeInBuyOrderBook(to_be_bought, order_price, market_maker);
        }
        
        return true;
    }
    
    function MarketSell(uint256 quote_amt,uint256 order_price, address market_maker) public returns (bool){
        uint256 to_be_sold = quote_amt;
        uint256[] memory BuyOrderPrices_mem = BuyOrderPrices;
        for(uint l = BuyOrderPrices_mem.length; l > 0; l--){
            uint256 i = l-1;
            if(BuyOrderPrices_mem[i] >= order_price && to_be_sold > 0){
                orderDetails[] memory oD = BuyOrderBook[BuyOrderPrices_mem[i]];
                uint256 ordersRemoved = 0;
                // orderDetails[] memory oD;
                for(uint j = 0; j < oD.length; j++){
                    // Single Block can Fill Entire order 
                    if(oD[j].quote_amt > to_be_sold){
                        base_token.transferFrom(address(this) , market_maker, to_be_sold*oD[j].order_price/1e4);
                        oD[j].quote_amt -= to_be_sold;
                        quote_token.transferFrom(address(this), oD[j].market_maker, quote_amt);
                        to_be_sold = 0;
                        BuyOrderBook[BuyOrderPrices_mem[i]][j-ordersRemoved] = oD[j];
                        break;
                    }
                    else{
                        base_token.transferFrom(address(this) , market_maker, oD[j].quote_amt*oD[j].order_price/1e4);
                        quote_token.transferFrom(address(this) , oD[j].market_maker, oD[j].quote_amt);
                        to_be_sold -= oD[j].quote_amt;
                        oD[j].quote_amt = 0;
                        // Removing Order Struct in Storage 
                        for (uint k = j - ordersRemoved; k<BuyOrderBook[BuyOrderPrices_mem[i]].length-1; k++){
                            BuyOrderBook[BuyOrderPrices_mem[i]][k] = BuyOrderBook[BuyOrderPrices_mem[i]][k+1];
                        }
                        BuyOrderBook[BuyOrderPrices_mem[i]].pop();
                        ordersRemoved += 1;
                        // return to_be_sold;
                    }
                    // check if oD is completely exhuasted, then remove key from SellOrderPrices 
                    if (BuyOrderBook[BuyOrderPrices_mem[i]].length == 0){
                        // delete BuyOrderBook[BuyOrderPrices[BuyOrderPrices.length-1]];
                        
                        delete BuyOrderBook[BuyOrderPrices_mem[i]];
                        // BuyOrderPrices[0] = BuyOrderPrices[BuyOrderPrices.length -1];
                        BuyOrderPrices.pop();
                        
                        
                        // uint256[] memory memBuyOrderPrices = BuyOrderPrices;
                        // memBuyOrderPrices = quick(memBuyOrderPrices);
                        // BuyOrderPrices = memBuyOrderPrices;
                        break;
                    }
                    
                    if (to_be_sold == 0){
                        break;
                    }
                }
            }
            else{
                break;
            }
        }
        // If there's still something to buy, place it in BuyOrderBook's respective place 
        if (to_be_sold > 0){
            placeInSellOrderBook(to_be_sold, order_price, market_maker);
        }
        return true;
    }
    
    function placeInBuyOrderBook(uint256 quote_amt,uint256 order_price,address market_maker) internal returns (bool){
        orderDetails memory oD = orderDetails({
                quote_amt : quote_amt,
                order_price : order_price,
                market_maker : market_maker
        });
        orderDetails[] storage oDs = BuyOrderBook[order_price];
        if (oDs.length == 0){
            BuyOrderPrices.push(order_price);
            uint256[] memory memBuyOrderPrices = BuyOrderPrices;
            memBuyOrderPrices = quick(memBuyOrderPrices);
            BuyOrderPrices = memBuyOrderPrices;
        }
        oDs.push(oD);
        BuyOrderBook[order_price] = oDs;
        return true;
    }
    
    function placeInSellOrderBook(uint256 quote_amt,uint256 order_price, address market_maker) internal returns (bool){
        orderDetails memory oD = orderDetails({
                quote_amt : quote_amt,
                order_price : order_price, 
                market_maker : market_maker
        });
        orderDetails[] storage oDs = SellOrderBook[order_price];
        if (oDs.length == 0){
            SellOrderPrices.push(order_price);
            uint256[] memory memSellOrderPrices = SellOrderPrices;
            memSellOrderPrices = quick(memSellOrderPrices);
            SellOrderPrices = memSellOrderPrices;
        }
        oDs.push(oD);
        SellOrderBook[order_price] = oDs;
        return true;
    }
    
    // Utilities for Sorting array 
    function quick(uint256[] memory data) internal pure returns(uint256[] memory){
        if (data.length > 1) {
            quickPart(data, 0, data.length - 1);
        }
        return data;
    }
    
    function quickPart(uint256[] memory data, uint low, uint high) internal pure {
        if (low < high) {
            uint pivotVal = data[(low + high) / 2];
        
            uint low1 = low;
            uint high1 = high;
            for (;;) {
                while (data[low1] < pivotVal) low1++;
                while (data[high1] > pivotVal) high1--;
                if (low1 >= high1) break;
                (data[low1], data[high1]) = (data[high1], data[low1]);
                low1++;
                high1--;
            }
            if (low < high1) quickPart(data, low, high1);
            high1++;
            if (high1 < high) quickPart(data, high1, high);
        }
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";
import "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

import "./interfaces/IPriceObserver.sol";


contract PriceFeedImplement is IPriceObserver,AutomationCompatibleInterface {

    mapping(string => address) private dataFeedAddresses;
    mapping(address => ProductInfo) private tokenInfos;
    mapping(address => uint256) private currentInfo;
    mapping(address=> SnowbowResultStatus) private productStatus;
    address[] private productAddresses; 

    uint256 public immutable interval;
    uint256 public lastTimeStamp;
    constructor(uint256 updateInterval) {
        interval = updateInterval;
        lastTimeStamp = block.timestamp;
    }

    function getLatestPrice() public {
        for (uint i = 0; i < productAddresses.length; i++) {
            address productAddr = productAddresses[i];
            ProductInfo storage product = tokenInfos[productAddr];
            AggregatorV2V3Interface dataFeed = AggregatorV2V3Interface(product.usdToken);
            (, int256 currentPriceInt, , , ) = dataFeed.latestRoundData();
            uint256 currentPrice = uint256(currentPriceInt);
            currentInfo[productAddr] = uint256(currentPrice);

            SnowbowResultStatus status;

            // 根据价格计算赌局状态
            if (currentPrice >= product.targetKnockInPrice && currentPrice <= product.targetKnockOutPrice) {
                status = SnowbowResultStatus.InAndOut;
            } else if (currentPrice >= product.targetKnockOutPrice) {
                status = SnowbowResultStatus.OnlyOut;
            } else if (currentPrice <= product.targetKnockInPrice) {
                status = SnowbowResultStatus.OnlyIn;
            } else {
                status = SnowbowResultStatus.NorInOrOut;
            }
            productStatus[productAddr] = status;
        }
    }


    function getProductResult(address productAddr) 
    external 
    view 
    returns(SnowbowResultStatus, uint256 period, uint256 endPrice) {
        ProductInfo memory product = tokenInfos[productAddr];
        uint256 currentPrice = currentInfo[productAddr];

        return (productStatus[productAddr], product.period, currentPrice); 
    }

    function registerProduct(address productAddr, ProductInfo calldata productInfo )  external
    {
        tokenInfos[productAddr] = productInfo;
        productAddresses.push(productAddr);
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;
        // 在这个示例中，performData没有被使用，但仍然需要按照函数签名返回一个空的bytes数组
        performData = new bytes(0);

        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        if ((block.timestamp - lastTimeStamp) > interval) {
            lastTimeStamp = block.timestamp;
            getLatestPrice();
        }
    }


}
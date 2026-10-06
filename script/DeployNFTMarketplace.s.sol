// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";

contract DeployNFTMarketplace is Script {
    function run() external returns (NFTMarketplace marketplace) {
        vm.startBroadcast();

        marketplace = new NFTMarketplace();

        vm.stopBroadcast();
    }
}

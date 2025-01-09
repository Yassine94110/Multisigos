// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";

contract DeployMultiSig is Script {
    // Test addresses (replace with actual addresses if deploying to production)
    address constant USER1 = 0x4078c27C2b322764De9eBd58dc65274f25BfAA4a;
    address constant USER2 = 0xA35AA55f3346AdEB966e409001475B70AF2AD3C7;
    address constant USER3 = 0x0048086120846898Bb56E9b4D5430a5F74cD20fb;

    function run() external returns (MultiSigWallet) {
        address[] memory owners = new address[](3);
        owners[0] = USER1;
        owners[1] = USER2;
        owners[2] = USER3;
        MultiSigWallet multiSigWallet = new MultiSigWallet(owners, 2);
    }
}

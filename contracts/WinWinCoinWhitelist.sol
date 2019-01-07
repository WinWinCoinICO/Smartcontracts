pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/access/Whitelist.sol";

contract WinWinCoinWhitelist is Whitelist {
    bool public whitelistEnabled = false;

    function whitelist(address _operator) public view returns (bool) {
        if (!whitelistEnabled) {
            return true;
        }

        return super.whitelist(_operator);
    }

    function enableWhitelist() public onlyOwner {
        whitelistEnabled = true;
    }

    function disableWhitelist() public onlyOwner {
        whitelistEnabled = false;
    }
}
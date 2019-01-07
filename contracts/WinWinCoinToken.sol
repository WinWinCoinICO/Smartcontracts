pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/PausableToken.sol";

contract WinWinCoinToken is PausableToken {
    using SafeERC20 for ERC20;

    string public name = "WinWinCoinToken";
    string public symbol = "WWC";
    uint8 public decimals = 0;
    uint public INITIAL_SUPPLY = 200000000;
    bool public isFreezed = false;
    
    constructor() public {
        totalSupply_ = INITIAL_SUPPLY;
        balances[msg.sender] = INITIAL_SUPPLY;
        owner = msg.sender;
    }

    modifier whenNotPaused() {
        if(isFreezed) {
            require(msg.sender == owner || !paused, "Token freezed or paused");            
        } else {
            require(!paused, "Crowdsale is paused");
        }
        _;
    } 
    
    function returnTokensFrom(address _from, uint256 amount) public onlyOwner {
        require(amount <= balances[_from]);
        allowed[_from][owner] = allowed[_from][owner].add(amount);
        transferFrom(_from, owner, amount);
    }

    function transferFromTo(address _from, address _to, uint256 _value) public onlyOwner returns (bool)  {
        require(_value <= balances[_from], "Not enougth balance");
        
        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        
        emit Transfer(_from, _to, _value);
        return true;
    }

    function freeze() public onlyOwner {
        isFreezed = true;
        if(!paused) {
            pause();
        }
    }

    function unfreeze() public onlyOwner {
        isFreezed = false;
        if(paused) {
            unpause();
        }
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != owner);
        balances[_newOwner] = balances[owner];
        balances[owner] = 0;
        _transferOwnership(_newOwner);
    }    
}
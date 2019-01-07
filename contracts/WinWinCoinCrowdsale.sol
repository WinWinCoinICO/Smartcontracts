pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/crowdsale/Crowdsale.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./WinWinCoinToken.sol";
import "./WinWinCoinWhitelist.sol";

contract WinWinCoinCrowdsale is Crowdsale, Ownable, Pausable {
    using SafeMath for uint256;

    enum CrowdsaleStage { PrivateSale, PreSale, Sale1, Sale2, Finalized }
    enum Fund { Advisors, Airdrop, Gamblers, Jackpot, Sale, Team }
    CrowdsaleStage internal stage = CrowdsaleStage.PrivateSale;

    bool public isFinalized = false; 
    
    event Finalized();
    event AirdropTokenPurchase(
        address indexed purchaser,
        address indexed beneficiary,
        uint256 value,
        uint256 amount
    );

    event TokenReferralBonus(
        address sender,
        address beneficiary,
        address referral,
        uint256 weiTaken,
        uint256 totalTokens,
        uint256 referralTokens
    );

    event WeiReferralBonus(
        address sender,
        address beneficiary,
        address referral,
        uint256 weiTaken,
        uint256 totalTokens,
        uint256 referralWei
    );

    event TokenTransfer(
        address sender,
        address beneficiary,
        uint256 tokensAmount,
        Fund fund
    );

    event Buyout(
        address sender,
        uint256 tokens,
        uint256 weiToTransfer
    );

    mapping(address => bool) private privelegedInvestors;
    mapping(address => uint256) private totalTokenPurchased; 

    // investor => master
    mapping(address => address) private referrals;
    mapping(address => bool) private referralsEthBonus;

    uint256 public buyoutFund            = 0;

    uint8 private preSaleBuyoutPercent = 0;
    uint8 private sale1BuyoutPercent   = 33;
    uint8 private sale2BuyoutPercent   = 58;

    uint256 public maxTokens            = 200000000;
    uint256 public tokensForJackpot    =  80000000;
    uint256 public tokensForSale       =  60000000;
    uint256 public tokensForAirdrop     =  14000000;
    uint256 public tokensForGamblers    =  26000000;
    uint256 public tokensForTeam        =  15000000;
    uint256 public tokensForAdvisors    =   5000000;
 
    uint16 private privateSaleMin      = 4000;
    uint16 private preSaleMin          =   20;
    uint16 private sale1Min            =   15;
    uint16 private sale2Min            =   10;

    uint256 private privateSaleBonus10 =  80000;
    uint256 private privateSaleBonus15 = 200000;
    uint256 private privateSaleBonus20 = 400000;

    uint256 private preSaleBonus10     =  2000;
    uint256 private preSaleBonus15     = 10000;
    uint256 private preSaleBonus20     = 20000;

    uint256 private sale1Bonus10       =  1350;
    uint256 private sale1Bonus15       =  6667;
    uint256 private sale1Bonus20       = 13350;

    uint256 private sale2Bonus10       =  1000;
    uint256 private sale2Bonus15       =  5000;
    uint256 private sale2Bonus20       = 10000;

                                         
    uint256 private privateSalePrice   = 1250000000000000;
    uint256 private preSalePrice       = 2500000000000000;
    uint256 private sale1Price         = 3750000000000000;
    uint256 private sale2Price         = 5000000000000000;

    uint256 private airdropMin         = 20;
    uint256 private airdropPrice       = 5000000000000000;
    uint256 private airdropBonus       = 100;
    bool public airdropEnabled = false;

    address whitelistAddress;    

    WinWinCoinToken private myToken;    
    
    constructor(address _wallet, WinWinCoinToken _token, address _whitelistAddress) 
        Crowdsale(getPrice(), _wallet, _token) public
    {        
        require(_whitelistAddress != address(0));
        require(_wallet != address(0));

        whitelistAddress = _whitelistAddress;
        myToken = _token;        
    }
    
    modifier checkVolume() {
        uint256 weiAmount = msg.value;
        uint256 minAmount;
        if(stage == CrowdsaleStage.PrivateSale) {
            minAmount = privateSalePrice * privateSaleMin;
        }
        if(stage == CrowdsaleStage.PreSale) {
            minAmount = preSalePrice * preSaleMin;
        }
        if(stage == CrowdsaleStage.Sale1) {
            minAmount = sale1Price * sale1Min;
        }
        if(stage == CrowdsaleStage.Sale2) {
            minAmount = sale2Price * sale2Min;
        }
        require(minAmount <= weiAmount, "Less that minimum amount");
        _;
    }    

    function getPrice() public view returns (uint256) {
        require(!isFinalized, "Crowdsale is finalized");

        if(stage == CrowdsaleStage.PrivateSale) {
            return privateSalePrice;
        }
        if(stage == CrowdsaleStage.PreSale) {
            return preSalePrice;
        }
        if(stage == CrowdsaleStage.Sale1) {
            return sale1Price;
        }
        if(stage == CrowdsaleStage.Sale2) {
            return sale2Price;
        }
    }    

    function getAvailableTokensAmountForBuyout(address _beneficiary, uint256 currentBalance) private view returns(uint256) {
        if(stage == CrowdsaleStage.PrivateSale) {
            return 0;
        }

        uint256 totalAvailable;
        if(stage == CrowdsaleStage.PreSale) {
            totalAvailable = totalTokenPurchased[_beneficiary].mul(preSaleBuyoutPercent).div(100);            
        }
        if(stage == CrowdsaleStage.Sale1) {
            totalAvailable = totalTokenPurchased[_beneficiary].mul(sale1BuyoutPercent).div(100);
        }
        if(stage == CrowdsaleStage.Sale2) {
            totalAvailable = totalTokenPurchased[_beneficiary].mul(sale2BuyoutPercent).div(100);
        }

        uint256 buyout = totalTokenPurchased[_beneficiary].sub(currentBalance);
        if(buyout > 0) {
            totalAvailable = totalAvailable.sub(buyout);
        }
        
        return totalAvailable;
    }

    function tokensForBuyout() public view returns(uint256) { 
        uint256 balance = myToken.balanceOf(msg.sender);
        
        if(privelegedInvestors[msg.sender] && stage != CrowdsaleStage.PrivateSale) {
            return balance;
        }

        return getAvailableTokensAmountForBuyout(msg.sender, balance);
    }

    function getStage() public view returns (CrowdsaleStage) {
        return stage;
    }

    function setPresaleStage() public onlyOwner {
        require(stage == CrowdsaleStage.PrivateSale, "Current stage is not PrivateSale");
        stage = CrowdsaleStage.PreSale;
    }
    

    function setSale1Stage() public onlyOwner {
        require(stage == CrowdsaleStage.PreSale, "Current stage is not Presale");
        stage = CrowdsaleStage.Sale1;
    }

    function setSale2Stage() public onlyOwner {
        require(stage == CrowdsaleStage.Sale1, "Current stage is not Sale1");
        stage = CrowdsaleStage.Sale2;
    }
    
    function () external payable {
        buyTokens(msg.sender, address(0));
    }

    function buyTokens(address _beneficiary, address referral) public payable checkVolume whenNotPaused {        
        require(!isFinalized, "Crowdsale is finalized");

        uint256 weiAmount = msg.value;
        _preValidatePurchase(_beneficiary, weiAmount);
                
        uint256 tokens = _getTokenAmount(weiAmount);

        uint256 price = getPrice();
        uint256 weiToTake = tokens.mul(price);
        uint256 weiTaken = weiToTake;
        
        weiRaised = weiRaised.add(weiTaken);
        
        uint256 tokensForBeneficiary = tryGetBonusTokens(tokens);

        uint256 referralTokens = 0;
        uint256 referralWei = 0;

        checkReferral(_beneficiary, referral);

        if(referrals[_beneficiary] != address(0)) {
            if(referralsEthBonus[referrals[_beneficiary]]) {                
                referralWei = weiToTake.div(20);                
                weiToTake = weiToTake.sub(referralWei);
            } else {
                referralTokens = tryGetReferralBonusTokens(tokens);
            }

            tokensForBeneficiary = tryGetInviteBonusTokens(tokensForBeneficiary, tokens);            
        }

        preprocessPurchase(tokensForBeneficiary, referralTokens);        

        _processPurchase(_beneficiary, tokensForBeneficiary);

        emit TokenPurchase(msg.sender, _beneficiary, weiTaken, tokensForBeneficiary);

        _updatePurchasingState(_beneficiary, weiAmount);
        processBeneficiaryStat(_beneficiary, tokensForBeneficiary);
        _forwardFunds(_beneficiary, weiTaken, referralWei);
        processReferralBonus(_beneficiary, referrals[_beneficiary], weiTaken, tokensForBeneficiary, referralWei, referralTokens);
        _postValidatePurchase(_beneficiary, weiAmount);
    }

    function processBeneficiaryStat(address _beneficiary, uint256 tokens) private {
        if(stage == CrowdsaleStage.PrivateSale) {
            privelegedInvestors[_beneficiary] = true;
        }

        if(!privelegedInvestors[_beneficiary]) {
            totalTokenPurchased[_beneficiary] = totalTokenPurchased[_beneficiary].add(tokens);
        }
    }

    function preprocessPurchase(uint256 tokensForBeneficiary, uint256 referralTokens) private {
        uint256 total = tokensForBeneficiary.add(referralTokens);
        require(tokensForSale >= total, "Not enougth tokens");
        tokensForSale = tokensForSale.sub(total);
    }

    function processReferralBonus(
        address _beneficiary, 
        address referral, 
        uint256 weiTaken, 
        uint256 tokensForBeneficiary, 
        uint256 referralWei, 
        uint256 referralTokens) private {
        if(referralTokens > 0) {
            _processPurchase(referral, referralTokens);
            emit TokenReferralBonus(msg.sender, _beneficiary, referral, weiTaken, tokensForBeneficiary, referralTokens);
        }

        if(referralWei > 0) {            
            referrals[_beneficiary].transfer(referralWei);
            emit WeiReferralBonus(msg.sender, _beneficiary, referral, weiTaken, tokensForBeneficiary, referralWei);
        }
    }

    function tryGetBonusTokens(uint256 tokens) private view returns(uint256){
        uint256 bonusTokens = calcBuyBonus(tokens);
        return tokens.add(bonusTokens);
    }

    function tryGetInviteBonusTokens(uint256 tokensWithBonuses, uint256 tokens) private pure returns(uint256) {
        uint256 refBonusTokens = tokens.div(10);
        return tokensWithBonuses.add(refBonusTokens);
    }

    function tryGetReferralBonusTokens(uint256 tokens) private pure returns(uint256) {
        return tokens.div(10);
    }

    function checkReferral(address _beneficiary, address referral) private {
        if(referral != address(0) && referrals[_beneficiary] == address(0)) {            
            referrals[_beneficiary] = referral;            
        }
    }

    function getReferralBonusType() public view returns (bool) {
        if(referralsEthBonus[msg.sender] == true) {
            return true;
        }

        return false;
    }

    function setReferralBonusType(bool byEth) public {
        if(byEth) {
            require(!referralsEthBonus[msg.sender]);
            referralsEthBonus[msg.sender] = true;
        } else {
            require(referralsEthBonus[msg.sender]);
            referralsEthBonus[msg.sender] = false;
        }
    }

    function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) internal {
        super._preValidatePurchase(_beneficiary, _weiAmount);

        WinWinCoinWhitelist whitelist = WinWinCoinWhitelist(whitelistAddress);
        require(whitelist.whitelist(_beneficiary));
    }

    function _getTokenAmount(uint256 _weiAmount) internal view returns (uint256) {
        uint256 price = getPrice();
        uint256 tokens = _weiAmount.div(price);       

        return tokens;
    }

    function _forwardFunds(address _beneficiary, uint256 weiToTake, uint256 referralShare) internal {
        uint256 change = msg.value.sub(weiToTake);

        uint256 buyoutShare = weiToTake.mul(30).div(100);
        buyoutFund = buyoutFund.add(buyoutShare);

        _beneficiary.transfer(change);
        
        uint256 forwardShare = weiToTake.sub(buyoutShare);
        forwardShare = forwardShare.sub(referralShare);

        wallet.transfer(forwardShare);
    }

    function _deliverTokens(address _beneficiary, uint256 _tokenAmount) internal {
        token.safeTransfer(_beneficiary, _tokenAmount);
    }

    function calcBuyBonus(uint256 tokenAmount) private view returns (uint256) {
        uint8 percent = 0;
        if(stage == CrowdsaleStage.PrivateSale) {
            if(tokenAmount >= privateSaleBonus10) {
                percent = 10;
            }
            if(tokenAmount >= privateSaleBonus15) {
                percent = 15;
            }
            if(tokenAmount >= privateSaleBonus20) {
                percent = 20;
            }
        }
        if(stage == CrowdsaleStage.PreSale) {
            if(tokenAmount >= preSaleBonus10) {
                percent = 10;
            }
            if(tokenAmount >= preSaleBonus15) {
                percent = 15;
            }
            if(tokenAmount >= preSaleBonus20) {
                percent = 20;
            }
        }
        if(stage == CrowdsaleStage.Sale1) {
            if(tokenAmount >= sale1Bonus10) {
                percent = 10;
            }
            if(tokenAmount >= sale1Bonus15) {
                percent = 15;
            }
            if(tokenAmount >= sale1Bonus20) {
                percent = 20;
            }
        }
        if(stage == CrowdsaleStage.Sale2) {
            if(tokenAmount >= sale2Bonus10) {
                percent = 10;
            }
            if(tokenAmount >= sale2Bonus15) {
                percent = 15;
            }
            if(tokenAmount >= sale2Bonus20) {
                percent = 20;
            }
        }

        if(percent > 0) {
            return tokenAmount.mul(percent).div(100);
        }

        return 0;
    }

    function enableAirdrop() public onlyOwner {
        require(!isFinalized, "Crowdsale is finalized");
        airdropEnabled = true;
    }

    function disableAirdrop() public onlyOwner {
        require(!isFinalized, "Crowdsale is finalized");
        airdropEnabled = false;
    }

    function buyWithAirdrop(address _beneficiary) public payable whenNotPaused {        
        require(!isFinalized, "Crowdsale is finalized");
        require(airdropEnabled, "Airdrop disabled");

        uint256 weiAmount = msg.value;

        _preValidatePurchase(_beneficiary, weiAmount);
        
        uint256 tokens = weiAmount.div(airdropPrice);
        require(tokens >= airdropMin, "Not enougth tokens");

        uint256 weiToTake = tokens.mul(airdropPrice);
        
        weiRaised = weiRaised.add(weiToTake);
        uint256 totalTokens = tokens.add(airdropBonus);

        require(tokensForAirdrop >= totalTokens, "Not enougth tokens in fund");
        tokensForAirdrop = tokensForAirdrop.sub(totalTokens);

        _processPurchase(_beneficiary, totalTokens);
        
        emit AirdropTokenPurchase(msg.sender, _beneficiary, weiToTake, totalTokens);

        _updatePurchasingState(_beneficiary, weiAmount);

        if(!privelegedInvestors[_beneficiary]) {
            totalTokenPurchased[_beneficiary] = totalTokenPurchased[_beneficiary].add(totalTokens);
        }

        _forwardFunds(_beneficiary, weiToTake, 0);
        _postValidatePurchase(_beneficiary, weiAmount);
    }

    function sendAirdropBonus(address _beneficiary) public onlyOwner {
        require(isFinalized, "Crowdsale is not finalized");
        require(airdropEnabled, "Airdrop disabled");

        uint256 tokens = 30;

        require(tokensForAirdrop >= tokens, "Not enougth tokens in fund");
        tokensForAirdrop = tokensForAirdrop.sub(tokens);

        _processPurchase(_beneficiary, tokens);

        emit AirdropTokenPurchase(msg.sender, _beneficiary, 0, 30);
    }

    function sendAirdropBonuses(address[] _beneficiaries) public onlyOwner {
        require(isFinalized, "Crowdsale is not finalized");
        require(airdropEnabled, "Airdrop disabled");

        uint256 tokens = 30 * _beneficiaries.length;
        require(tokensForAirdrop >= tokens, "Not enougth tokens in fund");

        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            sendAirdropBonus(_beneficiaries[i]);
        }
    }    

    function buyout(uint256 tokens) public whenNotPaused {        
        require(!isFinalized, "Crowdsale is finalized");
        require(stage != CrowdsaleStage.PrivateSale, "Buyout isn't active on private sale stage");
        
        address beneficiary = msg.sender;
        uint256 tokensAvailable = myToken.balanceOf(beneficiary);
        require(tokensAvailable >= tokens, "Not enougth tokens");

        if(!privelegedInvestors[beneficiary]) {
            uint256 availableForBuyout = getAvailableTokensAmountForBuyout(beneficiary, tokensAvailable);
            require(availableForBuyout >= tokens, "Over limit");
        }        

        uint256 price = getPrice();
        uint256 weiToTransfer = tokens.mul(price);        

        require(weiToTransfer <= buyoutFund, "Not enougth eth in buyout fund");        

        myToken.returnTokensFrom(beneficiary, tokens);
        tokensForSale = tokensForSale.add(tokens);

        buyoutFund = buyoutFund.sub(weiToTransfer);
        beneficiary.transfer(weiToTransfer);        

        emit Buyout(msg.sender, tokens, weiToTransfer);
    }

    function finalize() public onlyOwner {
        require(!isFinalized, "Crowdsale is finalized");
        require(stage == CrowdsaleStage.Sale2, "Crowdsale is not in stage Sale2");

        finalization();
        emit Finalized();

        isFinalized = true;
    }

    function finalization() private {
        tokensForJackpot = tokensForJackpot.add(tokensForSale);
        tokensForSale = 0;
        stage = CrowdsaleStage.Finalized;
        myToken.unfreeze();
    }

    function transferToken(address _newOwner) public onlyOwner {
        myToken.transferOwnership(_newOwner);        
    }

    function deposit() public onlyOwner payable {        
    }

    function withdraw(uint256 amount) public onlyOwner {        
        require(address(this).balance >= amount, "Not enougth balance");

        wallet.transfer(amount);
    }    

    function transferTokensFromFund(address _beneficiary, uint256 tokens, Fund fund) public onlyOwner {        
        require(fund != Fund.Jackpot, "Transfer from jackpot fund is not available");

        if(fund == Fund.Advisors) {
            require(tokensForAdvisors >= tokens, "Not enougth tokens in adviser tokens fund");
            tokensForAdvisors = tokensForAdvisors.sub(tokens);
        } else if(fund == Fund.Airdrop) {
            require(tokensForAirdrop >= tokens, "Not enougth tokens in airdrop tokens fund");
            tokensForAirdrop = tokensForAirdrop.sub(tokens);
        } else if(fund == Fund.Gamblers) {
            require(tokensForGamblers >= tokens, "Not enougth tokens in gamblers tokens fund");
            tokensForGamblers = tokensForGamblers.sub(tokens);
        } else if(fund == Fund.Sale) {
            require(tokensForSale >= tokens, "Not enougth tokens in sale tokens fund");
            tokensForSale = tokensForSale.sub(tokens);
        } else if(fund == Fund.Team) {
            require(tokensForTeam >= tokens, "Not enougth tokens in team tokens fund");
            tokensForTeam = tokensForTeam.sub(tokens);
        }
        
        _deliverTokens(_beneficiary, tokens);

        emit TokenTransfer(msg.sender, _beneficiary, tokens, fund);
    }
}
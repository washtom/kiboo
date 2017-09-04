pragma solidity ^0.4.16; 

contract owned { 
    address public owner;
    
    function owned() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner)  public  onlyOwner {
        owner = newOwner;
    }

    string public sourceUrl;   

    function setSourceUrl(string url) public onlyOwner {
        sourceUrl = url;
    }
}

contract tokenRecipient { function receiveApproval(address from, uint256 value, address token, bytes extraData); }

contract BaseToken { 
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    uint public createTime = now;

    mapping (address => uint256) public balanceOf;

    mapping (address => mapping (address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);

    function BaseToken() {
        
    }
    
    function _callDividend(address _user) internal{     
        throw;
    }

    function _transfer(address _from, address _to, uint _value) internal {
        require (_to != 0x0);                             
        require (balanceOf[_from] > _value);               
        require (balanceOf[_to] + _value > balanceOf[_to]);     
        _callDividend(_from);
        _callDividend(_to);          
        balanceOf[_from] -= _value;                      
        balanceOf[_to] += _value;                          
        Transfer(_from, _to, _value);
    }

    function transfer(address _to, uint256 _value)  public  {
        _transfer(msg.sender, _to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value)  public returns (bool success) {
        require (_value < allowance[_from][msg.sender]);    
        allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value)  public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        return true;
    }

    function approveAndCall(address _spender, uint256 _value, bytes _extraData) public returns (bool success) {
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, this, _extraData);
            return true;
        }
    }      
    
    event Burn(address indexed from, uint256 value);

    function burn(uint256 _value)  public returns (bool success) {
        require (balanceOf[msg.sender] > _value);       
        _callDividend(msg.sender);        
        balanceOf[msg.sender] -= _value;                    
        totalSupply -= _value;                              
        Burn(msg.sender, _value);
        return true;
    }

    function burnFrom(address _from, uint256 _value)  public returns (bool success) {
        require(balanceOf[_from] >= _value);               
        require(_value <= allowance[_from][msg.sender]);    
        _callDividend(_from); 
        balanceOf[_from] -= _value;                       
        allowance[_from][msg.sender] -= _value;             
        totalSupply -= _value;                              
        Burn(_from, _value);
        return true;
    }
}

contract IcoToken is owned, BaseToken {
    
    uint256 constant public buyIcoPrice =  0.1 ether;   
 
    function IcoToken()  BaseToken ()  owned() { 
    }

    mapping (address => uint256) public userEtherOf;   
    
    function buyIcoToken() payable  public  {      
        require(msg.sender == tx.origin);
        require(balanceOf[this] > 0);
        uint256 amount = msg.value / buyIcoPrice;             
        require (msg.value > 0 && amount > 0);
        _transfer(this, msg.sender, amount);            
        userEtherOf[this] += msg.value;                  
    }
    
    function userRefund() public {
         _userRefund(msg.sender, msg.sender);
    }

    function userRefundTo(address _to) public {
        require (_to != 0x0);  
        _userRefund(msg.sender, _to);
    }

    function _userRefund(address _from,  address _to) private {
        require (_to != 0x0);  
        require(msg.sender == tx.origin);
        uint256 amount = userEtherOf[_from];
        if(amount > 0){
            userEtherOf[_from] -= amount;
            require(userEtherOf[_from] >= 0);   
            _to.transfer(amount); 
        }
      }

}

contract MarketToken is IcoToken
{
    function MarketToken()  IcoToken ()  {
    }
  
    struct  SellToken{
        uint totalAmount;   
        uint256 price;      
        uint soldoutAmount;
        uint lineTime;      
        bool cancel;       
    } 

    uint256 public remainder = 0;  

    mapping (address => SellToken) public sellTokenOf;     

    event SetSellToken(address _sellerAddress, uint indexed _sellingAmount, uint256 indexed _price, uint indexed _lineTime);
  
    function setSellToken(uint _amount, uint256 _price, uint _lineTime) public
    {
        require(_amount <= balanceOf[msg.sender]);
        var st = SellToken({
            totalAmount: _amount,
            price : _price,
            soldoutAmount: 0,
            lineTime: _lineTime,
            cancel: false

        });
        sellTokenOf[msg.sender] = st;     
        SetSellToken(msg.sender, _amount, _price, _lineTime);
    }

    uint256 public cancelSellTokenFee = 0.01 ether;  

    function setCancelSellTokenFee(uint256 _newFee) public onlyOwner{
        cancelSellTokenFee = _newFee;
    }

    function cancelSellToken() payable public
    {
        require (msg.value >= cancelSellTokenFee);
        if(msg.value - cancelSellTokenFee > 0)
        {
            userEtherOf[msg.sender] += msg.value - cancelSellTokenFee; 
        }

        var st = sellTokenOf[msg.sender];
        require(st.lineTime > now && st.totalAmount - st.soldoutAmount > 0 && !st.cancel);        
        st.cancel = true;
        sellTokenOf[msg.sender] = st;

        remainder += cancelSellTokenFee;
    }

    function buyToken(address _sellerAddress) public payable returns(bool _result) {   
        _result=false;
        require (_sellerAddress != 0x0);    
        require (msg.sender == tx.origin);  
        
        var st = sellTokenOf[_sellerAddress];
        if (st.lineTime > now && st.totalAmount - st.soldoutAmount > 0 && !st.cancel){
            uint256 amount = msg.value / st.price;
            if (amount > st.totalAmount - st.soldoutAmount)    
            {
                amount = st.totalAmount - st.soldoutAmount;
            }

            var canAmount = balanceOf[_sellerAddress];    
            if(canAmount <= 0){
                return;
            }
            if (amount > canAmount)
            {
                amount = canAmount;
            }

            _transfer(_sellerAddress, msg.sender, amount);     
            _sellerAddress.transfer(amount *  st.price);       
            var backAmount = msg.value - amount *  st.price;
            if  (backAmount > 0){
                msg.sender.transfer(backAmount);              
            }

            st.soldoutAmount += amount;                       
            sellTokenOf[msg.sender] = st;

            _result = true;
            return;
        }
        else{
            msg.sender.transfer(msg.value);                
            return;
        }
    }
}

contract GameToken is MarketToken
 {
    function GameToken()  MarketToken ()   {
        name = "PowerBallToken";
        symbol = "$T$";
        decimals = 18;
        totalSupply = 1100000;      
        icoMaxShare = 1000000;     
        icoMinShare =  510000;     

        balanceOf[this] = icoMaxShare;                     
        balanceOf[msg.sender] = totalSupply -  icoMaxShare;  

        var dp = DividendPeriod ({
            StartTime : now,
            EndTime : 0,
            TotalAmount : 0,
            ShareAmount : 0
        });  
        currentDividendPeriodNo = 0;
        dividendPeriodOf[currentDividendPeriodNo] = dp;
    }

    uint public icoMinShare;   
    uint public icoMaxShare;    
    uint public icoDeadline = now + 1 years;      
   
    address public powerBallAddress;   
    uint public setPowerBallAddressTimes = 0;

    function setPowerBallAddress(address _PowerBallAddress)  public  onlyOwner{
        require (setPowerBallAddressTimes < 3);
        powerBallAddress = _PowerBallAddress;
        setPowerBallAddressTimes += 1;
    }

    bool public icoIsOver = false;   
    bool public icoIsSuccess = false;    
  
    function sendEtherToPowerBall()  public  {
        require (msg.sender == tx.origin);  
        require(powerBallAddress != 0x0); 
        if(icoIsOver)
        {
            return;
        }

        if(now >= icoDeadline && balanceOf[this] <= icoMaxShare - icoMinShare){   
            var toAmount = this.balance;
            userEtherOf[this] -= toAmount;         
            powerBallAddress.transfer(toAmount);    
            balanceTimeOf[this] = now;              

            icoIsOver = true;
            icoIsSuccess = true;
            return;
        }

        if(balanceOf[this] == 0)               
        {
            uint256 amount = icoMaxShare * buyIcoPrice; 
            require(this.balance - amount >= 0);
            userEtherOf[this] -= amount;       
            powerBallAddress.transfer(amount);  
            balanceTimeOf[this] = now;          

            icoIsOver = true;
            icoIsSuccess = true;
            return;
        }

         if(now >= icoDeadline && balanceOf[this] > icoMaxShare - icoMinShare){
            icoIsOver = true;
            icoIsSuccess = false;
        }

        return;
    }

     function icoFalseRefunds() public{
        require (msg.sender == tx.origin);  
        if (icoIsOver && !icoIsSuccess){
            if(balanceOf[msg.sender] > 0)
            {
                var amount = balanceOf[msg.sender];                 
                balanceOf[msg.sender] -= amount;
                msg.sender.transfer(amount * buyIcoPrice);
                balanceOf[this] += amount;
            }
        }
    }

    address public taxAddress = 0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359;         
    function setTaxAddress(address _newTaxAddress)  public onlyOwner {        
        taxAddress = _newTaxAddress;
    }

    address public commonwealAddress = 0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359;  
    function setCommonwealAddress(address _newCommonwealAddress) public onlyOwner {        
        commonwealAddress = _newCommonwealAddress;
    }

 
    uint public toTokenOwnerPer = 100;     
    uint public toTaxPer = 0;              
    uint public toCommonwealPer = 0;     

    function setFundsPerByOwner(uint _toTokenOwnerPer, uint _toTaxPer, uint _toCommonwealPer) public onlyOwner {
        require(_toTokenOwnerPer >= 50);         
        require (_toTokenOwnerPer + _toTaxPer + _toCommonwealPer == 100);
        toTokenOwnerPer =_toTokenOwnerPer;
        toTaxPer = _toTaxPer;
        toCommonwealPer = _toCommonwealPer;
        return;
    }

    struct DividendPeriod
    {
        uint StartTime;
        uint EndTime;
        uint256 TotalAmount;
        uint256 ShareAmount;
    }

    mapping (uint => DividendPeriod) public dividendPeriodOf;   

    uint256 public shareAddValue = 0;     
    uint256 public addTotalValue = 0;      

    uint public lastDividendTime = now;     
    
    mapping (address => uint) public balanceTimeOf;              
    
    uint256 public currentDividendPeriodNo = 0;    

    uint256 public minDividendAmount = 1000 ether;  

    function gamePay() payable public {
        //if(gameRegisterOf[msg.sender] > 0)
        //{ 
            remainder += msg.value;
            addTotalValue += msg.value;
            shareAddValue += msg.value /  totalSupply;  
           
            var thisEther = userEtherOf[this];
            var canValue = remainder + thisEther;  
            if(canValue < minDividendAmount || now - lastDividendTime < 30 days)   
            {
                return;
            }           
            
            var toTax = canValue * toTaxPer / 100;      
            var tocommonweal = canValue * toCommonwealPer / 100; 
            var toTokenOwner = canValue * toTokenOwnerPer / 100;

            var dp = dividendPeriodOf[currentDividendPeriodNo];
            uint256 ta = toTokenOwner;              
            uint256 sa = ta / totalSupply - 1;      
            if(sa == 0){return;}                 
            dp.ShareAmount = sa;
            dp.TotalAmount = sa * totalSupply;
            dp.EndTime = now;

            remainder = ta -  dp.TotalAmount;      
            if(thisEther >0){
                userEtherOf[this] -= thisEther;    
            }

            dividendPeriodOf[currentDividendPeriodNo] = dp;
            currentDividendPeriodNo += 1;

            var newdp = DividendPeriod({
                StartTime :  dp.EndTime,
                EndTime : 0,
                TotalAmount : 0,
                ShareAmount : 0
            });
            dividendPeriodOf[currentDividendPeriodNo] = newdp;

            if (toTax > 0){
                userEtherOf[taxAddress] += toTax;
            }
            if (tocommonweal > 0){ 
                userEtherOf[commonwealAddress] += tocommonweal; 
            }
                        
            return;
        //}
    }

    function callDividend() public returns (uint256 _amount) {
         _callDividend(msg.sender);
         _amount =  userEtherOf[msg.sender];
         return;
    }

   
    function _callDividend(address _user ) internal  {
        uint _amount = 0;
        uint lastTime = balanceTimeOf[_user];
        uint256 tokenNumber = balanceOf[_user];
        if(tokenNumber <= 0)
        {
            return; 
        }
        for(int i = int(currentDividendPeriodNo) - 1; i >= 0; i--){     
            var dp = dividendPeriodOf[currentDividendPeriodNo];
            if(lastTime < dp.EndTime){                            
                _amount += dp.ShareAmount * tokenNumber;
            }
            else if (lastTime >= dp.EndTime){
                break;
            }
        }
        balanceTimeOf[_user] = now;  
        if(_amount > 0){
            userEtherOf[_user] += _amount;
        }
        return;
    }

    function callDividendAndUserRefund() public {
        callDividend();
        userRefund();
    }
 
    function freeLostShare(address _user) public onlyOwner {
        require(balanceOf[_user] > 0 && now - createTime > 20 years && now - balanceTimeOf[_user] > 20 years);

        _callDividend(_user ); 
        var amount = userEtherOf[_user] ;        
        var ba = balanceOf[_user];
        balanceOf[_user] -= amount;
        userEtherOf[_user] -= ba;

        balanceOf[this] +=  ba;                
        msg.sender.transfer(amount / 2 );      
        this.transfer(amount - amount / 2);     
    }
 
    mapping (address => uint256) public gameRegisterOf;   
     
   
    function register(address _gameAddress) public onlyOwner {  
        require (_gameAddress != 0x0);  
        if(gameRegisterOf[msg.sender] == 0){
            gameRegisterOf[msg.sender] = now;
        }
    }
 
   
    function unRegister(address _gameAddress) public onlyOwner {   
        require (_gameAddress != 0x0);  
        if(gameRegisterOf[msg.sender] != 0){
            gameRegisterOf[msg.sender] = 0;
        }
    }

    function ()  payable public {
        if(gameRegisterOf[msg.sender] > 0)
        { 
            gamePay();
            return;
        }
        else if (icoIsOver && !icoIsSuccess){
            if(msg.value > 0)
            {
                userEtherOf[msg.sender] += msg.value;
            }
            icoFalseRefunds();
            return;
        }
        else    
        {
             buyIcoToken();
             return;
        }    
    }



}
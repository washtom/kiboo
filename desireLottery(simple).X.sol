pragma solidity ^0.4.11;

contract owned {
    address public owner;
    
    function owned() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require (msg.sender == owner);
        _;
    }

    function transferOwnership(address _newOwner)  public onlyOwner {
        owner = _newOwner;
    }
}


contract  desireLottery is owned {

    function desireLottery() {
        owner = msg.sender;
        maxProof = 16;
        ProofPrice = 0.01 ether;
        intervalTime = 30 minutes;
        currentPeriodMaxProof = maxProof;    
        currentPeriodProofPrice = ProofPrice;  
        currentPeriodEnd = now + intervalTime; 
    }

    function iniCurrentPeriod() private{
            currentPeriodStart=now;
            currentPeriodEnd = now + intervalTime;
            currentPeriodIndex = 0;
            currentPeriodMaxProof = maxProof; 
            currentPeriodProofPrice = ProofPrice;
    }
    
    uint public maxUserProof = 64;      
    function setMaxUserProof(uint _maxUserProof)  public onlyOwner {
        maxUserProof = _maxUserProof;
    }

    uint256  public currentPeriodStart = now;  
    uint256  public currentPeriodEnd = now + intervalTime;  
    uint256  public currentPeriodIndex = 0;     
    bytes32  public  currentRandomByte32 ="*";
    uint  public  currentPeriodMaxProof = maxProof;  
    uint  public  currentPeriodProofPrice = ProofPrice; 
   
    mapping(address => uint256)  public  userBalanceOf;

    uint256 public  ProofPrice = 0.01 ether;
    function setProofPrice(uint256 _value) onlyOwner  public returns (uint256 _result) {
        var pp = _value - _value % 0.0001 ether; 
        require(pp > 0);
        ProofPrice=pp;
        _result = ProofPrice;
        return;
    }

    uint public  constant minProof = 1;     
    uint  public maxProof = 16;           
    function setMaxProof(uint _value)  public onlyOwner{
        if(_value > 1 && _value < 80){        
            maxProof = _value;
        }
    }
   
    uint256  public intervalTime = 30 minutes;  
    function setIntervalTime(uint _newIntervalTime) onlyOwner public  returns(bool _result) {
        if (_newIntervalTime < 5 minutes || _newIntervalTime > 7 days) 
        {
            return false;
        }
        else
        {
            intervalTime = _newIntervalTime;
            return true;
        }
    }

    uint public toUserPer100 =  88;     
    uint public toAgentPer100 = 10;    
    uint public toOwnerPer100 =  2;     
  
    function setFundsPer100(uint _toUserPer100, uint _toAgentPer100, uint _toOwnerPer100)
        public onlyOwner {
        require(_toUserPer100 + _toAgentPer100 + _toOwnerPer100 == 100);
        require(_toUserPer100 >= 75 && _toAgentPer100 <= 15 && _toOwnerPer100 >= 1);
        toUserPer100 =_toUserPer100;
        toAgentPer100 = _toAgentPer100;
        toOwnerPer100 = _toOwnerPer100;
        return;
    }

    struct  UserProof{
        uint256 currentPeriodNo;  
        address user;       
        uint[] proof; 
        uint multiple;
        uint256 buyTime;
        uint proofPrice;
        uint256 orderCode;   
    }
    
    mapping(uint256 => UserProof)  public currentPeriodUser;

    function buyProofBySelf(uint[]  _proof, uint _multiple) payable  public returns(bool _result){
        return  _buyProofByOperator( _proof,   _multiple,    1,  msg.sender, false); 
    }

    function buyProofByOperator1(uint[]  _proof, uint _multiple, uint  _orderCode) payable  public returns(bool _result){
        return  _buyProofByOperator( _proof,   _multiple,   _orderCode,  msg.sender, true); 
    }
    
    function buyProofByOperator2(uint[]  _proof, uint _multiple,  uint  _orderCode, address _buyer) payable  public returns(bool _result){
        return _buyProofByOperator(  _proof,   _multiple, _orderCode,  _buyer,    true); 
    }
        
    function _buyProofByOperator(uint[]  _proof, uint _multiple,  uint  _orderCode, address _buyer, bool _isByAgent) 
        private returns(bool _result)
    {
        userBalanceOf[_buyer] +=  msg.value; 
        if(canOpenLottery())   
        {
            return false;
        }
        require(_proof.length <= currentPeriodMaxProof);

        for (uint i =0; i < _proof.length; i++){
            if(_proof[i] > currentPeriodMaxProof || _proof[i]  < minProof ){
                _proof[i] = now % currentPeriodMaxProof + 1;  
            }
        }
        
        uint256 uaserAmount = userBalanceOf[_buyer];
        uint canMultiple =  uaserAmount / currentPeriodProofPrice / _proof.length;
        if (canMultiple > _multiple){   
            canMultiple = _multiple;
        }
       
       uint256 buyAmount = canMultiple * currentPeriodProofPrice * _proof.length;
       if(buyAmount == 0)   
       {
           return false;
       }

       var usadd = UserProof({
           currentPeriodNo:currentPeriodStart,  
           user: _buyer, 
           proof: _proof, 
           multiple:canMultiple, 
           buyTime:now,
           proofPrice:currentPeriodProofPrice, 
           orderCode:_orderCode
        });
       currentPeriodUser[currentPeriodIndex] = usadd;
       currentPeriodIndex++;

       currentRandomByte32 = sha3(currentRandomByte32, block.blockhash(block.number), now + currentPeriodIndex);
       
        userBalanceOf[_buyer] -= buyAmount; 
        userBalanceOf[this] += buyAmount * toUserPer100 / 100;              //2
        if(_isByAgent){ 
            userBalanceOf[msg.sender] += buyAmount * toAgentPer100;         //3
        }
        else{
            userBalanceOf[owner] += buyAmount * toAgentPer100;              //3
        }
        userBalanceOf[owner] += buyAmount * toOwnerPer100 / 100;            //4        
    }

    function getOkCode()  private returns (uint _okCode){
        currentRandomByte32 = sha3(currentRandomByte32, block.blockhash(block.number), now + currentPeriodIndex);
        _okCode = uint256(currentRandomByte32) % currentPeriodMaxProof + 1 ; 
        return;
    }
    
    function callWinner(uint _okCode) private returns(uint _winner){
        _winner = 0;      
        for (uint i =0; i < currentPeriodIndex; i++){
            UserProof storage us = currentPeriodUser[i];
            uint multiple = getAllMultipe(us, _okCode);
            _winner += multiple;
        }
        return;
    }

    event UserWin(address indexed caller, address indexed user, uint multiple, uint okAmount); 
    
    function shareOkAmount(uint _okCode, uint _okAmount) private {
        for (uint m = 0; m < currentPeriodIndex; m++){
            UserProof storage thisus = currentPeriodUser[m];
            uint multiple = getAllMultipe(thisus, _okCode);
            if(multiple > 0){
                uint allOkAmount = multiple * _okAmount;
                userBalanceOf[this] -= allOkAmount;
                userBalanceOf[thisus.user] += allOkAmount;
                UserWin(msg.sender, thisus.user, multiple, _okAmount);   
            }
        }
        return;
    }
    
    function getAllMultipe(UserProof storage _us, uint _okCode)  private returns(uint _multiple){
        _multiple = 0;
        for(uint n = 0; n < _us.proof.length; n++){
            if ( _us.proof[n] == uint( _okCode)){
                _multiple += _us.multiple;
            }
        }
        return;
    }

    uint minSellProofNum = 6;  
    function setMinSellProofNum(uint _newMinSellProofNum) public  onlyOwner{
        require(_newMinSellProofNum > maxProof / 3);
        minSellProofNum = _newMinSellProofNum;
        return;
    }

    function canOpenLottery() private returns(bool _result){  
        if(currentPeriodIndex > maxUserProof){        
            return true;
        }
        if (now >= currentPeriodEnd)                   
        {
            return (currentPeriodIndex > minSellProofNum);
        }
        return false;        
    }

    event OpenLottery(address indexed caller, uint okCode, uint256 okAmount, uint256 toUserAmount);

    function openLottery()  public returns(bool _result)
    {
        if(canOpenLottery())   
        {
            uint okCode = getOkCode();           
            uint winner = callWinner(okCode);      
             if(winner == 0) 
            {
                OpenLottery(msg.sender, okCode,  0,  0);  
                return false;
            }

            userBalanceOf[this] -= currentPeriodProofPrice;   
            userBalanceOf[msg.sender] += currentPeriodProofPrice;   
            
            uint256 toUserAmount = userBalanceOf[this];    
            uint okAmount = toUserAmount / winner / 10 * 10;  

            shareOkAmount(okCode, okAmount);   

            if(userBalanceOf[this] != 0)
            {
                userBalanceOf[owner] += userBalanceOf[this];
                userBalanceOf[this] = 0;
            }
           
            iniCurrentPeriod();    
            _result = true;            
            OpenLottery(msg.sender, okCode,  okAmount,  toUserAmount);  
            return;
        }
        return false;
    }   
    
    uint256 public  constant refundCode = 88;
    uint256 public  constant openLotteryCode = 98;  
    uint256  public constant proofLabel =      0.000100 ether; 
    uint256 public  constant multipleLabel =   0.00000100 ether;
    uint256  public constant reservedLabel =   0.00000001 ether;
           
    function isRefunCode(uint256 _amount) private returns(bool _result){
        _result = _amount == refundCode;
        return;
    }

    function isOpenLotteryCode(uint256 _amount) private returns(bool _result){
        _result = _amount == openLotteryCode;
        return;
    }

    function userRefund()  public  {
        _userRefund(msg.sender);
    }

    function userRefund(address _to) public  {
        _userRefund(_to);
    }   

    function _userRefund(address _to) private  returns(bool _result){
        require (_to != 0x0);  
        require(userBalanceOf[msg.sender] > 0);
        
        uint256 _balanceAmount = userBalanceOf[msg.sender];
        userBalanceOf[msg.sender] -= _balanceAmount;            

        require(userBalanceOf[msg.sender] >= 0);            
        _to.transfer(_balanceAmount);                    
        return true;
    }

    function () payable  public 
    {  
        if (isOpenLotteryCode(amount)) 
        {
            userBalanceOf[msg.sender] +=  msg.value;
            openLottery();
            return;
        }

        if(canOpenLottery())   
        {
            userBalanceOf[msg.sender] +=  msg.value; 
            return;
        }
        
        if (isRefunCode(amount))  
        {           
            userBalanceOf[msg.sender] +=  msg.value; 
            userRefund();
            return;
        }
           
       
        uint256 amount = msg.value;
        var m1 = msg.value % proofLabel;
        var m2 = msg.value % multipleLabel;
        var m3 = msg.value % reservedLabel;
        int proof = int(m1-m2) / int(multipleLabel);
        int multiple = int(m2-m3) / int(reservedLabel);
        uint[] memory _proof = new uint[](1); 
        _proof[0] = uint(proof);
        buyProofBySelf(_proof, uint(multiple));            
        return;
    }

}


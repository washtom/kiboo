pragma solidity ^0.4.16;

contract  ImmediateLottery {    
    
    address public owner;

    modifier onlyOwner {
        require (msg.sender == owner);
        _;
    }
   
    function transferOwnership(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }    

    function ImmediateLottery() {
        owner = msg.sender;
        _iniClassMultiple();
    }

    uint256 public maxProofPrice = 0.1 ether;
    uint256 public minProofPrice = 1;

    function setProofPrice(uint256 _newMaxProofPrice, uint256 _newMinProofPrice) public onlyOwner {
        require (_newMaxProofPrice >= _newMinProofPrice * 100);
        require (_newMaxProofPrice < 10 ether);     
        maxProofPrice = _newMaxProofPrice;
        minProofPrice = _newMinProofPrice;
    } 

    function getMaxProofPrice() public returns (uint256 _result){
        if(maxProofPrice > this.balance / maxRewardMultiple)
        {
            _result = this.balance / maxRewardMultiple;
            return;
        }
        else{
            _result = maxProofPrice;
            return;
        }
    }

    mapping (uint => ClassMultiple) public classMultipleOf;         

    struct ClassMultiple{
        uint ClassID;
        uint Num;
        uint Multiple;
        uint AddIndex;
    }

    uint256 public constant maxRewardMultiple = 1000;

    uint private constant allNumber = 10000;  

    mapping (uint => uint) public rewardMultipleOf;     

    function iniRewardMultipleOf(uint _classID, uint _doingNum, uint _base) public onlyOwner returns(uint _result) {
        require(_classID >= 1 && _classID <= 5);

        var cm =  classMultipleOf[_classID];
        var step = allNumber / cm.Num;
        require(_base >= 1 && _base <= step);

        _result = 0;
        for(uint j = cm.AddIndex; j < cm.Num; j++){
            if (_result >= _doingNum){
                return;
            }

            var index = j * step + _base;
            if (index > allNumber || index <= 0){return;}

            rewardMultipleOf[index] = cm.Multiple;

            cm.AddIndex += 1;
            _result ++;
        }
        return;
    }

    function _iniClassMultiple() private {
        var c5 = ClassMultiple({
            ClassID: 5,
            Num: 2000,
            Multiple:1,
            AddIndex : 0
        });
        classMultipleOf[5] = c5;

        var c4 = ClassMultiple({
            ClassID: 4,
            Num: 1000,
            Multiple:2,
            AddIndex : 0
        });
        classMultipleOf[4] = c4;

        var c3 = ClassMultiple({
            ClassID: 3,
            Num: 200,
            Multiple:10,
            AddIndex : 0
        });
        classMultipleOf[3] = c3;

        var c2 = ClassMultiple({
            ClassID: 2,
            Num: 10,
            Multiple:100,
            AddIndex : 0
        });
        classMultipleOf[2] = c2;

        var c1 = ClassMultiple({
            ClassID: 1,
            Num: 1,
            Multiple:1000,
            AddIndex : 0
        });
        classMultipleOf[1] = c1;

        return;
    }  
      
    uint256 public proofIndex = 0;
    
    struct  UserProof{              
            address Buyer;       
            uint256 BuyTime;
            uint256 PayAmount; 
            uint256 OrderNumber;   
            uint WinMultiple;           
            uint256 AwardAmount;    
    }

    mapping (uint => UserProof) public userProofOf;        

    function buyProofBySelf1() 
        payable public returns(bool _result) {
        return _buyProofByAgent(0,  0,  msg.sender, false);
    }

    function buyProofBySelf2(uint256 _userMsg) 
        payable public returns(bool _result) {
        return _buyProofByAgent(0,  _userMsg,  msg.sender, false);
    }
   
    function buyProofByAgent1(uint256 _orderNumber)  
        payable public returns(bool _result)
    {
        return _buyProofByAgent(_orderNumber,  0,  msg.sender, true);  
    }

    function buyProofByAgent2(uint256 _orderNumber, uint256 _userMsg)  
        payable public returns(bool _result)
    {
        return _buyProofByAgent(_orderNumber,  _userMsg,  msg.sender, true);  
    }
    
    function buyProofByAgent3( uint256 _orderNumber, uint256 _userMsg, address _buyerAddress)  
        payable public returns(bool _result)
    {
        return _buyProofByAgent(_orderNumber,  _userMsg,  _buyerAddress, true);  
    }

    uint public toAgentPer100 = 9;                 
    
    function setToAgentPer100(uint _toAgentPer100) public onlyOwner {
        require(_toAgentPer100 <= 15);       
        toAgentPer100 = _toAgentPer100;
    }    

    bool public isSaveUserProof = true;

    function setIsSaveUserProof(bool _value) public onlyOwner{
        isSaveUserProof = _value;
    }

    uint public randomType = 1; 

    function setRandomType(uint _type) public onlyOwner{
        randomType = _type;
    }  
    
    function _buyProofByAgent(uint256 _orderNumber, uint256 _userMsg, address _buyerAddress, bool _isByAgent)  
        private returns(bool _result)
    {
        require(msg.value >= minProofPrice);

        var buyValue = msg.value;
        var canValue = getMaxProofPrice();
        uint remainValue = 0;
        if(buyValue > canValue)
        {
            buyValue = canValue;
            remainValue =  msg.value - canValue; 
        }     
        uint256 resultNum;
        bytes32 calNum;
        if (randomType == 1){
            calNum = sha3(block.blockhash(block.number), _userMsg, now + proofIndex);
            resultNum = uint256(calNum) % allNumber;
        }
        else 
        {
            calNum = sha3(block.blockhash(block.number), _userMsg, proofIndex);
            resultNum = uint256(calNum) % allNumber;
        }

        var multiple = rewardMultipleOf[resultNum];
        var awardAmount = multiple * buyValue;
     
        if(isSaveUserProof){
            var addUP = UserProof({
                Buyer: _buyerAddress,
                BuyTime: now,
                PayAmount: buyValue,
                OrderNumber: _orderNumber,
                WinMultiple: multiple,
                AwardAmount: awardAmount
            });
            userProofOf[proofIndex] = addUP;
        }
        proofIndex ++;

        if (awardAmount + remainValue > 0){
            _buyerAddress.transfer(awardAmount + remainValue);  
        }

        if(_isByAgent){
            uint256  to_Agent =  buyValue * toAgentPer100 / 100;   
            if(to_Agent > 0){
                msg.sender.transfer(to_Agent);        
            }    
        }
        
        _result = multiple > 0;
        return;
    }

    function getInterest(uint256 _amount) public onlyOwner{
        if (this.balance >= _amount){
            msg.sender.transfer(_amount);
        }
    }
     
    function () payable     
    {        
        if(msg.sender == owner){
            return;
        }
        else{
            buyProofBySelf1();
            return;
        }
    }

}



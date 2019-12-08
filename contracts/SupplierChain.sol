pragma solidity ^0.4.4;


contract SupplyChain3 {
    enum Role{ MainFactory, Supplier, FinancingInstitution } //user's role
    //enum Phase{ Supplier, Producer, Dealer, Retailer, Customer}

    struct User{
        bytes32 ID; //user ID
        string name; //user name 
        uint balance; //current balance
        Role role; //user's role
        bytes32 [] receiptList; //recepits that user keeps, store recepits' id
    }

    struct Receipt{
        bytes32 receiptID; //recepit number
        uint signTime; //when the recepit is signed
        uint endTime; //deadline of the recepit
        address producerAddr; //who give the recepit
        bytes32 producerID; //producer id
        uint amount; //amount of money
        address ownerAddr; //recepit owner's address
        bytes32 ownerID; //supplier id
       
        
    }

    //user map
    mapping(address => User) mainFactoryMap;
    mapping(address => User) supplierMap;
    mapping(address => User) financingInstitutionMap;
    mapping(address => User) blankMap;
    //recepit map
    mapping(bytes32 => Receipt) receiptMap;

    
    uint public totalFinancingAmount;
    
    Receipt [] receiptArr;

    function addUser(bytes32 id, string name, uint balance, Role role) returns (string) {
        User storage user = blankMap[msg.sender];
        
        user.ID = id;
        user.name = name;
        user.balance = balance;
        user.role = role;
        
        if (role == Role.MainFactory) mainFactoryMap[msg.sender] = user;
        else if (role == Role.Supplier)  supplierMap[msg.sender] = user;
        else if (role == Role.FinancingInstitution) financingInstitutionMap[msg.sender] = user;
        else return ("Invalid role type");        
        
        return ("User Registered successfully");
    }
    
    function getBalance(Role role, address userAddr) returns (uint) {
        User storage user = blankMap[msg.sender];
        if (role == Role.MainFactory) user = mainFactoryMap[msg.sender];
        else if (role == Role.Supplier) user = supplierMap[msg.sender];
        else if (role == Role.FinancingInstitution) user = financingInstitutionMap[msg.sender];
        return user.balance;
    }
    
    //sign recepit (for main factory)
    //function 1
    function signReceipt(bytes32 receiptID, uint signTime, uint amount, uint endTime, address supplierAddr) returns (string) {
        require(receiptMap[receiptID].receiptID == 0x0);

        require(mainFactoryMap[msg.sender].ID != 0x0);
        
        require(supplierMap[supplierAddr].ID != 0x0);
        
        Receipt storage receipt = receiptMap[receiptID];

        User storage mainFac = mainFactoryMap[msg.sender]; //get current user

        User storage currSupplier = supplierMap[supplierAddr]; //get goal supplier
        
        //sign receipt
        receipt.receiptID = receiptID;
        receipt.signTime = signTime;
        receipt.amount = amount;
        receipt.endTime = endTime;
        receipt.ownerID = currSupplier.ID;
        receipt.ownerAddr = supplierAddr;
        receipt.producerAddr = msg.sender;
        receipt.producerID = mainFac.ID;
        
        receiptMap[receiptID] = receipt;
        //connect receipt with the owner
        currSupplier.receiptList.push(receipt.receiptID);
        
        supplierMap[supplierAddr] = currSupplier;
        receiptArr.push(receipt);
        
        return ("Sign Receipt Success");
    }

    //transfer receipt (for supplier)
    //function 2
    
    function transferReceipt(address from, address to, bytes32 receiptID, uint amount, uint signTime, uint endTime) returns (string){
        //require (supplierMap[from].ID != 0x0 && supplierMap[to].ID != 0x0);
        require (receiptMap[receiptID].receiptID == 0x0); 
        User storage fromSupplier = supplierMap[from];
        User storage toSupplier = supplierMap[to];
        bytes32 fromReceiptID;
        //get from Receipt ID
        for (uint i = 0; i < fromSupplier.receiptList.length; i ++) {
            bytes32 tmp = fromSupplier.receiptList[i];
            if (receiptMap[tmp].ownerAddr == from) fromReceiptID = tmp;
        }
        
        Receipt storage fromReceipt = receiptMap[fromReceiptID];
        if (amount > fromReceipt.amount) return ("amount out of range");
        
        Receipt memory toReceipt = Receipt(receiptID, signTime, endTime, from, fromSupplier.ID, amount, to, toSupplier.ID);
        //update info
        receiptMap[receiptID] = toReceipt;
        receiptArr.push(toReceipt);
        
        return ("Transfer Receipt Success");  
    }
    
    //Financing issue (between suppliers and FinancingInstitution)
    //function 3
    
    function financing(uint amount) returns (string) {
        require(supplierMap[msg.sender].ID != 0x0);
        
        User storage currSupplier = supplierMap[msg.sender];
        bytes32 currReceiptID;
        //get current Receipt ID
        for (uint i = 0; i < currSupplier.receiptList.length; i ++) {
            bytes32 tmp = currSupplier.receiptList[i];
            if (receiptMap[tmp].ownerAddr == msg.sender) currReceiptID = tmp;
        }
        
        Receipt storage currReceipt = receiptMap[currReceiptID];
        
        if (amount > currReceipt.amount) return ("amount out of range");
        
        //financing
        currReceipt.amount = currReceipt.amount - amount;
        totalFinancingAmount = totalFinancingAmount + amount; //add debt
        currSupplier.balance += amount;
        
        //update info
        receiptMap[currReceiptID] = currReceipt;
        supplierMap[msg.sender] = currSupplier;
        
        for (uint j = 0; j < receiptArr.length; j ++) {
            if (receiptArr[j].receiptID == currReceiptID) receiptArr[j] = currReceipt;
        }
        return ("Financing Success");
    }
    
    //pay debt
    //function 4
    
    function payDebt() returns (string) {
       for (uint i = 0; i < receiptArr.length; i ++) {
           Receipt storage currReceipt = receiptArr[i];
           //get current producer and owner
           User storage currOwner = supplierMap[currReceipt.ownerAddr];
            User storage currProducer = supplierMap[currReceipt.producerAddr];
           if (currProducer.ID == 0x0) {
               currProducer = mainFactoryMap[currReceipt.producerAddr];
           }
          
           
           //pay debt
           
           //as for main factory
           if (currProducer.role == Role.MainFactory) {
               //pay to supplier
               if (currProducer.balance < currReceipt.amount) return ("Debt out of range, you're broke");
               
               currProducer.balance -= currReceipt.amount;
               currOwner.balance += currReceipt.amount;
               
               //pay to FinancingInstitution
               if (currProducer.balance < totalFinancingAmount) return ("Debt out of range(2), you're broke");
               
               currProducer.balance -= totalFinancingAmount;
               totalFinancingAmount = 0;
           }
           
           //as for suppliers
           if (currProducer.role == Role.Supplier) {
               //pay to supplier
               if (currProducer.balance < currReceipt.amount) return ("Debt out of range(3), you're broke");
               
               currProducer.balance -= currReceipt.amount;
               currOwner.balance += currReceipt.amount;
           }
           
           
           //clear receipt map
           delete receiptMap[currReceipt.receiptID];
       }
       delete receiptArr; //clear array
       return ("Success, all debts are paid");
    }
 
}

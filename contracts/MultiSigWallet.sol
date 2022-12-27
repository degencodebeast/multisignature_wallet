// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.3;

contract MultiSigWallet {

    //Events that are fired when eth is deposited into this multi-sig wallet
    event Deposit(address indexed sender, uint amount);
    event Submit(uint indexed txId); //we'll hit this event when a transaction is submitted waiting for other owners to approve
    event Approve(address indexed owner, uint indexed txId);
    event Revoke(address indexed owner, uint indexed txId);
    event Execute(uint indexed txId);

    struct Transaction {
        address to; //addresss where transaction is executed
        uint value; //amount of ether sent to the "to" address
        bytes data; //the data to be sent to the "to" address
        bool executed; //once the transaction is executed we'll set this to true, shows whether the tx is excecuted or not
    } 

    address[] public owners; //only the owners will be able to call most of the functions in this contract
    mapping(address=> bool) public isOwner; //mapping to check whether msg.sender is an owner
    //once a transaction is submitted to this contract, other owners will have to approve before that 
    //that transaction can be executed


    //the number of approvals that is required before it can be executed, we'll store it in a uint as "required"
    //no of approvals required before a transaction can be executed
    uint public required;

    Transaction[] public transactions;
    //each transaction can be executed if the number of approvals is >= required
    //we'll store the approval of each transaction by each owner in a mapping
    mapping(uint => mapping(address => bool)) public approved;//mapping of the index of the transaction to another mapping address, which will be the address of the owner
    //which will be mapped to a boolean, and the boolean will indicate whether the transaction is approved by an owner or not, so basically it's a mapping to check if a
    //transaction has been approved by a particular owner or not 

    modifier onlyOwner() {
        //require(isOwner[msg.sender], "not the owner");
        require(isOwner[msg.sender] == true, "not the owner");
        _;
    }

    modifier txExists(uint _txId) {
        require(_txId < transactions.length, "tx does not exist");
        _;
    }

    modifier notApproved(uint _txId) {
        require(!approved[_txId][msg.sender], "tx already approved");
        _;
    }

    modifier notExecuted(uint _txId) {
        require(!transactions[_txId].executed, "tx has already been executed");
        _;
    }

    constructor(address[] memory _owners, uint _required) {
        require(_owners.length > 0, "at least one owner is required");
        require(
            _required > 0 && _required <= _owners.length, 
            "invalid required number of owners"
        );

        //next we'll run a for loop to save the owners to the state variable 
        for(uint i = 0; i < _owners.length; i++) {
            //we'll get the address of the owner from an array into a variable
            address owner = _owners[i];
            require(owner != address(0), "this is a zero address");
            require(isOwner[owner] == false, "this address is already an owner address");
            //require(!isOwner[owner], "this address is already an owner address");
            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }


    //only owners can call submit, once a transaction has enough owners, then any of the owners will be able to execute the tranasaction
    //_data, data to be sent to the address _to
    function submit(address _to, uint _value, bytes calldata _data)
        external
        onlyOwner
        {
            transactions.push(Transaction(_to, _value, _data, false));
            emit Submit(transactions.length - 1);
        }

    function approve(uint _txId) 
        external 
        onlyOwner 
        txExists(_txId)
        notApproved(_txId)
        notExecuted(_txId)
    {
        approved[_txId][msg.sender] = true;
        emit Approve(msg.sender, _txId);
    }

    //before an owner can execute a transaction, they'll need to make sure that
    //the number of approvals is greater than required

    //let's write a function  given a txId, we'll count the number of approvals
    function _getApprovalCount(uint _txId) 
        private 
        view 
        returns(uint approvalCount)
    {
        for(uint i = 0; i < owners.length; i++) {
            if(approved[_txId][owners[i]] == true){
                approvalCount += 1;
            }
        //return approvalCount; //we don't need this return because the approvalCount has been implicitly declared in our function definition
        }
    }

    function execute(uint _txId) 
        external 
        onlyOwner 
        txExists(_txId)
        notExecuted(_txId)
    {
            uint count = _getApprovalCount(_txId);
            require(count >= required, "not enough approval counts");
            Transaction storage transaction = transactions[_txId];//storage because we are updating the state variable
           
            transaction.executed = true;

            //next we'll execute the transaction by typing "transaction.to", this will be the address
            //that we are gonna use the low level call to execute the transaction
            (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
            require(success, "tx failed");

            emit Execute(_txId);
    }

    //function to undo the approval
    function revoke(uint _txId) 
        external
        onlyOwner
        txExists(_txId)
        notExecuted(_txId)    
    {
        require(approved[_txId][msg.sender], "tx not approved");//meaning that msg.sender has approved this transaction
        approved[_txId][msg.sender] = false;



        emit Revoke(msg.sender, _txId);
    }

    function encode(string memory _value) external pure returns(bytes memory) {
        bytes memory result = abi.encode(_value);
        return result;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value); 
    }
}

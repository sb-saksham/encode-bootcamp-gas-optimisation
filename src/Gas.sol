// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28; 

import "./Ownable.sol";

contract GasContract is Ownable {
    uint256 immutable totalSupply = 0; // cannot be updated
    uint256 public paymentCounter = 0;
    mapping(address => uint256) public balances;
    address public contractOwner;
    mapping(address => Payment[]) public payments;
    mapping(address => uint256) public whitelist;
    address[5] public administrators;
    
    mapping(address => History) public paymentHistory; // when a payment was updated

    struct Payment {
        uint256 paymentID;
        bytes8 recipientName; // max 8 characters
        address recipient;
        address admin; // administrators address
        uint256 amount;
    }

    struct History {
        uint256 lastUpdate;
        uint256 blockNumber;
    }    
    struct ImportantStruct {
        uint256 amount;
        bool paymentStatus;
        address sender;
    }
    mapping(address => ImportantStruct) public whiteListStruct;

    event AddedToWhitelist(address userAddress, uint256 tier);

    modifier onlyAdminOrOwner() {
        if (checkForAdmin(msg.sender) || msg.sender == contractOwner) {
            _;
        } else {
            revert(
                "Error in Gas contract - onlyAdminOrOwner modifier : revert happened because the originator of the transaction was not the admin, and furthermore he wasn't the owner of the contract, so he cannot run this function"
            );
        }
    }

    modifier checkIfWhiteListed(address sender) {
        if(msg.sender != sender){
            revert("Gas Contract CheckIfWhiteListed modifier : revert happened because the originator of the transaction was not the sender");
        } else if((whitelist[msg.sender] < 0) && (whitelist[msg.sender] > 4)){
            revert("Gas Contract CheckIfWhiteListed modifier : revert happened because the user's tier is incorrect, it cannot be over 4 as the only tier we have are: 1, 2, 3; therfore 4 is an invalid tier for the whitlist of this contract. make sure whitlist tiers were set correctly");
        } else{
            _;
        }
    }

    event supplyChanged(address, uint256);
    event Transfer(address recipient, uint256 amount);
    event PaymentUpdated(
        address admin,
        uint256 ID,
        uint256 amount,
        bytes8 recipient
    );
    event WhiteListTransfer(address indexed);

    constructor(address[] memory _admins, uint256 _totalSupply) {
        contractOwner = msg.sender;
        totalSupply = _totalSupply;

        for (uint256 ii = 0; ii < administrators.length; ii++) {
            if (_admins[ii] != address(0)) {
                administrators[ii] = _admins[ii];
                if (_admins[ii] == contractOwner) {
                    balances[contractOwner] = totalSupply;
                    emit supplyChanged(_admins[ii], totalSupply);
                } else {
                    balances[_admins[ii]] = 0;
                    emit supplyChanged(_admins[ii], 0);
                }
            }
        }
    }

    function checkForAdmin(address _user) public view returns (bool admin_) {
        bool admin = false;
        for (uint256 ii = 0; ii < administrators.length; ii++) {
            if (administrators[ii] == _user) {
                admin = true;
            }
        }
        return admin;
    }

    function balanceOf(address _user) public view returns (uint256 balance_) {
       // uint256 balance = balances[_user];
        return balances[_user];
    }

    function addHistory(address _updateAddress)
        public
    {
        // History memory history;
        // history.blockNumber = block.number;
        // history.lastUpdate = block.timestamp;
         paymentHistory[_updateAddress] = History(block.timestamp, block.number);
    }

    function transfer(
        address _recipient,
        uint256 _amount,
        string calldata _name
    ) public {
        require(
            balances[msg.sender] >= _amount,
            "Gas Contract - Transfer function - Sender has insufficient Balance"
        );
        require(
            bytes(_name).length < 9,
            "Gas Contract - Transfer function -  The recipient name is too long, there is a max length of 8 characters"
        );
        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;
        emit Transfer(_recipient, _amount);
        payments[msg.sender].push(Payment(++paymentCounter,  bytes8(bytes(_name)),  _recipient, address(0), _amount ));
    }

    function updatePayment(
        address _user,
        uint256 _ID,
        uint256 _amount
    ) public onlyAdminOrOwner {
        require(
            _ID > 0,
            "Gas Contract - Update Payment function - ID must be greater than 0"
        );
        require(
            _amount > 0,
            "Gas Contract - Update Payment function - Amount must be greater than 0"
        );
        require(
            _user != address(0),
            "Gas Contract - Update Payment function - Administrator must have a valid non zero address"
        );

        for (uint256 ii = 0; ii < payments[_user].length; ii++) {
            if (payments[_user][ii].paymentID == _ID) {
                payments[_user][ii].admin = _user;
                payments[_user][ii].amount = _amount;
                addHistory(_user);
                emit PaymentUpdated(
                    msg.sender,
                    _ID,
                    _amount,
                    payments[_user][ii].recipientName
                );
            }
        }
    }

    function addToWhitelist(address _userAddrs, uint256 _tier)
        public
        onlyAdminOrOwner
    {
        require(
            _tier < 255,
            "Gas Contract - addToWhitelist function -  tier level should not be greater than 255"
        );
        whitelist[_userAddrs] = _tier;
        if (_tier > 3) {
            whitelist[_userAddrs] = 3;
        } else if (_tier == 1) {
            whitelist[_userAddrs] = 1;
        } else if (_tier > 0 && _tier < 3) {
            whitelist[_userAddrs] = 2;
        }
        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(
        address _recipient,
        uint256 _amount
    ) public checkIfWhiteListed(msg.sender) {
        whiteListStruct[msg.sender] = ImportantStruct(_amount, true, msg.sender);
        
        require(
            (_amount > 3) && (balances[msg.sender] >= _amount),
            "Gas Contract - whiteTransfers function - Sender has insufficient Balance/amount to send have to be bigger than 3"
        );
        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;
        balances[msg.sender] += whitelist[msg.sender];
        balances[_recipient] -= whitelist[msg.sender];
        
        emit WhiteListTransfer(_recipient);
    }

    function getPaymentStatus(address sender) public view returns (bool, uint256) {
        return (whiteListStruct[sender].paymentStatus, whiteListStruct[sender].amount);
    }

    receive() external payable {
        payable(msg.sender).transfer(msg.value);
    }


    fallback() external payable {
         payable(msg.sender).transfer(msg.value);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract MultiSigWallet {
    struct OwnerChange {
        address owner;
        bool isAdd;
        bool executed;
        uint confirmations;
    }

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint confirmations;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public required;
    mapping(uint => mapping(address => bool)) public isConfirmed;
    Transaction[] public transactions;
    OwnerChange[] public ownerChanges;

    event OwnerAdded(address indexed newOwner);
    event OwnerRemoved(address indexed removedOwner);
    event RequirementChanged(uint required);
    event TransactionSubmitted(uint txIndex);
    event TransactionConfirmed(address indexed owner, uint txIndex);
    event TransactionExecuted(uint txIndex);
    event TransactionRevoked(address indexed owner, uint txIndex);
    event OwnerChangeSubmitted(uint changeId);
    event OwnerChangeExecuted(uint changeId, address indexed owner, bool isAdd);
    event OwnerChangeRevoked(uint changeId);

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not owner");
        _;
    }

    modifier ownerChangeExists(uint changeId) {
        require(changeId < ownerChanges.length, "Owner change does not exist");
        _;
    }

    modifier notExecutedOwnerChange(uint changeId) {
        require(
            !ownerChanges[changeId].executed,
            "Owner change already executed"
        );
        _;
    }

    modifier transactionExists(uint txIndex) {
        require(txIndex < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint txIndex) {
        require(
            !transactions[txIndex].executed,
            "Transaction already executed"
        );
        _;
    }

    constructor(address[] memory _owners, uint _required) {
        require(_owners.length >= 3, "Minimum 3 owners required");
        require(_required >= 2, "At least two confirmations required");
        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }
        required = _required;
    }

    function submitTransaction(
        address _to,
        uint _value,
        bytes calldata _data
    ) public onlyOwner {
        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                confirmations: 0
            })
        );
        emit TransactionSubmitted(transactions.length - 1);
    }

    function confirmTransaction(
        uint _txIndex
    ) public onlyOwner transactionExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        transaction.confirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;
        emit TransactionConfirmed(msg.sender, _txIndex);

        if (transaction.confirmations >= required && !transaction.executed) {
            executeTransaction(_txIndex);
        }
    }

    function executeTransaction(
        uint _txIndex
    ) private transactionExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        require(
            transaction.confirmations >= required,
            "Insufficient confirmations"
        );

        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "Transaction failed");
        emit TransactionExecuted(_txIndex);
    }

    function revokeConfirmation(
        uint _txIndex
    ) public onlyOwner transactionExists(_txIndex) notExecuted(_txIndex) {
        require(isConfirmed[_txIndex][msg.sender], "Transaction not confirmed");

        Transaction storage transaction = transactions[_txIndex];
        transaction.confirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit TransactionRevoked(msg.sender, _txIndex);
    }

    function submitOwnerChange(address owner, bool isAdd) public onlyOwner {
        OwnerChange memory change = OwnerChange({
            owner: owner,
            isAdd: isAdd,
            executed: false,
            confirmations: 0
        });
        ownerChanges.push(change);
        emit OwnerChangeSubmitted(ownerChanges.length - 1);
    }

    function confirmOwnerChange(
        uint changeId
    )
        public
        onlyOwner
        ownerChangeExists(changeId)
        notExecutedOwnerChange(changeId)
    {
        OwnerChange storage change = ownerChanges[changeId];
        change.confirmations += 1;
        if (change.confirmations >= required && !change.executed) {
            executeOwnerChange(changeId);
        }
    }

    function executeOwnerChange(uint changeId) private {
        OwnerChange storage change = ownerChanges[changeId];
        require(change.confirmations >= required, "Insufficient confirmations");
        change.executed = true;
        if (change.isAdd) {
            require(!isOwner[change.owner], "Already an owner");
            isOwner[change.owner] = true;
            owners.push(change.owner);
        } else {
            require(isOwner[change.owner], "Not an owner");
            for (uint i = 0; i < owners.length; i++) {
                if (owners[i] == change.owner) {
                    owners[i] = owners[owners.length - 1];
                    owners.pop();
                    break;
                }
            }
            isOwner[change.owner] = false;
        }
        emit OwnerChangeExecuted(changeId, change.owner, change.isAdd);
    }

    function getTransactionByIndex(
        uint index
    ) public view returns (address, uint, bytes memory, bool, uint) {
        require(index < transactions.length, "Transaction index out of bounds");

        Transaction storage transaction = transactions[index];
        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.confirmations
        );
    }
}

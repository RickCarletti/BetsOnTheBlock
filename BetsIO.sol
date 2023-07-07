// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "hardhat/console.sol";

/**
 * @title BetsIO
 * @dev BetsIO
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
 */

contract BetsIO {

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    // INI Owner Details
    address private owner;
    
    event OwnerSet(address indexed oldOwner, address indexed newOwner);

    modifier isOwner() {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }

    constructor(){
        console.log("Owner contract deployed by:", msg.sender);
        owner = msg.sender; 
        emit OwnerSet(address(0), owner);
    }

    function changeOwner(address newOwner) public isOwner {
        emit OwnerSet(owner, newOwner);
        owner = newOwner;
    }
    // END Owner Details

    // INI ADM Details

    mapping(address => bool) private adms;

    event AdmNew(address indexed newAdm);
    event AdmDel(address indexed oldAdm);

    modifier isAdm(){
        if(owner != msg.sender){
            require(adms[msg.sender] == true, "Caller is not adminstrator");
        }
        _;
    }

    function addAdm(address newAdm) public isOwner {
        emit AdmNew(newAdm);
        adms[newAdm] = true;
    }

    function remAdm(address oldAdm) public isOwner {
        emit AdmDel(oldAdm);
        adms[oldAdm] = false;
    }

    // END ADM Details

    // INI FUNDS PLAYERS

    event RedeemAll(address indexed from_address, address indexed to_address);

    mapping(address => uint256) private address_value;

    function addFunds() public payable{
        address_value[msg.sender] = address_value[msg.sender] + msg.value;
    }

    function checkFunds() public view returns (uint)  {
        return address_value[msg.sender];
    }

    function redeemAll(address _to) public {
        (bool sent, bytes memory data) = _to.call{value: address_value[msg.sender]}("");
        require(sent, "Failed to send Ether");
        address_value[msg.sender] = 0;
        emit RedeemAll(msg.sender, _to);
    }

    // END FUNDS PLAYERS

    event CheckPool(
        uint poolId, 
        string description, 
        PoolStatus poolStatus, 
        string[] poolOptions, 
        uint256[] poolOptionsTotals, 
        Bet[] Bets, 
        int winningOption,
        uint256 poolTotal
    );

    event CheckMyBets(
        Bet[]
    );

    struct Bet{
        uint poolId;
        uint optionId;
		address better;
		uint value;
	}

    enum PoolStatus {Open, Closed, Canceled, Settled}

    struct Pool{
        uint poolId;
        string description;
        PoolStatus poolStatus;
        string[] poolOptions;
        uint256[] poolOptionsTotals;
        int winningOption;
        uint256 poolTotal;
    }

    mapping(uint => Bet[]) poolBets;

    mapping(address => Bet[]) addressBets;

    mapping(uint => Pool) allPools;

    uint private legthAddressBets;

    function createPool(string memory description, string[] memory options) public isAdm{
        Pool memory newPool;
        newPool.poolId = legthAddressBets;
        newPool.description = description;
        newPool.poolOptions = options;

        //Adaptação
        uint256[] memory temp = new uint256[](options.length);
        for(uint i=0; i<options.length; i++){
            temp[i] = 0;
        }
        newPool.poolOptionsTotals = temp;
        
        newPool.winningOption = -1;

        allPools[legthAddressBets] = newPool;

        legthAddressBets++;
    }


    function checkPool(uint poolId) public{
        emit CheckPool(
            allPools[poolId].poolId, 
            allPools[poolId].description, 
            allPools[poolId].poolStatus, 
            allPools[poolId].poolOptions, 
            allPools[poolId].poolOptionsTotals, 
            poolBets[poolId], 
            allPools[poolId].winningOption, 
            allPools[poolId].poolTotal
        );
    }

    function createBet(uint poolId, uint optionId, uint256 value) public{
        require(address_value[msg.sender] >= value, "Insufficient Funds");

        require(allPools[poolId].poolStatus == PoolStatus.Open, "Pool not Opened");

        require(allPools[poolId].poolOptions.length >= optionId, "Option not Exist");

        Bet memory bet;
        bet.poolId = poolId;
        bet.optionId = optionId;
        bet.better = msg.sender;
        bet.value = value;

        allPools[poolId].poolTotal = allPools[poolId].poolTotal + value;
        allPools[poolId].poolOptionsTotals[optionId] = allPools[poolId].poolOptionsTotals[optionId] + value;

        address_value[msg.sender] = address_value[msg.sender] - value;

        addressBets[msg.sender].push(bet);
        poolBets[poolId].push(bet);
    }

    function checkMyBets() public{
        emit CheckMyBets(addressBets[msg.sender]);
    }

    function closePool(uint poolId) public isAdm{
        require(allPools[poolId].poolStatus == PoolStatus.Open, "Pool not Opened");

        allPools[poolId].poolStatus = PoolStatus.Closed;
    }

    function cancelPool(uint poolId) public isAdm{
        require(allPools[poolId].poolStatus == PoolStatus.Closed, "Pool not Closed");

        Bet[] memory bets = poolBets[poolId];

        for(uint i=0; i<bets.length; i++){
            address_value[bets[i].better] = address_value[bets[i].better] + bets[i].value;
        }

        allPools[poolId].poolStatus = PoolStatus.Canceled;
    }

    function settledPool(uint poolId, uint winnerOption) public isAdm{
        require(allPools[poolId].poolStatus == PoolStatus.Closed, "Pool not Closed");

        require(allPools[poolId].poolOptions.length >= winnerOption, "Option not Exist");

        Bet[] memory bets = poolBets[poolId];
        uint256 tempValue;

        for(uint i=0; i<bets.length; i++){
            if(bets[i].optionId == winnerOption){
                // CALCULO DE PORCENTAGEM SEM CASA DECIMAL 
                tempValue = (((bets[i].value*10000)/(allPools[poolId].poolOptionsTotals[winnerOption]))*(allPools[poolId].poolTotal))/10000;
                address_value[bets[i].better] = address_value[bets[i].better] + tempValue;
            }
        }
        allPools[poolId].poolStatus = PoolStatus.Settled;
    }
} 
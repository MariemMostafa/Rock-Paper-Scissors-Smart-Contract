// SPDX-License-Identifier: GPL-3.0

// Mariem Mostafa  6873

pragma solidity ^0.8.4;
contract rockPaperScissors {
    struct choice {
        bytes32 blindedchoice;
        uint deposit;
    }

    address payable public contestManager;
    uint public commitmentEnd;
    uint public revealEnd;
    bool public ended;
    uint firstTimeFlag = 0;
    uint countParticipants = 1;
    
    mapping(address => choice[]) public choices;

    address payable public winner;
    uint public reward;
    string public bestChoice;

    mapping(address => uint) pendingReturns;

    event ContestEnded(address winner);

    error TooEarly(uint time);
    error TooLate(uint time);
    error ContestEndAlreadyCalled();

    modifier onlyBefore(uint time) {
        if (block.timestamp >= time) revert TooLate(time - block.timestamp);
        _;
    }
    modifier onlyAfter(uint time) {
        if (block.timestamp <= time) revert TooEarly(time - block.timestamp);
        _;
    }

    constructor
    (
        uint commitmentTime,
        uint revealTime,
        address payable contestManagerAddress
    ) 
    payable
    {
        contestManager = contestManagerAddress;
        commitmentEnd = block.timestamp + commitmentTime;
        revealEnd = commitmentEnd + revealTime;
        reward = msg.value;
    }

    function blind_a_choice(string calldata input, bytes32 secret) 
        public 
        pure 
        returns (bytes32){
        return keccak256(abi.encodePacked(input, secret));
    }


    function commitString(bytes32 blindedchoice)
        external
        payable
        onlyBefore(commitmentEnd)
    {
        if( countParticipants < 3 && msg.value > 0){
            countParticipants++;
            choices[msg.sender].push(
            choice({
            blindedchoice: blindedchoice,
            deposit: msg.value
            
        }));
        }

        else if ( countParticipants >= 3)
            revert("Only 2 participants are allowed!");

        // deposit must be more than reward to avoid the case where a participant aborts
        else if (msg.value < reward)
            revert("Deposit must be at least equal to or more than reward.");
    }

    function compareStrings(string memory a, string memory b) 
    internal 
    pure 
    returns (bool) {
    return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function compareInputs(string memory a, string memory bestchoice)
    internal
    pure  
    returns (bool)
    {
        
        if(compareStrings(a, "rock") && compareStrings(bestchoice, "paper")){
            return true;
        }
        else  if(compareStrings(a, "paper") && compareStrings(bestchoice, "scissors")){
            return true;
        }
        else  if(compareStrings(a, "scissors") && compareStrings(bestchoice, "rock")){
            return true;
        }
        else 
            return false;
    }


    function reveal(
        string[] calldata inputs,
        bytes32[] calldata secrets
    )
        payable
        external
        onlyAfter(commitmentEnd)
        onlyBefore(revealEnd)
    {
        uint length = choices[msg.sender].length;
        require(inputs.length == length);
        require(secrets.length == length);

        uint refund = 0;
        for (uint i = 0; i < length; i++) {
            choice storage choiceToCheck = choices[msg.sender][i];
            (string calldata input, bytes32 secret) = (inputs[i], secrets[i]);
        
        if( compareStrings(input, "rock") == false && compareStrings(input, "paper") == false && compareStrings(input, "scissors") == false)
            revert("Invalid Choice!");

        if (choiceToCheck.blindedchoice != keccak256(abi.encodePacked(input, secret))){
                // Bid was not actually revealed.
                // Do not refund deposit.
                continue;
            }

        refund = choiceToCheck.deposit;

        if(identifyWinner(msg.sender, input) == msg.sender)
            winner = payable (msg.sender);

        choiceToCheck.blindedchoice = bytes32(0);
        
        }       
        payable(msg.sender).transfer(refund);
    }


    function contestEnd()
        external
        onlyAfter(revealEnd)
    {
        if (ended) revert ContestEndAlreadyCalled();
        emit ContestEnded(winner);
        ended = true;
        winner.transfer(reward);
    }

    function identifyWinner(address participant, string memory input) internal
            returns (address w)
    {

        // The bestChoice is the input in the first reveal
        if (firstTimeFlag == 0){
            bestChoice = input;
            firstTimeFlag = 1;
        }


        if (compareInputs(input, bestChoice)){
            return winner;
        }

        bestChoice = input;
        winner = payable (participant);
        return winner;
    }

}
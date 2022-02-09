// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./SchoolOfRock.sol";

//Burner is owner of school of rock
contract BurnerV2 is Ownable {
    SchoolOfRock school;
    address public schoolAddress;
    
    struct BurnPowDetails {
        uint256 burnFee;
        uint256 difficulty;
        bytes32 previousHash;
    }
    BurnPowDetails public burnPowDetails;

    constructor(
        address newSchoolOfRockAddress,
        uint[12][12] memory newBurnRarityDistribution,
        uint256 newBurnFee,
        uint256 newBurnDifficulty,
        uint256[12] memory newRockTypeRarity,
        uint256[12] memory newRevenueSharePercentageByRockType
    ){
        setSchoolOfRock(newSchoolOfRockAddress);
        setBurnRarityDistribution(newBurnRarityDistribution);
        setBurnPowDetails(newBurnFee, newBurnDifficulty, false);
        setNewRockTypeRarity(newRockTypeRarity);
        setRevenueShareDetails(newRevenueSharePercentageByRockType);
    }

    function constructor2(
        int newMaxMintDistPercent,
        int newMaxMintWinners,
        int newMaxBurnDistPercent,
        int newMaxBurnWinners,
        uint256 newbaseMintGeneration,
        uint256 newbaseMintCost,
        uint256 newMintFactor,
        uint256 newMintDifficulty,
        uint256 newMintDifficultyFactor,
        uint256 newJackpotChance, 
        uint256 newJackpotDistPercent
    ) public onlyOwner {
        setMaxRewards(newMaxMintDistPercent, newMaxMintWinners, newMaxBurnDistPercent, newMaxBurnWinners);
        setMintPowDetails(newbaseMintGeneration,newbaseMintCost, newMintFactor, newMintDifficulty, newMintDifficultyFactor);
        setJackpotDetails(0, 90, newJackpotChance, newJackpotChance, newJackpotDistPercent);
    } 

    function setSchoolOfRock(address newSchoolOfRockAddress) public onlyOwner{
        school = SchoolOfRock(newSchoolOfRockAddress);
        schoolAddress = newSchoolOfRockAddress;
    }
    
    function setBurnPowDetails( uint256 newBurnFee, uint256 newDifficulty, bool actualDiff) public onlyOwner {
        burnPowDetails.burnFee = newBurnFee;
        if(actualDiff){
            burnPowDetails.difficulty = newDifficulty;
        } else {
            burnPowDetails.difficulty =
            uint256(
                0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
            ) /
            uint256(newDifficulty);
        }  
    }


    // *******************************************************
    // ***** These are all functions for collision ***********

    // index 0 shows burn rarity dist of burning 2 irons
    uint[12][12] public burnRarityDistribution;
    function setBurnRarityDistribution( uint[12][12] memory newBurnRarityDistribution) public onlyOwner {
        burnRarityDistribution = newBurnRarityDistribution;
    }

    // default only 2 planets can be burned for a new planet
    bool public extraPlanetAllowed;
    function setExtraPlanetAllowed(bool val) public onlyOwner {
        extraPlanetAllowed  = val;
    }

    // index 0 shows burn rarity dist of burning 3 irons
    uint[12][12] public burnRarityDistributionWithExtraToken;
    function setExtraBurnRarityDistribution( uint[12][12] memory newBurnRarityDistributionWithExtraToken) public onlyOwner {
        burnRarityDistributionWithExtraToken = newBurnRarityDistributionWithExtraToken;
    }

    // burn 2 tokens for a reroll
    event BurnAndRemint(uint256 tokenId1, uint256 tokenId2, int extraTokenId, uint burnTokenType, uint newTokenId);
    function combineAndBurnAndMint(uint256 tokenId1, uint256 tokenId2, int extraTokenId, uint nonce) public payable {
        (bool validPow, bytes32 powHash) = verifyBurnProofOfWork(msg.sender, nonce);
        require(validPow);
        // update burn proof of work details
        burnPowDetails.previousHash = powHash;

        uint rockType1 = school.getRockTypeFromTokenId(tokenId1);
        uint rockType2 = school.getRockTypeFromTokenId(tokenId2);

        // require that rock types are same, max extra tokens is correct, and user pays burn fee
        // diamonds cannot be burned
        require(rockType1 == rockType2 && rockType1 != 11 && msg.value == burnPowDetails.burnFee);

        // make sure owner of tokens are calling this function and not some rando.
        require(msg.sender == school.ownerOf(tokenId1) && msg.sender == school.ownerOf(tokenId2));

        // now with approval transfer token ownership to this contract
        school.transferFrom(msg.sender, address(this), tokenId1);
        school.transferFrom(msg.sender, address(this), tokenId2);

        // now with burn approval + free eth owed from token
        // burn will make sure token exist
        burnToken(tokenId1);
        burnToken(tokenId2);

        // get new rock token id
        uint newTokenId = school.currentTokenId() + 1;

        bytes32 newHash = keccak256(abi.encodePacked(powHash,block.timestamp));
        uint256 randomNum = (uint256(newHash) % 10000) + 1;

        uint256 currentRockType = 0;
        if(extraPlanetAllowed && extraTokenId > 0){
            uint extraTokenIdAsUint = uint(extraTokenId);

            uint extraRockType = school.getRockTypeFromTokenId(extraTokenIdAsUint);
            require(extraRockType == rockType1);

            // make sure owner owns extra token
            require(msg.sender == school.ownerOf(extraTokenIdAsUint));

            //transfer ownership to this contract
            school.transferFrom(msg.sender, address(this), extraTokenIdAsUint);
            //burn 
            burnToken(extraTokenIdAsUint);

            // get the rock type
            while (randomNum > burnRarityDistributionWithExtraToken[rockType1][currentRockType]) {currentRockType++;}
        } else {
            while (randomNum > burnRarityDistribution[rockType1][currentRockType]) {currentRockType++;}
        }

        emit BurnAndRemint(tokenId1, tokenId2, extraTokenId, rockType1, newTokenId);

        // distribute burn fee to rock holders
        if(msg.value > 0){
            payRockHolders(newHash, maxBurnDistPercent, maxBurnWinners);
        }
        jackpot(newHash, newTokenId, jackpotBurnChance);

        // create the token with the given type and add it to rockinfo 
        school.giftRock(currentRockType, msg.sender);

        // add token type info 
        addTokenIdToRockTypeInformation(newTokenId, currentRockType);

        // update mint cost + difficulty since token count changed
        updateProofOfWorkDetails(mintPowDetails.previousHash);
    }

    function burnToken(uint256 tokenId) internal {
        // get amount the rock tokenId is owed for holding
        uint256 amountOwed = rockTokenIdToAmountOwed[tokenId];

        // set the owed amount to be 0
        rockTokenIdToAmountOwed[tokenId] = 0;

        // reduce total amount owed by this contract
        totalAmountOwed -= amountOwed;

        // burn the token
        school.burn(tokenId);

        removeTokenIdToRockTypeInformation(tokenId);
    }


    function verifyBurnProofOfWork(address user, uint256 nonce)
        public
        view
        returns (bool, bytes32)
    {
        bytes32 powHash = keccak256(abi.encodePacked(user, burnPowDetails.previousHash, nonce));
        return (uint256(powHash) < burnPowDetails.difficulty, powHash);
    }

    function transferSchoolOfRockOwnership(address newOwner) public onlyOwner {
        school.transferOwnership(newOwner);
    }

    // ************* End of collision logic ******************
    // *******************************************************


    // *******************************************************
    // *********** These are all functions for mint **********

    //amount owed for each rock
    mapping(uint256 => uint256) public rockTokenIdToAmountOwed;
    //amount of reward cashed by a user over their lifetime
    mapping(address => uint256) public userToTotalRewardCashed;
    //total amount owed by contract right now
    uint256 public totalAmountOwed;
    // total amount given to public over the lifetime of this contract
    uint256 public totalAmountRewarded;

    // if 0 is 200, there is  20% chance to get rock type of 0
    // if 1 is 300, thenre is 10% chance to get tock type of 1 (300-200/10)
    uint256[12] public rockTypeRarity;
    function setNewRockTypeRarity(uint256[12] memory newRockTypeRarity)
        public
        onlyOwner
    {
        rockTypeRarity = newRockTypeRarity;
    }

    // index 0 is iron and has x percentage of revenue share
    uint256[12] public revenueSharePercentageByRockType;
    function setRevenueShareDetails(
        uint256[12] memory newRevenueSharePercentageByRockType
    ) public onlyOwner {
        revenueSharePercentageByRockType = newRevenueSharePercentageByRockType;
    }

   int public maxMintDistPercent;
   int public maxMintWinners;
   int public maxBurnDistPercent;
   int public maxBurnWinners;
   function setMaxRewards(
        int newMaxMintDistPercent,
        int newMaxMintWinners,
        int newMaxBurnDistPercent,
        int newMaxBurnWinners
    ) public onlyOwner {
        maxMintDistPercent = newMaxMintDistPercent;
        maxMintWinners = newMaxMintWinners;
        maxBurnDistPercent = newMaxBurnDistPercent;
        maxBurnWinners = newMaxBurnWinners;
    }

    struct PowDetails {
        // mint cost increases every generation by mint factor
        uint256 mintCost;
        uint256 mintFactor;
        bool mintStaticFlag;

        // difficulty decreases every generation by difficult factor
        uint256 difficulty;
        // typically 2 , this is the factor to reduce difficulty by every gen
        uint256 difficultyFactor;
        bool diffStaticFlag;

        // the generation number
        uint256 currentGeneration;

        bytes32 previousHash;
    }
    PowDetails public mintPowDetails;
    function setMintPowDetails(
        uint256 newbaseMintGeneration,
        uint256 newbaseMintCost,
        uint256 newMintFactor,
        uint256 newDifficulty,
        uint256 newDifficultyFactor
    ) public onlyOwner {
        mintPowDetails.currentGeneration = newbaseMintGeneration;
        mintPowDetails.mintCost = newbaseMintCost;
        mintPowDetails.mintFactor = newMintFactor;
        mintPowDetails.difficulty =
            uint256(
                0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
            ) /
            uint256(newDifficulty);
        mintPowDetails.difficultyFactor = newDifficultyFactor;
    }
    function setMintPOWStaticFlags(bool mintFlag, bool diffFlag) public onlyOwner {
        mintPowDetails.mintStaticFlag = mintFlag;
        mintPowDetails.diffStaticFlag = diffFlag;
    }

    function verifyMintProofOfWork(uint256 nonce)
        public
        view
        returns (bool, bytes32)
    {
        bytes32 powHash = keccak256(abi.encodePacked(msg.sender, mintPowDetails.previousHash, nonce));
        return (uint256(powHash) < mintPowDetails.difficulty, powHash);
    }

    function updateProofOfWorkDetails(bytes32 powHash)
        internal
    {   
        uint totalTokens = school.totalSupply();
        // update pow details if total tokens is greater than max tokens for current gen
        if (totalTokens > (2 ** mintPowDetails.currentGeneration)){
            mintPowDetails.currentGeneration++;
            // increase mint cost if flag is not set
            if (!mintPowDetails.mintStaticFlag){
                mintPowDetails.mintCost *= mintPowDetails.mintFactor;
            }

            // increase difficulty if flag is not set
            if(!mintPowDetails.diffStaticFlag){
                mintPowDetails.difficulty /= mintPowDetails.difficultyFactor;
            }
        } 
        // update pow details if total tokens is less than max tokens for prev gen
        else if (totalTokens <= (2 ** (mintPowDetails.currentGeneration - 1))){
            mintPowDetails.currentGeneration--;
            // decrease mint cost if flag is not set
            if (!mintPowDetails.mintStaticFlag){
                mintPowDetails.mintCost /= mintPowDetails.mintFactor;
            }

            // decrease difficulty if flag is not set
            if(!mintPowDetails.diffStaticFlag){
                mintPowDetails.difficulty *= mintPowDetails.difficultyFactor;
            }
        }

        //update the pow hash
        mintPowDetails.previousHash = powHash;
    }

    function explore(uint256 nonce) public payable {
        (bool validPow, bytes32 powHash) = verifyMintProofOfWork(nonce);
        require(validPow);
        require(msg.value == mintPowDetails.mintCost);

        bytes32 newHash = keccak256(abi.encodePacked(powHash,block.timestamp));

        // get new rock token id
        uint newTokenId = school.currentTokenId() + 1;

        // distribute minting cost to rock holders
        payRockHolders(newHash, maxMintDistPercent, maxMintWinners);

        // check jackpot / add to jackpot
        jackpot(newHash, newTokenId, jackpotMintChance);

        // get new rock type based on pow hash
        // and add to the new rock type information to contract
        // ex. 0=500, 1=800, 2=1000
        // this basically means 0 rocktype has 50% chance of getting picked, 1 rocktype has 30%,  2 rocktype has 20%
        // random number is picked from 1 - 1000
        uint256 randomNum = (uint256(newHash) % 1000) + 1;
        uint256 currentRockType = 0;
        while (randomNum > rockTypeRarity[currentRockType]) {currentRockType++;}

        // mint 
        school.giftRock(currentRockType, msg.sender);

        // add tokens to rock type information
        addTokenIdToRockTypeInformation(newTokenId, currentRockType);

        // update proof of work details
        updateProofOfWorkDetails(powHash);
    }

    event Winner(uint indexed mintedTokenId, address indexed winner, uint indexed winningTokenId, uint winningRockType, uint amount);
    function payRockHolders(bytes32 seed, int maxDistPercent, int maxWinners) internal {
        uint amountToDistribute = msg.value;
        uint256 stepNonce = 1;

        int currentMaxDistPercent = maxDistPercent;
        int currentWinners = maxWinners;

        uint lowestRevenueSharePerc = revenueSharePercentageByRockType[0];
        uint bestCurrentPossibleRockType = revenueSharePercentageByRockType.length - 1;

        while(currentWinners != 0 && currentMaxDistPercent > 0 && currentMaxDistPercent - int(lowestRevenueSharePerc) > 0){
            uint256 randomNum = uint256(keccak256(abi.encodePacked(seed,stepNonce++)));
            uint randomWinnerType = randomNum % (bestCurrentPossibleRockType + 1);

            uint256 totalNumberOfRockForGivenRockType = totalRocksPerRockType[randomWinnerType];
            if (totalNumberOfRockForGivenRockType == 0) continue;

            // select winner
            randomNum = uint256(keccak256(abi.encodePacked(seed,stepNonce++)));
            uint256 winnerRockTokenId = rockTypeToTokenList[randomWinnerType][randomNum % totalNumberOfRockForGivenRockType];

            //amount owed to rockTokenID
            uint256 rockRevenuePercentage = revenueSharePercentageByRockType[
                randomWinnerType
            ];
            uint256 amountOwed = (amountToDistribute * rockRevenuePercentage) /
                100;

            //distribute the amount and track changes
            rockTokenIdToAmountOwed[winnerRockTokenId] += amountOwed;
            address winningUserAddress = school.ownerOf(winnerRockTokenId);
            totalAmountOwed += amountOwed;
            
            emit Winner(school.currentTokenId() + 1, winningUserAddress, winnerRockTokenId, randomWinnerType, amountOwed);

            currentMaxDistPercent -= int(rockRevenuePercentage);
            while(currentMaxDistPercent > 0 &&
            currentMaxDistPercent < int(revenueSharePercentageByRockType[bestCurrentPossibleRockType])){
                if(bestCurrentPossibleRockType == 0) break;
                bestCurrentPossibleRockType--;
            }
            currentWinners--;
        }
    }

    // current jackpot amount
    uint256 public jackpotAmount;
    // 1/x chance to get jackpot through mint
    uint256 public jackpotMintChance;
    // 1/x chance to get jackpot through mint
    uint256 public jackpotBurnChance;
    // percentage of msg.value that is put into the jackpot
    uint256 public jackpotDistPercent;
    // percentage of jackpot given to winner
    uint256 public jackpotWinnerPercent;

    function setJackpotDetails(
        int newJackpotAmount,
        uint newJackpotWinnerPercent,
        uint256 newJackpotMintChance, 
        uint256 newJackpotBurnChance,
        uint256 newJackpotDistPercent
    ) public onlyOwner {
            jackpotWinnerPercent = newJackpotWinnerPercent;
            jackpotMintChance = newJackpotMintChance;
            jackpotBurnChance = newJackpotBurnChance;
            jackpotDistPercent = newJackpotDistPercent;
            if( newJackpotAmount > 0){
                jackpotAmount += uint(newJackpotAmount);
                totalAmountOwed += uint(newJackpotAmount);
            } else if( newJackpotAmount < 0){
                jackpotAmount -= uint(newJackpotAmount);
                totalAmountOwed -= uint(newJackpotAmount);
            }
    }
    event Jackpot(address indexed winner, uint jackpot, uint tokenId);
    function jackpot(bytes32 seed, uint256 newTokenId, uint256 chance) internal {
        uint256 randomNum = uint256(keccak256(abi.encodePacked(seed,uint(0))));
        bool winner = ((randomNum % chance) + 1) == chance;
        if(winner){
            uint winAmount = (jackpotAmount * jackpotWinnerPercent)/100;
            jackpotAmount -= winAmount;
            rockTokenIdToAmountOwed[newTokenId] += winAmount;
            emit Jackpot(msg.sender, winAmount, newTokenId);
        } else {
            uint amount = ((msg.value * jackpotDistPercent)/100);
            jackpotAmount += amount;
            totalAmountOwed += amount;
            emit Jackpot(address(0), jackpotAmount, newTokenId);
        }
    }

    // *************** End of mint logic *********************
    // *******************************************************

    // *******************************************************
    // ********** These are all functions for admin **********

    // pay  function
    event Withdraw(address indexed user, uint amount);
    function payUser(address user) public payable {
        require(msg.sender == user || msg.sender == owner());
        address owner = user;
        uint256 tokenCount = school.balanceOf(owner);
        uint256 amountOwedToUser = 0;
        if (tokenCount != 0) {
            // reset amount owed per token owned by user
            for (uint256 i = 0; i < tokenCount; i++) {
                uint256 tokenId = school.tokenOfOwnerByIndex(owner, i);
                amountOwedToUser += rockTokenIdToAmountOwed[tokenId];
                rockTokenIdToAmountOwed[tokenId] = 0;
            }

            // reduce smart contract debt
            totalAmountOwed -= amountOwedToUser;
            //  add to variable keeping track of rewards given out
            totalAmountRewarded += amountOwedToUser;
            // pay user
            payable(owner).transfer(amountOwedToUser);
            // update the total amount rewarded to user in their lifetime
            userToTotalRewardCashed[owner] += amountOwedToUser;
        }
        emit Withdraw(owner, amountOwedToUser);
    }

    struct RockSummary {
        uint256 tokenId;
        uint256 amountOwed;
    }
    function userSummary(address user)
        public
        view
        returns (RockSummary[] memory rockSummary, uint256 totalAmountOwedToUser, uint256 totalRewardsGiven)
    {
        address owner = user;
        uint256 tokenCount = school.balanceOf(owner);
        totalRewardsGiven += userToTotalRewardCashed[owner] + school.userToTotalRewardCashed(owner);
        if (tokenCount != 0) {
            rockSummary = new RockSummary[](tokenCount);
            for (uint256 i = 0; i < tokenCount; i++) {
                uint256 tokenId = school.tokenOfOwnerByIndex(owner, i);
                totalAmountOwedToUser += rockTokenIdToAmountOwed[tokenId];
                rockSummary[i] = RockSummary(
                    tokenId,
                    rockTokenIdToAmountOwed[tokenId]
                );            
            }
        }
    }


    function getContractBalance() public view returns (uint){
        return address(this).balance;
    }

    // contract owner can withdraw the fees
    function withdrawContractFee(bool feesMode, uint amountToWithdrawInWei) public payable onlyOwner {
        require(amountToWithdrawInWei <= address(this).balance - totalAmountOwed);
        uint amount = amountToWithdrawInWei;
        if (feesMode){
            amount= address(this).balance - totalAmountOwed;
        } 
        payable(msg.sender).transfer(amount);
    }

    // send funds to contract
    function sendFunds() public payable {}

    // *************** End of admin logic ********************
    // *******************************************************

    // *************** Start of logic to maintain rock types ***************
    // *********************************************************************

    // each index is the type of rock and the value is total number of rocks for that given rock type
    uint256[12] public totalRocksPerRockType;
    // Mapping from rock type to list of owned token IDs
    mapping(uint => mapping(uint256 => uint256)) public rockTypeToTokenList;
    // Mapping from token ID to index of the rock type tokens list
    mapping(uint256 => uint256) public tokenToIndexInRockTypeList;
    mapping(uint256 => uint) public tokenIdToRockType;

    function addTokenIdToRockTypeInformation(uint256 tokenId, uint256 rockType)
        internal
    {
        uint256 totalRockForGivenType = totalRocksPerRockType[rockType];
        rockTypeToTokenList[rockType][totalRockForGivenType] = tokenId;
        tokenToIndexInRockTypeList[tokenId] = totalRockForGivenType;
        totalRocksPerRockType[rockType]++;
        tokenIdToRockType[tokenId] = rockType;
    }

    function extendAddTokenInfo(uint256 tokenId, uint256 rockType) public onlyOwner {
        addTokenIdToRockTypeInformation(tokenId, rockType);
    }

    function removeTokenIdToRockTypeInformation(uint256 tokenId) internal {
        // swap the position of last token for a rock type with the token to delete
        uint rockType = tokenIdToRockType[tokenId];
        uint256 lastTokenIndexForRockType = totalRocksPerRockType[uint256(rockType)] - 1;
        uint256 tokenIndex = tokenToIndexInRockTypeList[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndexForRockType) {
            uint256 lastTokenIdForRockType = rockTypeToTokenList[rockType][lastTokenIndexForRockType];
            rockTypeToTokenList[rockType][tokenIndex] = lastTokenIdForRockType;
            tokenToIndexInRockTypeList[lastTokenIdForRockType] = tokenIndex;
        }

        delete tokenIdToRockType[tokenId];
        delete tokenToIndexInRockTypeList[tokenId];
        totalRocksPerRockType[uint256(rockType)]--;
    }

    function extendRemoveTokenInfo(uint256 tokenId) public onlyOwner {
        removeTokenIdToRockTypeInformation(tokenId);
    }

    function getRockTypeTokenIds(uint256 rockType)
        public
        view
        returns (uint256[] memory)
    {
        require(rockType >= 0 && rockType <= 11);
        uint256 totalRocks = totalRocksPerRockType[rockType];
        uint256[] memory rockTypeTokenIds = new uint256[](totalRocks);
        for (uint256 i = 0; i < totalRocks; i++) {
            rockTypeTokenIds[i] = rockTypeToTokenList[rockType][i];
        }
        return rockTypeTokenIds;
    }

    function migrateExistingRockTypeInformationFromIndex(uint start, uint end) public onlyOwner {
        for(uint rockIndex = start; rockIndex <= end; rockIndex++){
            uint tokenId = school.tokenByIndex(rockIndex);
            uint tokenType = school.getRockTypeFromTokenId(tokenId);
            addTokenIdToRockTypeInformation(tokenId, tokenType);
        }
    }

    function migrateExistingRockTypeInformationFromID(uint256[] calldata tokens, uint256 tokenType) external onlyOwner {
        uint length = tokens.length;
        for(uint rockIndex = 0; rockIndex < length; rockIndex++){
            uint tokenId = tokens[rockIndex];
            addTokenIdToRockTypeInformation(tokenId, tokenType);
        }
    }

    // ************************************************************
    // ***** These are all functions to modify School Of Rock *****
    
    //active
    function setBaseURI(string memory newBaseURI) public onlyOwner {
        school.setBaseURI(newBaseURI);
    }

    //active - gifting mechanism to gift a user a token of certain rock type for giveaways
    function giftRock(uint256 rockType, address to) public onlyOwner {
        // get new rock token id
        uint newTokenId = school.currentTokenId() + 1;
        school.giftRock(rockType, to);
        addTokenIdToRockTypeInformation(newTokenId, rockType);
    }

    //unused - after SOR migration is complete
    function withdrawSORContractFees(bool feesMode, uint amountToWithdrawInWei) public payable onlyOwner {
        school.withdrawContractFees(feesMode, amountToWithdrawInWei);
    }

    //unused  
    function setSORRevenueShareDetails(
        uint256[12] memory newRevenueSharePercentageByRockType,
        SchoolOfRock.PossibleRevenueShareCombination[] memory revenueShareCombinations
    ) public onlyOwner {
        school.setRevenueShareDetails(newRevenueSharePercentageByRockType, revenueShareCombinations);
    }

    //unused  
    function setSORRockTypeRarity(uint256[12] memory newRockTypeRarity)
        public
        onlyOwner
    {
        school.setRockTypeRarity(newRockTypeRarity);
    }

    //unused - after disabling toMint 
    function setSORPowDetails(
        uint256 newbaseMintCost,
        uint256 newMintFactor,
        uint256 newDifficulty,
        uint256 newDifficultyFactor
    ) public onlyOwner {
        school.setPowDetails(newbaseMintCost, newMintFactor, newDifficulty, newDifficultyFactor);
    }

    //unused  
    function setSORPOWStaticFlags(bool mintFlag, bool diffFlag) public onlyOwner {
        school.setPOWStaticFlags(mintFlag, diffFlag);
    }
}
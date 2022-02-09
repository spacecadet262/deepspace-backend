// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SchoolOfRock is ERC721Enumerable, Ownable{
    // *******************************************************
    // ***** RockManager starts here *****
    
    // if 0 is 200, there is  20% chance to get rock type of 0
    // if 1 is 300, thenre is 10% chance to get tock type of 1 (300-200/10)
    // refer  to getRockType for further clarification
    uint256[12] public rockTypeRarity;

    struct RockTypeInformation {
        // each index is the type of rock and the value is total number of rocks for that given rock type
        uint256[12] totalRocksPerRockType;
        // Mapping from rock type to list of owned token IDs
        mapping(uint => mapping(uint256 => uint256)) rockTypeToTokenList;
        // Mapping from token ID to index of the rock type tokens list
        mapping(uint256 => uint256) tokenToIndexInRockTypeList;
        mapping(uint256 => uint) tokenIdToRockType;
    }
    RockTypeInformation rockTypeInformation;

    // ex [0,1,1] -> winners are iron, and 2 aluminum
    struct PossibleRevenueShareCombination {
        uint256[] revenueShareCombination;
    }

    mapping(uint256 => PossibleRevenueShareCombination[]) rockTypeToAllRevenueShareCombinations;
    // index 0 is iron and has x percentage of revenue share
    uint256[12] public revenueSharePercentageByRockType;

    //amount owed for each rock
    mapping(uint256 => uint256) public rockTokenIdToAmountOwed;
    //amount owed to owner of rocks
    mapping(address => uint256) public userToTotalAmountOwed;
    //amount of reward cashed by a user over their lifetime
    mapping(address => uint256) public userToTotalRewardCashed;

    // total amount owed to public at this given time
    uint256 public totalAmountOwed;
    // total amount given to public over the lifetime of this contract
    uint256 public totalAmountRewarded;

    function addTokenIdToRockTypeInformation(uint256 tokenId, uint256 rockType)
        internal
    {
        uint256 totalRockForGivenType = rockTypeInformation
            .totalRocksPerRockType[rockType];
        rockTypeInformation.rockTypeToTokenList[rockType][
            totalRockForGivenType
        ] = tokenId;
        rockTypeInformation.tokenToIndexInRockTypeList[
            tokenId
        ] = totalRockForGivenType;
        rockTypeInformation.totalRocksPerRockType[rockType]++;
        rockTypeInformation.tokenIdToRockType[tokenId] = rockType;
    }

    function removeTokenIdToRockTypeInformation(uint256 tokenId) internal {
        // swap the position of last token for a rock type with the token to delete
        uint rockType = rockTypeInformation.tokenIdToRockType[tokenId];
        uint256 lastTokenIndexForRockType = rockTypeInformation
            .totalRocksPerRockType[uint256(rockType)] - 1;
        uint256 tokenIndex = rockTypeInformation.tokenToIndexInRockTypeList[
            tokenId
        ];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndexForRockType) {
            uint256 lastTokenIdForRockType = rockTypeInformation
                .rockTypeToTokenList[rockType][lastTokenIndexForRockType];

            rockTypeInformation.rockTypeToTokenList[rockType][
                    tokenIndex
                ] = lastTokenIdForRockType;
            rockTypeInformation.tokenToIndexInRockTypeList[
                lastTokenIdForRockType
            ] = tokenIndex;
        }

        delete rockTypeInformation.tokenIdToRockType[tokenId];
        delete rockTypeInformation.tokenToIndexInRockTypeList[tokenId];
        rockTypeInformation.totalRocksPerRockType[uint256(rockType)]--;
    }

    function getRockTypeTokenIds(uint256 rockType)
        public
        view
        returns (uint256[] memory)
    {
        require(rockType >= 0 && rockType <= 11);
        uint256 totalRocks = rockTypeInformation.totalRocksPerRockType[
            rockType
        ];
        uint256[] memory rockTypeTokenIds = new uint256[](totalRocks);
        for (uint256 i = 0; i < totalRocks; i++) {
            rockTypeTokenIds[i] = rockTypeInformation.rockTypeToTokenList[
                rockType
            ][i];
        }
        return rockTypeTokenIds;
    }

    function getRockTypeFromTokenId(uint256 tokenId)
        public
        view
        returns (uint256)
    {   
        require(_exists(tokenId));
        return rockTypeInformation.tokenIdToRockType[tokenId];
    }
    // ***** RockManager ends here *****
    // *******************************************************
    
    
    uint256 public currentTokenId = 0;
    string public baseURI;

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
        // this doubles every generation 2^n
        uint256 previousGenerationsSize;

        bytes32 previousHash;
    }
    PowDetails public powDetails;

    constructor(
        string memory name,
        string memory symbol,
        string memory newBaseURI,
        uint256 newBaseMintCost,
        uint256 newMintFactor,
        uint256 newDifficulty,
        uint256 newDifficultyFactor,
        uint256[12] memory newRockTypeRarity,
        uint256[12] memory newRevenueSharePercentageByRockType,
        PossibleRevenueShareCombination[] memory revenueShareCombinations
    ) ERC721(name, symbol) {
        setBaseURI(newBaseURI);
        setPowDetails(
            newBaseMintCost,
            newMintFactor,
            newDifficulty,
            newDifficultyFactor
        );
        powDetails.previousHash = blockhash(block.number);
        setRockTypeRarity(newRockTypeRarity);
        setRevenueShareDetails(
            newRevenueSharePercentageByRockType,
            revenueShareCombinations
        );

        // create one of each rock type and give it contract owner
        for (uint256 i = 0; i < 12; i++) {
            giftRock(i, msg.sender);
        }
    }

    function setRevenueShareDetails(
        uint256[12] memory newRevenueSharePercentageByRockType,
        PossibleRevenueShareCombination[] memory revenueShareCombinations
    ) public onlyOwner {
        revenueSharePercentageByRockType = newRevenueSharePercentageByRockType;

        for (uint256 i = 0; i < revenueShareCombinations.length; i++) {
            rockTypeToAllRevenueShareCombinations[revenueShareCombinations[i].revenueShareCombination[0]].
                push(revenueShareCombinations[i]);
        }
    }

    function setRockTypeRarity(uint256[12] memory newRockTypeRarity)
        public
        onlyOwner
    {
        rockTypeRarity = newRockTypeRarity;
    }

    function setPowDetails(
        uint256 newbaseMintCost,
        uint256 newMintFactor,
        uint256 newDifficulty,
        uint256 newDifficultyFactor
    ) public onlyOwner {
        powDetails.mintCost = newbaseMintCost;
        powDetails.mintFactor = newMintFactor;
        powDetails.difficulty =
            uint256(
                0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
            ) /
            uint256(newDifficulty);
        powDetails.difficultyFactor = newDifficultyFactor;
    }

    function setPOWStaticFlags(bool mintFlag, bool diffFlag) public onlyOwner {
        powDetails.mintStaticFlag = mintFlag;
        powDetails.diffStaticFlag = diffFlag;
    }

    function setBaseURI(string memory newBaseURI) public onlyOwner {
        baseURI = newBaseURI;
    }

    // Create a Gifting mechanism to give a user a token of certain rock type for free
    function giftRock(uint256 rockType, address to) public onlyOwner {
        // get new rock token id
        currentTokenId++;

        _mint(to, currentTokenId);
        // add token id to rockTypeInformation
        addTokenIdToRockTypeInformation(currentTokenId, rockType);

        // update proof of work
        updateProofOfWorkDetails(powDetails.previousHash, currentTokenId);
    }

    // todo: disable
    function mintTo(address to, uint256 nonce) public payable {
        (bool validPow, bytes32 powHash) = verifyProofOfWork(to, nonce);
        require(validPow);
        require(msg.value == powDetails.mintCost);

        bytes32 newHash = keccak256(abi.encodePacked(powHash,block.timestamp));

        // get new rock token id
        currentTokenId++;

        // update proof of work details
        updateProofOfWorkDetails(powHash, currentTokenId);

        // // distribute minting cost to rock holders
        payRockHolders(newHash);

        _mint(msg.sender, currentTokenId);

        // get new rock type based on pow hash
        // and add to the new rock type information to contract
        // ex. 0=500, 1=800, 2=1000
        // this basically means 0 rocktype has 50% chance of getting picked, 1 rocktype has 30%,  2 rocktype has 20%
        // random number is picked from 1 - 1000
        uint256 randomNum = (uint256(newHash) % 1000) + 1;
        uint256 currentRockType = 0;
        while (randomNum > rockTypeRarity[currentRockType]) {currentRockType++;}

        // add tokens to rock type information
        addTokenIdToRockTypeInformation(currentTokenId, currentRockType);

    }

    // todo: disable
    function verifyProofOfWork(address user, uint256 nonce)
        public
        view
        returns (bool, bytes32)
    {
        bytes32 powHash = keccak256(abi.encodePacked(user, powDetails.previousHash, nonce));
        return (uint256(powHash) < powDetails.difficulty, powHash);
    }

    // todo: disable
    function updateProofOfWorkDetails(bytes32 powHash, uint256 newTokenId)
        internal
    {
        // update pow details if generation changes
        if (newTokenId > powDetails.previousGenerationsSize) {
            //update prev generation size
            powDetails.previousGenerationsSize =
                2**powDetails.currentGeneration;

            // update mint cost if flag is not set
            if (!powDetails.mintStaticFlag){
                powDetails.mintCost *= powDetails.mintFactor;
            }

            // update difficulty if flag is not set
            if(!powDetails.diffStaticFlag){
                powDetails.difficulty /= powDetails.difficultyFactor;
            }

            powDetails.currentGeneration++;
        }
        //update the pow hash
        powDetails.previousHash = powHash;
    }

    // todo: disable
    event Winner(uint indexed mintedTokenId, address indexed winner, uint indexed winningTokenId, uint winningRockType, uint amount);
    function payRockHolders(bytes32 seed) internal {
        uint256 amountToDistribute = msg.value;
        uint256 stepNonce = 0;
        // pick a random rocktype as first winner
        uint256 randomNum = uint256(keccak256(abi.encodePacked(seed,stepNonce++)));
        PossibleRevenueShareCombination[] storage allRevShareCombosForRockType =  
            rockTypeToAllRevenueShareCombinations[randomNum % 12];
        randomNum = uint256(keccak256(abi.encodePacked(seed,stepNonce++)));
        // pick a random revenue share combination that contains the winning rock type
        uint[] storage randomRevenueShare = allRevShareCombosForRockType[
            randomNum % allRevShareCombosForRockType.length
        ].revenueShareCombination;
        
        // distribute revenue share to random owners
        for (uint256 i = 0; i < randomRevenueShare.length; i++) {
            uint256 rockTypeAsInt = randomRevenueShare[i];

            uint256 totalNumberOfRockForGivenRockType = rockTypeInformation
                .totalRocksPerRockType[rockTypeAsInt];
            // no rocks of that type exist so continue
            if (totalNumberOfRockForGivenRockType == 0) continue;
            randomNum = uint256(keccak256(abi.encodePacked(seed,stepNonce++)));
            uint256 winnerRockTokenId = rockTypeInformation.rockTypeToTokenList[
                rockTypeAsInt
            ][randomNum % totalNumberOfRockForGivenRockType];

            //amount owed to rockTokenID
            uint256 rockRevenuePercentage = revenueSharePercentageByRockType[
                rockTypeAsInt
            ];
            uint256 amountOwed = (amountToDistribute * rockRevenuePercentage) /
                100;

            //distribute the amount and track changes
            rockTokenIdToAmountOwed[winnerRockTokenId] += amountOwed;
            // get the owner address
            address owner = ownerOf(winnerRockTokenId);
            userToTotalAmountOwed[owner] += amountOwed;
            totalAmountOwed += amountOwed;

            emit Winner(currentTokenId, owner, winnerRockTokenId, rockTypeAsInt, amountOwed);
        }
    }

    function burn(uint256 tokenId) public {
        require(_exists(tokenId));

        address tokenOwner = ownerOf((tokenId));
        require(tokenOwner == msg.sender);

        // get amount the rock tokenId is owed for holding
        uint256 amountOwed = rockTokenIdToAmountOwed[tokenId];

        // set the owed amount to be 0
        rockTokenIdToAmountOwed[tokenId] = 0;

        // reduce the amount owed to previous owner of the rock
        userToTotalAmountOwed[tokenOwner] -= amountOwed;

        // reduce total amount owed by this contract
        totalAmountOwed -= amountOwed;

        // delete this token from rockTypeInfromation
        removeTokenIdToRockTypeInformation(tokenId);

        _burn(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            // mint
            // mint logic is done in mintTo and gift rock functions
        } else if (to == address(0)) {
            // burn
            // burn logic taken care of by burn function
        } else if (to != from) {
            // transfer from a user to another user
            uint256 amountOwed = rockTokenIdToAmountOwed[tokenId];
            userToTotalAmountOwed[from] -= amountOwed;
            userToTotalAmountOwed[to] += amountOwed;
        }
    }

    // todo: disable
    // pay  function
    event Withdraw(address indexed user, uint amount);
    function payUser() public payable {
        address owner = msg.sender;
        uint256 tokenCount = balanceOf(owner);
        uint256 amountOwed = userToTotalAmountOwed[owner];
        emit Withdraw(owner, amountOwed);
        if (tokenCount != 0 && amountOwed > 0) {
            // pay user
            payable(owner).transfer(amountOwed);
            // update the total amount rewarded to user in their lifetime
            userToTotalRewardCashed[owner] += amountOwed;

            // reset the amount owed to user
            userToTotalAmountOwed[owner] = 0;
            // reduce smart contract debt
            totalAmountOwed -= amountOwed;
            //  add to variable keeping track of rewards given out
            totalAmountRewarded += amountOwed;

            // reset amount owed per token owned by user
            for (uint256 i = 0; i < tokenCount; i++) {
                uint256 tokenId = tokenOfOwnerByIndex(owner, i);
                rockTokenIdToAmountOwed[tokenId] = 0;
            }
        }
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId));
        return string(abi.encodePacked(baseURI, "/", uintToString(tokenId)));
    }

    function uintToString(uint256 v) public pure returns (string memory) {
        uint256 maxlength = 100;
        bytes memory reversed = new bytes(maxlength);
        uint256 i = 0;
        while (v != 0) {
            uint256 remainder = v % 10;
            v = v / 10;
            reversed[i++] = bytes1(uint8(48 + remainder));
        }
        bytes memory s = new bytes(i);
        for (uint256 j = 0; j < i; j++) {
            s[j] = reversed[i - j - 1];
        }
        return string(s);
    }


    struct UserSummary {
        uint256 amountOwed;
        uint256 amountRewarded;
    }

    // todo: disable
    function userHighLevelSummary(address user)
        public
        view
        returns (UserSummary memory)
    {
        address owner = user;
        return
            UserSummary(
                userToTotalAmountOwed[owner],
                userToTotalRewardCashed[owner]
            );
    }

    struct RockSummary {
        uint256 tokenId;
        uint256 amountOwed;
    }

    // todo: disable
    function userRockLevelSummary(address user)
        public
        view
        returns (RockSummary[] memory)
    {
        address owner = user;
        uint256 tokenCount = balanceOf(owner);
        if (tokenCount == 0) {
            // Return an empty array
            return new RockSummary[](0);
        } else {
            RockSummary[] memory rockSummary = new RockSummary[](tokenCount);
            for (uint256 i = 0; i < tokenCount; i++) {
                uint256 tokenId = tokenOfOwnerByIndex(owner, i);
                rockSummary[i] = RockSummary(
                    tokenId,
                    rockTokenIdToAmountOwed[tokenId]
                );
            }
            return rockSummary;
        }
    }

    // todo: disable
    function getContractBalance() public view returns (uint){
        return address(this).balance;
    }

    // todo: disable
    // contract owner can withdraw the fees
    function withdrawContractFees(bool feesMode, uint amountToWithdrawInWei) public payable onlyOwner {
        require(amountToWithdrawInWei <= address(this).balance - totalAmountOwed);
        uint amount = amountToWithdrawInWei;
        if (feesMode){
            amount= address(this).balance - totalAmountOwed;
        } 
        payable(msg.sender).transfer(amount);
    }
}

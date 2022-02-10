Deep space backend:
Deepspace was an experimental novel project that tried to combine client-side proof-of-work with NFTs to create an open edition NFT that had intrinsic value and gave holders a passive income source. This was experimental in the sense that a proof-of-work combined with passive income was never done before, so with this project, I was aiming to see if this was a viable use-case for NFTs. Ultimately the project failed, but here is a technical walkthrough of the project along with the context of technical decisions.

Let's start with the backend side of things which can be found here: https://github.com/spacecadet262/deepspace-backend

Main contract - https://github.com/spacecadet262/deepspace-backend/blob/main/ethereum/contracts/SchoolOfRock.sol

Feel free to look around, but here are some points worthy of note:

1) giftRock function was created for giveaway purposes but was eventually repurposed for a different reason (more on this later)
2) The core of this contract is the proof-of-work(POW) , the client does the work to find the correct nonce that will allow a user to mint and verified by the verifyProofOfWork function
3) Once the client finds the correct nonce through POW, the client (browser) can use the mintTo function to mint an NFT. 
4) updateProofOfWorkDetails function will increase the difficulty of POW whenever the token count doubles (1,2,4,8, 16, etc.), which would require the client to do more work to find the correct nonce to mint. Additionally, whenever the difficulty of POW increases, so does mint cost. 
5) payRockHolders function will distribute the mint cost for newly minted randomly to holders of the NFT, which is the passive income portion of the project. 

Burner contract - https://github.com/spacecadet262/deepspace-backend/blob/main/ethereum/contracts/Burner.sol

This project, in its current functionality, had high demand, becoming an opensea top 100 project within a few days of launch. However, the prospect of passive income was a significant contributing factor to demand, and when the user count reached a critical mass, the rewards were not good enough and demand dramatically lessened. As a result, the experiment proved to be a failure, so I had to adapt to provide additional features for the project to survive. Thus the Burner contract was born. Due to a lucky inclusion of the giftRock function in the main contract, I created a wrapper around the main contract called Burner to do additional things, including collision (burn) and jackpot.

Key points:

1) Collision - a user could "collide" 2 planets to have a chance at minting a new planet instead of paying the mint price. The benefit of collision was that a user could collide two non-rare planets for a higher chance at a rare planet which gave better passive income. 
2) Jackpot - along with the passive income, a user could now win a jackpot whenever they minted or collided to randomly get a massive one-time reward. 

Server - https://github.com/spacecadet262/deepspace-backend/blob/main/src/main.js

This is imo the coolest part of the project. Essentially I hated the reveal aspect of other NFT projects, where you would mint an NFT and have to wait a few days for the reveal to find out what you got and its rarity. Why couldn't it just be instant? The answer is it can, but most projects want to create hype through the pre-reveal or lack the technical expertise to do it or follow what other projects are doing (*cough* sheep *cough*). There are many way to solve this, but this is my implementation:

I do instant reveal by :
1) Starting at line 96 is where I watch for mint events on every block to see if one my NFT's was minted and then I in real-time create the random metadata. 
2) One issue with this approach is that Opensea is slow af to reveal, and often time users have to manually press the refresh button for metadata to refresh. I felt like this was dumb and wanted to auto do it for the user, which is why refreshMetadataOnOpensea function exists in the helper.js. 

Job - https://github.com/spacecadet262/deepspace-backend/blob/main/src/main.js

WTF is a Job??? Well the reality of the situation is that servers are not always reliable, the blockchain event might error out, etc. It is possible for the metadata refresh not to happen due to various factors. To mitigate this, I created an ephemeral job that runs every 10 minutes, and the code can be found starting line 18 in main.js. I can run my server in "Job mode" which connects to a Redis cache to check if all NFTs minted in the past 10 minutes are valid. If not, the job will fix the metadata. 

I want to note this project is done with professional standard in mind, so I log everything of value and have a notification set to inform me if the server is down or of ANY  issues. Additionally, there is a lot of error checking, and validation to make sure the project is always working. A lot of the ways I am doing instant reveal, opensea refresh, and error checking jobs are rarely done before strategies within NFTs, that I consider to be a trade secrets. Ultimately, the project demand went to nothing after the first 2 weeks. I tried to add new features and market and collaborate, but managing this complex of a project alone was difficult. Additionally, the experiment based on POW and passive income while a noble pursuit, after this, I do not think it is a valid use case for NFTs. 


Front-end:

There is not anything particularly special about the front end. I used React + js to create the frontend. Check it out: https://deepspace-ce530.web.app/ 

Closing thoughts:

For this project, I was the sole developer, moderation, and promoter.  I created a front-end, multiple smart contract, backend to create images based on a mint event in real-time, and cron-job to verify and update metadata if errors occur. On release, this project had only a mint and burn functionality but, based on community feedback, was also updated to include a combine feature, where users can combine two NFTs to create a new one.

Throughout my experiences, I have worked with stakeholders to create the best product and listened to user feedback to increase product offerings. I am a problem-solver and dedicated partner liaison, and I believe that I would be an excellent addition to your team.



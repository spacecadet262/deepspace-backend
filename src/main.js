import express from "express";
import { space } from "../ethereum/space.js";
import { burner } from "../ethereum/burner.js";
import {
  sendMessageToDiscord,
  sendBurnMessageToDiscord,
  sendJackpotMessage,
} from "../discord/discord.js";
import redis from "redis";
import {
  createMetadataAndImage,
  validateAndUpdateMetadata,
  getPlanetType,
} from "./helper.js";
import logger from "../logging/logger.js";

//todo: create a domain?
if (process.env.MODE === "JOB") {
  logger.info({ system: "system" }, "starting in job mode");

  // connect to redis client
  var redisClient = redis.createClient(process.env.REDISCLOUD_URL, {
    no_ready_check: true,
  });

  redisClient.on("connect", function (error) {
    if (error) {
      logger.error(
        { system: "redis", error: error.message },
        "failed to connect to redis"
      );
    } else {
      logger.info({ system: "redis" }, "connected to redis");
    }
  });

  redisClient.get("blockNumber", async (error, reply) => {
    if (error) {
      logger.error(
        { system: "redis", error: error.message },
        "error attempting to get blockNumber from redis"
      );
    }

    // check if this is on init
    let blockNumber = 1;
    if (reply) {
      logger.info({ system: "redis" }, `got blockNumber ${reply}`);
      blockNumber = reply;
    }

    const pastEvents = await space.getPastEvents("Transfer", {
      filter: {
        from: "0x0000000000000000000000000000000000000000",
      },
      fromBlock: blockNumber,
    });

    // for each event, get the metadata, check if it has active  = "false", if so then generate correct metadata and image

    const pastEventsSize = pastEvents.length;
    await Promise.all(
      pastEvents.map(async (event, indx) => {
        const tokenID = event.returnValues.tokenId;
        logger.info({ tokenID }, `processing tokenID`);

        if (tokenID) {
          try {
            await validateAndUpdateMetadata(tokenID);
            logger.info({ tokenID }, `processed tokenID`);
          } catch (error) {
            logger.error(
              { tokenID, error: error.message },
              `failed to process tokenID`
            );
          }
        }

        // update blockNumber
        if (indx + 1 === pastEventsSize && tokenID) {
          const newBlockNumber = event.blockNumber;
          redisClient.set("blockNumber", newBlockNumber);
          logger.info(
            { system: "redis" },
            `updated BlockNumer from ${blockNumber} to ${newBlockNumber}`
          );
        }
      })
    );

    process.exit(0);
  });

  logger.info({ system: "system" }, "finished job");
} else {
  logger.info({ system: "system" }, "starting in server mode");

  // cache to keep track of processed tokenIDs
  let processedTokenIds = {};

  space.events.Transfer(
    {
      filter: {
        from: "0x0000000000000000000000000000000000000000",
      },
      fromBlock: "latest",
    },
    async (error, event) => {
      if (error) {
        logger.error(
          { system: "system", error: error.message },
          "failed to get event"
        );
      }
      if (event) {
        // get token ID
        const tokenID = event.returnValues.tokenId;
        logger.info({ tokenID: tokenID }, "processing event");

        // check processedTokenIds cache to check if
        // this is a duplicate event and can be ignored
        if (processedTokenIds[tokenID]) {
          logger.info(
            { tokenID: tokenID },
            "token already exists in processed cache"
          );
          return;
        }

        // process the event
        try {
          // create and upload metadata/image
          const data = await validateAndUpdateMetadata(tokenID);
          // set this token has been processed in cache
          processedTokenIds[tokenID] = true;
          // send mint message to discord if it metadata is valid
          if (data && data.attributes) {
            await sendMessageToDiscord(tokenID, data.attributes.planet);
          }
          logger.info({ tokenID: tokenID }, "processed event");
        } catch (error) {
          logger.error(
            { tokenID: tokenID, error: error.message },
            "failed to process event"
          );
          // don't throw error, so this will keep processing new events
        }
      }
    }
  );

  // process collisions
  // cache to keep track of processed tokenIDs
  let processedBurnTokenIds = {};
  burner.events.BurnAndRemint(
    {
      fromBlock: "latest",
    },
    async (error, event) => {
      if (error) {
        logger.error(
          { system: "system", error: error.message },
          "failed to get burn event"
        );
      }
      if (event) {
        const tokenID = event.returnValues.newTokenId;
        logger.info({ tokenID: tokenID }, "processing burn event");
        if (processedBurnTokenIds[tokenID]) {
          logger.info(
            { tokenID: tokenID },
            "token already exists in burn cache"
          );
          return;
        }

        const planet1 = event.returnValues.tokenId1;
        const planet2 = event.returnValues.tokenId2;
        const extraPlanet = event.returnValues.extraTokenId;
        const burnPlanetType = event.returnValues.burnTokenType;

        try {
          const tokenType = await getPlanetType(tokenID);
          await sendBurnMessageToDiscord(
            planet1,
            planet2,
            extraPlanet,
            burnPlanetType,
            tokenID,
            tokenType
          );

          logger.info({ tokenID: tokenID }, "processed burn event");
          processedBurnTokenIds[tokenID] = true;
        } catch (error) {
          logger.error(
            { tokenID: tokenID, error: error.message },
            "failed to process burn event"
          );
        }
      }
    }
  );

  // process jackpot
  // cache to keep track of jackpot tokenIDs
  let processedJackpotTokenIds = {};
  burner.events.Jackpot(
    {
      fromBlock: "latest",
    },
    async (error, event) => {
      if (error) {
        logger.error(
          { system: "system", error: error.message },
          "failed to get jackpot event"
        );
      }
      if (event) {
        const tokenID = event.returnValues.tokenId;
        logger.info({ tokenID: tokenID }, "processing jackpot event");
        if (processedJackpotTokenIds[tokenID]) {
          logger.info(
            { tokenID: tokenID },
            "token already exists in jackpot cache"
          );
          return;
        }

        const winnerAddress = event.returnValues.winner;
        const jackpotAmount = event.returnValues.jackpot;

        try {
          await sendJackpotMessage(winnerAddress, tokenID, jackpotAmount);
          logger.info({ tokenID: tokenID }, "processed jackpot event");
          processedJackpotTokenIds[tokenID] = true;
        } catch (error) {
          logger.error(
            { tokenID: tokenID, error: error.message },
            "failed to process jackpot event"
          );
        }
      }
    }
  );

  // just here for heroku
  const app = express();
  const PORT = process.env.PORT || 5000;
  app.listen(PORT, function () {
    console.log(`Listening on Port ${PORT}`);
  });
}

import { Client, Intents } from "discord.js";
import logger from "../logging/logger.js";
import { typetoPlanetMapping } from "../imageProcess/constants.js";
import Web3 from "web3";
const web3 = new Web3();

const TOKEN = process.env.DISCORD_TOKEN;
const PLANET_CHANNEL = process.env.PLANET_CHANNEL;
const BURN_CHANNEL = process.env.BURN_CHANNEL;
const JACKPOT_CHANNEL = process.env.JACKPOT_CHANNEL;

const client = new Client({
  intents: [Intents.FLAGS.GUILDS, Intents.FLAGS.GUILD_MESSAGES],
});

client.once("ready", () => {
  logger.info({ system: "discord" }, "client is ready");
});

try {
  await client.login(TOKEN);
  logger.info({ system: "discord" }, "client is logged in");
} catch (error) {
  logger.error(
    { system: "discord", error: error.message },
    "client failed to log in"
  );
}

const sendMessageToDiscord = async (tokenID, type) => {
  logger.info({ tokenID, system: "discord" }, "sending message to discord");

  try {
    await client.channels.cache
      .get(PLANET_CHANNEL)
      .send(`Planet ${tokenID} of type ${type.toUpperCase()} minted!`);
    logger.info({ tokenID, system: "discord" }, "message sent");
  } catch (error) {
    logger.error(
      { tokenID, system: "discord", error: error.message },
      "error sending message"
    );
  }
};

const sendBurnMessageToDiscord = async (
  planet1,
  planet2,
  extraPlanet,
  burnPlanetType,
  tokenID,
  tokenType
) => {
  logger.info(
    { tokenID, system: "discord" },
    "sending burn message to discord"
  );

  try {
    await client.channels.cache
      .get(BURN_CHANNEL)
      .send(
        `Planet ${tokenID} of type ${typetoPlanetMapping[
          tokenType
        ].toUpperCase()} minted by burning Planet ${planet1} + Planet ${planet2} ${
          extraPlanet > 0 ? `+ ${extraPlanet}` : ""
        } of type ${typetoPlanetMapping[burnPlanetType].toUpperCase()}`
      );
    logger.info({ tokenID, system: "discord" }, "burn message sent");
  } catch (error) {
    logger.error(
      { tokenID, system: "discord", error: error.message },
      "error sending burn message"
    );
  }
};

const sendJackpotMessage = async (address, tokenID, jackpotAmount) => {
  logger.info(
    { tokenID, system: "discord" },
    "sending jackpot message to discord"
  );

  const jackpot = web3.utils.fromWei(jackpotAmount, "ether");

  try {
    let msg = "";
    if (address === "0x0000000000000000000000000000000000000000") {
      msg = `JACKPOT amount is ${jackpot} ETH as of Planet ${tokenID}`;
    } else {
      msg = `Planet ${tokenID} won JACKPOT of ${jackpot} ETH`;
    }
    await client.channels.cache.get(JACKPOT_CHANNEL).send(msg);
    logger.info({ tokenID, system: "discord" }, "jackpot message sent");
  } catch (error) {
    logger.error(
      { tokenID, system: "discord", error: error.message },
      "error sending jackpot message"
    );
  }
};

export { sendMessageToDiscord, sendBurnMessageToDiscord, sendJackpotMessage };

import Web3 from "web3";
import logger from "../logging/logger.js";
import { createAlchemyWeb3 } from "@alch/alchemy-web3";

// Using WebSockets
const web3 = createAlchemyWeb3(process.env.WEBSOCKET_ADDRESS);
export default web3;

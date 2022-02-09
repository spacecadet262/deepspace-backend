import web3 from "./web3.js";
import contract from "./build/contracts/BurnerV2.json";

const contractAddress = process.env.BURNER_ADDRESS;
const burner = new web3.eth.Contract(contract.abi, contractAddress);

export { burner, contractAddress };

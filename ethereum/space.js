import web3 from "./web3.js";
import contract from "./build/contracts/SchoolOfRock.json";

//todo: update this
const contractAddress = process.env.DEEPSPACE_ADDRESS;
const space = new web3.eth.Contract(contract.abi, contractAddress);

// burner deployed
export { space, contractAddress };

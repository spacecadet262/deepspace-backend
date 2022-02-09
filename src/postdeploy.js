import { uploadFile, uploadMetadata } from "../aws/client.js";
import { createImage, generateMetadata } from "../imageProcess/imager.js";
import { space } from "../ethereum/space.js";
import { refreshMetadataOnOpensea } from "./helper.js";

// create the metadata and images for the first 12 planets
for (let i = 1; i <= 12; i++) {
  // get token ID
  const tokenID = i;
  console.log("Got the mint for token: " + tokenID);
  try {
    //get type
    const type = await space.methods.getRockTypeFromTokenId(tokenID).call();
    console.log("Found token ID " + tokenID + " rock type: " + type);

    const uri = await space.methods.tokenURI(tokenID).call();
    console.log("token ID " + tokenID + " tokenuri: " + uri);

    // generate the metadata with attributes
    const { metadata, attributes } = generateMetadata(tokenID, type);
    // upload metadata
    await uploadMetadata(metadata, tokenID);

    //create the image with the attributes
    const data = await createImage(tokenID, attributes);
    await uploadFile(data, tokenID);
    console.log("Image upload successfull for token: " + tokenID);

    await refreshMetadataOnOpensea(tokenID);
  } catch (error) {
    console.log("failed to update token: " + tokenID);
  }
}

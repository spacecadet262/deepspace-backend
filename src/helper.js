import { space, contractAddress } from "../ethereum/space.js";
import {
  uploadFile,
  uploadMetadata,
  getMetadataAsJson,
} from "../aws/client.js";
import { createImage, generateMetadata } from "../imageProcess/imager.js";
import axios from "axios";
import logger from "../logging/logger.js";

const createMetadataAndImage = async (tokenID) => {
  try {
    logger.info({ tokenID: tokenID }, "starting metadata and image upload");

    // get planet type
    const type = await getPlanetType(tokenID);

    // generate the metadata with attributes
    const { metadata, attributes } = generateMetadata(tokenID, type);

    // upload metadata
    await uploadMetadata(metadata, tokenID);

    // create the image with the attributes
    const data = await createImage(tokenID, attributes);

    // upload the image to S3
    await uploadFile(data, tokenID);

    // try to refresh opensea
    await refreshMetadataOnOpensea(tokenID);

    logger.info({ tokenID: tokenID }, "finished metadata and image upload");
    return { metadata, attributes };
  } catch (error) {
    logger.error(
      { tokenID: tokenID, error: error.message },
      "failed metadata and image upload"
    );
    throw error;
  }
};

const validateAndUpdateMetadata = async (tokenID) => {
  try {
    logger.info({ tokenID }, "validating and updating metadata");
    const metadata = await getMetadataAsJson(tokenID);
    if (
      metadata.active === "false" ||
      metadata.image === `${process.env.CLOUDCUBE_URL}/public/base.png`
    ) {
      logger.info({ tokenID }, "metadata is not correct");
      // return metadata and attributes
      return await createMetadataAndImage(tokenID);
    } else {
      logger.info({ tokenID }, "metadata is already correct");
      // if metadata is correct return an empty object
      return {};
    }
  } catch (error) {
    logger.error(
      { tokenID, error: error.message },
      "failed to validate and update metadata"
    );
    throw error;
  }
};

const refreshMetadataOnOpensea = async (tokenID) => {
  //TODO: update this for mainnet
  const validateURL = `https://api.opensea.io/asset/${contractAddress}/${tokenID}/?force_update=true`;
  // const validateURL = `https://testnets-api.opensea.io/asset/${contractAddress}/${tokenID}/validate/`;
  // const validateURL = `https://testnets-api.opensea.io/api/v1/asset/${contractAddress}/${tokenID}/?force_update=true`;
  try {
    logger.info({ tokenID, validateURL }, "refreshing metadata on opensea");
    const data = await axios.get(validateURL);
    logger.info(
      { tokenID, validateURL, status: data.status },
      "refreshed metadata on opensea"
    );
  } catch (error) {
    // if error status code is 404, then that means it probably worked so don't throw error
    if (error.response.status === 404) {
      logger.info(
        { tokenID, validateURL, status: error.response.status },
        "refreshed metadata on opensea"
      );
      return;
    } else {
      logger.error(
        { tokenID, validateURL, error: error.message },
        "failed to refresh metadata on opensea"
      );
      throw error;
    }
  }
};

// get the type of planet for token id
const getPlanetType = async (tokenID) => {
  logger.info({ tokenID: tokenID }, "finding rock type");
  try {
    const type = await space.methods.getRockTypeFromTokenId(tokenID).call();
    logger.info({ tokenID: tokenID, rockType: type }, "found rock type");
    return type;
  } catch (error) {
    logger.error(
      { tokenID: tokenID, error: error.message },
      "failed to find rock type"
    );
    throw error;
  }
};

export {
  createMetadataAndImage,
  validateAndUpdateMetadata,
  refreshMetadataOnOpensea,
  getPlanetType,
};

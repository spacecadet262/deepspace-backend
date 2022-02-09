import AWS from "aws-sdk";
import logger from "../logging/logger.js";

const system = { system: "s3" };

var credentials = new AWS.Credentials(
  process.env.CLOUDCUBE_ACCESS_KEY_ID,
  process.env.CLOUDCUBE_SECRET_ACCESS_KEY
);

const BUCKET = process.env.CLOUDCUBE_BUCKET;
const CLOUD_CUBE = process.env.CLOUDCUBE_CUBE;

AWS.config.credentials = credentials;

// Set the Region
AWS.config.update({ region: "us-east-1" });

// Create S3 service object
const s3 = new AWS.S3({ apiVersion: "2006-03-01" });

// Call S3 to list the buckets
s3.listBuckets(function (error, data) {
  if (error) {
    logger.error({ system, error: error.message }, "AWS S3 connect error");
  } else {
    logger.info({ system }, "AWS S3 connect succesful");
  }
});

const uploadFile = async (data, tokenID) => {
  // Setting up S3 upload parameters
  const params = {
    Bucket: BUCKET,
    Key: `${CLOUD_CUBE}/public/planet/image/${tokenID}.png`, // File name you want to save as in S3
    Body: data,
  };

  try {
    logger.info({ system, tokenID, Key: params.Key }, "uploading image");
    await s3.upload(params).promise();
    logger.info({ system, tokenID, Key: params.Key }, "uploaded image");
  } catch (error) {
    logger.error(
      { system, tokenID, Key: params.Key, error: error.message },
      "failed to upload image"
    );
    throw error;
  }
};

const uploadBaseFile = async (data) => {
  // Setting up S3 upload parameters
  const params = {
    Bucket: BUCKET,
    Key: `${CLOUD_CUBE}/public/base.png`, // File name you want to save as in S3
    Body: data,
  };
  // Uploading files to the bucket
  return s3.upload(params).promise();
};

const uploadMetadata = async (metadata, tokenID) => {
  const params = {
    Bucket: BUCKET,
    Key: `${CLOUD_CUBE}/public/planet/metadata/${tokenID}`,
    Body: JSON.stringify(metadata),
    ContentType: "application/json; charset=utf-8",
  };
  try {
    logger.info({ system, tokenID, metadata, params }, "uploading metadata");
    await s3.putObject(params).promise();
    logger.info({ system, tokenID, metadata, params }, "uploaded metadata");
  } catch (error) {
    logger.error(
      { system, tokenID, metadata, params, error: error.message },
      "failed to upload metadata"
    );
    throw error;
  }
};

const getMetadataAsJson = async (tokenID) => {
  const params = {
    Bucket: BUCKET,
    Key: `${CLOUD_CUBE}/public/planet/metadata/${tokenID}`,
  };

  try {
    logger.info({ system, tokenID, params }, "getting metadata");
    const data = JSON.parse(
      (await s3.getObject(params).promise()).Body.toString("utf-8")
    );
    logger.info({ system, tokenID, params }, "got metadata");
    return data;
  } catch (error) {
    logger.error(
      { system, tokenID, params, error: error.message },
      "failed to get metadata"
    );
    // if error, return empty object, so job will try to create metadata
    return {};
  }
};
export { uploadFile, uploadMetadata, uploadBaseFile, s3, getMetadataAsJson };

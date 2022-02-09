import { uploadMetadata, uploadBaseFile, s3 } from "../aws/client.js";
import { generateDummyMetadata } from "../imageProcess/imager.js";
import Jimp from "jimp";

const BUCKET = process.env.CLOUDCUBE_BUCKET;
const CLOUD_CUBE = process.env.CLOUDCUBE_CUBE;

// Delete the Bucket Completely
var params = {
  Bucket: BUCKET,
  Prefix: `${CLOUD_CUBE}/public/`, // Can be your folder name
};
while (true) {
  const listedObjects = await s3.listObjectsV2(params).promise();
  const numberOfObjects = listedObjects.Contents.length;
  console.log("number of keys: " + numberOfObjects);
  if (numberOfObjects > 0) {
    const deleteParams = {
      Bucket: BUCKET,
      Delete: { Objects: [] },
    };
    listedObjects.Contents.forEach(({ Key }) => {
      deleteParams.Delete.Objects.push({ Key });
      console.log("deleted file");
    });
    await s3.deleteObjects(deleteParams).promise();
  } else {
    break;
  }
}

// upload the base placeholder image
const baseImage = await Jimp.read(`./baseImages/base.png`);
const data = await baseImage.getBufferAsync(Jimp.MIME_PNG);
await uploadBaseFile(data);

// create dummy metadata for 1000 tokens
for (let i = 1; i <= 10000; i++) {
  const tokenID = i;
  uploadMetadata(generateDummyMetadata(tokenID), tokenID);
}

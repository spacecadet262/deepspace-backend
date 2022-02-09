import {
  typetoPlanetMapping,
  eyes,
  mouths,
  backgrounds,
  accessories,
  description,
} from "./constants.js";
import Jimp from "jimp";
import logger from "../logging/logger.js";

const eyesLength = eyes.length;
const mouthsLength = mouths.length;
const backgroundsLength = backgrounds.length;
const accessoriesLength = accessories.length;

// ring is a special case, where there is a back layer and front layer
const createImage = async (tokenID, attributes) => {
  try {
    logger.info({ tokenID, attributes }, "creating image");
    const background = await Jimp.read(
      `./baseImages/background/${attributes.background}.png`
    );
    const planet = await Jimp.read(
      `./baseImages/planets/${attributes.planet}.png`
    );
    const eyes = await Jimp.read(`./baseImages/eye/${attributes.eyes}.png`);
    const mouth = await Jimp.read(`./baseImages/mouth/${attributes.mouth}.png`);

    let accessoryType = attributes.accessory;
    const accessory = await Jimp.read(
      accessoryType === "ring"
        ? `./baseImages/accessory/${accessoryType}_front.png`
        : `./baseImages/accessory/${accessoryType}.png`
    );

    let accessoryBackLayer;
    if (accessoryType === "ring") {
      accessoryBackLayer = await Jimp.read(
        `./baseImages/accessory/${accessoryType}_back.png`
      );
    }

    let finalImage = background;

    if (accessoryType === "ring") {
      finalImage = finalImage.composite(accessoryBackLayer, 0, 0, {
        mode: Jimp.BLEND_SOURCE_OVER,
      });
    }

    finalImage = finalImage.composite(planet, 0, 0, {
      mode: Jimp.BLEND_SOURCE_OVER,
    });

    finalImage = finalImage.composite(eyes, 0, 0, {
      mode: Jimp.BLEND_SOURCE_OVER,
    });

    finalImage = finalImage.composite(mouth, 0, 0, {
      mode: Jimp.BLEND_SOURCE_OVER,
    });

    finalImage = finalImage.composite(accessory, 0, 0, {
      mode: Jimp.BLEND_SOURCE_OVER,
    });

    logger.info({ tokenID, attributes }, "created image");
    return await finalImage.getBufferAsync(Jimp.MIME_PNG);
  } catch (error) {
    logger.error(
      { tokenID, attributes, error: error.message },
      "failed to create image"
    );
    throw error;
  }
};

const generateMetadata = (tokenID, type) => {
  logger.info({ tokenID: tokenID }, "generating metadata and attributes");
  let metadata = {
    description: description,
    image: `${process.env.CLOUDCUBE_URL}/public/planet/image/${tokenID}.png`,
    name: `Planet ${tokenID}`,
    attributes: [],
  };
  const data = generateAttributes(type);
  metadata.attributes = data.metadata;
  const attributes = data.attributes;

  logger.info(
    { tokenID: tokenID, metadata, attributes },
    "generated metadata and attributes"
  );

  return { metadata, attributes };
};

const generateAttributes = (type) => {
  const planetType = typetoPlanetMapping[type];
  const randomBg = backgrounds[getRandomInt(0, backgroundsLength)];
  const randomEye = eyes[getRandomInt(0, eyesLength)];
  const randomMouth = mouths[getRandomInt(0, mouthsLength)];
  const randomAccessory = accessories[getRandomInt(0, accessoriesLength)];

  return {
    metadata: [
      {
        trait_type: "Type",
        value: planetType,
      },
      {
        trait_type: "Background",
        value: randomBg,
      },
      {
        trait_type: "Eyes",
        value: randomEye,
      },
      {
        trait_type: "Mouth",
        value: randomMouth,
      },
      {
        trait_type: "Accessory",
        value: randomAccessory,
      },
    ],
    attributes: {
      planet: planetType,
      background: randomBg,
      eyes: randomEye,
      mouth: randomMouth,
      accessory: randomAccessory,
    },
  };
};

const generateDummyMetadata = (tokenID) => {
  const metadata = {
    description: description,
    image: `${process.env.CLOUDCUBE_URL}/public/base.png`,
    name: `Planet ${tokenID}`,
    active: "false",
  };
  return metadata;
};

function getRandomInt(min, max) {
  min = Math.ceil(min);
  max = Math.floor(max);
  return Math.floor(Math.random() * (max - min) + min); //The maximum is exclusive and the minimum is inclusive
}

export { createImage, generateMetadata, generateDummyMetadata };

const fs = require('node:fs');
const path = require('node:path');
const { createCanvas, loadImage } = require('../backend/node_modules/@napi-rs/canvas');

const root = path.resolve(__dirname, '..');
const sourcePath = path.join(root, 'assets/branding/medishield-logo-source.png');
const markPath = path.join(root, 'assets/branding/medishield-launcher-mark.png');
const playStorePath = path.join(root, 'assets/branding/medishield-play-store-icon-512.png');
const markCrop = { x: 420, y: 35, width: 780, height: 640 };

function renderSquare(image, size, crop, maxFraction) {
  const canvas = createCanvas(size, size);
  const context = canvas.getContext('2d');
  context.fillStyle = '#FFFFFF';
  context.fillRect(0, 0, size, size);
  context.imageSmoothingEnabled = true;
  context.imageSmoothingQuality = 'high';

  const source = crop ?? { x: 0, y: 0, width: image.width, height: image.height };
  const scale = Math.min(
    (size * maxFraction) / source.width,
    (size * maxFraction) / source.height,
  );
  const width = source.width * scale;
  const height = source.height * scale;
  const x = (size - width) / 2;
  const y = (size - height) / 2;

  context.drawImage(
    image,
    source.x,
    source.y,
    source.width,
    source.height,
    x,
    y,
    width,
    height,
  );
  return canvas.toBuffer('image/png');
}

function writeIcon(relativePath, size, image, crop, maxFraction) {
  const outputPath = path.join(root, relativePath);
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, renderSquare(image, size, crop, maxFraction));
}

async function main() {
  const image = await loadImage(sourcePath);
  if (markCrop.x + markCrop.width > image.width || markCrop.y + markCrop.height > image.height) {
    throw new Error(`Logo crop exceeds source dimensions ${image.width}x${image.height}`);
  }

  writeIcon('assets/branding/medishield-launcher-mark.png', 1024, image, markCrop, 0.82);
  writeIcon('assets/branding/medishield-play-store-icon-512.png', 512, image, null, 0.94);

  const densities = [
    ['mdpi', 48],
    ['hdpi', 72],
    ['xhdpi', 96],
    ['xxhdpi', 144],
    ['xxxhdpi', 192],
  ];
  for (const [density, size] of densities) {
    writeIcon(`android/app/src/main/res/mipmap-${density}/ic_launcher.png`, size, image, markCrop, 0.82);
  }

  // Keep the adaptive-icon foreground inside the Android launcher safe zone.
  writeIcon('android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png', 432, image, markCrop, 0.66);
  writeIcon('web/icons/Icon-192.png', 192, image, markCrop, 0.82);
  writeIcon('web/icons/Icon-512.png', 512, image, markCrop, 0.82);
  writeIcon('web/icons/Icon-maskable-192.png', 192, image, markCrop, 0.66);
  writeIcon('web/icons/Icon-maskable-512.png', 512, image, markCrop, 0.66);
  writeIcon('web/favicon.png', 32, image, markCrop, 0.82);

  console.log(`Generated MediShield icons from ${image.width}x${image.height} source artwork.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

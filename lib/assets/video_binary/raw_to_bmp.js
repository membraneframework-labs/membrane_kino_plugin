/**
 * depth: 1 - monochrome
 *        4 - 4-bit grayscale
 *        8 - 8-bit grayscale
 *       16 - 16-bit color
 *       32 - 32-bit color
 **/

const DATA_URL_PREFIX = "data:image/bmp;base64,";

function rawToBMP(buffer, width, height, depth = 32) {
  function convert(size) {
    return String.fromCharCode(size & 0xff, (size >> 8) & 0xff, (size >> 16) & 0xff, (size >> 24) & 0xff);
  }

  let offset = depth <= 8 ? 54 + Math.pow(2, depth) * 4 : 54;

  //BMP Header
  let header = 'BM';                          // ID field
  header += convert(offset + buffer.length);     // BMP size
  header += convert(0);                       // unused
  header += convert(offset);                  // pixel data offset

  //DIB Header
  header += convert(40);                      // DIB header length
  header += convert(width);                   // image width
  header += convert(height);                  // image height
  header += String.fromCharCode(1, 0);        // color panes
  header += String.fromCharCode(depth, 0);    // bits per pixel
  header += convert(0);                       // compression method
  header += convert(buffer.byteLength);              // size of the raw data
  header += convert(2835);                    // horizontal print resolution
  header += convert(2835);                    // vertical print resolution
  header += convert(0);                       // color palette, 0 == 2^n
  header += convert(0);                       // important colors

  //Grayscale tables for bit depths <= 8
  if (depth <= 8) {
    header += convert(0);

    for (let s = Math.floor(255 / (Math.pow(2, depth) - 1)), i = s; i < 256; i += s) {
      header += convert(i + i * 256 + i * 65536);
    }
  }

  return DATA_URL_PREFIX + btoa(header) + bufferToBase64(buffer);
}

function bufferToBase64(buffer) {
  let binaryString = "";
  const bytes = new Uint8Array(buffer);
  const length = bytes.byteLength;

  for (let i = 0; i < length; i++) {
    binaryString += String.fromCharCode(bytes[i]);
  }

  return btoa(binaryString);
}

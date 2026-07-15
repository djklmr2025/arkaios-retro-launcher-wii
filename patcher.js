export { applyBps, crc32 };

const hasDocument = typeof document !== "undefined";
const romInput = hasDocument ? document.getElementById("rom-file") : null;
const patchInput = hasDocument ? document.getElementById("patch-file") : null;
const applyButton = hasDocument ? document.getElementById("apply-bps") : null;
const clearButton = hasDocument ? document.getElementById("clear-patcher") : null;
const statusBox = hasDocument ? document.getElementById("patcher-status") : null;

const crcTable = new Uint32Array(256);
for (let i = 0; i < 256; i += 1) {
  let c = i;
  for (let k = 0; k < 8; k += 1) {
    c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  }
  crcTable[i] = c >>> 0;
}

function setStatus(message, isError = false) {
  if (!statusBox) return;
  statusBox.textContent = message;
  statusBox.style.color = isError ? "#ff9b9b" : "";
}

function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc = crcTable[(crc ^ byte) & 0xff] ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function readVlv(reader) {
  let data = 0;
  let shift = 1;

  while (true) {
    const x = reader.readByte();
    data += (x & 0x7f) * shift;
    if (x & 0x80) {
      break;
    }
    shift <<= 7;
    data += shift;
  }

  return data >>> 0;
}

function decodeSigned(value) {
  const offset = value >>> 1;
  return value & 1 ? -offset : offset;
}

class ByteReader {
  constructor(bytes) {
    this.bytes = bytes;
    this.offset = 0;
  }

  readByte() {
    if (this.offset >= this.bytes.length) {
      throw new Error("Patch BPS incompleto.");
    }
    const value = this.bytes[this.offset];
    this.offset += 1;
    return value;
  }

  readBytes(length) {
    if (this.offset + length > this.bytes.length) {
      throw new Error("Patch BPS incompleto.");
    }
    const value = this.bytes.subarray(this.offset, this.offset + length);
    this.offset += length;
    return value;
  }

  readUint32LE(position) {
    return (
      this.bytes[position] |
      (this.bytes[position + 1] << 8) |
      (this.bytes[position + 2] << 16) |
      (this.bytes[position + 3] << 24)
    ) >>> 0;
  }
}

function applyBps(sourceBytes, patchBytes) {
  const reader = new ByteReader(patchBytes);
  const magic = String.fromCharCode(...reader.readBytes(4));
  if (magic !== "BPS1") {
    throw new Error("El parche no es BPS valido.");
  }

  const sourceSize = readVlv(reader);
  const targetSize = readVlv(reader);
  const metadataSize = readVlv(reader);
  reader.readBytes(metadataSize);

  if (sourceBytes.length !== sourceSize) {
    throw new Error(`La ROM base mide ${sourceBytes.length} bytes, pero el parche espera ${sourceSize}.`);
  }

  const targetBytes = new Uint8Array(targetSize);
  let outputOffset = 0;
  let sourceRelativeOffset = 0;
  let targetRelativeOffset = 0;
  const commandEnd = patchBytes.length - 12;

  while (reader.offset < commandEnd) {
    const data = readVlv(reader);
    const action = data & 3;
    const length = (data >>> 2) + 1;

    if (outputOffset + length > targetBytes.length) {
      throw new Error("El parche intenta escribir fuera del archivo de salida.");
    }

    if (action === 0) {
      targetBytes.set(sourceBytes.subarray(outputOffset, outputOffset + length), outputOffset);
      outputOffset += length;
    } else if (action === 1) {
      targetBytes.set(reader.readBytes(length), outputOffset);
      outputOffset += length;
    } else if (action === 2) {
      sourceRelativeOffset += decodeSigned(readVlv(reader));
      for (let i = 0; i < length; i += 1) {
        if (sourceRelativeOffset < 0 || sourceRelativeOffset >= sourceBytes.length) {
          throw new Error("El parche intenta leer fuera de la ROM base.");
        }
        targetBytes[outputOffset] = sourceBytes[sourceRelativeOffset];
        outputOffset += 1;
        sourceRelativeOffset += 1;
      }
    } else {
      targetRelativeOffset += decodeSigned(readVlv(reader));
      for (let i = 0; i < length; i += 1) {
        if (targetRelativeOffset < 0 || targetRelativeOffset >= outputOffset) {
          throw new Error("El parche intenta leer fuera de la ROM generada.");
        }
        targetBytes[outputOffset] = targetBytes[targetRelativeOffset];
        outputOffset += 1;
        targetRelativeOffset += 1;
      }
    }
  }

  const sourceCrc = reader.readUint32LE(commandEnd);
  const targetCrc = reader.readUint32LE(commandEnd + 4);
  const patchCrc = reader.readUint32LE(commandEnd + 8);
  const patchWithoutCrc = patchBytes.subarray(0, commandEnd + 8);

  if (crc32(sourceBytes) !== sourceCrc) {
    throw new Error("La ROM base no coincide con el CRC esperado por el parche.");
  }
  if (crc32(targetBytes) !== targetCrc) {
    throw new Error("La ROM generada no coincide con el CRC esperado.");
  }
  if (crc32(patchWithoutCrc) !== patchCrc) {
    throw new Error("El archivo BPS no coincide con su CRC interno.");
  }

  return targetBytes;
}

async function readFileBytes(file) {
  return new Uint8Array(await file.arrayBuffer());
}

function downloadBytes(bytes, filename) {
  if (!hasDocument) {
    throw new Error("La descarga solo esta disponible en navegador.");
  }
  const blob = new Blob([bytes], { type: "application/octet-stream" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}

function outputName(romName, patchName) {
  const romBase = romName.replace(/\.[^.]+$/, "");
  const patchBase = patchName.replace(/\.[^.]+$/, "");
  const base = patchBase || `${romBase}-patched`;
  return `${base}.sfc`;
}

applyButton?.addEventListener("click", async () => {
  try {
    const romFile = romInput?.files?.[0];
    const patchFile = patchInput?.files?.[0];
    if (!romFile || !patchFile) {
      setStatus("Selecciona primero la ROM base y el parche BPS.", true);
      return;
    }

    setStatus("Leyendo archivos locales...");
    const [romBytes, patchBytes] = await Promise.all([readFileBytes(romFile), readFileBytes(patchFile)]);
    setStatus("Aplicando parche BPS en tu navegador...");
    const result = applyBps(romBytes, patchBytes);
    const name = outputName(romFile.name, patchFile.name);
    downloadBytes(result, name);
    setStatus(`Listo. Se genero ${name} localmente (${result.length.toLocaleString()} bytes).`);
  } catch (error) {
    setStatus(error.message || "No se pudo aplicar el parche.", true);
  }
});

clearButton?.addEventListener("click", () => {
  if (romInput) romInput.value = "";
  if (patchInput) patchInput.value = "";
  setStatus("Esperando ROM base y parche BPS.");
});

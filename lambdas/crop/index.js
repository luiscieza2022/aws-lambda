import { S3Client, GetObjectCommand, PutObjectCommand } from "@aws-sdk/client-s3";
import sharp from "sharp";

const s3 = new S3Client({});

// Convierte un Stream de S3 a Buffer
const streamToBuffer = async (stream) => {
  const chunks = [];
  for await (const chunk of stream) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
};

export const handler = async (event) => {
  const bucketName = process.env.S3_BUCKET;
  const processedPrefix = process.env.PROCESSED_PREFIX || "processed/";

  for (const record of event.Records) {
    try {
      // SQS parsea la notificación del evento de S3
      const sqsBody = JSON.parse(record.body);
      
      // Manejar tanto mensaje directo de S3 como enrutado por SQS
      const s3Event = sqsBody.Records ? sqsBody.Records[0] : sqsBody;
      if (!s3Event || !s3Event.s3) continue;

      const objectKey = decodeURIComponent(s3Event.s3.object.key.replace(/\+/g, " "));

      // 1. Obtener la imagen original desde S3
      const getObjResponse = await s3.send(
        new GetObjectCommand({ Bucket: bucketName, Key: objectKey })
      );
      const inputBuffer = await streamToBuffer(getObjResponse.Body);

      // 2. Crear una máscara SVG circular de 40x40 px
      const svgCircleMask = Buffer.from(
        `<svg width="40" height="40"><circle cx="20" cy="20" r="20" fill="#fff"/></svg>`
      );

      // 3. Procesar la imagen con Sharp (redimensionar a 40x40 cover + recorte circular PNG)
      const outputBuffer = await sharp(inputBuffer)
        .resize(40, 40, { fit: "cover" })
        .composite([{ input: svgCircleMask, blend: "dest-in" }])
        .png()
        .toBuffer();

      // 4. Nombre del nuevo archivo recortado
      const originalFileName = objectKey.split("/").pop().split(".")[0];
      const newKey = `${processedPrefix}${originalFileName}_circular.png`;

      // 5. Guardar la imagen procesada en S3
      await s3.send(
        new PutObjectCommand({
          Bucket: bucketName,
          Key: newKey,
          Body: outputBuffer,
          ContentType: "image/png",
        })
      );

      console.log(`Imagen recortada guardada exitosamente en: ${newKey}`);
    } catch (err) {
      console.error("Error al procesar el mensaje SQS:", err);
      throw err; // Lanzar error para que SQS reintente o mande al DLQ si falla 3 veces
    }
  }
};
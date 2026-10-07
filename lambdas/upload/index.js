import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { randomUUID } from "crypto";

const s3 = new S3Client({});

export const handler = async (event) => {
  try {
    const bucketName = process.env.S3_BUCKET;
    const uploadPrefix = process.env.UPLOAD_PREFIX || "uploads/";

    if (!event.body) {
      return {
        statusCode: 400,
        body: JSON.stringify({ message: "No se proporcionó contenido en la solicitud." }),
      };
    }

    // Decodificar el cuerpo enviado (soporta base64 o raw)
    const buffer = event.isBase64Encoded
      ? Buffer.from(event.body, "base64")
      : Buffer.from(event.body);

    // Determinar la extensión del archivo a partir del Content-Type
    const contentType = event.headers?.["content-type"] || event.headers?.["Content-Type"] || "image/png";
    let ext = "png";
    if (contentType.includes("jpeg") || contentType.includes("jpg")) ext = "jpg";
    else if (contentType.includes("gif")) ext = "gif";
    else if (contentType.includes("webp")) ext = "webp";

    const fileName = `${uploadPrefix}${randomUUID()}.${ext}`;

    await s3.send(
      new PutObjectCommand({
        Bucket: bucketName,
        Key: fileName,
        Body: buffer,
        ContentType: contentType,
      })
    );

    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        message: "Imagen subida exitosamente.",
        fileKey: fileName,
      }),
    };
  } catch (error) {
    console.error("Error al subir la imagen:", error);
    return {
      statusCode: 500,
      body: JSON.stringify({ message: "Error interno al procesar la imagen.", error: error.message }),
    };
  }
};
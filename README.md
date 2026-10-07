\# Procesador de Imágenes Serverless en AWS (DEV / QA / PROD)



Este proyecto implementa un pipeline de procesamiento de imágenes serverless desplegado con Terraform en AWS.



\## Arquitectura



\- \*\*API Gateway HTTP API:\*\* Endpoint de entrada `POST /upload`.

\- \*\*AWS Lambda (`upload-lambda`):\*\* Recibe la imagen y la guarda en S3 (`uploads/`).

\- \*\*Amazon S3 \& SQS:\*\* La subida dispara un evento a la cola SQS con soporte de DLQ.

\- \*\*AWS Lambda (`crop-lambda`):\*\* Procesa el mensaje de SQS, recorta la imagen a un círculo transparente de 40x40px (Sharp) y la almacena en S3 (`processed/`).

\- \*\*VPC \& Security:\*\* Lambdas aisladas en subredes privadas comunicándose vía VPC Endpoints.



\## Despliegue de Entornos



Para desplegar cualquier entorno (`dev`, `qa`, `prod`):



```bash

cd terraform/environments/<entorno>

terraform init

terraform apply -auto-approve


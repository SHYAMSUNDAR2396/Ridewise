import { buildApp } from "./app";

// buildApp() calls loadConfig() synchronously, which throws (via Zod) if
// PROVIDER_MODE=production is missing any required credential -- so a
// misconfigured production server never reaches app.listen() below.
const app = buildApp();

const port = Number(process.env.PORT ?? 3000);

app
  .listen({ port, host: "0.0.0.0" })
  .then(() => {
    app.log.info(`Ridewise API listening on port ${port}`);
  })
  .catch((error) => {
    app.log.error(error);
    process.exit(1);
  });

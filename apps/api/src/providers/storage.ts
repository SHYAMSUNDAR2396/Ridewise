import { GetObjectCommand, PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

export interface Storage {
  /** Stores `bytes` at `key` and returns a URL the client can use to fetch it. */
  put(key: string, bytes: Uint8Array): Promise<string>;
}

/** In-memory storage for tests and PROVIDER_MODE=development. Never touches the network. */
export class InMemoryStorage implements Storage {
  private readonly objects = new Map<string, Uint8Array>();

  async put(key: string, bytes: Uint8Array): Promise<string> {
    this.objects.set(key, bytes);
    return `memory://${key}`;
  }

  get(key: string): Uint8Array | undefined {
    return this.objects.get(key);
  }
}

export interface S3StorageConfig {
  endpoint: string;
  bucket: string;
  accessKeyId: string;
  secretAccessKey: string;
}

/** S3-compatible storage used only in PROVIDER_MODE=production. */
const SIGNED_URL_EXPIRY_SECONDS = 3600;

export class S3Storage implements Storage {
  private readonly client: S3Client;
  private readonly bucket: string;

  constructor(config: S3StorageConfig) {
    this.bucket = config.bucket;
    this.client = new S3Client({
      endpoint: config.endpoint,
      region: "auto",
      credentials: {
        accessKeyId: config.accessKeyId,
        secretAccessKey: config.secretAccessKey,
      },
    });
  }

  async put(key: string, bytes: Uint8Array): Promise<string> {
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: bytes,
        ContentType: "audio/mpeg",
      }),
    );
    return getSignedUrl(this.client, new GetObjectCommand({ Bucket: this.bucket, Key: key }), {
      expiresIn: SIGNED_URL_EXPIRY_SECONDS,
    });
  }
}

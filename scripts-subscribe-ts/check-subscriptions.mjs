import { createPublicClient, http, defineChain, getAddress } from "viem";
import { SDK } from "@somnia-chain/reactivity";
import * as dotenv from "dotenv";

dotenv.config();

const somniaTestnet = defineChain({
  id: 50312,
  name: "Somnia Testnet",
  nativeCurrency: { name: "STT", symbol: "STT", decimals: 18 },
  rpcUrls: {
    default: { http: ["https://dream-rpc.somnia.network"] },
  },
  blockExplorers: {
    default: { name: "Shannon Explorer", url: "https://shannon-explorer.somnia.network" },
  },
});

function normalizeAddress(address) {
  if (!address) return undefined;
  try {
    return getAddress(address);
  } catch {
    return undefined;
  }
}

function parseIds(value) {
  if (!value || String(value).trim() === "") return [];
  return String(value)
    .split(/[,\s]+/)
    .map((entry) => entry.trim())
    .filter(Boolean)
    .map((entry) => {
      try {
        return BigInt(entry);
      } catch {
        throw new Error(`Invalid subscription id: ${entry}`);
      }
    });
}

function toStringValue(value) {
  return typeof value === "string" ? value : String(value ?? "");
}

function toSubscriptionInfoShape(value) {
  if (Array.isArray(value) && value.length >= 2) {
    return {
      subscriptionData: value[0],
      owner: value[1],
    };
  }
  if (value && typeof value === "object" && "subscriptionData" in value && "owner" in value) {
    return value;
  }
  return undefined;
}

async function main() {
  const subscriptionIds = parseIds(process.env.SUBSCRIPTION_IDS);
  if (subscriptionIds.length === 0) {
    throw new Error("SUBSCRIPTION_IDS is required. Example: SUBSCRIPTION_IDS=12,13");
  }

  const expectedOwner = normalizeAddress(process.env.OWNER_ADDRESS);
  const expectedHandler = normalizeAddress(process.env.HANDLER_ADDRESS);
  const expectedProfile = normalizeAddress(process.env.PROFILE_ADDRESS);
  const expectedTreasury = normalizeAddress(process.env.TREASURY_ADDRESS);

  const publicClient = createPublicClient({
    chain: somniaTestnet,
    transport: http(),
  });

  const sdk = new SDK({
    public: publicClient,
  });

  console.log("--- CHECK SUBSCRIPTION INFO ---");
  console.log(`IDs: ${subscriptionIds.map((id) => id.toString()).join(", ")}`);

  for (const id of subscriptionIds) {
    const result = await sdk.getSubscriptionInfo(id);
    if (result instanceof Error) {
      console.log(`#${id.toString()} -> NOT FOUND / ERROR: ${result.message}`);
      continue;
    }

    const info = toSubscriptionInfoShape(result);
    if (!info) {
      console.log(`#${id.toString()} -> UNKNOWN RESPONSE SHAPE`);
      continue;
    }

    const owner = normalizeAddress(toStringValue(info.owner)) ?? toStringValue(info.owner);
    const emitter =
      normalizeAddress(toStringValue(info.subscriptionData?.emitter)) ??
      toStringValue(info.subscriptionData?.emitter);
    const handler =
      normalizeAddress(toStringValue(info.subscriptionData?.handlerContractAddress)) ??
      toStringValue(info.subscriptionData?.handlerContractAddress);
    const topics = info.subscriptionData?.eventTopics ?? [];

    const ownerOk = expectedOwner ? owner === expectedOwner : true;
    const handlerOk = expectedHandler ? handler === expectedHandler : true;
    const emitterOk = expectedProfile || expectedTreasury
      ? emitter === expectedProfile || emitter === expectedTreasury
      : true;
    const marker = ownerOk && handlerOk && emitterOk ? "MATCH" : "OTHER";

    console.log(`#${id.toString()} [${marker}]`);
    console.log(`  owner   : ${owner}`);
    console.log(`  emitter : ${emitter}`);
    console.log(`  handler : ${handler}`);
    console.log(`  topics0 : ${topics[0] ?? "0x"}`);
  }
}

main().catch((error) => {
  console.error("FAILED to check subscriptions:", error);
  process.exit(1);
});

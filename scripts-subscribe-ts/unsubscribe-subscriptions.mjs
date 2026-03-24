import { createPublicClient, createWalletClient, http, defineChain, getAddress } from "viem";
import { privateKeyToAccount } from "viem/accounts";
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

function parseBoolean(value, defaultValue = false) {
  if (value === undefined || value === null || String(value).trim() === "") return defaultValue;
  const normalized = String(value).trim().toLowerCase();
  return normalized === "1" || normalized === "true" || normalized === "yes";
}

function normalizeAddress(address) {
  if (!address) return undefined;
  try {
    return getAddress(address);
  } catch {
    return undefined;
  }
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

function assertEnv(name, value) {
  if (!value || String(value).trim() === "") {
    throw new Error(`Missing environment variable: ${name}`);
  }
}

async function main() {
  const privateKey = process.env.PRIVATE_KEY;
  const subscriptionIds = parseIds(process.env.SUBSCRIPTION_IDS);
  const dryRun = parseBoolean(process.env.DRY_RUN, false);
  const skipOwnerCheck = parseBoolean(process.env.SKIP_OWNER_CHECK, false);

  assertEnv("PRIVATE_KEY", privateKey);
  if (subscriptionIds.length === 0) {
    throw new Error("SUBSCRIPTION_IDS is required. Example: SUBSCRIPTION_IDS=12,13");
  }

  const account = privateKeyToAccount(privateKey);
  const sender = normalizeAddress(account.address);

  const publicClient = createPublicClient({
    chain: somniaTestnet,
    transport: http(),
  });

  const walletClient = createWalletClient({
    account,
    chain: somniaTestnet,
    transport: http(),
  });

  const sdk = new SDK({
    public: publicClient,
    wallet: walletClient,
  });

  console.log("--- UNSUBSCRIBE SUBSCRIPTIONS ---");
  console.log(`Sender: ${account.address}`);
  console.log(`IDs   : ${subscriptionIds.map((id) => id.toString()).join(", ")}`);
  console.log(`DryRun: ${dryRun}`);

  for (const id of subscriptionIds) {
    if (!skipOwnerCheck) {
      const info = await sdk.getSubscriptionInfo(id);
      if (info instanceof Error) {
        console.log(`#${id.toString()} -> SKIP (not found / ${info.message})`);
        continue;
      }

      const parsedInfo = toSubscriptionInfoShape(info);
      if (!parsedInfo) {
        console.log(`#${id.toString()} -> SKIP (unknown response shape)`);
        continue;
      }

      const owner = normalizeAddress(toStringValue(parsedInfo.owner));
      if (!owner || !sender || owner !== sender) {
        console.log(`#${id.toString()} -> SKIP (owner ${owner ?? "unknown"} != sender ${sender ?? "unknown"})`);
        continue;
      }
    }

    if (dryRun) {
      console.log(`#${id.toString()} -> DRY_RUN (no tx sent)`);
      continue;
    }

    const tx = await sdk.cancelSoliditySubscription(id);
    if (tx instanceof Error) {
      console.log(`#${id.toString()} -> FAILED (${tx.message})`);
      continue;
    }

    console.log(`#${id.toString()} -> TX ${tx}`);
  }
}

main().catch((error) => {
  console.error("FAILED to unsubscribe subscriptions:", error);
  process.exit(1);
});

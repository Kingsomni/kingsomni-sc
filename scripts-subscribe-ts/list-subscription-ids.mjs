import { createPublicClient, http, defineChain, getAddress, keccak256, toBytes } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import * as dotenv from "dotenv";

dotenv.config();

const PRECOMPILE_ADDRESS = "0x0000000000000000000000000000000000000100";

const TOPIC_SUB_CREATED_WITH_DATA = keccak256(
  toBytes(
    "SubscriptionCreated(uint256,address,(bytes32[4],address,address,address,address,bytes4,uint64,uint64,uint64,bool,bool))"
  )
);
const TOPIC_SUB_CREATED_NO_DATA = keccak256(toBytes("SubscriptionCreated(uint64,address)"));
const TOPIC_SUB_REMOVED = keccak256(toBytes("SubscriptionRemoved(uint256,address)"));

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

function topicToAddress(topic) {
  if (!topic || typeof topic !== "string" || topic.length < 66) return undefined;
  return normalizeAddress(`0x${topic.slice(-40)}`);
}

function topicToBigInt(topic) {
  if (!topic || typeof topic !== "string") return undefined;
  try {
    return BigInt(topic);
  } catch {
    return undefined;
  }
}

function parseBlockSpan() {
  const raw = process.env.LOG_BLOCK_SPAN ?? "900";
  let span;
  try {
    span = BigInt(raw);
  } catch {
    throw new Error(`Invalid LOG_BLOCK_SPAN: ${raw}`);
  }
  if (span <= 0n || span > 1000n) {
    throw new Error("LOG_BLOCK_SPAN must be between 1 and 1000");
  }
  return span;
}

async function resolveFromBlock(publicClient) {
  const raw = process.env.SUBSCRIPTION_FROM_BLOCK;
  if (raw && raw.trim() !== "") {
    try {
      return BigInt(raw);
    } catch {
      throw new Error(`Invalid SUBSCRIPTION_FROM_BLOCK: ${raw}`);
    }
  }

  const latest = await publicClient.getBlockNumber();
  const fallback = latest > 120000n ? latest - 120000n : 0n;
  return fallback;
}

async function getLogsPaged({ publicClient, topic0, fromBlock, toBlock = "latest", blockSpan }) {
  const latestBlock = toBlock === "latest" ? await publicClient.getBlockNumber() : BigInt(toBlock);
  if (fromBlock > latestBlock) return [];

  const logs = [];
  let skippedRanges = 0;

  for (let start = fromBlock; start <= latestBlock; start += blockSpan) {
    const end = start + blockSpan - 1n;
    const boundedEnd = end > latestBlock ? latestBlock : end;

    try {
      const part = await publicClient.getLogs({
        address: PRECOMPILE_ADDRESS,
        fromBlock: start,
        toBlock: boundedEnd,
        topics: [topic0],
      });
      logs.push(...part);
    } catch (error) {
      const msg = String(error?.details ?? error?.shortMessage ?? error?.message ?? error ?? "");
      if (msg.toLowerCase().includes("missing block data")) {
        skippedRanges += 1;
        continue;
      }
      throw error;
    }
  }

  return { logs, skippedRanges, latestBlock };
}

async function main() {
  const ownerFromEnv = normalizeAddress(process.env.OWNER_ADDRESS);
  const privateKey = process.env.PRIVATE_KEY;
  const ownerFromPk = privateKey ? privateKeyToAccount(privateKey).address : undefined;
  const ownerAddress = ownerFromEnv ?? ownerFromPk;
  const blockSpan = parseBlockSpan();

  const publicClient = createPublicClient({
    chain: somniaTestnet,
    transport: http(),
  });

  const fromBlock = await resolveFromBlock(publicClient);

  const createdResult = await getLogsPaged({
    publicClient,
    topic0: TOPIC_SUB_CREATED_WITH_DATA,
    fromBlock,
    blockSpan,
  });
  const createdCompatResult = await getLogsPaged({
    publicClient,
    topic0: TOPIC_SUB_CREATED_NO_DATA,
    fromBlock,
    blockSpan,
  });
  const removedResult = await getLogsPaged({
    publicClient,
    topic0: TOPIC_SUB_REMOVED,
    fromBlock,
    blockSpan,
  });

  const createdIds = [];
  const allCreatedLogs = [...createdResult.logs, ...createdCompatResult.logs];
  for (const log of allCreatedLogs) {
    const owner = topicToAddress(log.topics?.[2]) ?? topicToAddress(log.topics?.[1]);
    if (ownerAddress && owner !== ownerAddress) continue;
    const id = topicToBigInt(log.topics?.[1]);
    if (id === undefined) continue;
    createdIds.push(id);
  }

  const removedIds = new Set();
  for (const log of removedResult.logs) {
    const owner = topicToAddress(log.topics?.[2]);
    if (ownerAddress && owner !== ownerAddress) continue;
    const id = topicToBigInt(log.topics?.[1]);
    if (id === undefined) continue;
    removedIds.add(id.toString());
  }

  const activeIds = [...new Set(createdIds.map((id) => id.toString()))]
    .filter((id) => !removedIds.has(id))
    .map((id) => BigInt(id))
    .sort((a, b) => (a === b ? 0 : a < b ? -1 : 1));

  console.log("--- LIST SUBSCRIPTION IDS ---");
  console.log(`Precompile : ${PRECOMPILE_ADDRESS}`);
  console.log(`Owner      : ${ownerAddress ?? "(none, show all owners)"}`);
  console.log(`From block : ${fromBlock.toString()}`);
  console.log(`To block   : ${createdResult.latestBlock.toString()}`);
  if (createdResult.skippedRanges + createdCompatResult.skippedRanges + removedResult.skippedRanges > 0) {
    console.log(
      `[warn] skipped ${createdResult.skippedRanges + createdCompatResult.skippedRanges + removedResult.skippedRanges} range(s) due to 'missing block data'`
    );
  }

  if (activeIds.length === 0) {
    console.log("No active subscription IDs found.");
    return;
  }

  console.log(`Active IDs (${activeIds.length}): ${activeIds.map((id) => id.toString()).join(", ")}`);
  console.log(`Use this in .env -> SUBSCRIPTION_IDS=${activeIds.map((id) => id.toString()).join(",")}`);
}

main().catch((error) => {
  console.error("FAILED to list subscription IDs:", error);
  process.exit(1);
});

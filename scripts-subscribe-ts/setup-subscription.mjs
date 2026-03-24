import { createPublicClient, createWalletClient, http, defineChain, parseGwei, keccak256, toBytes } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { SDK } from "@somnia-chain/reactivity";
import * as dotenv from "dotenv";

dotenv.config();

const PRECOMPILE_ADDRESS = "0x0000000000000000000000000000000000000100";
const TOPIC_SUB_CREATED_WITH_DATA = keccak256(
  toBytes(
    "SubscriptionCreated(uint256,address,(bytes32[4],address,address,address,address,bytes4,uint64,uint64,uint64,bool,bool))"
  )
);
const TOPIC_SUB_CREATED_NO_DATA = keccak256(toBytes("SubscriptionCreated(uint64,address)"));

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

function assertEnv(name, value) {
  if (!value || String(value).trim() === "") {
    throw new Error(`Missing environment variable: ${name}`);
  }
}

function topicToBigInt(topic) {
  if (!topic || typeof topic !== "string") return undefined;
  try {
    return BigInt(topic);
  } catch {
    return undefined;
  }
}

function extractSubscriptionIdsFromReceipt(receipt, ownerAddress) {
  const ids = [];

  for (const log of receipt.logs ?? []) {
    const logAddress = String(log.address ?? "").toLowerCase();
    const topic0 = String(log.topics?.[0] ?? "").toLowerCase();
    const topic2 = String(log.topics?.[2] ?? "").toLowerCase();

    if (logAddress !== PRECOMPILE_ADDRESS.toLowerCase()) continue;
    const matchesCreatedEvent =
      topic0 === TOPIC_SUB_CREATED_WITH_DATA.toLowerCase() ||
      topic0 === TOPIC_SUB_CREATED_NO_DATA.toLowerCase();
    if (!matchesCreatedEvent) continue;

    // topic[2] for 3-param event, topic[1] for 2-param event
    const ownerTopic = topic2 || String(log.topics?.[1] ?? "").toLowerCase();
    if (ownerAddress && ownerTopic && !ownerTopic.endsWith(ownerAddress.toLowerCase().slice(2))) continue;

    const subId = topicToBigInt(log.topics?.[1]);
    if (subId !== undefined) {
      ids.push(subId);
    }
  }

  return ids;
}

async function main() {
  const privateKey = process.env.PRIVATE_KEY;
  const handlerAddress = process.env.HANDLER_ADDRESS;
  const profileAddress = process.env.PROFILE_ADDRESS;
  const treasuryAddress = process.env.TREASURY_ADDRESS;
  const priorityFeeGwei = process.env.PRIORITY_FEE_GWEI ?? "0";
  const maxFeeGwei = process.env.MAX_FEE_GWEI ?? "10";
  const gasLimitRaw = process.env.SUBSCRIPTION_GAS_LIMIT ?? "3000000";

  assertEnv("PRIVATE_KEY", privateKey);
  assertEnv("HANDLER_ADDRESS", handlerAddress);
  assertEnv("PROFILE_ADDRESS", profileAddress);
  assertEnv("TREASURY_ADDRESS", treasuryAddress);

  let gasLimit;
  try {
    gasLimit = BigInt(gasLimitRaw);
  } catch {
    throw new Error(`Invalid SUBSCRIPTION_GAS_LIMIT: ${gasLimitRaw}`);
  }
  if (gasLimit <= 0n) {
    throw new Error("SUBSCRIPTION_GAS_LIMIT must be greater than 0");
  }

  const account = privateKeyToAccount(privateKey);
  console.log(`Using account: ${account.address}`);

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

  console.log("--- KINGSOMNI REACTIVITY DUAL-SETUP ---");
  console.log(`Gas config -> priorityFee: ${priorityFeeGwei} gwei, maxFee: ${maxFeeGwei} gwei, gasLimit: ${gasLimit.toString()}`);

  console.log(`Subscribing to Profile: ${profileAddress}...`);
  const profileTxHash = await sdk.createSoliditySubscription({
    emitter: profileAddress,
    handlerContractAddress: handlerAddress,
    priorityFeePerGas: parseGwei(priorityFeeGwei),
    maxFeePerGas: parseGwei(maxFeeGwei),
    gasLimit,
    isGuaranteed: true,
    isCoalesced: false,
  });
  if (profileTxHash instanceof Error) {
    throw new Error(`Profile subscription failed: ${profileTxHash.message}`);
  }
  console.log(`Profile subscription tx: ${profileTxHash}`);
  const profileReceipt = await publicClient.waitForTransactionReceipt({ hash: profileTxHash });
  const profileSubIds = extractSubscriptionIdsFromReceipt(profileReceipt, account.address);
  if (profileSubIds.length > 0) {
    console.log(`Profile subscription ID(s): ${profileSubIds.map((id) => id.toString()).join(", ")}`);
  } else {
    console.log("Profile subscription ID: not found in receipt logs.");
  }
  console.log("Profile Subscription Created.");

  console.log(`Subscribing to Treasury: ${treasuryAddress}...`);
  const treasuryTxHash = await sdk.createSoliditySubscription({
    emitter: treasuryAddress,
    handlerContractAddress: handlerAddress,
    priorityFeePerGas: parseGwei(priorityFeeGwei),
    maxFeePerGas: parseGwei(maxFeeGwei),
    gasLimit,
    isGuaranteed: true,
    isCoalesced: false,
  });
  if (treasuryTxHash instanceof Error) {
    throw new Error(`Treasury subscription failed: ${treasuryTxHash.message}`);
  }
  console.log(`Treasury subscription tx: ${treasuryTxHash}`);
  const treasuryReceipt = await publicClient.waitForTransactionReceipt({ hash: treasuryTxHash });
  const treasurySubIds = extractSubscriptionIdsFromReceipt(treasuryReceipt, account.address);
  if (treasurySubIds.length > 0) {
    console.log(`Treasury subscription ID(s): ${treasurySubIds.map((id) => id.toString()).join(", ")}`);
  } else {
    console.log("Treasury subscription ID: not found in receipt logs.");
  }
  console.log("Treasury Subscription Created.");

  console.log("SUCCESS: Kingsomni reactivity subscriptions are configured.");
}

main().catch((error) => {
  console.error("FAILED to create subscriptions:", error);
  process.exit(1);
});

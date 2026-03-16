import { createPublicClient, createWalletClient, http, defineChain, parseGwei } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { SDK } from '@somnia-chain/reactivity';
import * as dotenv from 'dotenv';

// Load .env
dotenv.config();

/**
 * SOMNIA TESTNET (SHANNON) CONFIGURATION
 */
const somniaTestnet = defineChain({
  id: 50312,
  name: 'Somnia Testnet',
  nativeCurrency: { name: 'STT', symbol: 'STT', decimals: 18 },
  rpcUrls: {
    default: { http: ['https://dream-rpc.somnia.network'] },
  },
  blockExplorers: {
    default: { name: 'Shannon Explorer', url: 'https://shannon-explorer.somnia.network' },
  },
});

async function main() {
  const privateKey = process.env.PRIVATE_KEY as `0x${string}`;
  const handlerAddress = process.env.HANDLER_ADDRESS as `0x${string}`;
  
  // ALAMAT EMITTER (KONTRAK YANG DIINTAI)
  const profileAddress = process.env.PROFILE_ADDRESS as `0x${string}`;
  const treasuryAddress = process.env.TREASURY_ADDRESS as `0x${string}`;

  if (!privateKey || !handlerAddress || !profileAddress || !treasuryAddress) {
    console.error("❌ ERROR: Missing environment variables in .env");
    console.log("Required: PRIVATE_KEY, HANDLER_ADDRESS, PROFILE_ADDRESS, TREASURY_ADDRESS");
    process.exit(1);
  }

  const account = privateKeyToAccount(privateKey);
  console.log(`🚀 Using account: ${account.address}`);

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

  try {
    /**
     * SUBSCRIPTION 1: KINGSOMNI PROFILE
     * Mentarget event StatUpgraded untuk fitur Bounty Pool
     */
    console.log(`⏳ Subscribing to Profile: ${profileAddress}...`);
    const profileSub = await sdk.createSoliditySubscription({
      emitterContractAddress: profileAddress, // FILTER: Hanya dari Profile
      handlerContractAddress: handlerAddress,
      priorityFeePerGas: parseGwei('2'),
      maxFeePerGas: parseGwei('10'),
      gasLimit: 3_000_000n,
      isGuaranteed: true,
      isCoalesced: false,
    });
    console.log("✅ Profile Subscription Created!");

    /**
     * SUBSCRIPTION 2: KINGSOMNI TREASURY
     * Mentarget event Deposited untuk fitur Global Boss
     */
    console.log(`⏳ Subscribing to Treasury: ${treasuryAddress}...`);
    const treasurySub = await sdk.createSoliditySubscription({
      emitterContractAddress: treasuryAddress, // FILTER: Hanya dari Treasury
      handlerContractAddress: handlerAddress,
      priorityFeePerGas: parseGwei('2'),
      maxFeePerGas: parseGwei('10'),
      gasLimit: 3_000_000n,
      isGuaranteed: true,
      isCoalesced: false,
    });
    console.log("✅ Treasury Subscription Created!");

    console.log("\n🚀 SUCCESS: Kingsomni is now FULLY AUTONOMOUS on Somnia Chain!");
    console.log("The world will now react to every Upgrade and Treasury movement.");

  } catch (error) {
    console.error("❌ FAILED to create subscriptions:", error);
    process.exit(1);
  }
}

main();

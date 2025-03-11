import { getBytes, solidityPackedKeccak256, toUtf8Bytes, Wallet } from 'ethers';
import * as dotenv from 'dotenv';

dotenv.config();

async function generateSignature(
    name: string,
    symbol: string,
    nonce: number,
    factory: string,
    chainId: number,
    msgSender: string,
    privateKey: string
) {
    // 1. Create the packed message hash (matching Solidity keccak256)
    const messageHash = solidityPackedKeccak256(
        ["string", "string", "uint256", "address", "uint256", "address"],
        [name, symbol, nonce, factory, chainId, msgSender]
    );
    console.log("Message Hash:", messageHash);

    // 2. Convert the hash to bytes
    const messageHashBytes = getBytes(messageHash);

    // 3. Create the Ethereum signed message prefix
    const prefix = toUtf8Bytes("\x19Ethereum Signed Message:\n32");
    
    // 4. Concatenate prefix and message hash
    const prefixedMessage = new Uint8Array(prefix.length + messageHashBytes.length);
    prefixedMessage.set(prefix);
    prefixedMessage.set(messageHashBytes, prefix.length);

    // 5. Create the final hash that matches toEthSignedMessageHash
    const finalHash = solidityPackedKeccak256(["bytes"], [prefixedMessage]);
    console.log("Final Hash (matching toEthSignedMessageHash):", finalHash);

    // 6. Sign the message
    const signer = new Wallet(privateKey);
    const signature = await signer.signMessage(messageHashBytes);
    console.log("Signature:", signature);

    return {
        messageHash,
        finalHash,
        signature
    };
}

// Execute the function
generateSignature(
    "My", // name
    "M", // symbol
    1, // nonce
    "0x6711893cd7b41552D74CeBbEc8e93773a5E9Ac66", // factory address
    80002, // chainId (base: 8453, polygon: 137, amoy: 80002)
    "0xc6d37C379816c96344b0e9523AC440523052675F",//"0x993461BBf7e553eb5BD1F5248A72B524C4a3B15D", // msg.sender (0x3B118745852D2E54D82Eb38c581136529E42549f)
    process.env.PRIVATE_KEY!
).then(result => {
    console.log("\nAll results:");
    console.log(result);
}).catch(error => {
    console.error("Error:", error);
});
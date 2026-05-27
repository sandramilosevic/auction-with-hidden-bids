async function main() {
    const stvarnaPonudauEth = "1"; 
    const mojaTajnaRec = "tajna1"; 
    const adresaNovcanika = "0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2"; 

    const value = ethers.utils.parseEther(stvarnaPonudauEth); 

    // ISPRAVAN PADDING ZDESNA (Solidity format)
    const hexString = ethers.utils.hexlify(ethers.utils.toUtf8Bytes(mojaTajnaRec));
    const secret = hexString.padEnd(66, "0"); 

    // Enkodovanje (abi.encode)
    const encodedData = ethers.utils.defaultAbiCoder.encode(
        ["uint256", "bytes32", "address"],
        [value, secret, adresaNovcanika]
    );

    const hash = ethers.utils.keccak256(encodedData);

    console.log("ZA FUNKCIJU bid():");
    console.log("bidHash:");
    console.log(hash);
    console.log("ZA FUNKCIJU reveal():");
    console.log("values:");
    console.log(`[${value.toString()}]`);
    console.log("secrets:");
    console.log(`["${secret}"]`);
}

main()

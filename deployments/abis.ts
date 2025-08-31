// Credora Protocol - Contract ABIs and Types
// Generated automatically from compiled contracts

import { AbiItem } from 'web3-utils';

export const CREDORA_SHARES_ABI: AbiItem[] = 
EOF && cat deployments/abi/CredoraShares.abi.json >> deployments/abis.ts && cat >> deployments/abis.ts << 'EOF'
 as AbiItem[];

export const POOL_ABI: AbiItem[] = 
EOF && cat deployments/abi/Pool.abi.json >> deployments/abis.ts && cat >> deployments/abis.ts << 'EOF'
 as AbiItem[];

export const CRD_VAULT_ABI: AbiItem[] = 
EOF && cat deployments/abi/CRDVault.abi.json >> deployments/abis.ts && cat >> deployments/abis.ts << 'EOF'
 as AbiItem[];

export const CREDIT_NOTE_721_ABI: AbiItem[] = 
EOF && cat deployments/abi/CreditNote721.abi.json >> deployments/abis.ts && cat >> deployments/abis.ts << 'EOF'
 as AbiItem[];

export const NOTE_ISSUER_ABI: AbiItem[] = 
EOF && cat deployments/abi/NoteIssuer.abi.json >> deployments/abis.ts && cat >> deployments/abis.ts << 'EOF'
 as AbiItem[];

export const GROTH16_VERIFIER_ABI: AbiItem[] = 
EOF && cat deployments/abi/Groth16Verifier.abi.json >> deployments/abis.ts && cat >> deployments/abis.ts << 'EOF'
 as AbiItem[];

export const GROTH16_VERIFIER_WRAPPER_ABI: AbiItem[] = 
EOF && cat deployments/abi/Groth16VerifierWrapper.abi.json >> deployments/abis.ts && cat >> deployments/abis.ts << 'EOF'
 as AbiItem[];

export const CREDORA_CONTRACTS = {
  CredoraShares: {
    address: '0x8763fe9e859CeFbaCfD567a9fb45E11D60862Fdc',
    abi: CREDORA_SHARES_ABI
  },
  Pool: {
    address: '0x18d4E173d80a967AE74C4696abf2f5CCf5175FD1',
    abi: POOL_ABI
  },
  CRDVault: {
    address: '0x0aE0c4Da6597aA4500CC2d9378f2c5b404DD352A',
    abi: CRD_VAULT_ABI
  },
  CreditNote721: {
    address: '0xd4473179E0FD3e6F7dF92dae2DECD73cE99D45CA',
    abi: CREDIT_NOTE_721_ABI
  },
  NoteIssuer: {
    address: '0x1E4E86fd9F416DF90Ac9A3FC09ADeB1dBC630e87',
    abi: NOTE_ISSUER_ABI
  },
  Groth16Verifier: {
    address: '0xf6D1f05A947ef8be93fA6b6696aC6a0105CE092c',
    abi: GROTH16_VERIFIER_ABI
  },
  Groth16VerifierWrapper: {
    address: '0x8B45ecf6A42611A967319e3541fE13c3D6f3DB90',
    abi: GROTH16_VERIFIER_WRAPPER_ABI
  }
} as const;

export type ContractName = keyof typeof CREDORA_CONTRACTS;

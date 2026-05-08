import fs from "node:fs";
import path from "node:path";
import solc from "solc";

const rootDir = process.cwd();
const contractsDir = path.join(rootDir, "contracts", "aiusd");
const artifactDir = path.join(rootDir, "artifacts", "contracts", "aiusd");

function loadFile(filePath) {
  return fs.readFileSync(filePath, "utf8");
}

function loadSources(directory) {
  const sources = {};

  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const absolutePath = path.join(directory, entry.name);

    if (entry.isDirectory()) {
      Object.assign(sources, loadSources(absolutePath));
      continue;
    }

    if (entry.isFile() && entry.name.endsWith(".sol")) {
      const relativePath = path.relative(rootDir, absolutePath).replaceAll(path.sep, "/");
      sources[relativePath] = { content: loadFile(absolutePath) };
    }
  }

  return sources;
}

function resolveImport(importPath) {
  const candidates = [
    path.join(rootDir, importPath),
    path.join(rootDir, "node_modules", importPath),
  ];

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return { contents: loadFile(candidate) };
    }
  }

  return { error: `File not found: ${importPath}` };
}

const input = {
  language: "Solidity",
  sources: loadSources(contractsDir),
  settings: {
    evmVersion: "osaka",
    optimizer: {
      enabled: true,
      runs: 200,
    },
    outputSelection: {
      "*": {
        "*": ["abi", "evm.bytecode.object", "evm.deployedBytecode.object", "metadata"],
      },
    },
  },
};

const output = JSON.parse(solc.compile(JSON.stringify(input), { import: resolveImport }));
const compilerErrors = [];

for (const issue of output.errors || []) {
  const line = issue.formattedMessage || issue.message;
  if (issue.severity === "error") {
    compilerErrors.push(line);
  } else {
    console.warn(line);
  }
}

if (compilerErrors.length > 0) {
  console.error(compilerErrors.join("\n"));
  process.exit(1);
}

fs.rmSync(artifactDir, { recursive: true, force: true });
fs.mkdirSync(artifactDir, { recursive: true });

for (const [sourceName, contracts] of Object.entries(output.contracts || {})) {
  if (!sourceName.startsWith("contracts/aiusd/")) {
    continue;
  }

  for (const [contractName, contractOutput] of Object.entries(contracts)) {
    const artifactPath = path.join(artifactDir, `${contractName}.json`);
    const artifact = {
      contractName,
      sourceName,
      abi: contractOutput.abi,
      bytecode: `0x${contractOutput.evm.bytecode.object}`,
      deployedBytecode: `0x${contractOutput.evm.deployedBytecode.object}`,
      metadata: JSON.parse(contractOutput.metadata),
    };

    fs.writeFileSync(artifactPath, JSON.stringify(artifact, null, 2));
    console.log(`Wrote ${path.relative(rootDir, artifactPath)}`);
  }
}

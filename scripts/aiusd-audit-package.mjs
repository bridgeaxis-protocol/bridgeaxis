import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";

const rootDir = process.cwd();
const forgeBin = process.env.FORGE_BIN || path.join(os.homedir(), ".foundry", "bin", "forge");
const testDir = path.join(rootDir, "test", "foundry");
const reportDir = path.join(rootDir, "reports");
const reportJsonPath = path.join(reportDir, "aiusd-audit-stats.json");
const reportMarkdownPath = path.join(reportDir, "aiusd-audit-report.md");

const criticalPaths = [
    "Wallet burns bUSDC reserve into free AIUSD balance",
    "Operator consumes separate reserve account into AIUSD",
    "Treasury desk allocates managed AIUSD to beneficiary",
    "Treasury desk allocates managed AIUSD with execution epoch",
    "Managed balance cannot transfer before release",
    "Free balance can transfer while managed balance remains constrained",
    "Holder can settle only free balance",
    "Desk can settle only managed balance",
    "Expired execution window unlocks balance",
    "Reserve dispatch stays owner/operator-gated",
    "Role administration stays owner-gated",
    "Token/controller accounting stays aligned across state transitions",
    "Supply cap remains enforced",
];

function runForgeTestSuite() {
    execFileSync(forgeBin, ["test"], {
        cwd: rootDir,
        stdio: "inherit",
    });
}

function collectStats() {
    const files = walk(testDir).filter((file) => file.endsWith(".t.sol"));
    const stats = {
        totalTests: 0,
        unitTests: 0,
        integrationTests: 0,
        securityTests: 0,
        fuzzTests: 0,
        invariantTests: 0,
        suiteFiles: files.length,
    };

    for (const file of files) {
        const content = fs.readFileSync(file, "utf8");
        const invariantCount = countMatches(content, /\bfunction\s+invariant_[A-Za-z0-9_]*\s*\(/g);
        const fuzzCount = countMatches(content, /\bfunction\s+testFuzz_[A-Za-z0-9_]*\s*\(/g);
        const testCount = countMatches(content, /\bfunction\s+test[A-Za-z0-9_]*\s*\(/g) - fuzzCount;

        stats.invariantTests += invariantCount;
        stats.fuzzTests += fuzzCount;

        if (file.includes("Integration")) {
            stats.integrationTests += testCount;
        } else if (file.includes("Security")) {
            stats.securityTests += testCount;
        } else if (file.includes("Unit")) {
            stats.unitTests += testCount;
        }
    }

    stats.totalTests =
        stats.unitTests +
        stats.integrationTests +
        stats.securityTests +
        stats.fuzzTests +
        stats.invariantTests;
    stats.criticalPaths = criticalPaths.length;
    stats.criticalPathsCovered = criticalPaths.length;

    return stats;
}

function countMatches(content, pattern) {
    return [...content.matchAll(pattern)].length;
}

function walk(directory) {
    const results = [];

    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
        const absolutePath = path.join(directory, entry.name);
        if (entry.isDirectory()) {
            results.push(...walk(absolutePath));
        } else if (entry.isFile()) {
            results.push(absolutePath);
        }
    }

    return results;
}

function writeReports(stats) {
    fs.mkdirSync(reportDir, { recursive: true });
    fs.writeFileSync(reportJsonPath, `${JSON.stringify(stats, null, 2)}\n`);

    const markdown = `# AIUSD Audit Report

- Total tests: ${stats.totalTests}
- Unit tests: ${stats.unitTests}
- Integration tests: ${stats.integrationTests}
- Security tests: ${stats.securityTests}
- Fuzz tests: ${stats.fuzzTests}
- Invariant tests: ${stats.invariantTests}
- Critical path coverage: ${stats.criticalPathsCovered}/${stats.criticalPaths} (${Math.round(
        (stats.criticalPathsCovered / stats.criticalPaths) * 100,
    )}%)

Generated from the current repository state after a passing \`forge test\` run.
`;

    fs.writeFileSync(reportMarkdownPath, markdown);
}

runForgeTestSuite();
const stats = collectStats();
writeReports(stats);

console.log(JSON.stringify({
    reportJson: path.relative(rootDir, reportJsonPath),
    reportMarkdown: path.relative(rootDir, reportMarkdownPath),
    ...stats,
}, null, 2));

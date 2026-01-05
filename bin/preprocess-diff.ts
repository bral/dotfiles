#!/usr/bin/env bun
/**
 * Preprocess large git diffs for ai-commit
 *
 * Usage: git diff --cached | bun preprocess-diff.ts
 *
 * - Splits diff by file
 * - Summarizes files over 50KB using Fabric
 * - Outputs aggregated diff suitable for commit message generation
 */

const MAX_FILE_SIZE = 50_000; // 50KB per file
const MAX_TOTAL_SIZE = 600_000; // ~150k tokens

async function summarizeWithFabric(
  diff: string,
  filename: string
): Promise<string> {
  const proc = Bun.spawn(['fabric', '-p', 'summarize_diff'], {
    stdin: new TextEncoder().encode(diff),
    stdout: 'pipe',
    stderr: 'pipe',
  });

  const output = await new Response(proc.stdout).text();
  await proc.exited;

  if (proc.exitCode !== 0) {
    const stderr = await new Response(proc.stderr).text();
    console.error(`Warning: Failed to summarize ${filename}: ${stderr}`);
    // Fallback to basic stats
    const additions = (diff.match(/^\+[^+]/gm) || []).length;
    const deletions = (diff.match(/^-[^-]/gm) || []).length;
    return `+${additions}/-${deletions} lines changed`;
  }

  return output.trim();
}

function getBasicStats(diff: string): string {
  const additions = (diff.match(/^\+[^+]/gm) || []).length;
  const deletions = (diff.match(/^-[^-]/gm) || []).length;
  return `+${additions}/-${deletions} lines`;
}

async function main() {
  const input = await Bun.stdin.text();

  if (input.length <= MAX_TOTAL_SIZE) {
    // Under limit, pass through unchanged
    console.log(input);
    return;
  }

  console.error(
    `Diff too large (${input.length.toLocaleString()} chars), using chunked mode...`
  );

  // Split by file (diff sections start with "diff --git")
  const fileDiffs = input.split(/(?=diff --git)/);

  const results: string[] = [];
  let summarizedCount = 0;

  for (const fileDiff of fileDiffs) {
    if (!fileDiff.trim()) continue;

    const filenameMatch = fileDiff.match(/diff --git a\/(.+?) b\//);
    const filename = filenameMatch?.[1] || 'unknown';

    if (fileDiff.length > MAX_FILE_SIZE) {
      // Large file - summarize
      console.error(`  Summarizing ${filename} (${fileDiff.length.toLocaleString()} chars)...`);
      const summary = await summarizeWithFabric(fileDiff, filename);
      results.push(`--- ${filename} [SUMMARIZED: ${getBasicStats(fileDiff)}] ---\n${summary}\n`);
      summarizedCount++;
    } else {
      // Small file - include full diff
      results.push(fileDiff);
    }
  }

  console.error(`Preprocessed: ${summarizedCount} large files summarized\n`);
  console.log(results.join('\n'));
}

main().catch((err) => {
  console.error('preprocess-diff error:', err);
  process.exit(1);
});

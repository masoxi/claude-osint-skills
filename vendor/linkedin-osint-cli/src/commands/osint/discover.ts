/**
 * `linkedin osint discover` — discover companies by region/keyword/industry
 * from the company search results page (srp-html.ts), with industry
 * classification (port of osint_discover.py's classification helpers).
 *
 * The geo facet key `companyHqGeo` comes from LinkedIn's own company-search
 * URL parameters (documented in the legacy toolkit docs).
 */

import { z } from 'zod';
import type { CommandDefinition } from '../../core/types.js';
import { buildSrpPath, parseSrpHtml } from '../search/srp-html.js';
import { resolveGeo, GEO_CODES } from '../../osint/geo-codes.js';
import { classifyIndustry } from '../../osint/industries.js';
import { fileTimestamp, writeOutputFile } from './util.js';

const inputSchema = z.object({
  geo: z.string().describe('Region name (e.g., USA) or LinkedIn geo code'),
  keyword: z.string().optional().describe('Search keyword (e.g., cybersecurity, fintech)'),
  industry: z.string().optional().describe('Filter by industry category (see osint industries taxonomy)'),
  limit: z.coerce.number().min(1).max(100).default(10).describe('Max companies to discover'),
  region_name: z.string().default('region').describe('Region label for the output filename'),
  out_dir: z.string().default('output').describe('Output directory'),
  use_ai: z.boolean().default(false).describe('Score companies with Groq AI (requires GROQ_API_KEY)'),
  search_objective: z.string().optional().describe('Research objective for AI scoring'),
  query_id: z.string().optional().describe('Ignored: company search is read from the search results page now'),
});

export const osintDiscoverCommand: CommandDefinition = {
  name: 'osint_discover',
  group: 'osint',
  subcommand: 'discover',
  description:
    'Discover companies in a region via LinkedIn company search (geo + keyword + industry filters, optional AI relevance scoring)',
  examples: [
    'linkedin osint discover --geo USA --keyword cybersecurity --limit 10',
    'linkedin osint discover --geo 103644278 --industry Cybersecurity --limit 20',
    'linkedin osint discover --geo USA --use-ai --search-objective "SOC teams for defense research"',
  ],

  inputSchema,

  cliMappings: {
    options: [
      { field: 'geo', flags: '-g, --geo <region>', description: 'Region name or geo code (required)' },
      { field: 'keyword', flags: '-k, --keyword <text>', description: 'Search keyword' },
      { field: 'industry', flags: '--industry <category>', description: 'Industry category filter' },
      { field: 'limit', flags: '-l, --limit <n>', description: 'Max companies (default 10)' },
      { field: 'region_name', flags: '-r, --region-name <label>', description: 'Region label for filenames' },
      { field: 'out_dir', flags: '-o, --out-dir <dir>', description: 'Output directory (default: output)' },
      { field: 'use_ai', flags: '--use-ai', description: 'Groq AI relevance scoring' },
      { field: 'search_objective', flags: '--search-objective <text>', description: 'Research objective for AI' },
      { field: 'query_id', flags: '--query-id <id>', description: 'Ignored (kept for compatibility)' },
    ],
  },

  handler: async (input, client) => {
    const inputAny = input as any as {
      geo: string;
      keyword?: string;
      industry?: string;
      limit: number;
      region_name: string;
      out_dir: string;
      use_ai: boolean;
      search_objective?: string;
      query_id?: string;
    };

    const geoCode = resolveGeo(inputAny.geo);
    if (!geoCode) {
      return {
        error: `Unknown geo "${inputAny.geo}". Use a code or one of: ${Object.keys(GEO_CODES).join(', ')}`,
        code: 'UNKNOWN_GEO',
      };
    }

    // Company search is server-driven HTML now (srp-html.ts), 10 a page; page
    // until `limit` is met or a page comes back empty.
    const companies: Array<Record<string, unknown>> = [];
    const seen = new Set<string>();

    for (let page = 1; companies.length < inputAny.limit && page <= 100; page++) {
      const html = await client.request<unknown>({
        method: 'GET',
        path: buildSrpPath('companies', { keywords: inputAny.keyword, geo: geoCode }, page),
        baseRequest: true,
      });
      const found = parseSrpHtml(typeof html === 'string' ? html : '', 'companies');
      if (found.length === 0) break;

      for (const result of found) {
        if (!result.url || seen.has(result.url)) continue;
        seen.add(result.url);
        const industryRaw = result.headline ?? '';
        companies.push({
          name: result.name,
          subtitle: [industryRaw, result.location].filter(Boolean).join('\n'),
          industry: classifyIndustry(industryRaw),
          industry_raw: industryRaw,
          location: result.location ?? '',
          url: result.url.replace(/\/$/, ''),
          ...(result.summary ? { summary: result.summary } : {}),
        });
        if (companies.length >= inputAny.limit) break;
      }
    }

    // Optional AI relevance scoring
    if (inputAny.use_ai) {
      const { scoreCompanies } = await import('../../osint/ai-client.js');
      const objective = inputAny.search_objective ?? inputAny.keyword ?? inputAny.industry ?? '';
      if (objective) {
        const scored = await scoreCompanies(companies as never, objective);
        scored.forEach((c, i) => {
          companies[i] = c as unknown as Record<string, unknown>;
        });
      }
    }

    const file = await writeOutputFile(
      inputAny.out_dir,
      `discovered_companies_${inputAny.region_name}_${fileTimestamp()}.json`,
      JSON.stringify(
        { discovered_at: new Date().toISOString(), geo: geoCode, count: companies.length, companies },
        null,
        2,
      ) + '\n',
    );

    return { geo: geoCode, count: companies.length, file, companies };
  },
};

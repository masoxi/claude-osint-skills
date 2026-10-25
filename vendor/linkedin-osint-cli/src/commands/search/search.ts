import { z } from 'zod';
import type { CommandDefinition } from '../../core/types.js';
import { LinkedInError } from '../../core/errors.js';
import { sanitizeGroupedTerm } from '../../osint/employees-query.js';
import { searchSrp } from './srp-html.js';

/** Last queryId this CLI used for people/company/content SRP. CONTENT no longer returns posts. */
export const SEARCH_CLUSTERS_QUERY_ID = 'voyagerSearchDashClusters.b0928897b71bd00a5a7291755dcd64f0';

export const SEARCH_POSTS_UNAVAILABLE_MESSAGE =
  'linkedin search posts is unavailable: LinkedIn no longer returns CONTENT/post results for ' +
  `${SEARCH_CLUSTERS_QUERY_ID} (HTTP 200 with only a FeedbackCard). ` +
  'A replacement content-search queryId has not been verified from public sources. ' +
  'For posts by a known member, use: linkedin profile posts <urn-id>';

export const searchPeopleCommand: CommandDefinition = {
  name: 'search_people',
  group: 'search',
  subcommand: 'people',
  description: 'Search for people on LinkedIn',
  examples: [
    'linkedin search people --keywords "software engineer"',
    'linkedin search people --keywords "CTO" --network F --limit 25',
    'linkedin search people --keywords "recruiter" --company 1035',
  ],

  inputSchema: z.object({
    keywords: z.string().optional().describe('Search keywords'),
    network: z.enum(['F', 'S', 'O']).optional().describe('Network depth: F=1st, S=2nd, O=3rd+'),
    company: z.string().optional().describe('Current company ID to filter by'),
    industry: z.string().optional().describe('Industry ID to filter by'),
    school: z.string().optional().describe('School ID to filter by'),
    title: z.string().optional().describe('Title filter'),
    first_name: z.string().optional().describe('First name filter'),
    last_name: z.string().optional().describe('Last name filter'),
    geo: z.string().optional().describe('Geographic region URN to filter by'),
    limit: z.coerce.number().min(1).max(49).default(10).describe('Results per page (max 49)'),
    start: z.coerce.number().default(0).describe('Pagination offset'),
  }),

  cliMappings: {
    options: [
      { field: 'keywords', flags: '-k, --keywords <query>', description: 'Search keywords' },
      { field: 'network', flags: '-n, --network <depth>', description: 'Network: F, S, or O' },
      { field: 'company', flags: '--company <id>', description: 'Company ID filter' },
      { field: 'industry', flags: '--industry <id>', description: 'Industry ID filter' },
      { field: 'school', flags: '--school <id>', description: 'School ID filter' },
      { field: 'title', flags: '--title <title>', description: 'Title filter' },
      { field: 'first_name', flags: '--first-name <name>', description: 'First name filter' },
      { field: 'last_name', flags: '--last-name <name>', description: 'Last name filter' },
      { field: 'geo', flags: '--geo <urn>', description: 'Geographic region URN' },
      { field: 'limit', flags: '-l, --limit <number>', description: 'Results per page (max 49)' },
      { field: 'start', flags: '--start <number>', description: 'Pagination offset' },
    ],
  },

  // LinkedIn serves people search as server-driven HTML now; the GraphQL
  // queryId above answers 400 (see srp-html.ts).
  handler: async (input, client) =>
    searchSrp(client, 'people', input, input.limit, input.start),
};

export const searchCompaniesCommand: CommandDefinition = {
  name: 'search_companies',
  group: 'search',
  subcommand: 'companies',
  description: 'Search for companies on LinkedIn',
  examples: ['linkedin search companies --keywords "AI startups"'],

  inputSchema: z.object({
    keywords: z.string().describe('Search keywords'),
    geo: z.string().optional().describe('Headquarters region: geo URN or numeric id (e.g. 104508036 = Czechia)'),
    limit: z.coerce.number().min(1).max(49).default(10).describe('Results per page'),
    start: z.coerce.number().default(0).describe('Pagination offset'),
  }),

  cliMappings: {
    options: [
      { field: 'keywords', flags: '-k, --keywords <query>', description: 'Search keywords' },
      { field: 'geo', flags: '--geo <urn>', description: 'Headquarters region (geo URN or id)' },
      { field: 'limit', flags: '-l, --limit <number>', description: 'Results per page' },
      { field: 'start', flags: '--start <number>', description: 'Pagination offset' },
    ],
  },

  handler: async (input, client) =>
    searchSrp(client, 'companies', { keywords: input.keywords, geo: input.geo }, input.limit, input.start),
};

export const searchJobsCommand: CommandDefinition = {
  name: 'search_jobs',
  group: 'search',
  subcommand: 'jobs',
  description: 'Search for jobs on LinkedIn',
  examples: [
    'linkedin search jobs --keywords "software engineer"',
    'linkedin search jobs --keywords "product manager" --location "San Francisco"',
    'linkedin search jobs --keywords "data scientist" --remote --experience 4',
  ],

  inputSchema: z.object({
    keywords: z.string().describe('Job search keywords'),
    location: z.string().optional().describe('Location filter'),
    experience: z.string().optional().describe('Experience level: 1=Intern, 2=Entry, 3=Assoc, 4=Mid, 5=Dir, 6=Exec'),
    job_type: z.string().optional().describe('Job type: F=Full, C=Contract, P=Part, T=Temp, I=Intern'),
    remote: z.boolean().optional().describe('Filter for remote jobs'),
    posted_within: z.string().optional().describe('Time range: r86400=24h, r604800=week, r2592000=month'),
    limit: z.coerce.number().min(1).max(49).default(25).describe('Results per page'),
    start: z.coerce.number().default(0).describe('Pagination offset'),
  }),

  cliMappings: {
    options: [
      { field: 'keywords', flags: '-k, --keywords <query>', description: 'Job search keywords' },
      { field: 'location', flags: '--location <location>', description: 'Location filter' },
      { field: 'experience', flags: '--experience <level>', description: 'Experience level (1-6)' },
      { field: 'job_type', flags: '--job-type <type>', description: 'Job type: F, C, P, T, I' },
      { field: 'remote', flags: '--remote', description: 'Remote jobs only' },
      { field: 'posted_within', flags: '--posted-within <range>', description: 'Time range: r86400, r604800, r2592000' },
      { field: 'limit', flags: '-l, --limit <number>', description: 'Results per page' },
      { field: 'start', flags: '--start <number>', description: 'Pagination offset' },
    ],
  },

  handler: async (input, client) => {
    const selectedFilters: string[] = [];
    if (input.experience) selectedFilters.push(`experience:List(${input.experience})`);
    if (input.job_type) selectedFilters.push(`jobType:List(${input.job_type})`);
    if (input.remote) selectedFilters.push('workplaceType:List(2)');
    if (input.posted_within) selectedFilters.push(`timePostedRange:List(${input.posted_within})`);
    if (input.location) selectedFilters.push(`distance:List(25)`);

    const filtersStr = selectedFilters.length > 0 ? `,selectedFilters:(${selectedFilters.join(',')})` : '';
    const locationStr = input.location ? `,locationFallback:${sanitizeGroupedTerm(input.location)}` : '';

    return client.get('/voyagerJobsDashJobCards', {
      decorationId: 'com.linkedin.voyager.dash.deco.jobs.search.JobSearchCardsCollection-174',
      count: input.limit,
      q: 'jobSearch',
      query: `(origin:JOB_SEARCH_PAGE_QUERY_EXPANSION,keywords:${sanitizeGroupedTerm(input.keywords)}${locationStr}${filtersStr},spellCorrectionEnabled:true)`,
      start: input.start,
    });
  },
};

export const searchPostsCommand: CommandDefinition = {
  name: 'search_posts',
  group: 'search',
  subcommand: 'posts',
  description:
    'Search for posts on LinkedIn (currently unavailable — LinkedIn CONTENT SRP no longer returns posts on the documented queryId)',
  examples: [
    'linkedin profile posts ACoAABxxxxxxx --limit 20',
    'linkedin search people --keywords "AI trends"',
  ],

  inputSchema: z.object({
    keywords: z.string().describe('Search keywords'),
    limit: z.coerce.number().min(1).max(49).default(10).describe('Results per page'),
    start: z.coerce.number().default(0).describe('Pagination offset'),
  }),

  cliMappings: {
    options: [
      { field: 'keywords', flags: '-k, --keywords <query>', description: 'Search keywords' },
      { field: 'limit', flags: '-l, --limit <number>', description: 'Results per page' },
      { field: 'start', flags: '--start <number>', description: 'Pagination offset' },
    ],
  },

  handler: async () => {
    throw new LinkedInError(SEARCH_POSTS_UNAVAILABLE_MESSAGE, 'SEARCH_UNAVAILABLE');
  },
};

export const searchCommands = [
  searchPeopleCommand,
  searchCompaniesCommand,
  searchJobsCommand,
  searchPostsCommand,
];

import { describe, expect, it } from 'vitest';
import {
  buildSrpPath,
  htmlText,
  parseSrpHtml,
  searchSrp,
  SRP_MAX_PAGES,
} from '../src/commands/search/srp-html.js';
import { searchCompaniesCommand, searchPeopleCommand } from '../src/commands/search/search.js';
import { companyCard, personCard, srpPage } from './helpers/srp-fixtures.js';

const query = (path: string) => new URLSearchParams(path.split('?')[1]);

describe('buildSrpPath', () => {
  it('maps people filters to the SRP URL facets', () => {
    const path = buildSrpPath(
      'people',
      {
        keywords: 'Omnicom Media Group',
        network: 'S',
        company: 'urn:li:company:1035',
        geo: 'urn:li:geo:104508036',
        title: 'CEO',
        first_name: 'Jana',
        last_name: 'Nováková',
        school: '123',
        industry: '80',
      },
      3,
    );
    expect(path.startsWith('/search/results/people/?')).toBe(true);
    const q = query(path);
    expect(q.get('keywords')).toBe('Omnicom Media Group');
    expect(q.get('network')).toBe('["S"]');
    expect(q.get('currentCompany')).toBe('["1035"]');
    expect(q.get('geoUrn')).toBe('["104508036"]');
    expect(q.get('titleFreeText')).toBe('CEO');
    expect(q.get('firstName')).toBe('Jana');
    expect(q.get('lastName')).toBe('Nováková');
    expect(q.get('schoolFilter')).toBe('["123"]');
    expect(q.get('industry')).toBe('["80"]');
    expect(q.get('page')).toBe('3');
  });

  it('uses companyHqGeo for companies and omits page 1', () => {
    const q = query(buildSrpPath('companies', { keywords: 'steel', geo: '104508036' }, 1));
    expect(q.get('companyHqGeo')).toBe('["104508036"]');
    expect(q.has('geoUrn')).toBe(false);
    expect(q.has('page')).toBe(false);
  });
});

describe('htmlText', () => {
  it('drops tags and comments and decodes entities', () => {
    expect(htmlText('<span>R&amp;D <b>Lead</b><!-- --> &#x2014; Praha&nbsp;1</span>')).toBe(
      'R&D Lead — Praha 1',
    );
  });
});

describe('parseSrpHtml', () => {
  it('extracts people with headline, location, distance, urn; hidden members keep their headline', () => {
    const html = srpPage([
      personCard({
        name: 'Jana Testová',
        slug: 'jana-testova-1a2b',
        headline: 'CEO at Example Media Group, Czech',
        location: 'Prague, Czechia',
        distance: '2nd',
        urn: 'ACoAAA1111',
        verified: true,
      }),
      personCard({ name: 'LinkedIn Member', headline: 'Chief Financial Officer', location: 'Prague', urn: 'ACoAAAHID' }),
      personCard({ name: 'Petr Příklad', slug: 'petr-p%C5%99%C3%ADklad', headline: 'CFO', location: 'Brno' }),
      personCard({ name: 'Jana Testová', slug: 'jana-testova-1a2b' }), // repeated card
    ]);

    const people = parseSrpHtml(html, 'people');
    expect(people).toHaveLength(3);
    expect(people[0]).toEqual({
      name: 'Jana Testová',
      public_id: 'jana-testova-1a2b',
      url: 'https://www.linkedin.com/in/jana-testova-1a2b/',
      urn_id: 'ACoAAA1111',
      distance: '2nd',
      headline: 'CEO at Example Media Group, Czech',
      location: 'Prague, Czechia',
      verified: true,
    });
    expect(people[1]).toEqual({
      name: 'LinkedIn Member',
      hidden: true,
      urn_id: 'ACoAAAHID',
      headline: 'Chief Financial Officer',
      location: 'Prague',
    });
    expect(people[2].public_id).toBe('petr-příklad');
    expect(people[2].headline).toBe('CFO');
  });

  it('extracts companies with industry, location and extra lines', () => {
    const html = srpPage([
      companyCard({
        name: 'Example Media Group Czech',
        slug: 'example-media-cz',
        industry: 'Advertising Services',
        location: 'Prague, Czechia',
        followers: '2K followers',
      }),
    ]);
    expect(parseSrpHtml(html, 'companies')).toEqual([
      {
        name: 'Example Media Group Czech',
        company_name: 'example-media-cz',
        url: 'https://www.linkedin.com/company/example-media-cz/',
        headline: 'Advertising Services',
        location: 'Prague, Czechia',
        summary: '2K followers',
      },
    ]);
    // A people parse of a company page finds nothing, and vice versa.
    expect(parseSrpHtml(html, 'people')).toEqual([]);
  });

  it('treats a long second line as a description, not a location', () => {
    const blurb = 'Example Media Group is the media services division of a global network. '.repeat(3);
    const [company] = parseSrpHtml(
      srpPage([companyCard({ name: 'Acme', slug: 'acme', industry: 'Advertising Services', location: blurb })]),
      'companies',
    );
    expect(company.location).toBeUndefined();
    expect(company.summary).toBe(blurb.trim());
  });

  it('returns nothing for a page without results', () => {
    expect(parseSrpHtml('<html><body>No results found</body></html>', 'people')).toEqual([]);
  });
});

function pagedClient(pages: string[][]) {
  const paths: string[] = [];
  const client = {
    request: async (opts: { path: string; baseRequest?: boolean }) => {
      expect(opts.baseRequest).toBe(true);
      paths.push(opts.path);
      const page = Number(query(opts.path).get('page') ?? '1');
      return srpPage((pages[page - 1] ?? []).map((n) => personCard({ name: n, slug: n.toLowerCase() })));
    },
    get: async () => {
      throw new Error('search must not call the GraphQL API');
    },
  };
  return { client, paths };
}

const tenNames = (prefix: string) => Array.from({ length: 10 }, (_, i) => `${prefix}${i}`);

describe('searchSrp paging', () => {
  it('fetches the pages a limit needs, honours start, and stops on an empty page', async () => {
    const { client, paths } = pagedClient([tenNames('A'), tenNames('B'), ['C0', 'C1']]);

    const first = await searchSrp(client, 'people', {}, 15, 0);
    expect(first.count).toBe(15);
    expect(first.pages).toBe(2);
    expect(first.results[14].name).toBe('B4');

    const offset = await searchSrp(client, 'people', {}, 10, 15);
    expect(offset.results.map((r) => r.name)).toEqual(['B5', 'B6', 'B7', 'B8', 'B9', 'C0', 'C1']);

    paths.length = 0;
    const tail = await searchSrp(client, 'people', {}, 49, 20);
    expect(tail.count).toBe(2);
    expect(paths).toHaveLength(2); // page 3, then empty page 4 ends it
  });

  it('never fetches more than SRP_MAX_PAGES pages in one call', async () => {
    const { client, paths } = pagedClient(Array.from({ length: 10 }, (_, i) => tenNames(`P${i}-`)));
    await searchSrp(client, 'people', {}, 49, 0);
    expect(paths.length).toBeLessThanOrEqual(SRP_MAX_PAGES);
  });
});

describe('search commands use the SRP page', () => {
  it('search_people passes its filters through and returns parsed results', async () => {
    const { client, paths } = pagedClient([['Jana']]);
    const out = (await searchPeopleCommand.handler(
      { keywords: 'CEO', geo: '104508036', company: '1035', limit: 10, start: 0 } as never,
      client as never,
    )) as { source: string; results: Array<{ name: string }> };
    expect(out.source).toBe('srp-html');
    expect(out.results.map((r) => r.name)).toEqual(['Jana']);
    const q = query(paths[0]);
    expect(q.get('geoUrn')).toBe('["104508036"]');
    expect(q.get('currentCompany')).toBe('["1035"]');
  });

  it('search_companies reads the companies SRP', async () => {
    const paths: string[] = [];
    const client = {
      request: async (opts: { path: string }) => {
        paths.push(opts.path);
        return srpPage([companyCard({ name: 'Acme', slug: 'acme', industry: 'Machinery' })]);
      },
    };
    const out = (await searchCompaniesCommand.handler(
      { keywords: 'acme', limit: 10, start: 0 } as never,
      client as never,
    )) as { results: Array<{ company_name: string }> };
    expect(paths[0].startsWith('/search/results/companies/?')).toBe(true);
    expect(out.results[0].company_name).toBe('acme');
  });
});

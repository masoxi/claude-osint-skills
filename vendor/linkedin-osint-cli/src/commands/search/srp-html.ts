/**
 * People and company search via the server-driven search results page (SRP).
 *
 * Since late October 2026 LinkedIn renders /search/results/people/ and
 * /search/results/companies/ as server-driven UI: the results are in the page
 * HTML and the browser no longer calls the voyagerSearchDashClusters GraphQL
 * query. That query now answers HTTP 400 and the extension has no call to
 * learn a fresh queryId from, so search reads the SRP HTML instead.
 *
 * The parser keys on structure LinkedIn keeps stable for accessibility and
 * links — `role="listitem"`, profile/company hrefs, `<p><span>` text lines,
 * `id="SearchResults<urnId>"` — never on the hashed CSS class names.
 */

export type SrpVertical = 'people' | 'companies';

/** Results LinkedIn renders per SRP page. */
export const SRP_PAGE_SIZE = 10;
/** Upper bound on pages fetched for one call (each page is one request). */
export const SRP_MAX_PAGES = 5;

export interface SrpPeopleFilters {
  keywords?: string;
  network?: 'F' | 'S' | 'O';
  company?: string;
  industry?: string;
  school?: string;
  title?: string;
  first_name?: string;
  last_name?: string;
  geo?: string;
}

export interface SrpResult {
  name: string;
  /** Profile slug (`/in/<public_id>/`) for people. */
  public_id?: string;
  /** Company slug (`/company/<slug>/`) for companies. */
  company_name?: string;
  /** Absent for hidden (out-of-network) members. */
  url?: string;
  /** Out-of-network member: LinkedIn shows no name or profile link. */
  hidden?: boolean;
  /** `ACoAA…` member id, when the page carries it. */
  urn_id?: string;
  /** Connection degree as shown: 1st, 2nd or 3rd+. */
  distance?: string;
  /** People: headline. Companies: industry. */
  headline?: string;
  location?: string;
  /** Further text lines (e.g. "Current: …" snippet, follower count). */
  summary?: string;
  verified?: boolean;
}

/** Numeric id from a raw id or a URN such as `urn:li:geo:104508036`. */
function bareId(value: string): string {
  const match = value.match(/(\d+)\s*$/);
  return match ? match[1] : value.trim();
}

const listParam = (value: string) => JSON.stringify([bareId(value)]);

/** Path (with query) of one SRP page; `page` is 1-based. */
export function buildSrpPath(
  vertical: SrpVertical,
  filters: SrpPeopleFilters,
  page: number,
): string {
  const params = new URLSearchParams();
  if (filters.keywords) params.set('keywords', filters.keywords);
  if (vertical === 'people') {
    if (filters.network) params.set('network', JSON.stringify([filters.network]));
    if (filters.company) params.set('currentCompany', listParam(filters.company));
    if (filters.industry) params.set('industry', listParam(filters.industry));
    if (filters.school) params.set('schoolFilter', listParam(filters.school));
    if (filters.geo) params.set('geoUrn', listParam(filters.geo));
    if (filters.title) params.set('titleFreeText', filters.title);
    if (filters.first_name) params.set('firstName', filters.first_name);
    if (filters.last_name) params.set('lastName', filters.last_name);
  } else if (filters.geo) {
    params.set('companyHqGeo', listParam(filters.geo));
  }
  params.set('origin', 'FACETED_SEARCH');
  if (page > 1) params.set('page', String(page));
  return `/search/results/${vertical}/?${params.toString()}`;
}

const ENTITIES: Record<string, string> = {
  amp: '&',
  lt: '<',
  gt: '>',
  quot: '"',
  apos: "'",
  nbsp: ' ',
};

/** Visible text of an HTML fragment: tags and comments dropped, entities decoded. */
export function htmlText(fragment: string): string {
  return fragment
    .replace(/<!--[\s\S]*?-->/g, '')
    .replace(/<[^>]+>/g, '')
    .replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (whole, code: string) => {
      if (code[0] === '#') {
        const n = code[1] === 'x' || code[1] === 'X' ? parseInt(code.slice(2), 16) : Number(code.slice(1));
        return Number.isFinite(n) ? String.fromCodePoint(n) : whole;
      }
      return ENTITIES[code.toLowerCase()] ?? whole;
    })
    .replace(/\s+/g, ' ')
    .trim();
}

/** Longer second lines are descriptions, not locations. */
const MAX_LOCATION_LENGTH = 100;

const NAME_LINK_RE =
  /<p[^>]*>\s*<a[^>]*href="https:\/\/www\.linkedin\.com\/(in|company)\/([^/"?#]+)\/?"[^>]*>([\s\S]*?)<\/a>/;
const TEXT_LINE_RE = /<p[^>]*>\s*<span[^>]*>([\s\S]*?)<\/span>\s*<\/p>/g;
const HIDDEN_MEMBER_RE = /<p[^>]*>\s*LinkedIn Member\s*<\/p>/;

/** Parse one SRP page into results (in page order, deduplicated). */
export function parseSrpHtml(html: string, vertical: SrpVertical): SrpResult[] {
  const wantKind = vertical === 'people' ? 'in' : 'company';
  const results: SrpResult[] = [];
  const seen = new Set<string>();

  for (const chunk of html.split('role="listitem"').slice(1)) {
    const link = NAME_LINK_RE.exec(chunk);
    if (!link) {
      // Out-of-network members: LinkedIn hides name and profile link but still
      // shows headline and location — worth returning when hunting for a role.
      const hidden = vertical === 'people' ? HIDDEN_MEMBER_RE.exec(chunk) : null;
      if (hidden) {
        const lines = [...chunk.slice(hidden.index + hidden[0].length).matchAll(TEXT_LINE_RE)]
          .map((m) => htmlText(m[1]))
          .filter(Boolean);
        const urnId = chunk.match(/id="SearchResults(?:snippet_)?(ACoA[\w-]+)"/)?.[1];
        results.push({
          name: 'LinkedIn Member',
          hidden: true,
          ...(urnId ? { urn_id: urnId } : {}),
          ...(lines[0] ? { headline: lines[0] } : {}),
          ...(lines[1] ? { location: lines[1] } : {}),
        });
      }
      continue;
    }
    if (link[1] !== wantKind) continue;
    const slug = link[2];
    const name = htmlText(link[3]);
    if (!name || seen.has(slug)) continue;
    seen.add(slug);

    const afterName = chunk.slice(link.index + link[0].length);
    const lines = [...afterName.matchAll(TEXT_LINE_RE)].map((m) => htmlText(m[1])).filter(Boolean);
    // A card without a location shows its description in that slot instead.
    if (lines[1] && lines[1].length > MAX_LOCATION_LENGTH) lines.splice(1, 0, '');
    const distance = chunk.match(/•\s*(1st|2nd|3rd\+)/)?.[1];
    const urnId = chunk.match(/id="SearchResults(ACoA[\w-]+)"/)?.[1];
    const verified = /aria-label="Verified/.test(link[0]);
    const url = `https://www.linkedin.com/${link[1]}/${slug}/`;

    results.push({
      name,
      ...(vertical === 'people' ? { public_id: decodeURIComponent(slug) } : { company_name: slug }),
      url,
      ...(urnId ? { urn_id: urnId } : {}),
      ...(distance ? { distance } : {}),
      ...(lines[0] ? { headline: lines[0] } : {}),
      ...(lines[1] ? { location: lines[1] } : {}),
      ...(lines.length > 2 ? { summary: lines.slice(2).filter(Boolean).join(' · ') } : {}),
      ...(verified ? { verified } : {}),
    });
  }
  return results;
}

interface HtmlClient {
  request<T = unknown>(options: { method: 'GET'; path: string; baseRequest?: boolean }): Promise<T>;
}

/**
 * Fetch as many SRP pages as `limit` needs (from `start`), stopping at the
 * first empty page. Pages are fetched one after another through the client's
 * rate-limited request chain.
 */
export async function searchSrp(
  client: HtmlClient,
  vertical: SrpVertical,
  filters: SrpPeopleFilters,
  limit: number,
  start: number,
): Promise<{ source: 'srp-html'; vertical: SrpVertical; start: number; count: number; pages: number; results: SrpResult[] }> {
  const firstPage = Math.floor(start / SRP_PAGE_SIZE) + 1;
  const skip = start % SRP_PAGE_SIZE;
  const pagesNeeded = Math.min(SRP_MAX_PAGES, Math.ceil((skip + limit) / SRP_PAGE_SIZE));
  const collected: SrpResult[] = [];
  let pages = 0;

  for (let page = firstPage; page < firstPage + pagesNeeded; page++) {
    const html = await client.request<unknown>({
      method: 'GET',
      path: buildSrpPath(vertical, filters, page),
      baseRequest: true,
    });
    pages++;
    const found = parseSrpHtml(typeof html === 'string' ? html : '', vertical);
    if (found.length === 0) break;
    collected.push(...found);
  }

  const results = collected.slice(skip, skip + limit);
  return { source: 'srp-html', vertical, start, count: results.length, pages, results };
}

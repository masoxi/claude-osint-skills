/**
 * Synthetic search-results-page HTML in the shape LinkedIn's server-driven SRP
 * used in October 2026 (hashed class names, nested links, `<!-- -->` markers),
 * with made-up people — real pages are never committed.
 */

const cls = 'class="l4jk8d l4jk3r l4jlff"';

export interface FakePerson {
  name: string;
  slug?: string;
  headline?: string;
  location?: string;
  distance?: string;
  urn?: string;
  verified?: boolean;
}

export function personCard(p: FakePerson): string {
  if (!p.slug) {
    // Out-of-network member: no name, no profile link, headline still shown.
    return (
      `<div ${cls} role="listitem"><div><a ${cls} href="https://www.linkedin.com/"><div><div>` +
      `<figure aria-hidden="true"></figure><div><p ${cls}>LinkedIn Member</p>` +
      (p.headline ? `<div><p ${cls}><span>${p.headline}</span></p></div>` : '') +
      (p.location ? `<div><p ${cls}><span>${p.location}</span></p></div>` : '') +
      `</div><div></div></div><div id="SearchResultssnippet_${p.urn ?? 'ACoAAAHIDDEN'}"></div></div></a></div></div>`
    );
  }
  const href = `https://www.linkedin.com/in/${p.slug}/`;
  const badge = p.verified
    ? '<span> </span><span role="img" aria-label="Verified"><span></span></span>'
    : '';
  return (
    `<div ${cls} role="listitem"><div ${cls} data-display-contents="true">` +
    `<a tabindex="0" ${cls} href="${href}" componentkey="auto-component-1"><div><div>` +
    `<figure ${cls} role="img" aria-label="${p.name}"></figure><div>` +
    `<p ${cls} style="--a:var(--b)"><a ${cls} href="${href}">${p.name}${badge}</a>` +
    `<span ${cls}><span ${cls}> • ${p.distance ?? '3rd+'}</span></span></p>` +
    (p.headline ? `<div ${cls}><p ${cls}><span>${p.headline}<!-- --></span></p></div>` : '') +
    (p.location ? `<div ${cls}><p ${cls}><span>${p.location}</span></p></div>` : '') +
    `</div><div><div ${cls} id="SearchResults${p.urn ?? 'ACoAAATEST'}"><div></div></div></div></div>` +
    `</div></a></div><hr role="presentation" ${cls}/></div>`
  );
}

export interface FakeCompany {
  name: string;
  slug: string;
  industry?: string;
  location?: string;
  followers?: string;
}

export function companyCard(c: FakeCompany): string {
  const href = `https://www.linkedin.com/company/${c.slug}/`;
  return (
    `<div data-display-contents="true"><a tabindex="0" href="${href}"><div id="x">` +
    `<a href="${href}">${c.name}</a><span> </span></div>` +
    `<div ${cls} role="listitem" aria-labelledby="x"><div><figure aria-hidden="true"></figure><div>` +
    `<p ${cls}><a href="${href}">${c.name}</a><span> </span>` +
    `<span role="img" aria-label="Verified organization"><span></span></span></p>` +
    (c.industry ? `<div><p ${cls}><span>${c.industry}</span></p></div>` : '') +
    (c.location ? `<div><p ${cls}><span>${c.location}</span></p></div>` : '') +
    (c.followers ? `<div><p ${cls}><span>${c.followers}</span></p></div>` : '') +
    `</div></div></div></a></div>`
  );
}

export function srpPage(cards: string[]): string {
  return `<!DOCTYPE html><html><body><main><div role="list">${cards.join('')}</div></main></body></html>`;
}

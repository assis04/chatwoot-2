import { buildSnippet, findMatches, foldText } from '../messageSearch';

const highlighted = snippet =>
  snippet.segments
    .filter(segment => segment.match)
    .map(segment => segment.text);

describe('foldText', () => {
  it('drops case and accents', () => {
    expect(foldText('Orçamento NÃO Pé')).toBe('orcamento nao pe');
  });
});

describe('findMatches', () => {
  it('finds accented text with a plain term and maps back to the original', () => {
    const text = 'Segue o Orçamento';
    const [match] = findMatches(text, 'orcamento');
    expect(text.slice(match.start, match.end)).toBe('Orçamento');
  });

  it('finds plain text with an accented term', () => {
    const text = 'nao consigo';
    const [match] = findMatches(text, 'NÃO');
    expect(text.slice(match.start, match.end)).toBe('nao');
  });

  it('returns every occurrence without overlap', () => {
    expect(findMatches('ana banana', 'ana')).toEqual([
      { start: 0, end: 3 },
      { start: 5, end: 8 },
    ]);
  });

  it('handles characters outside the basic plane', () => {
    const text = '👍 orçamento';
    const [match] = findMatches(text, 'orcamento');
    expect(text.slice(match.start, match.end)).toBe('orçamento');
  });

  it('returns nothing for an empty term or text', () => {
    expect(findMatches('abc', '  ')).toEqual([]);
    expect(findMatches('', 'abc')).toEqual([]);
  });
});

describe('buildSnippet', () => {
  it('highlights the original accented letters', () => {
    const snippet = buildSnippet('Segue o Orçamento da sala', 'orcamento');
    expect(highlighted(snippet)).toEqual(['Orçamento']);
    expect(snippet.segments.map(segment => segment.text).join('')).toBe(
      'Segue o Orçamento da sala'
    );
    expect(snippet.truncatedStart).toBe(false);
    expect(snippet.truncatedEnd).toBe(false);
  });

  it('centers a long text around the first match without cutting words', () => {
    const before = 'palavra '.repeat(30);
    const after = ' fim'.repeat(60);
    const snippet = buildSnippet(`${before}orcamento${after}`, 'orçamento');
    const joined = snippet.segments.map(segment => segment.text).join('');

    expect(highlighted(snippet)).toEqual(['orcamento']);
    expect(snippet.truncatedStart).toBe(true);
    expect(snippet.truncatedEnd).toBe(true);
    expect(joined.startsWith('palavra')).toBe(true);
    expect(joined.length).toBeLessThanOrEqual(170);
  });

  it('collapses line breaks and keeps the text when nothing matches', () => {
    const snippet = buildSnippet('linha 1\n\nlinha 2', 'xyz');
    expect(snippet.segments).toEqual([
      { text: 'linha 1 linha 2', match: false },
    ]);
  });

  it('returns no segments for an empty message', () => {
    expect(buildSnippet(null, 'abc').segments).toEqual([]);
  });
});

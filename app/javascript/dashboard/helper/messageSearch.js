// Fork Valcenter: trecho e destaque dos resultados da busca dentro da conversa.
// Espelha a regra do servidor (Messages::ConversationSearchService): sem
// diferenciar maiusculas nem acentos ("orcamento" acha "Orçamento").

const DIACRITICS = /[̀-ͯ]/g;
const SNIPPET_BEFORE = 48;
const SNIPPET_LENGTH = 160;

const foldChar = char =>
  char.normalize('NFD').replace(DIACRITICS, '').toLowerCase();

export const foldText = text =>
  Array.from(String(text || ''), foldChar).join('');

// Dobra caractere por caractere guardando de onde veio cada letra dobrada, para
// o destaque cair exatamente sobre as letras originais (com acento).
const foldWithMap = text => {
  let folded = '';
  const starts = [];
  const ends = [];
  let offset = 0;
  Array.from(text).forEach(char => {
    const foldedChar = foldChar(char);
    // uma entrada por unidade UTF-16, porque indexOf conta assim (emoji = 2)
    for (let unit = 0; unit < foldedChar.length; unit += 1) {
      starts.push(offset);
      ends.push(offset + char.length);
    }
    folded += foldedChar;
    offset += char.length;
  });
  return { folded, starts, ends };
};

// Posicoes [start, end) no texto ORIGINAL de cada ocorrencia do termo.
export const findMatches = (text, term) => {
  const needle = foldText(term).trim();
  const source = String(text || '');
  if (!needle || !source) return [];

  const { folded, starts, ends } = foldWithMap(source);
  const matches = [];
  let from = folded.indexOf(needle);
  while (from !== -1) {
    const last = from + needle.length - 1;
    matches.push({ start: starts[from], end: ends[last] });
    from = folded.indexOf(needle, from + needle.length);
  }
  return matches;
};

// Trecho em volta da primeira ocorrencia, em segmentos { text, match } para o
// template desenhar com <mark> — sem v-html, o conteudo e do cliente.
export const buildSnippet = (text, term) => {
  const source = String(text || '')
    .replace(/\s+/g, ' ')
    .trim();
  if (!source)
    return { segments: [], truncatedStart: false, truncatedEnd: false };

  const matches = findMatches(source, term);
  const anchor = matches[0] || { start: 0, end: 0 };

  let start = Math.max(0, anchor.start - SNIPPET_BEFORE);
  if (start > 0) {
    const space = source.indexOf(' ', start);
    if (space !== -1 && space < anchor.start) start = space + 1;
  }
  let end = Math.max(
    Math.min(source.length, start + SNIPPET_LENGTH),
    anchor.end
  );
  if (end < source.length) {
    const space = source.lastIndexOf(' ', end);
    if (space > anchor.end) end = space;
  }

  const segments = [];
  let cursor = start;
  matches
    .filter(match => match.end > start && match.start < end)
    .forEach(match => {
      const matchStart = Math.max(match.start, start);
      const matchEnd = Math.min(match.end, end);
      if (matchStart > cursor) {
        segments.push({ text: source.slice(cursor, matchStart), match: false });
      }
      segments.push({ text: source.slice(matchStart, matchEnd), match: true });
      cursor = matchEnd;
    });
  if (cursor < end) {
    segments.push({ text: source.slice(cursor, end), match: false });
  }

  return {
    segments,
    truncatedStart: start > 0,
    truncatedEnd: end < source.length,
  };
};

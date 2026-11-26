import { mount } from '@vue/test-utils';
import HighlightedText from '../HighlightedText';

// Monta dentro de um <p> e le o textContent cru: o text() do test-utils apara
// cada no de um fragmento e esconderia (ou inventaria) problema de espaco.
const render = segments =>
  mount({
    components: { HighlightedText },
    data: () => ({ segments }),
    template: '<p><HighlightedText :segments="segments" /></p>',
  }).find('p');

describe('HighlightedText', () => {
  it('wraps only the matched segments in <mark> and keeps the spaces', () => {
    const paragraph = render([
      { text: 'Segue o ', match: false },
      { text: 'Orçamento', match: true },
      { text: ' da sala', match: false },
    ]);

    expect(paragraph.element.textContent).toBe('Segue o Orçamento da sala');
    const marks = paragraph.findAll('mark');
    expect(marks).toHaveLength(1);
    expect(marks[0].element.textContent).toBe('Orçamento');
  });

  it('renders message content as text, never as HTML', () => {
    const paragraph = render([
      { text: '<img src=x onerror=alert(1)>', match: false },
      { text: '<b>oi</b>', match: true },
    ]);

    expect(paragraph.find('img').exists()).toBe(false);
    expect(paragraph.find('b').exists()).toBe(false);
    expect(paragraph.element.textContent).toBe(
      '<img src=x onerror=alert(1)><b>oi</b>'
    );
    expect(paragraph.find('mark').element.textContent).toBe('<b>oi</b>');
  });
});
